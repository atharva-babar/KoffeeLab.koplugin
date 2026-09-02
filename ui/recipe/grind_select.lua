-- ui/recipe/grind_select.lua
-- Grind screen for the recipe flow (TECH_SOLUTION §2.6). Shows the bean's roast
-- level purely as context — the app never computes a "correct" grind from it —
-- then a grinder picker and a grind-setting number bounded by that grinder's
-- configured min / max / step and rendered in its unit. Writes straight into the
-- shared draft; `on_change` lets the parent form repaint its summary row.

local Format = require("util/format")
local FormScreen = require("ui/widgets/form_screen")
local InfoMessage = require("ui/widget/infomessage")
local ListPicker = require("ui/widgets/list_picker")
local NumberInput = require("ui/widgets/number_input")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local GrindSelect = {}

local function clamp(value, lo, hi)
  if value == nil then
    return nil
  end
  if lo and value < lo then
    return lo
  end
  if hi and value > hi then
    return hi
  end
  return value
end

--- Build the screen.
---   GrindSelect.build{ draft = draft, on_change = function() … end }  -> FormScreen
function GrindSelect.build(opts)
  local draft = opts.draft
  local ConfigService = require("services/config_service")

  local function notify()
    if opts.on_change then
      opts.on_change()
    end
  end

  local fields = {
    {
      key = "_roast",
      label = _("Roast level"),
      display = function()
        local level = draft.bean and tonumber(draft.bean.roast_level)
        return level and Format.roast_label(level) or _("(no bean selected)")
      end,
      edit = function()
        UIManager:show(InfoMessage:new {
          text = _("Roast level is shown for context only; it does not set the grind."),
        })
      end,
    },
    {
      key = "grinder_id",
      label = _("Grinder"),
      display = function()
        return draft.grinder and draft.grinder.name or nil
      end,
      edit = function(form)
        local ok, grinders = ConfigService.grinders.list {}
        grinders = ok and grinders or {}
        if #grinders == 0 then
          UIManager:show(InfoMessage:new {
            text = _("No grinders configured yet. Add one in Configurator › Grinders."),
          })
          return
        end
        local items = {}
        for _idx, g in ipairs(grinders) do -- luacheck: ignore _idx
          items[#items + 1] = {
            text = string.format(
              "%s  (%s–%s %s)",
              g.name,
              tostring(g.min_value),
              tostring(g.max_value),
              g.unit_name or ""
            ),
            value = g.id,
            _grinder = g,
          }
        end
        ListPicker.show {
          title = _("Select Grinder"),
          items = items,
          current = draft.recipe.grinder_id,
          on_select = function(_, item)
            draft.grinder = item._grinder
            draft.recipe.grinder_id = item._grinder.id
            draft.recipe.grind_value =
              clamp(draft.recipe.grind_value, item._grinder.min_value, item._grinder.max_value)
            form:refreshItems()
            notify()
          end,
        }
      end,
    },
    {
      key = "grind_value",
      label = _("Grind setting"),
      display = function()
        if draft.recipe.grind_value == nil then
          return nil
        end
        return Format.grind(draft.recipe.grind_value, draft.grinder and draft.grinder.unit_name)
      end,
      edit = function(form)
        local g = draft.grinder
        if not g then
          UIManager:show(InfoMessage:new { text = _("Choose a grinder first.") })
          return
        end
        NumberInput.show {
          title = _("Grind setting"),
          value = draft.recipe.grind_value or g.min_value or 0,
          min = g.min_value,
          max = g.max_value,
          step = g.step_value or 1,
          unit = g.unit_name,
          precision = (g.step_value and g.step_value % 1 ~= 0) and "%.1f" or nil,
          on_ok = function(n)
            draft.recipe.grind_value = n
            form:refreshItems()
            notify()
          end,
        }
      end,
    },
  }

  return FormScreen:new {
    title = _("Grind"),
    values = draft.recipe,
    fields = fields,
    actions = {
      {
        text = _("Done"),
        callback = function(form)
          if form.nav then
            form.nav:pop()
          else
            UIManager:close(form)
          end
        end,
      },
    },
  }
end

return GrindSelect
