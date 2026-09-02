-- ui/recipe/detail.lua
-- Recipe detail page (TECH_SOLUTION §2.15). Read-only presentation of one recipe:
-- the brew parameters, ratio (util/format), sensory block, flavor tags, notes,
-- and the derived brew count + session average (never stored — §3.13). The
-- trailing rows are the actions: Brew Again / Add Observation (§2.16), Brew
-- history (§2.15), Edit and Delete (§2.17, §2.18). Built on Menu; informational
-- rows are inert.

local AddFlow = require("ui/recipe/add_flow")
local BrewAgain = require("ui/recipe/brew_again")
local ConfigService = require("services/config_service")
local ConfirmDialog = require("ui/widgets/confirm_dialog")
local Constants = require("util/constants")
local Format = require("util/format")
local Menu = require("ui/widget/menu")
local RecipeService = require("services/recipe_service")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local RecipeDetail = Menu:extend {
  name = "koffeelab_recipe_detail",
  covers_fullscreen = true,
  is_borderless = true,
  is_popout = false,
  is_enable_shortcut = false,
  with_bottom_line = true,
  title_bar_left_icon = "chevron.left",
  recipe_id = nil, -- required
  on_changed = nil, -- optional: called after edit / delete (e.g. to refresh an index)
}

function RecipeDetail:init()
  self:_fetch()
  self.title = self.recipe and self.recipe.title or _("Recipe")
  self.item_table = self:_items()
  Menu.init(self)
end

function RecipeDetail:_fetch()
  local ok, recipe = RecipeService.get(self.recipe_id)
  self.recipe = ok and recipe or nil
  if not self.recipe then
    return
  end
  local m = self.recipe
  self.method_name = nil
  local mok, method = require("services/method_service").get(m.method_id)
  self.method_name = mok and method.name or nil
  if m.bean_id then
    local bok, bean = ConfigService.beans.get(m.bean_id)
    self.bean = bok and bean or nil
  end
  if m.grinder_id then
    local gok, grinder = ConfigService.grinders.get(m.grinder_id)
    self.grinder = gok and grinder or nil
  end
end

local function row(text, value)
  return { text = text, mandatory = value and tostring(value) or _("—") }
end

function RecipeDetail:_items()
  local m = self.recipe
  if not m then
    return { { text = _("Recipe not found.") } }
  end
  local items = {}

  if self.method_name then
    items[#items + 1] = row(_("Method"), self.method_name)
  end
  if self.bean then
    items[#items + 1] = row(_("Bean"), self.bean.name)
  end
  items[#items + 1] = row(_("Dose"), Format.grams(m.dose_g))
  if self.grinder then
    local g = Format.grind(m.grind_value, self.grinder.unit_name)
    items[#items + 1] = row(_("Grinder"), self.grinder.name .. (g and "  ·  " .. g or ""))
  end
  if m.water_g ~= nil then
    items[#items + 1] = row(_("Water"), Format.grams(m.water_g))
  end
  if m.water_temp_c ~= nil then
    items[#items + 1] = row(_("Temperature"), Format.temp_c(m.water_temp_c))
  end
  if m.brew_time_sec ~= nil then
    items[#items + 1] = row(_("Brew time"), Format.duration(m.brew_time_sec))
  end
  if m.output_weight_g ~= nil then
    items[#items + 1] = row(_("Output"), Format.grams(m.output_weight_g))
  end
  local ratio = Format.ratio(m.water_g, m.dose_g, m.output_weight_g)
  if ratio then
    items[#items + 1] = row(_("Ratio"), ratio)
  end

  for _idx, p in ipairs(m.parameters or {}) do -- luacheck: ignore _idx
    local v = p.value
    if p.data_type == "duration" and tonumber(v) then
      v = Format.duration(tonumber(v))
    elseif p.unit and p.unit ~= "" and v ~= nil then
      v = tostring(v) .. " " .. p.unit
    end
    items[#items + 1] = row("  " .. p.label, v)
  end

  if #(m.steps or {}) > 0 then
    items[#items + 1] = { text = _("Brew steps"), mandatory = tostring(#m.steps), _head = true }
    for i, step in ipairs(m.steps) do
      local head = string.format(
        "  #%d  %s",
        i,
        Constants.STEP_TYPE_LABELS[step.step_type] or step.step_type or "?"
      )
      local note = {}
      if step.start_time_sec then
        note[#note + 1] = Format.duration(step.start_time_sec)
      end
      if step.target_total_water_g then
        note[#note + 1] = Format.grams(step.target_total_water_g)
      elseif step.target_water_g then
        note[#note + 1] = Format.grams(step.target_water_g)
      end
      items[#items + 1] = { text = head, mandatory = table.concat(note, " · ") }
    end
  end

  local sensory = {}
  for _idx, axis in ipairs(Constants.SENSORY_AXES) do -- luacheck: ignore _idx
    if m[axis.key] ~= nil then
      sensory[#sensory + 1] = axis.label .. " " .. tostring(m[axis.key])
    end
  end
  if #sensory > 0 then
    items[#items + 1] = { text = _("Sensory"), mandatory = "", _head = true }
    items[#items + 1] = { text = "  " .. table.concat(sensory, "   ") }
  end
  if m.overall_rating ~= nil then
    items[#items + 1] = row(_("Overall"), Format.rating_stars(m.overall_rating))
  end

  if #(m.flavor_tags or {}) > 0 then
    local names = {}
    for _idx, tag in ipairs(m.flavor_tags) do -- luacheck: ignore _idx
      names[#names + 1] = tag.name
    end
    items[#items + 1] = row(_("Flavor"), table.concat(names, " · "))
  end

  if m.notes and m.notes ~= "" then
    items[#items + 1] = { text = _("Notes"), mandatory = "", _head = true }
    items[#items + 1] = { text = "  " .. m.notes }
  end

  local stats = m.stats or {}
  items[#items + 1] = row(_("Brew count"), tonumber(stats.brew_count) or 0)
  if stats.avg_session_rating then
    items[#items + 1] =
      row(_("Session average"), Format.rating_avg_stars(tonumber(stats.avg_session_rating)))
  end

  items[#items + 1] = { text = _("Brew Again"), mandatory = "\u{203A}", _action = "brew_again" }
  items[#items + 1] = { text = _("Add Observation"), mandatory = "\u{203A}", _action = "observe" }
  items[#items + 1] = {
    text = _("Brew history"),
    mandatory = (tonumber(stats.brew_count) or 0) .. "  \u{203A}",
    _action = "history",
  }
  items[#items + 1] = { text = _("Edit"), mandatory = "\u{203A}", _action = "edit" }
  items[#items + 1] = { text = _("Delete"), mandatory = "\u{203A}", _action = "delete" }
  return items
end

function RecipeDetail:_reload()
  self:_fetch()
  self:switchItemTable(self.recipe and self.recipe.title or _("Recipe"), self:_items(), 1)
end

function RecipeDetail:_afterSessionChange()
  self:_reload()
  if self.on_changed then
    self.on_changed()
  end
end

function RecipeDetail:onMenuChoice(item)
  local action = item._action
  local stats = self.recipe and self.recipe.stats or {}
  if action == "brew_again" or action == "observe" then
    BrewAgain.open(self.recipe_id, {
      title = action == "observe" and _("Add Observation") or _("Brew Again"),
      brew_count = tonumber(stats.brew_count) or 0,
      on_saved = function()
        self:_afterSessionChange()
      end,
    })
  elseif action == "history" then
    local screen = require("ui/recipe/history"):new {
      recipe_id = self.recipe_id,
      on_changed = function()
        self:_afterSessionChange()
      end,
    }
    if self.nav then
      self.nav:push(screen)
    else
      UIManager:show(screen)
    end
  elseif action == "edit" then
    ConfirmDialog.confirm {
      text = _("Edit recipe?\n\nExisting recipe data will be changed."),
      ok_text = _("Continue"),
      on_confirm = function()
        AddFlow.edit(self.recipe_id, {
          on_saved = function()
            if self.on_changed then
              self.on_changed()
            end
            self:_reload()
          end,
        })
      end,
    }
  elseif action == "delete" then
    ConfirmDialog.destructive {
      text = _(
        "Delete recipe?\n\nThis will remove the recipe and its associated brew-session history."
      ),
      ok_text = _("Delete"),
      on_confirm = function()
        local ok, err = RecipeService.delete(self.recipe_id)
        if not ok then
          ConfirmDialog.blocked {
            text = _("Cannot delete — this recipe is ") .. tostring(err) .. _(
              ".\nRemove or change those drinks first."
            ),
          }
          return
        end
        if self.on_changed then
          self.on_changed()
        end
        if self.nav then
          self.nav:pop()
        else
          UIManager:close(self)
        end
      end,
    }
  end
  return true
end

function RecipeDetail:_back()
  if self.nav then
    self.nav:pop()
  else
    UIManager:close(self)
  end
  return true
end

RecipeDetail.onClose = RecipeDetail._back
RecipeDetail.onLeftButtonTap = RecipeDetail._back

return RecipeDetail
