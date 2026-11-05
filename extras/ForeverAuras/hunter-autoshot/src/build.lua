-- Builds the ForeverAuras transmit table. Globals from the host: BUILDDIR, read(path).
local function code(name) return read(BUILDDIR .. "/" .. name) end

local GROUP = "Hunter Auto Shot + Range"
local BAR, RANGE, CLIPS = "Hunter - Auto Shot", "Hunter - Range", "Hunter - Clip Counter"
local INTERNAL = 91

local hunterLoad = {
  use_class = true, class = { single = "HUNTER", multi = { HUNTER = true } },
  use_never = false, size = { multi = {} }, talent = { multi = {} }, spec = { multi = {} },
}

local function customTrigger(events, fn, vars)
  return {
    triggers = {
      { trigger = { type = "custom", custom_type = "stateupdate", check = "event", events = events,
                    custom = fn, customVariables = vars, debuffType = "HELPFUL", unit = "player" },
        untrigger = {} },
      activeTriggerMode = -10, disjunctive = "any",
    },
  }
end

local function base(id, uid, regionType, x, y)
  return { id = id, uid = uid, parent = GROUP, regionType = regionType, internalVersion = INTERNAL,
           anchorFrameType = "SCREEN", anchorPoint = "CENTER", selfPoint = "CENTER", xOffset = x, yOffset = y,
           frameStrata = 1, load = hunterLoad, information = {}, authorOptions = {}, config = {},
           animation = { start = { type = "none", duration_type = "seconds", easeType = "none", easeStrength = 3 },
                         main = { type = "none", duration_type = "seconds", easeType = "none", easeStrength = 3 },
                         finish = { type = "none", duration_type = "seconds", easeType = "none", easeStrength = 3 } } }
end

local function merge(a, b) for k, v in pairs(b) do a[k] = v end return a end

-- 1. Auto Shot bar.
local bar = merge(base(BAR, "hAsBar0001x", "aurabar", 0, 0), customTrigger(
  "PLAYER_SWING, START_AUTOREPEAT_SPELL, STOP_AUTOREPEAT_SPELL, PLAYER_ENTERING_WORLD, PLAYER_REGEN_DISABLED, FRAME_UPDATE, "
  .. "UNIT_SPELLCAST_SUCCEEDED:player, UNIT_SPELLCAST_START:player, UNIT_SPELLCAST_STOP:player, UNIT_SPELLCAST_FAILED:player, "
  .. "UNIT_SPELLCAST_INTERRUPTED:player, UNIT_SPELLCAST_CHANNEL_START:player, UNIT_SPELLCAST_CHANNEL_STOP:player",
  code("autoshot_trigger.lua"),
  '{ clipping = "bool", moving = "bool", windup = "bool", flash = "bool", stacks = true }'))
merge(bar, {
  width = 220, height = 18, orientation = "HORIZONTAL", inverse = true,
  texture = "Blizzard", textureSource = "LSM",
  barColor = { 0.15, 0.65, 1, 1 }, barColor2 = { 1, 1, 0, 1 }, enableGradient = false,
  backgroundColor = { 0, 0, 0, 0.6 },
  icon = true, icon_side = "LEFT", iconSource = -1, icon_color = { 1, 1, 1, 1 }, zoom = 0.3, desaturate = false,
  spark = true, sparkWidth = 8, sparkHeight = 26, sparkColor = { 1, 1, 1, 1 }, sparkBlendMode = "ADD",
  sparkTexture = "Interface\\CastingBar\\UI-CastingBar-Spark", sparkHidden = "BOTH",
  sparkOffsetX = 0, sparkOffsetY = 0, sparkRotationMode = "AUTO", sparkRotation = 0,
  alpha = 1,
  subRegions = {
    { type = "subbackground" },
    { type = "subtext", text_text = "%n", anchor_point = "INNER_LEFT", text_justify = "LEFT",
      text_fontSize = 12, text_fontType = "OUTLINE", text_color = { 1, 1, 1, 1 }, text_visible = true,
      text_selfPoint = "AUTO", anchorXOffset = 0, anchorYOffset = 0, text_shadowXOffset = 0, text_shadowYOffset = 0 },
    { type = "subtext", text_text = "%p", anchor_point = "INNER_RIGHT", text_justify = "RIGHT",
      text_fontSize = 12, text_fontType = "OUTLINE", text_color = { 1, 1, 1, 1 }, text_visible = true,
      text_selfPoint = "AUTO", anchorXOffset = 0, anchorYOffset = 0, text_shadowXOffset = 0, text_shadowYOffset = 0,
      text_text_format_p_format = "timed", text_text_format_p_time_precision = 1, text_text_format_p_time_dynamic_threshold = 60 },
    { type = "subborder", border_visible = true, border_edge = "Square Full White", border_color = { 0, 0, 0, 1 },
      border_size = 1, border_offset = 1 },
  },
  -- Later conditions win: wind-up yellow, moving orange, clipping and a clip red.
  conditions = {
    { check = { trigger = 1, variable = "windup", value = 1 }, changes = { { property = "barColor", value = { 1, 0.85, 0.1, 1 } } } },
    { check = { trigger = 1, variable = "moving", value = 1 }, changes = { { property = "barColor", value = { 1, 0.5, 0, 1 } } } },
    { check = { trigger = 1, variable = "clipping", value = 1 }, changes = { { property = "barColor", value = { 1, 0.1, 0.1, 1 } } } },
    { check = { trigger = 1, variable = "flash", value = 1 }, changes = { { property = "barColor", value = { 1, 0.1, 0.1, 1 } } } },
  },
  actions = { init = { do_custom = true, custom = code("autoshot_init.lua") }, start = {}, finish = {} },
})

-- 2. Range text, above the bar.
local range = merge(base(RANGE, "hAsRange01x", "text", 0, 24), customTrigger(
  "PLAYER_TARGET_CHANGED, PLAYER_SWING_RANGE_UPDATE, PLAYER_ENTERING_WORLD, FRAME_UPDATE",
  code("range_trigger.lua"), '{ zone = { type = "number" } }'))
merge(range, {
  displayText = "%n", font = "Friz Quadrata TT", fontSize = 16, outline = "OUTLINE", justify = "CENTER",
  color = { 1, 1, 1, 1 }, automaticWidth = "Auto", fixedWidth = 200, wordWrap = "WordWrap",
  shadowColor = { 0, 0, 0, 1 }, shadowXOffset = 1, shadowYOffset = -1, customTextUpdate = "event", alpha = 1,
  subRegions = {}, conditions = {},
  actions = { init = { do_custom = true, custom = code("range_init.lua") }, start = {}, finish = {} },
})

-- 3. Clips this fight, below the bar.
local clips = merge(base(CLIPS, "hAsClips01x", "text", 0, -22), customTrigger(
  "FA_HUNTER_CLIPS", code("clips_trigger.lua"), "{ stacks = true }"))
merge(clips, {
  displayText = "%n", font = "Friz Quadrata TT", fontSize = 11, outline = "OUTLINE", justify = "CENTER",
  color = { 0.85, 0.85, 0.85, 1 }, automaticWidth = "Auto", fixedWidth = 200, wordWrap = "WordWrap",
  shadowColor = { 0, 0, 0, 1 }, shadowXOffset = 1, shadowYOffset = -1, customTextUpdate = "event", alpha = 1,
  subRegions = {},
  conditions = {
    { check = { trigger = 1, variable = "stacks", op = ">", value = "0" }, changes = { { property = "color", value = { 1, 0.4, 0.4, 1 } } } },
  },
  actions = { start = {}, finish = {}, init = {} },
})

local group = {
  id = GROUP, uid = "hAsGroup01x", regionType = "group", internalVersion = INTERNAL,
  controlledChildren = { BAR, RANGE, CLIPS },
  anchorFrameType = "SCREEN", anchorPoint = "CENTER", selfPoint = "CENTER", xOffset = 0, yOffset = -200,
  frameStrata = 1, border = false, borderEdge = "Square Full White", borderOffset = 4, borderInset = 1, borderSize = 2,
  borderColor = { 0, 0, 0, 1 }, backdropColor = { 1, 1, 1, 0.5 }, scale = 1, alpha = 1,
  load = { size = { multi = {} }, talent = { multi = {} }, spec = { multi = {} }, class = { multi = {} } },
  triggers = { { trigger = { type = "aura2", unit = "player", debuffType = "HELPFUL" }, untrigger = {} } },
  conditions = {}, subRegions = {}, information = {}, authorOptions = {}, config = {}, actions = { start = {}, finish = {}, init = {} },
  animation = bar.animation,
  desc = "Auto Shot timer with clip detection (bar turns yellow in the 0.5 s wind-up, orange while you move in it, red when a cast will clip or just clipped), a range indicator (melee / dead zone / in range / out of range), and a clip counter for the current fight.",
}

local transmit = { m = "d", d = group, v = 2000, s = "1.1.0", c = { bar, range, clips } }

return transmit
