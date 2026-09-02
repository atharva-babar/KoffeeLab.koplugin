require("koffeelab.spec_helper")
local Methods = require("methods/init")
local Derive = require("methods/derive")

describe("methods registry", function()
  it("lists the five built-in methods in order", function()
    local slugs = {}
    for _, m in ipairs(Methods.list()) do
      slugs[#slugs + 1] = m.slug
    end
    assert.are.same({ "pour_over", "aeropress", "french_press", "espresso", "cold_brew" }, slugs)
  end)

  it("returns nil for an unknown slug", function()
    assert.is_nil(Methods.get("chemex_pro"))
  end)

  it("gives every method a name, fields, params and step schema", function()
    for _, m in ipairs(Methods.list()) do
      assert.is_string(m.name)
      assert.is_table(m.fields)
      assert.is_table(m.params)
      assert.is_table(m.steps.types)
      assert.is_table(m.steps.fields)
    end
  end)

  it("models AeroPress orientation and filter type as enums", function()
    local ap = Methods.get("aeropress")
    local by_key = {}
    for _, p in ipairs(ap.params) do
      by_key[p.key] = p
    end
    assert.are.equal("enum", by_key.orientation.type)
    assert.are.same({ "Standard", "Inverted" }, by_key.orientation.options)
    assert.are.same({ "Paper", "Metal", "Flow control" }, by_key.filter_type.options)
  end)

  it("drops the 'finish' step from every method", function()
    for _, m in ipairs(Methods.list()) do
      for _, t in ipairs(m.steps.types) do
        assert.are_not.equal("finish", t)
      end
    end
  end)

  it("does not ask for step duration or cumulative water directly", function()
    for _, m in ipairs(Methods.list()) do
      for _, f in ipairs(m.steps.fields) do
        assert.is_true(f == "start_time" or f == "water" or f == "note")
      end
    end
  end)
end)

describe("methods/derive", function()
  local steps = {
    { step_type = "bloom", start_time = 0, water = 40 },
    { step_type = "pour", start_time = 45, water = 160 },
    { step_type = "pour", start_time = 90, water = 100 },
  }

  it("accumulates water across steps", function()
    assert.are.same({ 40, 200, 300 }, Derive.total_water(steps))
  end)

  it("derives step duration from the next step's start time", function()
    assert.are.equal(45, Derive.duration(steps, 1))
    assert.are.equal(45, Derive.duration(steps, 2))
  end)

  it("uses total brew time for the last step", function()
    assert.are.equal(60, Derive.duration(steps, 3, 150))
    assert.is_nil(Derive.duration(steps, 3))
  end)
end)
