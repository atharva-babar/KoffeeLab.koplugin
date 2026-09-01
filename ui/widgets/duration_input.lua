-- ui/widgets/duration_input.lua
-- DurationInput — enter a duration as free text and store integer seconds
-- (TECH_SOLUTION §1.15, §2.9). Accepts "2:45", "1:02:03", "90" (bare seconds),
-- "15 min" / "15m", "2 h" / "1.5h" — the multi-hour forms Cold Brew needs. The
-- parse rules live in util/format so they are spec-tested; this widget is just
-- the InputDialog around them and the "that's not a duration" guard.
--
--   DurationInput.show{
--     title = _("Bloom time"),
--     value_sec = 30,                 -- optional starting value
--     on_ok = function(seconds) ... end,
--     on_cancel = function() ... end, -- optional
--   }

local Format = require("util/format")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local DurationInput = {}

function DurationInput.show(opts)
  assert(type(opts.on_ok) == "function", "DurationInput needs on_ok")
  local dialog
  dialog = InputDialog:new {
    title = opts.title or _("Enter a duration"),
    description = _("e.g. 2:45, 90 (seconds), 15 min, 2 h"),
    input = opts.value_sec and Format.duration(opts.value_sec) or "",
    input_hint = "2:45",
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
          text = _("Set"),
          is_enter_default = true,
          callback = function()
            local text = dialog:getInputText()
            local seconds = Format.parse_duration(text)
            if seconds == nil then
              UIManager:show(InfoMessage:new {
                text = _("Not a valid duration. Try 2:45, 90, 15 min or 2 h."),
              })
              return
            end
            UIManager:close(dialog)
            opts.on_ok(seconds)
          end,
        },
      },
    },
  }
  UIManager:show(dialog)
  dialog:onShowKeyboard()
  return dialog
end

return DurationInput
