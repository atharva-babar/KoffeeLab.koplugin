-- ui/recipe/recipe_form.lua
-- The method-driven recipe form (TECH_SOLUTION §2.4, §2.8, §3.6). Its rows are
-- built from the §1.9a fixed-column set plus the chosen method's
-- `brew_method_parameters` — there is no `if method == …` branching in the UI.
-- Bean / grind / steps / sensory each push their own screen; everything writes
-- into the shared `draft`. Save goes through `recipe_service` (validation + one
-- transaction) via `ui/recipe/add_flow`.

local BeanSelect = require("ui/recipe/bean_select")
local DurationInput = require("ui/widgets/duration_input")
local Format = require("util/format")
local FormScreen = require("ui/widgets/form_screen")
local GrindSelect = require("ui/recipe/grind_select")
local InfoMessage = require("ui/widget/infomessage")
local ListPicker = require("ui/widgets/list_picker")
local NumberInput = require("ui/widgets/number_input")
local Sensory = require("ui/recipe/sensory")
local StepEditor = require("ui/recipe/step_editor")
local TextInput = require("ui/widgets/text_input")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local RecipeForm = FormScreen:extend {
  name = "koffeelab_recipe_form",
  draft = nil, -- required
  on_saved = nil, -- optional: function(recipe_id)
}

local function grams_field(key, label, draft, min_zero)
  return {
    key = key,
    label = label,
    display = function()
      return draft.recipe[key] and Format.grams(draft.recipe[key]) or nil
    end,
    edit = function(form)
      NumberInput.show {
        title = label,
        value = draft.recipe[key] or 0,
        min = 0,
        max = 5000,
        step = 1,
        precision = "%.1f",
        unit = "g",
        on_ok = function(n)
          draft.recipe[key] = (min_zero or n > 0) and n or nil
          form:refreshItems()
        end,
      }
    end,
  }
end

-- One row per method parameter, rendered by its data_type (§3.6).
local function param_field(param, draft)
  local pid = tonumber(param.id)
  local label = param.label .. (param.unit and param.unit ~= "" and " (" .. param.unit .. ")" or "")
  return {
    key = "param_" .. tostring(pid),
    label = label,
    display = function()
      local v = draft.params[pid]
      if v == nil or v == "" then
        return nil
      end
      if param.data_type == "duration" then
        return Format.duration(tonumber(v)) or tostring(v)
      end
      if param.data_type == "bool" then
        return (tostring(v) == "1" or v == true) and _("Yes") or _("No")
      end
      return tostring(v)
    end,
    edit = function(form)
      local dt = param.data_type
      if dt == "text" then
        TextInput.show {
          title = param.label,
          value = draft.params[pid],
          on_ok = function(t)
            draft.params[pid] = t ~= "" and t or nil
            form:refreshItems()
          end,
        }
      elseif dt == "bool" then
        ListPicker.show {
          title = param.label,
          items = { { text = _("No"), value = 0 }, { text = _("Yes"), value = 1 } },
          current = tonumber(draft.params[pid]) or 0,
          on_select = function(v)
            draft.params[pid] = v
            form:refreshItems()
          end,
        }
      elseif dt == "duration" then
        DurationInput.show {
          title = param.label,
          value_sec = tonumber(draft.params[pid]),
          on_ok = function(sec)
            draft.params[pid] = sec
            form:refreshItems()
          end,
        }
      else -- int / real
        NumberInput.show {
          title = param.label,
          value = tonumber(draft.params[pid]) or param.min_value or 0,
          min = param.min_value or 0,
          max = param.max_value or 100000,
          step = dt == "real" and 0.1 or 1,
          precision = dt == "real" and "%.1f" or nil,
          unit = param.unit,
          on_ok = function(n)
            draft.params[pid] = n
            form:refreshItems()
          end,
        }
      end
    end,
  }
end

function RecipeForm:init()
  local draft = assert(self.draft, "RecipeForm needs a draft")
  self.editing = draft.editing_id ~= nil
  self.title = self.editing and _("Edit Recipe") or _("New Recipe")
  self.values = draft.recipe

  local method = draft.method
  local is_espresso = method.slug == "espresso"

  local fields = {
    {
      key = "title",
      label = _("Title"),
      display = function(v)
        return v.title
      end,
      edit = function(form)
        TextInput.show {
          title = _("Recipe title"),
          value = form.values.title,
          hint = _("e.g. Ethiopia Guji V60"),
          on_ok = function(t)
            form:set("title", t ~= "" and t or nil)
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
    grams_field("dose_g", _("Dose"), draft, false),
    {
      key = "_grind",
      label = _("Grind"),
      display = function()
        if not draft.grinder then
          return nil
        end
        local g = Format.grind(draft.recipe.grind_value, draft.grinder.unit_name)
        return draft.grinder.name .. (g and "  ·  " .. g or "")
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

  if not is_espresso then
    fields[#fields + 1] = grams_field("water_g", _("Total water"), draft, false)
  else
    fields[#fields + 1] = {
      key = "water_g",
      label = _("Total water"),
      display = function(v)
        return v.water_g and Format.grams(v.water_g) or _("n/a (espresso)")
      end,
      edit = function(form)
        NumberInput.show {
          title = _("Total water (optional for espresso)"),
          value = form.values.water_g or 0,
          min = 0,
          max = 5000,
          step = 1,
          precision = "%.1f",
          unit = "g",
          on_ok = function(n)
            form:set("water_g", n > 0 and n or nil)
          end,
        }
      end,
    }
  end

  fields[#fields + 1] = {
    key = "water_temp_c",
    label = _("Water temperature"),
    display = function(v)
      return v.water_temp_c and Format.temp_c(v.water_temp_c) or nil
    end,
    edit = function(form)
      NumberInput.show {
        title = _("Water temperature (°C)"),
        value = form.values.water_temp_c or 94,
        min = 0,
        max = 100,
        step = 1,
        unit = "°C",
        on_ok = function(n)
          form:set("water_temp_c", n > 0 and n or nil)
        end,
      }
    end,
  }

  fields[#fields + 1] = {
    key = "brew_time_sec",
    label = is_espresso and _("Shot time") or _("Brew time"),
    display = function(v)
      return v.brew_time_sec and Format.duration(v.brew_time_sec) or nil
    end,
    edit = function(form)
      DurationInput.show {
        title = is_espresso and _("Shot time") or _("Brew time"),
        value_sec = form.values.brew_time_sec,
        on_ok = function(sec)
          form:set("brew_time_sec", sec)
        end,
      }
    end,
  }

  fields[#fields + 1] = grams_field("output_weight_g", _("Output weight"), draft, false)

  for _idx, param in ipairs(method.parameters or {}) do -- luacheck: ignore _idx
    fields[#fields + 1] = param_field(param, draft)
  end

  fields[#fields + 1] = {
    key = "_steps",
    label = _("Brew steps"),
    display = function()
      local n = #draft.steps
      return n > 0 and tostring(n) or nil
    end,
    edit = function(form)
      form.nav:push(StepEditor:new {
        draft = draft,
        on_change = function()
          form:refreshItems()
        end,
      })
    end,
  }

  fields[#fields + 1] = {
    key = "_sensory",
    label = _("Flavor & sensory"),
    display = function(v)
      local set = 0
      for _i2, axis in ipairs(require("util/constants").SENSORY_AXES) do -- luacheck: ignore _i2
        if v[axis.key] ~= nil then
          set = set + 1
        end
      end
      local tags = #draft.flavor_tag_ids
      if set == 0 and tags == 0 then
        return nil
      end
      return string.format(_("%d axes · %d tags"), set, tags)
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

  self.fields = fields
  self.actions = {
    {
      text = _("Save recipe"),
      callback = function(form)
        form:_save()
      end,
    },
  }

  FormScreen.init(self)
end

function RecipeForm:_save()
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
