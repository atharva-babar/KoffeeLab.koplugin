-- ui/widgets/card_row.lua
-- CardRow — lays 2-3 cards/tiles in a centred horizontal group with `gap` between
-- them and `pad.page` on the outside. Equal widths by default; pass fractions or
-- pixel widths for an uneven split (e.g. a title + method card).
--
--   local w = CardRow.cellWidths(page_w, 2)          -- { w, w }
--   local w = CardRow.cellWidths(page_w, { 0.62, 0.38 })
--   local row = CardRow.new{ width = page_w, cards = { titleCard, methodCard } }
--
-- `CardRow.new` returns a widget (a CenterContainer) ready to drop into a screen's
-- VerticalGroup.

local CenterContainer = require("ui/widget/container/centercontainer")
local Design = require("ui/design")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")

local CardRow = {}

--- Cell widths for `n` equal cells, or for a list of fractions (<=1) / pixel
--- widths, fitted inside `page_w` minus the page margins and inter-cell gaps.
function CardRow.cellWidths(page_w, spec, gap)
  gap = gap or Design.gap
  local avail = page_w - 2 * Design.pad.page
  if type(spec) == "number" then
    local total_gap = gap * (spec - 1)
    local each = math.floor((avail - total_gap) / spec)
    local out = {}
    for i = 1, spec do
      out[i] = each
    end
    return out
  end
  local n = #spec
  local total_gap = gap * (n - 1)
  local inner = avail - total_gap
  local out = {}
  for i, v in ipairs(spec) do
    out[i] = (v <= 1) and math.floor(inner * v) or v
  end
  return out
end

--- Lay pre-built `cards` out centred in `page_w`.
function CardRow.new(o)
  local gap = o.gap or Design.gap
  local row = HorizontalGroup:new { align = "center" }
  for i, card in ipairs(o.cards) do
    if i > 1 then
      row[#row + 1] = HorizontalSpan:new { width = gap }
    end
    row[#row + 1] = card
  end
  return CenterContainer:new {
    dimen = Geom:new { w = o.width, h = row:getSize().h },
    row,
  }
end

return CardRow
