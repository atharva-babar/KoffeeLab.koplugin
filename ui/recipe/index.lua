-- ui/recipe/index.lua
-- Base-recipe index (TECH_SOLUTION §1.21, §2.14; design-language §4.3). A scrolling
-- column of recipe cards: method icon + title, method name as a caption, rating +
-- brew count on the right. Filter / Sort / Search are navbar actions that open
-- modal pickers — there are no control rows. Tapping a card opens ui/recipe/detail.
-- All data comes through search_service. `favourites = true` narrows to starred
-- recipes.

local Format = require("util/format")
local ListPicker = require("ui/widgets/list_picker")
local Methods = require("methods/init")
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
  navbar = "list",
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

-- Right-hand value: rating (session average, else overall stars) + brew count.
local function row_value(r)
  local parts = {}
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
  local ok, rows = SearchService.recipes {
    method_slug = self.method_slug,
    search = self.search,
    sort = self.sort,
    favorite = self.favourites or nil,
  }
  rows = ok and rows or {}

  local items = {
    { text = _("Recipes"), mandatory = tostring(#rows), kind = "head" },
  }
  if #rows == 0 then
    local unfiltered = self.method_slug == nil and self.search == ""
    local msg
    if self.favourites then
      msg = _("No favourite recipes yet. Star a recipe from its detail screen.")
    elseif unfiltered then
      msg = _("No recipes yet. Add one from the navbar.")
    else
      msg = _("No recipes match this filter.")
    end
    items[#items + 1] = { text = msg, kind = "text" }
  end
  for _idx, r in ipairs(rows) do -- luacheck: ignore _idx
    local method = Methods.get(r.method_slug)
    items[#items + 1] = {
      text = r.title,
      caption = r.method_name or (method and method.name) or _("?"),
      icon = method and method.icon or nil,
      mandatory = row_value(r),
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

--- Navbar verbs (design-language §3.7 `list` preset). Returns the opened modal.
function RecipeIndex:onNavAction(key)
  if key == "filter" then
    return self:_pickMethod()
  elseif key == "sort" then
    return self:_pickSort()
  elseif key == "search" then
    return self:_editSearch()
  end
end

function RecipeIndex:_pickMethod()
  local items = { { text = _("All methods"), value = false } }
  for _, m in ipairs(self.methods) do
    items[#items + 1] = { text = m.name, value = m.slug }
  end
  return ListPicker.show {
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
  return TextInput.show {
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
  return ListPicker.show {
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
