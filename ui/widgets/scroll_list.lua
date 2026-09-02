-- ui/widgets/scroll_list.lua
-- A vertical list with no pagination bar — the KoffeeLab replacement for the
-- Menu-based full-screen screens. Same item shape those screens already use:
--
--   ScrollList:new{
--     width = w, height = h,          -- viewport
--     show_parent = screen,           -- the ScreenBase hosting this
--     items = {
--       { text = "Dose", mandatory = "18 g", on_tap = fn },       -- normal row
--       { text = "Brew steps", mandatory = "3", kind = "head" },  -- section header, inert
--       { text = "bright, tea-like", kind = "text" },             -- wrapped body, inert
--     },
--   }
--
-- The host screen forwards `self.cropping_widget` (a ScrollableContainer) so
-- UIManager clips inner repaints. `:setItems()` rebuilds + repaints once;
-- `:rows()` returns the raw items array for specs.

local Card = require("ui/widgets/card")
local Design = require("ui/design")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconWidget = require("ui/widget/iconwidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local Paths = require("ui/paths")
local ScrollableContainer = require("ui/widget/container/scrollablecontainer")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Device = require("device")
local Screen = Device.screen

local ScrollList = InputContainer:extend {
  width = nil,
  height = nil,
  items = nil,
  show_parent = nil,
}

function ScrollList:init()
  self.items = self.items or {}
  self._pad = Design.pad.md
  -- reserve room for the vertical scrollbar the ScrollableContainer draws over
  -- the content when the list overflows (3 * its bar width)
  self._content_w = self.width - 3 * ScrollableContainer.scroll_bar_width
  self:_build()
end

-- One list row as a grey card: [icon] title .......... value, with an optional
-- muted `item.caption` line under the title and `gap` below the card instead of a
-- hairline. `item.icon` (a bundled slug) is optional.
function ScrollList:_normalRow(item)
  local card_w = self._content_w
  local inner_w = card_w - 2 * Design.pad.card
  local gap = Design.gap

  local icon, icon_w = nil, 0
  if item.icon then
    local sz = Screen:scaleBySize(24)
    icon = IconWidget:new {
      file = Paths.icon(item.icon),
      width = sz,
      height = sz,
      is_icon = true,
      alpha = true,
    }
    icon_w = sz + Design.gap
  end

  local right, right_w = nil, 0
  if item.mandatory and item.mandatory ~= "" then
    right = TextWidget:new {
      text = tostring(item.mandatory),
      face = Design.face("label"),
      fgcolor = Design.color.muted,
      max_width = math.floor(inner_w * 0.5),
      truncate_left = true,
    }
    right_w = right:getSize().w
  end

  local text_w = inner_w - icon_w - right_w - (right_w > 0 and gap or 0)
  local title = TextWidget:new {
    text = tostring(item.text or ""),
    face = Design.face("body"),
    max_width = text_w,
  }
  local left = title
  if item.caption and item.caption ~= "" then
    left = VerticalGroup:new {
      align = "left",
      title,
      VerticalSpan:new { width = Design.gap_tight },
      TextWidget:new {
        text = tostring(item.caption),
        face = Design.face("label"),
        fgcolor = Design.color.muted,
        max_width = text_w,
      },
    }
  end

  local content = HorizontalGroup:new { align = "center" }
  if icon then
    content[#content + 1] = icon
    content[#content + 1] = HorizontalSpan:new { width = Design.gap }
  end
  content[#content + 1] = left
  if right then
    content[#content + 1] = HorizontalSpan:new {
      width = math.max(gap, text_w - left:getSize().w),
    }
    content[#content + 1] = right
  end

  local card = Card:new {
    width = card_w,
    show_parent = self.show_parent or self,
    on_tap = item.on_tap,
    content,
  }

  return VerticalGroup:new { align = "left", card, VerticalSpan:new { width = Design.gap } }
end

function ScrollList:_headRow(item)
  local inner_w = self._content_w - 2 * self._pad
  local gap = Design.pad.md
  local right, right_w = nil, 0
  if item.mandatory and item.mandatory ~= "" then
    right = TextWidget:new {
      text = tostring(item.mandatory),
      face = Design.face("label"),
      fgcolor = Design.color.muted,
    }
    right_w = right:getSize().w
  end
  local left = TextWidget:new {
    text = tostring(item.text or ""),
    face = Design.face("title"),
    max_width = inner_w - right_w - (right_w > 0 and gap or 0),
  }
  local content = HorizontalGroup:new { align = "center", left }
  if right then
    content[#content + 1] =
      HorizontalSpan:new { width = math.max(gap, inner_w - left:getSize().w - right_w) }
    content[#content + 1] = right
  end
  return FrameContainer:new {
    bordersize = 0,
    padding = self._pad,
    padding_top = Design.pad.lg,
    margin = 0,
    width = self._content_w,
    background = Design.color.bg,
    content,
  }
end

function ScrollList:_textRow(item)
  return FrameContainer:new {
    bordersize = 0,
    padding = self._pad,
    padding_left = self._pad + Design.pad.md,
    margin = 0,
    width = self._content_w,
    background = Design.color.bg,
    TextBoxWidget:new {
      text = tostring(item.text or ""),
      face = Design.face("body"),
      fgcolor = Design.color.muted,
      width = self._content_w - 2 * self._pad - Design.pad.md,
    },
  }
end

function ScrollList:_build()
  local group = VerticalGroup:new { align = "left" }
  local grid = {}
  local y = 0
  for _, item in ipairs(self.items) do
    local w
    if item.kind == "head" then
      w = self:_headRow(item)
    elseif item.kind == "text" then
      w = self:_textRow(item)
    else
      w = self:_normalRow(item)
    end
    group[#group + 1] = w
    local h = w:getSize().h
    grid[#grid + 1] = { top = y, bottom = y + h - 1 }
    y = y + h
  end
  self._group = group

  self.cropping_widget = ScrollableContainer:new {
    dimen = Geom:new { w = self.width, h = self.height },
    show_parent = self.show_parent or self,
    step_scroll_grid = grid,
    group,
  }
  self[1] = self.cropping_widget
  self.dimen = Geom:new { w = self.width, h = self.height }
end

--- Rebuild from a new items array and repaint once.
function ScrollList:setItems(items)
  self.items = items or {}
  self:_build()
  UIManager:setDirty(self.show_parent or self, "ui")
end

--- The raw items array (for specs / callers that inspect content).
function ScrollList:rows()
  return self.items
end

return ScrollList
