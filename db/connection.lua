-- db/connection.lua
-- Owns the single SQLite handle for the plugin session: open / close / transaction.
-- SQL lives only in db/; nothing above this layer requires lua-ljsqlite3.

local SQ3 = require("lua-ljsqlite3/init")
local logger = require("logger")

local Connection = {}

-- Applied on every open, before any transaction (TECH_SOLUTION §1.22 "Connection
-- setup"). foreign_keys cannot be toggled inside a transaction, hence here.
local CONNECTION_PRAGMAS = {
  "PRAGMA foreign_keys = ON",
  "PRAGMA journal_mode = TRUNCATE", -- safer than WAL for a file copied over USB
  "PRAGMA synchronous = FULL", -- e-ink devices can lose power mid-write
  "PRAGMA busy_timeout = 2000",
}

local conn -- cached session handle
local conn_path -- path the cached handle was opened with

--- Resolve the on-device database path.
function Connection.default_path()
  local DataStorage = require("datastorage")
  return DataStorage:getSettingsDir() .. "/koffeelab.sqlite3"
end

--- Open (or return the cached) connection.
-- @param path optional override (":memory:" for specs); defaults to the device DB.
-- @return handle
function Connection.open(path)
  path = path or conn_path or Connection.default_path()
  if conn and not conn._closed and conn_path == path then
    return conn
  end
  if conn and not conn._closed then
    conn:close()
  end
  local handle = SQ3.open(path)
  for _, pragma in ipairs(CONNECTION_PRAGMAS) do
    handle:exec(pragma)
  end
  conn, conn_path = handle, path
  logger.dbg("KoffeeLab: opened DB", path)
  return conn
end

--- Close the cached connection and drop it. Safe to call when already closed.
function Connection.close()
  if conn and not conn._closed then
    conn:close()
    logger.dbg("KoffeeLab: closed DB", conn_path)
  end
  conn, conn_path = nil, nil
end

local function pack(...)
  return select("#", ...), { ... }
end

--- Run `fn(conn)` inside BEGIN/COMMIT. Rolls back and returns `nil, err` when `fn`
--- raises or returns `nil, err`; otherwise commits and returns `fn`'s results.
function Connection.with_transaction(fn)
  local handle = Connection.open()
  handle:exec("BEGIN")
  -- r[1] is pcall's ok flag; r[2..n] are fn's return values.
  local n, r = pack(pcall(fn, handle))
  if not r[1] then
    pcall(handle.exec, handle, "ROLLBACK")
    return nil, tostring(r[2])
  end
  if r[2] == nil and r[3] ~= nil then
    pcall(handle.exec, handle, "ROLLBACK")
    return nil, r[3]
  end
  handle:exec("COMMIT")
  return unpack(r, 2, n)
end

return Connection
