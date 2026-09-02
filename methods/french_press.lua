-- methods/french_press.lua
local _ = require("gettext")

return {
  slug = "french_press",
  name = _("French Press"),
  icon = "french_press",
  sort = 3,
  fields = {
    dose = { required = true },
    water = { required = true, label = _("Total water") },
    water_temp = {},
    brew_time = { label = _("Total brew time") },
    output = { hidden = true },
  },
  params = {
    { key = "steep_time", label = _("Steep before plunge"), type = "duration", min = 0 },
    { key = "crust_break", label = _("Break the crust?"), type = "bool" },
  },
  steps = {
    types = { "pour", "immerse", "wait", "stir", "plunge", "decant" },
    fields = { "start_time", "note" },
    derived = { "duration" },
  },
  output_note = { label = _("Expected result") },
}
