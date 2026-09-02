-- db/migrations.lua
-- Migration runner. Schema version lives in PRAGMA user_version. v2 is a
-- pre-release reset: it drops any legacy tables and rebuilds the v2 baseline
-- (db/schema.lua). There is no data-preserving path from v1.

local Schema = require("db/schema")
local logger = require("logger")

local Migrations = {}

Migrations.CURRENT_SCHEMA_VERSION = 2

local function user_version(conn)
  return tonumber(conn:rowexec("PRAGMA user_version")) or 0
end

local function apply_baseline(conn)
  for _, statement in ipairs(Schema.DROP_LEGACY) do
    conn:exec(statement)
  end
  for _, statement in ipairs(Schema.STATEMENTS) do
    conn:exec(statement)
  end
end

local migration = {}
migration[1] = apply_baseline
migration[2] = apply_baseline

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
