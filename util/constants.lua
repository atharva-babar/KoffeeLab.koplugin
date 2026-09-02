-- util/constants.lua
-- Read-only domain labels surfaced in the UI. Pure data, no DB, no widgets.

local _ = require("gettext")

local Constants = {}

-- step_type -> display label (superset across every method in methods/).
Constants.STEP_TYPE_LABELS = {
  setup = _("Setup"),
  bloom = _("Bloom"),
  pour = _("Pour"),
  wait = _("Wait"),
  stir = _("Stir"),
  swirl = _("Swirl"),
  drawdown = _("Drawdown"),
  press = _("Press"),
  bypass = _("Bypass"),
  immerse = _("Immerse"),
  plunge = _("Plunge"),
  decant = _("Decant"),
  preinfuse = _("Pre-infuse"),
  extract = _("Extract"),
}

Constants.ROAST_LEVELS = {
  { value = 1, label = _("Very Light") },
  { value = 2, label = _("Light") },
  { value = 3, label = _("Medium") },
  { value = 4, label = _("Medium-Dark") },
  { value = 5, label = _("Dark") },
}

Constants.ROAST_LABELS = {}
for _, entry in ipairs(Constants.ROAST_LEVELS) do
  Constants.ROAST_LABELS[entry.value] = entry.label
end

Constants.TEMPERATURE_MODES = {
  { value = "hot", label = _("Hot") },
  { value = "cold", label = _("Cold") },
}

Constants.TEMPERATURE_MODE_LABELS = { hot = _("Hot"), cold = _("Cold") }

-- Fixed sensory axes, recipe-level only. Order is render order.
Constants.SENSORY_AXES = {
  { key = "acidity", label = _("Acidity") },
  { key = "sweetness", label = _("Sweetness") },
  { key = "strength", label = _("Strength") },
  { key = "body", label = _("Body") },
  { key = "brightness", label = _("Brightness") },
}

-- Units offered for custom-drink ingredients.
Constants.INGREDIENT_UNITS = { "g", "ml", "tsp", "tbsp", "shot", "oz", "parts", "pump" }

return Constants
