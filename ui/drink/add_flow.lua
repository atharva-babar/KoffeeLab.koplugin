-- ui/drink/add_flow.lua
-- Orchestrates the Add / Edit Custom Drink flow (TECH_SOLUTION §2.11, §3.8). A
-- single in-memory `draft` is carried across every screen:
--
--   draft = {
--     drink = { title, temperature_mode, base_recipe_id, base_amount, base_unit,
--               rating, comment },
--     base_recipe = <recipe row: id, title, output_weight_g> or nil,  -- display
--     ingredients = { { ingredient_id, ingredient_name, amount, unit }, … },
--     steps       = { { instruction, note }, … },
--     editing_id  = <drink id> or nil,
--   }
--
-- Screen 1 is the hot/cold picker (a modal ListPicker); choosing a mode pushes
-- the drink form (ui/drink/drink_form). Edit skips the picker and prefills the
-- draft from `drink_service.get`.

local ConfigService = require("services/config_service")
local Constants = require("util/constants")
local DrinkForm = require("ui/drink/drink_form")
local DrinkService = require("services/drink_service")
local InfoMessage = require("ui/widget/infomessage")
local ListPicker = require("ui/widgets/list_picker")
local Nav = require("ui/nav")
local RecipeService = require("services/recipe_service")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local AddFlow = {}

-- Fixed custom_drinks columns the draft carries (§1.16).
AddFlow.DRINK_KEYS = {
  "title",
  "temperature_mode",
  "base_recipe_id",
  "base_amount",
  "base_unit",
  "rating",
  "comment",
}

local function warn(msg)
  UIManager:show(InfoMessage:new { text = tostring(msg), icon = "notice-warning" })
end

-- SQLite INTEGER columns arrive as int64 cdata; the service validators work in
-- plain Lua numbers, so normalise on the way into the draft.
local function plain(v)
  if type(v) == "cdata" then
    return tonumber(v)
  end
  return v
end

--- Start the Add Custom Drink flow. `opts.on_saved(drink_id)` fires after a
--- successful save (e.g. to refresh an index).
function AddFlow.start(opts)
  opts = opts or {}
  ListPicker.show {
    title = _("Hot or cold?"),
    items = {
      { text = Constants.TEMPERATURE_MODE_LABELS.hot, value = "hot" },
      { text = Constants.TEMPERATURE_MODE_LABELS.cold, value = "cold" },
    },
    on_select = function(mode)
      local draft = {
        drink = { temperature_mode = mode, base_unit = "g", comment = "" },
        ingredients = {},
        steps = {},
      }
      Nav:push(DrinkForm:new { draft = draft, on_saved = opts.on_saved })
    end,
  }
end

--- Edit an existing drink: prefill the draft and push the same form. `opts.on_saved`
--- fires after the update (the caller — usually the detail page — refreshes itself).
function AddFlow.edit(drink_id, opts)
  opts = opts or {}
  local ok, drink = DrinkService.get(drink_id)
  if not ok then
    warn(drink)
    return
  end

  local draft = {
    drink = {},
    ingredients = {},
    steps = {},
    editing_id = drink_id,
  }
  for _idx, key in ipairs(AddFlow.DRINK_KEYS) do -- luacheck: ignore _idx
    draft.drink[key] = plain(drink[key])
  end
  for _idx, ing in ipairs(drink.ingredients or {}) do -- luacheck: ignore _idx
    draft.ingredients[#draft.ingredients + 1] = {
      ingredient_id = plain(ing.ingredient_id),
      ingredient_name = ing.ingredient_name,
      amount = plain(ing.amount),
      unit = ing.unit,
    }
  end
  for _idx, step in ipairs(drink.steps or {}) do -- luacheck: ignore _idx
    draft.steps[#draft.steps + 1] = {
      instruction = step.instruction or "",
      note = step.note or "",
    }
  end
  if drink.base_recipe then
    draft.base_recipe = {
      id = plain(drink.base_recipe.id),
      title = drink.base_recipe.title,
      output_weight_g = plain(drink.base_recipe.output_weight_g),
    }
  end

  Nav:push(DrinkForm:new { draft = draft, on_saved = opts.on_saved })
end

--- Assemble the service payload from a draft (shared by create and update).
function AddFlow.payload(draft)
  local drink = {}
  for _idx, key in ipairs(AddFlow.DRINK_KEYS) do -- luacheck: ignore _idx
    drink[key] = draft.drink[key]
  end
  drink.comment = drink.comment or ""
  drink.base_unit = (drink.base_unit ~= nil and drink.base_unit ~= "") and drink.base_unit or "g"
  if drink.rating == 0 then
    drink.rating = nil
  end

  local ingredients = {}
  for _idx, ing in ipairs(draft.ingredients or {}) do -- luacheck: ignore _idx
    ingredients[#ingredients + 1] = {
      ingredient_id = ing.ingredient_id,
      amount = ing.amount,
      unit = (ing.unit ~= nil and ing.unit ~= "") and ing.unit or "g",
    }
  end

  local steps = {}
  for _idx, step in ipairs(draft.steps or {}) do -- luacheck: ignore _idx
    steps[#steps + 1] = { instruction = step.instruction or "", note = step.note or "" }
  end

  return drink, ingredients, steps
end

--- Persist the draft. Returns `ok, drink_or_error`.
function AddFlow.save(draft)
  local drink, ingredients, steps = AddFlow.payload(draft)
  if draft.editing_id then
    return DrinkService.update(draft.editing_id, drink, ingredients, steps)
  end
  return DrinkService.create(drink, ingredients, steps)
end

--- Active base recipes for the picker (title + output). Returns an array of rows.
function AddFlow.base_recipes()
  local ok, rows = RecipeService.list_for_index { sort = "title" }
  return ok and rows or {}
end

--- Active ingredients for the ingredient picker. Returns an array of rows.
function AddFlow.ingredients()
  local ok, rows = ConfigService.ingredients.list {}
  return ok and rows or {}
end

return AddFlow
