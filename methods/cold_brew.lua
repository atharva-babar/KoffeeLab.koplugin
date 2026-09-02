-- methods/cold_brew.lua
local _ = require("gettext")

return {
  slug = "cold_brew",
  name = _("Cold Brew"),
  icon = "cold_brew",
  sort = 5,
  fields = {
    dose = { required = true },
    water = { required = true, label = _("Total water") },
    water_temp = { hidden = true },
    brew_time = { label = _("Steep time") },
    output = { hidden = true },
  },
  params = {
    {
      key = "dilution_ratio",
      label = _("Dilution ratio"),
      type = "text",
      hint = _("e.g. 1:1 with water"),
    },
    {
      key = "vessel",
      label = _("Vessel"),
      type = "enum",
      options = { "Jar", "Toddy", "Bottle", "French press", "Other" },
    },
  },
  steps = {
    types = { "pour", "immerse", "wait", "decant" },
    fields = { "start_time", "water", "note" },
    derived = { "duration", "total_water" },
  },
  output_note = { label = _("Expected concentrate / result") },
}
