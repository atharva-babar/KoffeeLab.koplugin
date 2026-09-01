-- db/bootstrap.lua
-- One-shot startup: open the session SQLite handle and bring it up to the current
-- schema version (TECH_SOLUTION §3.3 "Application startup flow"). `main.lua` calls
-- `ensure()` from its `init()`; every service reaches the same cached connection
-- through `db/repo/support`. A failure here is recoverable — the plugin still
-- loads its menu entry, and the failure string is surfaced when the user opens it.

local Connection = require("db/connection")
local Migrations = require("db/migrations")
local logger = require("logger")

local Bootstrap = {
  _ready = false,
  _error = nil,
}

--- Open + migrate the on-device database once per session. Idempotent.
-- @return true on success, or `false, err_string` (also cached in `_error`).
function Bootstrap.ensure()
  if Bootstrap._ready then
    return true
  end
  local ok, err = pcall(function()
    local conn = Connection.open()
    local version, merr = Migrations.run(conn)
    if not version then
      error(merr or "migration failed", 0)
    end
  end)
  if not ok then
    Bootstrap._error = tostring(err)
    logger.warn("KoffeeLab: database bootstrap failed:", Bootstrap._error)
    return false, Bootstrap._error
  end
  Bootstrap._ready = true
  logger.dbg("KoffeeLab: database ready")
  return true
end

--- The last bootstrap error, or nil.
function Bootstrap.error()
  return Bootstrap._error
end

return Bootstrap
