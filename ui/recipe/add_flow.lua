-- ui/recipe/add_flow.lua
-- Orchestrates the Add / Edit Recipe flow (TECH_SOLUTION §2.4, §2.17, §3.6). A
-- single in-memory `draft` is carried across every screen:
--
--   draft = {
--     recipe = { … the fixed brew_recipes columns … },   -- §1.9a
--     method = <nested method row>,                        -- drives the form
--     steps  = { { step_type = …, … }, … },
--     params = { [param_id] = value, … },                  -- method parameters
--     flavor_tag_ids = { id, … },
--     bean = <bean row or nil>,  grinder = <grinder row or nil>,  -- display only
--     editing_id = <recipe id> or nil,
--   }
--
-- Screen 1 is the method picker (ui/recipe/method_select); picking a method
-- replaces it with the method-driven form (ui/recipe/recipe_form). Edit skips
-- screen 1 and prefills the draft from `recipe_service.get`.

local ConfigService = require("services/config_service")
local InfoMessage = require("ui/widget/infomessage")
local MethodSelect = require("ui/recipe/method_select")
local MethodService = require("services/method_service")
local Nav = require("ui/nav")
local RecipeForm = require("ui/recipe/recipe_form")
local RecipeService = require("services/recipe_service")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local AddFlow = {}

-- Fixed brew_recipes columns the draft carries (§1.9a). Method-specific values
-- travel in `draft.params`, sensory axes are set on `draft.recipe` too.
AddFlow.RECIPE_KEYS = {
  "title",
  "method_id",
  "bean_id",
  "grinder_id",
  "grind_value",
  "dose_g",
  "water_g",
  "water_temp_c",
  "brew_time_sec",
  "output_weight_g",
  "acidity",
  "sweetness",
  "strength",
  "body",
  "brightness",
  "overall_rating",
  "notes",
}

local function warn(msg)
  UIManager:show(InfoMessage:new { text = tostring(msg), icon = "notice-warning" })
end

-- SQLite INTEGER columns arrive as int64 cdata; the service validators (and the
-- widgets) work in plain Lua numbers, so normalise on the way into the draft.
local function plain(v)
  if type(v) == "cdata" then
    return tonumber(v)
  end
  return v
end

--- Start the Add Recipe flow. `opts.on_saved(recipe_id)` fires after a successful
--- save (e.g. to refresh an index).
function AddFlow.start(opts)
  opts = opts or {}
  Nav:push(MethodSelect:new {
    on_pick = function(_, method)
      local draft = {
        recipe = { method_id = method.id, notes = "" },
        method = method,
        steps = {},
        params = {},
        flavor_tag_ids = {},
      }
      Nav:replace(RecipeForm:new { draft = draft, on_saved = opts.on_saved })
    end,
  })
end

--- Edit an existing recipe: prefill the draft and push the same form. `opts.on_saved`
--- fires after the update (the caller — usually the detail page — refreshes itself).
function AddFlow.edit(recipe_id, opts)
  opts = opts or {}
  local ok, recipe = RecipeService.get(recipe_id)
  if not ok then
    warn(recipe)
    return
  end
  local mok, method = MethodService.get(recipe.method_id)
  if not mok then
    warn(method)
    return
  end

  local draft = {
    recipe = {},
    method = method,
    steps = {},
    params = {},
    flavor_tag_ids = {},
    editing_id = recipe_id,
  }
  for _idx, key in ipairs(AddFlow.RECIPE_KEYS) do -- luacheck: ignore _idx
    draft.recipe[key] = plain(recipe[key])
  end
  for _idx, step in ipairs(recipe.steps or {}) do -- luacheck: ignore _idx
    local copy = {}
    for k, v in pairs(step) do
      copy[k] = plain(v)
    end
    draft.steps[#draft.steps + 1] = copy
  end
  for _idx, pv in ipairs(recipe.parameters or {}) do -- luacheck: ignore _idx
    draft.params[tonumber(pv.param_id)] = pv.value
  end
  for _idx, tag in ipairs(recipe.flavor_tags or {}) do -- luacheck: ignore _idx
    draft.flavor_tag_ids[#draft.flavor_tag_ids + 1] = tag.id
  end
  if recipe.bean_id then
    local bok, bean = ConfigService.beans.get(recipe.bean_id)
    draft.bean = bok and bean or nil
  end
  if recipe.grinder_id then
    local gok, grinder = ConfigService.grinders.get(recipe.grinder_id)
    draft.grinder = gok and grinder or nil
  end

  Nav:push(RecipeForm:new { draft = draft, on_saved = opts.on_saved })
end

--- Assemble the service payload from a draft (shared by create and update).
function AddFlow.payload(draft)
  local recipe = {}
  for _idx, key in ipairs(AddFlow.RECIPE_KEYS) do -- luacheck: ignore _idx
    recipe[key] = draft.recipe[key]
  end
  if recipe.notes == nil then
    recipe.notes = ""
  end

  local param_values = {}
  for _idx, param in ipairs(draft.method.parameters or {}) do -- luacheck: ignore _idx
    local v = draft.params[tonumber(param.id)]
    if v ~= nil and v ~= "" then
      param_values[#param_values + 1] = { param_id = param.id, value = tostring(v) }
    end
  end

  return recipe, draft.steps, param_values, draft.flavor_tag_ids
end

--- Persist the draft. Returns `ok, recipe_or_error`.
function AddFlow.save(draft)
  local recipe, steps, param_values, tag_ids = AddFlow.payload(draft)
  if draft.editing_id then
    return RecipeService.update(draft.editing_id, recipe, steps, param_values, tag_ids)
  end
  return RecipeService.create(recipe, steps, param_values, tag_ids)
end

return AddFlow
