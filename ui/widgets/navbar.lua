-- ui/widgets/navbar.lua
-- Bottom navigation bar for the root-ish screens (Home, Index, Configurator).
-- KOReader has no navbar widget, so this is a FrameContainer with a top hairline
-- over a HorizontalGroup of 5 equal icon+label cells. The owning screen pins it
-- to the bottom with a BottomContainer and does the navigation in `on_select`.
--
--   Navbar:new{ width = screen_w, active = "home",
--               on_select = function(key) ... end, show_parent = screen }
--
-- keys: "home" | "index" | "add" | "favourites" | "configurator"
-- `Navbar.HEIGHT` is the computed pixel height (for content-area layout math).

local Blitbuffer = require("ffi/blitbuffer")
local Design = require("ui/design")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local IconWidget = require("ui/widget/iconwidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local Paths = require("ui/paths")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local CenterContainer = require("ui/widget/container/centercontainer")
local _ = require("gettext")
local Screen = Device.screen

local CELLS = {
  { key = "home", label = _("Home"), icon = "home" },
  { key = "index", label = _("Index"), icon = "index" },
  { key = "add", label = _("Add"), icon = "add" },
  { key = "favourites", label = _("Favourites"), icon = "favorite" },
  { key = "configurator", label = _("Config"), icon = "configurator" },
}

local ICON_SIZE = Screen:scaleBySize(22)
local GAP = Screen:scaleBySize(2)

local Navbar = InputContainer:extend {
  width = nil,
  active = nil,
  on_select = nil,
  show_parent = nil,
}

-- Height = hairline + top pad + icon + gap + label line + bottom pad.
Navbar.HEIGHT = Design.border
  + Design.pad.sm * 2
  + ICON_SIZE
  + GAP
  + TextWidget:new({ text = "Ag", face = Design.face("label") }):getSize().h

local function cell_widget(entry, active, cell_w)
  local inner = VerticalGroup:new {
    align = "center",
    IconWidget:new {
      file = Paths.icon(entry.icon),
      width = ICON_SIZE,
      height = ICON_SIZE,
      is_icon = true,
      alpha = true,
    },
    VerticalSpan:new { width = GAP },
    TextWidget:new {
      text = entry.label,
      face = Design.face("label"),
      fgcolor = active and Design.color.fg or Design.color.muted,
      bold = active or nil,
    },
  }
  return FrameContainer:new {
    background = active and Blitbuffer.COLOR_GRAY_E or Design.color.bg,
    bordersize = 0,
    padding = Design.pad.sm,
    margin = 0,
    width = cell_w,
    height = Navbar.HEIGHT - Design.border,
    CenterContainer:new {
      dimen = Geom:new {
        w = cell_w - Design.pad.sm * 2,
        h = Navbar.HEIGHT - Design.border - Design.pad.sm * 2,
      },
      inner,
    },
  }
end

function Navbar:init()
  local n = #CELLS
  local cell_w = math.floor(self.width / n)
  local row = HorizontalGroup:new {}
  self._ranges = {}
  for i, entry in ipairs(CELLS) do
    -- last cell absorbs the rounding remainder
    local w = (i == n) and (self.width - cell_w * (n - 1)) or cell_w
    table.insert(row, cell_widget(entry, entry.key == self.active, w))
    self._ranges[i] = { key = entry.key, x0 = cell_w * (i - 1), x1 = cell_w * (i - 1) + w }
  end

  self.frame = FrameContainer:new {
    background = Design.color.bg,
    bordersize = 0,
    padding = 0,
    margin = 0,
    width = self.width,
    VerticalGroup:new {
      LineWidget:new {
        dimen = Geom:new { w = self.width, h = Design.border },
        background = Design.color.hairline,
      },
      row,
    },
  }
  self[1] = self.frame
  self.dimen = Geom:new { x = 0, y = 0, w = self.width, h = Navbar.HEIGHT }

  if Device:isTouchDevice() then
    self.ges_events.Tap = {
      GestureRange:new {
        ges = "tap",
        range = function()
          return self.frame.dimen
        end,
      },
    }
  end
end

function Navbar:onTap(_, ges)
  if not self.on_select then
    return true
  end
  local base_x = self.frame.dimen and self.frame.dimen.x or 0
  local x = ges and ges.pos and (ges.pos.x - base_x)
  local key = self._ranges[1] and self._ranges[1].key
  if x then
    for _, r in ipairs(self._ranges) do
      if x >= r.x0 and x < r.x1 then
        key = r.key
        break
      end
    end
  end
  UIManager:setDirty(self.show_parent or self, "ui")
  self.on_select(key)
  return true
end

return Navbar
