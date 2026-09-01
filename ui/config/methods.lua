-- ui/config/methods.lua
-- Configurator › Brew Methods (TECH_SOLUTION §2.19): the five system methods plus
-- any user methods. Tapping one opens a read-only detail view (activate /
-- deactivate, and Edit for user methods); "+ Add Method" opens the builder. All
-- data through `method_service`.

local ListScreen = require("ui/config/list_screen")
local MethodDetail = require("ui/config/method_detail")
local MethodForm = require("ui/config/method_form")
local MethodService = require("services/method_service")
local _ = require("gettext")

local Methods = ListScreen:extend {
  name = "koffeelab_config_methods",
  title = _("Brew Methods"),
  add_text = "+ " .. _("Add Method"),
  empty_text = nil,
}

function Methods:load()
  local ok, rows = MethodService.list { include_inactive = true }
  return ok and rows or {}
end

function Methods:row(method)
  local parts = { tonumber(method.is_system) == 1 and _("system") or _("custom") }
  if tonumber(method.is_active) == 0 then
    parts[#parts + 1] = _("disabled")
  end
  return method.name, table.concat(parts, " · ")
end

function Methods:on_add()
  self.nav:push(MethodForm:new {
    on_saved = function()
      self:reload()
    end,
  })
end

function Methods:on_edit(method)
  self.nav:push(MethodDetail:new {
    method = method,
    on_changed = function()
      self:reload()
    end,
  })
end

return Methods
