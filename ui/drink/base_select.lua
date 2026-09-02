-- ui/drink/base_select.lua
-- Base-recipe picker for the custom-drink flow (TECH_SOLUTION §2.11). A modal
-- single-select over the active recipes, each row showing the recipe output so
-- the partial-output behaviour is explicit. Data through `recipe_service`; the
-- UI never touches a repository.

local Format = require("util/format")
local InfoMessage = require("ui/widget/infomessage")
local ListPicker = require("ui/widgets/list_picker")
local RecipeService = require("services/recipe_service")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local BaseSelect = {}

local function recipe_label(r)
  local out = tonumber(r.output_weight_g)
  if out then
    return r.title .. "  —  " .. Format.grams(out)
  end
  return r.title
end

--- Show the picker.
---   BaseSelect.show{ current = recipe_id, on_select = function(recipe_row) … end }
function BaseSelect.show(opts)
  local ok, recipes = RecipeService.list_for_index { sort = "title" }
  recipes = ok and recipes or {}

  if #recipes == 0 then
    UIManager:show(InfoMessage:new {
      text = _("No base recipes yet. Add a recipe first, then build a drink on it."),
      icon = "notice-warning",
    })
    return
  end

  local items = {}
  for _idx, r in ipairs(recipes) do -- luacheck: ignore _idx
    items[#items + 1] = { text = recipe_label(r), value = r.id, _recipe = r }
  end

  ListPicker.show {
    title = _("Select Base Recipe"),
    items = items,
    current = opts.current,
    on_select = function(_, item)
      opts.on_select(item._recipe)
    end,
  }
end

return BaseSelect
