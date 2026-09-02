-- ui/widgets/card.lua
-- Card — a tappable bordered box, the KoffeeLab primitive for home tiles and
-- section blocks. One repaint per tap. Not tappable when `on_tap` is nil (an
-- empty-state card).
--
--   Card:new{ width = w, height = h, on_tap = fn, show_parent = screen,
--             SomeChildWidget:new{ ... } }

local Design = require("ui/design")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")

local Card = InputContainer:extend {
  width = nil,
  height = nil,
  on_tap = nil,
  show_parent = nil,
}

function Card:init()
  self.frame = FrameContainer:new {
    background = Design.color.bg,
    bordersize = Design.border,
    color = Design.color.hairline,
    radius = Design.radius,
    padding = Design.pad.md,
    margin = 0,
    width = self.width,
    height = self.height,
    self[1],
  }
  self[1] = self.frame
  self.dimen = self.frame:getSize()

  if self.on_tap and Device:isTouchDevice() then
    self.ges_events.Tap = {
      -- the frame's x/y are only known after paintTo, so match lazily
      GestureRange:new {
        ges = "tap",
        range = function()
          return self.frame.dimen
        end,
      },
    }
  end
end

function Card:onTap()
  if not self.on_tap then
    return true
  end
  UIManager:setDirty(self.show_parent or self, "ui")
  self.on_tap()
  return true
end

--- The card's outer geometry (for layout math by the owning screen).
function Card:getSize()
  return self.dimen or Geom:new { w = self.width or 0, h = self.height or 0 }
end

return Card
