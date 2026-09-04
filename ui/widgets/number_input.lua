-- ui/widgets/number_input.lua
-- NumberInput — enter a REAL value within min/max/step by typing it (TECH_SOLUTION
-- §1.5 grinder ranges, §2.6 grind entry). A plain numeric text field (InputDialog
-- with the number keyboard) — no +/- steppers. The entered value is parsed and
-- clamped to [min, max]; the allowed range and unit are shown as the description.
--
--   NumberInput.show{
--     title = _("Grind setting"),
--     value = 15, min = 1, max = 30, step = 1,
--     unit = "clicks",              -- optional
--     precision = "%.1f",           -- optional; omit for integers
--     on_ok = function(value) ... end,
--     on_cancel = function() ... end,   -- optional
--   }

local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local NumberInput = {}

local function clamp(v, lo, hi)
  if lo and v < lo then
    return lo
  end
  if hi and v > hi then
    return hi
  end
  return v
end

function NumberInput.show(opts)
  assert(type(opts.on_ok) == "function", "NumberInput needs on_ok")
  local step = opts.step or 1
  local fractional = opts.precision ~= nil or (step % 1 ~= 0)
  local fmt = opts.precision or (fractional and "%.1f" or "%d")

  local function display(n)
    if n == nil then
      return ""
    end
    return fractional and string.format(fmt, n) or tostring(math.floor(n + 0.5))
  end

  -- description: the allowed range (+ unit), then any caller info line
  local range
  if opts.min ~= nil and opts.max ~= nil then
    range = string.format("%s–%s", display(opts.min), display(opts.max))
  elseif opts.min ~= nil then
    range = string.format("≥ %s", display(opts.min))
  elseif opts.max ~= nil then
    range = string.format("≤ %s", display(opts.max))
  end
  if range and opts.unit and opts.unit ~= "" then
    range = range .. " " .. opts.unit
  end
  local description = range
  if opts.info_text and opts.info_text ~= "" then
    description = range and (range .. "\n" .. opts.info_text) or opts.info_text
  end

  local dialog
  dialog = InputDialog:new {
    title = opts.title or _("Enter a number"),
    description = description,
    input = display(opts.value or opts.default_value or opts.min),
    input_type = "number",
    buttons = {
      {
        {
          text = _("Cancel"),
          id = "close",
          callback = function()
            UIManager:close(dialog)
            if opts.on_cancel then
              opts.on_cancel()
            end
          end,
        },
        {
          text = opts.ok_text or _("Set"),
          is_enter_default = true,
          callback = function()
            local n = tonumber(dialog:getInputText())
            UIManager:close(dialog)
            if n == nil then
              if opts.on_cancel then
                opts.on_cancel()
              end
              return
            end
            n = clamp(n, opts.min, opts.max)
            if not fractional then
              n = math.floor(n + 0.5)
            end
            opts.on_ok(n)
          end,
        },
      },
    },
  }
  UIManager:show(dialog)
  dialog:onShowKeyboard()
  return dialog
end

return NumberInput
