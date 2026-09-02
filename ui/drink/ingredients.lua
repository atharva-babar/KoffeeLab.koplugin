-- ui/drink/ingredients.lua
-- Custom-drink ingredient editor (TECH_SOLUTION §2.12). A card list: add / edit /
-- delete rows of `ingredient + amount + unit`. The ingredient list comes from the
-- Configurator (active ingredients via `config_service`), with an inline
-- "+ New ingredient" affordance. Rows are held in `draft.ingredients` (an array);
-- persistence happens when the drink is saved. `on_change` repaints the parent
-- form's summary row.

local ConfigService = require("services/config_service")
local FormScreen = require("ui/widgets/form_screen")
local InfoMessage = require("ui/widget/infomessage")
local ListPicker = require("ui/widgets/list_picker")
local Menu = require("ui/widget/menu")
local NumberInput = require("ui/widgets/number_input")
local TextInput = require("ui/widgets/text_input")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local function amount_str(amount, unit)
  local n = tonumber(amount)
  if n == nil then
    return nil
  end
  local num = (string.format("%.2f", n):gsub("%.?0+$", ""))
  return num .. " " .. (unit ~= nil and unit ~= "" and unit or "g")
end

-- ── the ingredient picker (active list + inline create) ───────────────────────

local function pick_ingredient(current_id, on_pick)
  local ok, list = ConfigService.ingredients.list {}
  local items = {}
  for _idx, ing in ipairs(ok and list or {}) do -- luacheck: ignore _idx
    items[#items + 1] = { text = ing.name, value = ing.id, _row = ing }
  end
  ListPicker.show {
    title = _("Ingredient"),
    items = items,
    current = current_id,
    on_select = function(_, item)
      on_pick(item._row)
    end,
    extra = {
      text = "+ " .. _("New ingredient"),
      callback = function()
        TextInput.show {
          title = _("New ingredient"),
          hint = _("e.g. Milk"),
          on_ok = function(name)
            if name == "" then
              return
            end
            local created, res = ConfigService.ingredients.create { name = name }
            if not created then
              UIManager:show(InfoMessage:new { text = tostring(res), icon = "notice-warning" })
              return
            end
            on_pick(res)
          end,
        }
      end,
    },
  }
end

-- ── the per-ingredient edit form ─────────────────────────────────────────────

local function edit_ingredient(nav, row, on_done, on_remove)
  local draft = {
    ingredient_id = row and row.ingredient_id or nil,
    ingredient_name = row and row.ingredient_name or nil,
    amount = row and row.amount or nil,
    unit = row and row.unit or "g",
  }

  local fields = {
    {
      key = "ingredient_id",
      label = _("Ingredient"),
      display = function(v)
        return v.ingredient_name
      end,
      edit = function(f)
        pick_ingredient(f.values.ingredient_id, function(ing)
          f.values.ingredient_id = ing.id
          f.values.ingredient_name = ing.name
          f:refreshItems()
        end)
      end,
    },
    {
      key = "amount",
      label = _("Amount"),
      display = function(v)
        return v.amount and amount_str(v.amount, v.unit) or nil
      end,
      edit = function(f)
        NumberInput.show {
          title = _("Amount"),
          value = f.values.amount or 0,
          min = 0,
          max = 100000,
          step = 1,
          precision = "%.1f",
          unit = f.values.unit,
          on_ok = function(n)
            f:set("amount", n)
          end,
        }
      end,
    },
    {
      key = "unit",
      label = _("Unit"),
      display = function(v)
        return v.unit
      end,
      edit = function(f)
        TextInput.show {
          title = _("Unit"),
          value = f.values.unit,
          hint = _("g / ml / shots"),
          on_ok = function(t)
            f:set("unit", t ~= "" and t or "g")
          end,
        }
      end,
    },
  }

  local actions = {
    {
      text = _("Done"),
      callback = function(f)
        if f.values.ingredient_id == nil then
          UIManager:show(InfoMessage:new {
            text = _("Choose an ingredient first."),
            icon = "notice-warning",
          })
          return
        end
        f.values.amount = tonumber(f.values.amount) or 0
        on_done(f.values)
        nav:pop()
      end,
    },
  }
  if on_remove then
    actions[#actions + 1] = {
      text = _("Delete ingredient"),
      callback = function()
        on_remove()
        nav:pop()
      end,
    }
  end

  nav:push(FormScreen:new {
    title = row and _("Edit Ingredient") or _("New Ingredient"),
    values = draft,
    fields = fields,
    actions = actions,
  })
end

-- ── the ingredient list ─────────────────────────────────────────────────────

local DrinkIngredients = Menu:extend {
  name = "koffeelab_drink_ingredients",
  covers_fullscreen = true,
  is_borderless = true,
  is_popout = false,
  is_enable_shortcut = false,
  with_bottom_line = true,
  title_bar_left_icon = "chevron.left",
  title = _("Ingredients"),
  draft = nil, -- required
  on_change = nil,
}

function DrinkIngredients:init()
  self.rows = self.draft.ingredients
  self.item_table = self:_items()
  Menu.init(self)
end

function DrinkIngredients:_items()
  local items = { { text = "+ " .. _("Add ingredient"), _add = true } }
  for i, ing in ipairs(self.rows) do
    items[#items + 1] = {
      text = ing.ingredient_name or _("?"),
      mandatory = amount_str(ing.amount, ing.unit) or _("\u{2014}"),
      _index = i,
    }
  end
  return items
end

function DrinkIngredients:_refresh()
  if self.on_change then
    self.on_change()
  end
  self:switchItemTable(nil, self:_items(), 1)
end

function DrinkIngredients:onMenuChoice(item)
  if item._add then
    edit_ingredient(self.nav, nil, function(values)
      self.rows[#self.rows + 1] = values
      self:_refresh()
    end)
    return true
  end
  local idx = item._index
  if not idx then
    return true
  end
  edit_ingredient(self.nav, self.rows[idx], function(values)
    self.rows[idx] = values
    self:_refresh()
  end, function()
    table.remove(self.rows, idx)
    self:_refresh()
  end)
  return true
end

function DrinkIngredients:_back()
  if self.nav then
    self.nav:pop()
  else
    UIManager:close(self)
  end
  return true
end

DrinkIngredients.onClose = DrinkIngredients._back
DrinkIngredients.onLeftButtonTap = DrinkIngredients._back

DrinkIngredients._edit_ingredient = edit_ingredient

return DrinkIngredients
