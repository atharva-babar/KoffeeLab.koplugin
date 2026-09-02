-- ui/recipe/brew_again.lua
-- The Brew Again / Add Observation dialog (TECH_SOLUTION §2.16, §3.7). A light
-- form over one new brew_sessions row: an optional 1–5 session rating, an
-- optional comment, and an optional brew time (captured with the tap-to-capture
-- stopwatch — §2.16a — or entered by hand). It is never a recipe editor. On save
-- it calls brew_service.record; brew_count and the session average are derived,
-- so the caller just re-reads the detail page.

local BrewService = require("services/brew_service")
local ConfirmDialog = require("ui/widgets/confirm_dialog")
local DurationInput = require("ui/widgets/duration_input")
local Format = require("util/format")
local FormScreen = require("ui/widgets/form_screen")
local ListPicker = require("ui/widgets/list_picker")
local Nav = require("ui/nav")
local Stopwatch = require("ui/recipe/stopwatch")
local TextInput = require("ui/widgets/text_input")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local BrewAgain = {}

local RATING_ITEMS = {
  { text = _("Not set"), value = 0 },
  { text = "1", value = 1 },
  { text = "2", value = 2 },
  { text = "3", value = 3 },
  { text = "4", value = 4 },
  { text = "5", value = 5 },
}

--- "splits: 0:32 / 1:10 / 2:45" for a splits array, or nil when there are none.
local function splits_suffix(splits)
  if not splits or #splits == 0 then
    return nil
  end
  local parts = {}
  for _idx, s in ipairs(splits) do -- luacheck: ignore _idx
    parts[#parts + 1] = Format.duration(s) or "0:00"
  end
  return "splits: " .. table.concat(parts, " / ")
end

local function close(form)
  if form.nav then
    form.nav:pop()
  else
    UIManager:close(form)
  end
end

--- Open the dialog for `recipe_id`.
---   BrewAgain.open(recipe_id, { brew_count = N, on_saved = fn, title = _("…") })
function BrewAgain.open(recipe_id, opts)
  opts = opts or {}
  local obs = {
    session_rating = nil,
    comment = "",
    measured_brew_time_sec = nil,
    splits_suffix = nil,
  }
  local next_count = (tonumber(opts.brew_count) or 0) + 1

  local fields = {
    {
      key = "_info",
      label = _("Brew count will become"),
      display = function()
        return tostring(next_count)
      end,
    },
    {
      key = "session_rating",
      label = _("Rating (optional)"),
      display = function()
        return obs.session_rating and Format.rating_stars(obs.session_rating) or nil
      end,
      edit = function(form)
        ListPicker.show {
          title = _("Session rating"),
          items = RATING_ITEMS,
          current = obs.session_rating or 0,
          on_select = function(value)
            obs.session_rating = (value ~= 0) and value or nil
            form:refreshItems()
          end,
        }
      end,
    },
    {
      key = "comment",
      label = _("Comment (optional)"),
      display = function()
        return (obs.comment and obs.comment ~= "") and obs.comment or nil
      end,
      edit = function(form)
        TextInput.show {
          title = _("Comment"),
          value = obs.comment,
          on_ok = function(text)
            obs.comment = text or ""
            form:refreshItems()
          end,
        }
      end,
    },
    {
      key = "measured_brew_time_sec",
      label = _("Brew time (optional)"),
      display = function()
        return obs.measured_brew_time_sec and Format.duration(obs.measured_brew_time_sec) or nil
      end,
      edit = function(form)
        ListPicker.show {
          title = _("Brew time"),
          items = {
            { text = _("Capture with stopwatch"), value = "capture" },
            { text = _("Enter manually"), value = "manual" },
            { text = _("Clear"), value = "clear" },
          },
          on_select = function(choice)
            if choice == "capture" then
              Nav:push(Stopwatch:new {
                on_capture = function(elapsed, splits)
                  obs.measured_brew_time_sec = elapsed
                  obs.splits_suffix = splits_suffix(splits)
                  form:refreshItems()
                end,
              })
            elseif choice == "manual" then
              DurationInput.show {
                title = _("Brew time"),
                value_sec = obs.measured_brew_time_sec,
                on_ok = function(sec)
                  obs.measured_brew_time_sec = sec
                  obs.splits_suffix = nil
                  form:refreshItems()
                end,
              }
            elseif choice == "clear" then
              obs.measured_brew_time_sec = nil
              obs.splits_suffix = nil
              form:refreshItems()
            end
          end,
        }
      end,
    },
  }

  local function do_save(form)
    local comment = obs.comment or ""
    if obs.splits_suffix then
      comment = (comment ~= "" and (comment .. "\n") or "") .. obs.splits_suffix
    end
    local ok, err = BrewService.record {
      recipe_id = recipe_id,
      session_rating = obs.session_rating,
      measured_brew_time_sec = obs.measured_brew_time_sec,
      comment = comment ~= "" and comment or nil,
    }
    if not ok then
      ConfirmDialog.blocked { text = tostring(err) }
      return
    end
    if opts.on_saved then
      opts.on_saved()
    end
    close(form)
  end

  local screen = FormScreen:new {
    title = opts.title or _("Brew Again"),
    values = obs,
    fields = fields,
    actions = {
      { text = _("Save"), callback = do_save },
      { text = _("Cancel"), callback = close },
    },
  }
  Nav:push(screen)
  return screen
end

BrewAgain._splits_suffix = splits_suffix

return BrewAgain
