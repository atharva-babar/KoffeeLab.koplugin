-- services/backup_service.lua
-- Backup & restore. File mode copies koffeelab.sqlite3 to a USB-visible folder;
-- JSON mode writes a versioned, portable envelope whose recipe/drink sections
-- embed the config rows they reference (integer ids are not portable). Import
-- matches config by natural key, remaps foreign keys and inserts, in one
-- transaction.

local rapidjson = require("rapidjson")
local util = require("util")
local DataStorage = require("datastorage")

local Connection = require("db/connection")
local DbBackup = require("db/backup")
local ConfigRepo = require("db/repo/config")
local RecipeRepo = require("db/repo/recipe")
local SessionRepo = require("db/repo/session")
local DrinkRepo = require("db/repo/drink")
local Methods = require("methods/init")
local Support = require("services/support")

local BackupService = {}

BackupService.FORMAT = "koffeelab-backup"
BackupService.FORMAT_VERSION = 2

local ALL_SECTIONS = { "configuration", "recipes", "drinks" }

local function timestamp()
  return os.date("!%Y%m%d-%H%M%S")
end

-- lua-ljsqlite3 hands back INTEGER columns as LuaJIT int64 cdata, which rapidjson
-- cannot encode. Coerce every cdata number to a Lua number.
local function sanitize(value)
  local t = type(value)
  if t == "cdata" then
    return tonumber(value)
  elseif t == "table" then
    local out = {}
    for k, v in pairs(value) do
      out[k] = sanitize(v)
    end
    return out
  end
  return value
end

local function to_set(list)
  local set = {}
  for _, v in ipairs(list) do
    set[v] = true
  end
  return set
end

function BackupService.default_backup_dir()
  for _, root in ipairs { "/mnt/us", "/mnt/onboard", "/mnt/sdcard" } do
    if util.directoryExists(root) then
      return root .. "/koffeelab/backups/"
    end
  end
  return DataStorage:getDataDir() .. "/koffeelab/backups/"
end

-- File backup / restore -----------------------------------------------------

function BackupService.backup_file(dest_dir)
  dest_dir = dest_dir or BackupService.default_backup_dir()
  local src = Connection.path()
  if not src or src == ":memory:" then
    return Support.err("no on-disk database to back up")
  end
  local made, merr = util.makePath(dest_dir)
  if not made then
    return Support.err("cannot create backup folder: " .. tostring(merr))
  end
  DbBackup.checkpoint()
  local dest = dest_dir .. "koffeelab-" .. timestamp() .. ".sqlite3"
  local copied, cerr = DbBackup.copy_file(src, dest)
  if not copied then
    return Support.err("copy failed: " .. tostring(cerr))
  end
  return Support.ok(dest)
end

function BackupService.restore_file(path)
  if not util.pathExists(path) then
    return Support.err("backup file not found")
  end
  local version, verr = DbBackup.probe_user_version(path)
  if not version then
    return Support.err(verr)
  end
  if version > DbBackup.CURRENT_SCHEMA_VERSION then
    return Support.err("that backup is from a newer version of KoffeeLab")
  end
  local ok, result = DbBackup.swap_in(path)
  if not ok then
    return Support.err(result)
  end
  return Support.ok { safety_copy = result }
end

-- JSON export -------------------------------------------------------------

local function bean_ref(id)
  local b = id and ConfigRepo.beans.get(id)
  if not b then
    return nil
  end
  return { name = b.name, roaster_name = b.roaster_name, roast_level = b.roast_level }
end

local function grinder_ref(id)
  local g = id and ConfigRepo.grinders.get(id)
  if not g then
    return nil
  end
  return {
    name = g.name,
    unit_name = g.unit_name,
    min_value = g.min_value,
    max_value = g.max_value,
    step_value = g.step_value,
  }
end

local RECIPE_COLUMN_KEYS = {
  "grind_value",
  "dose_g",
  "water_g",
  "water_temp_c",
  "brew_time_sec",
  "output_weight_g",
  "output_note",
  "is_favorite",
  "acidity",
  "sweetness",
  "strength",
  "body",
  "brightness",
  "overall_rating",
  "notes",
}

local function export_recipe(id)
  local r = RecipeRepo.get(id)
  local flavor_tags = {}
  for _, t in ipairs(r.flavor_tags) do
    flavor_tags[#flavor_tags + 1] = t.name
  end
  local sessions = {}
  for _, s in ipairs(SessionRepo.list_for_recipe(id)) do
    sessions[#sessions + 1] = {
      brewed_at = s.brewed_at,
      session_rating = s.session_rating,
      measured_brew_time_sec = s.measured_brew_time_sec,
      comment = s.comment,
    }
  end
  local out = {
    title = r.title,
    method = r.method_slug,
    bean = bean_ref(r.bean_id),
    grinder = grinder_ref(r.grinder_id),
    is_active = r.is_active,
    spec = r.spec,
    steps = r.steps,
    flavor_tags = flavor_tags,
    sessions = sessions,
  }
  for _, k in ipairs(RECIPE_COLUMN_KEYS) do
    out[k] = r[k]
  end
  return out
end

local function export_drink(id)
  local d = DrinkRepo.get(id)
  local base = RecipeRepo.get(d.base_recipe_id)
  local ingredients = {}
  for _, ing in ipairs(d.ingredients) do
    ingredients[#ingredients + 1] =
      { name = ing.ingredient_name, amount = ing.amount, unit = ing.unit }
  end
  local steps = {}
  for _, s in ipairs(d.steps) do
    steps[#steps + 1] = { instruction = s.instruction, note = s.note }
  end
  return {
    title = d.title,
    temperature_mode = d.temperature_mode,
    base_recipe = base and { title = base.title, method = base.method_slug } or nil,
    base_amount = d.base_amount,
    base_unit = d.base_unit,
    rating = d.rating,
    comment = d.comment,
    is_active = d.is_active,
    ingredients = ingredients,
    steps = steps,
  }
end

function BackupService.build_envelope(sections)
  local env = {
    format = BackupService.FORMAT,
    version = BackupService.FORMAT_VERSION,
    schema_version = DbBackup.CURRENT_SCHEMA_VERSION,
    created_at = os.time(),
    configuration = {},
    recipes = {},
    drinks = {},
  }

  if sections.configuration then
    env.configuration = {
      beans = ConfigRepo.beans.list { include_inactive = true },
      grinders = ConfigRepo.grinders.list { include_inactive = true },
      ingredients = ConfigRepo.ingredients.list { include_inactive = true },
      flavor_tags = ConfigRepo.flavor_tags.list { include_inactive = true },
    }
  end

  if sections.recipes then
    for _, id in ipairs(RecipeRepo.all_ids()) do
      env.recipes[#env.recipes + 1] = export_recipe(id)
    end
  end

  if sections.drinks then
    for _, id in ipairs(DrinkRepo.all_ids()) do
      env.drinks[#env.drinks + 1] = export_drink(id)
    end
  end

  return env
end

function BackupService.export_json(dest_dir, opts)
  dest_dir = dest_dir or BackupService.default_backup_dir()
  opts = opts or {}
  local sections = to_set(opts.sections or ALL_SECTIONS)

  local made, merr = util.makePath(dest_dir)
  if not made then
    return Support.err("cannot create backup folder: " .. tostring(merr))
  end

  local env = sanitize(BackupService.build_envelope(sections))
  local encoded, eerr = rapidjson.encode(env, { pretty = true, sort_keys = true })
  if not encoded then
    return Support.err("could not encode backup: " .. tostring(eerr))
  end
  local dest = dest_dir .. "koffeelab-" .. timestamp() .. ".json"
  local fh, ferr = io.open(dest, "wb")
  if not fh then
    return Support.err("cannot write backup: " .. tostring(ferr))
  end
  fh:write(encoded)
  fh:close()
  return Support.ok(dest)
end

-- JSON import -------------------------------------------------------------

local function load_envelope(path)
  if not util.pathExists(path) then
    return nil, "backup file not found"
  end
  local fh, ferr = io.open(path, "rb")
  if not fh then
    return nil, "cannot read backup: " .. tostring(ferr)
  end
  local raw = fh:read("*a")
  fh:close()
  local ok, data = pcall(rapidjson.decode, raw)
  if not ok or type(data) ~= "table" then
    return nil, "file is not valid JSON"
  end
  if data.format ~= BackupService.FORMAT then
    return nil, "not a KoffeeLab backup file"
  end
  if tonumber(data.schema_version or 0) > DbBackup.CURRENT_SCHEMA_VERSION then
    return nil, "that backup is from a newer version of KoffeeLab"
  end
  if tonumber(data.version) ~= BackupService.FORMAT_VERSION then
    return nil, "unsupported backup format version"
  end
  return data
end

local function count(list)
  return type(list) == "table" and #list or 0
end

function BackupService.preview_json(path)
  local data, err = load_envelope(path)
  if not data then
    return Support.err(err)
  end
  local config = data.configuration or {}
  return Support.ok {
    beans = count(config.beans),
    grinders = count(config.grinders),
    ingredients = count(config.ingredients),
    flavor_tags = count(config.flavor_tags),
    recipes = count(data.recipes),
    drinks = count(data.drinks),
  }
end

local function make_resolvers()
  local caches = { beans = {}, grinders = {}, ingredients = {}, flavor_tags = {} }
  local created = { beans = 0, grinders = 0, ingredients = 0, flavor_tags = 0 }

  local bean_index, grinder_index, ingredient_index, tag_index = {}, {}, {}, {}
  for _, b in ipairs(ConfigRepo.beans.list { include_inactive = true }) do
    bean_index[(b.roaster_name or "") .. "\0" .. b.name] = b.id
  end
  for _, g in ipairs(ConfigRepo.grinders.list { include_inactive = true }) do
    grinder_index[g.name] = g.id
  end
  for _, i in ipairs(ConfigRepo.ingredients.list { include_inactive = true }) do
    ingredient_index[i.name] = i.id
  end
  for _, t in ipairs(ConfigRepo.flavor_tags.list { include_inactive = true }) do
    tag_index[t.name] = t.id
  end

  local R = {}

  function R.bean(ref)
    if not ref or not ref.name then
      return nil
    end
    local key = (ref.roaster_name or "") .. "\0" .. ref.name
    if caches.beans[key] then
      return caches.beans[key]
    end
    local id = bean_index[key]
    if not id then
      id = assert(ConfigRepo.beans.create {
        name = ref.name,
        roaster_name = ref.roaster_name or "",
        roast_level = ref.roast_level,
      }).id
      created.beans = created.beans + 1
    end
    caches.beans[key] = id
    return id
  end

  function R.grinder(ref)
    if not ref or not ref.name then
      return nil
    end
    if caches.grinders[ref.name] then
      return caches.grinders[ref.name]
    end
    local id = grinder_index[ref.name]
    if not id then
      id = assert(ConfigRepo.grinders.create {
        name = ref.name,
        unit_name = ref.unit_name or "setting",
        min_value = ref.min_value or 0,
        max_value = ref.max_value or 100,
        step_value = ref.step_value or 1,
      }).id
      created.grinders = created.grinders + 1
    end
    caches.grinders[ref.name] = id
    return id
  end

  function R.ingredient(name)
    if not name then
      return nil
    end
    if caches.ingredients[name] then
      return caches.ingredients[name]
    end
    local id = ingredient_index[name]
    if not id then
      id = assert(ConfigRepo.ingredients.create { name = name }).id
      created.ingredients = created.ingredients + 1
    end
    caches.ingredients[name] = id
    return id
  end

  function R.tag(name)
    if not name then
      return nil
    end
    if caches.flavor_tags[name] then
      return caches.flavor_tags[name]
    end
    local id = tag_index[name]
    if not id then
      id = assert(ConfigRepo.flavor_tags.create { name = name }).id
      created.flavor_tags = created.flavor_tags + 1
    end
    caches.flavor_tags[name] = id
    return id
  end

  return R, created
end

local function apply(data)
  local resolve, created = make_resolvers()
  local summary =
    { config_created = created, recipes = 0, sessions = 0, drinks = 0, drinks_skipped = 0 }

  local config = data.configuration or {}
  for _, b in ipairs(config.beans or {}) do
    resolve.bean(b)
  end
  for _, g in ipairs(config.grinders or {}) do
    resolve.grinder(g)
  end
  for _, i in ipairs(config.ingredients or {}) do
    resolve.ingredient(i.name)
  end
  for _, t in ipairs(config.flavor_tags or {}) do
    resolve.tag(t.name)
  end

  local recipe_ids_by_key = {}
  for _, rec in ipairs(data.recipes or {}) do
    if not Methods.get(rec.method) then
      error("recipe '" .. tostring(rec.title) .. "' uses an unknown brew method", 0)
    end
    local recipe = {
      title = rec.title,
      method_slug = rec.method,
      bean_id = resolve.bean(rec.bean),
      grinder_id = resolve.grinder(rec.grinder),
      spec = rec.spec or {},
      steps = rec.steps or {},
    }
    for _, k in ipairs(RECIPE_COLUMN_KEYS) do
      recipe[k] = rec[k]
    end
    local tag_ids = {}
    for _, name in ipairs(rec.flavor_tags or {}) do
      tag_ids[#tag_ids + 1] = resolve.tag(name)
    end
    local row = assert(RecipeRepo.create(recipe, tag_ids))
    summary.recipes = summary.recipes + 1
    recipe_ids_by_key[(rec.title or "") .. "\0" .. rec.method] = row.id

    for _, sess in ipairs(rec.sessions or {}) do
      assert(SessionRepo.create {
        recipe_id = row.id,
        brewed_at = sess.brewed_at,
        session_rating = sess.session_rating,
        measured_brew_time_sec = sess.measured_brew_time_sec,
        comment = sess.comment,
      })
      summary.sessions = summary.sessions + 1
    end
  end

  for _, dr in ipairs(data.drinks or {}) do
    local base = dr.base_recipe or {}
    local base_id = base.title
      and recipe_ids_by_key[(base.title or "") .. "\0" .. (base.method or "")]
    if not base_id and base.title then
      local found = RecipeRepo.find_by_title(base.title, base.method)
      base_id = found and found.id or nil
    end
    if not base_id then
      summary.drinks_skipped = summary.drinks_skipped + 1
    else
      local ingredients = {}
      for _, ing in ipairs(dr.ingredients or {}) do
        ingredients[#ingredients + 1] =
          { ingredient_id = resolve.ingredient(ing.name), amount = ing.amount, unit = ing.unit }
      end
      assert(DrinkRepo.create({
        title = dr.title,
        temperature_mode = dr.temperature_mode,
        base_recipe_id = base_id,
        base_amount = dr.base_amount,
        base_unit = dr.base_unit or "g",
        rating = dr.rating,
        comment = dr.comment,
      }, ingredients, dr.steps or {}))
      summary.drinks = summary.drinks + 1
    end
  end

  return summary
end

function BackupService.import_json(path)
  local data, err = load_envelope(path)
  if not data then
    return Support.err(err)
  end
  local summary
  local ok, terr = Connection.with_transaction(function()
    summary = apply(data)
    return summary
  end)
  if not ok then
    return Support.err(terr)
  end
  return Support.ok(summary)
end

return BackupService
