-- services/recipe_service.lua
-- Recipe validation (§3.14 Recipe + Step) and the delete guard (§3.9 / §2.18 — a
-- recipe referenced by a custom drink cannot be deleted). All persistence is one
-- transaction in the repo layer.

local RecipeRepo = require("db/repo/recipe")
local MethodRepo = require("db/repo/method")
local ConfigRepo = require("db/repo/config")
local DrinkRepo = require("db/repo/drink")
local Support = require("services/support")

local RecipeService = {}

local SENSORY_AXES = { "acidity", "sweetness", "strength", "body", "brightness" }

local function validate_steps(steps, method)
  local allowed = {}
  for _, st in ipairs(method.step_types) do
    allowed[st.step_type] = true
  end
  for i, step in ipairs(steps or {}) do
    local where = "step " .. i
    if not allowed[step.step_type] then
      return string.format(
        "%s: '%s' is not a step type for %s",
        where,
        tostring(step.step_type),
        method.name
      )
    end
    local bad = Support.check {
      { Support.is_nonneg_or_nil(step.start_time_sec), where .. ": start time must be ≥ 0" },
      { Support.is_nonneg_or_nil(step.duration_sec), where .. ": duration must be ≥ 0" },
      { Support.is_nonneg_or_nil(step.target_water_g), where .. ": target water must be ≥ 0" },
      {
        Support.is_nonneg_or_nil(step.target_total_water_g),
        where .. ": total water must be ≥ 0",
      },
    }
    if bad then
      return bad
    end
  end
end

local function validate_params(param_values, method)
  local provided = {}
  for _, pv in ipairs(param_values or {}) do
    provided[pv.param_id] = pv.value
  end
  for _, p in ipairs(method.parameters) do
    if tonumber(p.required) == 1 then
      local v = provided[p.id]
      if v == nil or (type(v) == "string" and v:match("%S") == nil) then
        return string.format("%s is required for %s", p.label, method.name)
      end
    end
  end
end

local function validate(recipe, steps, param_values)
  if not Support.is_nonempty_string(recipe.title) then
    return "title is required"
  end
  local method = recipe.method_id and MethodRepo.get(recipe.method_id) or nil
  if not method then
    return "choose a brew method"
  end
  if tonumber(method.is_active) ~= 1 then
    return "that brew method is inactive"
  end

  if recipe.bean_id ~= nil and not ConfigRepo.beans.get(recipe.bean_id) then
    return "selected bean no longer exists"
  end
  if recipe.grinder_id ~= nil and not ConfigRepo.grinders.get(recipe.grinder_id) then
    return "selected grinder no longer exists"
  end

  local is_espresso = method.slug == "espresso"
  local bad = Support.check {
    { type(recipe.dose_g) == "number" and recipe.dose_g > 0, "dose must be greater than 0" },
    {
      recipe.water_g ~= nil or is_espresso,
      "total water is required",
    },
    { Support.is_nonneg_or_nil(recipe.water_g), "total water must be ≥ 0" },
    {
      recipe.water_temp_c == nil
        or (type(recipe.water_temp_c) == "number" and recipe.water_temp_c > 0),
      "water temperature must be greater than 0",
    },
    { Support.is_nonneg_or_nil(recipe.brew_time_sec), "brew time must be ≥ 0" },
    { Support.is_nonneg_or_nil(recipe.output_weight_g), "output weight must be ≥ 0" },
    { Support.is_rating_or_nil(recipe.overall_rating), "rating must be 1–5" },
  }
  if bad then
    return bad
  end
  for _, axis in ipairs(SENSORY_AXES) do
    if not Support.is_rating_or_nil(recipe[axis]) then
      return axis .. " must be 1–5"
    end
  end

  return validate_params(param_values, method) or validate_steps(steps, method)
end

function RecipeService.create(recipe, steps, param_values, flavor_tag_ids)
  recipe = recipe or {}
  local bad = validate(recipe, steps, param_values)
  if bad then
    return Support.err(bad)
  end
  return Support.from_repo(RecipeRepo.create(recipe, steps, param_values, flavor_tag_ids))
end

function RecipeService.update(id, recipe, steps, param_values, flavor_tag_ids)
  local current = RecipeRepo.get(id)
  if not current then
    return Support.err("recipe not found")
  end
  local candidate = {}
  for k, v in pairs(current) do
    candidate[k] = v
  end
  for k, v in pairs(recipe or {}) do
    candidate[k] = v
  end
  -- Steps/params default to the recipe's current set when the caller omits them.
  local check_steps = steps
  if check_steps == nil then
    check_steps = current.steps
  end
  local check_params = param_values
  if check_params == nil then
    check_params = current.parameters
  end
  local bad = validate(candidate, check_steps, check_params)
  if bad then
    return Support.err(bad)
  end
  return Support.from_repo(RecipeRepo.update(id, recipe or {}, steps, param_values, flavor_tag_ids))
end

function RecipeService.get(id)
  local recipe = RecipeRepo.get(id)
  if not recipe then
    return Support.err("recipe not found")
  end
  return Support.ok(recipe)
end

function RecipeService.list_for_index(opts)
  return Support.ok(RecipeRepo.list_for_index(opts))
end

--- Delete, unless a custom drink still uses this recipe as its base (§2.18).
function RecipeService.delete(id)
  local count = DrinkRepo.count_referencing_recipe(id)
  if count > 0 then
    return Support.err(string.format("used by %d custom drink%s", count, count == 1 and "" or "s"))
  end
  local ok, err = RecipeRepo.delete(id)
  if ok == nil then
    return Support.err(err or "database error")
  end
  if ok == false then
    return Support.err("recipe not found")
  end
  return Support.ok(true)
end

return RecipeService
