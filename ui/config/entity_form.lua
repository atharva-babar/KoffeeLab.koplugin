-- ui/config/entity_form.lua
-- Builds the add / edit form for a flat Configurator entity (bean, grinder,
-- ingredient, flavor tag) from a declarative field list, on top of the Phase 3
-- FormScreen + widget set. All persistence goes through a `config_service`
-- sub-table (`.create` / `.update` / `.set_active`) — the UI never touches a
-- repository (TECH_SOLUTION §3.2). Service validation errors are shown with an
-- InfoMessage and leave the form open so the user can fix the field.
--
--   EntityForm.build{
--     nav = nav,
--     title = _("Beans"),
--     service = ConfigService.beans,
--     entity = row_or_nil,                       -- nil => create
--     fields = {
--       { key = "roaster_name", label = _("Roaster"), kind = "text" },
--       { key = "name",         label = _("Name"),    kind = "text" },
--       { key = "roast_level",  label = _("Roast"),   kind = "pick",
--         options = Constants.ROAST_LEVELS, default = 3 },
--       { key = "min_value",    label = _("Minimum"), kind = "number",
--         min = 0, max = 1000, step = 1 },
--     },
--     on_saved = function() parent_list:reload() end,
--   }  -> FormScreen  (caller does Nav:push)

local ConfirmDialog = require("ui/widgets/confirm_dialog")
local FormScreen = require("ui/widgets/form_screen")
local InfoMessage = require("ui/widget/infomessage")
local ListPicker = require("ui/widgets/list_picker")
local NumberInput = require("ui/widgets/number_input")
local TextInput = require("ui/widgets/text_input")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local EntityForm = {}

local function label_for(options, value)
  for _i, opt in ipairs(options or {}) do
    if opt.value == value then
      return opt.label
    end
  end
  return value ~= nil and tostring(value) or nil
end

local function display_value(field, values)
  local v = values[field.key]
  if field.kind == "pick" then
    return label_for(field.options, v)
  end
  if v == nil or v == "" then
    return nil
  end
  if field.unit then
    return tostring(v) .. " " .. field.unit
  end
  return tostring(v)
end

local function edit_field(field, form)
  if field.kind == "text" then
    TextInput.show {
      title = field.label,
      value = form.values[field.key],
      hint = field.hint,
      on_ok = function(text)
        form:set(field.key, text ~= "" and text or nil)
      end,
    }
  elseif field.kind == "number" then
    NumberInput.show {
      title = field.label,
      value = form.values[field.key] or field.default or field.min or 0,
      min = field.min or 0,
      max = field.max or 100000,
      step = field.step or 1,
      unit = field.unit,
      precision = field.precision,
      on_ok = function(n)
        form:set(field.key, n)
      end,
    }
  elseif field.kind == "pick" then
    local items = {}
    for _i, opt in ipairs(field.options) do
      items[#items + 1] = { text = opt.label, value = opt.value }
    end
    ListPicker.show {
      title = field.label,
      items = items,
      current = form.values[field.key],
      on_select = function(value)
        form:set(field.key, value)
      end,
    }
  end
end

local function collect(fields, values)
  local payload = {}
  for _i, field in ipairs(fields) do
    payload[field.key] = values[field.key]
  end
  return payload
end

function EntityForm.build(opts)
  local editing = opts.entity ~= nil
  local values = {}
  for _i, field in ipairs(opts.fields) do
    if editing then
      values[field.key] = opts.entity[field.key]
    elseif field.default ~= nil then
      values[field.key] = field.default
    end
  end

  local form
  local function finish()
    if opts.on_saved then
      opts.on_saved()
    end
    if opts.nav then
      opts.nav:pop()
    else
      UIManager:close(form)
    end
  end

  local function save()
    local payload = collect(opts.fields, form.values)
    local ok, result
    if editing then
      ok, result = opts.service.update(opts.entity.id, payload)
    else
      ok, result = opts.service.create(payload)
    end
    if not ok then
      UIManager:show(InfoMessage:new { text = tostring(result), icon = "notice-warning" })
      return
    end
    finish()
  end

  local form_fields = {}
  for _i, field in ipairs(opts.fields) do
    form_fields[#form_fields + 1] = {
      key = field.key,
      label = field.label,
      display = function(v)
        return display_value(field, v)
      end,
      edit = function(f)
        edit_field(field, f)
      end,
    }
  end

  local actions = {
    { text = _("Save"), callback = save },
  }

  if editing then
    local active = tonumber(opts.entity.is_active) ~= 0
    actions[#actions + 1] = {
      text = active and _("Disable") or _("Enable"),
      callback = function()
        if active then
          ConfirmDialog.confirm {
            text = _("Disable this entry? Existing recipes keep it; it is hidden from new ones."),
            ok_text = _("Disable"),
            on_confirm = function()
              local ok, err = opts.service.set_active(opts.entity.id, false)
              if not ok then
                UIManager:show(InfoMessage:new { text = tostring(err), icon = "notice-warning" })
                return
              end
              finish()
            end,
          }
        else
          local ok, err = opts.service.set_active(opts.entity.id, true)
          if not ok then
            UIManager:show(InfoMessage:new { text = tostring(err), icon = "notice-warning" })
            return
          end
          finish()
        end
      end,
    }
  end

  form = FormScreen:new {
    title = opts.title,
    values = values,
    fields = form_fields,
    actions = actions,
  }
  return form
end

return EntityForm
