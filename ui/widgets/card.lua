-- ui/widgets/card.lua
-- Card — the KoffeeLab primitive: a rounded, borderless, light-grey box on the
-- white page. One repaint per tap. Inert (not tappable) when `on_tap` is nil, e.g.
-- an empty-state card or a plain content block.
--
--   Card:new{ width = w, height = h, on_tap = fn, show_parent = screen,
--             active = false, SomeChildWidget:new{ ... } }
--
-- `height` omitted => the card hugs its content. `active = true` paints the
-- pressed grey from the start (a selected/current card).

local Design = require("ui/design")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")

local Card = InputContainer:extend {
  width = nil,
  height = nil,
  on_tap = nil,
  show_parent = nil,
  active = false,
  padding = nil, -- overrides Design.pad.card
}

function Card:init()
  self.frame = FrameContainer:new {
    background = self.active and Design.color.card_active or Design.color.card,
    bordersize = 0,
    radius = Design.radius,
    padding = self.padding or Design.pad.card,
    margin = 0,
    width = self.width,
    height = self.height,
    self[1],
  }
  self[1] = self.frame
  -- FrameContainer:getSize() reports its *content* size and ignores a forced
  -- width/height; report the forced size so a VerticalGroup lays this card out
  -- (and centres it) at the width it actually paints.
  local fs = self.frame:getSize()
  self.dimen = Geom:new { w = self.width or fs.w, h = self.height or fs.h }

  if self.on_tap and Device:isTouchDevice() then
    self.ges_events.Tap = {
      -- x/y are only known after paintTo, so match lazily against self.dimen
      GestureRange:new {
        ges = "tap",
        range = function()
          return self.dimen
        end,
      },
    }
  end
end

function Card:paintTo(bb, x, y)
  InputContainer.paintTo(self, bb, x, y)
  self.dimen.x, self.dimen.y = x, y
end

function Card:onTap()
  if not self.on_tap then
    return true
  end
  -- The action drives its own repaint (a pushed screen / modal / list rebuild);
  -- a "pressed" flash would just stick grey on e-ink until the next full paint.
  self.on_tap()
  return true
end

--- The card's outer geometry (for layout math by the owning screen).
function Card:getSize()
  return self.dimen or Geom:new { w = self.width or 0, h = self.height or 0 }
end

return Card
