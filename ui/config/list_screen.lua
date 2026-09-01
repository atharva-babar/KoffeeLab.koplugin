-- ui/config/list_screen.lua
-- A reusable full-screen list for a Configurator category (TECH_SOLUTION §2.19).
-- Built on KOReader's Menu so pagination, large tap targets and Back come for
-- free. The first row is always "+ Add …"; the rest are the entities the loader
-- returns. Tapping an entity runs `on_edit(entity)`; tapping Add runs `on_add()`.
-- Hardware / gesture Back and the titlebar chevron all route to `Nav:pop()`.
--
-- Subclasses (see ui/config/flat_screen) override these methods:
--   Screen:load()          -> array of entities, already sorted
--   Screen:row(entity)     -> text, mandatory      (mandatory = right-aligned note)
--   Screen:on_add()        -- "+ Add" row tapped
--   Screen:on_edit(entity) -- an entity row tapped
--
-- After a child form saves it calls `screen:reload()` so the list repaints with
-- the new data.

local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local ListScreen = Menu:extend {
  name = "koffeelab_config_list",
  covers_fullscreen = true,
  is_borderless = true,
  is_popout = false,
  is_enable_shortcut = false,
  title_bar_left_icon = "chevron.left",
  with_bottom_line = true,
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

function ListScreen:init()
  self.item_table = self:_buildItems()
  Menu.init(self)
end

function ListScreen:_buildItems()
  local items = {
    {
      text = self.add_text or _("+ Add"),
      mandatory = "\u{203A}", -- ›
      _add = true,
    },
  }
  local rows = self:load() or {}
  if #rows == 0 and self.empty_text then
    items[#items + 1] = { text = self.empty_text, _disabled = true }
  end
  for _i, entity in ipairs(rows) do
    local text, mandatory = self:row(entity)
    items[#items + 1] = {
      text = text,
      mandatory = mandatory,
      _entity = entity,
    }
  end
  return items
end

--- Rebuild the list from the loader and repaint in place.
function ListScreen:reload()
  local keep = math.max(1, ((self.page or 1) - 1) * (self.perpage or 1) + 1)
  self:switchItemTable(nil, self:_buildItems(), keep)
end

function ListScreen:onMenuChoice(item)
  if item._disabled then
    return true
  end
  if item._add then
    self:on_add()
  elseif item._entity then
    self:on_edit(item._entity)
  end
  return true
end

function ListScreen:_back()
  if self.nav then
    self.nav:pop()
  else
    UIManager:close(self)
  end
  return true
end

ListScreen.onClose = ListScreen._back
ListScreen.onLeftButtonTap = ListScreen._back

return ListScreen
