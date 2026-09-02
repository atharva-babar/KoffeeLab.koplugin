-- methods/pour_over.lua
local _ = require("gettext")

return {
  slug = "pour_over",
  name = _("Pour Over"),
  icon = "pour_over",
  sort = 1,
  fields = {
    dose = { required = true },
    water = { required = true, label = _("Total water") },
    water_temp = {},
    brew_time = { label = _("Total brew time") },
    output = { hidden = true },
  },
  params = {
    {
      key = "dripper",
      label = _("Dripper"),
      type = "enum",
      options = { "V60", "Kalita Wave", "Origami", "Chemex", "Flat bottom", "Other" },
    },
  },
  steps = {
    types = { "bloom", "pour", "wait", "stir", "drawdown" },
    fields = { "start_time", "water", "note" },
    derived = { "duration", "total_water" },
  },
  output_note = { label = _("Expected drawdown / result") },
}
