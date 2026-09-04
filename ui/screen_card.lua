-- ui/screen_card.lua
-- Base for the v2 card screens (recipe / drink detail, the wizard, stopwatch,
-- index root): a ScreenBase with `scroll = true` wrapping a centred vertical
-- stack of Cards / SectionCards / CardRows.
--
-- A subclass implements `buildCards()` returning an ordered array of widgets
-- (each sized to `self.card_w`). ScreenCard frames them with `pad.page` top and
-- bottom and `gap` between, centres the column (capped at MAX_PAGE_W so it stays
-- readable on a large panel), keeps a flat `self.cards` for specs, and
-- `refresh()` rebuilds + repaints once.
--
--   local Detail = ScreenCard:extend{ name = "koffeelab_recipe_detail" }
--   function Detail:buildCards()
--     return { SectionCard:new{ width = self.card_w, title = ..., body = ... } }
--   end

local Design = require("ui/design")
local Device = require("device")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ScreenBase = require("ui/screen_base")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Screen = Device.screen

-- Cap the content column so cards do not stretch edge-to-edge on a big screen.
local MAX_PAGE_W = 600

local ScreenCard = ScreenBase:extend {
  name = "koffeelab_screen_card",
  scroll = true,
}

function ScreenCard:getContentWidget()
  self.page_w = math.min(self.screen_w, Screen:scaleBySize(MAX_PAGE_W))
  self.card_w = self.page_w - 2 * Design.pad.page

  -- A width-pinned, centred column. The ScrollableContainer must see the real
  -- content height, so this is a plain VerticalGroup (never a fixed-dimen
  -- container, which would make it think the content always fits). The first
  -- child pins the width to the full viewport so `align = "center"` works.
  self.content_wrap = VerticalGroup:new {
    align = "center",
    HorizontalSpan:new { width = self.screen_w },
  }
  self.content_wrap[2] = self:_buildStack()
  return self.content_wrap
end

function ScreenCard:_buildStack()
  self.cards = self:buildCards() or {}
  local col = VerticalGroup:new { align = "center" }
  col[#col + 1] = VerticalSpan:new { width = Design.pad.page }
  for i, card in ipairs(self.cards) do
    if i > 1 then
      col[#col + 1] = VerticalSpan:new { width = Design.gap }
    end
    col[#col + 1] = card
  end
  col[#col + 1] = VerticalSpan:new { width = Design.pad.page }
  return col
end

--- Subclasses override. Returns an ordered array of card widgets.
function ScreenCard:buildCards()
  return {}
end

--- Rebuild the stack from buildCards() and repaint once.
function ScreenCard:refresh()
  if not self.content_wrap then
    return
  end
  self.content_wrap[2] = self:_buildStack()
  self.content_wrap:resetLayout()
  -- content height may have changed (e.g. a wizard page swap): force the
  -- ScrollableContainer to recompute whether / how far it scrolls.
  if self.scroll_container and self.scroll_container.reset then
    self.scroll_container:reset()
  end
  UIManager:setDirty(self, "ui")
end

return ScreenCard
