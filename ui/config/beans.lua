-- ui/config/beans.lua
-- Configurator › Beans (TECH_SOLUTION §2.19): list every bean (active + disabled),
-- add / edit (roaster, name, roast level via a ListPicker over the §0.12 labels),
-- soft-disable. All data through `config_service.beans`.

local Constants = require("util/constants")
local FlatScreen = require("ui/config/flat_screen")
local _ = require("gettext")

local function row(bean)
  local parts = {}
  if bean.roaster_name and bean.roaster_name ~= "" then
    parts[#parts + 1] = bean.roaster_name
  end
  parts[#parts + 1] = Constants.ROAST_LABELS[tonumber(bean.roast_level)] or _("Medium")
  if tonumber(bean.is_active) == 0 then
    parts[#parts + 1] = _("disabled")
  end
  return bean.name, table.concat(parts, " · ")
end

return FlatScreen.define {
  name = "koffeelab_config_beans",
  title = _("Beans"),
  singular = _("Bean"),
  service = require("services/config_service").beans,
  empty_text = _("No beans yet. Tap “+ Add Bean”."),
  row = row,
  fields = {
    { key = "roaster_name", label = _("Roaster"), kind = "text", hint = _("e.g. Blue Tokai") },
    { key = "name", label = _("Bean name"), kind = "text", hint = _("e.g. Ethiopia Guji") },
    {
      key = "roast_level",
      label = _("Roast level"),
      kind = "pick",
      options = Constants.ROAST_LEVELS,
      default = 3,
    },
  },
}
