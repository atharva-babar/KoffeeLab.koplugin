-- methods/aeropress.lua
local _ = require("gettext")

return {
  slug = "aeropress",
  name = _("AeroPress"),
  icon = "aeropress",
  sort = 2,
  fields = {
    dose = { required = true },
    water = { required = true, label = _("Total water") },
    water_temp = {},
    brew_time = { label = _("Total brew time") },
    output = { label = _("Cup yield") },
  },
  params = {
    {
      key = "orientation",
      label = _("Orientation"),
      type = "enum",
      options = { "Standard", "Inverted" },
      default = "Standard",
    },
    {
      key = "filter_type",
      label = _("Filter type"),
      type = "enum",
      options = { "Paper", "Metal", "Flow control" },
      default = "Paper",
    },
    { key = "bypass_water", label = _("Bypass water"), type = "number", unit = "g", min = 0 },
  },
  steps = {
    types = { "setup", "bloom", "stir", "pour", "wait", "press", "bypass" },
    fields = { "start_time", "water", "note" },
    derived = { "duration", "total_water" },
  },
  output_note = { label = _("Expected result") },
}
