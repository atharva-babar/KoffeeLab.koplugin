-- spec/spec_helper.lua
-- Shared bootstrap for KoffeeLab busted specs. They run inside the KOReader
-- emulator's test environment (see `make test` / scripts/test.sh), which provides
-- lua-ljsqlite3, datastorage and logger. This helper puts the plugin's own modules
-- on the require path and pulls in KOReader's standard test globals.
--
-- Specs use an in-memory SQLite DB (Connection.open(":memory:")) seeded per test;
-- they never touch the on-device database file.

pcall(require, "commonrequire")

-- The emulator runs busted with cwd at the koreader install dir; the plugin is
-- symlinked in under plugins/. Add its root so `require("db/connection")` resolves.
local plugin_root = "plugins/KoffeeLab.koplugin/"
if not package.path:find(plugin_root, 1, true) then
  package.path = plugin_root .. "?.lua;" .. package.path
end

local Connection = require("db/connection")

local M = {}

--- Fresh in-memory connection with the schema PRAGMAs applied. Caller closes via
--- M.teardown() (or Connection.close()).
function M.fresh_connection()
  Connection.close()
  return Connection.open(":memory:")
end

--- Fresh in-memory DB migrated to the current schema version (schema + seed).
function M.migrated_connection()
  local conn = M.fresh_connection()
  local Migrations = require("db/migrations")
  assert(Migrations.run(conn))
  return conn
end

function M.teardown()
  Connection.close()
end

return M
