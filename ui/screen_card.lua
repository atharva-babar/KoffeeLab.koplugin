-- ui/screen_card.lua
-- Base for the v2 card screens (recipe / drink detail, Home-like config screens):
-- a ScreenBase with `scroll = true` wrapping a centred vertical stack of Cards /
-- SectionCards / CardRows.
--
-- A subclass implements `buildCards()` returning an ordered array of widgets
-- (each already sized to `self.card_w`). ScreenCard frames them with `pad.page`
-- top/bottom and `gap` between, keeps a flat `self.cards` for specs, and
-- `refresh()` rebuilds + repaints once.
--
--   local Detail = ScreenCard:extend{ name = "koffeelab_recipe_detail" }
--   function Detail:buildCards()
--     return { SectionCard:new{ width = self.card_w, title = ..., body = ... } }
--   end

local Design = require("ui/design")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ScreenBase = require("ui/screen_base")
local TopContainer = require("ui/widget/container/topcontainer")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local ScreenCard = ScreenBase:extend {
  name = "koffeelab_screen_card",
  scroll = true,
}

function ScreenCard:getContentWidget()
  self.card_w = self.screen_w - 2 * Design.pad.page
  self.content_wrap = TopContainer:new {
    dimen = Geom:new { w = self.screen_w, h = self.content_height },
    self:_buildStack(),
  }
  return self.content_wrap
end

function ScreenCard:_buildStack()
  self.cards = self:buildCards() or {}
  local col = VerticalGroup:new { align = "left" }
  col[#col + 1] = VerticalSpan:new { width = Design.pad.page }
  for i, card in ipairs(self.cards) do
    if i > 1 then
      col[#col + 1] = VerticalSpan:new { width = Design.gap }
    end
    col[#col + 1] = card
  end
  col[#col + 1] = VerticalSpan:new { width = Design.pad.page }

  return HorizontalGroup:new {
    align = "top",
    HorizontalSpan:new { width = Design.pad.page },
    col,
  }
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
  self.content_wrap[1] = self:_buildStack()
  if self.scroll_container and self.scroll_container.reset then
    self.scroll_container:reset()
  end
  UIManager:setDirty(self, "ui")
end

return ScreenCard
