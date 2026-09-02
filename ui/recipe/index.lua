-- ui/recipe/index.lua
-- Base-recipe index (TECH_SOLUTION §1.21, §2.14). A scrolling list: three control
-- rows at the top (method filter, title search, sort) followed by the result
-- rows, each rendering `method · <rating> · N brews`. Tapping a result opens
-- ui/recipe/detail. All data comes through search_service. `favourites = true`
-- narrows to starred recipes (the navbar Favourites tab).

local Format = require("util/format")
local ListPicker = require("ui/widgets/list_picker")
local MethodService = require("services/method_service")
local Nav = require("ui/nav")
local ScreenList = require("ui/screen_list")
local SearchService = require("services/search_service")
local TextInput = require("ui/widgets/text_input")
local _ = require("gettext")

local SORT_ORDER = { "updated", "rating", "brew_count", "title" }
local SORT_LABELS = {
  updated = _("Recently updated"),
  rating = _("Rating"),
  brew_count = _("Brew count"),
  title = _("Title"),
}

local RecipeIndex = ScreenList:extend {
  name = "koffeelab_recipe_index",
  title = _("Base Coffee Recipes"),
}

function RecipeIndex:init()
  self.method_slug = nil
  self.search = ""
  self.sort = "updated"
  if self.favourites then
    self.title = _("Favourite Recipes")
  end
  local ok, methods = MethodService.list()
  self.methods = ok and methods or {}
  ScreenList.init(self)
end

function RecipeIndex:_method_label()
  if self.method_slug == nil then
    return _("All")
  end
  for _, m in ipairs(self.methods) do
    if m.slug == self.method_slug then
      return m.name
    end
  end
  return _("All")
end

local function row_note(r)
  local parts = { r.method_name or _("?") }
  local avg = tonumber(r.avg_session_rating)
  local overall = tonumber(r.overall_rating)
  if avg then
    parts[#parts + 1] = Format.rating_decimal(avg)
  elseif overall then
    parts[#parts + 1] = Format.rating_stars(overall)
  end
  local n = tonumber(r.brew_count) or 0
  parts[#parts + 1] = string.format(n == 1 and "%d brew" or "%d brews", n)
  return table.concat(parts, "  \u{00B7}  ")
end

function RecipeIndex:buildItems()
  local items = {
    {
      text = _("Method:  ") .. self:_method_label(),
      mandatory = "\u{203A}",
      _ctl = "method",
      callback = function()
        self:_pickMethod()
      end,
    },
    {
      text = _("Search:  ") .. (self.search ~= "" and self.search or _("(all)")),
      mandatory = "\u{203A}",
      _ctl = "search",
      callback = function()
        self:_editSearch()
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

  local ok, rows = SearchService.recipes {
    method_slug = self.method_slug,
    search = self.search,
    sort = self.sort,
    favorite = self.favourites or nil,
  }
  rows = ok and rows or {}
  items[#items + 1] = { text = _("Recipes"), mandatory = tostring(#rows), kind = "head" }
  if #rows == 0 then
    local unfiltered = self.method_slug == nil and self.search == ""
    local msg
    if self.favourites then
      msg = _("No favourite recipes yet. Star a recipe from its detail screen.")
    elseif unfiltered then
      msg = _("No recipes yet. Add one from the Home screen.")
    else
      msg = _("No recipes match this filter.")
    end
    items[#items + 1] = { text = msg, kind = "text" }
  end
  for _idx, r in ipairs(rows) do -- luacheck: ignore _idx
    items[#items + 1] = {
      text = r.title,
      mandatory = row_note(r),
      _recipe_id = r.id,
      callback = function()
        Nav:push(require("ui/recipe/detail"):new {
          recipe_id = r.id,
          on_changed = function()
            self:refresh()
          end,
        })
      end,
    }
  end
  return items
end

RecipeIndex._refresh = ScreenList.refresh

function RecipeIndex:_pickMethod()
  local items = { { text = _("All methods"), value = false } }
  for _, m in ipairs(self.methods) do
    items[#items + 1] = { text = m.name, value = m.slug }
  end
  ListPicker.show {
    title = _("Filter by method"),
    items = items,
    current = self.method_slug or false,
    on_select = function(value)
      self.method_slug = value or nil
      self:refresh()
    end,
  }
end

function RecipeIndex:_editSearch()
  TextInput.show {
    title = _("Search recipes by title"),
    value = self.search,
    on_ok = function(text)
      self.search = text or ""
      self:refresh()
    end,
  }
end

function RecipeIndex:_pickSort()
  local items = {}
  for _idx, key in ipairs(SORT_ORDER) do -- luacheck: ignore _idx
    items[#items + 1] = { text = SORT_LABELS[key], value = key }
  end
  ListPicker.show {
    title = _("Sort recipes by"),
    items = items,
    current = self.sort,
    on_select = function(value)
      self.sort = value
      self:refresh()
    end,
  }
end

return RecipeIndex
