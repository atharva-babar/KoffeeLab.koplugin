-- ui/config/ingredients.lua
-- Configurator › Ingredients (TECH_SOLUTION §2.19): a name-only list with
-- add / rename / disable. A duplicate name surfaces the unique-constraint error
-- from `config_service.ingredients` and the form stays open.

local FlatScreen = require("ui/config/flat_screen")
local _ = require("gettext")

return FlatScreen.define {
  name = "koffeelab_config_ingredients",
  title = _("Ingredients"),
  singular = _("Ingredient"),
  service = require("services/config_service").ingredients,
  empty_text = _("No ingredients yet. Tap “+ Add Ingredient”."),
  fields = {
    { key = "name", label = _("Name"), kind = "text", hint = _("e.g. Milk") },
  },
}
