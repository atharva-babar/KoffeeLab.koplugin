require("koffeelab.spec_helper")
local helper = require("koffeelab.spec_helper")
require("ui/paths").root = "plugins/KoffeeLab.koplugin"
local Nav = require("ui/nav")

local MethodService = require("services/method_service")
local ConfigService = require("services/config_service")
local RecipeService = require("services/recipe_service")
local AddFlow = require("ui/recipe/add_flow")

-- Regression: TagPicker used `self.selected`, which Menu/FocusManager reserves
-- for its focus cursor and overwrites, so flavour tags never reached the draft.
describe("flavour tags through the Add Recipe wizard", function()
  local ids
  before_each(function()
    ids = helper.recipe_ready()
    Nav:closeAll()
  end)
  after_each(function()
    Nav:closeAll()
    helper.teardown()
  end)

  it("tags ticked in Sensory are saved on the recipe", function()
    assert(ConfigService.flavor_tags.create { name = "Citrus" })
    assert(ConfigService.flavor_tags.create { name = "Cocoa" })

    AddFlow.start {}
    local _, po = MethodService.get_by_slug("pour_over")
    Nav:top():on_pick(po)
    local form = Nav:top()

    for k, v in pairs {
      title = "Tagged V60",
      bean_id = ids.bean_id,
      grinder_id = ids.grinder_id,
      grind_value = 15,
      dose_g = 18,
      water_g = 300,
      water_temp_c = 94,
      brew_time_sec = 165,
      output_weight_g = 250,
    } do
      form.draft.recipe[k] = v
    end

    local sensory_field
    for _, f in ipairs(form.all_fields) do
      if f.key == "_sensory" then
        sensory_field = f
      end
    end
    sensory_field.edit(form)
    local sensory = Nav:top()

    local tag_field
    for _, item in ipairs(sensory.item_table) do
      if item._field and item._field.key == "flavor_tag_ids" then
        tag_field = item._field
      end
    end
    tag_field.edit(sensory)
    local picker = Nav:top()
    assert.are.equal("koffeelab_recipe_tags", picker.name)
    assert.are.equal(picker.chosen_ids, form.draft.flavor_tag_ids) -- same table, not a copy

    for _, item in ipairs(picker.item_table) do
      if item._id then
        picker:onMenuChoice(item)
      end
    end
    assert.are.equal(2, #form.draft.flavor_tag_ids)

    Nav:pop() -- picker
    Nav:pop() -- sensory
    Nav:top():_save()

    assert.are.equal("koffeelab_recipe_detail", Nav:top().name)
    local _, recipe = RecipeService.get(Nav:top().recipe_id)
    assert.are.equal(2, #(recipe.flavor_tags or {}))
  end)
end)
