-- ui/widgets/stat_card.lua
-- StatCard — a Home card: a muted header line over up to 3 tappable title lines.
-- Tapping a line opens that item; tapping the header opens the full list. When
-- there are no items the card shows one muted "Nothing yet" line and is inert.
--
-- The card always reserves MAX_ITEMS body rows (blank filler for missing ones)
-- and sizes its height to that content, so every card in the Home grid is the
-- same height and the rounded background always contains its text.
--
--   StatCard:new{ width = w, show_parent = screen,
--     header = _("Recently Saved"), on_header = fn, empty_text = _("No recipes yet"),
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
  self.lines = {} -- the tappable line widgets, in order
  self.shown = {} -- the item tables actually rendered (<= MAX_ITEMS)

  local body = VerticalGroup:new { align = "left" }
  local header_tap = (#self.items > 0) and self.on_header or nil
  self.header_line = self:_line(self.header, Design.face("label"), Design.color.muted, header_tap)
  body[#body + 1] = self.header_line

  -- Always lay out MAX_ITEMS body rows so every card is the same height. Real
  -- items are tappable; an empty card puts its "nothing yet" note on row 1; any
  -- remaining rows are blank spacers that just hold the height.
  for i = 1, MAX_ITEMS do
    body[#body + 1] = VerticalSpan:new { width = Design.gap_tight }
    local item = self.items[i]
    if item then
      local line = self:_line(item.text, Design.face("body"), Design.color.fg, item.on_tap)
      self.lines[#self.lines + 1] = line
      self.shown[#self.shown + 1] = item
      body[#body + 1] = line
    elseif i == 1 and #self.items == 0 then
      body[#body + 1] = self:_line(
        self.empty_text or _("Nothing yet"),
        Design.face("body"),
        Design.color.muted,
        nil
      )
    else
      body[#body + 1] = self:_line(" ", Design.face("body"), Design.color.card, nil)
    end
  end

  self.frame = FrameContainer:new {
    background = Design.color.card,
    bordersize = 0,
    radius = Design.radius,
    padding = Design.pad.card,
    margin = 0,
    width = self.width,
    body,
  }
  self[1] = self.frame
  -- FrameContainer:getSize() reports content size and ignores a forced width;
  -- report the forced width (with the measured content height) so the grid lays
  -- the cards out at the size they actually paint.
  local fs = self.frame:getSize()
  self.height = fs.h
  self.dimen = Geom:new { w = self.width or fs.w, h = fs.h }
  self.inert = #self.items == 0
end

function StatCard:paintTo(bb, x, y)
  InputContainer.paintTo(self, bb, x, y)
  self.dimen.x, self.dimen.y = x, y
end

function StatCard:getSize()
  return self.dimen or Geom:new { w = self.width or 0, h = self.height or 0 }
end

return StatCard
