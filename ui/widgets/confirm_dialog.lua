-- ui/widgets/confirm_dialog.lua
-- ConfirmDialog — a thin wrapper over KOReader's ConfirmBox with KoffeeLab's
-- standard wording for destructive / irreversible actions (TECH_SOLUTION §2.17,
-- §2.18, §3.12). Keeps the button labels and phrasing consistent everywhere.
--
--   ConfirmDialog.destructive{
--     text = _("Delete this recipe?"),
--     ok_text = _("Delete"),          -- optional; defaults to _("Delete")
--     on_confirm = function() ... end,
--     on_cancel = function() ... end, -- optional
--   }
--
--   ConfirmDialog.confirm{ text = ..., ok_text = ..., on_confirm = ... }
--   ConfirmDialog.blocked{ text = _("Used by 2 drinks.") }   -- info only, single OK

local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local ConfirmDialog = {}

local function show_box(opts)
  local box = ConfirmBox:new {
    text = opts.text,
    ok_text = opts.ok_text,
    cancel_text = opts.cancel_text or _("Cancel"),
    ok_callback = opts.on_confirm,
    cancel_callback = opts.on_cancel,
  }
  UIManager:show(box)
  return box
end

--- Neutral confirmation (e.g. discard unsaved edits).
function ConfirmDialog.confirm(opts)
  assert(type(opts.on_confirm) == "function", "ConfirmDialog needs on_confirm")
  return show_box {
    text = opts.text,
    ok_text = opts.ok_text or _("OK"),
    cancel_text = opts.cancel_text,
    on_confirm = opts.on_confirm,
    on_cancel = opts.on_cancel,
  }
end

--- Destructive confirmation — irreversible delete / overwrite.
function ConfirmDialog.destructive(opts)
  assert(type(opts.on_confirm) == "function", "ConfirmDialog needs on_confirm")
  return show_box {
    text = opts.text,
    ok_text = opts.ok_text or _("Delete"),
    cancel_text = opts.cancel_text,
    on_confirm = opts.on_confirm,
    on_cancel = opts.on_cancel,
  }
end

--- An action the service refused (e.g. "used by N drinks") — informational,
--- single dismiss button, no choice to make.
function ConfirmDialog.blocked(opts)
  local msg = InfoMessage:new {
    text = opts.text,
    icon = "notice-warning",
  }
  UIManager:show(msg)
  return msg
end

return ConfirmDialog
