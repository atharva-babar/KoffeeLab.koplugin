-- ui/drink/index.lua
-- Custom-drink index (TECH_SOLUTION §2.14). A scrolling list: three control rows
-- (temperature filter, ingredient filter, sort) followed by the result rows
-- rendering `base recipe · <rating> · Hot/Cold`. Tapping a result opens
-- ui/drink/detail. Data through drink_service / search_service.

local Constants = require("util/constants")
local ConfigService = require("services/config_service")
local Format = require("util/format")
local ListPicker = require("ui/widgets/list_picker")
local Nav = require("ui/nav")
local ScreenList = require("ui/screen_list")
local SearchService = require("services/search_service")
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
}

function DrinkIndex:init()
  self.temperature_mode = nil -- nil | "hot" | "cold"
  self.ingredient_id = nil
  self.sort = "updated"
  local ok, ingredients = ConfigService.ingredients.list {}
  self.ingredients = ok and ingredients or {}
  ScreenList.init(self)
end

function DrinkIndex:_temp_label()
  return self.temperature_mode and Constants.TEMPERATURE_MODE_LABELS[self.temperature_mode]
    or _("All")
end

function DrinkIndex:_ingredient_label()
  if self.ingredient_id == nil then
    return _("All")
  end
  for _idx, ing in ipairs(self.ingredients) do -- luacheck: ignore _idx
    if ing.id == self.ingredient_id then
      return ing.name
    end
  end
  return _("All")
end

local function row_note(d)
  local parts = { d.base_recipe_title or _("?") }
  local rating = tonumber(d.rating)
  if rating then
    parts[#parts + 1] = Format.rating_stars(rating)
  end
  parts[#parts + 1] = Constants.TEMPERATURE_MODE_LABELS[d.temperature_mode] or d.temperature_mode
  return table.concat(parts, "  \u{00B7}  ")
end

function DrinkIndex:buildItems()
  local items = {
    {
      text = _("Temperature:  ") .. self:_temp_label(),
      mandatory = "\u{203A}",
      _ctl = "temperature",
      callback = function()
        self:_pickTemperature()
      end,
    },
    {
      text = _("Ingredient:  ") .. self:_ingredient_label(),
      mandatory = "\u{203A}",
      _ctl = "ingredient",
      callback = function()
        self:_pickIngredient()
      end,
    },
    {
      text = _("Sort:  ") .. SORT_LABELS[self.sort],
      mandatory = "\u{203A}",
      _ctl = "sort",
      callback = function()
        self:_pickSort()
      end,
    },
  }

  local ok, rows = SearchService.drinks {
    temperature_mode = self.temperature_mode,
    ingredient_id = self.ingredient_id,
    sort = self.sort,
  }
  rows = ok and rows or {}
  items[#items + 1] = { text = _("Drinks"), mandatory = tostring(#rows), kind = "head" }
  if #rows == 0 then
    local unfiltered = self.temperature_mode == nil and self.ingredient_id == nil
    items[#items + 1] = {
      text = unfiltered and _("No custom drinks yet. Add one from the Home screen.")
        or _("No drinks match this filter."),
      kind = "text",
    }
  end
  for _idx, d in ipairs(rows) do -- luacheck: ignore _idx
    items[#items + 1] = {
      text = d.title,
      mandatory = row_note(d),
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

function DrinkIndex:_pickTemperature()
  ListPicker.show {
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
  ListPicker.show {
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
  ListPicker.show {
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
