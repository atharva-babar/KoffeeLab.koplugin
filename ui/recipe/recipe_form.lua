-- ui/recipe/recipe_form.lua
-- The method-driven recipe wizard (design-language §4.6). Pages: Basics / Brew /
-- Steps / Output. Field cards come from the chosen method's `fields` (shared
-- columns it surfaces) and `params` — there is no `if method == …` branching.
-- Bean / grind / steps / sensory push their own screen. Save goes through
-- ui/recipe/add_flow -> recipe_service.

local BeanSelect = require("ui/recipe/bean_select")
local Constants = require("util/constants")
local DurationInput = require("ui/widgets/duration_input")
local Format = require("util/format")
local GrindSelect = require("ui/recipe/grind_select")
local InfoMessage = require("ui/widget/infomessage")
local ListPicker = require("ui/widgets/list_picker")
local NumberInput = require("ui/widgets/number_input")
local Sensory = require("ui/recipe/sensory")
local StepEditor = require("ui/recipe/step_editor")
local TextInput = require("ui/widgets/text_input")
local UIManager = require("ui/uimanager")
local Wizard = require("ui/widgets/wizard")
local _ = require("gettext")

local RecipeForm = Wizard:extend {
  name = "koffeelab_recipe_form",
  draft = nil,
  on_saved = nil,
}

local GRAMS_FIELDS = {
  dose = { col = "dose_g", label = _("Dose") },
  water = { col = "water_g", label = _("Total water") },
  output = { col = "output_weight_g", label = _("Output weight") },
}

local function grams_row(draft, name, method_spec)
  local def = GRAMS_FIELDS[name]
  local col, label = def.col, method_spec.label or def.label
  return {
    key = col,
    label = label,
    display = function()
      return draft.recipe[col] and Format.grams(draft.recipe[col]) or nil
    end,
    edit = function(form)
      NumberInput.show {
        title = label,
        value = draft.recipe[col] or 0,
        min = 0,
        max = 5000,
        step = 1,
        hold_step = 25,
        precision = "%.1f",
        unit = "g",
        on_ok = function(n)
          draft.recipe[col] = n > 0 and n or nil
          form:refreshItems()
        end,
      }
    end,
  }
end

local function temp_row(draft, method_spec)
  return {
    key = "water_temp_c",
    label = method_spec.label or _("Water temperature"),
    display = function()
      return draft.recipe.water_temp_c and Format.temp_c(draft.recipe.water_temp_c) or nil
    end,
    edit = function(form)
      NumberInput.show {
        title = _("Water temperature (\u{00B0}C)"),
        value = draft.recipe.water_temp_c or 94,
        min = 0,
        max = 100,
        step = 1,
        unit = "\u{00B0}C",
        on_ok = function(n)
          draft.recipe.water_temp_c = n > 0 and n or nil
          form:refreshItems()
        end,
      }
    end,
  }
end

local function brew_time_row(draft, method_spec)
  local label = method_spec.label or _("Brew time")
  return {
    key = "brew_time_sec",
    label = label,
    display = function()
      return draft.recipe.brew_time_sec and Format.duration(draft.recipe.brew_time_sec) or nil
    end,
    edit = function(form)
      DurationInput.show {
        title = label,
        value_sec = draft.recipe.brew_time_sec,
        on_ok = function(sec)
          draft.recipe.brew_time_sec = sec
          form:refreshItems()
        end,
      }
    end,
  }
end

local function param_row(param, draft)
  return {
    key = "param_" .. param.key,
    label = param.unit and param.unit ~= "" and (param.label .. " (" .. param.unit .. ")")
      or param.label,
    display = function()
      local v = draft.spec[param.key]
      if v == nil or v == "" then
        return nil
      end
      if param.type == "duration" then
        return Format.duration(tonumber(v)) or tostring(v)
      end
      if param.type == "bool" then
        return (v == true or tostring(v) == "1") and _("Yes") or _("No")
      end
      return tostring(v)
    end,
    edit = function(form)
      if param.type == "enum" then
        local items = {}
        for _, opt in ipairs(param.options) do
          items[#items + 1] = { text = opt, value = opt }
        end
        ListPicker.show {
          title = param.label,
          items = items,
          current = draft.spec[param.key],
          on_select = function(v)
            draft.spec[param.key] = v
            form:refreshItems()
          end,
        }
      elseif param.type == "bool" then
        ListPicker.show {
          title = param.label,
          items = { { text = _("No"), value = 0 }, { text = _("Yes"), value = 1 } },
          current = tonumber(draft.spec[param.key]) or 0,
          on_select = function(v)
            draft.spec[param.key] = v
            form:refreshItems()
          end,
        }
      elseif param.type == "duration" then
        DurationInput.show {
          title = param.label,
          value_sec = tonumber(draft.spec[param.key]),
          on_ok = function(sec)
            draft.spec[param.key] = sec
            form:refreshItems()
          end,
        }
      elseif param.type == "number" then
        NumberInput.show {
          title = param.label,
          value = tonumber(draft.spec[param.key]) or param.min or 0,
          min = param.min or 0,
          max = param.max or 100000,
          step = 1,
          hold_step = 10,
          unit = param.unit,
          on_ok = function(n)
            draft.spec[param.key] = n
            form:refreshItems()
          end,
        }
      else
        TextInput.show {
          title = param.label,
          value = draft.spec[param.key],
          hint = param.hint,
          on_ok = function(t)
            draft.spec[param.key] = t ~= "" and t or nil
            form:refreshItems()
          end,
        }
      end
    end,
  }
end

function RecipeForm:init()
  local draft = assert(self.draft, "RecipeForm needs a draft")
  local method = draft.method
  self.editing = draft.editing_id ~= nil
  self.wizard_title = self.editing and _("Edit Recipe") or _("New Recipe")
  self.values = draft.recipe

  local basics = {
    {
      key = "title",
      label = _("Title"),
      display = function()
        return draft.recipe.title
      end,
      edit = function(form)
        TextInput.show {
          title = _("Recipe title"),
          value = draft.recipe.title,
          hint = _("e.g. Ethiopia Guji V60"),
          on_ok = function(t)
            draft.recipe.title = t ~= "" and t or nil
            form:refreshItems()
          end,
        }
      end,
    },
    {
      key = "_method",
      label = _("Method"),
      display = function()
        return method.name
      end,
      edit = function()
        UIManager:show(InfoMessage:new {
          text = _("The brew method is chosen at the start and cannot be changed here."),
        })
      end,
    },
  }

  local brew = {
    {
      key = "bean_id",
      label = _("Bean"),
      display = function()
        return draft.bean and draft.bean.name or nil
      end,
      edit = function(form)
        BeanSelect.show {
          current = draft.recipe.bean_id,
          on_select = function(bean)
            draft.bean = bean
            draft.recipe.bean_id = bean and bean.id or nil
            form:refreshItems()
          end,
        }
      end,
    },
    {
      key = "_grind",
      label = _("Grind"),
      display = function()
        if not draft.grinder then
          return nil
        end
        local g = Format.grind(draft.recipe.grind_value, draft.grinder.unit_name)
        return draft.grinder.name .. (g and "  \u{00B7}  " .. g or "")
      end,
      edit = function(form)
        form.nav:push(GrindSelect.build {
          draft = draft,
          on_change = function()
            form:refreshItems()
          end,
        })
      end,
    },
  }

  local order = { "dose", "water", "water_temp", "brew_time", "output" }
  for _, name in ipairs(order) do
    local spec = method.fields and method.fields[name]
    if spec and not spec.hidden then
      if name == "water_temp" then
        brew[#brew + 1] = temp_row(draft, spec)
      elseif name == "brew_time" then
        brew[#brew + 1] = brew_time_row(draft, spec)
      else
        brew[#brew + 1] = grams_row(draft, name, spec)
      end
    end
  end
  for _, param in ipairs(method.params or {}) do
    brew[#brew + 1] = param_row(param, draft)
  end

  local output = {}
  if method.output_note then
    output[#output + 1] = {
      key = "output_note",
      label = method.output_note.label or _("Expected result"),
      display = function()
        return draft.recipe.output_note ~= "" and draft.recipe.output_note or nil
      end,
      edit = function(form)
        TextInput.show {
          title = method.output_note.label or _("Expected result"),
          value = draft.recipe.output_note,
          on_ok = function(t)
            draft.recipe.output_note = t
            form:refreshItems()
          end,
        }
      end,
    }
  end
  output[#output + 1] = {
    key = "_sensory",
    label = _("Flavor & sensory"),
    display = function()
      local set = 0
      for _, axis in ipairs(Constants.SENSORY_AXES) do
        if draft.recipe[axis.key] ~= nil then
          set = set + 1
        end
      end
      local tags = #draft.flavor_tag_ids
      if set == 0 and tags == 0 then
        return nil
      end
      return string.format(_("%d axes \u{00B7} %d tags"), set, tags)
    end,
    edit = function(form)
      form.nav:push(Sensory.build {
        draft = draft,
        on_change = function()
          form:refreshItems()
        end,
      })
    end,
  }

  local steps = {
    {
      key = "_steps",
      label = _("Brew steps"),
      display = function()
        local n = #draft.steps
        return n > 0 and string.format(_("%d steps"), n) or nil
      end,
      edit = function(form)
        form.nav:push(StepEditor:new {
          draft = draft,
          on_change = function()
            form:refreshItems()
          end,
        })
      end,
    },
  }

  self.pages = {
    {
      title = _("Basics"),
      fields = basics,
      validate = function(v)
        if not v.title or v.title == "" then
          return _("Give the recipe a title.")
        end
      end,
    },
    { title = _("Brew"), fields = brew },
    { title = _("Steps"), fields = steps },
    { title = _("Output"), fields = output },
  }

  Wizard.init(self)
end

function RecipeForm:on_save()
  self:_persist()
end

function RecipeForm:_persist()
  local ok, result = require("ui/recipe/add_flow").save(self.draft)
  if not ok then
    UIManager:show(InfoMessage:new { text = tostring(result), icon = "notice-warning" })
    return
  end
  if self.on_saved then
    self.on_saved(result.id)
  end
  if self.editing then
    if self.nav then
      self.nav:pop()
    else
      UIManager:close(self)
    end
  else
    local Detail = require("ui/recipe/detail")
    if self.nav then
      self.nav:replace(Detail:new { recipe_id = result.id })
    else
      UIManager:close(self)
    end
  end
end

return RecipeForm
