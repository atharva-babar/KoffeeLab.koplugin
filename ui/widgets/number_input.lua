-- ui/widgets/number_input.lua
-- NumberInput — pick a REAL value within min/max/step (TECH_SOLUTION §1.5
-- grinder ranges, §2.6 grind entry). Wraps KOReader's SpinWidget, which is
-- already e-ink-safe (discrete +/- , one repaint per press) and renders an
-- optional unit label.
--
--   NumberInput.show{
--     title = _("Grind setting"),
--     value = 15, min = 1, max = 30, step = 1,
--     unit = "clicks",              -- optional
--     precision = "%.1f",           -- optional; omit for integers
--     on_ok = function(value) ... end,
--     on_cancel = function() ... end,   -- optional
--   }

local SpinWidget = require("ui/widget/spinwidget")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local NumberInput = {}

function NumberInput.show(opts)
  assert(type(opts.on_ok) == "function", "NumberInput needs on_ok")
  local step = opts.step or 1
  local is_fractional = opts.precision ~= nil or (step % 1 ~= 0)

  local spin
  spin = SpinWidget:new {
    title_text = opts.title or _("Enter a number"),
    info_text = opts.info_text or _("Tap the number to type it"),
    value = opts.value or opts.min or 0,
    value_min = opts.min,
    value_max = opts.max,
    value_step = step,
    value_hold_step = opts.hold_step or (step * 5),
    precision = opts.precision or (is_fractional and "%.1f" or nil),
    unit = opts.unit,
    ok_text = opts.ok_text or _("Set"),
    ok_always_enabled = true,
    default_value = opts.default_value,
    callback = function(spin_widget)
      opts.on_ok(spin_widget.value)
    end,
    cancel_callback = function()
      if opts.on_cancel then
        opts.on_cancel()
      end
    end,
  }
  UIManager:show(spin)
  return spin
end

return NumberInput
