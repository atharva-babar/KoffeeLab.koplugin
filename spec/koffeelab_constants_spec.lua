require("koffeelab.spec_helper")
local Constants = require("util/constants")

describe("util/constants", function()
  it("labels the step types used across methods", function()
    assert.are.equal("Bloom", Constants.STEP_TYPE_LABELS.bloom)
    assert.are.equal("Pre-infuse", Constants.STEP_TYPE_LABELS.preinfuse)
  end)

  it("maps the five roast levels", function()
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

  it("offers ingredient units", function()
    assert.is_true(#Constants.INGREDIENT_UNITS > 1)
    assert.are.equal("g", Constants.INGREDIENT_UNITS[1])
  end)
end)
