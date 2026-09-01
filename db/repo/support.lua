-- db/repo/support.lua
-- Shared helpers for the repository layer. Repositories own SQL and transactions;
-- everything above them (services, UI) sees only `value` or `nil, err_string`
-- (§Conventions 15). This module turns the lua-ljsqlite3 exceptions that a failed
-- statement raises into that contract, and centralises the bits every repo repeats
-- (timestamps, the session handle, the transaction wrapper).

local Connection = require("db/connection")
local Query = require("db/query")

local Support = {}

--- Pack a positional parameter list that may contain embedded/trailing nils, with
--- an explicit `n` so Query's binder does not truncate at the first hole.
function Support.args(...)
  return { n = select("#", ...), ... }
end

--- Build and run an INSERT from an ordered column list and a value map. Columns
--- whose value is nil are omitted entirely, so SQLite column DEFAULTs still apply
--- (an explicit `NULL` would violate a NOT NULL DEFAULT column). Returns the
--- Query.exec result (`changes`, `last_insert_rowid`).
function Support.insert(conn, tbl, cols, values)
  local use_cols, marks, params = {}, {}, {}
  for _, col in ipairs(cols) do
    if values[col] ~= nil then
      use_cols[#use_cols + 1] = col
      marks[#marks + 1] = "?"
      params[#params + 1] = values[col]
    end
  end
  local sql = string.format(
    "INSERT INTO %s (%s) VALUES (%s)",
    tbl,
    table.concat(use_cols, ", "),
    table.concat(marks, ", ")
  )
  return Query.exec(conn, sql, params)
end

--- The cached session connection (opened once per §1.22 "Connection setup").
function Support.conn()
  return Connection.open()
end

--- Best-effort wall clock. Never the sole sort key (§Conventions 11) — repos pair
--- it with the row `id`.
function Support.now()
  return os.time()
end

-- lua-ljsqlite3 raises `ljsqlite3[<code>] <message>\nstack traceback: …`. Callers
-- want the message, not the trace; unique-constraint failures get a friendlier form.
local function clean_error(err)
  local text = tostring(err)
  text = text:gsub("\n%s*stack traceback:.*$", "")
  text = text:gsub("^.-ljsqlite3%[%d+%]%s*", "")
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  local column = text:match("UNIQUE constraint failed: [%w_]+%.([%w_]+)")
  if column then
    return "that " .. column .. " is already in use"
  end
  if text:match("UNIQUE constraint failed") then
    return "that value is already in use"
  end
  return text
end

local function pack(...)
  return select("#", ...), { ... }
end

--- Run `fn(...)` and translate a raised SQLite error into `nil, err_string`.
--- Returns `fn`'s own results on success (including a deliberate `nil, err`).
function Support.guard(fn, ...)
  local n, r = pack(pcall(fn, ...))
  if not r[1] then
    return nil, clean_error(r[2])
  end
  return unpack(r, 2, n)
end

--- Wrap `fn(conn)` in a single transaction (§Conventions 16). Rolls back and
--- returns `nil, err_string` on any raised error or on `fn` returning `nil, err`.
function Support.transaction(fn)
  return Connection.with_transaction(function(conn)
    return Support.guard(fn, conn)
  end)
end

--- Build the `col = ?` assignment list and bound values for an UPDATE, taking only
--- the keys named in `allowed` that are actually present in `fields`.
-- @return sql_fragment (may be ""), params array
function Support.assignments(fields, allowed)
  local sets, params = {}, {}
  for _, key in ipairs(allowed) do
    if fields[key] ~= nil then
      sets[#sets + 1] = key .. " = ?"
      params[#params + 1] = fields[key]
    end
  end
  return table.concat(sets, ", "), params
end

return Support
