local helper = require("koffeelab.spec_helper")
local Method = require("db/repo/method")
local Recipe = require("db/repo/recipe")

describe("db/repo/method", function()
  before_each(function()
    helper.migrated_connection()
  end)

  after_each(function()
    helper.teardown()
  end)

  it("returns a system method with parameters, step types and equipment nested", function()
    local m = assert(Method.get_by_slug("pour_over"))
    assert.are.equal("Pour Over", m.name)
    assert.is_table(m.parameters)
    assert.is_table(m.step_types)
    assert.is_table(m.equipment)
    assert.is_true(#m.step_types >= 1)
    assert.are.equal("bloom", m.step_types[1].step_type)
  end)

  it("lists active methods by sort order", function()
    local list = Method.list()
    assert.are.equal(5, #list)
    assert.are.equal("pour_over", list[1].slug)
  end)

  it("creates a user method with nested rows in one transaction", function()
    local moka = assert(Method.create_user_method {
      slug = "moka_pot",
      name = "Moka Pot",
      icon = "MP",
      parameters = {
        { key = "heat_level", label = "Heat level", data_type = "text" },
        { key = "prewarm_water", label = "Pre-warm water", data_type = "bool" },
      },
      step_types = { "setup", "extract", "finish" },
      equipment = { "Moka pot", "Stove" },
    })
    assert.are.equal(0, tonumber(moka.is_system))
    assert.are.equal(2, #moka.parameters)
    assert.are.equal(3, #moka.step_types)
    assert.are.equal(2, #moka.equipment)

    local fetched = assert(Method.get_by_slug("moka_pot"))
    assert.are.equal(moka.id, fetched.id)
  end)

  it("blocks a destructive system-method edit that a recipe depends on", function()
    local pour_over = assert(Method.get_by_slug("pour_over"))
    assert(Recipe.create({ title = "V60", method_id = pour_over.id, dose_g = 15 }, {
      { step_type = "bloom", start_time_sec = 0, duration_sec = 30 },
    }))

    -- Drop the "bloom" step type that the recipe above uses.
    local kept = {}
    for _, st in ipairs(pour_over.step_types) do
      if st.step_type ~= "bloom" then
        kept[#kept + 1] = st.step_type
      end
    end
    local ok, err = Method.update_user_method(pour_over.id, {}, { step_types = kept })
    assert.is_nil(ok)
    assert.is_truthy(err:match("bloom"))

    -- The step type is untouched after the rejected edit.
    local after = assert(Method.get_by_slug("pour_over"))
    local has_bloom = false
    for _, st in ipairs(after.step_types) do
      has_bloom = has_bloom or st.step_type == "bloom"
    end
    assert.is_true(has_bloom)
  end)

  it("allows a safe system-method edit (adding a step type)", function()
    local pour_over = assert(Method.get_by_slug("pour_over"))
    local types = {}
    for _, st in ipairs(pour_over.step_types) do
      types[#types + 1] = st.step_type
    end
    types[#types + 1] = "agitate"
    local updated = assert(Method.update_user_method(pour_over.id, {}, { step_types = types }))
    assert.are.equal(#types, #updated.step_types)
  end)

  it("deactivates a method", function()
    local moka = assert(Method.create_user_method { slug = "moka_pot", name = "Moka Pot" })
    assert(Method.set_active(moka.id, false))
    assert.are.equal(5, #Method.list())
    assert.are.equal(6, #Method.list { include_inactive = true })
  end)
end)
