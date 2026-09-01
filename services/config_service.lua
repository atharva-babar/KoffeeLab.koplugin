-- services/config_service.lua
-- Validation and referential rules for the four flat config entities (§3.14 Bean /
-- Grinder; §3.12). Hard delete is never offered — the caller disables via
-- `set_active` (§1.22 policy table). Beans/grinders that are still referenced by a
-- recipe cannot even be disabled without a warning, but soft-disable itself is
-- always allowed (existing recipes still render disabled config — §1.21).

local ConfigRepo = require("db/repo/config")
local Support = require("services/support")

local ConfigService = {}

local VALIDATORS = {
  beans = function(f)
    return Support.check {
      { Support.is_nonempty_string(f.name), "bean name is required" },
      {
        f.roaster_name == nil or type(f.roaster_name) == "string",
        "roaster name must be text",
      },
      {
        f.roast_level == nil or (f.roast_level >= 1 and f.roast_level <= 5),
        "roast level must be 1–5",
      },
    }
  end,
  grinders = function(f)
    return Support.check {
      { Support.is_nonempty_string(f.name), "grinder name is required" },
      { Support.is_nonempty_string(f.unit_name), "unit name is required" },
      { type(f.min_value) == "number", "minimum is required" },
      { type(f.max_value) == "number", "maximum is required" },
      {
        type(f.min_value) == "number"
          and type(f.max_value) == "number"
          and f.min_value <= f.max_value,
        "minimum must be ≤ maximum",
      },
      { type(f.step_value) == "number" and f.step_value > 0, "step must be greater than 0" },
    }
  end,
  ingredients = function(f)
    return Support.check {
      { Support.is_nonempty_string(f.name), "ingredient name is required" },
    }
  end,
  flavor_tags = function(f)
    return Support.check {
      { Support.is_nonempty_string(f.name), "tag name is required" },
    }
  end,
}

-- Merge validation over the existing row for partial updates.
local function merged(entity, id, fields)
  local current = ConfigRepo[entity].get(id)
  if not current then
    return nil
  end
  local out = {}
  for k, v in pairs(current) do
    out[k] = v
  end
  for k, v in pairs(fields) do
    out[k] = v
  end
  return out
end

local function build(entity)
  local service = {}

  function service.list(opts)
    return Support.ok(ConfigRepo[entity].list(opts))
  end

  function service.get(id)
    local row = ConfigRepo[entity].get(id)
    if not row then
      return Support.err("not found")
    end
    return Support.ok(row)
  end

  function service.create(fields)
    local bad = VALIDATORS[entity](fields or {})
    if bad then
      return Support.err(bad)
    end
    return Support.from_repo(ConfigRepo[entity].create(fields))
  end

  function service.update(id, fields)
    local candidate = merged(entity, id, fields or {})
    if not candidate then
      return Support.err("not found")
    end
    local bad = VALIDATORS[entity](candidate)
    if bad then
      return Support.err(bad)
    end
    return Support.from_repo(ConfigRepo[entity].update(id, fields))
  end

  function service.set_active(id, active)
    return Support.from_repo(ConfigRepo[entity].set_active(id, active))
  end

  -- Hard delete is intentionally not part of the config surface (§3.12).
  function service.delete()
    return Support.err("configuration entries are disabled, not deleted")
  end

  return service
end

for _, entity in ipairs { "beans", "grinders", "ingredients", "flavor_tags" } do
  ConfigService[entity] = build(entity)
end

return ConfigService
