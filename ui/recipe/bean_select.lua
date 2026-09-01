-- ui/recipe/bean_select.lua
-- Bean picker for the recipe flow (TECH_SOLUTION §2.5): a modal single-select
-- over the active beans, with a "+ Add New Bean" affordance that drops into the
-- Configurator bean form and returns to the flow. Data through `config_service`;
-- the UI never touches a repository.

local Constants = require("util/constants")
local EntityForm = require("ui/config/entity_form")
local ListPicker = require("ui/widgets/list_picker")
local Nav = require("ui/nav")
local _ = require("gettext")

local BeanSelect = {}

-- Same field set the Configurator uses for beans (§2.19).
BeanSelect.FIELDS = {
  { key = "roaster_name", label = _("Roaster"), kind = "text", hint = _("e.g. Blue Tokai") },
  { key = "name", label = _("Bean name"), kind = "text", hint = _("e.g. Ethiopia Guji") },
  {
    key = "roast_level",
    label = _("Roast level"),
    kind = "pick",
    options = Constants.ROAST_LEVELS,
    default = 3,
  },
}

local function bean_label(bean)
  local roast = Constants.ROAST_LABELS[tonumber(bean.roast_level)]
  if bean.roaster_name and bean.roaster_name ~= "" then
    return bean.name .. "  —  " .. bean.roaster_name .. (roast and " · " .. roast or "")
  end
  return bean.name .. (roast and "  —  " .. roast or "")
end

--- Show the picker.
---   BeanSelect.show{ current = bean_id, on_select = function(bean_row) … end }
function BeanSelect.show(opts)
  local ConfigService = require("services/config_service")
  local ok, beans = ConfigService.beans.list {}
  beans = ok and beans or {}

  local items = {}
  for _idx, bean in ipairs(beans) do -- luacheck: ignore _idx
    items[#items + 1] = { text = bean_label(bean), value = bean.id, _bean = bean }
  end

  ListPicker.show {
    title = _("Select Bean"),
    items = items,
    current = opts.current,
    on_select = function(_, item)
      opts.on_select(item._bean)
    end,
    extra = {
      text = _("+ Add New Bean"),
      callback = function()
        Nav:push(EntityForm.build {
          nav = Nav,
          title = _("New Bean"),
          service = ConfigService.beans,
          fields = BeanSelect.FIELDS,
        })
      end,
    },
  }
end

return BeanSelect
