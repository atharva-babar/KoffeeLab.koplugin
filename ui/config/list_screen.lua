-- ui/config/list_screen.lua
-- A reusable scrolling full-screen list for a Configurator category
-- (TECH_SOLUTION §2.19). Rows are the entities the loader returns; the "+ Add"
-- verb lives on the bottom navbar (config_list preset). Tapping an entity runs
-- `on_edit(entity)`; the navbar Add cell runs `on_add()`.
--
-- Subclasses (see ui/config/flat_screen) override:
--   Screen:load()          -> array of entities, already sorted
--   Screen:row(entity)     -> text, mandatory
--   Screen:on_add()        -- navbar Add cell tapped
--   Screen:on_edit(entity) -- an entity row tapped
--
-- After a child form saves it calls `screen:reload()`.

local ScreenList = require("ui/screen_list")

local ListScreen = ScreenList:extend {
  name = "koffeelab_config_list",
  navbar = "config_list",
  empty_text = nil,
}

--- The navbar Add cell runs this category's add flow.
function ListScreen:onNavAdd()
  self:on_add()
end

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
  local items = {}
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
