-- ui/config/list_screen.lua
-- A reusable scrolling full-screen list for a Configurator category
-- (TECH_SOLUTION §2.19). The first row is always "+ Add …"; the rest are the
-- entities the loader returns. Tapping an entity runs `on_edit(entity)`; tapping
-- Add runs `on_add()`.
--
-- Subclasses (see ui/config/flat_screen) override:
--   Screen:load()          -> array of entities, already sorted
--   Screen:row(entity)     -> text, mandatory
--   Screen:on_add()        -- "+ Add" row tapped
--   Screen:on_edit(entity) -- an entity row tapped
--
-- After a child form saves it calls `screen:reload()`.

local ScreenList = require("ui/screen_list")
local _ = require("gettext")

local ListScreen = ScreenList:extend {
  name = "koffeelab_config_list",
  add_text = nil,
  empty_text = nil,
}

--- Override in a subclass: return the array of entities to list.
function ListScreen:load()
  return {}
end

--- Override in a subclass: return `text, mandatory` for one entity row.
function ListScreen:row(entity)
  return tostring(entity), nil
end

--- Override in a subclass.
function ListScreen:on_add() end

--- Override in a subclass.
function ListScreen:on_edit(entity) end -- luacheck: ignore entity

function ListScreen:buildItems()
  local items = {
    {
      text = self.add_text or _("+ Add"),
      mandatory = "\u{203A}", -- ›
      _add = true,
      callback = function()
        self:on_add()
      end,
    },
  }
  local rows = self:load() or {}
  if #rows == 0 and self.empty_text then
    items[#items + 1] = { text = self.empty_text, kind = "text", _disabled = true }
  end
  for _i, entity in ipairs(rows) do -- luacheck: ignore _i
    local text, mandatory = self:row(entity)
    items[#items + 1] = {
      text = text,
      mandatory = mandatory,
      _entity = entity,
      callback = function()
        self:on_edit(entity)
      end,
    }
  end
  return items
end

--- Rebuild the list from the loader and repaint once.
ListScreen.reload = ListScreen.refresh

return ListScreen
