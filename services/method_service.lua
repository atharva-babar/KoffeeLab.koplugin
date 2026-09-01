-- services/method_service.lua
-- Brew-method reads plus user-method create/edit. The destructive-edit guard for
-- system methods (§2.19) lives in the repo; this layer validates the payload shape
-- and forbids editing a system method's identity (slug / is_system).

local MethodRepo = require("db/repo/method")
local Support = require("services/support")

local MethodService = {}

local DATA_TYPES = { int = true, real = true, text = true, bool = true, duration = true }

local function validate_method(fields, opts)
  local bad = Support.check {
    { Support.is_nonempty_string(fields.name), "method name is required" },
  }
  if bad then
    return bad
  end
  for i, p in ipairs(opts.parameters or {}) do
    if not Support.is_nonempty_string(p.key) then
      return string.format("parameter %d: key is required", i)
    end
    if not Support.is_nonempty_string(p.label) then
      return string.format("parameter %d: label is required", i)
    end
    if not DATA_TYPES[p.data_type] then
      return string.format("parameter %d: unknown data type '%s'", i, tostring(p.data_type))
    end
  end
  for i, st in ipairs(opts.step_types or {}) do
    local step_type = type(st) == "table" and st.step_type or st
    if not Support.is_nonempty_string(step_type) then
      return string.format("step type %d is empty", i)
    end
  end
end

function MethodService.list(opts)
  return Support.ok(MethodRepo.list(opts))
end

function MethodService.get(id)
  local m = MethodRepo.get(id)
  if not m then
    return Support.err("method not found")
  end
  return Support.ok(m)
end

function MethodService.get_by_slug(slug)
  local m = MethodRepo.get_by_slug(slug)
  if not m then
    return Support.err("method not found")
  end
  return Support.ok(m)
end

function MethodService.create(fields)
  fields = fields or {}
  if not Support.is_nonempty_string(fields.slug) then
    return Support.err("method slug is required")
  end
  local bad = validate_method(fields, fields)
  if bad then
    return Support.err(bad)
  end
  return Support.from_repo(MethodRepo.create_user_method(fields))
end

function MethodService.update(id, fields, opts)
  fields = fields or {}
  opts = opts or {}
  local current = MethodRepo.get(id)
  if not current then
    return Support.err("method not found")
  end
  if fields.slug ~= nil and fields.slug ~= current.slug then
    return Support.err("a method's slug cannot be changed")
  end
  fields.slug = nil
  local candidate = { name = fields.name or current.name }
  local bad = validate_method(candidate, opts)
  if bad then
    return Support.err(bad)
  end
  return Support.from_repo(MethodRepo.update_user_method(id, fields, opts))
end

function MethodService.set_active(id, active)
  return Support.from_repo(MethodRepo.set_active(id, active))
end

return MethodService
