-- ui/backup.lua
-- Backup & Restore screen (TECH_SOLUTION §2.22, §1.20, §3.11). A plain Menu:
--
--   Back up configuration            -> backup_service.export_json{configuration}
--   Back up recipes & history        -> backup_service.export_json{recipes,drinks}
--   Back up the whole database        -> backup_service.backup_file() (the .sqlite3)
--   Restore from a JSON backup        -> PathChooser -> preview counts -> confirm -> import_json
--   Restore from a database file      -> PathChooser -> confirm -> restore_file (swap)
--
-- §2.22 sketches "Restore Configuration / Restore Recipes" as two buttons; a JSON
-- envelope carries whichever sections it was exported with and `import_json`
-- applies them all, so one "Restore from a JSON backup" row covers both without a
-- misleading choice. The file (.sqlite3) path is the primary disaster-recovery
-- mechanism from §1.20 and is needed for the P10.2 device acceptance run.
--
-- Every restore previews and asks for confirmation before touching the DB
-- (§1.20 — never silently overwrite). All work goes through `backup_service`.

local BackupService = require("services/backup_service")
local ConfirmDialog = require("ui/widgets/confirm_dialog")
local InfoMessage = require("ui/widget/infomessage")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local Backup = Menu:extend {
  name = "koffeelab_backup",
  covers_fullscreen = true,
  is_borderless = true,
  is_popout = false,
  is_enable_shortcut = false,
  with_bottom_line = true,
  title_bar_left_icon = "chevron.left",
  title = _("Backup & Restore"),
}

function Backup:init()
  self.item_table = {
    { text = _("Back up configuration"), _action = "backup_config" },
    { text = _("Back up recipes & history"), _action = "backup_recipes" },
    { text = _("Back up the whole database"), _action = "backup_file" },
    { text = _("Restore from a JSON backup"), _action = "restore_json" },
    { text = _("Restore from a database file"), _action = "restore_file" },
  }
  Menu.init(self)
end

local function info(text)
  UIManager:show(InfoMessage:new { text = text })
end

local function warn(text)
  UIManager:show(InfoMessage:new { text = tostring(text), icon = "notice-warning" })
end

local function basename(path)
  return (tostring(path):gsub(".*/", ""))
end

-- ── backup ──────────────────────────────────────────────────────────────────

--- kind = "configuration" | "recipes" | "file"
function Backup:_backup(kind)
  local ok, result
  if kind == "file" then
    ok, result = BackupService.backup_file()
  else
    local sections = kind == "configuration" and { "configuration" } or { "recipes", "drinks" }
    ok, result = BackupService.export_json(nil, { sections = sections })
  end
  if not ok then
    warn(result)
    return false
  end
  info(_("Backup saved:\n") .. basename(result))
  return true
end

-- ── JSON restore ────────────────────────────────────────────────────────────

local function preview_text(counts)
  local lines = { _("This backup contains:") }
  local order = {
    { "beans", _("Beans") },
    { "grinders", _("Grinders") },
    { "ingredients", _("Ingredients") },
    { "flavor_tags", _("Flavor tags") },
    { "methods", _("Brew methods") },
    { "recipes", _("Recipes") },
    { "drinks", _("Custom drinks") },
  }
  for _idx, row in ipairs(order) do -- luacheck: ignore _idx
    local n = tonumber(counts[row[1]]) or 0
    if n > 0 then
      lines[#lines + 1] = string.format("%s: %d", row[2], n)
    end
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = _("Existing entries are matched by name; nothing is deleted.")
  return table.concat(lines, "\n")
end

local function summary_text(s)
  local c = s.config_created or {}
  return table.concat({
    _("Restore complete."),
    "",
    string.format(_("Recipes added: %d"), s.recipes or 0),
    string.format(_("Sessions added: %d"), s.sessions or 0),
    string.format(_("Custom drinks added: %d"), s.drinks or 0),
    string.format(
      _("Config rows created: %d"),
      (c.beans or 0)
        + (c.grinders or 0)
        + (c.ingredients or 0)
        + (c.flavor_tags or 0)
        + (c.methods or 0)
    ),
    (s.drinks_skipped or 0) > 0
        and string.format(_("Drinks skipped (missing base recipe): %d"), s.drinks_skipped)
      or nil,
  }, "\n")
end

--- Validate `path`, show the preview, and on confirmation import it. Returns the
--- import summary on success (for tests); nil otherwise.
function Backup:_restoreJson(path)
  local ok, counts = BackupService.preview_json(path)
  if not ok then
    warn(counts)
    return nil
  end
  local result
  ConfirmDialog.destructive {
    text = preview_text(counts),
    ok_text = _("Restore"),
    on_confirm = function()
      local iok, summary = BackupService.import_json(path)
      if not iok then
        warn(summary)
        return
      end
      result = summary
      info(summary_text(summary))
    end,
  }
  return result
end

-- ── file (.sqlite3) restore ─────────────────────────────────────────────────

function Backup:_restoreFile(path)
  local result
  ConfirmDialog.destructive {
    text = _(
      "Replace the current database with this file?\n\nA timestamped safety copy of the current database is kept."
    ),
    ok_text = _("Replace"),
    on_confirm = function()
      local ok, res = BackupService.restore_file(path)
      if not ok then
        warn(res)
        return
      end
      result = res
      info(_("Database restored. A safety copy of the previous database was kept."))
      if self.nav then
        self.nav:reset(require("ui/home"):new {})
      end
    end,
  }
  return result
end

-- ── file picker ─────────────────────────────────────────────────────────────

function Backup:_pickFile(exts, on_pick)
  local PathChooser = require("ui/widget/pathchooser")
  UIManager:show(PathChooser:new {
    select_directory = false,
    path = BackupService.default_backup_dir(),
    file_filter = function(name)
      local lower = name:lower()
      for _idx, ext in ipairs(exts) do -- luacheck: ignore _idx
        if lower:sub(-#ext) == ext then
          return true
        end
      end
      return false
    end,
    onConfirm = function(path)
      on_pick(path)
    end,
  })
end

function Backup:onMenuChoice(item)
  local action = item and item._action
  if action == "backup_config" then
    self:_backup("configuration")
  elseif action == "backup_recipes" then
    self:_backup("recipes")
  elseif action == "backup_file" then
    self:_backup("file")
  elseif action == "restore_json" then
    self:_pickFile({ ".json" }, function(path)
      self:_restoreJson(path)
    end)
  elseif action == "restore_file" then
    self:_pickFile({ ".sqlite3", ".sqlite" }, function(path)
      self:_restoreFile(path)
    end)
  end
  return true
end

function Backup:_back()
  if self.nav then
    self.nav:pop()
  else
    UIManager:close(self)
  end
  return true
end

Backup.onClose = Backup._back
Backup.onLeftButtonTap = Backup._back

return Backup
