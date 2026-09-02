-- ui/recipe/detail.lua
-- Read-only recipe view plus the action rows (Brew Again / Add Observation /
-- Brew history / Favourite / Edit / Delete). A scrolling list grouped into
-- sections; informational rows are inert. Derived values (ratio, step duration,
-- cumulative water) are computed here, never stored.

local AddFlow = require("ui/recipe/add_flow")
local BrewAgain = require("ui/recipe/brew_again")
local ConfigService = require("services/config_service")
local ConfirmDialog = require("ui/widgets/confirm_dialog")
local Constants = require("util/constants")
local Derive = require("methods/derive")
local Format = require("util/format")
local Methods = require("methods/init")
local RecipeService = require("services/recipe_service")
local ScreenList = require("ui/screen_list")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local RecipeDetail = ScreenList:extend {
  name = "koffeelab_recipe_detail",
  recipe_id = nil,
  on_changed = nil,
}

function RecipeDetail:init()
  self:_fetch()
  self.title = self.recipe and self.recipe.title or _("Recipe")
  ScreenList.init(self)
end

function RecipeDetail:_fetch()
  local ok, recipe = RecipeService.get(self.recipe_id)
  self.recipe = ok and recipe or nil
  if not self.recipe then
    return
  end
  if self.recipe.bean_id then
    local bok, bean = ConfigService.beans.get(self.recipe.bean_id)
    self.bean = bok and bean or nil
  end
  if self.recipe.grinder_id then
    local gok, grinder = ConfigService.grinders.get(self.recipe.grinder_id)
    self.grinder = gok and grinder or nil
  end
end

local function row(text, value)
  return { text = text, mandatory = value and tostring(value) or _("\u{2014}") }
end

local function param_value(param, raw)
  if raw == nil or raw == "" then
    return nil
  end
  if param.type == "duration" and tonumber(raw) then
    return Format.duration(tonumber(raw))
  end
  if param.type == "bool" then
    return (raw == true or tostring(raw) == "1") and _("Yes") or _("No")
  end
  if param.unit and param.unit ~= "" then
    return tostring(raw) .. " " .. param.unit
  end
  return tostring(raw)
end

function RecipeDetail:buildItems()
  local m = self.recipe
  if not m then
    return {
      { text = _("Recipe not found. It may have been deleted."), kind = "text", _inert = true },
    }
  end
  local method = m.method or Methods.get(m.method_slug)
  local items = {}

  items[#items + 1] = { text = _("Brew"), kind = "head" }
  items[#items + 1] = row(_("Method"), m.method_name)
  if self.bean then
    items[#items + 1] = row(_("Bean"), self.bean.name)
  end
  if m.dose_g ~= nil then
    items[#items + 1] = row(_("Dose"), Format.grams(m.dose_g))
  end
  if self.grinder then
    local g = Format.grind(m.grind_value, self.grinder.unit_name)
    items[#items + 1] = row(_("Grinder"), self.grinder.name .. (g and "  \u{00B7}  " .. g or ""))
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

  for _, p in ipairs(method and method.params or {}) do
    local v = param_value(p, m.spec and m.spec[p.key])
    if v ~= nil then
      items[#items + 1] = row(p.label, v)
    end
  end

  if #(m.steps or {}) > 0 then
    local total_water = Derive.total_water(m.steps)
    items[#items + 1] = { text = _("Brew steps"), mandatory = tostring(#m.steps), kind = "head" }
    for i, step in ipairs(m.steps) do
      local head = string.format("#%d  %s", i, Methods.step_label(step.step_type))
      local note = {}
      if step.start_time then
        note[#note + 1] = Format.duration(step.start_time)
      end
      local dur = Derive.duration(m.steps, i, m.brew_time_sec)
      if dur and dur > 0 then
        note[#note + 1] = Format.duration(dur)
      end
      if total_water[i] then
        note[#note + 1] = Format.grams(total_water[i])
      elseif step.water then
        note[#note + 1] = Format.grams(step.water)
      end
      items[#items + 1] = { text = head, mandatory = table.concat(note, " \u{00B7} ") }
    end
  end

  if m.output_note and m.output_note ~= "" then
    local label = method and method.output_note and method.output_note.label or _("Expected result")
    items[#items + 1] = { text = label, kind = "head" }
    items[#items + 1] = { text = m.output_note, kind = "text" }
  end

  local sensory = {}
  for _, axis in ipairs(Constants.SENSORY_AXES) do
    if m[axis.key] ~= nil then
      sensory[#sensory + 1] = axis.label .. " " .. tostring(m[axis.key])
    end
  end
  if #sensory > 0 then
    items[#items + 1] = { text = _("Sensory"), kind = "head" }
    items[#items + 1] = { text = table.concat(sensory, "   "), kind = "text" }
  end
  if m.overall_rating ~= nil then
    items[#items + 1] = row(_("Overall"), Format.rating_stars(m.overall_rating))
  end

  if #(m.flavor_tags or {}) > 0 then
    local names = {}
    for _, tag in ipairs(m.flavor_tags) do
      names[#names + 1] = tag.name
    end
    items[#items + 1] = row(_("Flavor"), table.concat(names, " \u{00B7} "))
  end

  if m.notes and m.notes ~= "" then
    items[#items + 1] = { text = _("Notes"), kind = "head" }
    items[#items + 1] = { text = m.notes, kind = "text" }
  end

  local stats = m.stats or {}
  items[#items + 1] = { text = _("History"), kind = "head" }
  items[#items + 1] = row(_("Brew count"), tonumber(stats.brew_count) or 0)
  if stats.avg_session_rating then
    items[#items + 1] =
      row(_("Session average"), Format.rating_avg_stars(tonumber(stats.avg_session_rating)))
  end

  local fav = tonumber(m.is_favorite) == 1
  items[#items + 1] = { text = _("Actions"), kind = "head" }
  items[#items + 1] = {
    text = _("Brew Again"),
    mandatory = "\u{203A}",
    _action = "brew_again",
    callback = function()
      self:_brew(_("Brew Again"))
    end,
  }
  items[#items + 1] = {
    text = _("Add Observation"),
    mandatory = "\u{203A}",
    _action = "observe",
    callback = function()
      self:_brew(_("Add Observation"))
    end,
  }
  items[#items + 1] = {
    text = _("Brew history"),
    mandatory = (tonumber(stats.brew_count) or 0) .. "  \u{203A}",
    _action = "history",
    callback = function()
      self:_openHistory()
    end,
  }
  items[#items + 1] = {
    text = fav and _("Remove from Favourites") or _("Add to Favourites"),
    mandatory = fav and "\u{2605}" or "\u{2606}",
    _action = "favorite",
    callback = function()
      RecipeService.set_favorite(self.recipe_id, not fav)
      self:_afterSessionChange()
    end,
  }
  items[#items + 1] = {
    text = _("Edit"),
    mandatory = "\u{203A}",
    _action = "edit",
    callback = function()
      self:_edit()
    end,
  }
  items[#items + 1] = {
    text = _("Delete"),
    mandatory = "\u{203A}",
    _action = "delete",
    callback = function()
      self:_delete()
    end,
  }
  return items
end

function RecipeDetail:_reload()
  self:_fetch()
  self.title = self.recipe and self.recipe.title or _("Recipe")
  self:refresh()
end

function RecipeDetail:_afterSessionChange()
  self:_reload()
  if self.on_changed then
    self.on_changed()
  end
end

function RecipeDetail:_brew(title)
  local stats = self.recipe and self.recipe.stats or {}
  BrewAgain.open(self.recipe_id, {
    title = title,
    brew_count = tonumber(stats.brew_count) or 0,
    on_saved = function()
      self:_afterSessionChange()
    end,
  })
end

function RecipeDetail:_openHistory()
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
end

function RecipeDetail:_edit()
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
end

function RecipeDetail:_delete()
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

return RecipeDetail
