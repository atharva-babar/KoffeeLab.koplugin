-- ui/drink/steps.lua
-- Custom-drink process editor (TECH_SOLUTION §2.13). Repeated free-text sections:
-- an instruction plus an optional note, no timing and no structured events. A
-- card list with add / edit / delete / reorder. Steps are held in `draft.steps`
-- (an array); persistence happens when the drink is saved. `on_change` repaints
-- the parent form's summary row.

local FormScreen = require("ui/widgets/form_screen")
local Menu = require("ui/widget/menu")
local TextInput = require("ui/widgets/text_input")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local function edit_step(nav, step, on_done, on_remove, movers)
  local draft = {
    instruction = step and step.instruction or "",
    note = step and step.note or "",
  }

  local fields = {
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
        on_done { instruction = f.values.instruction or "", note = f.values.note or "" }
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

local DrinkSteps = Menu:extend {
  name = "koffeelab_drink_steps",
  covers_fullscreen = true,
  is_borderless = true,
  is_popout = false,
  is_enable_shortcut = false,
  with_bottom_line = true,
  title_bar_left_icon = "chevron.left",
  title = _("Process Steps"),
  draft = nil, -- required
  on_change = nil,
}

function DrinkSteps:init()
  self.steps = self.draft.steps
  self.item_table = self:_items()
  Menu.init(self)
end

function DrinkSteps:_items()
  local items = { { text = "+ " .. _("Add step"), _add = true } }
  for i, step in ipairs(self.steps) do
    items[#items + 1] = {
      text = string.format(
        "#%d  %s",
        i,
        step.instruction ~= "" and step.instruction or _("(no text)")
      ),
      mandatory = (step.note and step.note ~= "") and _("note") or "",
      _index = i,
    }
  end
  return items
end

function DrinkSteps:_refresh()
  if self.on_change then
    self.on_change()
  end
  self:switchItemTable(nil, self:_items(), 1)
end

function DrinkSteps:onMenuChoice(item)
  if item._add then
    edit_step(self.nav, nil, function(values)
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
  edit_step(self.nav, self.steps[idx], function(values)
    self.steps[idx] = values
    self:_refresh()
  end, function()
    table.remove(self.steps, idx)
    self:_refresh()
  end, movers)
  return true
end

function DrinkSteps:_back()
  if self.nav then
    self.nav:pop()
  else
    UIManager:close(self)
  end
  return true
end

DrinkSteps.onClose = DrinkSteps._back
DrinkSteps.onLeftButtonTap = DrinkSteps._back

DrinkSteps._edit_step = edit_step

return DrinkSteps
