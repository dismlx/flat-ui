local _, ns = ...

local KEY = "nameplates"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

local FONT_OBJECT = "SystemFont_NamePlate"
local HEALTH_TEXTS, CAST_TEXTS = { "Text", "LeftText", "RightText" }, { "Text", "CastTargetNameText" }
local NAME, HEALTH, FORMAT, CAST, PARTS = "name text", "health text", "health text format", "cast bar text", "cast bar parts"

local state = setmetatable({}, { __mode = "k" })
local gameColour = setmetatable({}, { __mode = "k" })
local followName, followHealth
local waitingForCombat, queued = false, false

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

local function Soon(fn)
	if C_Timer and C_Timer.After then
		C_Timer.After(0, fn)
	else
		fn()
	end
end

local function St(unitFrame)
	local record = state[unitFrame]
	if record == nil then
		record = {}
		state[unitFrame] = record
	end
	return record
end

local function OnFor(unitFrame)
	if not ns.Enabled(KEY) then
		return false
	end
	if Opt("friendly") then
		return true
	end
	local friend = unitFrame.isFriend
	return not (Plain(friend, "boolean") and friend)
end

local function White(path)
	return ns.Get(path):sub(3, 8) == "ffffff"
end

local function Region(owner, key)
	if ns.Forbidden(owner) then
		return nil
	end
	local region = owner[key]
	if ns.IsSecret(region) or type(region) ~= "table" then
		return nil
	end
	return region
end

local function Strings(owner, keys)
	local list = {}
	for _, key in ipairs(keys) do
		local fontString = Region(owner, key)
		if fontString then
			list[#list + 1] = fontString
		end
	end
	return list
end

local function Frame(owner, key)
	local frame = Region(owner, key)
	if frame and not ns.Forbidden(frame) then
		return frame
	end
end

local function CastBarOf(unitFrame)
	local container = Frame(unitFrame, "CastBarsContainer")
	return container and Frame(container, "castBar")
end

local function HealthBarOf(unitFrame)
	local container = Frame(unitFrame, "HealthBarsContainer")
	return container and Frame(container, "healthBar")
end

local function TextColour(fontString, r, g, b)
	if r ~= nil then
		if gameColour[fontString] == nil then
			local ok, gr, gg, gb, ga = pcall(fontString.GetTextColor, fontString)
			if not ok or not (Plain(gr, "number") and Plain(gg, "number") and Plain(gb, "number")) then
				error("the text colour could not be read", 0)
			end
			gameColour[fontString] = { gr, gg, gb, Plain(ga, "number") and ga or 1 }
		end
		if not pcall(fontString.SetTextColor, fontString, r, g, b, 1) then
			error("the text colour could not be set", 0)
		end
	elseif gameColour[fontString] then
		local back = gameColour[fontString]
		gameColour[fontString] = nil
		if not pcall(fontString.SetTextColor, fontString, back[1], back[2], back[3], back[4]) then
			error("the game's text colour could not be put back", 0)
		end
	end
end

local function Allowed(frame)
	local check = C_RestrictedActions and C_RestrictedActions.CheckAllowProtectedFunctions
	if check then
		local ok, allowed = pcall(check, frame, true)
		if ok and Plain(allowed, "boolean") then
			return allowed
		end
	end
	return not InCombatLockdown()
end

local function ThreatColour(unitFrame)
	local threat = Opt("threatName") == true and ns.PlateThreat
	if type(threat) ~= "table" then
		return nil
	end
	local okActive, active = pcall(threat.Active)
	if not (okActive and active == true) then
		return nil
	end
	local okState, current = pcall(threat.Get, unitFrame)
	if okState and type(current) == "table" and current.tapped ~= true then
		local okColour, cr, cg, cb = pcall(threat.Colour, current)
		if okColour and ns.Finite(cr) and ns.Finite(cg) and ns.Finite(cb) then
			return cr, cg, cb
		end
	end
	return nil
end

local function HealthThreatColour(unitFrame)
	if Opt("threatHealthText") ~= true then
		return nil
	end
	return ThreatColour(unitFrame)
end

local function NamePart(unitFrame, st, on, fromGame)
	local name = Region(unitFrame, "name")
	if name == nil then
		return
	end
	local shown = not on or Opt("nameShow")
	if not shown or st.nameFaded then
		ns.SetFaded(name, not shown)
		st.nameFaded = not shown or nil
	end
	local mode = on and Opt("nameColour") or "game"
	local r, g, b
	local tr, tg, tb
	if on then
		tr, tg, tb = ThreatColour(unitFrame)
	end
	if tr ~= nil then
		r, g, b = tr, tg, tb
	elseif mode == "white" then
		r, g, b = 1, 1, 1
	elseif mode == "custom" then
		r, g, b = ns.Colour(KEY .. ".nameCustomColour")
	elseif mode == "reaction" or mode == "class" then
		local unit = unitFrame.unit
		if Plain(unit, "string") then
			local okPlayer, player = pcall(UnitIsPlayer, unit)
			if mode == "class" and okPlayer and Plain(player, "boolean") and player then
				r, g, b = ns.ClassColourOf(unit)
			else
				r, g, b = ns.ReactionColour(unit)
			end
		end
	end
	if r ~= nil then
		if not followName then
			ns.Note(KEY, "Name colour: the game's name update cannot be followed, so the colour can go back to the game's.")
		end
		local okShown, isShown = pcall(name.IsShown, name)
		local gameColour = fromGame and okShown and Plain(isShown, "boolean") and isShown
		if gameColour or st.nameGame == nil then
			local ok, gr, gg, gb, ga = pcall(name.GetVertexColor, name)
			if ok and Plain(gr, "number") and Plain(gg, "number") and Plain(gb, "number") then
				st.nameGame = { gr, gg, gb, Plain(ga, "number") and ga or 1 }
			else
				st.nameGame = false
			end
		end
		st.nameSet = true
		if not pcall(name.SetVertexColor, name, r, g, b) then
			error("the name colour could not be set", 0)
		end
	elseif st.nameSet then
		local back = st.nameGame
		st.nameSet, st.nameGame = nil, nil
		if back and not pcall(name.SetVertexColor, name, back[1], back[2], back[3], back[4]) then
			error("the game's name colour could not be put back", 0)
		end
	end
end

local function AnyShown(strings)
	if #strings == 0 then
		return true
	end
	for _, fontString in ipairs(strings) do
		local ok, shown = pcall(fontString.IsShown, fontString)
		if not ok or not Plain(shown, "boolean") or shown then
			return true
		end
	end
	return false
end

local function Ease(unitFrame, region, to, ease)
	if type(ns.PlateEase) == "function" then
		local ok, done, running = pcall(ns.PlateEase, unitFrame, region, to, not ease)
		if ok and done then
			return running == true
		end
	end
	ns.SetFaded(region, to == 0)
	return false
end

local function HealthPart(unitFrame, st, on, ease)
	local strings = Strings(HealthBarOf(unitFrame), HEALTH_TEXTS)
	local r, g, b
	if on then
		r, g, b = HealthThreatColour(unitFrame)
	end
	if r == nil and on and not White(KEY .. ".healthTextColour") then
		r, g, b = ns.Colour(KEY .. ".healthTextColour")
	end
	for _, fontString in ipairs(strings) do
		TextColour(fontString, r, g, b)
	end
	local when, format = on and Opt("healthTextWhen") or "always", on and Opt("healthFormat") or "game"
	if ns.PartStopped(KEY, FORMAT) then
		format = "game"
	end
	local mine = when ~= "always" or format ~= "game"
	if mine or st.htFaded then
		local shown = ns.PlateUnitFrame("target") == unitFrame or (when == "focus" and ns.PlateUnitFrame("focus") == unitFrame)
		local fade = (ns.Enabled(KEY) and not Opt("healthText")) or format ~= "game" or (when ~= "always" and not shown)
		local was = st.htSeen
		if when ~= "always" then
			st.htSeen = shown == true
		else
			st.htSeen = nil
		end
		local soft = when ~= "always" and (ease == true or (was ~= nil and was ~= st.htSeen))
		for _, fontString in ipairs(strings) do
			Ease(unitFrame, fontString, fade and 0 or 1, soft)
		end
		st.htFaded = mine and fade or nil
	end
end

ns.PLATE_HEALTH_FORMATS = { percent = "%.0f%%", both = "%s  %.0f%%", curmax = "%s / %s" }

local function Num(value)
	local call = ns.Get("unitframes.numberStyle") == "full" and BreakUpLargeNumbers or AbbreviateNumbers or BreakUpLargeNumbers
	return call(value)
end

local function SetHealthText(own, format, unit)
	local formats = ns.PLATE_HEALTH_FORMATS
	if format == "value" then
		own:SetText(Num(UnitHealth(unit)))
	elseif format == "curmax" then
		own:SetFormattedText(formats.curmax, Num(UnitHealth(unit)), Num(UnitHealthMax(unit)))
	elseif format == "percent" then
		own:SetFormattedText(formats.percent, UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
	elseif format == "both" then
		own:SetFormattedText(formats.both, Num(UnitHealth(unit)), UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
	else
		local miss = UnitHealthMissing(unit)
		local strings = C_StringUtil
		if ns.IsSecret(miss) then
			if type(strings) == "table" and type(strings.TruncateWhenZero) == "function" then
				own:SetText(strings.TruncateWhenZero(miss))
			else
				own:SetText(Num(miss))
			end
		elseif ns.Finite(miss) and miss >= 1 then
			own:SetText(Num(miss))
		else
			own:SetText("")
		end
	end
end

local function OwnHealthText(unitFrame, st, healthBar)
	local own = st.own
	if own == nil then
		own = ns.OwnText(unitFrame, "OVERLAY", FONT_OBJECT)
		if own == nil then
			error("the health text could not be made", 0)
		end
		st.own = own
		own:SetPoint("RIGHT", healthBar, "RIGHT", -4, 0)
	end
	local game = Region(healthBar, "RightText")
	if game then
		local ok, file, size, flags = pcall(game.GetFont, game)
		if ok and Plain(file, "string") and Plain(size, "number") and Plain(flags, "string") then
			local key = ("%s|%s|%s"):format(file, size, flags)
			if st.ownFont ~= key then
				if pcall(own.SetFont, own, file, size, flags) then
					st.ownFont = key
				end
			end
		end
	end
	return own
end

local function FormatPart(unitFrame, st, on, ease)
	local format = on and Opt("healthFormat") or "game"
	if format == "game" then
		if st.own then
			Ease(unitFrame, st.own, 1, false)
			st.own:SetText("")
			st.own:Hide()
		end
		return
	end
	local healthBar = HealthBarOf(unitFrame)
	if healthBar == nil then
		return
	end
	if not followHealth then
		ns.Note(KEY, "Health text format: the game's health update cannot be followed, so the text may not change with the health.")
	end
	local own = OwnHealthText(unitFrame, st, healthBar)
	local colourR, colourG, colourB = HealthThreatColour(unitFrame)
	if colourR == nil then
		colourR, colourG, colourB = 1, 1, 1
		if not White(KEY .. ".healthTextColour") then
			colourR, colourG, colourB = ns.Colour(KEY .. ".healthTextColour")
		end
	end
	own:SetTextColor(colourR, colourG, colourB, 1)
	local unit = unitFrame.unit
	local when = Opt("healthTextWhen")
	local seen = when == "always" or ns.PlateUnitFrame("target") == unitFrame or (when == "focus" and ns.PlateUnitFrame("focus") == unitFrame)
	local wanted = Opt("healthText") and Plain(unit, "string") and AnyShown(Strings(healthBar, HEALTH_TEXTS))
	local fading = false
	if wanted and when ~= "always" then
		local was = st.ownSeen
		st.ownSeen = seen == true
		fading = Ease(unitFrame, own, seen and 1 or 0, ease == true or (was ~= nil and was ~= st.ownSeen))
	else
		st.ownSeen = nil
		Ease(unitFrame, own, 1, false)
	end
	local shown = (wanted and seen) or fading
	own:SetShown(shown and true or false)
	if shown then
		SetHealthText(own, format, unit)
	end
end

local function CastPart(unitFrame, st, on)
	local castBar = CastBarOf(unitFrame)
	if castBar == nil then
		return
	end
	local percent = on and Opt("castTextSize") or 100
	local flags = on and ns.OUTLINE_FLAGS[Opt("castTextOutline")] or nil
	local face = on and Opt("textFace") ~= "default" and ns.FontFile(Opt("textFace")) or nil
	local r, g, b
	if on and not White(KEY .. ".castTextColour") then
		r, g, b = ns.Colour(KEY .. ".castTextColour")
	end
	for _, key in ipairs(CAST_TEXTS) do
		local spec = { percent = percent, flags = flags, face = face }
		if key == "Text" and r ~= nil then
			spec.r, spec.g, spec.b = r, g, b
		end
		if ns.TextStyle(castBar[key], spec) == false then
			error("the spell name font could not be set", 0)
		end
	end
end

local function Fade(castBar, st, key, flag, faded)
	if faded or st[flag] then
		ns.SetFaded(Region(castBar, key), faded)
		st[flag] = faded or nil
	end
end

local Layout

local function PartsPart(unitFrame, st, on)
	local castBar = CastBarOf(unitFrame)
	if castBar == nil then
		return
	end
	Fade(castBar, st, "Spark", "sparkFaded", on and not Opt("castSpark"))
	Fade(castBar, st, "BorderShield", "shieldFaded", on and not Opt("castShield"))
	local percent = on and Opt("castIconSize") or 100
	if percent == 100 and not st.iconSized then
		return
	end
	local options, icon = NamePlateSetupOptions, Region(castBar, "Icon")
	local width, height = Plain(options, "table") and options.castIconWidth, Plain(options, "table") and options.castIconHeight
	if icon == nil or not (Plain(width, "number") and Plain(height, "number")) then
		return
	end
	if Allowed(castBar) then
		st.iconSized = percent ~= 100 or nil
		icon:SetSize(width * percent / 100, height * percent / 100)
	elseif not InCombatLockdown() then
		ns.Note(KEY, "Spell icon size: the game does not allow the spell icon to be resized.")
	elseif not waitingForCombat then
		waitingForCombat = true
		ns.OutOfCombat(function()
			waitingForCombat = false
			ns.EachPlate(Layout)
		end)
	end
end

local function QueueAll()
	if not queued then
		queued = true
		Soon(function()
			queued = false
			ns.EachPlate(Layout)
		end)
	end
end

local function Run(part, fn, unitFrame, ...)
	local st = St(unitFrame)
	if ns.IsStopped(KEY) or ns.PartStopped(KEY, part) then
		pcall(fn, unitFrame, st, false, ...)
	else
		ns.EachPart(KEY, part, fn, unitFrame, st, OnFor(unitFrame), ...)
		if ns.PartStopped(KEY, part) then
			pcall(fn, unitFrame, st, false, ...)
			QueueAll()
		end
	end
end

function Layout(unitFrame)
	if ns.Forbidden(unitFrame) then
		return
	end
	Run(NAME, NamePart, unitFrame)
	Run(HEALTH, HealthPart, unitFrame)
	Run(FORMAT, FormatPart, unitFrame)
	Run(CAST, CastPart, unitFrame)
	Run(PARTS, PartsPart, unitFrame)
end

local function OnName(frame)
	if ns.IsPlate(frame) and not ns.Forbidden(frame) then
		Run(NAME, NamePart, frame, true)
	end
end

local function OnHealth(frame)
	if ns.IsPlate(frame) and not ns.Forbidden(frame) then
		Run(FORMAT, FormatPart, frame)
	end
end

local function Leave(unitFrame)
	local st = state[unitFrame]
	if st then
		st.htSeen, st.ownSeen = nil, nil
	end
	if st and st.own then
		pcall(st.own.SetText, st.own, "")
	end
end

local retargetQueued = false
local function Retarget()
	if retargetQueued then
		return
	end
	retargetQueued = true
	Soon(function()
		retargetQueued = false
		ns.EachPlate(function(unitFrame)
			Run(HEALTH, HealthPart, unitFrame, true)
			Run(FORMAT, FormatPart, unitFrame, true)
		end)
	end)
end

local threatFollowed = false
local function OnThreat(frame)
	if Opt("threatName") == true and ns.IsPlate(frame) and not ns.Forbidden(frame) then
		Run(NAME, NamePart, frame)
		if Opt("threatHealthText") == true then
			Run(HEALTH, HealthPart, frame)
			Run(FORMAT, FormatPart, frame)
		end
	end
end
local function FollowThreat()
	local threat = ns.PlateThreat
	if not threatFollowed and type(threat) == "table" and type(threat.OnChange) == "function" then
		threatFollowed = pcall(threat.OnChange, OnThreat)
	end
end

function ns.PlateNameShown(unitFrame)
	local st = unitFrame ~= nil and not ns.IsSecret(unitFrame) and state[unitFrame] or nil
	return not (st and st.nameFaded == true)
end

local function Seen(region)
	local ok, shown = pcall(region.IsShown, region)
	if not ok or not Plain(shown, "boolean") or not shown then
		return false
	end
	local okAlpha, alpha = pcall(region.GetAlpha, region)
	return not okAlpha or not ns.Finite(alpha) or alpha > 0.05
end

function ns.PlateHealthText(unitFrame)
	if unitFrame == nil or ns.IsSecret(unitFrame) or ns.Forbidden(unitFrame) then
		return nil
	end
	local st = state[unitFrame]
	if st and st.own and Seen(st.own) then
		return st.own
	end
	for _, fontString in ipairs(Strings(HealthBarOf(unitFrame), HEALTH_TEXTS)) do
		if Seen(fontString) then
			return fontString
		end
	end
	return nil
end

EXTRA.layout[#EXTRA.layout + 1] = Layout
EXTRA.show[#EXTRA.show + 1] = FollowThreat
EXTRA.show[#EXTRA.show + 1] = Layout
EXTRA.leave[#EXTRA.leave + 1] = Leave
EXTRA.refresh[#EXTRA.refresh + 1] = FollowThreat
followName = ns.FollowGlobal("CompactUnitFrame_UpdateName", OnName) == true
followHealth = ns.FollowGlobal("CompactUnitFrame_UpdateHealth", OnHealth) == true
ns.AddEvent(KEY, "PLAYER_TARGET_CHANGED", Retarget)
ns.AddEvent(KEY, "PLAYER_FOCUS_CHANGED", function()
	if Opt("healthTextWhen") == "focus" then
		Retarget()
	end
end)
