-- ui/widgets/grind_dial.lua
-- A modal grind-setting picker: a segmented ButtonProgressWidget with −/+ fine
-- tune and a "⋮" that opens the keyboard (NumberInput) for an exact value. Maps
-- the button position to `min + (pos-1) * step`, clamped to [min, max]. Matches
-- the "- +/<>" control the user asked for and stays e-ink safe (one repaint per
-- press).
--
--   GrindDial.show{
--     value = 15, min = 1, max = 30, step = 1,
--     default = 15,                 -- optional: the grinder's mid / default
--     unit = "clicks",              -- optional
--     on_change = function(value) ... end,   -- fired on every adjustment
--   }

local ButtonProgressWidget = require("ui/widget/buttonprogresswidget")
local CenterContainer = require("ui/widget/container/centercontainer")
local Design = require("ui/design")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local MovableContainer = require("ui/widget/container/movablecontainer")
local NumberInput = require("ui/widgets/number_input")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")
local Format = require("util/format")
local Screen = Device.screen

local GrindDial = {}

local function clamp(v, lo, hi)
  if lo and v < lo then
    return lo
  end
  if hi and v > hi then
    return hi
  end
  return v
end

function GrindDial.show(opts)
  local step = opts.step or 1
  local lo, hi = opts.min or 0, opts.max or (opts.value or 0)
  local span = math.max(hi - lo, step)
  -- one segment per step, capped at 12; wide ranges get an even stride and the
  -- −/+ fine-tune buttons (and ⋮ keyboard) cover the values between segments
  local n = math.max(2, math.min(math.floor(span / step) + 1, 12))
  local stride = span / (n - 1)

  local function snap(value)
    return clamp(lo + math.floor((value - lo) / step + 0.5) * step, lo, hi)
  end
  local function pos_for(value)
    return clamp(math.floor((value - lo) / stride + 0.5) + 1, 1, n)
  end
  local function value_for(pos)
    return snap(lo + (pos - 1) * stride)
  end

  local dialog
  local value = clamp(opts.value or lo, lo, hi)

  local label = TextWidget:new {
    text = Format.grind(value, opts.unit) or tostring(value),
    face = Design.face("title"),
  }
  local progress
  local function apply(new_value)
    value = clamp(new_value, lo, hi)
    label:setText(Format.grind(value, opts.unit) or tostring(value))
    progress:setPosition(pos_for(value), opts.default and pos_for(opts.default) or nil)
    UIManager:setDirty(dialog, "ui")
    if opts.on_change then
      opts.on_change(value)
    end
  end

  progress = ButtonProgressWidget:new {
    width = math.floor(Screen:getWidth() * 0.8),
    font_size = 20,
    num_buttons = n,
    position = pos_for(value),
    default_position = opts.default and pos_for(opts.default) or nil,
    fine_tune = true,
    more_options = true,
    thin_grey_style = true,
    callback = function(arg)
      if arg == "-" then
        apply(value - step)
      elseif arg == "+" then
        apply(value + step)
      elseif arg == "\u{22EE}" then
        NumberInput.show {
          title = _("Grind setting"),
          info_text = _("Tap the number to type it"),
          value = value,
          min = lo,
          max = hi,
          step = step,
          unit = opts.unit,
          precision = (step % 1 ~= 0) and "%.1f" or nil,
          on_ok = function(exact)
            apply(exact)
          end,
        }
      elseif type(arg) == "number" then
        apply(value_for(arg))
      end
    end,
  }

  local content = FrameContainer:new {
    background = Design.color.bg,
    bordersize = Design.border,
    radius = 8,
    padding = Design.pad.lg,
    VerticalGroup:new {
      align = "center",
      label,
      VerticalSpan:new { width = Design.pad.md },
      progress,
      VerticalSpan:new { width = Design.pad.sm },
      TextWidget:new {
        text = _("Swipe down to close"),
        face = Design.face("label"),
        fgcolor = Design.color.muted,
      },
    },
  }

  dialog = InputContainer:new {
    CenterContainer:new {
      dimen = Geom:new { w = Screen:getWidth(), h = Screen:getHeight() },
      MovableContainer:new { content },
    },
  }
  dialog.ges_events.TapClose = {
    GestureRange:new {
      ges = "tap",
      range = Geom:new { x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() },
    },
  }
  dialog.onTapClose = function()
    UIManager:close(dialog)
    return true
  end
  dialog.onClose = dialog.onTapClose
  dialog.onAnyKeyPressed = dialog.onTapClose

  -- test hooks
  dialog._progress = progress
  dialog._adjust = function(arg)
    progress.callback(arg)
  end
  dialog._value = function()
    return value
  end

  UIManager:show(dialog)
  return dialog
end

return GrindDial
