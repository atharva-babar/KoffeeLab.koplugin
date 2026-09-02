-- ui/recipe/stopwatch.lua
-- Tap-to-capture stopwatch (TECH_SOLUTION §2.16a). The elapsed-time display is
-- STATIC — it is repainted only when the user taps (Start / Split / Stop). There
-- is no scheduleIn, no refresh loop; between taps the screen never changes. Each
-- tap reads os.time(); on Stop the elapsed seconds and any splits are handed back
-- through `on_capture`. Fully optional — the caller can just leave the brew time
-- unset. Built on Menu so Back and large tap targets come for free.

local Format = require("util/format")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local Stopwatch = Menu:extend {
  name = "koffeelab_recipe_stopwatch",
  covers_fullscreen = true,
  is_borderless = true,
  is_popout = false,
  is_enable_shortcut = false,
  with_bottom_line = true,
  title_bar_left_icon = "chevron.left",
  title = _("Capture Brew Time"),
  on_capture = nil, -- function(elapsed_sec_or_nil, splits_array)
}

function Stopwatch:init()
  self.state = "idle" -- idle | running | stopped
  self.start_time = nil
  self.elapsed = 0
  self.splits = {} -- elapsed-second marks
  self.item_table = self:_items()
  Menu.init(self)
end

function Stopwatch:_shown_elapsed()
  if self.state == "running" and self.start_time then
    return os.time() - self.start_time
  end
  return self.elapsed
end

function Stopwatch:_items()
  local items = {
    {
      text = _("Elapsed"),
      mandatory = Format.duration(self:_shown_elapsed()) or "0:00",
      _inert = true,
    },
  }

  if self.state == "idle" then
    items[#items + 1] = { text = _("Tap to start"), mandatory = "\u{203A}", _act = "start" }
  elseif self.state == "running" then
    items[#items + 1] = { text = _("Split"), mandatory = "\u{203A}", _act = "split" }
    items[#items + 1] = { text = _("Stop"), mandatory = "\u{203A}", _act = "stop" }
  else
    items[#items + 1] = { text = _("Use this time"), mandatory = "\u{203A}", _act = "use" }
    items[#items + 1] = { text = _("Restart"), mandatory = "\u{203A}", _act = "restart" }
  end

  if #self.splits > 0 then
    items[#items + 1] = { text = _("Splits"), mandatory = tostring(#self.splits), _inert = true }
    for i, s in ipairs(self.splits) do
      items[#items + 1] = {
        text = string.format("  #%d", i),
        mandatory = Format.duration(s) or "0:00",
        _inert = true,
      }
    end
  end
  return items
end

function Stopwatch:_repaint()
  self:switchItemTable(self.title, self:_items(), 1)
end

function Stopwatch:onMenuChoice(item)
  local act = item._act
  if act == "start" then
    self.state = "running"
    self.start_time = os.time()
    self.elapsed = 0
    self.splits = {}
  elseif act == "split" and self.start_time then
    self.splits[#self.splits + 1] = os.time() - self.start_time
  elseif act == "stop" and self.start_time then
    self.elapsed = os.time() - self.start_time
    self.state = "stopped"
  elseif act == "restart" then
    self.state = "idle"
    self.start_time = nil
    self.elapsed = 0
    self.splits = {}
  elseif act == "use" then
    if self.on_capture then
      self.on_capture(self.elapsed > 0 and self.elapsed or nil, self.splits)
    end
    return self:_back()
  end
  if act then
    self:_repaint()
  end
  return true
end

function Stopwatch:_back()
  if self.nav then
    self.nav:pop()
  else
    UIManager:close(self)
  end
  return true
end

Stopwatch.onClose = Stopwatch._back
Stopwatch.onLeftButtonTap = Stopwatch._back

return Stopwatch
