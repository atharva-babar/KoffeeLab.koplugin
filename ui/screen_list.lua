-- ui/screen_list.lua
-- Base for the full-screen list screens: a ScreenBase (so hardware Back / swipe
-- south / multiswipe / chevron all reach Nav:pop, plus the optional bottom
-- navbar) wrapping a ui/widgets/scroll_list — a scrolling list with no
-- pagination bar.
--
-- A subclass implements `buildItems()` returning an array of row tables:
--   { text = "Dose", mandatory = "18 g", callback = fn }   -- tappable row
--   { text = "Steps", mandatory = "3", kind = "head" }      -- section header
--   { text = "long wrapped note", kind = "text" }           -- inert body text
-- Any extra `_field` keys are preserved on `self.item_table` for callers/specs.
--
-- `self.item_table` holds the raw rows; `onMenuChoice(row)` runs `row.callback`;
-- `refresh()` rebuilds and repaints once.

local ScreenBase = require("ui/screen_base")
local ScrollList = require("ui/widgets/scroll_list")

local ScreenList = ScreenBase:extend {
  name = "koffeelab_screen_list",
}

function ScreenList:getContentWidget()
  self.item_table = self:buildItems() or {}
  self.list = ScrollList:new {
    width = self.screen_w,
    height = self.content_height,
    show_parent = self,
    items = self:_toRows(self.item_table),
  }
  return self.list
end

function ScreenList:_toRows(items)
  local rows = {}
  for _, it in ipairs(items) do
    local kind = it.kind
    if it._head then
      kind = "head"
    end
    local row = { text = it.text, mandatory = it.mandatory, kind = kind }
    if not kind and not it._inert and it.callback then
      row.on_tap = function()
        it.callback()
      end
    end
    rows[#rows + 1] = row
  end
  return rows
end

--- Subclasses override. Returns the row array (see file header).
function ScreenList:buildItems()
  return {}
end

--- Run a row's callback (kept for parity with the old Menu API).
function ScreenList:onMenuChoice(row)
  if row and row.callback then
    row.callback()
  end
  return true
end

--- Rebuild the list from buildItems() and repaint once.
function ScreenList:refresh()
  if not self.list then
    return
  end
  self.item_table = self:buildItems() or {}
  self.list:setItems(self:_toRows(self.item_table))
end

return ScreenList
