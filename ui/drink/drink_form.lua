-- ui/drink/drink_form.lua
-- The custom-drink wizard (design-language §4.6). Two pages: Basics (title,
-- temperature, base recipe + amount used — the recipe output is shown so partial
-- use is explicit) and Extras (ingredients, process steps, rating, comment).
-- Ingredients / steps push their own sub-editor; everything writes into the
-- shared `draft`. Save goes through `drink_service` (validation + one
-- transaction) via `ui/drink/add_flow`.

local BaseSelect = require("ui/drink/base_select")
local Constants = require("util/constants")
local DrinkIngredients = require("ui/drink/ingredients")
local DrinkSteps = require("ui/drink/steps")
local Format = require("util/format")
local InfoMessage = require("ui/widget/infomessage")
local ListPicker = require("ui/widgets/list_picker")
local NumberInput = require("ui/widgets/number_input")
local TextInput = require("ui/widgets/text_input")
local UIManager = require("ui/uimanager")
local Wizard = require("ui/widgets/wizard")
local _ = require("gettext")

local RATING_ITEMS = {
  { text = _("Not set"), value = 0 },
  { text = "1", value = 1 },
  { text = "2", value = 2 },
  { text = "3", value = 3 },
  { text = "4", value = 4 },
  { text = "5", value = 5 },
}

local DrinkForm = Wizard:extend {
  name = "koffeelab_drink_form",
  draft = nil, -- required
  on_saved = nil, -- optional: function(drink_id)
}

function DrinkForm:init()
  local draft = assert(self.draft, "DrinkForm needs a draft")
  self.editing = draft.editing_id ~= nil
  self.wizard_title = self.editing and _("Edit Custom Drink") or _("New Custom Drink")
  self.values = draft.drink

  local basics = {
    {
      key = "title",
      label = _("Title"),
      display = function(v)
        return v.title
      end,
      edit = function(form)
        TextInput.show {
          title = _("Drink title"),
          value = form.values.title,
          hint = _("e.g. Iced Oat Latte"),
          on_ok = function(t)
            form:set("title", t ~= "" and t or nil)
          end,
        }
      end,
    },
    {
      key = "temperature_mode",
      label = _("Temperature"),
      display = function(v)
        return v.temperature_mode and Constants.TEMPERATURE_MODE_LABELS[v.temperature_mode]
      end,
      edit = function(form)
        local items = {}
        for _idx, mode in ipairs(Constants.TEMPERATURE_MODES) do -- luacheck: ignore _idx
          items[#items + 1] = { text = mode.label, value = mode.value }
        end
        ListPicker.show {
          title = _("Hot or cold?"),
          items = items,
          current = form.values.temperature_mode,
          on_select = function(v)
            form:set("temperature_mode", v)
          end,
        }
      end,
    },
    {
      key = "base_recipe_id",
      label = _("Base recipe"),
      display = function()
        return draft.base_recipe and draft.base_recipe.title or nil
      end,
      edit = function(form)
        BaseSelect.show {
          current = draft.drink.base_recipe_id,
          on_select = function(recipe)
            draft.base_recipe = recipe
            draft.drink.base_recipe_id = recipe and recipe.id or nil
            form:refreshItems()
          end,
        }
      end,
    },
    {
      key = "base_amount",
      label = _("Amount used"),
      display = function(v)
        local n = tonumber(v.base_amount)
        if n == nil then
          return nil
        end
        return (string.format("%.2f", n):gsub("%.?0+$", "")) .. " " .. (v.base_unit or "g")
      end,
      edit = function(form)
        local out = draft.base_recipe and tonumber(draft.base_recipe.output_weight_g) or nil
        NumberInput.show {
          title = _("Amount of base output used"),
          info_text = out and string.format(_("Recipe output: %s"), Format.grams(out)) or nil,
          value = tonumber(form.values.base_amount) or 0,
          min = 0,
          max = 100000,
          step = 1,
          precision = "%.1f",
          unit = form.values.base_unit or "g",
          on_ok = function(n)
            form:set("base_amount", n > 0 and n or nil)
          end,
        }
      end,
    },
  }

  local extras = {
    {
      key = "_ingredients",
      label = _("Ingredients"),
      display = function()
        local n = #draft.ingredients
        return n > 0 and string.format(_("%d ingredients"), n) or nil
      end,
      edit = function(form)
        form.nav:push(DrinkIngredients:new {
          draft = draft,
          on_change = function()
            form:refreshItems()
          end,
        })
      end,
    },
    {
      key = "_steps",
      label = _("Process steps"),
      display = function()
        local n = #draft.steps
        return n > 0 and string.format(_("%d steps"), n) or nil
      end,
      edit = function(form)
        form.nav:push(DrinkSteps:new {
          draft = draft,
          on_change = function()
            form:refreshItems()
          end,
        })
      end,
    },
    {
      key = "rating",
      label = _("Rating"),
      display = function(v)
        return v.rating and tostring(v.rating) or nil
      end,
      edit = function(form)
        ListPicker.show {
          title = _("Rating"),
          items = RATING_ITEMS,
          current = tonumber(form.values.rating) or 0,
          on_select = function(v)
            form:set("rating", (v ~= 0) and v or nil)
          end,
        }
      end,
    },
    {
      key = "comment",
      label = _("Comment"),
      display = function(v)
        return (v.comment and v.comment ~= "") and v.comment or nil
      end,
      edit = function(form)
        TextInput.show {
          title = _("Comment"),
          value = form.values.comment,
          on_ok = function(t)
            form:set("comment", t)
          end,
        }
      end,
    },
  }

  self.pages = {
    {
      title = _("Basics"),
      fields = basics,
      validate = function(v)
        if not v.title or v.title == "" then
          return _("Give the drink a title.")
        end
      end,
    },
    { title = _("Extras"), fields = extras },
  }

  Wizard.init(self)
end

function DrinkForm:on_save()
  local ok, result = require("ui/drink/add_flow").save(self.draft)
  if not ok then
    UIManager:show(InfoMessage:new { text = tostring(result), icon = "notice-warning" })
    return
  end
  if self.on_saved then
    self.on_saved(result.id)
  end
  if self.editing then
    if self.nav then
      self.nav:pop()
    else
      UIManager:close(self)
    end
  else
    local Detail = require("ui/drink/detail")
    if self.nav then
      self.nav:replace(Detail:new { drink_id = result.id })
    else
      UIManager:close(self)
    end
  end
end

return DrinkForm
