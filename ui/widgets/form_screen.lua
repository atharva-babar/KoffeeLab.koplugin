-- ui/widgets/form_screen.lua
-- FormScreen — a vertically ordered list of labelled rows for long forms
-- (TECH_SOLUTION §2.1 rules 7/11, §3.15 "divide long forms into pages"). Built
-- on KOReader's Menu so pagination, large tap targets and Back handling come for
-- free. Each row shows `LABEL .............. current value`; tapping it runs the
-- field's editor (a ListPicker / NumberInput / DurationInput / …), which writes
-- back into `self.values` and calls `self:refreshItems()`.
--
--   local screen = FormScreen:new{
--     title = _("New Pour Over"),
--     values = draft,                       -- table the fields read/write
--     fields = {
--       { key = "title", label = _("Title"),
--         display = function(v) return v.title end,
--         edit = function(form) ... form:set("title", text); end },
--       { key = "dose_g", label = _("Dose"),
--         display = function(v) return v.dose_g and (v.dose_g .. " g") end,
--         edit = function(form) NumberInput.show{ ... on_ok = function(n) form:set("dose_g", n) end } end },
--     },
--     actions = {                            -- optional footer rows
--       { text = _("Save"), callback = function(form) ... end },
--     },
--   }
--   Nav:push(screen)

local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local FormScreen = Menu:extend {
  name = "koffeelab_form",
  covers_fullscreen = true,
  is_borderless = true,
  is_popout = false,
  is_enable_shortcut = false, -- no keyboard shortcut column on e-ink
  title_bar_left_icon = "chevron.left",
  fields = nil,
  values = nil,
  actions = nil,
  -- called after Back (gesture / key / chevron); defaults to Nav:pop when nav is set
  on_back = nil,
}

function FormScreen:init()
  self.values = self.values or {}
  self.fields = self.fields or {}
  self.item_table = self:_buildItems()
  Menu.init(self)
end

function FormScreen:_buildItems()
  local items = {}
  -- NB: do not use `_` as the loop variable here — it shadows the gettext `_`
  -- that the `_("—")` fallback below needs.
  for _idx, field in ipairs(self.fields) do -- luacheck: ignore _idx
    local value_str
    if field.display then
      value_str = field.display(self.values)
    end
    table.insert(items, {
      text = field.label,
      mandatory = value_str and tostring(value_str) or _("—"),
      _field = field,
    })
  end
  for _idx, action in ipairs(self.actions or {}) do -- luacheck: ignore _idx
    table.insert(items, {
      text = action.text,
      mandatory = "\u{203A}", -- ›
      _action = action,
    })
  end
  return items
end

--- Update one draft value and repaint the list.
function FormScreen:set(key, value)
  self.values[key] = value
  self:refreshItems()
end

function FormScreen:refreshItems()
  -- keep the reader on the page they were editing
  local keep = math.max(1, ((self.page or 1) - 1) * (self.perpage or 1) + 1)
  self:switchItemTable(nil, self:_buildItems(), keep)
end

function FormScreen:onMenuChoice(item)
  if item._action then
    item._action.callback(self)
  elseif item._field and item._field.edit then
    item._field.edit(self)
  end
  return true
end

function FormScreen:_back()
  if self.on_back then
    self.on_back()
  elseif self.nav then
    self.nav:pop()
  else
    UIManager:close(self)
  end
  return true
end

FormScreen.onClose = FormScreen._back
FormScreen.onLeftButtonTap = FormScreen._back

return FormScreen
