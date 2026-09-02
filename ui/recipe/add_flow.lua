-- ui/recipe/add_flow.lua
-- Orchestrates Add / Edit Recipe. One in-memory `draft` travels every screen:
--   draft = {
--     recipe = { ...shared brew_recipes columns... },
--     method = <static def from methods/>,
--     steps  = { { step_type, start_time, water, note }, ... },
--     spec   = { [param_key] = value },
--     flavor_tag_ids = { id, ... },
--     bean, grinder = <rows, display only>,
--     editing_id = <recipe id> or nil,
--   }

local ConfigService = require("services/config_service")
local InfoMessage = require("ui/widget/infomessage")
local MethodSelect = require("ui/recipe/method_select")
local Methods = require("methods/init")
local Nav = require("ui/nav")
local RecipeForm = require("ui/recipe/recipe_form")
local RecipeService = require("services/recipe_service")
local UIManager = require("ui/uimanager")

local AddFlow = {}

AddFlow.RECIPE_KEYS = {
  "title",
  "method_slug",
  "bean_id",
  "grinder_id",
  "grind_value",
  "dose_g",
  "water_g",
  "water_temp_c",
  "brew_time_sec",
  "output_weight_g",
  "output_note",
  "acidity",
  "sweetness",
  "strength",
  "body",
  "brightness",
  "overall_rating",
  "notes",
  "is_favorite",
}

local function warn(msg)
  UIManager:show(InfoMessage:new { text = tostring(msg), icon = "notice-warning" })
end

-- SQLite INTEGER columns arrive as int64 cdata; the validators and widgets work
-- in plain Lua numbers, so normalise everything on the way into the draft.
local function plain(v)
  if type(v) == "cdata" then
    return tonumber(v)
  end
  return v
end

local function new_draft(method)
  local spec = {}
  for _, p in ipairs(method.params or {}) do
    if p.default ~= nil then
      spec[p.key] = p.default
    end
  end
  return {
    recipe = { method_slug = method.slug, notes = "" },
    method = method,
    steps = {},
    spec = spec,
    flavor_tag_ids = {},
  }
end

function AddFlow.start(opts)
  opts = opts or {}
  Nav:push(MethodSelect:new {
    on_pick = function(_, method)
      Nav:replace(RecipeForm:new { draft = new_draft(method), on_saved = opts.on_saved })
    end,
  })
end

function AddFlow.edit(recipe_id, opts)
  opts = opts or {}
  local ok, recipe = RecipeService.get(recipe_id)
  if not ok then
    warn(recipe)
    return
  end
  local method = Methods.get(recipe.method_slug)
  if not method then
    warn("unknown brew method")
    return
  end

  local draft = {
    recipe = {},
    method = method,
    steps = {},
    spec = {},
    flavor_tag_ids = {},
    editing_id = recipe_id,
  }
  for _, key in ipairs(AddFlow.RECIPE_KEYS) do
    draft.recipe[key] = plain(recipe[key])
  end
  for _, step in ipairs(recipe.steps or {}) do
    local copy = {}
    for k, v in pairs(step) do
      copy[k] = plain(v)
    end
    draft.steps[#draft.steps + 1] = copy
  end
  for k, v in pairs(recipe.spec or {}) do
    draft.spec[k] = plain(v)
  end
  for _, tag in ipairs(recipe.flavor_tags or {}) do
    draft.flavor_tag_ids[#draft.flavor_tag_ids + 1] = plain(tag.id)
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

function AddFlow.payload(draft)
  local recipe = {}
  for _, key in ipairs(AddFlow.RECIPE_KEYS) do
    recipe[key] = draft.recipe[key]
  end
  recipe.notes = recipe.notes or ""
  recipe.output_note = recipe.output_note or ""

  local spec = {}
  for _, p in ipairs(draft.method.params or {}) do
    local v = draft.spec[p.key]
    if v ~= nil and v ~= "" then
      spec[p.key] = v
    end
  end

  return recipe, draft.steps, spec, draft.flavor_tag_ids
end

function AddFlow.save(draft)
  local recipe, steps, spec, tag_ids = AddFlow.payload(draft)
  if draft.editing_id then
    return RecipeService.update(draft.editing_id, recipe, steps, spec, tag_ids)
  end
  return RecipeService.create(recipe, steps, spec, tag_ids)
end

return AddFlow
