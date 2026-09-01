-- db/migrations.lua
-- Migration runner. Schema version lives in SQLite's PRAGMA user_version
-- (TECH_SOLUTION §1.19). Migration 1 applies the full DDL (db/schema.lua) and then
-- the system-method seed (db/seed.lua), all inside one transaction — any error
-- rolls the whole batch back and leaves user_version untouched.

local Schema = require("db/schema")
local Seed = require("db/seed")
local logger = require("logger")

local Migrations = {}

Migrations.CURRENT_SCHEMA_VERSION = 1

local function user_version(conn)
  return tonumber(conn:rowexec("PRAGMA user_version")) or 0
end

-- migration[n] applies the change from version n-1 to n. Each runs inside the
-- runner's transaction and must be idempotent-safe only in the sense that the
-- runner never calls it once user_version >= n.
local migration = {}

migration[1] = function(conn)
  for _, statement in ipairs(Schema.STATEMENTS) do
    conn:exec(statement)
  end
  Seed.seed_system_methods(conn)
end

--- Bring `conn` up to CURRENT_SCHEMA_VERSION. No-op when already current.
-- @return CURRENT_SCHEMA_VERSION on success, or nil, err on failure (rolled back).
function Migrations.run(conn)
  conn = conn or require("db/connection").open()
  local from = user_version(conn)
  if from >= Migrations.CURRENT_SCHEMA_VERSION then
    return Migrations.CURRENT_SCHEMA_VERSION
  end

  conn:exec("BEGIN")
  local ok, err = pcall(function()
    for version = from + 1, Migrations.CURRENT_SCHEMA_VERSION do
      logger.dbg("KoffeeLab: applying migration", version)
      migration[version](conn)
    end
    conn:exec("PRAGMA user_version = " .. Migrations.CURRENT_SCHEMA_VERSION)
  end)
  if not ok then
    pcall(conn.exec, conn, "ROLLBACK")
    return nil, tostring(err)
  end
  conn:exec("COMMIT")
  return Migrations.CURRENT_SCHEMA_VERSION
end

return Migrations
