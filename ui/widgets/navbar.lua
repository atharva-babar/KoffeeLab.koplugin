-- ui/widgets/navbar.lua
-- The contextual bottom navigation bar. Every KoffeeLab verb lives here and only
-- here (docs/design-language.md §1.2). KOReader has no navbar widget, so this is a
-- FrameContainer with a top hairline over a centred HorizontalGroup of 2-5 equal
-- icon+label cells. The owning screen pins it to the bottom with a BottomContainer
-- and navigates in `on_select`.
--
--   Navbar:new{ width = screen_w, active = "home", show_parent = screen,
--               items = { "home", "filter", "sort", "search", "back" },
--               on_select = function(key) ... end }
--
-- Each item is either a known key (string) or a { key, icon, label } table.
-- `Navbar.HEIGHT` is the computed pixel height (for content-area layout math).

local Design = require("ui/design")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
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

-- key -> { icon file, short label }. `favourite` flips to the filled star when the
-- caller marks the item `{ key = "favourite", on = true }`.
local KNOWN = {
  home = { icon = "home", label = _("Home") },
  index = { icon = "index", label = _("Index") },
  configurator = { icon = "configurator", label = _("Config") },
  add = { icon = "add", label = _("Add") },
  add_recipe = { icon = "add_recipe", label = _("Recipe") },
  add_drink = { icon = "add_drink", label = _("Drink") },
  filter = { icon = "filter", label = _("Filter") },
  sort = { icon = "sort", label = _("Sort") },
  search = { icon = "search", label = _("Search") },
  back = { icon = "back", label = _("Back") },
  next = { icon = "next", label = _("Next") },
  exit = { icon = "exit", label = _("Exit") },
  edit = { icon = "edit", label = _("Edit") },
  delete = { icon = "delete", label = _("Delete") },
  save = { icon = "save", label = _("Save") },
  brew_again = { icon = "brew_again", label = _("Brew") },
  favourite = { icon = "favorite", label = _("Favourite") },
}

local ICON_SIZE = Screen:scaleBySize(22)
local GAP = Screen:scaleBySize(2)
local CELL_W = Screen:scaleBySize(74)

local Navbar = InputContainer:extend {
  width = nil,
  items = nil,
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

--- Resolve one item spec ({ key,... } or a bare key string) to a full entry.
local function resolve(spec)
  if type(spec) == "string" then
    spec = { key = spec }
  end
  local base = KNOWN[spec.key] or { icon = spec.key, label = spec.key }
  local icon = spec.icon or base.icon
  if spec.key == "favourite" and spec.on then
    icon = "favorite_filled"
  end
  return { key = spec.key, icon = icon, label = spec.label or base.label }
end

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
    background = active and Design.color.card or Design.color.bg,
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
  local specs = self.items or { "home" }
  self.entries = {}
  for i, s in ipairs(specs) do
    self.entries[i] = resolve(s)
  end
  local n = #self.entries

  local cell_w = math.min(CELL_W, math.floor(self.width / n))
  local bar_w = cell_w * n
  local left = math.floor((self.width - bar_w) / 2)

  -- Build the row at the FULL width (leading + trailing spacer) so the enclosing
  -- VerticalGroup's centre-align is a no-op and the painted cells line up exactly
  -- with self._ranges (which the tap hit-test uses).
  local row = HorizontalGroup:new { align = "top" }
  if left > 0 then
    row[#row + 1] = HorizontalSpan:new { width = left }
  end
  self._ranges = {}
  for i, entry in ipairs(self.entries) do
    row[#row + 1] = cell_widget(entry, entry.key == self.active, cell_w)
    self._ranges[i] = {
      key = entry.key,
      x0 = left + cell_w * (i - 1),
      x1 = left + cell_w * i,
    }
  end
  local right = self.width - left - bar_w
  if right > 0 then
    row[#row + 1] = HorizontalSpan:new { width = right }
  end

  self.frame = FrameContainer:new {
    background = Design.color.bg,
    bordersize = 0,
    padding = 0,
    margin = 0,
    width = self.width,
    VerticalGroup:new {
      align = "left",
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
