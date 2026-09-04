-- ui/screen_base.lua
-- Base widget every KoffeeLab feature screen extends (TECH_SOLUTION §2.1). It
-- provides the consistent frame — a full-screen white FrameContainer, a titlebar
-- with a back chevron, and a fixed content area below it — plus a single Back
-- path: hardware Back, a Back gesture (multiswipe / swipe south) and the
-- on-screen chevron all call Nav:pop().
--
-- Subclass usage:
--
--   local MyScreen = ScreenBase:extend{ name = "koffeelab_my", title = _("My") }
--   function MyScreen:getContentWidget()
--     return SomeWidget:new{ width = self.screen_w, height = self.content_height }
--   end
--
-- The contextual bottom navbar (docs/design-language.md §3.7) is opt-in via the
-- `navbar` field: a preset name ("list" | "detail_recipe" | "detail_drink" |
-- "wizard" | "home" | "index" | "configurator" | "config_list"), or an explicit
-- item list. Generic keys (home / index / configurator / add / back / exit) are
-- handled here; the rest (filter / sort / search / edit / delete / save / next /
-- brew_again / favourite) dispatch to `self:onNavAction(key)`, which subclasses
-- override. "add" routes through `self:onNavAdd()` (overridable).
--
-- Optional hook: `MyScreen:onCleanup()` is called once when the screen closes,
-- for releasing resources (DB cursors, cached rows, …).

local Blitbuffer = require("ffi/blitbuffer")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local Navbar = require("ui/widgets/navbar")
local OverlapGroup = require("ui/widget/overlapgroup")
local ScrollableContainer = require("ui/widget/container/scrollablecontainer")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local Screen = Device.screen

-- Contextual navbar item sets, keyed by preset name (design-language §3.7).
-- Home / Index / Configurator share one 5-cell layout so the primary navigation
-- never shifts under the reader.
local NAVBARS = {
  home = { "home", "index", "add", "configurator", "exit" },
  index = { "home", "index", "add", "configurator", "exit" },
  configurator = { "home", "index", "add", "configurator", "exit" },
  config_list = { "home", "add", "back" },
  list = { "home", "filter", "sort", "search", "back" },
  detail_recipe = { "home", "edit", "delete", "brew_again", "favourite" },
  detail_drink = { "home", "edit", "delete" },
  wizard = { "back", "save", "exit" },
}

local ScreenBase = InputContainer:extend {
  name = "koffeelab_screen",
  title = "",
  -- set to true to hide the back chevron (root screens whose Back closes the plugin)
  no_back_button = false,
  covers_fullscreen = true,
  -- opt-in bottom navbar: a preset name from NAVBARS above, or an explicit item
  -- list ({ "home", "filter", ... } or { { key, icon, label }, ... }). nil = none.
  navbar = nil,
  -- the highlighted cell; defaults to the preset name when `navbar` is a string.
  navbar_active = nil,
  -- opt-in: wrap the content in a ScrollableContainer.
  scroll = false,
}

ScreenBase.NAVBARS = NAVBARS

--- Screen-specific navbar keys (filter / sort / edit / …) land here. Override.
function ScreenBase:onNavAction(_key) end

--- Rebuild the bottom navbar with a new item list / active cell and repaint once.
--- Used when a cell must reflect changed state (e.g. the favourite star).
function ScreenBase:setNavbarItems(items, active)
  if not self._navbar_slot then
    return
  end
  self._nav_items = items or self._nav_items
  self._nav_active = active or self._nav_active
  self.navbar_widget = Navbar:new {
    width = self.screen_w,
    items = self._nav_items,
    active = self._nav_active,
    show_parent = self,
    on_select = function(key)
      self:_navSelect(key)
    end,
  }
  self._navbar_slot[1] = self.navbar_widget
  UIManager:setDirty(self, "ui")
end

function ScreenBase:init()
  self.screen_w = Screen:getWidth()
  self.screen_h = Screen:getHeight()
  self.dimen = Geom:new { x = 0, y = 0, w = self.screen_w, h = self.screen_h }

  if Device:hasKeys() then
    self.key_events.Close = { { Device.input.group.Back } }
  end
  if Device:isTouchDevice() then
    self.ges_events.MultiSwipe = {
      GestureRange:new { ges = "multiswipe", range = self.dimen },
    }
    self.ges_events.SwipeBack = {
      GestureRange:new { ges = "swipe", range = self.dimen },
    }
  end

  self.title_bar = TitleBar:new {
    width = self.screen_w,
    fullscreen = true,
    align = "center",
    title = self.title,
    with_bottom_line = true,
    left_icon = (not self.no_back_button) and "chevron.left" or nil,
    left_icon_tap_callback = function()
      self:onReturn()
    end,
    show_parent = self,
  }

  -- resolve the navbar spec (preset name -> item list) once
  local nav_items, nav_active
  if self.navbar then
    if type(self.navbar) == "string" then
      nav_items = NAVBARS[self.navbar] or { self.navbar }
      nav_active = self.navbar_active or self.navbar
    else
      nav_items = self.navbar
      nav_active = self.navbar_active
    end
  end

  local nav_h = self.navbar and Navbar.HEIGHT or 0
  self.content_height = self.screen_h - self.title_bar:getHeight() - nav_h

  local content = self:getContentWidget() or VerticalGroup:new {}

  if self.scroll then
    self.scroll_container = ScrollableContainer:new {
      dimen = Geom:new { w = self.screen_w, h = self.content_height },
      show_parent = self,
      content,
    }
    -- UIManager clips inner repaints/inverts against this
    self.cropping_widget = self.scroll_container
    content = self.scroll_container
  elseif content.cropping_widget then
    -- the content widget manages its own scrolling (e.g. ui/widgets/scroll_list)
    self.cropping_widget = content.cropping_widget
  end

  local body = VerticalGroup:new {
    align = "left",
    self.title_bar,
    content,
  }

  local root = body
  if self.navbar then
    self._nav_items, self._nav_active = nav_items, nav_active
    self.navbar_widget = Navbar:new {
      width = self.screen_w,
      items = nav_items,
      active = nav_active,
      show_parent = self,
      on_select = function(key)
        self:_navSelect(key)
      end,
    }
    self._navbar_slot = BottomContainer:new {
      dimen = Geom:new { w = self.screen_w, h = self.screen_h },
      self.navbar_widget,
    }
    root = OverlapGroup:new {
      dimen = Geom:new { w = self.screen_w, h = self.screen_h },
      body,
      self._navbar_slot,
    }
  end

  self.main_frame = FrameContainer:new {
    width = self.screen_w,
    height = self.screen_h,
    background = Blitbuffer.COLOR_WHITE,
    bordersize = 0,
    padding = 0,
    margin = 0,
    root,
  }
  self[1] = self.main_frame
end

--- Navbar tap handler. Generic navigation keys are handled here (resetting to
--- Home first so repeated navbar taps don't grow the stack); everything else is
--- a screen-specific verb handed to `self:onNavAction(key)`.
function ScreenBase:_navSelect(key)
  local Nav = self.nav or require("ui/nav")
  if key == "home" then
    Nav:reset(require("ui/home"):new {})
  elseif key == "index" then
    Nav:reset(require("ui/home"):new {})
    Nav:push(require("ui/index"):new {})
  elseif key == "favourites" then
    Nav:reset(require("ui/home"):new {})
    Nav:push(require("ui/recipe/index"):new { favourites = true })
  elseif key == "configurator" then
    Nav:reset(require("ui/home"):new {})
    Nav:push(require("ui/configurator"):new {})
  elseif key == "add" then
    self:onNavAdd()
  elseif key == "exit" then
    Nav:closeAll()
  elseif key == "back" then
    self:_goBack()
  else
    self:onNavAction(key)
  end
end

--- What the navbar "add" key does. The default is the Recipe / Custom Drink
--- chooser (as on the Index screen); list screens that own a single "add" verb
--- (the Configurator entities) override this to run their own `on_add`.
function ScreenBase:onNavAdd()
  self:_navAdd()
end

function ScreenBase:_navAdd()
  local ButtonDialog = require("ui/widget/buttondialog")
  local _ = require("gettext")
  local dialog
  dialog = ButtonDialog:new {
    title = _("Add"),
    title_align = "center",
    buttons = {
      {
        {
          text = _("+ Add Recipe"),
          callback = function()
            UIManager:close(dialog)
            require("ui/recipe/add_flow").start {}
          end,
        },
      },
      {
        {
          text = _("+ Add Custom Drink"),
          callback = function()
            UIManager:close(dialog)
            require("ui/drink/add_flow").start {}
          end,
        },
      },
    },
  }
  UIManager:show(dialog)
end

--- Subclasses override this to return the body widget (below the titlebar).
--- It should size itself to `self.screen_w` x `self.content_height`.
function ScreenBase:getContentWidget()
  return VerticalGroup:new {}
end

function ScreenBase:_goBack()
  if self.nav then
    self.nav:pop()
  else
    UIManager:close(self)
  end
  return true
end

-- dispatch dynamically so a subclass that overrides _goBack (e.g. the Wizard,
-- whose Back steps to the previous page) is honoured here too
function ScreenBase:onReturn()
  return self:_goBack()
end
function ScreenBase:onClose()
  return self:_goBack()
end

function ScreenBase:onMultiSwipe()
  -- any multiswipe direction goes back (consistent with KOReader fullscreen widgets)
  return self:_goBack()
end

function ScreenBase:onSwipeBack(_, ges)
  if ges and ges.direction == "south" then
    return self:_goBack()
  end
  return false
end

function ScreenBase:onShow()
  UIManager:setDirty(self, "flashui")
  return true
end

function ScreenBase:onCloseWidget()
  if self.onCleanup then
    self:onCleanup()
  end
  UIManager:setDirty(nil, "ui")
end

return ScreenBase
