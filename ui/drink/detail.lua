-- ui/drink/detail.lua
-- Custom-drink detail page (TECH_SOLUTION §2.15 / §2.14). Read-only presentation
-- of one drink: temperature, base recipe + amount used, the derived remaining
-- output (never stored — §3.13), extra ingredients, process steps, rating and
-- comment, plus Edit / Delete actions (§2.17). Built on Menu; informational rows
-- are inert.

local AddFlow = require("ui/drink/add_flow")
local ConfirmDialog = require("ui/widgets/confirm_dialog")
local Constants = require("util/constants")
local Format = require("util/format")
local Menu = require("ui/widget/menu")
local DrinkService = require("services/drink_service")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local DrinkDetail = Menu:extend {
  name = "koffeelab_drink_detail",
  covers_fullscreen = true,
  is_borderless = true,
  is_popout = false,
  is_enable_shortcut = false,
  with_bottom_line = true,
  title_bar_left_icon = "chevron.left",
  drink_id = nil, -- required
  on_changed = nil, -- optional: called after edit / delete (Phase 8)
}

function DrinkDetail:init()
  self:_fetch()
  self.title = self.drink and self.drink.title or _("Drink")
  self.item_table = self:_items()
  Menu.init(self)
end

function DrinkDetail:_fetch()
  local ok, drink = DrinkService.get(self.drink_id)
  self.drink = ok and drink or nil
end

local function row(text, value)
  return { text = text, mandatory = value and tostring(value) or _("\u{2014}") }
end

local function amount_str(amount, unit)
  local n = tonumber(amount)
  if n == nil then
    return nil
  end
  if unit and unit ~= "" then
    return (string.format("%.2f", n):gsub("%.?0+$", "")) .. " " .. unit
  end
  return Format.grams(n)
end

function DrinkDetail:_items()
  local d = self.drink
  if not d then
    return { { text = _("Drink not found."), _inert = true } }
  end
  local items = {}

  items[#items + 1] = row(
    _("Temperature"),
    Constants.TEMPERATURE_MODE_LABELS[d.temperature_mode] or d.temperature_mode
  )

  local base = d.base_recipe
  items[#items + 1] = row(_("Base recipe"), base and base.title or _("\u{2014}"))
  items[#items + 1] = row(_("Amount used"), amount_str(d.base_amount, d.base_unit))

  local out = base and tonumber(base.output_weight_g) or nil
  local used = tonumber(d.base_amount)
  if out and used then
    items[#items + 1] = row(_("Remaining of batch"), Format.grams(math.max(0, out - used)))
  end

  if #(d.ingredients or {}) > 0 then
    items[#items + 1] =
      { text = _("Ingredients"), mandatory = tostring(#d.ingredients), _inert = true }
    for _idx, ing in ipairs(d.ingredients) do -- luacheck: ignore _idx
      items[#items + 1] = {
        text = "  " .. (ing.ingredient_name or _("?")),
        mandatory = amount_str(ing.amount, ing.unit) or _("\u{2014}"),
      }
    end
  end

  if #(d.steps or {}) > 0 then
    items[#items + 1] = { text = _("Steps"), mandatory = tostring(#d.steps), _inert = true }
    for i, step in ipairs(d.steps) do
      items[#items + 1] = { text = string.format("  #%d  %s", i, step.instruction or "") }
      if step.note and step.note ~= "" then
        items[#items + 1] = { text = "      " .. step.note, _inert = true }
      end
    end
  end

  if d.rating ~= nil then
    items[#items + 1] = row(_("Rating"), Format.rating_stars(tonumber(d.rating)))
  end
  if d.comment and d.comment ~= "" then
    items[#items + 1] = { text = _("Comment"), mandatory = "", _inert = true }
    items[#items + 1] = { text = "  " .. d.comment, _inert = true }
  end

  items[#items + 1] = { text = _("Edit"), mandatory = "\u{203A}", _action = "edit" }
  items[#items + 1] = { text = _("Delete"), mandatory = "\u{203A}", _action = "delete" }
  return items
end

function DrinkDetail:_reload()
  self:_fetch()
  self:switchItemTable(self.drink and self.drink.title or _("Drink"), self:_items(), 1)
end

function DrinkDetail:onMenuChoice(item)
  local action = item and item._action
  if action == "edit" then
    ConfirmDialog.confirm {
      text = _("Edit drink?\n\nExisting drink data will be changed."),
      ok_text = _("Continue"),
      on_confirm = function()
        AddFlow.edit(self.drink_id, {
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
      text = _("Delete drink?\n\nThis removes the drink, its ingredients and its steps."),
      ok_text = _("Delete"),
      on_confirm = function()
        local ok, err = DrinkService.delete(self.drink_id)
        if not ok then
          ConfirmDialog.blocked { text = tostring(err) }
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

function DrinkDetail:_back()
  if self.nav then
    self.nav:pop()
  else
    UIManager:close(self)
  end
  return true
end

DrinkDetail.onClose = DrinkDetail._back
DrinkDetail.onLeftButtonTap = DrinkDetail._back

return DrinkDetail
