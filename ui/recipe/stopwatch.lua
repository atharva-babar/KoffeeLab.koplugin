-- ui/recipe/stopwatch.lua
-- Tap-to-capture stopwatch (TECH_SOLUTION §2.16a). The elapsed-time display is
-- STATIC — it is repainted only when the user taps (Start / Split / Stop). There
-- is no scheduleIn, no refresh loop; between taps the screen never changes. Each
-- tap reads os.time(); on Stop the elapsed seconds and any splits are handed back
-- through `on_capture`. Fully optional — the caller can just leave the brew time
-- unset.

local Format = require("util/format")
local ScreenList = require("ui/screen_list")
local _ = require("gettext")

local Stopwatch = ScreenList:extend {
  name = "koffeelab_recipe_stopwatch",
  title = _("Capture Brew Time"),
  on_capture = nil, -- function(elapsed_sec_or_nil, splits_array)
}

function Stopwatch:init()
  self.state = "idle" -- idle | running | stopped
  self.start_time = nil
  self.elapsed = 0
  self.splits = {} -- elapsed-second marks
  ScreenList.init(self)
end

function Stopwatch:_shown_elapsed()
  if self.state == "running" and self.start_time then
    return os.time() - self.start_time
  end
  return self.elapsed
end

function Stopwatch:buildItems()
  local items = {
    {
      text = _("Elapsed"),
      mandatory = Format.duration(self:_shown_elapsed()) or "0:00",
      kind = "head",
    },
  }

  local function act_row(text, act)
    return {
      text = text,
      mandatory = "\u{203A}",
      _act = act,
      callback = function()
        self:_do(act)
      end,
    }
  end
  if self.state == "idle" then
    items[#items + 1] = act_row(_("Tap to start"), "start")
  elseif self.state == "running" then
    items[#items + 1] = act_row(_("Split"), "split")
    items[#items + 1] = act_row(_("Stop"), "stop")
  else
    items[#items + 1] = act_row(_("Use this time"), "use")
    items[#items + 1] = act_row(_("Restart"), "restart")
  end

  if #self.splits > 0 then
    items[#items + 1] = { text = _("Splits"), mandatory = tostring(#self.splits), kind = "head" }
    for i, s in ipairs(self.splits) do
      items[#items + 1] =
        { text = string.format("#%d", i), mandatory = Format.duration(s) or "0:00" }
    end
  end
  return items
end

Stopwatch._items = Stopwatch.buildItems
Stopwatch._repaint = ScreenList.refresh

function Stopwatch:onMenuChoice(item)
  return self:_do(item and item._act)
end

function Stopwatch:_do(act)
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
    return self:onReturn()
  end
  if act then
    self:_repaint()
  end
  return true
end

return Stopwatch
