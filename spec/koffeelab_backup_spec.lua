local helper = require("koffeelab.spec_helper")
local Connection = require("db/connection")
local Migrations = require("db/migrations")
local BackupService = require("services/backup_service")
local ConfigRepo = require("db/repo/config")
local MethodRepo = require("db/repo/method")
local RecipeRepo = require("db/repo/recipe")
local SessionRepo = require("db/repo/session")
local DrinkRepo = require("db/repo/drink")

-- A scratch directory unique per test, cleaned up in after_each.
local function scratch_dir()
  local base = os.tmpname()
  os.remove(base)
  lfs.mkdir(base)
  return base .. "/"
end

local function rmrf(path)
  if lfs.attributes(path, "mode") == "directory" then
    for entry in lfs.dir(path) do
      if entry ~= "." and entry ~= ".." then
        rmrf(path .. "/" .. entry)
      end
    end
    lfs.rmdir(path)
  elseif path then
    os.remove(path)
  end
end

local function seed_dataset()
  local bean =
    assert(ConfigRepo.beans.create { name = "Ethiopia Guji", roaster_name = "Blue Tokai" })
  local grinder = assert(ConfigRepo.grinders.create {
    name = "Timemore C3S",
    unit_name = "clicks",
    min_value = 1,
    max_value = 30,
    step_value = 1,
  })
  local tag = assert(ConfigRepo.flavor_tags.create { name = "Floral" })
  local milk = assert(ConfigRepo.ingredients.create { name = "Milk" })
  local pour_over = assert(MethodRepo.get_by_slug("pour_over"))
  local espresso = assert(MethodRepo.get_by_slug("espresso"))

  local recipe = assert(RecipeRepo.create({
    title = "Ethiopia Guji V60",
    method_id = pour_over.id,
    bean_id = bean.id,
    grinder_id = grinder.id,
    grind_value = 18,
    dose_g = 15,
    water_g = 250,
    water_temp_c = 93.5,
    acidity = 4,
  }, {
    { step_type = "bloom", start_time_sec = 0, duration_sec = 30, target_water_g = 50 },
    { step_type = "pour", start_time_sec = 30, target_total_water_g = 250 },
  }, {
    { param_id = pour_over.parameters[1].id, value = "Hario V60 02" },
  }, { tag.id }))
  assert(SessionRepo.create { recipe_id = recipe.id, session_rating = 5, comment = "great" })

  local base = assert(RecipeRepo.create {
    title = "Dark Crema",
    method_id = espresso.id,
    dose_g = 18,
    output_weight_g = 36,
  })
  assert(DrinkRepo.create({
    title = "Iced Latte",
    temperature_mode = "cold",
    base_recipe_id = base.id,
    base_amount = 18,
  }, { { ingredient_id = milk.id, amount = 150, unit = "ml" } }))
end

describe("services/backup_service — JSON", function()
  before_each(function()
    helper.migrated_connection()
    seed_dataset()
  end)

  after_each(function()
    helper.teardown()
  end)

  it("exports and re-imports onto a fresh DB, remapping foreign keys", function()
    local dir = scratch_dir()
    finally(function()
      rmrf(dir)
    end)

    local ok, dest = BackupService.export_json(dir)
    assert.is_true(ok)
    assert.is_truthy(dest:match("%.json$"))

    -- Fresh DB, different id space: create a decoy bean so ids won't line up.
    helper.teardown()
    helper.migrated_connection()
    assert(ConfigRepo.beans.create { name = "Decoy", roaster_name = "X" })

    local iok, summary = BackupService.import_json(dest)
    assert.is_true(iok, tostring(summary))
    assert.are.equal(2, summary.recipes)
    assert.are.equal(1, summary.sessions)
    assert.are.equal(1, summary.drinks)

    local recipes = RecipeRepo.list_for_index { search = "Ethiopia" }
    assert.are.equal(1, #recipes)
    local full = RecipeRepo.get(recipes[1].id)
    assert.are.equal("Ethiopia Guji V60", full.title)
    assert.are.equal(2, #full.steps)
    assert.are.equal(1, #full.flavor_tags)
    assert.are.equal("Hario V60 02", full.parameters[1].value)

    -- FK remapped to a bean that actually exists in the new DB.
    local bean = ConfigRepo.beans.get(full.bean_id)
    assert.are.equal("Ethiopia Guji", bean.name)

    local drinks = DrinkRepo.list_for_index {}
    assert.are.equal(1, #drinks)
    local drink = DrinkRepo.get(drinks[1].id)
    assert.are.equal("Dark Crema", drink.base_recipe.title)
    assert.are.equal(1, #drink.ingredients)
  end)

  it("matches embedded config by natural key instead of duplicating", function()
    local dir = scratch_dir()
    finally(function()
      rmrf(dir)
    end)
    local _, dest = BackupService.export_json(dir)

    -- Import back onto the SAME DB: the bean/grinder/tag already exist by name.
    local iok = BackupService.import_json(dest)
    assert.is_true(iok)
    assert.are.equal(1, #ConfigRepo.beans.list())
    assert.are.equal(1, #ConfigRepo.grinders.list())
    assert.are.equal(1, #ConfigRepo.flavor_tags.list())
  end)

  it("rejects a corrupt file without mutating the DB", function()
    local dir = scratch_dir()
    finally(function()
      rmrf(dir)
    end)
    local path = dir .. "broken.json"
    local fh = io.open(path, "wb")
    fh:write("{ this is not json ")
    fh:close()

    local before = #RecipeRepo.all_ids()
    local ok, err = BackupService.import_json(path)
    assert.is_false(ok)
    assert.is_truthy(err)
    assert.are.equal(before, #RecipeRepo.all_ids())
  end)

  it("rejects a newer format/schema version", function()
    local dir = scratch_dir()
    finally(function()
      rmrf(dir)
    end)
    local path = dir .. "future.json"
    local fh = io.open(path, "wb")
    fh:write(
      '{"format":"koffeelab-backup","version":1,"schema_version":999,"recipes":[],"drinks":[]}'
    )
    fh:close()

    local ok, err = BackupService.import_json(path)
    assert.is_false(ok)
    assert.is_truthy(err:match("newer"))
  end)

  it("previews counts without applying", function()
    local dir = scratch_dir()
    finally(function()
      rmrf(dir)
    end)
    local _, dest = BackupService.export_json(dir)
    local ok, counts = BackupService.preview_json(dest)
    assert.is_true(ok)
    assert.are.equal(2, counts.recipes)
    assert.are.equal(1, counts.drinks)
  end)
end)

describe("services/backup_service — file", function()
  local db_path

  before_each(function()
    Connection.close()
    db_path = os.tmpname()
    os.remove(db_path)
    local conn = Connection.open(db_path)
    assert(Migrations.run(conn))
    seed_dataset()
  end)

  after_each(function()
    Connection.close()
    os.remove(db_path)
  end)

  it("backs up the sqlite file and restores it after data loss", function()
    local dir = scratch_dir()
    finally(function()
      rmrf(dir)
    end)

    local ok, backup_path = BackupService.backup_file(dir)
    assert.is_true(ok, tostring(backup_path))
    assert.is_truthy(lfs.attributes(backup_path, "mode"))

    -- Destroy the live data (drinks first — they RESTRICT their base recipe).
    for _, id in ipairs(DrinkRepo.all_ids()) do
      DrinkRepo.delete(id)
    end
    for _, id in ipairs(RecipeRepo.all_ids()) do
      RecipeRepo.delete(id)
    end
    assert.are.equal(0, #RecipeRepo.all_ids())

    local rok, result = BackupService.restore_file(backup_path)
    assert.is_true(rok, tostring(result))
    assert.are.equal(2, #RecipeRepo.all_ids())
  end)

  it("refuses a file whose user_version is newer than the code", function()
    local dir = scratch_dir()
    finally(function()
      rmrf(dir)
    end)
    local bogus = dir .. "future.sqlite3"
    local sqlite = require("lua-ljsqlite3/init")
    local h = sqlite.open(bogus)
    h:exec("PRAGMA user_version = 999")
    h:exec("CREATE TABLE x (id INTEGER)")
    h:close()

    local before = #RecipeRepo.all_ids()
    local ok, err = BackupService.restore_file(bogus)
    assert.is_false(ok)
    assert.is_truthy(err:match("newer"))
    assert.are.equal(before, #RecipeRepo.all_ids())
  end)
end)
