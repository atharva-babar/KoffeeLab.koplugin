-- util/constants.lua
-- Shared, read-only domain constants surfaced in the UI (TECH_SOLUTION §1.12
-- step types, §0.12 roast labels, §0.13 temperature modes, §0.10 sensory axes,
-- §0.1 method slugs). Pure data — no DB, no widgets. Services own the DDL-level
-- CHECK values; this module is the single place the UI reads the human labels.

local _ = require("gettext")

local Constants = {}

--- Generic brew-step types (§1.12). Order matches the doc's built-in list.
Constants.STEP_TYPES = {
  "setup",
  "pour",
  "bloom",
  "wait",
  "stir",
  "agitate",
  "immerse",
  "preinfuse",
  "extract",
  "press",
  "plunge",
  "bypass",
  "decant",
  "finish",
  "note",
}

--- step_type -> display label.
Constants.STEP_TYPE_LABELS = {
  setup = _("Setup"),
  pour = _("Pour"),
  bloom = _("Bloom"),
  wait = _("Wait"),
  stir = _("Stir"),
  agitate = _("Agitate"),
  immerse = _("Immerse"),
  preinfuse = _("Pre-infuse"),
  extract = _("Extract"),
  press = _("Press"),
  plunge = _("Plunge"),
  bypass = _("Bypass"),
  decant = _("Decant"),
  finish = _("Finish"),
  note = _("Note"),
}

--- Roast levels 1..5 with the default labels (§0.12).
Constants.ROAST_LEVELS = {
  { value = 1, label = _("Very Light") },
  { value = 2, label = _("Light") },
  { value = 3, label = _("Medium") },
  { value = 4, label = _("Medium-Dark") },
  { value = 5, label = _("Dark") },
}

--- roast level (1..5) -> label, falling back to the number when out of range.
Constants.ROAST_LABELS = {}
for i = 1, #Constants.ROAST_LEVELS do
  local entry = Constants.ROAST_LEVELS[i]
  Constants.ROAST_LABELS[entry.value] = entry.label
end

--- Custom-drink temperature modes (§0.13). Stored value == DDL CHECK value.
Constants.TEMPERATURE_MODES = {
  { value = "hot", label = _("Hot") },
  { value = "cold", label = _("Cold") },
}

Constants.TEMPERATURE_MODE_LABELS = {
  hot = _("Hot"),
  cold = _("Cold"),
}

--- Fixed sensory axes, recipe-level only (§0.10). Order is the render order.
Constants.SENSORY_AXES = {
  { key = "acidity", label = _("Acidity") },
  { key = "sweetness", label = _("Sweetness") },
  { key = "strength", label = _("Strength") },
  { key = "body", label = _("Body") },
  { key = "brightness", label = _("Brightness") },
}

--- Built-in system method slugs (§0.1). The DB is the source of truth for ids;
--- the UI uses these only for stable ordering / icon lookup.
Constants.SYSTEM_METHOD_SLUGS = {
  "pour_over",
  "aeropress",
  "french_press",
  "espresso",
  "cold_brew",
}

--- Parameter data types (matches brew_method_parameters.data_type CHECK).
Constants.PARAM_DATA_TYPES = { "int", "real", "text", "bool", "duration" }

return Constants
