-- ui/home.lua
-- KoffeeLab root screen (TECH_SOLUTION §2.2, §2.3): four large full-width
-- buttons — Add Recipe, Custom Drink, Index, Configurator — plus an overflow
-- menu (Backup, Restore, About) behind the titlebar's right-hand icon. Every
-- button navigates through Nav; later phases swap the placeholder destinations
-- for real screens.

local ButtonDialog = require("ui/widget/buttondialog")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Geom = require("ui/geometry")
local InfoMessage = require("ui/widget/infomessage")
local Nav = require("ui/nav")
local Placeholder = require("ui/placeholder")
local ScreenBase = require("ui/screen_base")
local UIManager = require("ui/uimanager")
local Version = require("version")
local _ = require("gettext")

local HomeScreen = ScreenBase:extend {
  name = "koffeelab_home",
  title = _("KoffeeLab"),
  no_back_button = false, -- Back from Home closes the plugin (stack empties)
  right_icon = "appbar.menu",
}

function HomeScreen:_open(title, message)
  Nav:push(Placeholder:new { title = title, message = message })
end

function HomeScreen:getContentWidget()
  local width = math.floor(self.screen_w * 0.9)
  local buttons = ButtonTable:new {
    width = width,
    buttons = {
      {
        {
          text = _("+ Add Recipe"),
          callback = function()
            self:_open(_("Add Recipe"), _("The Add Recipe flow arrives in Phase 5."))
          end,
        },
      },
      {
        {
          text = _("+ Custom Drink"),
          callback = function()
            self:_open(_("Custom Drink"), _("Custom drinks arrive in Phase 8."))
          end,
        },
      },
      {
        {
          text = _("Index"),
          callback = function()
            self:_open(_("Index"), _("The recipe / drink index arrives in Phase 6."))
          end,
        },
      },
      {
        {
          text = _("Configurator"),
          callback = function()
            self:_open(_("Configurator"), _("The Configurator arrives in Phase 4."))
          end,
        },
      },
    },
    show_parent = self,
  }
  return CenterContainer:new {
    dimen = Geom:new { w = self.screen_w, h = self.content_height },
    buttons,
  }
end

function HomeScreen:onRightButton()
  local dialog
  dialog = ButtonDialog:new {
    title = _("KoffeeLab"),
    title_align = "center",
    buttons = {
      {
        {
          text = _("Backup"),
          callback = function()
            UIManager:close(dialog)
            self:_open(_("Backup"), _("Backup & restore UI arrives in Phase 9."))
          end,
        },
      },
      {
        {
          text = _("Restore"),
          callback = function()
            UIManager:close(dialog)
            self:_open(_("Restore"), _("Backup & restore UI arrives in Phase 9."))
          end,
        },
      },
      {
        {
          text = _("About"),
          callback = function()
            UIManager:close(dialog)
            self:_showAbout()
          end,
        },
      },
    },
  }
  UIManager:show(dialog)
end

function HomeScreen:_showAbout()
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

return HomeScreen
