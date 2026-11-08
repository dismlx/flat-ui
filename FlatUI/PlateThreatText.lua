local _, ns = ...

-- Threat text on nameplates, parts of Nameplates.lua (ns.PlateExtra): the threat value left of the health bar and the name of the enemy's target
-- right of it. Both follow the threat that PlateThreat.lua keeps for each plate (ns.PlateThreat): the state after a change (OnChange) and every
-- threat update the game makes on the plate (OnUpdate); this file never asks the game for the threat level. The core is found the first time a
-- hook of this file runs, and without it the rows do nothing. Each text is a font string of the addon's own on the plate's unit frame, so both
-- fade with the plate, made the first time the plate needs it and, on a frame that may be protected, only out of combat (as CastTime.lua makes
-- its text), in the font of the game's health text. The game's answers go to the texts as they are: a withheld number, name, colour or answer is
-- never read, compared or joined in Lua, since SetFormattedText, SetTextColor and SetAlphaFromBoolean take them
-- (SimpleFontStringAPIDocumentation.lua:539-548, 675-688; SimpleRegionAPIDocumentation.lua:133-145). Every call is in a pcall; a part that fails
-- on enough plates stops alone and hides its text on every plate.
-- The value follows Threat Plates' threat widget (Widgets/ThreatWidget.lua:352-408): the share of aggro (scaledPercentage) or the share of the
-- tank's threat (rawPercentage) of UnitDetailedThreatSituation, or the game's own threat number, the lead while tanking and the share of the
-- tank's threat otherwise (Blizzard_UnitFrame/Mainline/UnitFrame.lua:1028-1046), in place of Threat Plates' value types that compare units,
-- which show nothing on this client (ThreatWidget.lua:417-426). The enemy's target follows its TargetUnit (Elements/Healthbar.lua:258-342).

local KEY = "nameplates"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

local VALUE, TARGET = "threat value", "enemy's target"
local FONT_OBJECT = "SystemFont_NamePlate"
-- Nameplate units between a text and what it sits beside.
local GAP = 4
-- The kinds of Threat value that show a number.
local SHOWN = { scaled = true, raw = true, lead = true }

-- Per unit frame: value and target (the font strings), valueShown and targetShown (false once hidden), base (the font object's font, for a plate
-- whose health text cannot be read), fonts (per font string, the font it was given), place (what the target text is anchored to), colourFor and
-- colourThreat (the state and the setting the value was coloured for), own (what Nameplates.lua keeps of the plate), waiting (the plate waits for
-- the end of combat to get its texts).
local recs = setmetatable({}, { __mode = "k" })
-- subscribed: the listeners are on the core. heard: UNIT_TARGET is heard. fighting: between PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED.
-- placeWaiting: the target texts wait for the end of combat to be placed again.
local subscribed, heard, fighting, placeWaiting = false, false, false, false
local listener
local Draw, OnChange, OnUpdate

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

-- The answer of a call of the client, or nil when the call is missing, raises or the answer is withheld.
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

-- A frame of a plate that the addon may touch.
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

-- True while the plate shows only the name: there is no health bar to stand beside.
local function NameOnly(unitFrame)
	local only = unitFrame.showOnlyName
	return Plain(only, "boolean") and only
end

-- SetPoint and ClearAllPoints are protected (SimpleScriptRegionResizingAPIDocumentation.lua:22-30, 135-139), so on a frame that may be
-- protected nothing is made or placed in combat. Movers.lua has ns.MaybeProtected; before it loads every frame counts as protected.
local function MayBeProtected(frame)
	return type(ns.MaybeProtected) ~= "function" or ns.MaybeProtected(frame)
end

local function CanPlace(unitFrame, text)
	return not (InCombatLockdown() and (MayBeProtected(unitFrame) or (text ~= nil and MayBeProtected(text))))
end

-- The threat core ----------------------------------------------------------------------------

-- The listeners are added to the threat of the nameplates (PlateThreat.lua) the first time a hook finds it; the core adds each once however often
-- it is passed.
local function Subscribe()
	local PT = ns.PlateThreat
	if not subscribed and type(PT) == "table" and type(PT.OnChange) == "function" and type(PT.OnUpdate) == "function" then
		subscribed = pcall(PT.OnChange, OnChange) and pcall(PT.OnUpdate, OnUpdate)
	end
	return PT
end

-- The threat of the nameplates while it is on, else nil.
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

-- The state the core keeps for a plate, or nil.
local function StateOf(PT, unitFrame)
	local ok, state = pcall(PT.Get, unitFrame)
	if ok and type(state) == "table" then
		return state
	end
	return nil
end

-- The texts ----------------------------------------------------------------------------------

-- One of the two texts of a plate, made the first time it is wanted. A plate that may be protected gets it when combat ends, and is drawn then.
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
	if which == "value" then
		-- Threat Plates' value: left of the bar, outside it, aligned right (Constants.lua:2080-2103).
		text:SetJustifyH("RIGHT")
		text:SetPoint("RIGHT", healthBar, "LEFT", -GAP, 0)
	else
		text:SetJustifyH("LEFT")
	end
	rec[which] = text
	return text
end

local function Clear(rec, which)
	local text = rec[which]
	if text ~= nil and rec[which .. "Shown"] ~= false then
		text:SetText("")
		text:Hide()
		rec[which .. "Shown"] = false
	end
end

-- The font of the game's health text at Threat value size, with the game's flags, as the health text of the addon's own takes it (PlateText.lua).
-- A plate whose health text cannot be read keeps the font object's font at that size.
local function Font(unitFrame, rec, text)
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
	local percent = Opt("threatValueSize")
	local key = ("%s|%s|%s|%s"):format(file, size, flags, percent)
	if rec.fonts[text] ~= key and pcall(text.SetFont, text, file, size * percent / 100, flags) then
		rec.fonts[text] = key
	end
end

-- The threat value ---------------------------------------------------------------------------

-- True while Show threat value lets the value show: always, in a group or with a pet (Threat Plates' In groups and With pet,
-- ThreatWidget.lua:358), or only in a group.
local function When()
	local when = Opt("threatValueWhen")
	if when == "always" or Ask(IsInGroup) == true then
		return true
	end
	return when == "group" and Ask(UnitExists, "pet") == true
end

-- The number of the value as the game gives it: a number, a withheld value or nil. The game answers nothing for an enemy the player is not on
-- the threat table of (UnitDocumentation.lua:1086-1106, MayReturnNothing), and withholds the values on some bosses
-- (SecretWhenUnitThreatValuesRestricted, SecretPredicatesDocumentation.lua:164-168).
local function Number(mode, unit)
	local ok, tanking, _, scaled, raw = pcall(UnitDetailedThreatSituation, "player", unit)
	if not ok then
		return nil
	end
	if mode == "scaled" then
		return scaled
	end
	if mode == "lead" and not ns.IsSecret(tanking) and tanking == true then
		-- The game's own threat number shows the lead while tanking (UnitFrame.lua:1031-1034; UnitDocumentation.lua:3261-3277).
		local okLead, lead = pcall(UnitThreatPercentageOfLead, "player", unit)
		if okLead then
			return lead
		end
		return nil
	end
	return raw
end

-- A withheld number goes to the font string untouched; nothing, nil or a refusal writes nothing. Nothing is formatted in Lua.
local function Write(text, value)
	if (ns.IsSecret(value) or ns.Finite(value)) and pcall(text.SetFormattedText, text, "%.0f%%", value) then
		return
	end
	text:SetText("")
end

-- The threat colour of the state with Threat value in the threat colour, else white (Threat Plates' UseThreatColor and its custom white), set when
-- the state or the setting changes.
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
	end
	text:SetTextColor(r, g, b, 1)
	rec.colourFor, rec.colourThreat = state, threat
end

-- Shown while the plate has a state, Threat value shows a number, the plate shows its health bar and Show threat value allows. The number is
-- written on every threat update of the plate, as Threat Plates does on each UNIT_THREAT_LIST_UPDATE (ThreatWidget.lua:357).
local function ValuePart(unitFrame, rec, on, full)
	local PT = on and Core() or nil
	local mode = Opt("threatValue")
	local state = PT and SHOWN[mode] and StateOf(PT, unitFrame) or nil
	local unit = unitFrame.unit
	if not (state and Plain(unit, "string") and not NameOnly(unitFrame) and When()) then
		Clear(rec, "value")
		return
	end
	local text = Text(unitFrame, rec, "value")
	if text == nil then
		return
	end
	if full or rec.fonts[text] == nil then
		Font(unitFrame, rec, text)
	end
	ValueColour(PT, rec, text, state)
	Write(text, Number(mode, unit))
	text:Show()
	rec.valueShown = true
end

-- The enemy's target -------------------------------------------------------------------------

-- What the target text sits after: a class icon on the right of the bar, else the level frame while it shows (the game's hangs past the end of the
-- bar, Camelot/Blizzard_NamePlateLevelFrame.xml:5-8, and Flat UI's square box ends the bar), else the bar.
local function Beside(unitFrame, rec)
	local own = rec.own
	own = type(own) == "table" and own or {}
	if own.classShown and own.iconSide == "right" and type(own.icon) == "table" then
		return own.icon, "icon"
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

-- In a fight a text that may be protected keeps its anchor, and every plate is placed again when the fight ends.
local function Place(unitFrame, rec, text)
	local frame, key = Beside(unitFrame, rec)
	if frame == nil or rec.place == key then
		return
	end
	if not CanPlace(unitFrame, text) then
		if not placeWaiting then
			placeWaiting = true
			ns.OutOfCombat(function()
				placeWaiting = false
				ns.EachPlate(Draw, true)
			end)
		end
		return
	end
	text:ClearAllPoints()
	text:SetPoint("LEFT", frame, "RIGHT", GAP, 0)
	rec.place = key
end

-- The unit the enemy of a plate attacks, or nil while its name is not to show: an attackable plate with its health bar, in a fight with Only in
-- combat, the plate of your target with Only on your target. UnitExists of the token has no secret rule (UnitDocumentation.lua:1192-1205).
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

-- The class colour of a player, from the game's colour of its class, withheld or not (C_ClassColor.GetClassColor, ClassColorDocumentation.lua:11-25,
-- takes a withheld class: UnitClass, UnitDocumentation.lua:911-927), all in one pcall; white for any other unit and whenever a step fails.
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

-- The name of the enemy's target in brackets (Threat Plates' ShowBrackets), as the game gives it: UnitName is withheld for most compound tokens
-- (SecretWhenUnitNameIdentityRestricted, UnitDocumentation.lua:2489-2504). Not when it attacks you: UnitIsUnit with the player is comparable
-- (SecretPredicatesDocumentation.lua:9-14) and withheld for a compound token on maps where addons are restricted (119-123); then the game's
-- answer sets the opacity, so in a dungeon the game hides your own name (Threat Plates shows it there, Compatibility.lua:208-216). A call the
-- client refuses hides the text.
local function TargetPart(unitFrame, rec, on, full)
	local token = TargetToken(unitFrame, on)
	if token == nil then
		Clear(rec, "target")
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
		if not pcall(text.SetAlphaFromBoolean, text, me, 0, 1) then
			Clear(rec, "target")
			return
		end
	else
		text:SetAlpha(1)
	end
	text:Show()
	rec.targetShown = true
end

-- Running the parts --------------------------------------------------------------------------

local Listen

-- Runs one part for one plate. A part that is stopped, or a module that is off, runs with `on` false, which hides its text; a part that stops
-- hides its text on every plate.
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

-- Both texts of a plate. full: the plate was shown or laid out, so the font is read again.
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

-- The plate of the unit whose target changed, or every plate when the client withholds which unit it was. Only nameplate units have one.
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

-- UNIT_TARGET comes for every unit in a fight (UnitDocumentation.lua:4869-4877), so a frame of the addon's own hears it only while the enemy's
-- target can show: the module and the row on, and with Only in combat only in a fight, as the threat list hears its events (Threat.lua).
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

-- A plate's threat changed, came or went: its value takes the new colour and both texts are drawn again. A state that went may be the core
-- going off.
function OnChange(unitFrame, state)
	if ns.IsPlate(unitFrame) then
		Draw(unitFrame)
	end
	if state == nil then
		pcall(Listen)
	end
end

-- Every threat update of a plate: the numbers move while the state stays.
function OnUpdate(unitFrame)
	if ns.IsPlate(unitFrame) then
		Draw(unitFrame)
	end
end

-- A fight starts or ends: with Only in combat the enemy's target shows or hides, and UNIT_TARGET is heard only in it. InCombatLockdown() is not yet
-- true while PLAYER_REGEN_DISABLED is handled, so the fight is the time between the two events (UnitDocumentation.lua:3887, 3893).
local function Fight(on)
	fighting = on
	pcall(Listen)
	if Opt("aggroTarget") == true and Opt("aggroTargetCombat") == true then
		ns.EachPlate(DrawTarget)
	end
end

-- Hooks into the plates --------------------------------------------------------------------------

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
		if text ~= nil then
			pcall(text.SetText, text, "")
			pcall(text.Hide, text)
		end
		rec[which .. "Shown"] = false
	end
	rec.colourFor = nil
end
-- Rows changed, the page went off or on: every plate is drawn again. The name gets its colour back from the layout of PlateText.lua, which the
-- refresh runs on every plate first.
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
end)
