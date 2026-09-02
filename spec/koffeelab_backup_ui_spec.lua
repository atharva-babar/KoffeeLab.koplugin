require("koffeelab.spec_helper")
local Nav = require("ui/nav")
local Screen = require("device").screen

local Connection = require("db/connection")
local Migrations = require("db/migrations")
local BackupService = require("services/backup_service")
local ConfirmDialog = require("ui/widgets/confirm_dialog")
local ConfigRepo = require("db/repo/config")
local RecipeRepo = require("db/repo/recipe")
local DrinkRepo = require("db/repo/drink")
local SessionRepo = require("db/repo/session")

local Backup = require("ui/backup")

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

local function files_matching(dir, pat)
  local out = {}
  for f in lfs.dir(dir) do
    if f:match(pat) then
      out[#out + 1] = dir .. f
    end
  end
  return out
end

local function seed()
  local bean =
    assert(ConfigRepo.beans.create { name = "Ethiopia Guji", roaster_name = "Blue Tokai" })
  local grinder = assert(ConfigRepo.grinders.create {
    name = "Timemore C3S",
    unit_name = "clicks",
    min_value = 1,
    max_value = 30,
    step_value = 1,
  })
  local milk = assert(ConfigRepo.ingredients.create { name = "Milk" })
  local recipe = assert(RecipeRepo.create({
    title = "Guji V60",
    method_slug = "pour_over",
    bean_id = bean.id,
    grinder_id = grinder.id,
    grind_value = 18,
    dose_g = 15,
    water_g = 250,
  }, {}))
  assert(SessionRepo.create { recipe_id = recipe.id, session_rating = 5 })
  local base = assert(RecipeRepo.create {
    title = "Dark Crema",
    method_slug = "espresso",
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

local function wipe_data()
  for _, id in ipairs(DrinkRepo.all_ids()) do
    DrinkRepo.delete(id)
  end
  for _, id in ipairs(RecipeRepo.all_ids()) do
    RecipeRepo.delete(id)
  end
end

describe("ui/backup (Backup UI — Phase 9)", function()
  local dir, db_path, orig_dir_fn, orig_destructive

  before_each(function()
    Connection.close()
    db_path = os.tmpname()
    os.remove(db_path)
    assert(Migrations.run(Connection.open(db_path)))
    seed()

    dir = scratch_dir()
    orig_dir_fn = BackupService.default_backup_dir
    BackupService.default_backup_dir = function()
      return dir
    end
    orig_destructive = ConfirmDialog.destructive
    Nav:closeAll()
  end)

  after_each(function()
    BackupService.default_backup_dir = orig_dir_fn
    ConfirmDialog.destructive = orig_destructive
    Nav:closeAll()
    Connection.close()
    os.remove(db_path)
    rmrf(dir)
  end)

  it("renders the five action rows", function()
    local screen = Nav:push(Backup:new {})
    screen:paintTo(Screen.bb, 0, 0)
    assert.are.equal(5, #screen.item_table)
  end)

  describe("backup", function()
    it("writes a configuration JSON file", function()
      local screen = Backup:new {}
      assert.is_true(screen:_backup("configuration"))
      assert.are.equal(1, #files_matching(dir, "%.json$"))
    end)

    it("writes a recipes JSON file and a full database file", function()
      local screen = Backup:new {}
      assert.is_true(screen:_backup("recipes"))
      assert.is_true(screen:_backup("file"))
      assert.are.equal(1, #files_matching(dir, "%.json$"))
      assert.are.equal(1, #files_matching(dir, "%.sqlite3$"))
    end)

    it("a menu tap routes to the backup action", function()
      local screen = Nav:push(Backup:new {})
      assert.is_true(screen:onMenuChoice { _action = "backup_config" })
      assert.are.equal(1, #files_matching(dir, "%.json$"))
    end)
  end)

  describe("JSON restore", function()
    it("previews then restores onto a wiped database", function()
      local screen = Backup:new {}
      assert.is_true(screen:_backup("recipes"))
      local path = files_matching(dir, "%.json$")[1]

      wipe_data()
      assert.are.equal(0, #RecipeRepo.all_ids())

      ConfirmDialog.destructive = function(opts)
        opts.on_confirm()
      end
      local summary = screen:_restoreJson(path)
      assert.is_table(summary)
      assert.are.equal(2, summary.recipes)
      assert.are.equal(1, summary.sessions)
      assert.are.equal(1, summary.drinks)
      assert.are.equal(2, #RecipeRepo.all_ids())
    end)

    it("rejects a corrupt file and changes nothing (no confirm shown)", function()
      local path = dir .. "broken.json"
      local fh = io.open(path, "wb")
      fh:write("{ not valid json ")
      fh:close()

      local shown = false
      ConfirmDialog.destructive = function()
        shown = true
      end
      local before = #RecipeRepo.all_ids()
      local screen = Backup:new {}
      assert.is_nil(screen:_restoreJson(path))
      assert.is_false(shown)
      assert.are.equal(before, #RecipeRepo.all_ids())
    end)
  end)

  describe("database-file restore", function()
    it("swaps a .sqlite3 backup back in after data loss", function()
      local screen = Backup:new {}
      assert.is_true(screen:_backup("file"))
      local path = files_matching(dir, "%.sqlite3$")[1]

      wipe_data()
      assert.are.equal(0, #RecipeRepo.all_ids())

      ConfirmDialog.destructive = function(opts)
        opts.on_confirm()
      end
      local result = screen:_restoreFile(path)
      assert.is_table(result)
      assert.are.equal(2, #RecipeRepo.all_ids())
    end)
  end)
end)
