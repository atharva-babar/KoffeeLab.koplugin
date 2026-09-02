-- ui/recipe/index.lua
-- Base-recipe index (TECH_SOLUTION §1.21, §2.14). One full-screen Menu: three
-- control rows at the top (method filter, title search, sort) followed by the
-- result rows, each rendering `method · <rating> · N brews`. Tapping a result
-- opens ui/recipe/detail. All data comes through search_service — no SQL here.
-- Changing a control repaints the list once (e-ink safe — §2.1).

local Format = require("util/format")
local ListPicker = require("ui/widgets/list_picker")
local Menu = require("ui/widget/menu")
local MethodService = require("services/method_service")
local SearchService = require("services/search_service")
local TextInput = require("ui/widgets/text_input")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local SORT_ORDER = { "updated", "rating", "brew_count", "title" }
local SORT_LABELS = {
  updated = _("Recently updated"),
  rating = _("Rating"),
  brew_count = _("Brew count"),
  title = _("Title"),
}

local RecipeIndex = Menu:extend {
  name = "koffeelab_recipe_index",
  covers_fullscreen = true,
  is_borderless = true,
  is_popout = false,
  is_enable_shortcut = false,
  with_bottom_line = true,
  title_bar_left_icon = "chevron.left",
  title = _("Base Coffee Recipes"),
}

function RecipeIndex:init()
  self.method_id = nil
  self.search = ""
  self.sort = "updated"
  local ok, methods = MethodService.list {}
  self.methods = ok and methods or {}
  self.item_table = self:_items()
  Menu.init(self)
end

function RecipeIndex:_method_label()
  if self.method_id == nil then
    return _("All")
  end
  for _idx, m in ipairs(self.methods) do -- luacheck: ignore _idx
    if m.id == self.method_id then
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

function RecipeIndex:_items()
  local items = {
    { text = _("Method:  ") .. self:_method_label(), mandatory = "\u{203A}", _ctl = "method" },
    {
      text = _("Search:  ") .. (self.search ~= "" and self.search or _("(all)")),
      mandatory = "\u{203A}",
      _ctl = "search",
    },
    { text = _("Sort:  ") .. SORT_LABELS[self.sort], mandatory = "\u{203A}", _ctl = "sort" },
  }

  local ok, rows = SearchService.recipes {
    method_id = self.method_id,
    search = self.search,
    sort = self.sort,
  }
  rows = ok and rows or {}
  items[#items + 1] = { text = _("Recipes"), mandatory = tostring(#rows), _head = true }
  if #rows == 0 then
    items[#items + 1] = { text = _("  No recipes match."), _inert = true }
  end
  for _idx, r in ipairs(rows) do -- luacheck: ignore _idx
    items[#items + 1] = { text = r.title, mandatory = row_note(r), _recipe_id = r.id }
  end
  return items
end

function RecipeIndex:_refresh()
  local keep = math.max(1, ((self.page or 1) - 1) * (self.perpage or 1) + 1)
  self:switchItemTable(self.title, self:_items(), keep)
end

function RecipeIndex:_pickMethod()
  local items = { { text = _("All methods"), value = false } }
  for _idx, m in ipairs(self.methods) do -- luacheck: ignore _idx
    items[#items + 1] = { text = m.name, value = m.id }
  end
  ListPicker.show {
    title = _("Filter by method"),
    items = items,
    current = self.method_id or false,
    on_select = function(value)
      self.method_id = value or nil
      self:_refresh()
    end,
  }
end

function RecipeIndex:_editSearch()
  TextInput.show {
    title = _("Search recipes by title"),
    value = self.search,
    on_ok = function(text)
      self.search = text or ""
      self:_refresh()
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
      self:_refresh()
    end,
  }
end

function RecipeIndex:onMenuChoice(item)
  if item._inert or item._head then
    return true
  end
  if item._ctl == "method" then
    self:_pickMethod()
  elseif item._ctl == "search" then
    self:_editSearch()
  elseif item._ctl == "sort" then
    self:_pickSort()
  elseif item._recipe_id then
    self.nav:push(require("ui/recipe/detail"):new {
      recipe_id = item._recipe_id,
      on_changed = function()
        self:_refresh()
      end,
    })
  end
  return true
end

function RecipeIndex:_back()
  if self.nav then
    self.nav:pop()
  else
    UIManager:close(self)
  end
  return true
end

RecipeIndex.onClose = RecipeIndex._back
RecipeIndex.onLeftButtonTap = RecipeIndex._back

return RecipeIndex
