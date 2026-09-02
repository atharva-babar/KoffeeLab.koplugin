-- ui/widgets/stat_card.lua
-- StatCard — a Home card: a muted header line over up to 3 tappable title lines.
-- Tapping a line opens that item; tapping the header opens the full list. When
-- there are no items the card shows one muted "Nothing yet" line and is inert.
--
--   StatCard:new{ width = w, height = h, show_parent = screen,
--     header = _("Recent"), on_header = fn, empty_text = _("No brews yet"),
--     items = { { text = "V60 Morning", on_tap = fn }, ... } }  -- up to 3

local Design = require("ui/design")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")

local MAX_ITEMS = 3

local StatCard = InputContainer:extend {
  width = nil,
  height = nil,
  header = "",
  items = nil,
  on_header = nil,
  empty_text = nil,
  show_parent = nil,
}

-- One tappable text line inside the card. `range_of` is resolved lazily because
-- the inner frame's x/y are only known after paintTo.
function StatCard:_line(text, face, fgcolor, on_tap)
  local inner_w = self.width - 2 * Design.pad.card
  local frame = FrameContainer:new {
    background = Design.color.card,
    bordersize = 0,
    padding = 0,
    margin = 0,
    TextWidget:new {
      text = tostring(text or ""),
      face = face,
      fgcolor = fgcolor,
      max_width = inner_w,
    },
  }
  if not (on_tap and Device:isTouchDevice()) then
    return frame
  end
  local row = InputContainer:new { frame }
  row.ges_events.Tap = {
    GestureRange:new {
      ges = "tap",
      range = function()
        return frame.dimen
      end,
    },
  }
  row.onTap = function()
    UIManager:setDirty(self.show_parent or self, "ui")
    on_tap()
    return true
  end
  return row
end

function StatCard:init()
  self.items = self.items or {}
  self.lines = {}

  local body = VerticalGroup:new { align = "left" }
  local header_tap = (#self.items > 0) and self.on_header or nil
  self.header_line = self:_line(self.header, Design.face("label"), Design.color.muted, header_tap)
  body[#body + 1] = self.header_line

  if #self.items == 0 then
    body[#body + 1] = VerticalSpan:new { width = Design.gap_tight }
    body[#body + 1] =
      self:_line(self.empty_text or _("Nothing yet"), Design.face("body"), Design.color.muted, nil)
  else
    for i = 1, math.min(MAX_ITEMS, #self.items) do
      local item = self.items[i]
      body[#body + 1] = VerticalSpan:new { width = Design.gap_tight }
      local line = self:_line(item.text, Design.face("body"), Design.color.fg, item.on_tap)
      self.lines[#self.lines + 1] = line
      body[#body + 1] = line
    end
  end

  self.frame = FrameContainer:new {
    background = Design.color.card,
    bordersize = 0,
    radius = Design.radius,
    padding = Design.pad.card,
    margin = 0,
    width = self.width,
    height = self.height,
    body,
  }
  self[1] = self.frame
  self.dimen = self.frame:getSize()
  self.inert = #self.items == 0
end

function StatCard:getSize()
  return self.dimen or Geom:new { w = self.width or 0, h = self.height or 0 }
end

return StatCard
