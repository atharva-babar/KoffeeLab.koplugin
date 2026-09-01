-- ui/config/method_detail.lua
-- Read-only view of one brew method (TECH_SOLUTION §2.19): its parameters, the
-- step types it allows, and its equipment, plus activate / deactivate and — for
-- user methods — an Edit action. System methods are never editable here; the
-- destructive-edit guard itself lives in `method_service` / the repo.
--
-- Built on Menu: informational rows are inert, the trailing rows are the actions.

local Constants = require("util/constants")
local ConfirmDialog = require("ui/widgets/confirm_dialog")
local InfoMessage = require("ui/widget/infomessage")
local MethodService = require("services/method_service")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local DATA_TYPE_LABELS = {
  int = _("number"),
  real = _("decimal"),
  text = _("text"),
  bool = _("yes / no"),
  duration = _("duration"),
}

local MethodDetail = Menu:extend {
  name = "koffeelab_method_detail",
  covers_fullscreen = true,
  is_borderless = true,
  is_popout = false,
  is_enable_shortcut = false,
  with_bottom_line = true,
  title_bar_left_icon = "chevron.left",
  method = nil, -- required: a nested method row from method_service
  on_changed = nil, -- optional: called after activate / deactivate / edit
}

function MethodDetail:init()
  self.title = self.method.name
  self.item_table = self:_buildItems()
  Menu.init(self)
end

function MethodDetail:_reloadMethod()
  local ok, fresh = MethodService.get(self.method.id)
  if ok then
    self.method = fresh
  end
  self:switchItemTable(self.method.name, self:_buildItems(), 1)
end

function MethodDetail:_buildItems()
  local m = self.method
  local system = tonumber(m.is_system) == 1
  local active = tonumber(m.is_active) ~= 0
  local items = {
    { text = _("Type"), mandatory = system and _("System") or _("Custom") },
    { text = _("Status"), mandatory = active and _("Active") or _("Disabled") },
  }
  if m.icon and m.icon ~= "" then
    items[#items + 1] = { text = _("Icon"), mandatory = m.icon }
  end

  items[#items + 1] = { text = _("Parameters"), mandatory = tostring(#m.parameters), _head = true }
  if #m.parameters == 0 then
    items[#items + 1] = { text = "  " .. _("(none)") }
  end
  for _i, p in ipairs(m.parameters) do
    local note = DATA_TYPE_LABELS[p.data_type] or p.data_type
    if p.unit and p.unit ~= "" then
      note = note .. " · " .. p.unit
    end
    if tonumber(p.required) == 1 then
      note = note .. " · " .. _("required")
    end
    items[#items + 1] = { text = "  " .. p.label .. "  (" .. p.key .. ")", mandatory = note }
  end

  items[#items + 1] =
    { text = _("Steps allowed"), mandatory = tostring(#m.step_types), _head = true }
  for _i, st in ipairs(m.step_types) do
    items[#items + 1] = {
      text = "  " .. (Constants.STEP_TYPE_LABELS[st.step_type] or st.step_type),
    }
  end

  items[#items + 1] = { text = _("Equipment"), mandatory = tostring(#m.equipment), _head = true }
  for _i, e in ipairs(m.equipment) do
    items[#items + 1] = { text = "  " .. e.name }
  end

  items[#items + 1] = {
    text = active and _("Deactivate method") or _("Activate method"),
    mandatory = "\u{203A}",
    _action = "toggle",
  }
  if not system then
    items[#items + 1] = { text = _("Edit method"), mandatory = "\u{203A}", _action = "edit" }
  end
  return items
end

function MethodDetail:_setActive(active)
  local ok, err = MethodService.set_active(self.method.id, active)
  if not ok then
    UIManager:show(InfoMessage:new { text = tostring(err), icon = "notice-warning" })
    return
  end
  if self.on_changed then
    self.on_changed()
  end
  self:_reloadMethod()
end

function MethodDetail:onMenuChoice(item)
  if item._action == "toggle" then
    local active = tonumber(self.method.is_active) ~= 0
    if active then
      ConfirmDialog.confirm {
        text = _(
          "Deactivate this method? Existing recipes keep it; it is hidden from the Add Recipe method list."
        ),
        ok_text = _("Deactivate"),
        on_confirm = function()
          self:_setActive(false)
        end,
      }
    else
      self:_setActive(true)
    end
  elseif item._action == "edit" then
    local MethodForm = require("ui/config/method_form")
    self.nav:push(MethodForm:new {
      method = self.method,
      on_saved = function()
        if self.on_changed then
          self.on_changed()
        end
        self:_reloadMethod()
      end,
    })
  end
  return true
end

function MethodDetail:_back()
  if self.nav then
    self.nav:pop()
  else
    UIManager:close(self)
  end
  return true
end

MethodDetail.onClose = MethodDetail._back
MethodDetail.onLeftButtonTap = MethodDetail._back

return MethodDetail
