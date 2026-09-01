-- db/query.lua
-- Thin, domain-agnostic helpers over a lua-ljsqlite3 connection. Every helper binds
-- parameters (never string-concatenated SQL, §3.20). Repositories build on these;
-- nothing here knows about the schema.

local Query = {}

-- Bind an array of params positionally. `params.n` (an explicit count) lets callers
-- pass trailing/embedded nils unambiguously; otherwise `#params` is used.
local function bind_params(stmt, params)
  if not params then
    return
  end
  local count = params.n or #params
  for i = 1, count do
    stmt:bind1(i, params[i])
  end
end

--- Run `sql` and return every row as a column-name-keyed table (array, possibly empty).
function Query.all(conn, sql, params)
  local stmt = conn:prepare(sql)
  bind_params(stmt, params)
  local rows, header = {}, {}
  while true do
    local row = stmt:step(nil, header)
    if not row then
      break
    end
    local record = {}
    for i = 1, #header do
      record[header[i]] = row[i]
    end
    rows[#rows + 1] = record
  end
  stmt:close()
  return rows
end

--- Run `sql` and return the first row (column-name-keyed) or nil.
function Query.one(conn, sql, params)
  return Query.all(conn, sql, params)[1]
end

--- Run a write (`INSERT` / `UPDATE` / `DELETE`) and return
--- `{ changes = <affected rows>, last_insert_rowid = <rowid> }`.
function Query.exec(conn, sql, params)
  local stmt = conn:prepare(sql)
  bind_params(stmt, params)
  stmt:step()
  stmt:close()
  return {
    changes = tonumber(conn:rowexec("SELECT changes()")) or 0,
    last_insert_rowid = tonumber(conn:rowexec("SELECT last_insert_rowid()")) or 0,
  }
end

--- Escape `%`, `_` and `\` in user text for use with `LIKE ? ESCAPE '\'`.
function Query.like_escape(text)
  return (tostring(text):gsub("([%%_\\])", "\\%1"))
end

--- Build a `%…%` substring pattern with the user text escaped.
function Query.like_contains(text)
  return "%" .. Query.like_escape(text) .. "%"
end

return Query
