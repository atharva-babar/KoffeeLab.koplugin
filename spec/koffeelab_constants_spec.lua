require("koffeelab.spec_helper")
local Constants = require("util/constants")

describe("util/constants", function()
  it("lists the §1.12 built-in step types with a label for each", function()
    assert.are.equal(15, #Constants.STEP_TYPES)
    for _, step_type in ipairs(Constants.STEP_TYPES) do
      assert.is_string(Constants.STEP_TYPE_LABELS[step_type])
    end
    assert.are.equal("Bloom", Constants.STEP_TYPE_LABELS.bloom)
  end)

  it("maps the five §0.12 roast levels", function()
    assert.are.equal(5, #Constants.ROAST_LEVELS)
    assert.are.equal("Very Light", Constants.ROAST_LABELS[1])
    assert.are.equal("Dark", Constants.ROAST_LABELS[5])
    assert.is_nil(Constants.ROAST_LABELS[6])
  end)

  it("exposes the hot/cold temperature modes", function()
    assert.are.equal("Hot", Constants.TEMPERATURE_MODE_LABELS.hot)
    assert.are.equal("Cold", Constants.TEMPERATURE_MODE_LABELS.cold)
    assert.is_nil(Constants.TEMPERATURE_MODE_LABELS.lukewarm)
  end)

  it("fixes the five sensory axes in render order", function()
    local keys = {}
    for _, axis in ipairs(Constants.SENSORY_AXES) do
      table.insert(keys, axis.key)
    end
    assert.are.same({ "acidity", "sweetness", "strength", "body", "brightness" }, keys)
  end)

  it("names the five system methods", function()
    assert.are.same(
      { "pour_over", "aeropress", "french_press", "espresso", "cold_brew" },
      Constants.SYSTEM_METHOD_SLUGS
    )
  end)
end)
