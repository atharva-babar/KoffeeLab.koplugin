-- services/method_service.lua
-- Read-only access to the static method registry (methods/), kept as a service
-- so the UI layer never requires methods/ directly.

local Methods = require("methods/init")
local Support = require("services/support")

local MethodService = {}

function MethodService.list()
  return Support.ok(Methods.list())
end

function MethodService.get(slug)
  local m = Methods.get(slug)
  if not m then
    return Support.err("unknown brew method")
  end
  return Support.ok(m)
end

MethodService.get_by_slug = MethodService.get

return MethodService
