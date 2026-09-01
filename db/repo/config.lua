-- db/repo/config.lua
-- CRUD for the four flat configuration entities: beans, grinders, ingredients,
-- flavor_tags (§1.22). No hard delete here — disabling is soft (§3.12); the service
-- layer owns the "still referenced?" checks. Every write stamps timestamps.
--
-- Returns a table with one sub-table per entity, each exposing the same shape:
--   list({include_inactive=false}) -> rows
--   get(id)                        -> row | nil
--   create(fields)                 -> row | nil, err
--   update(id, fields)             -> row | nil, err
--   set_active(id, bool)           -> row | nil, err

local Query = require("db/query")
local Support = require("db/repo/support")

-- Per-entity config: table name, the columns a caller may write, and default sort.
local ENTITIES = {
  beans = {
    table = "beans",
    writable = { "name", "roaster_name", "roast_level" },
    order_by = "roaster_name COLLATE NOCASE, name COLLATE NOCASE",
  },
  grinders = {
    table = "grinders",
    writable = { "name", "unit_name", "min_value", "max_value", "step_value" },
    order_by = "name COLLATE NOCASE",
  },
  ingredients = {
    table = "ingredients",
    writable = { "name" },
    order_by = "name COLLATE NOCASE",
  },
  flavor_tags = {
    table = "flavor_tags",
    writable = { "name" },
    order_by = "name COLLATE NOCASE",
  },
}

local function make_repo(spec)
  local repo = {}

  function repo.list(opts)
    opts = opts or {}
    local sql = "SELECT * FROM " .. spec.table
    if not opts.include_inactive then
      sql = sql .. " WHERE is_active = 1"
    end
    sql = sql .. " ORDER BY " .. spec.order_by .. ", id"
    return Query.all(Support.conn(), sql)
  end

  function repo.get(id)
    return Query.one(Support.conn(), "SELECT * FROM " .. spec.table .. " WHERE id = ?", { id })
  end

  function repo.create(fields)
    return Support.guard(function()
      local now = Support.now()
      local cols, values = {}, { created_at = now, updated_at = now }
      for _, key in ipairs(spec.writable) do
        cols[#cols + 1] = key
        values[key] = fields[key]
      end
      cols[#cols + 1] = "created_at"
      cols[#cols + 1] = "updated_at"
      local res = Support.insert(Support.conn(), spec.table, cols, values)
      return repo.get(res.last_insert_rowid)
    end)
  end

  function repo.update(id, fields)
    return Support.guard(function()
      local frag, params = Support.assignments(fields, spec.writable)
      if frag == "" then
        return repo.get(id)
      end
      params[#params + 1] = Support.now()
      params[#params + 1] = id
      local sql = string.format("UPDATE %s SET %s, updated_at = ? WHERE id = ?", spec.table, frag)
      Query.exec(Support.conn(), sql, params)
      return repo.get(id)
    end)
  end

  function repo.set_active(id, active)
    return Support.guard(function()
      Query.exec(
        Support.conn(),
        "UPDATE " .. spec.table .. " SET is_active = ?, updated_at = ? WHERE id = ?",
        { active and 1 or 0, Support.now(), id }
      )
      return repo.get(id)
    end)
  end

  return repo
end

local Config = {}
for name, spec in pairs(ENTITIES) do
  Config[name] = make_repo(spec)
end

return Config
