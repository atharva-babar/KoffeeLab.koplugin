-- ui/config/flavor_tags.lua
-- Configurator › Flavor Tags (TECH_SOLUTION §2.19): a name-only list with
-- add / rename / disable. A duplicate name surfaces the unique-constraint error
-- from `config_service.flavor_tags`.

local FlatScreen = require("ui/config/flat_screen")
local _ = require("gettext")

return FlatScreen.define {
  name = "koffeelab_config_flavor_tags",
  title = _("Flavor Tags"),
  singular = _("Flavor Tag"),
  service = require("services/config_service").flavor_tags,
  empty_text = _("No flavor tags yet. Use the Add button below."),
  fields = {
    { key = "name", label = _("Name"), kind = "text", hint = _("e.g. Chocolate") },
  },
}
