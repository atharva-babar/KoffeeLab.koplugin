-- ui/widgets/tile_strip.lua
-- TileStrip — a tidy grid of small { label, value } chips inside a SectionCard
-- (Brew Details: `Beans 18 g` `Water 200 mL / 93°` `Output 1:15`). Chips are
-- equal-width white cells laid out in a fixed number of columns (2 by default),
-- so the block reads as an aligned strip, not ragged blocks. It never scrolls
-- sideways; long values wrap inside their cell.
--
--   TileStrip:new{ width = inner_w, columns = 2, items = {
--     { label = _("Beans"), value = "Ethiopia 18 g" },
--     { label = _("Water"), value = "200 mL / 93 C" },
--   } }

local Design = require("ui/design")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local TileStrip = {}

local function chip(item, cell_w)
  local pad = Design.gap_tight
  local inner = cell_w - 2 * pad
  local body = VerticalGroup:new {
    align = "left",
    TextWidget:new {
      text = tostring(item.label or ""),
      face = Design.face("label"),
      fgcolor = Design.color.muted,
      max_width = inner,
    },
    VerticalSpan:new { width = Design.gap_tight },
    TextBoxWidget:new {
      text = tostring(item.value or ""),
      face = Design.face("body"),
      width = inner,
    },
  }
  return FrameContainer:new {
    background = Design.color.bg,
    bordersize = 0,
    radius = math.floor(Design.radius * 0.6),
    padding = pad,
    margin = 0,
    width = cell_w,
    body,
  }
end

function TileStrip:new(o)
  o = o or {}
  local width = o.width or 0
  local gap = o.gap or Design.gap_tight
  local n = #(o.items or {})
  local cols = math.max(1, math.min(o.columns or 2, n))
  local cell_w = math.floor((width - gap * (cols - 1)) / cols)

  local chips = {}
  local rows = VerticalGroup:new { align = "left" }
  local row = HorizontalGroup:new { align = "top" }

  for i, item in ipairs(o.items or {}) do
    local col = (i - 1) % cols
    if col == 0 and i > 1 then
      rows[#rows + 1] = row
      rows[#rows + 1] = VerticalSpan:new { width = gap }
      row = HorizontalGroup:new { align = "top" }
    end
    if col > 0 then
      row[#row + 1] = HorizontalSpan:new { width = gap }
    end
    local c = chip(item, cell_w)
    row[#row + 1] = c
    chips[#chips + 1] = c
  end
  if #row > 0 then
    rows[#rows + 1] = row
  end

  rows.chips = chips
  rows.dimen = Geom:new { w = width, h = rows:getSize().h }
  return rows
end

return TileStrip
