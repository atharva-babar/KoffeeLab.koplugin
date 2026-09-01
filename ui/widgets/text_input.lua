-- ui/widgets/text_input.lua
-- TextInput — a single free-text value in a modal (TECH_SOLUTION §2.1). Thin
-- wrapper over KOReader's InputDialog with KoffeeLab's standard Cancel / Save
-- buttons and the on-screen keyboard opened for you.
--
--   TextInput.show{
--     title = _("Bean name"),
--     value = "Ethiopia Guji",         -- optional starting text
--     hint = _("e.g. Ethiopia Guji"),   -- optional placeholder
--     description = _("…"),             -- optional helper line
--     on_ok = function(text) ... end,   -- text is trimmed of surrounding space
--     on_cancel = function() ... end,   -- optional
--   }

local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local TextInput = {}

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function TextInput.show(opts)
  assert(type(opts.on_ok) == "function", "TextInput needs on_ok")
  local dialog
  dialog = InputDialog:new {
    title = opts.title or _("Enter text"),
    description = opts.description,
    input = opts.value or "",
    input_hint = opts.hint or "",
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
          text = _("Save"),
          is_enter_default = true,
          callback = function()
            local text = trim(dialog:getInputText() or "")
            UIManager:close(dialog)
            opts.on_ok(text)
          end,
        },
      },
    },
  }
  UIManager:show(dialog)
  dialog:onShowKeyboard()
  return dialog
end

return TextInput
