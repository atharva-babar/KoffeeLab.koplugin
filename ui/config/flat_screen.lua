-- ui/config/flat_screen.lua
-- Wires a ListScreen + editor for one flat Configurator entity.
-- Single-text-field entities (ingredients, flavor tags) get a one-shot TextInput
-- dialog; multi-field entities (beans, grinders) push a full EntityForm.

local EntityForm = require("ui/config/entity_form")
local InfoMessage = require("ui/widget/infomessage")
local ListScreen = require("ui/config/list_screen")
local TextInput = require("ui/widgets/text_input")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local FlatScreen = {}

local function default_row(entity)
  return entity.name, tonumber(entity.is_active) == 0 and _("disabled") or nil
end

local function is_single_text(fields)
  return #fields == 1 and (fields[1].kind == "text" or fields[1].kind == nil)
end

function FlatScreen.define(cfg)
  local Screen = ListScreen:extend {
    name = cfg.name,
    title = cfg.title,
    add_text = cfg.add_text or ("+ " .. _("Add") .. " " .. (cfg.singular or cfg.title)),
    empty_text = cfg.empty_text,
  }
  local single = is_single_text(cfg.fields)
  local field = cfg.fields[1]

  function Screen:load()
    local ok, rows = cfg.service.list { include_inactive = true }
    return ok and rows or {}
  end

  function Screen:row(entity)
    return (cfg.row or default_row)(entity)
  end

  function Screen:on_add()
    if single then
      TextInput.show {
        title = _("New ") .. (cfg.singular or cfg.title),
        hint = field.hint,
        on_ok = function(text)
          if text == "" then
            return
          end
          local ok, res = cfg.service.create { [field.key] = text }
          if not ok then
            UIManager:show(InfoMessage:new { text = tostring(res), icon = "notice-warning" })
            return
          end
          self:reload()
        end,
      }
      return
    end
    self.nav:push(EntityForm.build {
      nav = self.nav,
      title = _("New ") .. (cfg.singular or cfg.title),
      service = cfg.service,
      fields = cfg.fields,
      on_saved = function()
        self:reload()
      end,
    })
  end

  function Screen:on_edit(entity)
    if single then
      TextInput.show {
        title = _("Rename ") .. (cfg.singular or cfg.title),
        value = entity[field.key],
        hint = field.hint,
        on_ok = function(text)
          if text == "" or text == entity[field.key] then
            return
          end
          local ok, res = cfg.service.update(entity.id, { [field.key] = text })
          if not ok then
            UIManager:show(InfoMessage:new { text = tostring(res), icon = "notice-warning" })
            return
          end
          self:reload()
        end,
      }
      return
    end
    self.nav:push(EntityForm.build {
      nav = self.nav,
      title = _("Edit ") .. (cfg.singular or cfg.title),
      service = cfg.service,
      entity = entity,
      fields = cfg.fields,
      on_saved = function()
        self:reload()
      end,
    })
  end

  return Screen
end

return FlatScreen
