local _, ns = ...

local BAR_BACKGROUND = "UI-HUD-CoolDownManager-Bar-BG"

local seen = setmetatable({}, { __mode = "k" })
local counted = setmetatable({}, { __mode = "k" })

local function Count(key, frame)
	if not counted[frame] then
		counted[frame] = true
		ns.Count(key)
	end
end

local function Own(key, frame)
	local own = seen[frame]
	if not own then
		own = {}
		seen[frame] = own
		Count(key, frame)
	end
	return own
end

local function TextureOf(path)
	local id = ns.Get(path)
	if id == "default" then
		return nil
	end
	return ns.BarTexture(id) or false
end

local hiddenLabels = setmetatable({}, { __mode = "k" })

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

local gameOffsets = setmetatable({}, { __mode = "k" })
local setOffsets = setmetatable({}, { __mode = "k" })
local colours = setmetatable({}, { __mode = "k" })
local followed = setmetatable({}, { __mode = "k" })
local Watch
local WatchGame

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

local function JoinBar(bar, option, above)
	local ok, point, relativeTo, relativePoint, x, y = pcall(bar.GetPoint, bar, 1)
	if not ok or ns.IsSecret(point) or ns.IsSecret(relativeTo) or ns.IsSecret(relativePoint) or ns.IsSecret(x) or ns.IsSecret(y) then
		return
	end
	if point ~= "TOP" or relativePoint ~= "BOTTOM" or relativeTo == nil or type(x) ~= "number" or type(y) ~= "number" then
		return
	end
	if setOffsets[bar] == nil or math.abs(y - setOffsets[bar]) > 0.001 then
		gameOffsets[bar] = y
	end
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
		ns.Each("resource", JoinBar, alt, "alt", display.hidePower == true and "health" or "power")
	end
end

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

local RESOURCE_TEXTS = { "TextString", "LeftText", "RightText" }

local function ApplyResourceText(bar)
	local on = ns.Enabled("resource")
	local style
	if on and ns.Get("resource.textOwn") then
		local r, g, b = ns.Colour("resource.textColour")
		style = { r = r, g = g, b = b }
	end
	for _, name in ipairs(RESOURCE_TEXTS) do
		local part = ns.Get(name == "LeftText" and "resource.percent" or "resource.value")
		local hide = on and not (ns.Get("resource.text") and part)
		StyleLabel("resource", bar[name], on and ns.Get("resource.textSize") or 100, hide, style and { r = style.r, g = style.g, b = style.b },
			on and ns.Get("resource.textOutline") or nil)
	end
end

local function FillAlternate(display)
	if ns.Forbidden(display) or display.hasBeenSetup ~= true then
		return
	end
	local bar = display.AlternatePowerBar
	if bar and not ns.Forbidden(bar) then
		ns.Each("resource", ApplyResourceFill, bar)
	end
end

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

local CLASS_NOTE = "Personal resource display: the game withholds your class here, so Class colour is not used."

local function ChosenColour(option)
	if not ns.Enabled("resource") then
		return nil
	end
	if option == "health" then
		local wanted, r, g, b = ns.Get("resource.healthClass"), nil, nil, nil
		if wanted then
			r, g, b = ns.ClassColour()
		end
		if wanted and not r then
			ns.Note("resource", CLASS_NOTE)
		else
			ns.ClearNote("resource", CLASS_NOTE)
		end
		if r then
			return r, g, b
		end
	end
	if ns.Get("resource." .. option .. "Own") then
		return ns.Colour("resource." .. option .. "Colour")
	end
	return nil
end

local function FollowColour(bar, option)
	if option == "health" and ns.ResourceHealthLeft and ns.ResourceHealthLeft() then
		return
	end
	local own = colours[bar]
	local cr, cg, cb = ChosenColour(option)
	local wanted = cr ~= nil
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

local function ApplyColour(bar, option)
	local wanted = ChosenColour(option) ~= nil
	followed[bar] = wanted and type(bar.SetStatusBarColor) == "function" and option or nil
	if followed[bar] or colours[bar] then
		FollowColour(bar, option)
	end
end

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

local SWING_TIMERS = {
	{ "SwingTimerMainHandFrame", "main" },
	{ "SwingTimerOffHandFrame", "off" },
	{ "SwingTimerRangedFrame", "ranged" },
}

local SWING_GRACE, SWING_FADE = 0.4, 0.25
local idleSince, swingFaded = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })

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
	if ns.IsSecret(ending) then
		return false
	elseif ending ~= nil then
		idleSince[timer] = nil
		return false
	end
	local now, since = GetTime(), idleSince[timer]
	if since == nil or since > now then
		idleSince[timer] = now
		return false
	end
	return now - since >= SWING_GRACE + SWING_FADE
end

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

local sparksFaded = setmetatable({}, { __mode = "k" })

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

local swingSet = setmetatable({}, { __mode = "k" })
local SWING_LABELS = { "TypeLabel", "TimeLabel" }
local GAME_RANGE_ALPHA = 0.4

local function SwingOut(timer)
	local out, editing, swinging = timer.isOutOfRange, timer.isInEditMode, timer.swingDuration
	if ns.IsSecret(out) or out ~= true or ns.IsSecret(editing) or editing == true then
		return false
	end
	return not ns.IsSecret(swinging) and swinging == nil
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

local function SwingFadeStep(timer)
	local bar = timer.StatusBar
	if bar == nil or ns.Forbidden(bar) then
		return
	end
	local ending, editing, since = timer.swingEndTime, timer.isInEditMode, idleSince[timer]
	local swinging = ns.IsSecret(ending) or ending ~= nil
	local left
	if not swinging and since ~= nil and not (ns.IsSecret(editing) or editing == true) and ns.Enabled("swing") and ns.Get("swing.idle") == "hide" then
		local t = GetTime() - since - SWING_GRACE
		if t >= 0 and t < SWING_FADE then
			left = 1 - t / SWING_FADE
		end
	end
	local base = swingFaded[timer]
	if left then
		if base == nil then
			local ok, alpha = pcall(bar.GetAlpha, bar)
			base = ok and ns.Finite(alpha) and alpha or 1
			swingFaded[timer] = base
		end
		pcall(bar.SetAlpha, bar, base * left)
	elseif base ~= nil then
		swingFaded[timer] = nil
		if not swinging then
			pcall(bar.SetAlpha, bar, base)
		end
	end
end

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
	SwingFadeStep(timer)
end

local AUTO_SHOT_AIM = 0.5
local AUTO_SHOT_ALPHA = 0.5
local autoBands = setmetatable({}, { __mode = "k" })

local function RangedSwing(timer)
	local duration = timer.swingDuration
	if ns.Finite(duration) and duration > 0 then
		return duration
	end
	if type(UnitAttackSpeed) == "function" then
		local ok, _, _, ranged = pcall(UnitAttackSpeed, "player")
		if ok and ns.Finite(ranged) and ranged > 0 then
			return ranged
		end
	end
	return nil
end

local function ApplyAutoShot(timer, option)
	if option ~= "ranged" then
		return
	end
	local bar = timer.StatusBar
	if bar == nil or ns.Forbidden(bar) then
		return
	end
	local band = autoBands[timer]
	local duration, width
	if ns.Enabled("swing") and ns.Get("swing.autoShot") then
		duration = RangedSwing(timer)
		local ok, w = pcall(bar.GetWidth, bar)
		width = ok and ns.Finite(w) and w > 0 and w or nil
	end
	if not (duration and width) then
		if band then
			band:Hide()
		end
		return
	end
	if band == nil then
		band = bar:CreateTexture(nil, "ARTWORK", nil, 7)
		ns.Own[band] = true
		autoBands[timer] = band
	end
	local r, g, b = ns.Colour("swing.autoShotColour")
	band:SetColorTexture(r, g, b, AUTO_SHOT_ALPHA)
	local side = ns.Get("swing.reverse") and "LEFT" or "RIGHT"
	band:ClearAllPoints()
	band:SetPoint("TOP" .. side, bar, "TOP" .. side, 0, 0)
	band:SetPoint("BOTTOM" .. side, bar, "BOTTOM" .. side, 0, 0)
	band:SetWidth(width * math.min(1, AUTO_SHOT_AIM / duration))
	band:Show()
end

local Q = {}
do
	local SPELLS = { 78, 845, 6807, 2973 }
	local CLASSES = { WARRIOR = true, DRUID = true, HUNTER = true }
	local EVENTS = { "CURRENT_SPELL_CAST_CHANGED", "ACTIONBAR_UPDATE_STATE", "PLAYER_SWING", "PLAYER_REGEN_ENABLED" }
	local state = { frame = nil, hearing = false, pending = false, names = nil, covers = setmetatable({}, { __mode = "k" }) }

	function Q.Wanted()
		if not (ns.Enabled("swing") and ns.Get("swing.queued") == true) or type(UnitClassBase) ~= "function" then
			return false
		end
		local ok, class = pcall(UnitClassBase, "player")
		return ok and not ns.IsSecret(class) and type(class) == "string" and CLASSES[class] == true
	end

	local function Names()
		if state.names then
			return state.names
		end
		if type(C_Spell) ~= "table" or type(C_Spell.GetSpellName) ~= "function" then
			return nil
		end
		local names = {}
		for _, id in ipairs(SPELLS) do
			local ok, name = pcall(C_Spell.GetSpellName, id)
			if ok and not ns.IsSecret(name) and type(name) == "string" and name ~= "" then
				names[#names + 1] = name
			end
		end
		if #names == #SPELLS then
			state.names = names
		end
		return names
	end

	local function Waiting()
		local ask = type(C_Spell) == "table" and C_Spell.IsCurrentSpell or nil
		local names = Names()
		if type(ask) ~= "function" or not names then
			return false
		end
		for _, name in ipairs(names) do
			local ok, current = pcall(ask, name)
			if ok and not ns.IsSecret(current) and current == true then
				return true
			end
		end
		return false
	end

	local function Cover(timer)
		local cover = state.covers[timer]
		if cover == false then
			return nil
		end
		local bar = timer.StatusBar
		local fill = bar ~= nil and not ns.Forbidden(bar) and ns.FillRegion(bar) or nil
		if not fill or (cover and cover.region == fill) or (InCombatLockdown() and ns.MaybeProtected(bar)) then
			return cover
		end
		if not cover then
			state.covers[timer] = false
			local tex = bar:CreateTexture(nil, "ARTWORK", nil, 6)
			ns.Own[tex] = true
			tex:Hide()
			cover = { tex = tex }
		end
		cover.tex:ClearAllPoints()
		cover.tex:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
		cover.tex:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
		cover.region = fill
		state.covers[timer] = cover
		return cover
	end

	local function Paint(cover)
		local file = TextureOf("swing.texture")
		if file == nil then
			file = ns.BarTexture()
		end
		local r, g, b = ns.Colour("swing.queuedColour")
		local key = ("%s|%s|%s|%s"):format(tostring(file), r, g, b)
		if cover.key ~= key then
			if file then
				cover.tex:SetTexture(file)
			else
				cover.tex:SetColorTexture(1, 1, 1, 1)
			end
			cover.tex:SetVertexColor(r, g, b, 1)
			cover.key = key
		end
	end

	function Q.Apply(timer, option)
		if option ~= "main" then
			return
		end
		local cover = state.covers[timer]
		if not Q.Wanted() then
			if cover then
				cover.tex:Hide()
			end
			return
		end
		cover = Cover(timer)
		if cover then
			Paint(cover)
			cover.tex:SetShown(Waiting())
		end
	end

	local function Look()
		state.pending = false
		local timer = _G.SwingTimerMainHandFrame
		if timer ~= nil and not ns.IsSecret(timer) and not ns.Forbidden(timer) then
			ns.Each("swing", Q.Apply, timer, "main")
		end
	end

	local function Heard()
		if state.pending then
			return
		end
		state.pending = true
		if C_Timer and C_Timer.After then
			C_Timer.After(0, Look)
		else
			Look()
		end
	end

	function Q.Hear(on)
		if on == state.hearing then
			return
		end
		if on and not state.frame then
			state.frame = CreateFrame("Frame")
			ns.Own[state.frame] = true
			state.frame:SetScript("OnEvent", Heard)
		end
		if state.frame then
			for _, event in ipairs(EVENTS) do
				pcall(on and state.frame.RegisterEvent or state.frame.UnregisterEvent, state.frame, event)
			end
		end
		state.hearing = on
	end
end

local function SwingLooks(timer)
	ns.Each("swing", ApplySwingTimer, timer, swingOption[timer] or "main")
	ns.Each("swing", ApplySwingIdle, timer)
end

local swingSized = setmetatable({}, { __mode = "k" })
local swingQueued = setmetatable({}, { __mode = "k" })

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
			ns.Each("swing", ApplyAutoShot, timer, entry[2])
			ns.Each("swing", Q.Apply, timer, entry[2])
		end
	end
	Q.Hear(Q.Wanted())
	WatchGame("swing")
end

ns.Register("swing", { label = "Swing timers", Start = RefreshSwing, Refresh = RefreshSwing })

local gameFrame
local gameEvents = false
local gamePolling = false
local passQueued = false
local editing = false
local editWatched = false
local passOwner = {}
local scriptsHooked = setmetatable({}, { __mode = "k" })
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

local function SwingWanted()
	if not ns.Enabled("swing") then
		return false
	end
	return math.abs(ns.Get("swing.rangeAlpha") / 100 - GAME_RANGE_ALPHA) > 0.0001 or ns.Get("swing.textOwn") or ns.Get("swing.idle") ~= "show"
		or ns.Get("swing.reverse") or false
end

local AUTO_SHOT_EVENTS = { "PLAYER_SWING", "WEAPON_SLOT_CHANGED", "PLAYER_ENTERING_WORLD" }
local autoFrame
local autoEvents = false
local autoQueued = false

local function AutoShotWanted()
	return ns.Enabled("swing") and ns.Get("swing.autoShot") == true
end

local function AutoShotPass()
	autoQueued = false
	if gameEvents then
		return
	end
	EachTimer(function(timer)
		ns.Each("swing", ApplyAutoShot, timer, swingOption[timer])
	end)
end

local function AutoShotEvent(_, event, ...)
	if event == "PLAYER_SWING" then
		local _, swingType = ...
		local ranged = Enum and Enum.PlayerSwingType and Enum.PlayerSwingType.Ranged
		if ranged ~= nil and not ns.IsSecret(swingType) and swingType ~= ranged then
			return
		end
	end
	if autoQueued then
		return
	end
	autoQueued = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0, AutoShotPass)
	else
		AutoShotPass()
	end
end

local function SwingInFlight()
	if not ns.Enabled("swing") then
		return false
	end
	if ns.Get("swing.idle") ~= "hide" and not ns.Get("swing.textOwn") and math.abs(ns.Get("swing.rangeAlpha") / 100 - GAME_RANGE_ALPHA) <= 0.0001 then
		return false
	end
	local found, hide, now = false, ns.Get("swing.idle") == "hide", GetTime()
	EachTimer(function(timer)
		local ending, since = timer.swingEndTime, idleSince[timer]
		if (not ns.IsSecret(ending) and ending ~= nil) or (hide and since ~= nil and now >= since and now - since < SWING_GRACE + SWING_FADE) then
			found = true
		end
	end)
	return found
end

local HookBars

local function ResourcePass()
	local display = PersonalResourceDisplayFrame
	if display ~= nil and scriptsHooked[display] and not ns.Forbidden(display) and not ns.IsStopped("resource") then
		JoinBars(display)
		FillAlternate(display)
		HookBars(display)
	end
end

local function SafeIdle(timer)
	local ok, idle = pcall(SwingIdle, timer)
	return ok and idle
end

local function SwingLight(timer)
	local idle = SafeIdle(timer)
	if idleSeen[timer] ~= idle then
		idleSeen[timer] = idle
		SwingLooks(timer)
	end
	ns.Each("swing", ApplySwingRange, timer)
	ns.Each("swing", SwingFadeStep, timer)
end

local function SwingFull(timer)
	idleSeen[timer] = SafeIdle(timer)
	SwingLooks(timer)
	ns.Each("swing", ApplySwingRange, timer)
	ns.Each("swing", ApplySwingReverse, timer)
	ns.Each("swing", ApplyAutoShot, timer, swingOption[timer])
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

function HookBars(display)
	if display.hasBeenSetup == true then
		HookShown(display.AlternatePowerBar, "OnShow", "OnHide")
		HookShown(display.ClassFrameContainer, "OnShow", "OnHide")
	end
end

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
		pcall(gameFrame.RegisterUnitEvent, gameFrame, "UNIT_ATTACK_SPEED", "player")
		pcall(gameFrame.RegisterUnitEvent, gameFrame, "UNIT_INVENTORY_CHANGED", "player")
		if autoEvents then
			autoEvents = false
			pcall(autoFrame.UnregisterAllEvents, autoFrame)
		end
	elseif kind == "swing" and not gameEvents and not autoEvents and AutoShotWanted() then
		autoEvents = true
		if autoFrame == nil then
			autoFrame = CreateFrame("Frame")
			ns.Own[autoFrame] = true
			autoFrame:SetScript("OnEvent", AutoShotEvent)
		end
		for _, event in ipairs(AUTO_SHOT_EVENTS) do
			pcall(autoFrame.RegisterEvent, autoFrame, event)
		end
		pcall(autoFrame.RegisterUnitEvent, autoFrame, "UNIT_ATTACK_SPEED", "player")
	end
	ns.WatchEditModePass()
	PollState()
end

local CAST_BARS = {
	{ "PlayerCastingBarFrame", "player" },
	{ "OverlayPlayerCastingBarFrame", "player" },
	{ "PetCastingBarFrame", "pet" },
	{ "TargetFrameSpellBar", "target", true },
	{ "FocusFrameSpellBar", "focus", true },
}

local function Placed(outline)
	local ok, points = pcall(outline.top.GetNumPoints, outline.top)
	return not ok or ns.IsSecret(points) or type(points) ~= "number" or points > 0
end

local outlineOf = setmetatable({}, { __mode = "k" })
local barOption = setmetatable({}, { __mode = "k" })
local castParts = setmetatable({}, { __mode = "k" })

local function ApplyCastBar(bar, option, direct)
	local on = ns.Enabled("castbars") and ns.Get("castbars." .. option)
	if not on and not seen[bar] then
		return
	end
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
		ns.Note("castbars", "Cast bars: the game refused a border on one bar, which keeps its default frame.")
		on = false
	end
	ns.SetOutline(outline, on, ns.Get("castbars.backdrop"))
	ns.SetFaded(bar.Border, on)
	ns.SetFaded(bar.Background, on)
	ns.SetFaded(bar.DropShadow, on)
	ns.SetFaded(bar.TextBorder, on and not ns.Get("castbars.textPlate"))
end

local function PlainNumber(value)
	if ns.IsSecret(value) or type(value) ~= "number" or value ~= value then
		return nil
	end
	return value
end

local function BarPart(bar, name)
	local ok, part = pcall(function()
		return bar[name]
	end)
	if ok and type(part) == "table" and not ns.IsSecret(part) then
		return part
	end
	return nil
end

local function FadePart(bar, state, name, hide)
	if hide or state[name] then
		ns.SetFaded(BarPart(bar, name), hide)
		state[name] = hide or nil
	end
end

local JUSTIFY = { left = "LEFT", center = "CENTER", right = "RIGHT" }

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

local iconTold = false
local function ApplyCastIcon(bar, option)
	if option == "player" or option == "pet" then
		local hide = ns.Enabled("castbars") and ns.Get("castbars.playerIcon") == true and not ns.PartStopped("castbars", "cast marks")
			and not (ns.Get("castbars.flat") == true and ns.PartStopped("castbars", "flat fill"))
		local state = castParts[bar]
		if hide or (state and state.Icon) then
			if not state then
				state = {}
				castParts[bar] = state
			end
			FadePart(bar, state, "Icon", hide)
		end
		return
	end
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
				iconTold = false
				ns.Each("castbars", ApplyCastIcon, bar, option)
			end)
		end
		if not iconTold and place ~= "hidden" and right ~= (state.iconMoved == true) and type(ns.PanelShown) == "function" and ns.PanelShown() == true then
			iconTold = true
			print("Flat UI: the target and focus bar icons move when the fight ends.")
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
function ns.CastBarInterrupted(bar)
	if ns.IsSecret(bar) or ns.Forbidden(bar) then
		return false
	end
	local fill = ns.FillRegion(bar)
	if not fill then
		return false
	end
	local ok, atlas = pcall(fill.GetAtlas, fill)
	return ok and not ns.IsSecret(atlas) and type(atlas) == "string" and CAST_STATES[atlas:lower()] == "interrupted"
end

local CAST_COLOURS = {
	cast = "castbars.castColour",
	channel = "castbars.channelColour",
	shield = "castbars.shieldColour",
	interrupted = "castbars.interruptedColour",
	craft = "castbars.craftColour",
}

local casts = setmetatable({}, { __mode = "k" })
local following = setmetatable({}, { __mode = "k" })
local verdicts = {}

local function Protected(frame)
	local ok, protected = pcall(frame.IsProtected, frame)
	return not ok or ns.IsSecret(protected) or protected == true
end

local function Anchored(region)
	local ok, points = pcall(region.GetNumPoints, region)
	if not ok or ns.IsSecret(points) or type(points) ~= "number" then
		return true
	end
	return points > 0
end

local function CastCover(bar, record)
	if record.failed then
		return false
	end
	local fill = ns.FillRegion(bar)
	if not fill or (InCombatLockdown() and Protected(bar)) then
		return false
	end
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
		Count("castbars", bar)
	end
	return true
end

local function IsTrue(value)
	return not ns.IsSecret(value) and value == true
end

local function CastState(bar, record)
	local fill = record.fill
	if IsTrue(bar.reverseChanneling) then
		return "none"
	end
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
	local casting, channeling = bar.casting, bar.channeling
	local spark = bar.Spark
	if not ns.IsSecret(casting) and not ns.IsSecret(channeling) and not casting and not channeling and spark ~= nil then
		local sparkOk, sparkShown = pcall(spark.IsShown, spark)
		if sparkOk and IsTrue(sparkShown) then
			return "interrupted"
		end
	end
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

local function CastColour(record, state)
	if record.kick ~= nil and (state == "cast" or state == "channel") then
		local path = record.kick == "far" and "castbars.interruptFar" or (record.kick and "castbars.interruptReady" or "castbars.interruptCooling")
		local r, g, b = ns.Colour(path)
		return r, g, b, ns.Get(path)
	end
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

local function PaintBorder(bar, r, g, b)
	ns.SetOutlineColour(outlineOf[bar], r, g, b)
end

local function HideMarks(record)
	if record.marks then
		for _, name in ipairs({ "icon", "latency", "queue" }) do
			if record[name] then
				record[name]:Hide()
			end
		end
		record.marks = nil
	end
end

local function LatencyTint(holder, ...)
	local hex = ns.Get("castbars.latencyColour")
	if holder.latencyHex == hex then
		return
	end
	local ok, r, g, b = pcall(ns.Colour, "castbars.latencyColour")
	if not (ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b)) then
		r, g, b = 1, 0, 0
	end
	for i = 1, select("#", ...) do
		local zone = select(i, ...)
		if zone then
			zone:SetColorTexture(r, g, b, 0.6)
		end
	end
	holder.latencyHex = hex
end

local QUEUE = { at = nil, ms = nil, every = 1, least = 5 }

local function QueueWindow()
	local now = GetTime()
	if QUEUE.at and now >= QUEUE.at and now - QUEUE.at < QUEUE.every then
		return QUEUE.ms
	end
	local ms
	local api = C_Spell
	if type(api) == "table" and type(api.GetSpellQueueWindow) == "function" then
		local ok, value = pcall(api.GetSpellQueueWindow)
		if ok and ns.Finite(value) and value >= 0 then
			ms = value > 0 and value < QUEUE.least and value * 1000 or value
		end
	end
	if ms == nil and type(GetCVar) == "function" then
		local ok, value = pcall(GetCVar, "SpellQueueWindow")
		local number = ok and not ns.IsSecret(value) and tonumber(value) or nil
		ms = ns.Finite(number) and number >= 0 and number or nil
	end
	QUEUE.at, QUEUE.ms = now, ms or 400
	return QUEUE.ms
end

local function QueueTint(holder, mark)
	local hex = ns.Get("castbars.queueColour")
	if holder.queueHex == hex then
		return
	end
	local ok, r, g, b = pcall(ns.Colour, "castbars.queueColour")
	if not (ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b)) then
		r, g, b = 1, 1, 1
	end
	mark:SetColorTexture(r, g, b, 1)
	holder.queueHex = hex
end

local function MakeMark(bar, record, name, anchor)
	if record.markFailed or (InCombatLockdown() and Protected(bar)) then
		return nil
	end
	local mark = bar:CreateTexture(nil, "OVERLAY", nil, name == "icon" and 1 or name == "queue" and 2 or 0)
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

local function PlaceQueue(bar, record, wantQueue, startMs, endMs, width)
	local queue = record.queue
	local window = wantQueue and startMs and endMs and endMs > startMs and width and width > 0 and QueueWindow() or nil
	if not (window and window > 0) then
		if queue then
			queue:Hide()
		end
		return false
	end
	if not queue then
		local spacer = record.queueSpacer or MakeMark(bar, record, "queueSpacer", function(mark)
			mark:SetColorTexture(0, 0, 0, 0)
			mark:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
			mark:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
			mark:SetWidth(0.01)
		end)
		queue = spacer and MakeMark(bar, record, "queue", function(mark)
			mark:SetColorTexture(1, 1, 1, 1)
			mark:SetPoint("TOP", spacer, "TOPRIGHT", 0, 0)
			mark:SetPoint("BOTTOM", spacer, "BOTTOMRIGHT", 0, 0)
		end)
		if not queue then
			return false
		end
	end
	QueueTint(record, queue)
	local x = (1 - math.min(1, window / (endMs - startMs))) * width
	if record.queueX ~= x then
		record.queueSpacer:SetWidth(math.max(x, 0.01))
		record.queueX = x
	end
	local px = ns.Pixels(bar, 1)
	if record.queuePx ~= px then
		queue:SetWidth(px)
		record.queuePx = px
	end
	queue:Show()
	return true
end

local function Marks(bar, record, wantIcon, wantLatency, wantQueue)
	local unit = record.option == "pet" and "pet" or "player"
	local name, _, texture, startMs, endMs = UnitCastingInfo(unit)
	local channel = false
	if not ns.IsSecret(name) and name == nil then
		name, _, texture, startMs, endMs = UnitChannelInfo(unit)
		channel = true
	end
	if ns.IsSecret(name) then
		HideMarks(record)
		return
	elseif name == nil then
		if record.latency then
			record.latency:Hide()
		end
		if record.queue then
			record.queue:Hide()
		end
		local icon = record.icon
		if icon and not wantIcon then
			icon:Hide()
		end
		record.marks = icon and icon:IsShown() or nil
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
			LatencyTint(record, latency)
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
	if PlaceQueue(bar, record, wantQueue and not channel, startMs, endMs, width) then
		shown = true
	end
	record.marks = shown or nil
end

local function PaintMarks(bar, record, state)
	local option = record.key == "castbars" and record.option
	local wantIcon = (option == "player" or option == "pet") and ns.Get("castbars.playerIcon")
	local wantLatency = option == "player" and state ~= "interrupted" and ns.Get("castbars.latency")
	local wantQueue = option == "player" and state ~= "interrupted" and ns.Get("castbars.queue") == true
	if not wantIcon and not wantLatency and not wantQueue then
		HideMarks(record)
	elseif ns.PartStopped("castbars", "cast marks") or not ns.EachPart("castbars", "cast marks", Marks, bar, record, wantIcon, wantLatency, wantQueue) then
		HideMarks(record)
	end
end

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

local function BarUnit(bar)
	return bar.unit
end

local function Kick(bar, record, state)
	if (state ~= "cast" and state ~= "channel" and state ~= "withheld") or type(ns.InterruptReady) ~= "function" then
		return nil
	end
	local unit
	if record.key == "castbars" then
		unit = (record.option == "target" or record.option == "focus") and record.option or nil
	elseif record.key == "nameplates" then
		local ok, value = pcall(BarUnit, bar)
		unit = ok and not ns.IsSecret(value) and type(value) == "string" and value or nil
	end
	if unit == nil then
		return nil
	end
	return ns.InterruptReady(unit)
end

local function SetFlash(bar, record, tint, r, g, b, shield, otherwise)
	if tint ~= "withheld" and record.flashTint == tint then
		return
	end
	local flash = BarPart(bar, "Flash")
	if flash then
		pcall(flash.SetDesaturated, flash, tint ~= nil and tint ~= "off")
		if tint == "withheld" then
			pcall(flash.SetVertexColorFromBoolean, flash, shield, ColourObject(record, "shield"), ColourObject(record, otherwise))
		elseif tint == nil then
			pcall(flash.SetVertexColor, flash, 1, 1, 1)
		else
			pcall(flash.SetVertexColor, flash, r, g, b)
		end
	end
	record.flashTint = tint
end

local function PaintFlash(bar, record, state, r, g, b, shield, otherwise)
	local rule = ns.Get("castbars.flash")
	if rule == "off" then
		SetFlash(bar, record, "off", 0, 0, 0)
	elseif rule ~= "cast" then
		SetFlash(bar, record, nil)
	elseif state == "withheld" then
		SetFlash(bar, record, "withheld", nil, nil, nil, shield, otherwise)
	else
		SetFlash(bar, record, ("%s,%s,%s"):format(r, g, b), r, g, b)
	end
end

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
	record.kick = Kick(bar, record, state)
	if state == "withheld" then
		cover:SetVertexColorFromBoolean(shield, ColourObject(record, "shield"), ColourObject(record, otherwise))
		record.state, record.hex = state, nil
		PaintBorder(bar, nil)
		PaintFlash(bar, record, state, nil, nil, nil, shield, otherwise)
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
		PaintFlash(bar, record, state, r, g, b)
	end
	if not record.shown then
		cover:Show()
		record.shown = true
	end
	PaintMarks(bar, record, state)
end

local function PollCast(bar, record)
	local ok, forbidden = pcall(bar.IsForbidden, bar)
	if not ok or ns.IsSecret(forbidden) or forbidden ~= false then
		return
	end
	local shown = bar:IsShown()
	if ns.IsSecret(shown) or shown == true then
		PaintCast(bar, record)
	else
		record.kind = nil
		PaintBorder(bar, nil)
		HideMarks(record)
	end
end

local function CastFillPart(key)
	return key == "castbars" and "flat fill" or "cast bar fill"
end

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

function ns.CastFill(key, bar, on)
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
	if not on and record.flashTint ~= nil and not forbidden then
		SetFlash(bar, record, nil)
	end
	if changed then
		Watch()
	end
end

local function ApplyCastFill(bar)
	ns.CastFill("castbars", bar, ns.Enabled("castbars") and ns.Get("castbars.flat") and not ns.PartStopped("castbars", "flat fill"))
end

do
	local KICK_BARS = { { "TargetFrameSpellBar", "target" }, { "FocusFrameSpellBar", "focus" } }
	local KICK_EVERY, KICK_PX = 0.1, 2
	local strips, queued = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
	local kickFrame, kickClock, kicking, resized = nil, 0, false, false

	local function StripPx()
		local px = ns.Get("castbars.interruptStrip")
		if ns.Finite(px) and px >= 1 and px <= 6 then
			return px
		end
		return KICK_PX
	end

	local function KickWanted()
		return ns.Enabled("castbars") and ns.Get("castbars.interrupt") == true and ns.Get("castbars.flat") ~= true
			and type(ns.InterruptReady) == "function" and type(ns.InterruptKnown) == "function" and ns.InterruptKnown() == true
	end

	local function HideStrip(strip)
		if strip and strip.shown then
			pcall(strip.tex.Hide, strip.tex)
			strip.shown = false
		end
	end

	local function MakeStrip(bar)
		local strip = strips[bar]
		if strip ~= nil then
			return strip or nil
		end
		if InCombatLockdown() and ns.MaybeProtected(bar) then
			if not queued[bar] then
				queued[bar] = true
				ns.OutOfCombat(function()
					queued[bar] = nil
					pcall(ns.CastKickSync)
				end)
			end
			return nil
		end
		local ok, tex = pcall(bar.CreateTexture, bar, nil, "OVERLAY", nil, 7)
		if not ok or ns.IsSecret(tex) or type(tex) ~= "table" then
			strips[bar] = false
			return nil
		end
		ns.Own[tex] = true
		tex:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
		tex:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
		local px = StripPx()
		tex:SetHeight(ns.Pixels(bar, px))
		tex:Hide()
		if not Anchored(tex) then
			strips[bar] = false
			ns.Note("castbars", "Cast bars: the game refused the interrupt strip on a target or focus bar, so it does not show there.")
			return nil
		end
		strip = { tex = tex, shown = false, px = px }
		strips[bar] = strip
		return strip
	end

	local function PaintStrip(bar, unit)
		local strip = strips[bar]
		if not strip then
			return
		end
		local answer = nil
		if IsTrue(bar.casting) or IsTrue(bar.channeling) then
			answer = ns.InterruptReady(unit)
		end
		if answer == nil then
			HideStrip(strip)
			return
		end
		local locked = false
		local shield = bar.BorderShield
		if shield ~= nil and not ns.IsSecret(shield) and type(shield) == "table" then
			local ok, shown = pcall(shield.IsShown, shield)
			if ok then
				locked = shown
			end
		end
		if not ns.IsSecret(locked) and locked == true then
			HideStrip(strip)
			return
		end
		local tex = strip.tex
		local path = answer == "far" and "castbars.interruptFar" or (answer and "castbars.interruptReady" or "castbars.interruptCooling")
		local hex = ns.Get(path)
		if strip.hex ~= hex then
			local r, g, b = ns.Colour(path)
			tex:SetColorTexture(r, g, b, 1)
			strip.hex = hex
		end
		if ns.IsSecret(locked) then
			if not (tex.SetAlphaFromBoolean and pcall(tex.SetAlphaFromBoolean, tex, locked, 0, 1)) then
				tex:SetAlpha(1)
			end
			strip.alpha = nil
		elseif strip.alpha ~= 1 then
			tex:SetAlpha(1)
			strip.alpha = 1
		end
		if not strip.shown then
			tex:Show()
			strip.shown = true
		end
	end

	local function KickTick(_, elapsed)
		kickClock = kickClock + elapsed
		if kickClock < KICK_EVERY then
			return
		end
		kickClock = 0
		if not KickWanted() then
			ns.CastKickSync()
			return
		end
		for _, entry in ipairs(KICK_BARS) do
			local bar = _G[entry[1]]
			local strip = bar ~= nil and strips[bar]
			if strip then
				local ok, err = pcall(PaintStrip, bar, entry[2])
				if not ok then
					HideStrip(strip)
					strips[bar] = false
					ns.Note("castbars", "Cast bars: the interrupt strip of a target or focus bar failed, so it no longer shows there. " .. tostring(err))
				end
			end
		end
	end

	function ns.CastKickSync()
		local wanted = KickWanted()
		for _, entry in ipairs(KICK_BARS) do
			local bar = _G[entry[1]]
			if bar ~= nil and not ns.IsSecret(bar) and not ns.Forbidden(bar) then
				if wanted then
					local strip = MakeStrip(bar)
					local px = StripPx()
					if strip and not InCombatLockdown() then
						pcall(strip.tex.SetHeight, strip.tex, ns.Pixels(bar, px))
						strip.px = px
					elseif strip and strip.px ~= px and not resized then
						resized = true
						if type(ns.PanelShown) == "function" and ns.PanelShown() == true then
							print("Flat UI: the interrupt strip takes its new height when the fight ends.")
						end
						ns.OutOfCombat(function()
							resized = false
							pcall(ns.CastKickSync)
						end)
					end
				else
					HideStrip(strips[bar])
				end
			end
		end
		if wanted ~= kicking then
			if wanted and kickFrame == nil then
				kickFrame = CreateFrame("Frame")
				ns.Own[kickFrame] = true
			end
			if kickFrame then
				kickFrame:SetScript("OnUpdate", wanted and KickTick or nil)
			end
			kicking = wanted
		end
	end
end

do
	local MARK_BARS = { { "PlayerCastingBarFrame", "player" }, { "OverlayPlayerCastingBarFrame", "player" }, { "PetCastingBarFrame", "pet" } }
	local MARK_EVERY, MARK_PART, MARK_NAMES = 0.05, "cast marks", { "icon", "cast", "channel", "queue" }
	local sets, queued = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
	local markFrame, markClock, marking = nil, 0, false

	local function MarksWanted()
		return ns.Enabled("castbars") and ns.Get("castbars.flat") ~= true and not ns.PartStopped("castbars", MARK_PART)
			and (ns.Get("castbars.latency") == true or ns.Get("castbars.playerIcon") == true or ns.Get("castbars.queue") == true)
	end

	local function ShowMark(set, name, show)
		local mark = set[name]
		if mark and (set.shown[name] == true) ~= show then
			if show then
				mark:Show()
			else
				mark:Hide()
			end
			set.shown[name] = show or nil
		end
	end

	local function HideSet(set)
		if set then
			for _, name in ipairs(MARK_NAMES) do
				pcall(ShowMark, set, name, false)
			end
		end
	end

	local function NewMark(bar, sublevel, place)
		local ok, mark = pcall(bar.CreateTexture, bar, nil, "OVERLAY", nil, sublevel)
		if not ok or ns.IsSecret(mark) or type(mark) ~= "table" then
			return nil
		end
		ns.Own[mark] = true
		if not pcall(place, mark) then
			return nil
		end
		mark:Hide()
		return Anchored(mark) and mark or nil
	end

	local function NewZone(bar, side)
		return NewMark(bar, 0, function(mark)
			mark:SetColorTexture(1, 0, 0, 0.6)
			mark:SetPoint("TOP" .. side, bar, "TOP" .. side, 0, 0)
			mark:SetPoint("BOTTOM" .. side, bar, "BOTTOM" .. side, 0, 0)
			mark:SetWidth(0.01)
		end)
	end

	local function MakeSet(bar, unit)
		local set = sets[bar]
		if set ~= nil then
			return set or nil
		end
		if InCombatLockdown() and ns.MaybeProtected(bar) then
			if not queued[bar] then
				queued[bar] = true
				ns.OutOfCombat(function()
					queued[bar] = nil
					pcall(ns.CastMarksSync)
				end)
			end
			return nil
		end
		local icon = NewMark(bar, 1, function(mark)
			mark:SetPoint("RIGHT", bar, "LEFT", -5, 0)
			mark:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end)
		local cast = unit == "player" and NewZone(bar, "RIGHT") or nil
		local channel = unit == "player" and NewZone(bar, "LEFT") or nil
		if not icon or (unit == "player" and not (cast and channel)) then
			sets[bar] = false
			ns.Note("castbars", "Cast bars: the game refused a mark on one cast bar, which keeps its default look.")
			return nil
		end
		set = { unit = unit, icon = icon, cast = cast, channel = channel, shown = {}, widths = {} }
		if unit == "player" then
			local spacer = NewMark(bar, 0, function(mark)
				mark:SetColorTexture(0, 0, 0, 0)
				mark:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
				mark:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
				mark:SetWidth(0.01)
			end)
			set.queueSpacer = spacer
			set.queue = spacer and NewMark(bar, 2, function(mark)
				mark:SetColorTexture(1, 1, 1, 1)
				mark:SetPoint("TOP", spacer, "TOPRIGHT", 0, 0)
				mark:SetPoint("BOTTOM", spacer, "BOTTOMRIGHT", 0, 0)
				mark:SetWidth(ns.Pixels(bar, 1))
			end) or nil
		end
		sets[bar] = set
		return set
	end

	local function PaintQueue(set, wantQueue, channel, startMs, endMs, width)
		local window = wantQueue and not channel and startMs and endMs and endMs > startMs and width and width > 0 and QueueWindow() or nil
		if not (set.queue and window and window > 0) then
			ShowMark(set, "queue", false)
			return
		end
		QueueTint(set, set.queue)
		local x = (1 - math.min(1, window / (endMs - startMs))) * width
		if set.widths.queue ~= x then
			set.queueSpacer:SetWidth(math.max(x, 0.01))
			set.widths.queue = x
		end
		ShowMark(set, "queue", true)
	end

	local function PaintSet(bar, set, wantIcon, wantLatency, wantQueue)
		local name, _, texture, startMs, endMs = UnitCastingInfo(set.unit)
		local channel = false
		if not ns.IsSecret(name) and name == nil then
			name, _, texture, startMs, endMs = UnitChannelInfo(set.unit)
			channel = true
		end
		if ns.IsSecret(name) then
			HideSet(set)
			return
		elseif name == nil then
			local ok, shown = pcall(bar.IsShown, bar)
			if ok and not ns.IsSecret(shown) and shown == true then
				ShowMark(set, "cast", false)
				ShowMark(set, "channel", false)
				ShowMark(set, "queue", false)
				if not wantIcon then
					ShowMark(set, "icon", false)
				end
			else
				HideSet(set)
			end
			return
		end
		local height = PlainNumber(bar:GetHeight())
		if wantIcon and not ns.IsSecret(texture) and (type(texture) == "number" or type(texture) == "string") and height and height > 0 then
			local icon = set.icon
			if set.file ~= texture then
				icon:SetTexture(texture)
				set.file = texture
			end
			if set.size ~= height then
				icon:SetSize(height, height)
				set.size = height
			end
			ShowMark(set, "icon", true)
		else
			ShowMark(set, "icon", false)
		end
		if not set.cast then
			return
		end
		LatencyTint(set, set.cast, set.channel)
		local side = channel and "channel" or "cast"
		ShowMark(set, channel and "cast" or "channel", false)
		local width = PlainNumber(bar:GetWidth())
		startMs, endMs = PlainNumber(startMs), PlainNumber(endMs)
		local world = wantLatency and type(GetNetStats) == "function" and PlainNumber(select(4, GetNetStats())) or nil
		if world and startMs and endMs and endMs > startMs and width and width > 0 then
			local zone = math.min(1, math.max(0, world) / (endMs - startMs)) * width
			if set.widths[side] ~= zone then
				set[side]:SetWidth(math.max(zone, 0.01))
				set.widths[side] = zone
			end
			ShowMark(set, side, true)
		else
			ShowMark(set, side, false)
		end
		PaintQueue(set, wantQueue, channel, startMs, endMs, width)
	end

	local function MarkTick(_, elapsed)
		markClock = markClock + elapsed
		if markClock < MARK_EVERY then
			return
		end
		markClock = 0
		if not MarksWanted() then
			pcall(ns.CastMarksSync)
			return
		end
		local wantIcon, wantLatency = ns.Get("castbars.playerIcon") == true, ns.Get("castbars.latency") == true
		local wantQueue = ns.Get("castbars.queue") == true
		for _, entry in ipairs(MARK_BARS) do
			local bar = _G[entry[1]]
			local set = bar ~= nil and sets[bar]
			if set then
				local ok, err = ns.EachPart("castbars", MARK_PART, PaintSet, bar, set, wantIcon, wantLatency, wantQueue)
				if not ok then
					HideSet(set)
					if err then
						sets[bar] = false
						ns.Note("castbars", "Cast bars: the spell icon or latency zone of one cast bar failed, so it no longer shows there. " .. err)
					end
				end
			end
		end
	end

	function ns.CastMarksSync()
		local wanted = MarksWanted()
		for _, entry in ipairs(MARK_BARS) do
			local bar = _G[entry[1]]
			if bar ~= nil and not ns.IsSecret(bar) and not ns.Forbidden(bar) then
				if wanted then
					MakeSet(bar, entry[2])
				else
					HideSet(sets[bar])
				end
			end
		end
		if wanted ~= marking then
			if wanted and markFrame == nil then
				markFrame = CreateFrame("Frame")
				ns.Own[markFrame] = true
			end
			if markFrame then
				markFrame:SetScript("OnUpdate", wanted and MarkTick or nil)
			end
			marking = wanted
		end
	end
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
	if ns.CastTicksSync then ns.CastTicksSync() end
	if ns.CastRankSync then ns.CastRankSync() end
	if ns.InterruptSync then ns.InterruptSync() end
	pcall(ns.CastMarksSync)
end

ns.Register("castbars", { label = "Cast bars", Start = RefreshCastBars, Refresh = RefreshCastBars })

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
