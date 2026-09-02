-- ui/recipe/detail.lua
-- Read-only recipe view (design-language §4.4): a scrolling stack of SectionCards
-- — Brew Details (a tile strip), Steps, Sensory, Output / Result, Flavour,
-- History (tap → sessions), Notes. Every verb (Edit / Delete / Brew again /
-- Favourite) is on the `detail_recipe` navbar. Derived values (ratio, step
-- duration, cumulative water) are computed here, never stored.

local AddFlow = require("ui/recipe/add_flow")
local BrewAgain = require("ui/recipe/brew_again")
local ConfigService = require("services/config_service")
local ConfirmDialog = require("ui/widgets/confirm_dialog")
local Constants = require("util/constants")
local Derive = require("methods/derive")
local Design = require("ui/design")
local Format = require("util/format")
local KvList = require("ui/widgets/kv_list")
local Methods = require("methods/init")
local RecipeService = require("services/recipe_service")
local ScreenCard = require("ui/screen_card")
local SectionCard = require("ui/widgets/section_card")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TileStrip = require("ui/widgets/tile_strip")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")

local RecipeDetail = ScreenCard:extend {
  name = "koffeelab_recipe_detail",
  navbar = "detail_recipe",
  recipe_id = nil,
  on_changed = nil,
}

function RecipeDetail:init()
  self:_fetch()
  self.title = self.recipe and self.recipe.title or _("Recipe")
  self.navbar = self:_navItems() -- the favourite cell reflects state
  ScreenCard.init(self)
end

function RecipeDetail:_navItems()
  return {
    "home",
    "edit",
    "delete",
    "brew_again",
    { key = "favourite", on = self:_isFavourite() },
  }
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

function RecipeDetail:_isFavourite()
  return self.recipe ~= nil and tonumber(self.recipe.is_favorite) == 1
end

-- A stack of "label ......... value" lines, for use as a SectionCard body.
function RecipeDetail:_rows(pairs_)
  return KvList.new(self.card_w - 2 * Design.pad.card, pairs_)
end

function RecipeDetail:_wrapped(text)
  return TextBoxWidget:new {
    text = tostring(text),
    face = Design.face("body"),
    width = self.card_w - 2 * Design.pad.card,
  }
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

function RecipeDetail:buildCards()
  local m = self.recipe
  if not m then
    self.not_found = true
    return {
      SectionCard:new {
        width = self.card_w,
        show_parent = self,
        body = self:_wrapped(_("Recipe not found. It may have been deleted.")),
      },
    }
  end
  self.not_found = false
  local method = m.method or Methods.get(m.method_slug)
  local cards = {}

  -- Brew Details -------------------------------------------------------------
  local tiles = {}
  local function tile(label, value)
    if value ~= nil and value ~= "" then
      tiles[#tiles + 1] = { label = label, value = tostring(value) }
    end
  end
  tile(_("Method"), m.method_name)
  if self.bean then
    tile(_("Bean"), self.bean.name .. (m.dose_g and "  \u{00B7}  " .. Format.grams(m.dose_g) or ""))
  elseif m.dose_g ~= nil then
    tile(_("Dose"), Format.grams(m.dose_g))
  end
  if self.grinder then
    local g = Format.grind(m.grind_value, self.grinder.unit_name)
    tile(_("Grind"), self.grinder.name .. (g and "  \u{00B7}  " .. g or ""))
  end
  if m.water_g ~= nil or m.water_temp_c ~= nil then
    local bits = {}
    if m.water_g ~= nil then
      bits[#bits + 1] = Format.grams(m.water_g)
    end
    if m.water_temp_c ~= nil then
      bits[#bits + 1] = Format.temp_c(m.water_temp_c)
    end
    tile(_("Water"), table.concat(bits, " / "))
  end
  if m.brew_time_sec ~= nil then
    tile(_("Brew time"), Format.duration(m.brew_time_sec))
  end
  local ratio = Format.ratio(m.water_g, m.dose_g, m.output_weight_g)
  if m.output_weight_g ~= nil or ratio then
    local bits = {}
    if m.output_weight_g ~= nil then
      bits[#bits + 1] = Format.grams(m.output_weight_g)
    end
    if ratio then
      bits[#bits + 1] = ratio
    end
    tile(_("Output"), table.concat(bits, "  \u{00B7}  "))
  end
  for _, p in ipairs(method and method.params or {}) do
    tile(p.label, param_value(p, m.spec and m.spec[p.key]))
  end
  cards[#cards + 1] = SectionCard:new {
    width = self.card_w,
    title = _("Brew Details"),
    show_parent = self,
    body = TileStrip:new { width = self.card_w - 2 * Design.pad.card, items = tiles },
  }

  -- Steps -------------------------------------------------------------------
  if #(m.steps or {}) > 0 then
    local total_water = Derive.total_water(m.steps)
    local step_rows = {}
    for i, step in ipairs(m.steps) do
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
      step_rows[#step_rows + 1] = {
        string.format("#%d  %s", i, Methods.step_label(step.step_type)),
        table.concat(note, "  \u{00B7}  "),
      }
    end
    cards[#cards + 1] = SectionCard:new {
      width = self.card_w,
      title = _("Steps"),
      show_parent = self,
      body = self:_rows(step_rows),
    }
  end

  -- Sensory + Output / Result --------------------------------------------
  local sensory_rows = {}
  for _, axis in ipairs(Constants.SENSORY_AXES) do
    if m[axis.key] ~= nil then
      sensory_rows[#sensory_rows + 1] = { axis.label, Format.rating_stars(m[axis.key]) }
    end
  end
  if #sensory_rows > 0 then
    cards[#cards + 1] = SectionCard:new {
      width = self.card_w,
      title = _("Sensory"),
      show_parent = self,
      body = self:_rows(sensory_rows),
    }
  end

  local result_rows = {}
  if m.overall_rating ~= nil then
    result_rows[#result_rows + 1] = { _("Overall"), Format.rating_stars(m.overall_rating) }
  end
  if #(m.flavor_tags or {}) > 0 then
    local names = {}
    for _, tag in ipairs(m.flavor_tags) do
      names[#names + 1] = tag.name
    end
    result_rows[#result_rows + 1] = { _("Flavour"), table.concat(names, "  \u{00B7}  ") }
  end
  if m.output_note and m.output_note ~= "" or #result_rows > 0 then
    local label = method and method.output_note and method.output_note.label or _("Expected result")
    local body
    if m.output_note and m.output_note ~= "" and #result_rows > 0 then
      body = VerticalGroup:new {
        align = "left",
        self:_wrapped(m.output_note),
        VerticalSpan:new { width = Design.gap },
        self:_rows(result_rows),
      }
    elseif m.output_note and m.output_note ~= "" then
      body = self:_wrapped(m.output_note)
    else
      body = self:_rows(result_rows)
    end
    cards[#cards + 1] = SectionCard:new {
      width = self.card_w,
      title = label,
      show_parent = self,
      body = body,
    }
  end

  -- History ---------------------------------------------------------------
  local stats = m.stats or {}
  local hist_rows = { { _("Brew count"), tonumber(stats.brew_count) or 0 } }
  if stats.avg_session_rating then
    hist_rows[#hist_rows + 1] =
      { _("Session average"), Format.rating_avg_stars(tonumber(stats.avg_session_rating)) }
  end
  cards[#cards + 1] = SectionCard:new {
    width = self.card_w,
    title = _("History"),
    show_parent = self,
    on_tap = function()
      self:_openHistory()
    end,
    body = self:_rows(hist_rows),
  }

  -- Notes ---------------------------------------------------------------
  if m.notes and m.notes ~= "" then
    cards[#cards + 1] = SectionCard:new {
      width = self.card_w,
      title = _("Notes"),
      show_parent = self,
      body = self:_wrapped(m.notes),
    }
  end

  return cards
end

--- Navbar verbs (design-language §3.7 `detail_recipe` preset).
function RecipeDetail:onNavAction(key)
  if key == "edit" then
    self:_edit()
  elseif key == "delete" then
    self:_delete()
  elseif key == "brew_again" then
    self:_brew(_("Brew Again"))
  elseif key == "favourite" then
    RecipeService.set_favorite(self.recipe_id, not self:_isFavourite())
    self:_afterSessionChange()
  end
end

function RecipeDetail:_reload()
  self:_fetch()
  self.title = self.recipe and self.recipe.title or _("Recipe")
  self:setNavbarItems(self:_navItems())
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
