-- util/validation.lua
-- Shared, widget-free predicates for the §3.14 validation rules. Services call
-- these to build their `ok, error` results; UI forms call the same predicates to
-- disable a Save button or flag a field before the service round-trip. Pure
-- functions — no DB, no state.

local Constants = require("util/constants")

local Validation = {}

local function is_number(v)
  return type(v) == "number"
end

local function is_integer(v)
  return is_number(v) and v == math.floor(v)
end

function Validation.is_nonempty_string(v)
  return type(v) == "string" and v:match("%S") ~= nil
end

function Validation.is_positive_number(v)
  return is_number(v) and v > 0
end

function Validation.is_nonneg_number(v)
  return is_number(v) and v >= 0
end

function Validation.is_positive_or_nil(v)
  return v == nil or Validation.is_positive_number(v)
end

function Validation.is_nonneg_or_nil(v)
  return v == nil or Validation.is_nonneg_number(v)
end

--- integer 1..5 (a sensory axis or a catalogue/session rating — §3.14, §1.11).
function Validation.is_rating(v)
  return is_integer(v) and v >= 1 and v <= 5
end

function Validation.is_rating_or_nil(v)
  return v == nil or Validation.is_rating(v)
end

--- integer 1..5 roast level (§0.12).
function Validation.is_roast_level(v)
  return is_integer(v) and v >= 1 and v <= 5
end

function Validation.is_temperature_mode(v)
  return Constants.TEMPERATURE_MODE_LABELS[v] ~= nil
end

function Validation.is_step_type(v)
  return Constants.STEP_TYPE_LABELS[v] ~= nil
end

function Validation.in_range(v, min_value, max_value)
  return is_number(v) and v >= min_value and v <= max_value
end

--- Grinder config sanity (§3.14): min <= max and step > 0.
function Validation.grinder_range_ok(min_value, max_value, step_value)
  return is_number(min_value)
    and is_number(max_value)
    and is_number(step_value)
    and min_value <= max_value
    and step_value > 0
end

--- Run `{ predicate_result, message }` pairs; return the first failing message
--- or nil when all pass. Mirrors services/support.check so a service and a form
--- can share the rule list.
function Validation.first_error(rules)
  for _, rule in ipairs(rules) do
    if not rule[1] then
      return rule[2]
    end
  end
  return nil
end

return Validation
