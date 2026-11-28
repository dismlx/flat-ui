local _, ns = ...

local KEY = "nameplates"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

local VALUE, TARGET = "threat value", "enemy's target"
local FONT_OBJECT = "SystemFont_NamePlate"
local GAP, ROW_GAP = 4, 1
local SHOWN = { scaled = true, raw = true, lead = true }
local JUSTIFY = { left = "RIGHT", right = "LEFT", above = "CENTER", below = "CENTER" }
local FADE = 0.15

local recs = setmetatable({}, { __mode = "k" })
local subscribed, heard, fighting, placeWaiting = false, false, false, false
local listener
local Draw, OnChange, OnUpdate, Beside, MakeFades, Clear

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and not ns.IsSecret(value) then
		return value
	end
	return nil
end

local function Rec(unitFrame)
	local rec = recs[unitFrame]
	if rec == nil then
		rec = { fonts = {} }
		recs[unitFrame] = rec
	end
	return rec
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

local function Frame(owner, key)
	local frame = Region(owner, key)
	if frame and not ns.Forbidden(frame) then
		return frame
	end
end

local function HealthBarOf(unitFrame)
	local container = Frame(unitFrame, "HealthBarsContainer")
	return container and Frame(container, "healthBar")
end

local function NameOnly(unitFrame)
	local only = unitFrame.showOnlyName
	return Plain(only, "boolean") and only
end

local function MayBeProtected(frame)
	return type(ns.MaybeProtected) ~= "function" or ns.MaybeProtected(frame)
end

local function CanPlace(unitFrame, text)
	return not (InCombatLockdown() and (MayBeProtected(unitFrame) or (text ~= nil and MayBeProtected(text))))
end

local function PlaceLater()
	if not placeWaiting then
		placeWaiting = true
		ns.OutOfCombat(function()
			placeWaiting = false
			ns.EachPlate(Draw, true)
		end)
	end
end

local function Subscribe()
	local PT = ns.PlateThreat
	if not subscribed and type(PT) == "table" and type(PT.OnChange) == "function" and type(PT.OnUpdate) == "function" then
		subscribed = pcall(PT.OnChange, OnChange) and pcall(PT.OnUpdate, OnUpdate)
	end
	return PT
end

local function Core()
	local PT = Subscribe()
	if type(PT) ~= "table" then
		return nil
	end
	local ok, active = pcall(PT.Active)
	if ok and active == true then
		return PT
	end
	return nil
end

local function StateOf(PT, unitFrame)
	local ok, state = pcall(PT.Get, unitFrame)
	if ok and type(state) == "table" then
		return state
	end
	return nil
end

function MakeFades(rec, which, text)
	local ok, fadeIn, fadeOut = pcall(function()
		local inGroup = text:CreateAnimationGroup()
		ns.Own[inGroup] = true
		local appear = inGroup:CreateAnimation("Alpha")
		ns.Own[appear] = true
		appear:SetFromAlpha(0)
		appear:SetToAlpha(1)
		appear:SetDuration(FADE)
		local outGroup = text:CreateAnimationGroup()
		ns.Own[outGroup] = true
		local away = outGroup:CreateAnimation("Alpha")
		ns.Own[away] = true
		away:SetFromAlpha(1)
		away:SetToAlpha(0)
		away:SetDuration(FADE)
		pcall(outGroup.SetToFinalAlpha, outGroup, true)
		outGroup:SetScript("OnFinished", function()
			if rec[which .. "Shown"] == false then
				text:SetText("")
				text:Hide()
			end
		end)
		return inGroup, outGroup
	end)
	if ok and type(fadeIn) == "table" and type(fadeOut) == "table" then
		rec[which .. "In"], rec[which .. "Out"] = fadeIn, fadeOut
	end
end

local function Text(unitFrame, rec, which)
	local text = rec[which]
	if text ~= nil then
		return text
	end
	local healthBar = HealthBarOf(unitFrame)
	if healthBar == nil then
		return nil
	end
	if not CanPlace(unitFrame) then
		if not rec.waiting then
			rec.waiting = true
			ns.OutOfCombat(function()
				rec.waiting = nil
				Draw(unitFrame, true)
			end)
		end
		return nil
	end
	text = ns.OwnText(unitFrame, "OVERLAY", FONT_OBJECT)
	if text == nil then
		error("the threat text could not be made", 0)
	end
	if rec.base == nil then
		local ok, file, size, flags = pcall(text.GetFont, text)
		local plainFlags = not ns.IsSecret(flags) and (flags == nil or type(flags) == "string")
		rec.base = ok and Plain(file, "string") and ns.Finite(size) and size > 0 and plainFlags and { file, size, flags or "" } or false
	end
	text:SetText("")
	text:Hide()
	if which ~= "value" then
		text:SetJustifyH("LEFT")
	end
	rec[which] = text
	MakeFades(rec, which, text)
	return text
end

local function Playing(group)
	if not group then
		return false
	end
	local ok, playing = pcall(group.IsPlaying, group)
	return ok and playing == true
end

local function StopFades(rec, which)
	for _, group in ipairs({ rec[which .. "In"] or false, rec[which .. "Out"] or false }) do
		if group then
			pcall(group.Stop, group)
		end
	end
end

function Clear(rec, which, now)
	local text = rec[which]
	if text ~= nil and rec[which .. "Shown"] ~= false then
		rec[which .. "Shown"] = false
		local fadeIn, fadeOut = rec[which .. "In"], rec[which .. "Out"]
		if fadeIn then
			pcall(fadeIn.Stop, fadeIn)
		end
		if not now and fadeOut and not rec[which .. "Withheld"] and not (which == "value" and rec.covered) and Ask(text.IsShown, text) == true
			and not Playing(fadeOut) and pcall(fadeOut.Play, fadeOut) then
			return
		end
		StopFades(rec, which)
		text:SetText("")
		text:Hide()
	end
end

local function Appear(rec, which, text, fade)
	local fadeIn, fadeOut = rec[which .. "In"], rec[which .. "Out"]
	local cut = Playing(fadeOut)
	if fadeOut then
		pcall(fadeOut.Stop, fadeOut)
	end
	local covered = which == "value" and rec.covered == true
	if not covered then
		text:SetAlpha(1)
	end
	text:Show()
	if fade and not cut and not covered and fadeIn then
		pcall(fadeIn.Stop, fadeIn)
		pcall(fadeIn.Play, fadeIn)
	end
end

local function Font(unitFrame, rec, text, outline)
	local file, size, flags
	local game = Region(HealthBarOf(unitFrame), "RightText")
	if game then
		local ok, f, s, fl = pcall(game.GetFont, game)
		local plainFlags = not ns.IsSecret(fl) and (fl == nil or type(fl) == "string")
		if ok and Plain(f, "string") and ns.Finite(s) and s > 0 and plainFlags then
			file, size, flags = f, s, fl or ""
		end
	end
	if file == nil and rec.base then
		file, size, flags = rec.base[1], rec.base[2], rec.base[3]
	end
	if file == nil then
		return
	end
	local chosen = outline ~= nil and outline ~= "game" and ns.OUTLINE_FLAGS[outline] or nil
	if type(chosen) == "string" then
		flags = chosen
	end
	local percent = Opt("threatValueSize")
	local key = ("%s|%s|%s|%s"):format(file, size, flags, percent)
	if rec.fonts[text] ~= key and pcall(text.SetFont, text, file, size * percent / 100, flags) then
		rec.fonts[text] = key
	end
end

local function When()
	local when = Opt("threatValueWhen")
	if when == "always" or Ask(IsInGroup) == true then
		return true
	end
	return when == "group" and Ask(UnitExists, "pet") == true
end

local function Number(mode, unit)
	local ok, tanking, _, scaled, raw = pcall(UnitDetailedThreatSituation, "player", unit)
	if not ok then
		return nil
	end
	if mode == "scaled" then
		return scaled
	end
	if mode == "lead" and not ns.IsSecret(tanking) and tanking == true then
		local okLead, lead = pcall(UnitThreatPercentageOfLead, "player", unit)
		if okLead then
			return lead
		end
		return nil
	end
	return raw
end

local function Write(text, value)
	if (ns.IsSecret(value) or ns.Finite(value)) and pcall(text.SetFormattedText, text, "%.0f%%", value) then
		return
	end
	text:SetText("")
end

local function ValueColour(PT, rec, text, state)
	local threat = Opt("threatValueColour") == true
	if rec.colourFor == state and rec.colourThreat == threat then
		return
	end
	local r, g, b = 1, 1, 1
	if threat then
		local ok, cr, cg, cb = pcall(PT.Colour, state)
		if ok and ns.Finite(cr) and ns.Finite(cg) and ns.Finite(cb) then
			r, g, b = cr, cg, cb
		end
	else
		r, g, b = ns.Colour(KEY .. ".threatValueCustom")
	end
	text:SetTextColor(r, g, b, 1)
	rec.colourFor, rec.colourThreat = state, threat
end

local function Lift(unitFrame)
	local options, constants = NamePlateSetupOptions, NamePlateConstants
	if not Plain(options, "table") or (type(ns.PlateNameShown) == "function" and ns.PlateNameShown(unitFrame) == false) then
		return 0
	end
	local styles = Plain(constants, "table") and constants.NAME_ANCHOR_STYLES or nil
	local inside = Plain(styles, "table") and styles.InsideHealthBar or nil
	local style = options.unitNameAnchorStyle
	if Plain(inside, "number") and Plain(style, "number") and style == inside then
		return 0
	end
	local spacing, height, size = options.healthBarToNameAboveSpacing, options.healthBarFontHeight, Opt("nameSize")
	return (ns.Finite(spacing) and spacing or 0) + (ns.Finite(height) and height or 0) * (ns.Finite(size) and size or 100) / 100
end

local function QuestPlace(unitFrame)
	if type(ns.PlateQuestPlace) == "function" then
		pcall(ns.PlateQuestPlace, unitFrame)
	end
end

local function OverpowerPlace(unitFrame)
	if type(ns.PlateOverpowerPlace) == "function" then
		pcall(ns.PlateOverpowerPlace, unitFrame)
	end
	if type(ns.PlateSlipPlace) == "function" then
		pcall(ns.PlateSlipPlace, unitFrame)
	end
end

local function DebuffTop(unitFrame)
	if type(ns.PlateDebuffTop) ~= "function" then
		return nil, false
	end
	local ok, guide, stale = pcall(ns.PlateDebuffTop, unitFrame)
	if not ok or type(guide) ~= "table" then
		return nil, false
	end
	return guide, stale == true
end

local function ComboRow(unitFrame)
	if type(ns.PlateComboRow) ~= "function" then
		return nil
	end
	local ok, row = pcall(ns.PlateComboRow, unitFrame)
	return ok and type(row) == "table" and row or nil
end

local function Collapses(frame)
	return frame ~= nil and Ask(frame.CollapsesLayout, frame) == true
end

local function AurasSeen(unitFrame, rec)
	local own = rec.own
	local when = Opt("aurasWhen")
	if not (ns.Enabled(KEY) and type(own) == "table" and own.styleOn == true and (when == "target" or when == "focus")) then
		return true
	end
	return ns.PlateUnitFrame("target") == unitFrame or (when == "focus" and ns.PlateUnitFrame("focus") == unitFrame)
end

local function AuraRow(unitFrame, rec, key)
	local auras = Frame(unitFrame, "AurasFrame")
	local list = auras and Frame(auras, key)
	if list and Ask(auras.IsShown, auras) == true and Ask(list.IsShown, list) == true and AurasSeen(unitFrame, rec) then
		return list
	end
	return nil
end

local function LeftEnd(unitFrame, rec)
	local buffs = AuraRow(unitFrame, rec, "BuffListFrame")
	if buffs then
		return buffs, "buffs"
	end
	local class, marker = Frame(unitFrame, "ClassificationFrame"), Frame(unitFrame, "RaidTargetFrame")
	if Collapses(class) and Collapses(marker) then
		return class, "class"
	end
	return nil
end

local function GapFrom(key)
	return (key == "buffs" or key == "cc") and ROW_GAP or GAP
end

local function MarkerLift(rec)
	local own = rec.own
	local y = type(own) == "table" and own.markY or nil
	return ns.Finite(y) and y or 0
end

local function PlaceValue(unitFrame, rec, text)
	local healthBar = HealthBarOf(unitFrame)
	if healthBar == nil then
		return
	end
	local place = Opt("threatValuePlace")
	if JUSTIFY[place] == nil then
		place = "left"
	end
	local x, y = Opt("threatValueX"), Opt("threatValueY")
	x, y = ns.Finite(x) and x or 0, ns.Finite(y) and y or 0
	local frame, key, lift = healthBar, "bar", 0
	if place == "left" then
		local left, leftKey = LeftEnd(unitFrame, rec)
		if left then
			frame, key, lift = left, leftKey, MarkerLift(rec)
		end
	elseif place == "right" then
		frame, key = Beside(unitFrame, rec)
	elseif place == "below" then
		local combo = ComboRow(unitFrame)
		local cast = Frame(unitFrame, "CastBarsContainer")
		if combo then
			frame, key = combo, "combo"
		elseif cast then
			frame, key = cast, "cast"
		end
	elseif place == "above" then
		local guide, stale = DebuffTop(unitFrame)
		if guide then
			frame, key = guide, "guide"
		else
			lift = Lift(unitFrame)
		end
		if stale then
			PlaceLater()
		end
	end
	if frame == nil then
		return
	end
	local wanted = ("%s:%s:%s:%s:%s"):format(place, x, y, key, lift)
	if rec.valuePlace == wanted then
		return
	end
	if not CanPlace(unitFrame, rec.valuePlace ~= nil and text or nil) then
		PlaceLater()
		return
	end
	text:ClearAllPoints()
	text:SetJustifyH(JUSTIFY[place])
	if place == "left" then
		text:SetPoint("RIGHT", frame, "LEFT", x - GapFrom(key), y - lift)
	elseif place == "right" then
		text:SetPoint("LEFT", frame, "RIGHT", x + GapFrom(key), y)
	elseif place == "above" then
		text:SetPoint("BOTTOM", frame, "TOP", x, y + lift + GAP)
	else
		text:SetPoint("TOP", frame, "BOTTOM", x, y - GAP)
	end
	rec.valuePlace, rec.valueSide = wanted, place
	QuestPlace(unitFrame)
	OverpowerPlace(unitFrame)
end

local function StandsOver(unitFrame, rec)
	if rec.valueSide == "above" then
		QuestPlace(unitFrame)
		OverpowerPlace(unitFrame)
	end
end

local function ValuePart(unitFrame, rec, on, full)
	local PT = on and Core() or nil
	local mode = Opt("threatValue")
	local state = PT and SHOWN[mode] and StateOf(PT, unitFrame) or nil
	local unit = unitFrame.unit
	if not (state and Plain(unit, "string") and not NameOnly(unitFrame) and When()) then
		local was = rec.valueShown == true
		Clear(rec, "value", not on)
		if was then
			StandsOver(unitFrame, rec)
		end
		return
	end
	local text = Text(unitFrame, rec, "value")
	if text == nil then
		return
	end
	local again = full or rec.valueShown ~= true
	if again then
		PlaceValue(unitFrame, rec, text)
	end
	if again or rec.fonts[text] == nil then
		Font(unitFrame, rec, text, Opt("threatValueOutline"))
	end
	ValueColour(PT, rec, text, state)
	Write(text, Number(mode, unit))
	local was = rec.valueShown
	Appear(rec, "value", text, was ~= true)
	rec.valueShown = true
	if was ~= true then
		StandsOver(unitFrame, rec)
	end
end

function Beside(unitFrame, rec)
	local own = rec.own
	own = type(own) == "table" and own or {}
	if own.classShown and own.iconSide == "right" and type(own.icon) == "table" then
		return own.icon, "icon"
	end
	local cc = AuraRow(unitFrame, rec, "CrowdControlListFrame")
	if cc then
		return cc, "cc"
	end
	local level = Frame(unitFrame, "PlayerLevelDiffFrame")
	if level and not own.levelFade then
		local ok, shown = pcall(level.IsShown, level)
		if ok and Plain(shown, "boolean") and shown then
			return level, "level"
		end
	end
	return HealthBarOf(unitFrame), "bar"
end

local function After(unitFrame, rec)
	if rec.value ~= nil and rec.valueSide == "right" and SHOWN[Opt("threatValue")] and not ns.PartStopped(KEY, VALUE) then
		return rec.value, "value"
	end
	return Beside(unitFrame, rec)
end

local function Place(unitFrame, rec, text)
	local frame, key = After(unitFrame, rec)
	if frame == nil or rec.place == key then
		return
	end
	if not CanPlace(unitFrame, text) then
		PlaceLater()
		return
	end
	text:ClearAllPoints()
	text:SetPoint("LEFT", frame, "RIGHT", GapFrom(key), 0)
	rec.place = key
	QuestPlace(unitFrame)
end

local function AurasMoved()
	if Opt("aurasWhen") == "always" then
		return
	end
	ns.EachPlate(function(unitFrame)
		local rec = recs[unitFrame]
		if rec == nil or ns.Forbidden(unitFrame) then
			return
		end
		if rec.value ~= nil and rec.valueShown == true then
			pcall(PlaceValue, unitFrame, rec, rec.value)
		end
		if rec.target ~= nil and rec.targetShown == true then
			pcall(Place, unitFrame, rec, rec.target)
		end
		QuestPlace(unitFrame)
	end)
end

local function TargetToken(unitFrame, on)
	if not (on and Opt("aggroTarget") == true and Core()) then
		return nil
	end
	local unit = unitFrame.unit
	if not Plain(unit, "string") or NameOnly(unitFrame) then
		return nil
	end
	if Opt("aggroTargetCombat") == true and not fighting then
		return nil
	end
	if Opt("aggroTargetOnly") == true and ns.PlateUnitFrame("target") ~= unitFrame then
		return nil
	end
	if Ask(UnitCanAttack, "player", unit) ~= true then
		return nil
	end
	local token = unit .. "target"
	if Ask(UnitExists, token) ~= true then
		return nil
	end
	return token
end

local function TargetColour(text, token)
	if Ask(UnitIsPlayer, token) == true and type(C_ClassColor) == "table" and pcall(function()
		local _, class = UnitClass(token)
		local colour = C_ClassColor.GetClassColor(class)
		text:SetTextColor(colour.r, colour.g, colour.b, 1)
	end) then
		return
	end
	text:SetTextColor(1, 1, 1, 1)
end

local function TargetPart(unitFrame, rec, on, full)
	local token = TargetToken(unitFrame, on)
	if token == nil then
		Clear(rec, "target", not on)
		return
	end
	local text = Text(unitFrame, rec, "target")
	if text == nil then
		return
	end
	if full or rec.fonts[text] == nil then
		Font(unitFrame, rec, text)
	end
	Place(unitFrame, rec, text)
	local withheld, me = false, nil
	if Opt("aggroTargetNotMe") == true then
		local ok, answer = pcall(UnitIsUnit, token, "player")
		if not ok or (not ns.IsSecret(answer) and answer == true) then
			Clear(rec, "target")
			return
		end
		if ns.IsSecret(answer) then
			withheld, me = true, answer
		end
	end
	local ok, name = pcall(UnitName, token)
	if not ok or not (ns.IsSecret(name) or (type(name) == "string" and name ~= "")) or not pcall(text.SetFormattedText, text, "[%s]", name) then
		Clear(rec, "target")
		return
	end
	TargetColour(text, token)
	if withheld then
		StopFades(rec, "target")
		rec.targetWithheld = true
		if not pcall(text.SetAlphaFromBoolean, text, me, 0, 1) then
			Clear(rec, "target", true)
			return
		end
		text:Show()
	else
		rec.targetWithheld = nil
		Appear(rec, "target", text, rec.targetShown ~= true)
	end
	rec.targetShown = true
end

local Listen

local function Run(part, fn, unitFrame, full)
	local rec = Rec(unitFrame)
	if ns.IsStopped(KEY) or ns.PartStopped(KEY, part) then
		pcall(fn, unitFrame, rec, false, full)
	elseif not ns.EachPart(KEY, part, fn, unitFrame, rec, ns.Enabled(KEY), full) and ns.PartStopped(KEY, part) then
		ns.EachPlate(function(frame)
			pcall(fn, frame, Rec(frame), false)
		end)
		pcall(Listen)
	end
end

function Draw(unitFrame, full)
	if ns.Forbidden(unitFrame) then
		return
	end
	Run(VALUE, ValuePart, unitFrame, full)
	Run(TARGET, TargetPart, unitFrame, full)
end

local function DrawTarget(unitFrame)
	if not ns.Forbidden(unitFrame) then
		Run(TARGET, TargetPart, unitFrame)
	end
end

local function OnUnitTarget(unit)
	if ns.IsSecret(unit) then
		ns.EachPlate(DrawTarget)
	elseif type(unit) == "string" and unit:find("^nameplate") then
		local unitFrame = ns.PlateUnitFrame(unit)
		if unitFrame then
			DrawTarget(unitFrame)
		end
	end
end

function Listen()
	local want = (ns.Enabled(KEY) and not ns.PartStopped(KEY, TARGET) and Opt("aggroTarget") == true and Core() ~= nil
		and (Opt("aggroTargetCombat") ~= true or fighting)) == true
	if want == heard or (not want and listener == nil) then
		return
	end
	if listener == nil then
		local ok, frame = pcall(CreateFrame, "Frame")
		if not ok or type(frame) ~= "table" then
			return
		end
		ns.Own[frame] = true
		frame:SetScript("OnEvent", function(_, _, unit)
			pcall(OnUnitTarget, unit)
		end)
		listener = frame
	end
	if want then
		heard = pcall(listener.RegisterEvent, listener, "UNIT_TARGET")
	else
		pcall(listener.UnregisterEvent, listener, "UNIT_TARGET")
		heard = false
	end
end

function OnChange(unitFrame, state)
	if ns.IsPlate(unitFrame) then
		Draw(unitFrame)
	end
	if state == nil then
		pcall(Listen)
	end
end

function OnUpdate(unitFrame)
	if ns.IsPlate(unitFrame) then
		Draw(unitFrame)
	end
end

local function Fight(on)
	fighting = on
	pcall(Listen)
	if Opt("aggroTarget") == true and Opt("aggroTargetCombat") == true then
		ns.EachPlate(DrawTarget)
	end
end

function ns.PlateThreatTexts(unitFrame)
	local rec = unitFrame ~= nil and recs[unitFrame]
	if not rec or ns.IsStopped(KEY) then
		return nil
	end
	local value, target = rec.value, rec.target
	if ns.PartStopped(KEY, VALUE) or not SHOWN[Opt("threatValue")] then
		value = nil
	end
	if value ~= nil and rec.valueSide == "above" and rec.valueShown ~= true then
		value = nil
	end
	if ns.PartStopped(KEY, TARGET) or Opt("aggroTarget") ~= true or rec.place == nil then
		target = nil
	end
	return value, value and rec.valueSide or nil, target
end

function ns.PlateThreatValueCover(unitFrame, on, instant)
	local rec = unitFrame ~= nil and not ns.IsSecret(unitFrame) and recs[unitFrame] or nil
	if not rec then
		return
	end
	on = on == true or nil
	if rec.covered == on then
		return
	end
	rec.covered = on
	local text = rec.value
	if text == nil or ns.Forbidden(unitFrame) then
		return
	end
	if on and rec.valueIn then
		pcall(rec.valueIn.Stop, rec.valueIn)
	end
	if type(ns.PlateEase) == "function" and pcall(ns.PlateEase, unitFrame, text, on and 0 or 1, instant) then
		return
	end
	text:SetAlpha(on and 0 or 1)
end

function ns.PlateAurasSeen(unitFrame)
	if unitFrame == nil or ns.Forbidden(unitFrame) then
		return true
	end
	return AurasSeen(unitFrame, Rec(unitFrame))
end

function ns.PlateThreatPlace(unitFrame)
	local rec = unitFrame ~= nil and recs[unitFrame]
	if rec and rec.value ~= nil and rec.valueShown == true and not ns.Forbidden(unitFrame) and not ns.IsStopped(KEY)
		and not ns.PartStopped(KEY, VALUE) then
		pcall(PlaceValue, unitFrame, rec, rec.value)
	end
end

function ns.PlateAuraRow(unitFrame, side)
	if unitFrame == nil or ns.Forbidden(unitFrame) then
		return nil
	end
	return AuraRow(unitFrame, Rec(unitFrame), side == "left" and "BuffListFrame" or "CrowdControlListFrame")
end

EXTRA.show[#EXTRA.show + 1] = function(unitFrame, own)
	Subscribe()
	Rec(unitFrame).own = own
	Listen()
	Draw(unitFrame, true)
end
EXTRA.layout[#EXTRA.layout + 1] = function(unitFrame, own)
	Rec(unitFrame).own = own
	Draw(unitFrame, true)
end
EXTRA.leave[#EXTRA.leave + 1] = function(unitFrame)
	local rec = recs[unitFrame]
	if rec == nil then
		return
	end
	for _, which in ipairs({ "value", "target" }) do
		local text = rec[which]
		pcall(StopFades, rec, which)
		if text ~= nil then
			pcall(text.SetText, text, "")
			pcall(text.Hide, text)
		end
		rec[which .. "Shown"] = false
	end
	rec.colourFor = nil
end
EXTRA.refresh[#EXTRA.refresh + 1] = function()
	Subscribe()
	fighting = InCombatLockdown() == true
	for _, rec in pairs(recs) do
		rec.colourFor = nil
	end
	Listen()
	ns.EachPlate(Draw, true)
end

ns.AddEvent(KEY, "PLAYER_REGEN_DISABLED", function()
	Fight(true)
end)
ns.AddEvent(KEY, "PLAYER_REGEN_ENABLED", function()
	Fight(false)
end)
ns.AddEvent(KEY, "PLAYER_TARGET_CHANGED", function()
	if Opt("aggroTarget") == true then
		ns.EachPlate(DrawTarget)
	end
	AurasMoved()
end)
ns.AddEvent(KEY, "PLAYER_FOCUS_CHANGED", function()
	if Opt("aurasWhen") == "focus" then
		AurasMoved()
	end
end)
