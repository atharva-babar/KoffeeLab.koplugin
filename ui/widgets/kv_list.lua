-- ui/widgets/kv_list.lua
-- KvList — a small stack of "label ......... value" lines for use as a SectionCard
-- body on the detail screens. Not a list widget: no scrolling, no taps.
--
--   KvList.new(inner_w, { { _("Dose"), "18 g" }, { _("Ratio"), "1:16" } })

local Design = require("ui/design")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local KvList = {}

function KvList.new(inner_w, rows)
  local g = VerticalGroup:new { align = "left" }
  for i, r in ipairs(rows) do
    if i > 1 then
      g[#g + 1] = VerticalSpan:new { width = Design.gap_tight }
    end
    local label = TextWidget:new {
      text = tostring(r[1]),
      face = Design.face("label"),
      fgcolor = Design.color.muted,
    }
    local value = TextWidget:new {
      text = tostring(r[2]),
      face = Design.face("body"),
      max_width = math.max(1, inner_w - label:getSize().w - Design.gap),
    }
    g[#g + 1] = HorizontalGroup:new {
      align = "center",
      label,
      HorizontalSpan:new {
        width = math.max(Design.gap, inner_w - label:getSize().w - value:getSize().w),
      },
      value,
    }
  end
  return g
end

return KvList
