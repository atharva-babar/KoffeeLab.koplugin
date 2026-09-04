-- ui/widgets/section_card.lua
-- SectionCard — a titled block on a detail / form screen: a centred NotoSerif
-- title over a body slot (rows, a TileStrip, wrapped text, a small grid).
-- Replaces the old `head` / `text` / row kinds of ui/widgets/scroll_list.
--
--   SectionCard:new{ width = w, title = _("Brew Details"), show_parent = screen,
--                    on_tap = fn,           -- optional: whole card tappable
--                    body = SomeWidget:new{ ... } }

local Card = require("ui/widgets/card")
local CenterContainer = require("ui/widget/container/centercontainer")
local Design = require("ui/design")
local Geom = require("ui/geometry")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local SectionCard = {}

function SectionCard:new(o)
  o = o or {}
  local inner_w = (o.width or 0) - 2 * Design.pad.card
  local inner = VerticalGroup:new { align = "left" }
  if o.title and o.title ~= "" then
    local title = TextWidget:new {
      text = tostring(o.title),
      face = Design.face("title"),
      max_width = inner_w,
    }
    inner[#inner + 1] = CenterContainer:new {
      dimen = Geom:new { w = inner_w, h = title:getSize().h },
      title,
    }
    if o.body then
      inner[#inner + 1] = VerticalSpan:new { width = Design.gap }
    end
  end
  if o.body then
    inner[#inner + 1] = o.body
  end
  local card = Card:new {
    width = o.width,
    on_tap = o.on_tap,
    show_parent = o.show_parent,
    inner,
  }
  card.title = o.title
  return card
end

return SectionCard
