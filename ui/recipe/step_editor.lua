-- ui/recipe/step_editor.lua
-- Brew-step editor. The fields offered per step come from the method's
-- `steps.fields`; step duration and cumulative water are derived
-- (methods/derive) and shown read-only, never entered. Steps live in
-- `draft.steps` until the recipe is saved.

local Derive = require("methods/derive")
local DurationInput = require("ui/widgets/duration_input")
local Format = require("util/format")
local FormScreen = require("ui/widgets/form_screen")
local ListPicker = require("ui/widgets/list_picker")
local Methods = require("methods/init")
local NumberInput = require("ui/widgets/number_input")
local ScreenList = require("ui/screen_list")
local TextInput = require("ui/widgets/text_input")
local _ = require("gettext")

local function field_row(key, scale)
  if key == "start_time" then
    return {
      key = "start_time",
      label = _("Start time"),
      display = function(v)
        return v.start_time and Format.duration(v.start_time, scale) or nil
      end,
      edit = function(f)
        DurationInput.show {
          title = _("Start time"),
          value_sec = f.values.start_time,
          scale = scale,
          on_ok = function(sec)
            f:set("start_time", sec)
          end,
        }
      end,
    }
  elseif key == "water" then
    return {
      key = "water",
      label = _("Water this step"),
      display = function(v)
        return v.water and Format.grams(v.water) or nil
      end,
      edit = function(f)
        NumberInput.show {
          title = _("Water this step (g)"),
          value = f.values.water or 0,
          min = 0,
          max = 5000,
          step = 1,
          hold_step = 25,
          unit = "g",
          on_ok = function(n)
            f:set("water", n > 0 and n or nil)
          end,
        }
      end,
    }
  end
  return {
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
  }
end

local function edit_step(nav, method, step, on_done, on_remove, movers)
  local allowed = method.steps.types
  local draft = {}
  for k, v in pairs(step or {}) do
    draft[k] = v
  end
  draft.step_type = draft.step_type or allowed[1]

  local fields = {
    {
      key = "step_type",
      label = _("Step type"),
      display = function(v)
        return Methods.step_label(v.step_type)
      end,
      edit = function(f)
        local items = {}
        for _, st in ipairs(allowed) do
          items[#items + 1] = { text = Methods.step_label(st), value = st }
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
  }
  for _, key in ipairs(method.steps.fields) do
    fields[#fields + 1] = field_row(key, method.time_scale)
  end

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

  nav:push(FormScreen:new {
    title = step and _("Edit Step") or _("New Step"),
    values = draft,
    fields = fields,
    actions = actions,
  })
end

local StepEditor = ScreenList:extend {
  name = "koffeelab_recipe_steps",
  title = _("Brew Steps"),
  draft = nil,
  on_change = nil,
}

function StepEditor:init()
  self.steps = self.draft.steps
  self.method = self.draft.method
  ScreenList.init(self)
end

function StepEditor:buildItems()
  local total_water = Derive.total_water(self.steps)
  local total_brew = self.draft.recipe.brew_time_sec
  local scale = self.method and self.method.time_scale
  local items = {
    {
      text = "+ " .. _("Add step"),
      _add = true,
      callback = function()
        self:onMenuChoice { _add = true }
      end,
    },
  }
  for i, step in ipairs(self.steps) do
    local head = string.format("#%d", i)
    if step.start_time then
      head = head .. "  " .. Format.duration(step.start_time, scale)
    end
    head = head .. "  " .. Methods.step_label(step.step_type)
    local bits = {}
    local dur = Derive.duration(self.steps, i, total_brew)
    if dur and dur > 0 then
      bits[#bits + 1] = Format.duration(dur, scale)
    end
    if total_water[i] then
      bits[#bits + 1] = _("total ") .. Format.grams(total_water[i])
    elseif step.water then
      bits[#bits + 1] = Format.grams(step.water)
    end
    items[#items + 1] = {
      text = head,
      mandatory = table.concat(bits, "  \u{00B7}  "),
      _index = i,
      callback = function()
        self:onMenuChoice { _index = i }
      end,
    }
  end
  return items
end

function StepEditor:_refresh()
  if self.on_change then
    self.on_change()
  end
  self:refresh()
end

function StepEditor:onMenuChoice(item)
  if item._add then
    edit_step(self.nav, self.method, nil, function(values)
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
  edit_step(self.nav, self.method, self.steps[idx], function(values)
    values.note = values.note or ""
    self.steps[idx] = values
    self:_refresh()
  end, function()
    table.remove(self.steps, idx)
    self:_refresh()
  end, movers)
  return true
end

StepEditor._edit_step = edit_step

return StepEditor
