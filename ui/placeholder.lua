-- ui/placeholder.lua
-- A titled empty screen used while later phases are unbuilt (TECH_SOLUTION
-- §3.19 incremental delivery). Real feature screens replace these one phase at a
-- time; until then tapping a Home button lands on a screen that renders, says
-- what is coming, and returns cleanly with Back.

local CenterContainer = require("ui/widget/container/centercontainer")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local ScreenBase = require("ui/screen_base")
local TextBoxWidget = require("ui/widget/textboxwidget")
local _ = require("gettext")

local Placeholder = ScreenBase:extend {
  name = "koffeelab_placeholder",
  message = nil,
}

function Placeholder:getContentWidget()
  return CenterContainer:new {
    dimen = Geom:new { w = self.screen_w, h = self.content_height },
    TextBoxWidget:new {
      text = self.message or _("Coming in a later phase."),
      face = Font:getFace("infofont"),
      width = math.floor(self.screen_w * 0.8),
      alignment = "center",
    },
  }
end

return Placeholder
