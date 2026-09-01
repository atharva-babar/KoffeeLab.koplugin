-- ui/config/flat_screen.lua
-- Factory that wires a ListScreen + EntityForm pair for one of the flat
-- Configurator entities (beans, grinders, ingredients, flavor tags). The four
-- category modules differ only in their title, field list and row formatting, so
-- they each just call `FlatScreen.define{…}` and return the result.
--
--   return require("ui/config/flat_screen").define{
--     name = "koffeelab_config_beans",
--     title = _("Beans"),
--     singular = _("Bean"),
--     service = require("services/config_service").beans,
--     fields = { … EntityForm field specs … },
--     row = function(entity) return text, mandatory end,   -- optional
--     empty_text = _("No beans yet. Tap “+ Add Bean”."),    -- optional
--   }

local EntityForm = require("ui/config/entity_form")
local ListScreen = require("ui/config/list_screen")
local _ = require("gettext")

local FlatScreen = {}

local function default_row(entity)
  local note = tonumber(entity.is_active) == 0 and _("disabled") or nil
  return entity.name, note
end

function FlatScreen.define(cfg)
  local Screen = ListScreen:extend {
    name = cfg.name,
    title = cfg.title,
    add_text = cfg.add_text or ("+ " .. _("Add") .. " " .. (cfg.singular or cfg.title)),
    empty_text = cfg.empty_text,
  }

  function Screen:load()
    local ok, rows = cfg.service.list { include_inactive = true }
    return ok and rows or {}
  end

  function Screen:row(entity)
    return (cfg.row or default_row)(entity)
  end

  function Screen:on_add()
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
