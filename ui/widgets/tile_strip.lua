-- ui/widgets/tile_strip.lua
-- TileStrip — a tidy grid of small { label, value } chips inside a SectionCard
-- (Brew Details: `Beans 18 g` `Water 200 mL / 93°` `Output 1:15`). Chips are
-- equal-width white cells laid out in a fixed number of columns (2 by default).
-- Every chip is padded to a common minimum size and its content is centred, so
-- the block reads as an even, aligned strip rather than ragged blocks. A short
-- final row (one lone chip) is centred under the full rows above it. It never
-- scrolls sideways; long values wrap inside their cell.
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
local CenterContainer = require("ui/widget/container/centercontainer")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Device = require("device")
local Screen = Device.screen

local TileStrip = {}

-- Every chip is at least this tall (roughly a label line + two value lines), so a
-- strip of all-short chips still has breathing room and matches one that wraps.
local MIN_CHIP_H = Screen:scaleBySize(56)

-- The centred label + value stack for one chip, at a fixed inner width.
local function chip_body(item, inner_w)
  return VerticalGroup:new {
    align = "center",
    TextWidget:new {
      text = tostring(item.label or ""),
      face = Design.face("label"),
      fgcolor = Design.color.muted,
      max_width = inner_w,
    },
    VerticalSpan:new { width = Design.gap_tight },
    TextBoxWidget:new {
      text = tostring(item.value or ""),
      face = Design.face("body"),
      width = inner_w,
      alignment = "center",
    },
  }
end

function TileStrip:new(o)
  o = o or {}
  local width = o.width or 0
  local gap = o.gap or Design.gap_tight
  local n = #(o.items or {})
  local cols = math.max(1, math.min(o.columns or 2, n))
  local cell_w = math.floor((width - gap * (cols - 1)) / cols)
  local pad = Design.gap_tight
  local inner_w = cell_w - 2 * pad

  -- Pass 1: build every body and find the tallest so all chips share one height.
  local bodies = {}
  local chip_h = MIN_CHIP_H
  for i, item in ipairs(o.items or {}) do
    bodies[i] = chip_body(item, inner_w)
    chip_h = math.max(chip_h, bodies[i]:getSize().h + 2 * pad)
  end

  -- Pass 2: wrap each body in a fixed-size, centred chip.
  local chips = {}
  for i = 1, n do
    chips[i] = FrameContainer:new {
      background = Design.color.bg,
      bordersize = 0,
      radius = math.floor(Design.radius * 0.6),
      padding = 0,
      margin = 0,
      width = cell_w,
      height = chip_h,
      CenterContainer:new {
        dimen = Geom:new { w = cell_w, h = chip_h },
        bodies[i],
      },
    }
  end

  -- Lay the chips out row by row. `align = "center"` centres a short final row
  -- (the full rows already span `width`, so it is a no-op for them).
  local rows = VerticalGroup:new { align = "center" }
  local row = HorizontalGroup:new { align = "top" }
  for i = 1, n do
    local col = (i - 1) % cols
    if col == 0 and i > 1 then
      rows[#rows + 1] = row
      rows[#rows + 1] = VerticalSpan:new { width = gap }
      row = HorizontalGroup:new { align = "top" }
    end
    if col > 0 then
      row[#row + 1] = HorizontalSpan:new { width = gap }
    end
    row[#row + 1] = chips[i]
  end
  if #row > 0 then
    rows[#rows + 1] = row
  end

  rows.chips = chips
  rows.dimen = Geom:new { w = width, h = rows:getSize().h }
  return rows
end

return TileStrip
