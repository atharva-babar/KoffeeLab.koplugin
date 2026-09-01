-- ui/widgets/rating.lua
-- Rating1to5 — five large discrete buttons [1]..[5] (TECH_SOLUTION §2.10). The
-- selected value is drawn inverted (Button.preselect) so the state is obvious in
-- grayscale, not just a subtle tint. One repaint per tap. Tapping the current
-- value again clears it back to nil (sensory axes and session ratings are
-- nullable — §3.14).

local Button = require("ui/widget/button")
local Device = require("device")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local Size = require("ui/size")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Screen = Device.screen

local Rating1to5 = WidgetContainer:extend {
  value = nil, -- nil or 1..5
  on_change = nil, -- function(new_value)  (new_value may be nil)
  width = nil, -- total width; defaults to a comfortable size
  allow_clear = true,
}

function Rating1to5:init()
  self.width = self.width or math.floor(Screen:getWidth() * 0.9)
  self:_build()
end

function Rating1to5:_build()
  local span = Size.span.horizontal_default
  local btn_width = math.floor((self.width - span * 4) / 5)
  local row = HorizontalGroup:new {}
  self._buttons = {}
  for n = 1, 5 do
    local btn = Button:new {
      text = string.format("%d", n),
      width = btn_width,
      text_font_size = 22,
      preselect = self.value == n,
      show_parent = self.show_parent or self,
      callback = function()
        self:_select(n)
      end,
    }
    self._buttons[n] = btn
    table.insert(row, btn)
    if n < 5 then
      table.insert(row, HorizontalSpan:new { width = span })
    end
  end
  self[1] = row
  self.dimen = row:getSize()
end

function Rating1to5:_select(n)
  if self.value == n and self.allow_clear then
    self.value = nil
  else
    self.value = n
  end
  self:_build()
  UIManager:setDirty(self.show_parent or self, "ui")
  if self.on_change then
    self.on_change(self.value)
  end
end

--- Set the value programmatically (no on_change fired).
function Rating1to5:setValue(v)
  self.value = v
  self:_build()
end

function Rating1to5:getValue()
  return self.value
end

return Rating1to5
