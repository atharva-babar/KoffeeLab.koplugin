-- ui/config/method_form.lua
-- Build or edit a user brew method (TECH_SOLUTION §2.19): name, display icon
-- label, its parameters, the step types it allows, and its equipment. Everything
-- is held in an in-memory draft and written in one go through
-- `method_service.create` / `.update` (which runs a single transaction and the
-- §2.19 destructive-edit guard). System methods never reach this screen.
--
--   MethodForm:new{ method = existing_or_nil, on_saved = function() ... end }

local Constants = require("util/constants")
local FormScreen = require("ui/widgets/form_screen")
local InfoMessage = require("ui/widget/infomessage")
local ListPicker = require("ui/widgets/list_picker")
local Menu = require("ui/widget/menu")
local MethodService = require("services/method_service")
local TextInput = require("ui/widgets/text_input")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local DATA_TYPE_ITEMS = {}
for _i, dt in ipairs(Constants.PARAM_DATA_TYPES) do
  DATA_TYPE_ITEMS[#DATA_TYPE_ITEMS + 1] = { text = dt, value = dt }
end

local function slugify(name)
  local slug = tostring(name or ""):lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  return slug ~= "" and slug or "method"
end

-- ── one parameter ──────────────────────────────────────────────────────────────

local function edit_param(nav, param, on_done)
  local draft = {
    key = param and param.key,
    label = param and param.label,
    data_type = (param and param.data_type) or "text",
    unit = param and param.unit,
    required = param and tonumber(param.required) or 0,
  }
  local form
  local fields = {
    {
      key = "key",
      label = _("Key"),
      display = function(v)
        return v.key
      end,
      edit = function(f)
        TextInput.show {
          title = _("Parameter key"),
          value = f.values.key,
          hint = _("e.g. water_ratio"),
          on_ok = function(t)
            f:set("key", t ~= "" and t or nil)
          end,
        }
      end,
    },
    {
      key = "label",
      label = _("Label"),
      display = function(v)
        return v.label
      end,
      edit = function(f)
        TextInput.show {
          title = _("Parameter label"),
          value = f.values.label,
          on_ok = function(t)
            f:set("label", t ~= "" and t or nil)
          end,
        }
      end,
    },
    {
      key = "data_type",
      label = _("Type"),
      display = function(v)
        return v.data_type
      end,
      edit = function(f)
        ListPicker.show {
          title = _("Data type"),
          items = DATA_TYPE_ITEMS,
          current = f.values.data_type,
          on_select = function(v)
            f:set("data_type", v)
          end,
        }
      end,
    },
    {
      key = "unit",
      label = _("Unit"),
      display = function(v)
        return v.unit
      end,
      edit = function(f)
        TextInput.show {
          title = _("Unit (optional)"),
          value = f.values.unit,
          hint = _("e.g. g, s"),
          on_ok = function(t)
            f:set("unit", t ~= "" and t or nil)
          end,
        }
      end,
    },
    {
      key = "required",
      label = _("Required"),
      display = function(v)
        return v.required == 1 and _("Yes") or _("No")
      end,
      edit = function(f)
        ListPicker.show {
          title = _("Required"),
          items = { { text = _("No"), value = 0 }, { text = _("Yes"), value = 1 } },
          current = f.values.required,
          on_select = function(v)
            f:set("required", v)
          end,
        }
      end,
    },
  }

  local actions = {
    {
      text = _("Done"),
      callback = function()
        if
          not (draft.key and draft.key:match("%S")) or not (draft.label and draft.label:match("%S"))
        then
          UIManager:show(InfoMessage:new {
            text = _("A parameter needs a key and a label."),
            icon = "notice-warning",
          })
          return
        end
        on_done(draft)
        nav:pop()
      end,
    },
  }
  if param then
    actions[#actions + 1] = {
      text = _("Remove parameter"),
      callback = function()
        on_done(nil)
        nav:pop()
      end,
    }
  end

  form =
    FormScreen:new { title = _("Parameter"), values = draft, fields = fields, actions = actions }
  nav:push(form)
end

-- ── parameter list ─────────────────────────────────────────────────────────────

local ParamListScreen = Menu:extend {
  name = "koffeelab_method_params",
  covers_fullscreen = true,
  is_borderless = true,
  is_popout = false,
  is_enable_shortcut = false,
  with_bottom_line = true,
  title_bar_left_icon = "chevron.left",
  title = _("Parameters"),
  params = nil, -- shared array from the draft
  on_change = nil,
}

function ParamListScreen:init()
  self.item_table = self:_items()
  Menu.init(self)
end

function ParamListScreen:_items()
  local items = { { text = "+ " .. _("Add parameter"), _add = true } }
  for i, p in ipairs(self.params) do
    items[#items + 1] =
      { text = p.label or p.key or _("(unnamed)"), mandatory = p.data_type, _index = i }
  end
  return items
end

function ParamListScreen:_refresh()
  if self.on_change then
    self.on_change()
  end
  self:switchItemTable(nil, self:_items(), 1)
end

function ParamListScreen:onMenuChoice(item)
  if item._add then
    edit_param(self.nav, nil, function(draft)
      if draft then
        self.params[#self.params + 1] = draft
        self:_refresh()
      end
    end)
  elseif item._index then
    local idx = item._index
    edit_param(self.nav, self.params[idx], function(draft)
      if draft then
        self.params[idx] = draft
      else
        table.remove(self.params, idx)
      end
      self:_refresh()
    end)
  end
  return true
end

function ParamListScreen:_back()
  if self.nav then
    self.nav:pop()
  else
    UIManager:close(self)
  end
  return true
end

ParamListScreen.onClose = ParamListScreen._back
ParamListScreen.onLeftButtonTap = ParamListScreen._back

-- ── step-type picker (multi-select) ────────────────────────────────────────────

local StepPickerScreen = Menu:extend {
  name = "koffeelab_method_steps",
  covers_fullscreen = true,
  is_borderless = true,
  is_popout = false,
  is_enable_shortcut = false,
  with_bottom_line = true,
  title_bar_left_icon = "chevron.left",
  title = _("Allowed steps"),
  selected = nil, -- shared array of step_type strings
  on_change = nil,
}

function StepPickerScreen:init()
  self.item_table = self:_items()
  Menu.init(self)
end

function StepPickerScreen:_isSelected(step_type)
  for _i, st in ipairs(self.selected) do
    if st == step_type then
      return true
    end
  end
  return false
end

function StepPickerScreen:_items()
  local items = {}
  for _i, step_type in ipairs(Constants.STEP_TYPES) do
    local mark = self:_isSelected(step_type) and "\u{2713} " or "   "
    items[#items + 1] = {
      text = mark .. (Constants.STEP_TYPE_LABELS[step_type] or step_type),
      _step = step_type,
    }
  end
  return items
end

function StepPickerScreen:onMenuChoice(item)
  local step_type = item._step
  if self:_isSelected(step_type) then
    for i, st in ipairs(self.selected) do
      if st == step_type then
        table.remove(self.selected, i)
        break
      end
    end
  else
    self.selected[#self.selected + 1] = step_type
  end
  if self.on_change then
    self.on_change()
  end
  self:switchItemTable(nil, self:_items(), (self.page or 1))
  return true
end

function StepPickerScreen:_back()
  if self.nav then
    self.nav:pop()
  else
    UIManager:close(self)
  end
  return true
end

StepPickerScreen.onClose = StepPickerScreen._back
StepPickerScreen.onLeftButtonTap = StepPickerScreen._back

-- ── equipment list ────────────────────────────────────────────────────────────

local EquipmentListScreen = Menu:extend {
  name = "koffeelab_method_equipment",
  covers_fullscreen = true,
  is_borderless = true,
  is_popout = false,
  is_enable_shortcut = false,
  with_bottom_line = true,
  title_bar_left_icon = "chevron.left",
  title = _("Equipment"),
  equipment = nil, -- shared array of { name = ... }
  on_change = nil,
}

function EquipmentListScreen:init()
  self.item_table = self:_items()
  Menu.init(self)
end

function EquipmentListScreen:_items()
  local items = { { text = "+ " .. _("Add equipment"), _add = true } }
  for i, e in ipairs(self.equipment) do
    items[#items + 1] = { text = e.name, _index = i }
  end
  return items
end

function EquipmentListScreen:_refresh()
  if self.on_change then
    self.on_change()
  end
  self:switchItemTable(nil, self:_items(), 1)
end

function EquipmentListScreen:onMenuChoice(item)
  if item._add then
    TextInput.show {
      title = _("Equipment name"),
      on_ok = function(t)
        if t ~= "" then
          self.equipment[#self.equipment + 1] = { name = t }
          self:_refresh()
        end
      end,
    }
  elseif item._index then
    local idx = item._index
    TextInput.show {
      title = _("Equipment name"),
      value = self.equipment[idx].name,
      description = _("Clear the text to remove this item."),
      on_ok = function(t)
        if t == "" then
          table.remove(self.equipment, idx)
        else
          self.equipment[idx] = { name = t }
        end
        self:_refresh()
      end,
    }
  end
  return true
end

function EquipmentListScreen:_back()
  if self.nav then
    self.nav:pop()
  else
    UIManager:close(self)
  end
  return true
end

EquipmentListScreen.onClose = EquipmentListScreen._back
EquipmentListScreen.onLeftButtonTap = EquipmentListScreen._back

-- ── the method form itself ────────────────────────────────────────────────────

local MethodForm = FormScreen:extend {
  name = "koffeelab_method_form",
  method = nil, -- existing method row (edit) or nil (create)
  on_saved = nil,
}

function MethodForm:init()
  local m = self.method
  self.editing = m ~= nil
  self.title = self.editing and _("Edit Method") or _("New Method")

  local draft = {
    name = m and m.name,
    icon = m and m.icon,
    parameters = {},
    step_types = {},
    equipment = {},
  }
  if m then
    for _i, p in ipairs(m.parameters or {}) do
      draft.parameters[#draft.parameters + 1] = {
        key = p.key,
        label = p.label,
        data_type = p.data_type,
        unit = p.unit,
        required = tonumber(p.required) or 0,
      }
    end
    for _i, st in ipairs(m.step_types or {}) do
      draft.step_types[#draft.step_types + 1] = st.step_type
    end
    for _i, e in ipairs(m.equipment or {}) do
      draft.equipment[#draft.equipment + 1] = { name = e.name }
    end
  end
  self.values = draft

  self.fields = {
    {
      key = "name",
      label = _("Name"),
      display = function(v)
        return v.name
      end,
      edit = function(form)
        TextInput.show {
          title = _("Method name"),
          value = form.values.name,
          hint = _("e.g. Moka Pot"),
          on_ok = function(t)
            form:set("name", t ~= "" and t or nil)
          end,
        }
      end,
    },
    {
      key = "icon",
      label = _("Icon label"),
      display = function(v)
        return v.icon
      end,
      edit = function(form)
        TextInput.show {
          title = _("Icon label"),
          description = _("A short text badge shown on the method card, e.g. MP."),
          value = form.values.icon,
          on_ok = function(t)
            form:set("icon", t ~= "" and t or nil)
          end,
        }
      end,
    },
    {
      key = "parameters",
      label = _("Parameters"),
      display = function(v)
        return tostring(#v.parameters)
      end,
      edit = function(form)
        form.nav:push(ParamListScreen:new {
          params = form.values.parameters,
          on_change = function()
            form:refreshItems()
          end,
        })
      end,
    },
    {
      key = "step_types",
      label = _("Allowed steps"),
      display = function(v)
        return tostring(#v.step_types)
      end,
      edit = function(form)
        form.nav:push(StepPickerScreen:new {
          selected = form.values.step_types,
          on_change = function()
            form:refreshItems()
          end,
        })
      end,
    },
    {
      key = "equipment",
      label = _("Equipment"),
      display = function(v)
        return tostring(#v.equipment)
      end,
      edit = function(form)
        form.nav:push(EquipmentListScreen:new {
          equipment = form.values.equipment,
          on_change = function()
            form:refreshItems()
          end,
        })
      end,
    },
  }

  self.actions = {
    {
      text = _("Save method"),
      callback = function(form)
        form:_save()
      end,
    },
  }

  FormScreen.init(self)
end

function MethodForm:_save()
  local d = self.values
  local payload = {
    name = d.name,
    icon = d.icon,
    parameters = d.parameters,
    step_types = d.step_types,
    equipment = d.equipment,
  }

  local ok, result
  if self.editing then
    ok, result = MethodService.update(self.method.id, { name = d.name, icon = d.icon }, {
      parameters = d.parameters,
      step_types = d.step_types,
      equipment = d.equipment,
    })
  else
    payload.slug = slugify(d.name)
    ok, result = MethodService.create(payload)
  end

  if not ok then
    UIManager:show(InfoMessage:new { text = tostring(result), icon = "notice-warning" })
    return
  end
  if self.on_saved then
    self.on_saved()
  end
  if self.nav then
    self.nav:pop()
  else
    UIManager:close(self)
  end
end

MethodForm._ParamListScreen = ParamListScreen
MethodForm._StepPickerScreen = StepPickerScreen
MethodForm._EquipmentListScreen = EquipmentListScreen
MethodForm._slugify = slugify

return MethodForm
