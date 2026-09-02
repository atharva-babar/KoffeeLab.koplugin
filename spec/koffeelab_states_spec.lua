require("koffeelab.spec_helper")
local helper = require("koffeelab.spec_helper")
local Nav = require("ui/nav")
local Screen = require("device").screen

local ConfigService = require("services/config_service")
local RecipeService = require("services/recipe_service")
local DrinkService = require("services/drink_service")
local RecipeRepo = require("db/repo/recipe")
local DrinkRepo = require("db/repo/drink")

-- A string a user could actually read: non-empty, no raw sqlite / stack noise.
local function readable(s)
  return type(s) == "string"
    and s:match("%S") ~= nil
    and not s:lower():find("ljsqlite3")
    and not s:lower():find("traceback")
    and not s:lower():find("attempt to")
end

local function find_row(screen, needle)
  for _, item in ipairs(screen.item_table) do
    if tostring(item.text):find(needle, 1, true) then
      return item
    end
  end
end

describe("empty & error states (Phase 10)", function()
  before_each(function()
    helper.migrated_connection()
    Nav:closeAll()
  end)

  after_each(function()
    Nav:closeAll()
    helper.teardown()
  end)

  describe("a fresh install is fully navigable", function()
    it("Home → Index → both indexes render with helpful empty rows", function()
      local Home = require("ui/home")
      local home = Nav:reset(Home:new {})
      home:paintTo(Screen.bb, 0, 0)

      local RecipeIndex = require("ui/recipe/index")
      local ri = Nav:push(RecipeIndex:new {})
      ri:paintTo(Screen.bb, 0, 0)
      assert.is_truthy(find_row(ri, "No recipes yet"))
      -- an inert empty row must not blow up when tapped
      assert.is_true(ri:onMenuChoice(find_row(ri, "No recipes yet")))
      Nav:pop()

      local DrinkIndex = require("ui/drink/index")
      local di = Nav:push(DrinkIndex:new {})
      di:paintTo(Screen.bb, 0, 0)
      assert.is_truthy(find_row(di, "No custom drinks yet"))
      assert.is_true(di:onMenuChoice(find_row(di, "No custom drinks yet")))
    end)

    it("every Configurator list screen renders with an empty-state row", function()
      for _, mod in ipairs {
        "ui/config/beans",
        "ui/config/grinders",
        "ui/config/ingredients",
        "ui/config/flavor_tags",
      } do
        local screen = Nav:push(require(mod):new {})
        screen:paintTo(Screen.bb, 0, 0)
        assert.is_truthy(find_row(screen, "No "), mod .. " has no empty-state row")
        Nav:pop()
      end
    end)

    it("the method picker and configurator open on a fresh DB", function()
      local Configurator = require("ui/configurator")
      local c = Nav:push(Configurator:new {})
      c:paintTo(Screen.bb, 0, 0)
      assert.is_true(#c.item_table >= 5)
      Nav:pop()

      -- 5 system methods are seeded, so the picker shows cards (not the empty state)
      local MethodSelect = require("ui/recipe/method_select")
      local ms = Nav:push(MethodSelect:new { on_pick = function() end })
      ms:paintTo(Screen.bb, 0, 0)
      Nav:pop()
    end)

    it("filtered indexes say 'no match' rather than 'nothing yet'", function()
      local RecipeIndex = require("ui/recipe/index")
      local ri = RecipeIndex:new {}
      ri.search = "zzz-nope"
      ri:refresh()
      assert.is_truthy(find_row(ri, "No recipes match"))
    end)
  end)

  describe("service errors are readable", function()
    it("recipe validation", function()
      local ok, err = RecipeService.create {}
      assert.is_false(ok)
      assert.is_true(readable(err), err)
      assert.are.equal("title is required", err)
    end)

    it("custom-drink validation", function()
      local ok, err = DrinkService.create { title = "X" }
      assert.is_false(ok)
      assert.is_true(readable(err), err)
    end)

    it("config validation", function()
      local ok, err = ConfigService.beans.create {}
      assert.is_false(ok)
      assert.is_true(readable(err), err)
      assert.are.equal("bean name is required", err)
    end)

    it("a duplicate name surfaces a friendly unique-constraint message", function()
      assert(ConfigService.ingredients.create { name = "Milk" })
      local ok, err = ConfigService.ingredients.create { name = "Milk" }
      assert.is_false(ok)
      assert.is_true(readable(err), err)
      assert.is_truthy(err:lower():find("already in use"))
    end)

    it("the recipe delete guard reports the referencing drink count", function()
      local ok, base = RecipeService.create({
        title = "Base",
        method_slug = "espresso",
        dose_g = 18,
        output_weight_g = 36,
      }, {}, {}, {})
      assert(ok, base)
      local milk = select(2, ConfigService.ingredients.create { name = "Milk" })
      assert(DrinkService.create({
        title = "Latte",
        temperature_mode = "cold",
        base_recipe_id = base.id,
        base_amount = 18,
      }, { { ingredient_id = milk.id, amount = 100, unit = "ml" } }, {}))

      local dok, derr = RecipeService.delete(base.id)
      assert.is_false(dok)
      assert.is_true(readable(derr), derr)
      assert.is_truthy(derr:find("1 custom drink"))
    end)

    it("config hard-delete is refused with an explanation, not a crash", function()
      local ok, err = ConfigService.beans.delete(1)
      assert.is_false(ok)
      assert.is_true(readable(err), err)
    end)

    it("get on a missing row is a clean error, not nil-deref", function()
      local ok, err = RecipeService.get(99999)
      assert.is_false(ok)
      assert.is_true(readable(err), err)
      assert.is_false((DrinkService.get(99999)))
    end)
  end)

  describe("detail screens survive a deleted target", function()
    it("recipe detail renders a single inert 'not found' card", function()
      local RecipeDetail = require("ui/recipe/detail")
      local d = Nav:push(RecipeDetail:new { recipe_id = 99999 })
      d:paintTo(Screen.bb, 0, 0)
      assert.is_true(d.not_found)
      assert.are.equal(1, #d.cards)
    end)

    it("drink detail renders a single inert 'not found' card", function()
      local DrinkDetail = require("ui/drink/detail")
      local d = Nav:push(DrinkDetail:new { drink_id = 99999 })
      d:paintTo(Screen.bb, 0, 0)
      assert.is_true(d.not_found)
      assert.are.equal(1, #d.cards)
    end)
  end)

  it("no orphaned rows: wiping data leaves the DB queryable", function()
    assert.are.equal(0, #RecipeRepo.all_ids())
    assert.are.equal(0, #DrinkRepo.all_ids())
    local _, rows = RecipeService.list_for_index {}
    assert.are.same({}, rows)
  end)
end)
