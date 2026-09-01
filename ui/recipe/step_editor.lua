-- ui/recipe/step_editor.lua
-- Brew-step editor (TECH_SOLUTION §2.7, §2.9). One card list for every method:
-- add / edit / delete / reorder steps. The fields offered for a step depend on
-- its `step_type` (and the method's allowed types); times use DurationInput so
-- Cold Brew's multi-hour steps format cleanly and raw seconds never show. Steps
-- are held in `draft.steps` (an array); persistence happens when the recipe is
-- saved. `on_change` repaints the parent form's summary row.

local Constants = require("util/constants")
local DurationInput = require("ui/widgets/duration_input")
local Format = require("util/format")
local FormScreen = require("ui/widgets/form_screen")
local ListPicker = require("ui/widgets/list_picker")
local Menu = require("ui/widget/menu")
local NumberInput = require("ui/widgets/number_input")
local TextInput = require("ui/widgets/text_input")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local function step_summary(step)
  local bits = {}
  if step.target_total_water_g then
    bits[#bits + 1] = _("total ") .. Format.grams(step.target_total_water_g)
  elseif step.target_water_g then
    bits[#bits + 1] = Format.grams(step.target_water_g)
  end
  if step.duration_sec then
    bits[#bits + 1] = Format.duration(step.duration_sec)
  end
  return table.concat(bits, " · ")
end

-- ── the per-step edit form ────────────────────────────────────────────────────

local function edit_step(nav, allowed_types, step, on_done, on_remove, movers)
  local draft = {}
  for k, v in pairs(step or {}) do
    draft[k] = v
  end
  if draft.step_type == nil then
    draft.step_type = allowed_types[1]
  end

  local fields = {
    {
      key = "step_type",
      label = _("Step type"),
      display = function(v)
        return Constants.STEP_TYPE_LABELS[v.step_type] or v.step_type
      end,
      edit = function(f)
        local items = {}
        for _idx, st in ipairs(allowed_types) do -- luacheck: ignore _idx
          items[#items + 1] = { text = Constants.STEP_TYPE_LABELS[st] or st, value = st }
        end
        ListPicker.show {
          title = _("Step type"),
          items = items,
          current = f.values.step_type,
          on_select = function(v)
            f:set("step_type", v)
          end,
        }
      end,
    },
    {
      key = "start_time_sec",
      label = _("Start time"),
      display = function(v)
        return v.start_time_sec and Format.duration(v.start_time_sec) or nil
      end,
      edit = function(f)
        DurationInput.show {
          title = _("Start time"),
          value_sec = f.values.start_time_sec,
          on_ok = function(sec)
            f:set("start_time_sec", sec)
          end,
        }
      end,
    },
    {
      key = "duration_sec",
      label = _("Duration"),
      display = function(v)
        return v.duration_sec and Format.duration(v.duration_sec) or nil
      end,
      edit = function(f)
        DurationInput.show {
          title = _("Duration"),
          value_sec = f.values.duration_sec,
          on_ok = function(sec)
            f:set("duration_sec", sec)
          end,
        }
      end,
    },
    {
      key = "target_water_g",
      label = _("Water this step"),
      display = function(v)
        return v.target_water_g and Format.grams(v.target_water_g) or nil
      end,
      edit = function(f)
        NumberInput.show {
          title = _("Water this step (g)"),
          value = f.values.target_water_g or 0,
          min = 0,
          max = 5000,
          step = 1,
          unit = "g",
          on_ok = function(n)
            f:set("target_water_g", n > 0 and n or nil)
          end,
        }
      end,
    },
    {
      key = "target_total_water_g",
      label = _("Total water so far"),
      display = function(v)
        return v.target_total_water_g and Format.grams(v.target_total_water_g) or nil
      end,
      edit = function(f)
        NumberInput.show {
          title = _("Total water so far (g)"),
          value = f.values.target_total_water_g or 0,
          min = 0,
          max = 5000,
          step = 1,
          unit = "g",
          on_ok = function(n)
            f:set("target_total_water_g", n > 0 and n or nil)
          end,
        }
      end,
    },
    {
      key = "temperature_c",
      label = _("Temperature"),
      display = function(v)
        return v.temperature_c and Format.temp_c(v.temperature_c) or nil
      end,
      edit = function(f)
        NumberInput.show {
          title = _("Temperature (°C)"),
          value = f.values.temperature_c or 94,
          min = 0,
          max = 100,
          step = 1,
          unit = "°C",
          on_ok = function(n)
            f:set("temperature_c", n > 0 and n or nil)
          end,
        }
      end,
    },
    {
      key = "instruction",
      label = _("Instruction"),
      display = function(v)
        return v.instruction ~= "" and v.instruction or nil
      end,
      edit = function(f)
        TextInput.show {
          title = _("Instruction"),
          value = f.values.instruction,
          on_ok = function(t)
            f:set("instruction", t)
          end,
        }
      end,
    },
    {
      key = "note",
      label = _("Note"),
      display = function(v)
        return v.note ~= "" and v.note or nil
      end,
      edit = function(f)
        TextInput.show {
          title = _("Note"),
          value = f.values.note,
          on_ok = function(t)
            f:set("note", t)
          end,
        }
      end,
    },
  }

  local actions = {
    {
      text = _("Done"),
      callback = function(f)
        on_done(f.values)
        nav:pop()
      end,
    },
  }
  if movers and movers.up then
    actions[#actions + 1] = {
      text = _("Move up"),
      callback = function()
        movers.up()
        nav:pop()
      end,
    }
  end
  if movers and movers.down then
    actions[#actions + 1] = {
      text = _("Move down"),
      callback = function()
        movers.down()
        nav:pop()
      end,
    }
  end
  if on_remove then
    actions[#actions + 1] = {
      text = _("Delete step"),
      callback = function()
        on_remove()
        nav:pop()
      end,
    }
  end

  local form = FormScreen:new {
    title = step and _("Edit Step") or _("New Step"),
    values = draft,
    fields = fields,
    actions = actions,
  }
  nav:push(form)
end

-- ── the step list ─────────────────────────────────────────────────────────────

local StepEditor = Menu:extend {
  name = "koffeelab_recipe_steps",
  covers_fullscreen = true,
  is_borderless = true,
  is_popout = false,
  is_enable_shortcut = false,
  with_bottom_line = true,
  title_bar_left_icon = "chevron.left",
  title = _("Brew Steps"),
  draft = nil, -- required
  on_change = nil,
}

function StepEditor:init()
  self.steps = self.draft.steps
  self.allowed_types = {}
  for _idx, st in ipairs(self.draft.method.step_types or {}) do -- luacheck: ignore _idx
    self.allowed_types[#self.allowed_types + 1] = st.step_type
  end
  if #self.allowed_types == 0 then
    self.allowed_types = Constants.STEP_TYPES
  end
  self.item_table = self:_items()
  Menu.init(self)
end

function StepEditor:_items()
  local items = { { text = "+ " .. _("Add step"), _add = true } }
  for i, step in ipairs(self.steps) do
    local head = string.format("#%d", i)
    if step.start_time_sec then
      head = head .. "  " .. Format.duration(step.start_time_sec)
    end
    head = head .. "  " .. (Constants.STEP_TYPE_LABELS[step.step_type] or step.step_type or "?")
    items[#items + 1] = { text = head, mandatory = step_summary(step), _index = i }
  end
  return items
end

function StepEditor:_refresh()
  if self.on_change then
    self.on_change()
  end
  self:switchItemTable(nil, self:_items(), 1)
end

function StepEditor:onMenuChoice(item)
  if item._add then
    edit_step(self.nav, self.allowed_types, nil, function(values)
      values.instruction = values.instruction or ""
      values.note = values.note or ""
      self.steps[#self.steps + 1] = values
      self:_refresh()
    end)
    return true
  end

  local idx = item._index
  if not idx then
    return true
  end
  local movers = {}
  if idx > 1 then
    movers.up = function()
      self.steps[idx], self.steps[idx - 1] = self.steps[idx - 1], self.steps[idx]
      self:_refresh()
    end
  end
  if idx < #self.steps then
    movers.down = function()
      self.steps[idx], self.steps[idx + 1] = self.steps[idx + 1], self.steps[idx]
      self:_refresh()
    end
  end
  edit_step(self.nav, self.allowed_types, self.steps[idx], function(values)
    values.instruction = values.instruction or ""
    values.note = values.note or ""
    self.steps[idx] = values
    self:_refresh()
  end, function()
    table.remove(self.steps, idx)
    self:_refresh()
  end, movers)
  return true
end

function StepEditor:_back()
  if self.nav then
    self.nav:pop()
  else
    UIManager:close(self)
  end
  return true
end

StepEditor.onClose = StepEditor._back
StepEditor.onLeftButtonTap = StepEditor._back

StepEditor._edit_step = edit_step

return StepEditor
