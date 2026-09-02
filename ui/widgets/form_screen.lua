-- ui/widgets/form_screen.lua
-- FormScreen — a scrolling list of labelled rows for long forms (TECH_SOLUTION
-- §2.1 rules 7/11). Each row shows `LABEL ............. current value`; tapping it
-- runs the field's editor (a ListPicker / NumberInput / DurationInput / …), which
-- writes back into `self.values` and calls `self:refreshItems()`. Built on
-- ui/screen_list so it scrolls (no pagination bar) and Back handling comes from
-- ScreenBase.
--
--   local screen = FormScreen:new{
--     title = _("New Pour Over"),
--     values = draft,                       -- table the fields read/write
--     fields = {
--       { key = "title", label = _("Title"),
--         display = function(v) return v.title end,
--         edit = function(form) ... form:set("title", text) end },
--     },
--     actions = {                            -- optional footer rows
--       { text = _("Save"), callback = function(form) ... end },
--     },
--     on_back = function() ... end,          -- optional; default Nav:pop
--   }
--   Nav:push(screen)

local ScreenBase = require("ui/screen_base")
local ScreenList = require("ui/screen_list")
local _ = require("gettext")

local FormScreen = ScreenList:extend {
  name = "koffeelab_form",
  fields = nil,
  values = nil,
  actions = nil,
  on_back = nil,
}

function FormScreen:init()
  self.values = self.values or {}
  self.fields = self.fields or {}
  ScreenList.init(self)
end

function FormScreen:buildItems()
  local items = {}
  for _idx, field in ipairs(self.fields) do -- luacheck: ignore _idx
    local value_str = field.display and field.display(self.values)
    items[#items + 1] = {
      text = field.label,
      mandatory = value_str and tostring(value_str) or _("\u{2014}"),
      _field = field,
      callback = field.edit and function()
        field.edit(self)
      end or nil,
    }
  end
  for _idx, action in ipairs(self.actions or {}) do -- luacheck: ignore _idx
    items[#items + 1] = {
      text = action.text,
      mandatory = "\u{203A}", -- ›
      _action = action,
      callback = function()
        action.callback(self)
      end,
    }
  end
  return items
end

--- Update one draft value and repaint the list.
function FormScreen:set(key, value)
  self.values[key] = value
  self:refreshItems()
end

function FormScreen:refreshItems()
  self:refresh()
end

--- Kept for parity with the old Menu API (specs call this directly).
function FormScreen:onMenuChoice(item)
  if item._action then
    item._action.callback(self)
  elseif item._field and item._field.edit then
    item._field.edit(self)
  end
  return true
end

function FormScreen:_goBack()
  if self.on_back then
    self.on_back()
    return true
  end
  return ScreenBase._goBack(self)
end

return FormScreen
