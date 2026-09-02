-- ui/paths.lua
-- Plugin root path singleton. Sub-modules get no automatic `path` from
-- PluginLoader, so main.lua sets `Paths.root` from `self.path` before any screen
-- is built, and helpers here resolve bundled resources against it.

local Paths = { root = nil }

--- Absolute path to a plugin-bundled SVG icon (resources/icons/<name>.svg).
function Paths.icon(name)
  return (Paths.root or ".") .. "/resources/icons/" .. name .. ".svg"
end

return Paths
