-- db/backup.lua
-- The file-level SQLite operations behind services/backup_service.lua (§1.20). SQL
-- and the sqlite handle stay in db/ (§Conventions 4); the service owns the JSON
-- envelope, the natural-key matching and the USB paths.

local SQ3 = require("lua-ljsqlite3/init")
local ffiutil = require("ffi/util")
local Connection = require("db/connection")
local Migrations = require("db/migrations")

local Backup = {}

--- Make the main DB file self-contained before it is copied (§1.20). No-op under
--- journal_mode = TRUNCATE, but harmless and correct if WAL is ever enabled.
function Backup.checkpoint()
  local conn = Connection.open()
  pcall(function()
    conn:exec("PRAGMA wal_checkpoint(TRUNCATE)")
  end)
end

--- Read `PRAGMA user_version` from a standalone SQLite file without disturbing the
--- session handle. Returns a number, or nil, err when the file will not open.
function Backup.probe_user_version(path)
  local ok, handle = pcall(SQ3.open, path)
  if not ok or not handle then
    return nil, "cannot open database file"
  end
  local ok_read, version = pcall(function()
    return tonumber(handle:rowexec("PRAGMA user_version"))
  end)
  handle:close()
  if not ok_read then
    return nil, "file is not a readable database"
  end
  return version or 0
end

Backup.CURRENT_SCHEMA_VERSION = Migrations.CURRENT_SCHEMA_VERSION

--- Copy `from` to `to`. Returns true, or nil, err.
function Backup.copy_file(from, to)
  local err = ffiutil.copyFile(from, to)
  if err then
    return nil, err
  end
  return true
end

--- Replace the live database file with `src` (already validated by the caller),
--- keeping a timestamped safety copy of the current file first. Reopens the session
--- handle and runs migrations. Returns true, or nil, err (after best-effort rollback
--- to the safety copy).
function Backup.swap_in(src)
  local target = Connection.path()
  if not target or target == ":memory:" then
    return nil, "no on-disk database to replace"
  end
  local safety = target .. ".pre-restore-" .. os.time()

  local ok, err = Backup.copy_file(target, safety)
  if not ok then
    return nil, "could not create a safety copy: " .. tostring(err)
  end

  Connection.close()

  ok, err = Backup.copy_file(src, target)
  if not ok then
    Backup.copy_file(safety, target) -- put the original back
    Connection.open(target)
    return nil, "restore failed, original kept: " .. tostring(err)
  end

  local migrated, merr = Migrations.run(Connection.open(target))
  if not migrated then
    Connection.close()
    Backup.copy_file(safety, target)
    Connection.open(target)
    return nil, "restored file could not be migrated: " .. tostring(merr)
  end

  return true, safety
end

return Backup
