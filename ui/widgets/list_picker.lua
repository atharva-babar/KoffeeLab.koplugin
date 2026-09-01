-- ui/widgets/list_picker.lua
-- ListPicker — a full-screen modal single-select list (TECH_SOLUTION §2.1 rule
-- 8: prefer modal selection dialogs to small dropdown arrows). Thin wrapper over
-- KOReader's Menu: paginated, large rows, hardware/gesture Back and the titlebar
-- chevron all cancel.
--
--   ListPicker.show{
--     title = _("Select bean"),
--     items = { { text = "Ethiopia Guji", value = 3 }, ... },
--     current = 3,                 -- optional; marks the active row
--     on_select = function(value, item) ... end,
--     on_cancel = function() ... end,        -- optional
--     extra = { text = _("+ Add New Bean"), callback = function() ... end },  -- optional footer action
--   }

local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local ListPicker = {}

function ListPicker.show(opts)
  assert(type(opts.on_select) == "function", "ListPicker needs on_select")
  local item_table = {}

  for _, entry in ipairs(opts.items or {}) do
    local text = entry.text or tostring(entry.value)
    if opts.current ~= nil and entry.value == opts.current then
      text = "\u{2713} " .. text -- check mark on the active row
    end
    table.insert(item_table, {
      text = text,
      _value = entry.value,
      _item = entry,
    })
  end

  if opts.extra then
    table.insert(item_table, {
      text = opts.extra.text,
      _extra = true,
    })
  end

  local menu
  menu = Menu:new {
    title = opts.title or _("Select"),
    item_table = item_table,
    is_borderless = true,
    is_popout = false,
    is_enable_shortcut = false,
    covers_fullscreen = true,
    title_bar_left_icon = "chevron.left",
    onMenuChoice = function(_, item)
      if item._extra then
        UIManager:close(menu)
        opts.extra.callback()
      else
        UIManager:close(menu)
        opts.on_select(item._value, item._item)
      end
      return true
    end,
    onLeftButtonTap = function()
      UIManager:close(menu)
      if opts.on_cancel then
        opts.on_cancel()
      end
      return true
    end,
  }
  -- Back key / Back gesture: cancel (Menu:onClose has submenu logic we don't need)
  menu.onClose = function()
    UIManager:close(menu)
    if opts.on_cancel then
      opts.on_cancel()
    end
    return true
  end

  UIManager:show(menu)
  return menu
end

return ListPicker
