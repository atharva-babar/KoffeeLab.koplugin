-- ui/configurator.lua
-- The Configurator category list (TECH_SOLUTION §2.19): the entities recipes and
-- drinks depend on. Each row pushes its own management screen through Nav.

local ConfirmDialog = require("ui/widgets/confirm_dialog")
local InfoMessage = require("ui/widget/infomessage")
local Nav = require("ui/nav")
local ScreenList = require("ui/screen_list")
local UIManager = require("ui/uimanager")
local Version = require("version")
local _ = require("gettext")

local Configurator = ScreenList:extend {
  name = "koffeelab_configurator",
  title = _("Configurator"),
  navbar = "configurator",
}

-- module path -> title, loaded lazily so a broken feature screen cannot stop the
-- Configurator itself from opening.
local CATEGORIES = {
  { title = _("Beans"), module = "ui/config/beans" },
  { title = _("Grinders"), module = "ui/config/grinders" },
  { title = _("Ingredients"), module = "ui/config/ingredients" },
  { title = _("Flavor Tags"), module = "ui/config/flavor_tags" },
  { title = _("Backup & Restore"), module = "ui/backup" },
}

function Configurator:buildItems()
  local items = {}
  for _i, cat in ipairs(CATEGORIES) do -- luacheck: ignore _i
    items[#items + 1] = {
      text = cat.title,
      mandatory = "\u{203A}", -- ›
      _cat = cat,
      callback = function()
        Nav:push(require(cat.module):new {})
      end,
    }
  end
  items[#items + 1] = { text = _("About"), kind = "head" }
  items[#items + 1] = {
    text = _("About KoffeeLab"),
    mandatory = "\u{203A}",
    callback = function()
      self:_showAbout()
    end,
  }

  items[#items + 1] = { text = _("Developer"), kind = "head" }
  items[#items + 1] = {
    text = _("Load sample data"),
    mandatory = "\u{203A}",
    callback = function()
      self:_loadSample()
    end,
  }
  return items
end

function Configurator:_showAbout()
  UIManager:show(InfoMessage:new {
    text = _("KoffeeLab")
      .. "\n"
      .. _(
        "Local-first coffee recipe catalogue with brew history, tasting notes and custom drinks."
      )
      .. "\n\n"
      .. _("KOReader")
      .. " "
      .. tostring(Version:getCurrentRevision()),
  })
end

function Configurator:_loadSample()
  local SampleData = require("services/sample_data")
  ConfirmDialog.confirm {
    text = _(
      "Add the built-in sample beans, grinders, recipes and drinks?\n\nExisting data is kept; sample recipes/drinks are appended."
    ),
    ok_text = _("Load"),
    on_confirm = function()
      local ok, summary = SampleData.load()
      if not ok then
        UIManager:show(InfoMessage:new { text = tostring(summary), icon = "notice-warning" })
        return
      end
      UIManager:show(InfoMessage:new {
        text = string.format(
          _("Added %d recipes, %d brew sessions and %d custom drinks."),
          summary.recipes,
          summary.sessions,
          summary.drinks
        ),
      })
    end,
  }
end

return Configurator
