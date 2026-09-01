local helper = require("koffeelab.spec_helper")
local Config = require("db/repo/config")

describe("db/repo/config", function()
  before_each(function()
    helper.migrated_connection()
  end)

  after_each(function()
    helper.teardown()
  end)

  describe("beans", function()
    it("creates, reads and updates a bean with repo-set timestamps", function()
      local bean = assert(Config.beans.create {
        name = "Ethiopia Guji",
        roaster_name = "Blue Tokai",
        roast_level = 2,
      })
      assert.are.equal("Ethiopia Guji", bean.name)
      assert.is_truthy(bean.created_at)
      assert.are.equal(bean.created_at, bean.updated_at)

      local fetched = Config.beans.get(bean.id)
      assert.are.equal("Blue Tokai", fetched.roaster_name)

      local updated = assert(Config.beans.update(bean.id, { roast_level = 4 }))
      assert.are.equal(4, tonumber(updated.roast_level))
    end)

    it("hides inactive beans from list by default", function()
      local a = assert(Config.beans.create { name = "Active" })
      local b = assert(Config.beans.create { name = "Retired" })
      assert(Config.beans.set_active(b.id, false))

      local visible = Config.beans.list()
      assert.are.equal(1, #visible)
      assert.are.equal(a.id, visible[1].id)

      assert.are.equal(2, #Config.beans.list { include_inactive = true })
    end)
  end)

  describe("grinders", function()
    it("round-trips a grinder", function()
      local g = assert(Config.grinders.create {
        name = "Timemore C3S",
        unit_name = "clicks",
        min_value = 1,
        max_value = 30,
        step_value = 1,
      })
      assert.are.equal("clicks", g.unit_name)
      assert.are.equal(30, tonumber(g.max_value))
    end)
  end)

  for _, entity in ipairs { "ingredients", "flavor_tags" } do
    describe(entity, function()
      it("surfaces the unique-name constraint as nil, err", function()
        assert(Config[entity].create { name = "Milk" })
        local dup, err = Config[entity].create { name = "Milk" }
        assert.is_nil(dup)
        assert.is_truthy(err)
      end)

      it("renames and disables", function()
        local row = assert(Config[entity].create { name = "Original" })
        local renamed = assert(Config[entity].update(row.id, { name = "Renamed" }))
        assert.are.equal("Renamed", renamed.name)
        assert(Config[entity].set_active(row.id, false))
        assert.are.equal(0, #Config[entity].list())
      end)
    end)
  end
end)
