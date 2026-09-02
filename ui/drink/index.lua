-- ui/drink/index.lua
-- Custom-drink index (TECH_SOLUTION §2.14; design-language §4.3). A scrolling
-- column of drink cards: tumbler icon + title, base recipe as a caption, rating +
-- Hot/Cold on the right. Filter (temperature / ingredient), Sort and Search are
-- navbar actions that open modal pickers. Tapping a card opens ui/drink/detail.
-- Data through drink_service / search_service.

local ButtonDialog = require("ui/widget/buttondialog")
local Constants = require("util/constants")
local ConfigService = require("services/config_service")
local Format = require("util/format")
local ListPicker = require("ui/widgets/list_picker")
local Nav = require("ui/nav")
local ScreenList = require("ui/screen_list")
local SearchService = require("services/search_service")
local TextInput = require("ui/widgets/text_input")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local SORT_ORDER = { "updated", "rating", "title" }
local SORT_LABELS = {
  updated = _("Recently updated"),
  rating = _("Rating"),
  title = _("Title"),
}

local DrinkIndex = ScreenList:extend {
  name = "koffeelab_drink_index",
  title = _("Custom Drinks"),
  navbar = "list",
}

function DrinkIndex:init()
  self.temperature_mode = nil -- nil | "hot" | "cold"
  self.ingredient_id = nil
  self.search = ""
  self.sort = "updated"
  local ok, ingredients = ConfigService.ingredients.list {}
  self.ingredients = ok and ingredients or {}
  ScreenList.init(self)
end

local function row_value(d)
  local parts = {}
  local rating = tonumber(d.rating)
  if rating then
    parts[#parts + 1] = Format.rating_stars(rating)
  end
  parts[#parts + 1] = Constants.TEMPERATURE_MODE_LABELS[d.temperature_mode] or d.temperature_mode
  return table.concat(parts, "  \u{00B7}  ")
end

function DrinkIndex:buildItems()
  local ok, rows = SearchService.drinks {
    temperature_mode = self.temperature_mode,
    ingredient_id = self.ingredient_id,
    search = self.search,
    sort = self.sort,
  }
  rows = ok and rows or {}

  local items = {
    { text = _("Drinks"), mandatory = tostring(#rows), kind = "head" },
  }
  if #rows == 0 then
    local unfiltered = self.temperature_mode == nil
      and self.ingredient_id == nil
      and self.search == ""
    items[#items + 1] = {
      text = unfiltered and _("No custom drinks yet. Add one from the navbar.")
        or _("No drinks match this filter."),
      kind = "text",
    }
  end
  for _idx, d in ipairs(rows) do -- luacheck: ignore _idx
    items[#items + 1] = {
      text = d.title,
      caption = d.base_recipe_title or _("?"),
      icon = "custom_drink",
      mandatory = row_value(d),
      _drink_id = d.id,
      callback = function()
        Nav:push(require("ui/drink/detail"):new {
          drink_id = d.id,
          on_changed = function()
            self:refresh()
          end,
        })
      end,
    }
  end
  return items
end

DrinkIndex._refresh = ScreenList.refresh

--- Navbar verbs (design-language §3.7 `list` preset). Returns the opened modal.
function DrinkIndex:onNavAction(key)
  if key == "filter" then
    return self:_pickFilter()
  elseif key == "sort" then
    return self:_pickSort()
  elseif key == "search" then
    return self:_editSearch()
  end
end

-- Drinks have two filter axes; offer the choice, then the matching picker.
function DrinkIndex:_pickFilter()
  local dialog
  dialog = ButtonDialog:new {
    title = _("Filter drinks"),
    title_align = "center",
    buttons = {
      {
        {
          text = _("By temperature"),
          callback = function()
            UIManager:close(dialog)
            self:_pickTemperature()
          end,
        },
      },
      {
        {
          text = _("By ingredient"),
          callback = function()
            UIManager:close(dialog)
            self:_pickIngredient()
          end,
        },
      },
    },
  }
  UIManager:show(dialog)
  return dialog
end

function DrinkIndex:_editSearch()
  return TextInput.show {
    title = _("Search drinks by title"),
    value = self.search,
    on_ok = function(text)
      self.search = text or ""
      self:refresh()
    end,
  }
end

function DrinkIndex:_pickTemperature()
  return ListPicker.show {
    title = _("Filter by temperature"),
    items = {
      { text = _("All"), value = false },
      { text = Constants.TEMPERATURE_MODE_LABELS.hot, value = "hot" },
      { text = Constants.TEMPERATURE_MODE_LABELS.cold, value = "cold" },
    },
    current = self.temperature_mode or false,
    on_select = function(value)
      self.temperature_mode = value or nil
      self:refresh()
    end,
  }
end

function DrinkIndex:_pickIngredient()
  local items = { { text = _("All ingredients"), value = false } }
  for _idx, ing in ipairs(self.ingredients) do -- luacheck: ignore _idx
    items[#items + 1] = { text = ing.name, value = ing.id }
  end
  return ListPicker.show {
    title = _("Filter by ingredient"),
    items = items,
    current = self.ingredient_id or false,
    on_select = function(value)
      self.ingredient_id = value or nil
      self:refresh()
    end,
  }
end

function DrinkIndex:_pickSort()
  local items = {}
  for _idx, key in ipairs(SORT_ORDER) do -- luacheck: ignore _idx
    items[#items + 1] = { text = SORT_LABELS[key], value = key }
  end
  return ListPicker.show {
    title = _("Sort drinks by"),
    items = items,
    current = self.sort,
    on_select = function(value)
      self.sort = value
      self:refresh()
    end,
  }
end

return DrinkIndex
