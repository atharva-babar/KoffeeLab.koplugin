-- services/recipe_service.lua
-- Recipe validation (driven by the static method definition) and the delete
-- guard (a recipe used by a custom drink cannot be deleted). Persistence is one
-- transaction in the repo.

local RecipeRepo = require("db/repo/recipe")
local ConfigRepo = require("db/repo/config")
local DrinkRepo = require("db/repo/drink")
local Methods = require("methods/init")
local Support = require("services/support")

local RecipeService = {}

local SENSORY_AXES = { "acidity", "sweetness", "strength", "body", "brightness" }

local FIELD_COLUMN = {
  dose = "dose_g",
  water = "water_g",
  water_temp = "water_temp_c",
  brew_time = "brew_time_sec",
  output = "output_weight_g",
}

local function validate_fields(recipe, method)
  for name, spec in pairs(method.fields or {}) do
    local col = FIELD_COLUMN[name]
    local v = col and recipe[col]
    if not spec.hidden then
      if spec.required and (type(v) ~= "number" or v <= 0) then
        return string.format("%s is required", spec.label or name)
      elseif v ~= nil and not Support.is_nonneg_or_nil(v) then
        return string.format("%s must be \u{2265} 0", spec.label or name)
      end
    end
  end
  if not Support.is_nonneg_or_nil(recipe.brew_time_sec) then
    return "brew time must be \u{2265} 0"
  end
  if
    recipe.water_temp_c ~= nil
    and not (type(recipe.water_temp_c) == "number" and recipe.water_temp_c > 0)
  then
    return "water temperature must be greater than 0"
  end
end

local function validate_spec(spec, method)
  spec = spec or {}
  for _, p in ipairs(method.params or {}) do
    local v = spec[p.key]
    local present = v ~= nil and v ~= ""
    if p.required and not present then
      return string.format("%s is required", p.label)
    end
    if present then
      if p.type == "enum" then
        local ok = false
        for _, opt in ipairs(p.options) do
          if opt == v then
            ok = true
          end
        end
        if not ok then
          return string.format("%s: '%s' is not a valid choice", p.label, tostring(v))
        end
      elseif p.type == "number" or p.type == "duration" then
        if type(v) ~= "number" then
          return string.format("%s must be a number", p.label)
        end
        if p.min and v < p.min then
          return string.format("%s must be \u{2265} %s", p.label, p.min)
        end
        if p.max and v > p.max then
          return string.format("%s must be \u{2264} %s", p.label, p.max)
        end
      end
    end
  end
end

local function validate_steps(steps, method)
  local allowed = {}
  for _, t in ipairs(method.steps and method.steps.types or {}) do
    allowed[t] = true
  end
  for i, step in ipairs(steps or {}) do
    local where = "step " .. i
    if not allowed[step.step_type] then
      return string.format(
        "%s: '%s' is not a step for %s",
        where,
        tostring(step.step_type),
        method.name
      )
    end
    if not Support.is_nonneg_or_nil(step.start_time) then
      return where .. ": start time must be \u{2265} 0"
    end
    if not Support.is_nonneg_or_nil(step.water) then
      return where .. ": water must be \u{2265} 0"
    end
  end
end

local function validate(recipe, steps, spec)
  if not Support.is_nonempty_string(recipe.title) then
    return "title is required"
  end
  local method = Methods.get(recipe.method_slug)
  if not method then
    return "choose a brew method"
  end
  if recipe.bean_id ~= nil and not ConfigRepo.beans.get(recipe.bean_id) then
    return "selected bean no longer exists"
  end
  if recipe.grinder_id ~= nil and not ConfigRepo.grinders.get(recipe.grinder_id) then
    return "selected grinder no longer exists"
  end
  for _, axis in ipairs(SENSORY_AXES) do
    if not Support.is_rating_or_nil(recipe[axis]) then
      return axis .. " must be 1\u{2013}5"
    end
  end
  if not Support.is_rating_or_nil(recipe.overall_rating) then
    return "rating must be 1\u{2013}5"
  end
  return validate_fields(recipe, method)
    or validate_spec(spec, method)
    or validate_steps(steps, method)
end

local function repo_payload(recipe, steps, spec)
  local out = {}
  for k, v in pairs(recipe or {}) do
    out[k] = v
  end
  if out.notes == nil then
    out.notes = ""
  end
  if out.output_note == nil then
    out.output_note = ""
  end
  out.spec = spec or {}
  out.steps = steps or {}
  return out
end

function RecipeService.create(recipe, steps, spec, flavor_tag_ids)
  recipe = recipe or {}
  local bad = validate(recipe, steps, spec)
  if bad then
    return Support.err(bad)
  end
  return Support.from_repo(RecipeRepo.create(repo_payload(recipe, steps, spec), flavor_tag_ids))
end

function RecipeService.update(id, recipe, steps, spec, flavor_tag_ids)
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
  local check_steps = steps == nil and current.steps or steps
  local check_spec = spec == nil and current.spec or spec
  local bad = validate(candidate, check_steps, check_spec)
  if bad then
    return Support.err(bad)
  end
  local payload = repo_payload(recipe or {}, steps, spec)
  if steps == nil then
    payload.steps = nil
  end
  if spec == nil then
    payload.spec = nil
  end
  return Support.from_repo(RecipeRepo.update(id, payload, flavor_tag_ids))
end

function RecipeService.get(id)
  local recipe = RecipeRepo.get(id)
  if not recipe then
    return Support.err("recipe not found")
  end
  recipe.method = Methods.get(recipe.method_slug)
  recipe.method_name = recipe.method and recipe.method.name or recipe.method_slug
  return Support.ok(recipe)
end

function RecipeService.list_for_index(opts)
  local rows = RecipeRepo.list_for_index(opts)
  for _, r in ipairs(rows) do
    local m = Methods.get(r.method_slug)
    r.method_name = m and m.name or r.method_slug
  end
  return Support.ok(rows)
end

function RecipeService.set_favorite(id, favorite)
  return Support.from_repo(RecipeRepo.set_favorite(id, favorite))
end

--- Delete, unless a custom drink still uses this recipe as its base.
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
