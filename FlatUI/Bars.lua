local _, ns = ...

-- Personal resource display, swing timers and cast bars. Each has a frame texture around the
-- bar and a background behind it. Both go, and a backdrop and thin edges replace them.
-- Every Apply below puts Blizzard's art back when its bar is turned off.
-- The fills are flat too: a solid fill on swing timers and resource bars, and on cast bars a
-- texture laid over the game's fill. The chosen bar texture is an image file in place of the solid colour.
-- The names and numbers on the bars are sized and hidden with the font and the alpha of their font strings.

local BAR_BACKGROUND = "UI-HUD-CoolDownManager-Bar-BG"

local seen = setmetatable({}, { __mode = "k" })
local counted = setmetatable({}, { __mode = "k" })

-- Counts a frame for /flatui status once, however many ways it is styled.
local function Count(key, frame)
	if not counted[frame] then
		counted[frame] = true
		ns.Count(key)
	end
end

-- State kept for a Blizzard frame, counted for /flatui status the first time.
local function Own(key, frame)
	local own = seen[frame]
	if not own then
		own = {}
		seen[frame] = own
		Count(key, frame)
	end
	return own
end

-- The image file a bar texture row asks for: nil for the texture of the Flat UI page, false for a solid colour.
local function TextureOf(path)
	local id = ns.Get(path)
	if id == "default" then
		return nil
	end
	return ns.BarTexture(id) or false
end

-- Labels this addon has hidden. The game shows and hides these labels itself and never sets their alpha.
local hiddenLabels = setmetatable({}, { __mode = "k" })

-- Sets the size of a label and hides or shows it. A label is touched for its alpha only while it is
-- hidden here or was. style has the colour of the text (r, g, b) when the row has its own. outline is the id of a text outline row: the game's
-- own flags stay for "game" or none.
local function StyleLabel(key, label, percent, hide, style, outline)
	if label == nil or ns.IsSecret(label) then
		return
	end
	style = style or {}
	style.percent, style.flags = percent, outline and ns.OutlineFlags(outline) or nil
	local styled = ns.TextStyle(label, style)
	if styled == false then
		ns.Note(key, ("%s: the font of a label could not be changed, so it keeps its size."):format(ns.modules[key].label))
	end
	if hide or hiddenLabels[label] then
		ns.SetFaded(label, hide)
		hiddenLabels[label] = hide or nil
	end
end

-- Personal resource display -------------------------------------------------------------------

local gameOffsets = setmetatable({}, { __mode = "k" })
local setOffsets = setmetatable({}, { __mode = "k" })
-- Per bar: the game's colour (gr, gg, gb, ga) and the custom colour set on it (sr, sg, sb).
local colours = setmetatable({}, { __mode = "k" })
-- The bars whose custom colour is on, each with its option, "health" or "power".
local followed = setmetatable({}, { __mode = "k" })
-- Starts or stops the one frame that follows custom colours and cast bars; defined with it below.
local Watch
-- Follows what the game does to the resource display and the swing timers, with no hook on a frame method; defined after the swing timers.
local WatchGame

-- The frame art of each bar is one unnamed background texture.
local function ApplyResourceBar(bar, option)
	local on = ns.Enabled("resource") and ns.Get("resource." .. option)
	if not on and not seen[bar] then
		return
	end
	local outline = ns.Outline(bar, bar)
	local own = Own("resource", bar)
	if own.art == nil then
		own.art = ns.RegionWithAtlas(bar, BAR_BACKGROUND) or false
		if not own.art then
			ns.Note("resource", "Personal resource display: the default frame of a bar was not found and is still shown.")
		end
	end
	ns.SetOutline(outline, on, ns.Get("resource.backdrop"))
	ns.SetFaded(own.art or nil, on)
end

-- The game anchors each lower bar by its TOP to the BOTTOM of the bar above, 4 units down.
-- The default art covered that space. Joined, the two bars share one border.
local function JoinBar(bar, option, above)
	local ok, point, relativeTo, relativePoint, x, y = pcall(bar.GetPoint, bar, 1)
	if not ok or ns.IsSecret(point) or ns.IsSecret(relativeTo) or ns.IsSecret(relativePoint) or ns.IsSecret(x) or ns.IsSecret(y) then
		return
	end
	if point ~= "TOP" or relativePoint ~= "BOTTOM" or relativeTo == nil or type(x) ~= "number" or type(y) ~= "number" then
		return
	end
	if setOffsets[bar] == nil or math.abs(y - setOffsets[bar]) > 0.001 then
		-- Not the offset this addon last set, so the game set it.
		gameOffsets[bar] = y
	end
	-- Joined only when this bar and the one above both have their thin border.
	local join = ns.Enabled("resource") and ns.Get("resource.join") and ns.Get("resource." .. option) and ns.Get("resource." .. above)
	local wanted = join and -ns.Pixels(bar, ns.Get("general.thickness")) or gameOffsets[bar]
	if wanted and math.abs(y - wanted) > 0.001 then
		bar:SetPoint("TOP", relativeTo, "BOTTOM", x, wanted)
		setOffsets[bar] = wanted
	end
end

local function JoinBars(display)
	local power, alt = display.PowerBar, display.AlternatePowerBar
	if power and not ns.Forbidden(power) then
		ns.Each("resource", JoinBar, power, "power", "health")
	end
	if alt and not ns.Forbidden(alt) then
		-- Under the power bar, or under the health bar when the power bar is hidden.
		ns.Each("resource", JoinBar, alt, "alt", display.hidePower == true and "health" or "power")
	end
end

-- The fill is white when flat, and an image file is white too, so the colour the game sets on the bar is
-- the colour seen.
local function ApplyResourceFill(bar)
	if ns.Enabled("resource") and ns.Get("resource.flat") then
		local flat, refused = ns.FlatFill(bar, 1, 1, 1, nil, true, TextureOf("resource.texture"))
		if flat == true then
			Count("resource", bar)
		elseif flat == false then
			ns.Note("resource", refused and "Personal resource display: the game refused a flat fill on a bar, which keeps its default fill."
				or "Personal resource display: the default fill of a bar could not be read and is still shown.")
		end
	elseif ns.RestoreFill(bar) == false then
		ns.Note("resource", "Personal resource display: the game refused to put back the default fill of a bar.")
	end
end

-- The percentage and the amount on a bar. The game sets them with SetText, Show and Hide only.
local RESOURCE_TEXTS = { "TextString", "LeftText", "RightText" }

local function ApplyResourceText(bar)
	local on = ns.Enabled("resource")
	local style
	if on and ns.Get("resource.textOwn") then
		local r, g, b = ns.Colour("resource.textColour")
		style = { r = r, g = g, b = b }
	end
	for _, name in ipairs(RESOURCE_TEXTS) do
		-- The percentage is the left text, the amount the right one and the whole string.
		local part = ns.Get(name == "LeftText" and "resource.percent" or "resource.value")
		local hide = on and not (ns.Get("resource.text") and part)
		StyleLabel("resource", bar[name], on and ns.Get("resource.textSize") or 100, hide, style and { r = style.r, g = style.g, b = style.b },
			on and ns.Get("resource.textOutline") or nil)
	end
end

-- The alternate power bar reads its own fill once while the game sets it up, so it waits for that.
local function FillAlternate(display)
	if ns.Forbidden(display) or display.hasBeenSetup ~= true then
		return
	end
	local bar = display.AlternatePowerBar
	if bar and not ns.Forbidden(bar) then
		ns.Each("resource", ApplyResourceFill, bar)
	end
end

-- Red, green, blue and alpha of a bar's colour, or nil when the game withholds them.
local function ReadColour(bar)
	local ok, r, g, b, a = pcall(bar.GetStatusBarColor, bar)
	if ok and not ns.IsSecret(a) and a == nil then
		a = 1
	end
	if not ok or ns.IsSecret(r) or ns.IsSecret(g) or ns.IsSecret(b) or ns.IsSecret(a)
		or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" or type(a) ~= "number" then
		return nil
	end
	return r, g, b, a
end

local function Near(a, b)
	return math.abs(a - b) < 0.002
end

-- Keeps a custom colour on the health or power bar. The game sets the colour of these bars again
-- now and then, so a colour that is not the custom one is the game's: it is kept, and put back
-- when the custom colour is switched off. option is "health" or "power".
local function FollowColour(bar, option)
	-- Colour health by health left paints the health bar itself (HealthColour.lua).
	if option == "health" and ns.ResourceHealthLeft and ns.ResourceHealthLeft() then
		return
	end
	local own = colours[bar]
	local wanted = ns.Enabled("resource") and ns.Get("resource." .. option .. "Own")
	if not wanted and not (own and own.sr) then
		return
	end
	if not own then
		own = {}
		colours[bar] = own
	end
	local r, g, b, a = ReadColour(bar)
	if r and not (own.sr and Near(r, own.sr) and Near(g, own.sg) and Near(b, own.sb)) then
		own.gr, own.gg, own.gb, own.ga = r, g, b, a
	end
	if wanted then
		local cr, cg, cb = ns.Colour("resource." .. option .. "Colour")
		if not (r and Near(r, cr) and Near(g, cg) and Near(b, cb)) then
			bar:SetStatusBarColor(cr, cg, cb)
		end
		own.sr, own.sg, own.sb = cr, cg, cb
	else
		if own.gr then
			bar:SetStatusBarColor(own.gr, own.gg, own.gb, own.ga)
		end
		own.sr, own.sg, own.sb = nil, nil, nil
	end
end

-- Applies the custom colour of a bar, or puts the game's back. A bar whose custom colour is on
-- is followed every frame.
local function ApplyColour(bar, option)
	local wanted = ns.Enabled("resource") and ns.Get("resource." .. option .. "Own")
	followed[bar] = wanted and type(bar.SetStatusBarColor) == "function" and option or nil
	if followed[bar] or colours[bar] then
		FollowColour(bar, option)
	end
end

-- Runs every frame while a custom colour is on. A bar the game has made forbidden since is dropped.
local function PollColours()
	local dropped
	for bar, option in pairs(followed) do
		local ok, forbidden = pcall(bar.IsForbidden, bar)
		if not ok or ns.IsSecret(forbidden) or forbidden ~= false then
			followed[bar] = nil
			dropped = true
		else
			ns.Each("resource", FollowColour, bar, option)
		end
	end
	if dropped then
		Watch()
	end
end

local function RefreshResource()
	local display = PersonalResourceDisplayFrame
	if display == nil or ns.Forbidden(display) then
		return
	end
	local container = display.HealthBarsContainer
	local bars = {
		{ container and container.healthBar or false, "health" },
		{ display.PowerBar or false, "power" },
		{ display.AlternatePowerBar or false, "alt" },
	}
	for _, entry in ipairs(bars) do
		if entry[1] and not ns.Forbidden(entry[1]) then
			ns.Each("resource", ApplyResourceBar, entry[1], entry[2])
			ns.Each("resource", ApplyResourceText, entry[1])
		end
	end
	JoinBars(display)
	for _, entry in ipairs(bars) do
		local isAlt = entry[2] == "alt"
		if entry[1] and not ns.Forbidden(entry[1]) and (not isAlt or display.hasBeenSetup == true) then
			ns.Each("resource", ApplyResourceFill, entry[1])
			if not isAlt then
				ns.Each("resource", ApplyColour, entry[1], entry[2])
			end
		end
	end
	-- The game sets its own spacing again in Setup, after a change of its settings and when a bar is shown or hidden: a pass on the next frame follows each.
	WatchGame("resource")
	Watch()
	if ns.HealthLeftSync then
		ns.HealthLeftSync()
	end
end

ns.Register("resource", {
	label = "Personal resource display",
	Start = RefreshResource,
	Refresh = RefreshResource,
	Resized = RefreshResource,
})

-- Swing timers --------------------------------------------------------------------------------

-- Blizzard sets the alpha of Border and Background when the target goes in and out of range,
-- so they are hidden instead of faded. Nothing shows them again.
local SWING_TIMERS = {
	{ "SwingTimerMainHandFrame", "main" },
	{ "SwingTimerOffHandFrame", "off" },
	{ "SwingTimerRangedFrame", "ranged" },
}

-- True while the bar of a timer is hidden: out of combat with "combat", or not swinging with "hide". The game sets swingEndTime when a swing starts and clears it when it ends.
local function SwingIdle(timer)
	local mode = ns.Enabled("swing") and ns.Get("swing.idle")
	if mode ~= "hide" and mode ~= "combat" then
		return false
	end
	local ending, editing = timer.swingEndTime, timer.isInEditMode
	if ns.IsSecret(editing) or editing == true then
		return false
	end
	if mode == "combat" then
		local ok, fighting = pcall(UnitAffectingCombat, "player")
		return ok and fighting == false
	end
	return not ns.IsSecret(ending) and ending == nil
end

-- The border switch each timer was applied with, for the hooks that apply it again.
local swingOption = setmetatable({}, { __mode = "k" })

local function ApplySwingTimer(timer, option)
	local bar = timer.StatusBar
	if not bar or ns.Forbidden(bar) then
		return
	end
	swingOption[timer] = option
	local on = ns.Enabled("swing") and ns.Get("swing." .. option)
	local own = seen[timer]
	if not on and not own then
		return
	end
	-- Around the bar, which dims out of range, or around the whole timer. Each outline is made
	-- the first time it is wanted.
	local whole = ns.Get("swing.outline") == "frame"
	local barOutline = (own and own.bar) or (on and not whole and ns.Outline(bar, bar)) or nil
	local wholeOutline = (own and own.whole) or (on and whole and ns.Outline(timer, timer)) or nil
	own = Own("swing", timer)
	own.bar, own.whole = barOutline, wholeOutline
	ns.SetOutline(barOutline, on and not whole, ns.Get("swing.backdrop"))
	ns.SetOutline(wholeOutline, on and whole and not SwingIdle(timer), ns.Get("swing.backdrop"))
	ns.SetHidden(timer.Border, on)
	ns.SetHidden(timer.Background, on)
end

-- Bars whose spark or label shadow this addon has hidden.
local sparksFaded = setmetatable({}, { __mode = "k" })

-- The fill is solid whatever the border switches say. The spark and the label shadow belong to
-- the game's fill, so they are hidden or shown only while the fill is flat.
local function ApplySwingFill(timer, option)
	local bar = timer.StatusBar
	if bar == nil or ns.Forbidden(bar) then
		return
	end
	local on = ns.Enabled("swing") and ns.Get("swing.flat")
	if on then
		local r, g, b
		if ns.Get("swing.classColour") then
			r, g, b = ns.ClassColour()
		end
		if r == nil then
			r, g, b = ns.Colour("swing." .. option .. "Colour")
		end
		-- The atlas the game draws, if the fill does not say.
		local atlas = timer.barTexture
		if ns.IsSecret(atlas) or type(atlas) ~= "string" then
			atlas = nil
		end
		local flat, refused = ns.FlatFill(bar, r, g, b, atlas, nil, TextureOf("swing.texture"))
		if flat == false then
			ns.Note("swing", refused and "Swing timers: the game refused a flat fill on a timer, which keeps its default fill."
				or "Swing timers: the default fill of a timer could not be read and is still shown.")
		end
		on = flat == true
		if on then
			Count("swing", timer)
		end
	elseif ns.RestoreFill(bar) == false then
		ns.Note("swing", "Swing timers: the game refused to put back the default fill of a timer.")
	end
	local hideSpark, hideShadow = on and not ns.Get("swing.spark"), on and not ns.Get("swing.textShadow")
	if hideSpark or hideShadow or sparksFaded[bar] then
		ns.SetFaded(bar.Pip, hideSpark)
		ns.SetFaded(bar.TypeLabelShadow, hideShadow)
		sparksFaded[bar] = (hideSpark or hideShadow) or nil
	end
end

-- The name and the time left of a timer. The game sets their text, colour and shown state, never their font or alpha.
local SWING_TEXTS = { { "TypeLabel", "swing.name" }, { "TimeLabel", "swing.time" } }

local function ApplySwingText(timer)
	local bar = timer.StatusBar
	if bar == nil or ns.Forbidden(bar) then
		return
	end
	local on = ns.Enabled("swing")
	for _, entry in ipairs(SWING_TEXTS) do
		StyleLabel("swing", bar[entry[1]], on and ns.Get("swing.textSize") or 100, on and not ns.Get(entry[2]), nil, on and ns.Get("swing.textOutline") or nil)
	end
end

-- What this addon has set on a timer: alpha (the opacity set while out of range), colour (true while it sets the text colour), reverse, idle.
local swingSet = setmetatable({}, { __mode = "k" })
-- The labels of a timer and the colours the game gives them: white in range, red out of range (Blizzard_SwingTimer.lua:423).
local SWING_LABELS = { "TypeLabel", "TimeLabel" }
local GAME_RANGE_ALPHA = 0.4

-- The game sets isOutOfRange itself and treats a timer in Edit Mode as in range (Blizzard_SwingTimer.lua:367-373).
local function SwingOut(timer)
	local out, editing = timer.isOutOfRange, timer.isInEditMode
	return not ns.IsSecret(out) and out == true and not (not ns.IsSecret(editing) and editing == true)
end

local function GameTextColour(out)
	local colour = out and RED_FONT_COLOR or HIGHLIGHT_FONT_COLOR
	local ok, r, g, b = pcall(function()
		return colour:GetRGB()
	end)
	if ok and not ns.IsSecret(r) and not ns.IsSecret(g) and not ns.IsSecret(b) and type(r) == "number" and type(g) == "number" and type(b) == "number" then
		return r, g, b
	end
	if out then
		return 1, 0.1, 0.1
	end
	return 1, 1, 1
end

-- The opacity of the bar and the colour of the labels while the target is out of range. The game sets both when the range changes, and
-- this runs after it; with the game's own values it makes no call, and puts the game's values back for what it changed.
local function ApplySwingRange(timer)
	local bar = timer.StatusBar
	if bar == nil or ns.Forbidden(bar) then
		return
	end
	local on = ns.Enabled("swing")
	local alpha = on and ns.Get("swing.rangeAlpha") / 100 or GAME_RANGE_ALPHA
	local changed = math.abs(alpha - GAME_RANGE_ALPHA) > 0.0001
	local colour = on and ns.Get("swing.textOwn")
	local set = swingSet[timer]
	if not set and not changed and not colour then
		return
	end
	if not set then
		set = {}
		swingSet[timer] = set
	end
	local out = SwingOut(timer)
	if out then
		if changed or set.alpha then
			pcall(bar.SetAlpha, bar, alpha)
		end
		set.alpha = changed or nil
	else
		-- The game sets the alpha again when the range changes.
		set.alpha = nil
	end
	for _, name in ipairs(SWING_LABELS) do
		local label = bar[name]
		if label ~= nil and not ns.IsSecret(label) then
			if colour then
				pcall(label.SetTextColor, label, ns.Colour(out and "swing.rangeTextColour" or "swing.textColour"))
			elseif set.colour then
				pcall(label.SetTextColor, label, GameTextColour(out))
			end
		end
	end
	set.colour = colour or nil
end

-- The fill from the right, and the spark at the end of the fill.
local function ApplySwingReverse(timer)
	local bar = timer.StatusBar
	if bar == nil or ns.Forbidden(bar) then
		return
	end
	local reverse = ns.Enabled("swing") and ns.Get("swing.reverse") or false
	local set = swingSet[timer]
	if not reverse and not (set and set.reverse) then
		return
	end
	if not set then
		set = {}
		swingSet[timer] = set
	end
	if not pcall(bar.SetReverseFill, bar, reverse) then
		ns.Note("swing", "Swing timers: the game refused to fill a timer from the right, which keeps its direction.")
		return
	end
	set.reverse = reverse or nil
	local pip, fill = bar.Pip, ns.FillRegion(bar)
	if pip ~= nil and fill ~= nil and not ns.IsSecret(pip) then
		local side = reverse and "LEFT" or "RIGHT"
		pcall(pip.ClearAllPoints, pip)
		pcall(pip.SetPoint, pip, side, fill, side, 0, 0)
	end
end

-- The bar of a timer that is not swinging, hidden or shown.
local function ApplySwingIdle(timer)
	local bar = timer.StatusBar
	if bar == nil or ns.Forbidden(bar) then
		return
	end
	local hide = SwingIdle(timer)
	local set = swingSet[timer]
	if hide or (set and set.idle) then
		if not set then
			set = {}
			swingSet[timer] = set
		end
		ns.SetHidden(bar, hide)
		set.idle = hide or nil
	end
end

-- After the game starts, ends or lays out a timer, and sets its range look: what it did is looked at again.
local function SwingLooks(timer)
	ns.Each("swing", ApplySwingTimer, timer, swingOption[timer] or "main")
	ns.Each("swing", ApplySwingIdle, timer)
end

-- Timers whose width Flat UI set, and the ones waiting for the end of a fight.
local swingSized = setmetatable({}, { __mode = "k" })
local swingQueued = setmetatable({}, { __mode = "k" })

-- The width of the personal resource display, or the width Edit Mode has for the timer. Edit Mode sets the width again only for a changed setting
-- (EditModeSystemTemplates.lua:2803-2810), and UpdateSystemSettingWidth lays the frames out again (2765-2769), so the layout value is read and set here.
local function ApplySwingWidth(timer)
	if ns.EditModeOpen() then
		return
	end
	if InCombatLockdown() and ns.MaybeProtected(timer) then
		if not swingQueued[timer] then
			swingQueued[timer] = true
			ns.OutOfCombat(function()
				swingQueued[timer] = nil
				ns.Each("swing", ApplySwingWidth, timer)
			end)
		end
		return
	end
	local width = ns.Enabled("swing") and ns.Get("swing.width") == "resource" and ns.StackWidth and ns.StackWidth(timer) or nil
	if width then
		swingSized[timer] = true
		timer:SetWidth(width)
	elseif swingSized[timer] then
		swingSized[timer] = nil
		local ok, game = pcall(function()
			return timer:GetSettingValue(Enum.EditModeSwingTimerSetting.Width)
		end)
		if ok and ns.Finite(game) and game > 0 then
			timer:SetWidth(game)
		end
	end
end

function ns.SwingWidths()
	for _, entry in ipairs(SWING_TIMERS) do
		local timer = _G[entry[1]]
		if timer ~= nil and not ns.Forbidden(timer) then
			ns.Each("swing", ApplySwingWidth, timer)
		end
	end
end

local function RefreshSwing()
	for _, entry in ipairs(SWING_TIMERS) do
		local timer = _G[entry[1]]
		if timer ~= nil and not ns.Forbidden(timer) then
			ns.Each("swing", ApplySwingWidth, timer)
			ns.Each("swing", ApplySwingTimer, timer, entry[2])
			ns.Each("swing", ApplySwingFill, timer, entry[2])
			ns.Each("swing", ApplySwingText, timer)
			ns.Each("swing", ApplySwingRange, timer)
			ns.Each("swing", ApplySwingReverse, timer)
			ns.Each("swing", ApplySwingIdle, timer)
		end
	end
	-- The game starts, ends and lays out a swing, and sets its range look, with no call that is followed: events, and a look every frame while one is needed.
	WatchGame("swing")
end

ns.Register("swing", { label = "Swing timers", Start = RefreshSwing, Refresh = RefreshSwing })

-- What the game does to these frames is followed without a hook on any of their methods. The game's own calls (UpdatePowerBarAnchor,
-- UpdateAdditionalBarAnchors, ApplyRangePresentation, ClearSwingTimer, ResetSwingTimer) are copies in each frame, so a hook on one is a
-- field written on a game frame. A script hooked with HookScript, an event and the end of Edit Mode say when the game has changed them
-- (Blizzard_PersonalResourceDisplay.lua:124, 713-715, 751-752; Blizzard_SwingTimer.lua:141-161), and the pass runs on the next frame,
-- after the game's code has finished. EllesmereUI hooks the script of a game frame the same way (EllesmereUIResourceBars.lua:11600).
local gameFrame
local gameEvents = false
local gamePolling = false
local passQueued = false
local editing = false
local editWatched = false
local passOwner = {}
local scriptsHooked = setmetatable({}, { __mode = "k" })
-- Per timer: whether its bar was idle when it was last looked at.
local idleSeen = setmetatable({}, { __mode = "k" })

local SWING_EVENTS = { "PLAYER_SWING", "PLAYER_SWING_RANGE_UPDATE", "PLAYER_TARGET_CHANGED", "WEAPON_SLOT_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_IN_COMBAT_CHANGED" }

local function EachTimer(fn)
	for _, entry in ipairs(SWING_TIMERS) do
		local timer = _G[entry[1]]
		if timer ~= nil and not ns.Forbidden(timer) then
			fn(timer)
		end
	end
end

-- A swing setting that is not the game's own needs the timers followed.
local function SwingWanted()
	if not ns.Enabled("swing") then
		return false
	end
	return math.abs(ns.Get("swing.rangeAlpha") / 100 - GAME_RANGE_ALPHA) > 0.0001 or ns.Get("swing.textOwn") or ns.Get("swing.idle") ~= "show"
		or ns.Get("swing.reverse") or false
end

-- True while a timer that hides its idle bar is swinging, so the end of the swing is looked for.
local function SwingInFlight()
	if not ns.Enabled("swing") or ns.Get("swing.idle") ~= "hide" then
		return false
	end
	local found = false
	EachTimer(function(timer)
		local ending = timer.swingEndTime
		if not ns.IsSecret(ending) and ending ~= nil then
			found = true
		end
	end)
	return found
end

local HookBars

-- The layout of the display, and the fill of the alternate bar, after the game's own.
local function ResourcePass()
	local display = PersonalResourceDisplayFrame
	if display ~= nil and scriptsHooked[display] and not ns.Forbidden(display) and not ns.IsStopped("resource") then
		JoinBars(display)
		FillAlternate(display)
		HookBars(display)
	end
end

-- A timer that raises when read counts as not idle.
local function SafeIdle(timer)
	local ok, idle = pcall(SwingIdle, timer)
	return ok and idle
end

-- Idle and range of the timers, which a swing or Edit Mode changes.
local function SwingLight(timer)
	local idle = SafeIdle(timer)
	if idleSeen[timer] ~= idle then
		idleSeen[timer] = idle
		SwingLooks(timer)
	end
	ns.Each("swing", ApplySwingRange, timer)
end

local function SwingFull(timer)
	idleSeen[timer] = SafeIdle(timer)
	SwingLooks(timer)
	ns.Each("swing", ApplySwingRange, timer)
	ns.Each("swing", ApplySwingReverse, timer)
end

local GamePoll

local function PollState()
	local wanted = editing or SwingInFlight()
	if wanted == gamePolling or gameFrame == nil then
		return
	end
	gameFrame:SetScript("OnUpdate", wanted and GamePoll or nil)
	gamePolling = wanted
end

local function RunPass()
	passQueued = false
	ResourcePass()
	-- The cast bar and the swing timers take the width of the display.
	if ns.StackWidths then
		pcall(ns.StackWidths)
	end
	if gameEvents then
		EachTimer(SwingFull)
	end
	PollState()
end

local function QueuePass()
	if passQueued then
		return
	end
	passQueued = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0, RunPass)
	else
		RunPass()
	end
end

-- Every frame while Edit Mode is open (its settings change with no event) and while a swing runs.
function GamePoll()
	if editing then
		ResourcePass()
	end
	if gameEvents then
		EachTimer(SwingLight)
	end
	PollState()
end

local function EditModeIn()
	editing = true
	QueuePass()
	PollState()
end

local function EditModeOut()
	editing = false
	QueuePass()
	PollState()
end

local function HookShown(frame, ...)
	if type(frame) ~= "table" or ns.IsSecret(frame) or ns.Forbidden(frame) or type(frame.HookScript) ~= "function" or scriptsHooked[frame] then
		return
	end
	local ok = true
	for index = 1, select("#", ...) do
		ok = pcall(frame.HookScript, frame, (select(index, ...)), QueuePass) and ok
	end
	scriptsHooked[frame] = ok or nil
end

-- The display's Setup runs once and sets scripts on these two (Blizzard_PersonalResourceDisplay.lua:153-164, 713-715, 751-752), which clears a hook
-- made before it; they are hooked once it has run, from the pass its OnShow queues.
function HookBars(display)
	if display.hasBeenSetup == true then
		HookShown(display.AlternatePowerBar, "OnShow", "OnHide")
		HookShown(display.ClassFrameContainer, "OnShow", "OnHide")
	end
end

-- The pass runs on the events of Edit Mode. The cast bars call this too, so a profile with cast bars on and no swing or resource module follows the display.
function ns.WatchEditModePass()
	if not editWatched and type(EventRegistry) == "table" and not ns.IsSecret(EventRegistry) and type(EventRegistry.RegisterCallback) == "function" then
		editWatched = pcall(function()
			EventRegistry:RegisterCallback("EditMode.Enter", EditModeIn, passOwner)
			EventRegistry:RegisterCallback("EditMode.Exit", EditModeOut, passOwner)
			EventRegistry:RegisterCallback("EditMode.RefreshPersonalResourceDisplay", QueuePass, passOwner)
			EventRegistry:RegisterCallback("EditMode.SavedLayouts", QueuePass, passOwner)
		end)
	end
end

function WatchGame(kind)
	if gameFrame == nil then
		gameFrame = CreateFrame("Frame")
		ns.Own[gameFrame] = true
		gameFrame:SetScript("OnEvent", QueuePass)
	end
	if kind == "resource" then
		local display = PersonalResourceDisplayFrame
		if display ~= nil and not ns.Forbidden(display) then
			HookShown(display, "OnShow")
			HookBars(display)
		end
	elseif not gameEvents and SwingWanted() then
		gameEvents = true
		for _, event in ipairs(SWING_EVENTS) do
			pcall(gameFrame.RegisterEvent, gameFrame, event)
		end
		-- The game's own list has it too (Blizzard_SwingTimer.lua:3-12): a change of attack speed can turn the range check off, which sets the range again.
		pcall(gameFrame.RegisterUnitEvent, gameFrame, "UNIT_ATTACK_SPEED", "player")
	end
	ns.WatchEditModePass()
	PollState()
end

-- Cast bars -----------------------------------------------------------------------------------

-- The target and focus bars can be anchored to the aura rows, where addon frames may not be
-- attached, so their edges are textures of the bar itself.
local CAST_BARS = {
	{ "PlayerCastingBarFrame", "player" },
	{ "OverlayPlayerCastingBarFrame", "player" },
	{ "PetCastingBarFrame", "pet" },
	{ "TargetFrameSpellBar", "target", true },
	{ "FocusFrameSpellBar", "focus", true },
}

-- False when the game refused to anchor an edge, which raises no error.
local function Placed(outline)
	local ok, points = pcall(outline.top.GetNumPoints, outline.top)
	return not ok or ns.IsSecret(points) or type(points) ~= "number" or points > 0
end

-- Per cast bar: its outline, its place (player, pet, target or focus) and what this addon has set on its parts.
local outlineOf = setmetatable({}, { __mode = "k" })
local barOption = setmetatable({}, { __mode = "k" })
local castParts = setmetatable({}, { __mode = "k" })

local function ApplyCastBar(bar, option, direct)
	local on = ns.Enabled("castbars") and ns.Get("castbars." .. option)
	if not on and not seen[bar] then
		return
	end
	-- Nothing is created or anchored on a protected bar in combat, so its default frame stays until the border can be made.
	if not seen[bar] and InCombatLockdown() and ns.MaybeProtected(bar) then
		ns.OutOfCombat(function()
			ns.Each("castbars", ApplyCastBar, bar, option, direct)
		end)
		return
	end
	local outline = ns.Outline(bar, bar, direct)
	outlineOf[bar] = outline
	Own("castbars", bar)
	if on and not Placed(outline) then
		-- No border could be drawn, so the default frame stays.
		ns.Note("castbars", "Cast bars: the game refused a border on one bar, which keeps its default frame.")
		on = false
	end
	ns.SetOutline(outline, on, ns.Get("castbars.backdrop"))
	ns.SetFaded(bar.Border, on)
	ns.SetFaded(bar.Background, on)
	ns.SetFaded(bar.DropShadow, on)
	ns.SetFaded(bar.TextBorder, on and not ns.Get("castbars.textPlate"))
end

-- A number the game gave, or nil for a withheld value or another type.
local function PlainNumber(value)
	if ns.IsSecret(value) or type(value) ~= "number" or value ~= value then
		return nil
	end
	return value
end

-- A part of a cast bar that may not be there.
local function BarPart(bar, name)
	local ok, part = pcall(function()
		return bar[name]
	end)
	if ok and type(part) == "table" and not ns.IsSecret(part) then
		return part
	end
	return nil
end

-- Fades a part while it is hidden here, and puts it back. The game only shows and hides the spark, the shield, the spell name and the icon, and
-- never sets their alpha (CastingBarFrame.lua:680-719, 824-829, 902-919).
local function FadePart(bar, state, name, hide)
	if hide or state[name] then
		ns.SetFaded(BarPart(bar, name), hide)
		state[name] = hide or nil
	end
end

local JUSTIFY = { left = "LEFT", center = "CENTER", right = "RIGHT" }

-- The alignment of the spell name. The game's own is read before it is changed and put back for "As the game has it". The game gives the
-- string a new font object whenever it lays the bar out, so a value that is not the one set here is the game's.
local function AlignText(text, state, wanted)
	local ok, current = pcall(text.GetJustifyH, text)
	if not ok or ns.IsSecret(current) or type(current) ~= "string" then
		return false
	end
	if current ~= state.justSet then
		state.justGame = current
	end
	if wanted then
		if current ~= wanted and not pcall(text.SetJustifyH, text, wanted) then
			return false
		end
		state.justSet = wanted
	elseif state.justSet then
		if current == state.justSet and state.justGame and state.justGame ~= current and not pcall(text.SetJustifyH, text, state.justGame) then
			return false
		end
		state.justSet = nil
	end
	return true
end

-- The colour of the spell name, the same way: the game sets none itself, but a new font object brings its own.
local function ColourText(text, state, wanted)
	local ok, r, g, b, a = pcall(text.GetTextColor, text)
	r, g, b, a = PlainNumber(r), PlainNumber(g), PlainNumber(b), PlainNumber(a)
	if not ok or not (r and g and b and a) then
		return false
	end
	local set = state.colourSet
	local ours = set and Near(r, set[1]) and Near(g, set[2]) and Near(b, set[3])
	if not ours then
		state.colourGame = { r, g, b, a }
	end
	if wanted then
		local cr, cg, cb = ns.Colour("castbars.textColour")
		if not (Near(r, cr) and Near(g, cg) and Near(b, cb)) and not pcall(text.SetTextColor, text, cr, cg, cb, state.colourGame[4]) then
			return false
		end
		state.colourSet = { cr, cg, cb }
	elseif set then
		local game = state.colourGame
		if ours and not pcall(text.SetTextColor, text, game[1], game[2], game[3], game[4]) then
			return false
		end
		state.colourSet = nil
	end
	return true
end

-- The spell name of a cast bar: shown, aligned, coloured. Called again by CastBarSize.lua after the game lays the bar out.
function ns.CastText(bar)
	local on = ns.Enabled("castbars")
	local hide = on and not ns.Get("castbars.textShow")
	local align = on and ns.Get("castbars.textAlign") or "game"
	local colour = on and ns.Get("castbars.textOwn") or false
	local state = castParts[bar]
	if not state and not hide and align == "game" and not colour then
		return
	end
	if not state then
		state = {}
		castParts[bar] = state
	end
	FadePart(bar, state, "Text", hide)
	local text = BarPart(bar, "Text")
	if text and ((JUSTIFY[align] or state.justSet) and AlignText(text, state, JUSTIFY[align]) == false
		or (colour or state.colourSet) and ColourText(text, state, colour) == false) then
		ns.Note("castbars", "Cast bars: the game would not change the alignment or colour of a spell name, which keeps its own.")
	end
end

-- The icon of the target and focus bars: where the game has it, on the right of the bar, or hidden. The game anchors the icon once, in its
-- XML (CastingBarFrame.xml:247-252), and does not anchor it again. The bars hang from protected frames, so the anchor waits for the end of combat.
local function ApplyCastIcon(bar, option)
	if option ~= "target" and option ~= "focus" then
		return
	end
	local state = castParts[bar]
	local on = ns.Enabled("castbars")
	local place = on and ns.Get("castbars.iconPos") or "game"
	local icon = BarPart(bar, "Icon")
	if not icon or (place == "game" and not state) then
		return
	end
	if not state then
		state = {}
		castParts[bar] = state
	end
	FadePart(bar, state, "Icon", place == "hidden")
	local right = place == "right"
	if not right and not state.iconMoved then
		return
	end
	if InCombatLockdown() and ns.MaybeProtected(bar) then
		if not state.iconQueued then
			state.iconQueued = true
			ns.OutOfCombat(function()
				state.iconQueued = nil
				ns.Each("castbars", ApplyCastIcon, bar, option)
			end)
		end
		return
	end
	if right then
		if not state.iconGame then
			local ok, point, relativeTo, relativePoint, x, y = pcall(icon.GetPoint, icon, 1)
			x, y = PlainNumber(x), PlainNumber(y)
			if not ok or not (x and y) or ns.IsSecret(point) or ns.IsSecret(relativePoint) or type(point) ~= "string"
				or type(relativePoint) ~= "string" or ns.IsSecret(relativeTo) then
				ns.Note("castbars", "Cast bars: the place of a spell icon could not be read, so it stays where the game has it.")
				return
			end
			state.iconGame = { point, relativeTo, relativePoint, x, y }
		end
		-- The game's icon is 5 units left of the bar; this one is 5 units right of it.
		if not pcall(function()
			icon:ClearAllPoints()
			icon:SetPoint("LEFT", bar, "RIGHT", 5, 0)
		end) then
			local game = state.iconGame
			if game then
				pcall(function()
					icon:ClearAllPoints()
					icon:SetPoint(game[1], game[2], game[3], game[4], game[5])
				end)
			end
			FadePart(bar, state, "Icon", false)
			ns.Note("castbars", "Cast bars: the game refused to move a spell icon, which stays where the game has it.")
			return
		end
		state.iconMoved = true
	else
		local game = state.iconGame
		if not game or not pcall(function()
			icon:ClearAllPoints()
			icon:SetPoint(game[1], game[2], game[3], game[4], game[5])
		end) then
			ns.Note("castbars", "Cast bars: the game refused to move a spell icon, which stays where the game has it.")
			return
		end
		state.iconMoved = nil
	end
end

-- The parts of a cast bar that have a switch of their own.
local function ApplyCastParts(bar, option)
	barOption[bar] = option
	local state = castParts[bar]
	local on = ns.Enabled("castbars")
	local hideSpark, hideShield = on and not ns.Get("castbars.spark"), on and not ns.Get("castbars.shield")
	if state or hideSpark or hideShield then
		if not state then
			state = {}
			castParts[bar] = state
		end
		FadePart(bar, state, "Spark", hideSpark)
		FadePart(bar, state, "BorderShield", hideShield)
	end
	ns.CastText(bar)
	ApplyCastIcon(bar, option)
end

-- The game draws the fill of a cast bar again on every cast, interrupt and finish, with colours
-- that are part of its art, and sometimes from a name it withholds. So the fill is left alone and
-- a texture of this addon's lies over it, the size of the fill, coloured by what the cast is doing.
-- The state of a cast is read from the atlas the fill draws.
local CAST_STATES = {
	["ui-castingbar-filling-standard"] = "cast",
	["ui-castingbar-full-standard"] = "cast",
	["ui-castingbar-filling-channel"] = "channel",
	["ui-castingbar-full-channel"] = "channel",
	["ui-castingbar-uninterruptable"] = "shield",
	["ui-castingbar-interrupted"] = "interrupted",
	["ui-castingbar-filling-applyingcrafting"] = "craft",
	["ui-castingbar-full-applyingcrafting"] = "craft",
}
local CAST_COLOURS = {
	cast = "castbars.castColour",
	channel = "castbars.channelColour",
	shield = "castbars.shieldColour",
	interrupted = "castbars.interruptedColour",
	craft = "castbars.craftColour",
}

-- Per cast bar: { key = the module it belongs to, on, fill, cover, state, hex, shown, failed, objects, kind }
local casts = setmetatable({}, { __mode = "k" })
-- The records of the bars that are on, which is all the poll visits.
local following = setmetatable({}, { __mode = "k" })
-- Per module, filled again on every poll: whether its bars are followed.
local verdicts = {}

local function Protected(frame)
	local ok, protected = pcall(frame.IsProtected, frame)
	return not ok or ns.IsSecret(protected) or protected == true
end

-- False when the game refused to anchor a texture, which raises no error.
local function Anchored(region)
	local ok, points = pcall(region.GetNumPoints, region)
	if not ok or ns.IsSecret(points) or type(points) ~= "number" then
		return true
	end
	return points > 0
end

-- Makes the cover the first time its bar is shown: the game gives some bars their fill only when
-- they first cast. Returns false when it is not made, and tries again on a later frame unless the
-- game refused it.
local function CastCover(bar, record)
	if record.failed then
		return false
	end
	local fill = ns.FillRegion(bar)
	if not fill or (InCombatLockdown() and Protected(bar)) then
		return false
	end
	-- Set before the calls that can raise, so a bar that fails is not tried every frame.
	record.failed = true
	local layer, sublevel = "ARTWORK", 0
	local ok, drawLayer, drawSublevel = pcall(fill.GetDrawLayer, fill)
	if ok and not ns.IsSecret(drawLayer) and not ns.IsSecret(drawSublevel) and type(drawLayer) == "string" and type(drawSublevel) == "number" then
		layer, sublevel = drawLayer, drawSublevel
	end
	local cover = bar:CreateTexture(nil, layer, nil, math.min(sublevel + 1, 7))
	ns.Own[cover] = true
	cover:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
	cover:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
	cover:Hide()
	if not Anchored(cover) then
		ns.Note(record.key, ("%s: the game refused a fill on one cast bar, which keeps its default fill."):format(ns.modules[record.key].label))
		return false
	end
	record.fill, record.cover, record.failed = fill, cover, nil
	if record.key == "castbars" then
		-- The nameplates count their own plates.
		Count("castbars", bar)
	end
	return true
end

-- True for a plain true, never for a withheld value.
local function IsTrue(value)
	return not ns.IsSecret(value) and value == true
end

-- What the cast on a bar is doing: cast, channel, shield, interrupted, craft, or none for no
-- cover. The state "withheld" comes with the withheld answer that decides it and the state
-- it is when that answer is false.
local function CastState(bar, record)
	local fill = record.fill
	if IsTrue(bar.reverseChanneling) then
		return "none"
	end
	-- A fill that is hidden shows nothing, so nothing is laid over it.
	local shownOk, fillShown = pcall(fill.IsShown, fill)
	if shownOk and not ns.IsSecret(fillShown) and fillShown == false then
		return "none"
	end
	local ok, atlas = pcall(fill.GetAtlas, fill)
	if ok and not ns.IsSecret(atlas) then
		if type(atlas) ~= "string" or atlas == "" then
			return "none"
		end
		return CAST_STATES[atlas:lower()] or "cast"
	end
	-- The name is withheld. The game sets these fields from event names, so they are plain.
	local casting, channeling = bar.casting, bar.channeling
	local spark = bar.Spark
	if not ns.IsSecret(casting) and not ns.IsSecret(channeling) and not casting and not channeling and spark ~= nil then
		-- The game shows the spark again on an interrupt and hides it on a finish.
		local sparkOk, sparkShown = pcall(spark.IsShown, spark)
		if sparkOk and IsTrue(sparkShown) then
			return "interrupted"
		end
	end
	-- The game clears the fields when a cast ends and keeps the bar up while it fades, so the kind of
	-- the cast is kept from the frames in which it was set.
	if IsTrue(channeling) then
		record.kind = "channel"
	elseif IsTrue(casting) then
		record.kind = "cast"
	end
	local otherwise = record.kind or "cast"
	local shield = bar.BorderShield
	if shield ~= nil then
		local shieldOk, shieldShown = pcall(shield.IsShown, shield)
		if shieldOk then
			if ns.IsSecret(shieldShown) then
				return "withheld", shieldShown, otherwise
			elseif shieldShown == true then
				return "shield"
			end
		end
	end
	return otherwise
end

-- The colour of a state of a cast on one bar, and a key that changes with it: the class colour for casts and channels on the player bar, the own
-- colours of the target and focus bars, otherwise the cast colours of the Flat UI page.
local function CastColour(record, state)
	local option = record.key == "castbars" and record.option
	if option == "player" and (state == "cast" or state == "channel") and ns.Get("castbars.playerClass") then
		local r, g, b = ns.ClassColour()
		if r then
			return r, g, b, ("%s,%s,%s"):format(r, g, b)
		end
	elseif (option == "target" or option == "focus") and (state == "cast" or state == "channel") and ns.Get("castbars.targetOwn") then
		local path = state == "cast" and "castbars.targetCast" or "castbars.targetChannel"
		local r, g, b = ns.Colour(path)
		return r, g, b, ns.Get(path)
	end
	local r, g, b = ns.Colour(CAST_COLOURS[state])
	return r, g, b, ns.Get(CAST_COLOURS[state])
end

-- A colour object for SetVertexColorFromBoolean, made again only when the colour changed.
local function ColourObject(record, state)
	local r, g, b, hex = CastColour(record, state)
	record.objects = record.objects or {}
	local object = record.objects[state]
	if not object or object.hex ~= hex then
		object = { hex = hex, colour = CreateColor(r, g, b, 1) }
		record.objects[state] = object
	end
	return object.colour
end

-- The border of a bar in the colour of the cast, or in the Flat UI colour for none.
local function PaintBorder(bar, r, g, b)
	ns.SetOutlineColour(outlineOf[bar], r, g, b)
end

-- The marks of a cast bar of the Cast bars page: the spell icon on the player and pet bars and the latency zone on the player bar. They are
-- textures of the addon's own on the bar, so they hide with it.
local function HideMarks(record)
	if record.marks then
		for _, name in ipairs({ "icon", "latency" }) do
			if record[name] then
				record[name]:Hide()
			end
		end
		record.marks = nil
	end
end

-- A texture of the addon's own on the bar, laid over the cover. Nil while the bar cannot take one yet or when the game refused its anchor.
local function MakeMark(bar, record, name, anchor)
	if record.markFailed or (InCombatLockdown() and Protected(bar)) then
		return nil
	end
	local mark = bar:CreateTexture(nil, "OVERLAY", nil, name == "icon" and 1 or 0)
	ns.Own[mark] = true
	anchor(mark)
	mark:Hide()
	if not Anchored(mark) then
		record.markFailed = true
		ns.Note("castbars", "Cast bars: the game refused a mark on one cast bar, which keeps its default look.")
		return nil
	end
	record[name] = mark
	return mark
end

-- The spell icon and the latency zone for the cast on a bar of the player or the pet. Their numbers come from UnitCastingInfo and
-- UnitChannelInfo, which the game withholds for every unit but the player and the pet (SecretPredicatesDocumentation.lua:110-113), and each is
-- tested before it is used.
local function Marks(bar, record, wantIcon, wantLatency)
	local unit = record.option == "pet" and "pet" or "player"
	local name, _, texture, startMs, endMs = UnitCastingInfo(unit)
	local channel = false
	if not ns.IsSecret(name) and name == nil then
		name, _, texture, startMs, endMs = UnitChannelInfo(unit)
		channel = true
	end
	if ns.IsSecret(name) or name == nil then
		HideMarks(record)
		return
	end
	local width, height = PlainNumber(bar:GetWidth()), PlainNumber(bar:GetHeight())
	local shown = false
	local icon = record.icon
	if wantIcon and not ns.IsSecret(texture) and (type(texture) == "number" or type(texture) == "string") and height and height > 0 then
		icon = icon or MakeMark(bar, record, "icon", function(mark)
			mark:SetPoint("RIGHT", bar, "LEFT", -5, 0)
			mark:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end)
		if icon then
			if record.iconFile ~= texture then
				icon:SetTexture(texture)
				record.iconFile = texture
			end
			if record.iconHeight ~= height then
				icon:SetSize(height, height)
				record.iconHeight = height
			end
			icon:Show()
			shown = true
		end
	elseif icon then
		icon:Hide()
	end
	local latency = record.latency
	startMs, endMs = PlainNumber(startMs), PlainNumber(endMs)
	local world = type(GetNetStats) == "function" and PlainNumber(select(4, GetNetStats())) or nil
	if wantLatency and startMs and endMs and endMs > startMs and world and width and width > 0 then
		local side = channel and "LEFT" or "RIGHT"
		latency = latency or MakeMark(bar, record, "latency", function(mark)
			mark:SetColorTexture(1, 0, 0, 0.6)
			mark:SetPoint("TOP" .. side, bar, "TOP" .. side, 0, 0)
			mark:SetPoint("BOTTOM" .. side, bar, "BOTTOM" .. side, 0, 0)
			record.latencySide = side
		end)
		if latency then
			if record.latencySide ~= side then
				latency:ClearAllPoints()
				latency:SetPoint("TOP" .. side, bar, "TOP" .. side, 0, 0)
				latency:SetPoint("BOTTOM" .. side, bar, "BOTTOM" .. side, 0, 0)
				record.latencySide = side
			end
			local zone = math.min(1, math.max(0, world) / (endMs - startMs)) * width
			if record.latencyWidth ~= zone then
				latency:SetWidth(math.max(zone, 0.01))
				record.latencyWidth = zone
			end
			latency:Show()
			shown = true
		end
	elseif latency then
		latency:Hide()
	end
	record.marks = shown or nil
end

local function PaintMarks(bar, record, state)
	local option = record.key == "castbars" and record.option
	local wantIcon = (option == "player" or option == "pet") and state ~= "interrupted" and ns.Get("castbars.playerIcon")
	local wantLatency = option == "player" and state ~= "interrupted" and ns.Get("castbars.latency")
	if not wantIcon and not wantLatency then
		HideMarks(record)
	elseif ns.PartStopped("castbars", "cast marks") or not ns.EachPart("castbars", "cast marks", Marks, bar, record, wantIcon, wantLatency) then
		HideMarks(record)
	end
end

-- The cover is plain white, or the image file of the chosen bar texture. The colour is a tint on top of
-- either, and is painted again after a change of picture. The bars of the Cast bars and of the nameplates
-- each take the texture row of their own page.
local function CoverArt(record)
	local key = record.key
	local row = key == "castbars" and "castbars.texture" or key == "nameplates" and "nameplates.castTexture" or nil
	local texture = ns.BarTexture(row and ns.Get(row) or nil) or false
	if record.art ~= texture then
		if texture then
			record.cover:SetTexture(texture)
		else
			record.cover:SetColorTexture(1, 1, 1, 1)
		end
		record.art, record.state = texture, nil
	end
end

-- Colours the cover for the state of the cast. The texture is called only when the state or its
-- colour changed.
local function PaintCast(bar, record)
	if not record.cover and not CastCover(bar, record) then
		return
	end
	local cover = record.cover
	CoverArt(record)
	record.option = barOption[bar]
	local state, shield, otherwise = CastState(bar, record)
	if state == "none" then
		if record.shown then
			cover:Hide()
			record.shown, record.state = false, nil
		end
		PaintBorder(bar, nil)
		HideMarks(record)
		return
	end
	if state == "withheld" and not (CreateColor and cover.SetVertexColorFromBoolean) then
		state = otherwise
	end
	if state == "withheld" then
		-- The answer goes to the texture untouched, so it is asked every frame.
		cover:SetVertexColorFromBoolean(shield, ColourObject(record, "shield"), ColourObject(record, otherwise))
		record.state, record.hex = state, nil
		-- The border keeps the Flat UI colour: the colour of the cast is not known.
		PaintBorder(bar, nil)
	else
		local r, g, b, hex = CastColour(record, state)
		if record.state ~= state or record.hex ~= hex then
			cover:SetVertexColor(r, g, b, 1)
			record.state, record.hex = state, hex
		end
		if record.key == "castbars" and ns.Get("castbars.stateBorder") then
			PaintBorder(bar, r, g, b)
		else
			PaintBorder(bar, nil)
		end
	end
	if not record.shown then
		cover:Show()
		record.shown = true
	end
	PaintMarks(bar, record, state)
end

-- A bar that is not shown has no cast. A bar the game has made forbidden since is not read.
local function PollCast(bar, record)
	local ok, forbidden = pcall(bar.IsForbidden, bar)
	if not ok or ns.IsSecret(forbidden) or forbidden ~= false then
		return
	end
	local shown = bar:IsShown()
	-- A withheld answer counts as shown.
	if ns.IsSecret(shown) or shown == true then
		PaintCast(bar, record)
	else
		record.kind = nil
		PaintBorder(bar, nil)
		HideMarks(record)
	end
end

-- The part of a module that stops when its cast bar fills keep failing: the flat fill of the Cast
-- bars, or the cast bar fill among the fills of the nameplates.
local function CastFillPart(key)
	return key == "castbars" and "flat fill" or "cast bar fill"
end

-- Runs every frame while a cast bar wants a flat fill. An error stops the flat fill and not the
-- module the bar belongs to. A bar that fails, or whose module or flat fill has stopped, gets its
-- look back. A flat fill that stops in the middle of a poll gives back the bars after it without a line.
local function PollCasts()
	for key in pairs(verdicts) do
		verdicts[key] = nil
	end
	for bar, record in pairs(following) do
		local key = record.key
		local part = CastFillPart(key)
		local follow = verdicts[key]
		if follow == nil then
			follow = ns.Enabled(key) and not ns.PartStopped(key, part)
			verdicts[key] = follow
		end
		if follow then
			local ok, err = ns.EachPart(key, part, PollCast, bar, record)
			if not ok then
				pcall(ns.CastFill, key, bar, false)
				if err then
					ns.Note(key, ("%s: a flat fill failed on one cast bar, which keeps its default fill. %s"):format(ns.modules[key].label, err))
				end
			end
		else
			pcall(ns.CastFill, key, bar, false)
		end
	end
end

-- A flat fill on one cast bar for the module named by key: nameplate cast bars come here too.
-- The colours are the cast colours on the Flat UI page, whether or not the Cast bars page is switched on.
function ns.CastFill(key, bar, on)
	-- A withheld value raises when it is used as a table key.
	if ns.IsSecret(bar) then
		return
	end
	local record = casts[bar]
	if record == nil and not on then
		return
	end
	local forbidden = ns.Forbidden(bar)
	if record == nil then
		if forbidden or type(bar.GetStatusBarTexture) ~= "function" then
			return
		end
		record = { key = key }
		casts[bar] = record
	end
	on = (on and not forbidden) or false
	local changed = record.on ~= on
	record.key, record.on = key, on
	following[bar] = on and record or nil
	if not on and record.shown and not forbidden then
		record.cover:Hide()
		record.shown, record.state = false, nil
		PaintBorder(bar, nil)
		HideMarks(record)
	end
	if changed then
		Watch()
	end
end

local function ApplyCastFill(bar)
	ns.CastFill("castbars", bar, ns.Enabled("castbars") and ns.Get("castbars.flat") and not ns.PartStopped("castbars", "flat fill"))
end

local function RefreshCastBars()
	for _, entry in ipairs(CAST_BARS) do
		local bar = _G[entry[1]]
		if bar ~= nil and not ns.Forbidden(bar) then
			ns.Each("castbars", ApplyCastBar, bar, entry[2], entry[3])
			ns.Each("castbars", ApplyCastParts, bar, entry[2])
			ns.Each("castbars", ApplyCastFill, bar)
		end
	end
	if ns.CastBarSizes then ns.CastBarSizes() end
	if ns.CastTimeSync then ns.CastTimeSync() end
end

ns.Register("castbars", { label = "Cast bars", Start = RefreshCastBars, Refresh = RefreshCastBars })

-- One frame follows the cast bars and the custom colours of the resource bars, only while one
-- of them is wanted.
local pollFrame
local polling = false

local function Poll()
	PollCasts()
	PollColours()
end

function Watch()
	local wanted = next(followed) ~= nil or next(following) ~= nil
	if wanted == polling then
		return
	end
	if not pollFrame then
		pollFrame = CreateFrame("Frame")
		ns.Own[pollFrame] = true
	end
	pollFrame:SetScript("OnUpdate", wanted and Poll or nil)
	polling = wanted
end
