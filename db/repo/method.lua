-- db/repo/method.lua
-- Brew methods (§1.14, §1.22). Read-mostly: the five system methods are seeded and
-- protected; users may add their own. `get`/`get_by_slug` return the method with its
-- `parameters`, `step_types` and `equipment` nested.
--
-- Destructive edits to a system method (is_system = 1) that would drop a parameter or
-- step-type still referenced by a recipe are rejected (§2.19). Safe edits — adding
-- rows, renaming labels, reordering, toggling active — are allowed.

local Query = require("db/query")
local Support = require("db/repo/support")

local Method = {}

local METHOD_FIELDS = { "slug", "name", "icon", "description", "sort_order" }

local function nested(conn, method)
  method.parameters = Query.all(
    conn,
    "SELECT * FROM brew_method_parameters WHERE method_id = ? ORDER BY sort_order, id",
    { method.id }
  )
  method.step_types = Query.all(
    conn,
    "SELECT step_type, sort_order FROM brew_method_step_types WHERE method_id = ? ORDER BY sort_order, step_type",
    { method.id }
  )
  method.equipment = Query.all(
    conn,
    "SELECT * FROM brew_method_equipment WHERE method_id = ? ORDER BY sort_order, id",
    { method.id }
  )
  return method
end

function Method.list(opts)
  opts = opts or {}
  local conn = Support.conn()
  local sql = "SELECT * FROM brew_methods"
  if not opts.include_inactive then
    sql = sql .. " WHERE is_active = 1"
  end
  sql = sql .. " ORDER BY sort_order, name COLLATE NOCASE, id"
  local rows = Query.all(conn, sql)
  for _, row in ipairs(rows) do
    nested(conn, row)
  end
  return rows
end

function Method.get(id)
  local conn = Support.conn()
  local row = Query.one(conn, "SELECT * FROM brew_methods WHERE id = ?", { id })
  return row and nested(conn, row) or nil
end

function Method.get_by_slug(slug)
  local conn = Support.conn()
  local row = Query.one(conn, "SELECT * FROM brew_methods WHERE slug = ?", { slug })
  return row and nested(conn, row) or nil
end

local function insert_parameters(conn, method_id, params)
  for order, p in ipairs(params or {}) do
    Query.exec(
      conn,
      [[INSERT INTO brew_method_parameters
          (method_id, key, label, data_type, unit, required, default_value, min_value, max_value, sort_order)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
      Support.args(
        method_id,
        p.key,
        p.label,
        p.data_type,
        p.unit,
        p.required and 1 or 0,
        p.default_value,
        p.min_value,
        p.max_value,
        p.sort_order or order
      )
    )
  end
end

local function insert_step_types(conn, method_id, step_types)
  for order, st in ipairs(step_types or {}) do
    local step_type = type(st) == "table" and st.step_type or st
    Query.exec(
      conn,
      "INSERT INTO brew_method_step_types (method_id, step_type, sort_order) VALUES (?, ?, ?)",
      { method_id, step_type, order }
    )
  end
end

local function insert_equipment(conn, method_id, equipment)
  for order, e in ipairs(equipment or {}) do
    local name = type(e) == "table" and e.name or e
    Query.exec(
      conn,
      "INSERT INTO brew_method_equipment (method_id, name, sort_order) VALUES (?, ?, ?)",
      { method_id, name, order }
    )
  end
end

--- Create a user method (is_system = 0) with its nested parameters / step types /
--- equipment, all in one transaction.
function Method.create_user_method(fields)
  return Support.transaction(function(conn)
    local now = Support.now()
    Query.exec(
      conn,
      [[INSERT INTO brew_methods (slug, name, icon, description, is_system, is_active, sort_order, created_at, updated_at)
        VALUES (?, ?, ?, ?, 0, 1, ?, ?, ?)]],
      Support.args(
        fields.slug,
        fields.name,
        fields.icon,
        fields.description or "",
        fields.sort_order or 0,
        now,
        now
      )
    )
    local method_id = Query.one(conn, "SELECT last_insert_rowid() AS id").id
    insert_parameters(conn, method_id, fields.parameters)
    insert_step_types(conn, method_id, fields.step_types)
    insert_equipment(conn, method_id, fields.equipment)
    return Method.get(method_id)
  end)
end

-- Which existing parameter keys / step types would this edit remove, and is any of
-- them still referenced by a recipe? Returns an error string, or nil when safe.
local function destructive_conflict(conn, method_id, new_param_keys, new_step_types)
  if new_param_keys then
    local keep = {}
    for _, k in ipairs(new_param_keys) do
      keep[k] = true
    end
    local existing = Query.all(
      conn,
      "SELECT id, key FROM brew_method_parameters WHERE method_id = ?",
      { method_id }
    )
    for _, p in ipairs(existing) do
      if not keep[p.key] then
        local used = Query.one(
          conn,
          "SELECT 1 AS x FROM brew_recipe_parameters WHERE param_id = ? LIMIT 1",
          { p.id }
        )
        if used then
          return "parameter '" .. p.key .. "' is used by an existing recipe"
        end
      end
    end
  end
  if new_step_types then
    local keep = {}
    for _, st in ipairs(new_step_types) do
      keep[type(st) == "table" and st.step_type or st] = true
    end
    local existing = Query.all(
      conn,
      "SELECT step_type FROM brew_method_step_types WHERE method_id = ?",
      { method_id }
    )
    for _, s in ipairs(existing) do
      if not keep[s.step_type] then
        local used = Query.one(
          conn,
          [[SELECT 1 AS x FROM brew_recipe_steps st
              JOIN brew_recipes r ON r.id = st.recipe_id
             WHERE r.method_id = ? AND st.step_type = ? LIMIT 1]],
          { method_id, s.step_type }
        )
        if used then
          return "step type '" .. s.step_type .. "' is used by an existing recipe"
        end
      end
    end
  end
end

--- Update a method. For system methods, a destructive change (removing a referenced
--- parameter or step type) is rejected; safe changes go through. `opts.parameters`,
--- `opts.step_types`, `opts.equipment` (when given) fully replace their sets.
function Method.update_user_method(id, fields, opts)
  opts = opts or {}
  return Support.transaction(function(conn)
    local method = Query.one(conn, "SELECT * FROM brew_methods WHERE id = ?", { id })
    if not method then
      return nil, "method not found"
    end

    if tonumber(method.is_system) == 1 then
      local param_keys
      if opts.parameters then
        param_keys = {}
        for _, p in ipairs(opts.parameters) do
          param_keys[#param_keys + 1] = p.key
        end
      end
      local conflict = destructive_conflict(conn, id, param_keys, opts.step_types)
      if conflict then
        return nil, conflict
      end
    end

    local frag, params = Support.assignments(fields or {}, METHOD_FIELDS)
    if frag ~= "" then
      params[#params + 1] = Support.now()
      params[#params + 1] = id
      Query.exec(
        conn,
        "UPDATE brew_methods SET " .. frag .. ", updated_at = ? WHERE id = ?",
        params
      )
    else
      Query.exec(conn, "UPDATE brew_methods SET updated_at = ? WHERE id = ?", { Support.now(), id })
    end

    if opts.parameters then
      Query.exec(conn, "DELETE FROM brew_method_parameters WHERE method_id = ?", { id })
      insert_parameters(conn, id, opts.parameters)
    end
    if opts.step_types then
      Query.exec(conn, "DELETE FROM brew_method_step_types WHERE method_id = ?", { id })
      insert_step_types(conn, id, opts.step_types)
    end
    if opts.equipment then
      Query.exec(conn, "DELETE FROM brew_method_equipment WHERE method_id = ?", { id })
      insert_equipment(conn, id, opts.equipment)
    end

    return Method.get(id)
  end)
end

function Method.set_active(id, active)
  return Support.guard(function()
    Query.exec(
      Support.conn(),
      "UPDATE brew_methods SET is_active = ?, updated_at = ? WHERE id = ?",
      { active and 1 or 0, Support.now(), id }
    )
    return Method.get(id)
  end)
end

return Method
