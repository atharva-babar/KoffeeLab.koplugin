-- ui/nav.lua
-- A small screen stack on top of UIManager (TECH_SOLUTION §2.2, §3.4). Feature
-- screens are plain KOReader widgets (usually `ui/screen_base` subclasses) that
-- cover the full screen; Nav owns the ordering and teardown so every screen is
-- reached and left the same way:
--
--   * Nav:push(w)     show `w` above the current screen
--   * Nav:pop()        close the top screen, reveal the one below; closing the
--                      last screen leaves the plugin (stack empty)
--   * Nav:replace(w)   swap the top screen for `w` (same depth)
--   * Nav:reset(w)     close everything, start a fresh stack at `w`
--
-- Screens never call UIManager:close on themselves — hardware/gesture Back and
-- the on-screen back button all route here (see ui/screen_base). This keeps the
-- stack and UIManager's window stack in agreement.

local UIManager = require("ui/uimanager")
local logger = require("logger")

local Nav = {
  _stack = {},
}

function Nav:depth()
  return #self._stack
end

function Nav:top()
  return self._stack[#self._stack]
end

--- Push `screen` on top of the stack and show it.
function Nav:push(screen)
  assert(screen, "Nav:push needs a widget")
  screen.nav = self
  table.insert(self._stack, screen)
  logger.dbg("KoffeeLab Nav: push ->", #self._stack)
  UIManager:show(screen)
  return screen
end

--- Close the top screen and reveal the one beneath it. Returns the newly
--- exposed screen, or nil when the stack is now empty (plugin closed).
function Nav:pop()
  local screen = table.remove(self._stack)
  if not screen then
    return nil
  end
  UIManager:close(screen)
  local below = self._stack[#self._stack]
  logger.dbg("KoffeeLab Nav: pop ->", #self._stack)
  if below then
    UIManager:setDirty(below, "ui")
  end
  return below
end

--- Replace the top screen with `screen`, keeping the stack depth unchanged.
function Nav:replace(screen)
  assert(screen, "Nav:replace needs a widget")
  local old = table.remove(self._stack)
  screen.nav = self
  table.insert(self._stack, screen)
  UIManager:show(screen)
  if old then
    UIManager:close(old)
  end
  logger.dbg("KoffeeLab Nav: replace, depth", #self._stack)
  return screen
end

--- Tear the whole stack down (top first) without showing anything new.
function Nav:closeAll()
  for i = #self._stack, 1, -1 do
    UIManager:close(self._stack[i])
    self._stack[i] = nil
  end
end

--- Close everything and start a new stack rooted at `screen`.
function Nav:reset(screen)
  self:closeAll()
  return self:push(screen)
end

return Nav
