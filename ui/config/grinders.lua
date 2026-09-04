-- ui/config/grinders.lua
-- Configurator › Grinders (TECH_SOLUTION §1.5, §2.19): list + add / edit form
-- (name, unit name, min, max, step), soft-disable. `min <= max` and `step > 0` are
-- enforced by `config_service.grinders`; a violation is shown and the form stays
-- open.

local FlatScreen = require("ui/config/flat_screen")
local _ = require("gettext")

local function row(grinder)
  local range = string.format(
    "%s–%s %s / %s",
    tostring(grinder.min_value),
    tostring(grinder.max_value),
    grinder.unit_name or "",
    tostring(grinder.step_value)
  )
  if tonumber(grinder.is_active) == 0 then
    range = range .. " · " .. _("disabled")
  end
  return grinder.name, range
end

return FlatScreen.define {
  name = "koffeelab_config_grinders",
  title = _("Grinders"),
  singular = _("Grinder"),
  service = require("services/config_service").grinders,
  empty_text = _("No grinders yet. Use the Add button below."),
  row = row,
  fields = {
    { key = "name", label = _("Name"), kind = "text", hint = _("e.g. Timemore C3S") },
    { key = "unit_name", label = _("Unit name"), kind = "text", hint = _("e.g. clicks") },
    {
      key = "min_value",
      label = _("Minimum"),
      kind = "number",
      min = 0,
      max = 1000,
      step = 1,
      default = 0,
    },
    {
      key = "max_value",
      label = _("Maximum"),
      kind = "number",
      min = 0,
      max = 1000,
      step = 1,
      default = 30,
    },
    {
      key = "step_value",
      label = _("Step"),
      kind = "number",
      min = 0.1,
      max = 100,
      step = 0.1,
      precision = "%.1f",
      default = 1,
    },
  },
}
