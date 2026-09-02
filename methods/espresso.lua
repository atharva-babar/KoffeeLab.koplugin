-- methods/espresso.lua
local _ = require("gettext")

return {
  slug = "espresso",
  name = _("Espresso"),
  icon = "espresso",
  sort = 4,
  fields = {
    dose = { required = true },
    water = { hidden = true },
    water_temp = {},
    brew_time = { label = _("Shot time") },
    output = { required = true, label = _("Yield") },
  },
  params = {
    { key = "preinfusion", label = _("Pre-infusion"), type = "duration", min = 0 },
    {
      key = "basket",
      label = _("Basket"),
      type = "enum",
      options = { "Single", "Double", "Triple", "Ridgeless" },
    },
  },
  steps = {
    types = { "preinfuse", "extract" },
    fields = { "start_time", "note" },
    derived = { "duration" },
  },
  output_note = { label = _("Expected shot / taste") },
}
