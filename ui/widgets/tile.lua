-- ui/widgets/tile.lua
-- Tile — a Card whose content is a centred icon over a short label. Used by method
-- pickers, Home actions and the Index chooser. Built on Card so tap behaviour and
-- styling stay in one place.
--
--   Tile:new{ width = w, height = h, icon = "add", label = _("Add Recipe"),
--             on_tap = fn, show_parent = screen }

local Card = require("ui/widgets/card")
local CenterContainer = require("ui/widget/container/centercontainer")
local Design = require("ui/design")
local Geom = require("ui/geometry")
local IconWidget = require("ui/widget/iconwidget")
local Paths = require("ui/paths")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Device = require("device")
local Screen = Device.screen

local Tile = {}

function Tile:new(o)
  o = o or {}
  local icon_size = o.icon_size or Screen:scaleBySize(28)
  local inner_w = (o.width or 0) - 2 * Design.pad.card
  local inner = VerticalGroup:new {
    align = "center",
    IconWidget:new {
      file = Paths.icon(o.icon),
      width = icon_size,
      height = icon_size,
      is_icon = true,
      alpha = true,
    },
    VerticalSpan:new { width = Design.gap_tight },
    TextWidget:new {
      text = o.label or "",
      face = Design.face("body"),
      max_width = inner_w,
    },
  }
  local body = CenterContainer:new {
    dimen = Geom:new {
      w = inner_w,
      h = (o.height or 0) - 2 * Design.pad.card,
    },
    inner,
  }
  local card = Card:new {
    width = o.width,
    height = o.height,
    on_tap = o.on_tap,
    show_parent = o.show_parent,
    body,
  }
  card.label = o.label
  return card
end

return Tile
