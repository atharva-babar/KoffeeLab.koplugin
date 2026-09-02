require("koffeelab.spec_helper")
local helper = require("koffeelab.spec_helper")

local SampleData = require("services/sample_data")
local SearchService = require("services/search_service")
local ConfigService = require("services/config_service")

describe("services/sample_data", function()
  before_each(function()
    helper.migrated_connection()
  end)

  after_each(function()
    helper.teardown()
  end)

  it("reports an empty catalogue before loading", function()
    assert.is_false(SampleData.loaded())
  end)

  it("loads beans, grinders, recipes, sessions and drinks", function()
    local ok, summary = SampleData.load()
    assert.is_true(ok, tostring(summary))
    assert.is_true(summary.recipes >= 10)
    assert.is_true(summary.drinks >= 3)
    assert.is_true(summary.sessions >= 5)

    assert.is_true(SampleData.loaded())

    local _, recipes = SearchService.recipes {}
    assert.are.equal(summary.recipes, #recipes)
    -- every method is represented
    local methods = {}
    for _, r in ipairs(recipes) do
      methods[r.method_slug] = true
    end
    for _, m in ipairs { "pour_over", "aeropress", "french_press", "espresso", "cold_brew" } do
      assert.is_true(methods[m], "missing sample recipe for " .. m)
    end

    local _, drinks = SearchService.drinks {}
    assert.are.equal(summary.drinks, #drinks)
  end)

  it("does not duplicate config entities on a second load", function()
    assert(SampleData.load())
    local _, beans1 = ConfigService.beans.list { include_inactive = true }
    assert(SampleData.load())
    local _, beans2 = ConfigService.beans.list { include_inactive = true }
    assert.are.equal(#beans1, #beans2)
  end)
end)
