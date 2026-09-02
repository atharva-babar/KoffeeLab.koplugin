-- ui/widgets/tile_strip.lua
-- TileStrip — a horizontal run of small { label, value } chips, used inside a
-- SectionCard (Brew Details: `Beans 18 g` `Water 200 mL / 93°` `Output 1:15`).
-- Chips are white so they read against the grey card. The run wraps to a new line
-- when it doesn't fit; it never scrolls sideways.
--
--   TileStrip:new{ width = inner_w, items = {
--     { label = _("Beans"), value = "Ethiopia 18 g" },
--     { label = _("Water"), value = "200 mL / 93 C" },
--   } }

local Design = require("ui/design")
local FrameContainer = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local TileStrip = {}

local function chip(item, max_w)
  local body = VerticalGroup:new {
    align = "left",
    TextWidget:new {
      text = tostring(item.label or ""),
      face = Design.face("label"),
      fgcolor = Design.color.muted,
      max_width = max_w,
    },
    VerticalSpan:new { width = Design.gap_tight },
    TextWidget:new {
      text = tostring(item.value or ""),
      face = Design.face("body"),
      max_width = max_w,
    },
  }
  return FrameContainer:new {
    background = Design.color.bg,
    bordersize = 0,
    radius = math.floor(Design.radius * 0.7),
    padding = Design.gap_tight,
    margin = 0,
    body,
  }
end

function TileStrip:new(o)
  o = o or {}
  local gap = o.gap or Design.gap_tight
  local width = o.width or 0
  local group = VerticalGroup:new { align = "left" }
  local row = HorizontalGroup:new { align = "top" }
  local row_w = 0
  local chips = {}

  local function flush()
    if #row > 0 then
      group[#group + 1] = row
      row = HorizontalGroup:new { align = "top" }
      row_w = 0
    end
  end

  for _, item in ipairs(o.items or {}) do
    local c = chip(item, width)
    local cw = c:getSize().w
    local need = (row_w > 0 and gap or 0) + cw
    if row_w > 0 and row_w + need > width then
      flush()
      need = cw
    end
    if #row > 0 then
      row[#row + 1] = HorizontalSpan:new { width = gap }
    end
    row[#row + 1] = c
    row_w = row_w + need
    chips[#chips + 1] = c
  end
  flush()

  -- vertical gaps between wrapped rows
  local spaced = VerticalGroup:new { align = "left" }
  for i, r in ipairs(group) do
    if i > 1 then
      spaced[#spaced + 1] = VerticalSpan:new { width = gap }
    end
    spaced[#spaced + 1] = r
  end
  spaced.chips = chips
  spaced.dimen = spaced:getSize()
  spaced.dimen.w = width
  return spaced
end

return TileStrip
