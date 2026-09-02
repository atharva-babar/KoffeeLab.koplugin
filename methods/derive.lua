-- methods/derive.lua
-- Values computed from a recipe's steps, never stored. A step is an ordered
-- table { step_type, start_time, water, note }.

local Derive = {}

--- Cumulative water after each step (array parallel to `steps`). nil water counts
--- as 0; an entry is nil only when no step up to it added water.
function Derive.total_water(steps)
  local out, running, seen = {}, 0, false
  for i, step in ipairs(steps or {}) do
    if type(step.water) == "number" then
      running = running + step.water
      seen = true
    end
    out[i] = seen and running or nil
  end
  return out
end

--- Duration of step `i` in seconds: the gap to the next step's start time, or for
--- the last step the gap to `total_brew_time`. nil when it cannot be computed.
function Derive.duration(steps, i, total_brew_time)
  steps = steps or {}
  local step = steps[i]
  if not step or type(step.start_time) ~= "number" then
    return nil
  end
  local nxt = steps[i + 1]
  local endpoint = nxt and nxt.start_time or total_brew_time
  if type(endpoint) ~= "number" then
    return nil
  end
  local d = endpoint - step.start_time
  return d >= 0 and d or nil
end

return Derive
