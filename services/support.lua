-- services/support.lua
-- Shared helpers for the service layer. Services validate inputs and enforce the
-- referential rules (§3.14, §1.22 policy table), then delegate to repositories.
-- They return `ok, result_or_error` (§Conventions 15) — a boolean first, unlike the
-- repos' `value | nil, err`.

local Support = {}

function Support.ok(value)
  return true, value
end

function Support.err(message)
  return false, message
end

--- Adapt a repository result (`value` or `nil, err_string`) to the service contract.
function Support.from_repo(value, err)
  if value == nil then
    return false, err or "database error"
  end
  return true, value
end

--- Run a sequence of `{ condition, message }` checks; returns `nil` when all pass or
--- the first failing message.
function Support.check(rules)
  for _, rule in ipairs(rules) do
    if not rule[1] then
      return rule[2]
    end
  end
end

local function is_number(v)
  return type(v) == "number"
end

--- nil, or an integer 1..5 — the shape every sensory axis and rating shares (§3.14).
function Support.is_rating_or_nil(v)
  return v == nil or (is_number(v) and v >= 1 and v <= 5 and v == math.floor(v))
end

--- nil, or a number >= 0.
function Support.is_nonneg_or_nil(v)
  return v == nil or (is_number(v) and v >= 0)
end

function Support.is_nonempty_string(v)
  return type(v) == "string" and v:match("%S") ~= nil
end

return Support
