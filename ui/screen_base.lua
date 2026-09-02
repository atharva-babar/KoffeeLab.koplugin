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

local ScreenBase = InputContainer:extend {
  name = "koffeelab_screen",
  title = "",
  -- set to true to hide the back chevron (root screens whose Back closes the plugin)
  no_back_button = false,
  -- optional titlebar right-hand icon + handler (e.g. an overflow menu)
  right_icon = nil,
  covers_fullscreen = true,
  -- opt-in: a Navbar key ("home"|"index"|"favourites"|"configurator") pins the
  -- bottom nav to this screen; nil = no navbar (deep screens).
  navbar = nil,
  -- opt-in: wrap the content in a ScrollableContainer.
  scroll = false,
}

--- Override in a subclass that sets `right_icon`.
function ScreenBase:onRightButton() end

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
    right_icon = self.right_icon,
    right_icon_tap_callback = self.right_icon and function()
      self:onRightButton()
    end or nil,
    show_parent = self,
  }

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
  end

  local body = VerticalGroup:new {
    align = "left",
    self.title_bar,
    content,
  }

  local root = body
  if self.navbar then
    self.navbar_widget = Navbar:new {
      width = self.screen_w,
      active = self.navbar,
      show_parent = self,
      on_select = function(key)
        self:_navSelect(key)
      end,
    }
    root = OverlapGroup:new {
      dimen = Geom:new { w = self.screen_w, h = self.screen_h },
      body,
      BottomContainer:new {
        dimen = Geom:new { w = self.screen_w, h = self.screen_h },
        self.navbar_widget,
      },
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

--- Navbar tap handler. Keep the back-stack shallow: reset to Home, then push the
--- target so repeated navbar taps don't grow the stack.
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
    self:_navAdd()
  end
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

ScreenBase.onReturn = ScreenBase._goBack
ScreenBase.onClose = ScreenBase._goBack

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
