local _, ns = ...

-- Interrupt ready: whether the player's class interrupt can be used now. Two things show it. An enemy's cast that can be interrupted takes one of
-- two colours of the Colours page on the flat target, focus and nameplate cast bars (Bars.lua asks ns.InterruptReady for each bar it paints), and
-- the game's look for a cast that cannot be interrupted stays. The icon of the interrupt in the cooldown row gets a gold border while the target
-- or the focus casts something it can stop and the interrupt is ready (Cooldowns.lua hands its icons to ns.InterruptIcons).
-- The interrupts are those of CooldownData.lua (the kind "interrupt") of the player's class, every rank: Pummel and Shield Bash, Kick, Earth Shock,
-- Counterspell, Silence, Feral Charge, and the Felhunter's Spell Lock, asked in the pet's book (SpellBookDocumentation.lua:738-771). A class with
-- none known, a Hunter or a Paladin, shows nothing. The first rank of the list the book knows stands for them all, and an icon of any rank, or of
-- the same name as Cooldowns.lua joins ranks, is the interrupt's. One counts while the game says it can be cast now or could be with more power
-- (C_Spell.IsSpellUsable, SpellDocumentation.lua:980-995): Pummel out of Berserker Stance and Shield Bash without a shield do not.
-- Ready is a plain answer: GetSpellCooldown never withholds isEnabled, isActive and isOnGCD (SpellSharedDocumentation.lua:19-31), though it withholds
-- the times in a fight (SpellDocumentation.lua:309-325), and an interrupt is ready while its cooldown is off or is the global cooldown alone, as the
-- game's cooldown manager tells the two apart (CooldownViewer.lua:986-993). isOnGCD is to be trusted only in SPELL_UPDATE_COOLDOWN
-- (SpellSharedDocumentation.lua:30), so only that event turns an interrupt to not ready. No event comes when a cooldown runs out (the game's
-- cooldown manager refreshes itself then, CooldownViewer.lua:517-519), so between events a look, at most every 0.2 s while a bar, the row or
-- /flatui status asks, turns it back to ready once its cooldown is over. A withheld answer is no answer: the bars keep their colours and no border
-- shows.
-- Whether a cast can be interrupted is withheld for every unit but the player and the pet (UnitDocumentation.lua:828-893,
-- SecretPredicatesDocumentation.lua:115-118). It goes to the texture untouched, as the shield of a bar does (Bars.lua, SetVertexColorFromBoolean),
-- and to the border with SetAlphaFromBoolean (SimpleFrameAPIDocumentation.lua:1145-1155; SetShown takes no withheld value from an addon,
-- UnitFrameUtil.lua:487). Nothing is written on a frame of the game's: the colours are on Flat UI's covers, the border is on Flat UI's icons, and
-- the casts of the target and the focus are only heard. Not a module: the colours belong to the cast bars, the border to the cooldown row.
-- This follows the interrupt colours of EnhanceQoL by Philipp Barth (UF.lua:9385-9457, UF_StandaloneCastbar.lua:1345-1442,
-- FocusInterruptTracker.lua:697-899) and its interrupt glow (CooldownPanels.lua:1971-2006), adapted with his permission.

local BARS, GLOW = "castbars", "cooldowns"
local BARS_ROW, GLOW_ROW = "castbars.interrupt", "cooldowns.interruptGlow"
local GLOW_PART = "interrupt glow"
-- Seconds between two looks at an interrupt on cooldown, and the width of the border in screen pixels (the mark of an action button).
local RECHECK, BORDER_PX = 0.2, 2
-- The gold of the game's proc glow, as ProcGlow.lua has it.
local GOLD = { 1, 0.82, 0 }
local UNITS = { "target", "focus" }
-- What makes an interrupt known: the book and the world, and the pet (UNIT_PET) for a class whose interrupt is the pet's. Once one is known, what
-- changes it: its cooldown, what can be cast, the stance or form, the shield.
local BOOK = { "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD" }
local OWN = { "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE", "UPDATE_SHAPESHIFT_FORM", "PLAYER_EQUIPMENT_CHANGED" }
-- The casts of the target and the focus, as the game's cast bar hears them (CastingBarFrame.lua:236-249), and the change of either unit.
local CASTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
	"UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE",
	"UNIT_SPELLCAST_NOT_INTERRUPTIBLE" }
local CHANGES = { "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED" }
local CAST_EVENT = {}
for _, event in ipairs(CASTS) do
	CAST_EVENT[event] = true
end
local NO_BOOLEAN = "Interrupt glow: the game hides whether a cast can be interrupted and has no call to show it, so the border stays off."

local IsSecret = ns.IsSecret

-- class: the class file of the player. list: the interrupts of the class, each { name, ids, set, pet, id (the rank known), usable, ready }.
-- dirty: the book is to be read again. checked: when the cooldowns were last looked at. frame: the frame of the events; book, pet, full, hearing:
-- whether it hears BOOK, UNIT_PET, OWN and the casts of the two units; byUnit and petByUnit: whether the casts and UNIT_PET went by unit.
-- glows: per icon of the cooldown row, its border. looping, wantLoop: a look of the row is waiting, and is wanted. fault: the first failure of a
-- look of a bar or of an event.
local S = { class = nil, list = nil, dirty = true, checked = nil, frame = nil, book = false, pet = false, full = false, hearing = false, byUnit = false,
	petByUnit = false, glows = setmetatable({}, { __mode = "k" }), looping = false, wantLoop = false, fault = nil }

-- The first answer of a game call, or nil when the call is missing, raises or is withheld.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, answer = pcall(fn, ...)
	if ok and not IsSecret(answer) then
		return answer
	end
	return nil
end

local function Now()
	local now = Ask(GetTime)
	return type(now) == "number" and now or nil
end

-- True when the client has the calls the readiness needs.
local function HasCalls()
	local spells, book = C_Spell, C_SpellBook
	return type(spells) == "table" and type(spells.GetSpellCooldown) == "function" and type(book) == "table"
		and (type(book.IsSpellKnown) == "function" or type(book.IsSpellKnownOrInSpellBook) == "function")
end

-- The class file of the player, asked until the game gives a plain one (UnitDocumentation.lua:911-928).
local function Class()
	if S.class == nil and type(UnitClass) == "function" then
		local ok, _, class = pcall(UnitClass, "player")
		if ok and not IsSecret(class) and type(class) == "string" and class ~= "" then
			S.class = class
		end
	end
	return S.class
end

-- The index of the kind "interrupt" in CooldownData.lua.
local function InterruptKind()
	for index, name in ipairs(type(ns.COOLDOWN_KINDS) == "table" and ns.COOLDOWN_KINDS or {}) do
		if name == "interrupt" then
			return index
		end
	end
	return nil
end

-- The interrupts of the player's class, made once the class is known.
local function Abilities()
	if S.list ~= nil then
		return S.list
	end
	local class, data, byClass, kind = Class(), ns.ABILITIES, ns.ABILITIES_BY_CLASS, InterruptKind()
	if class == nil or type(data) ~= "table" or type(byClass) ~= "table" or kind == nil then
		return {}
	end
	local list = {}
	for _, index in ipairs(type(byClass[class]) == "table" and byClass[class] or {}) do
		local a = data[index]
		if type(a) == "table" and a.kind == kind and type(a.casts) == "table" and #a.casts > 0 then
			local set = {}
			for _, id in ipairs(a.casts) do
				set[id] = true
			end
			list[#list + 1] = { name = a.name, ids = a.casts, set = set, pet = type(a.flags) == "string" and a.flags:find("p", 1, true) ~= nil }
		end
	end
	S.list = list
	return list
end

local function SpellName(id)
	local name = Ask(C_Spell.GetSpellName, id)
	return type(name) == "string" and name ~= "" and name or nil
end

-- The book of the player or of the pet (SpellBookConstantsDocumentation.lua:35-45), Player 0 and Pet 1 where the client gives no enum.
local function Bank(pet)
	local banks = type(Enum) == "table" and Enum.SpellBookSpellBank or nil
	local value = type(banks) == "table" and banks[pet and "Pet" or "Player"] or nil
	return type(value) == "number" and value or (pet and 1 or 0)
end

-- The first rank of the list the book knows: the ranks are listed highest first.
local function KnownRank(ab)
	local book, bank = C_SpellBook, Bank(ab.pet)
	for _, id in ipairs(ab.ids) do
		local known = Ask(book.IsSpellKnown, id, bank)
		if known == nil then
			known = Ask(book.IsSpellKnownOrInSpellBook, id, bank)
		end
		if known == true then
			return id
		end
	end
	return nil
end

-- True while the game says the interrupt can be cast, or could be with more power. A pet's ability, a missing call and a withheld answer count.
local function Usable(ab)
	if ab.id == nil then
		return false
	end
	local call = C_Spell.IsSpellUsable
	if ab.pet or type(call) ~= "function" then
		return true
	end
	local ok, usable, short = pcall(call, ab.id)
	if not ok or IsSecret(usable) or IsSecret(short) then
		return true
	end
	return usable == true or short == true
end

-- True while the cooldown of a spell is off or is the global cooldown alone, false while it runs or is held (isEnabled false), nil when the game
-- gives no plain answer.
local function Fresh(id)
	local info = Ask(C_Spell.GetSpellCooldown, id)
	if type(info) ~= "table" then
		return nil
	end
	local enabled, active, gcd = info.isEnabled, info.isActive, info.isOnGCD
	if IsSecret(enabled) or IsSecret(active) or IsSecret(gcd) then
		return nil
	end
	if enabled == false then
		return false
	end
	return active ~= true or gcd == true
end

local function ScanKnown()
	for _, ab in ipairs(Abilities()) do
		local id = KnownRank(ab)
		if id ~= ab.id then
			ab.id, ab.ready = id, nil
		end
	end
end

local function ScanUsable()
	for _, ab in ipairs(Abilities()) do
		ab.usable = Usable(ab)
	end
end

-- trusted: inside SPELL_UPDATE_COOLDOWN, where isOnGCD can be trusted. Elsewhere an answer only gives a first one or turns an interrupt to ready.
local function ScanCooldowns(trusted)
	for _, ab in ipairs(Abilities()) do
		if ab.id ~= nil then
			local fresh = Fresh(ab.id)
			if trusted or ab.ready == nil or fresh == true then
				ab.ready = fresh
			end
		end
	end
	S.checked = Now()
end

local function Rescan()
	S.dirty = false
	if not HasCalls() then
		return
	end
	ScanKnown()
	ScanUsable()
	ScanCooldowns(false)
end

-- A look between events, at most every RECHECK seconds: an interrupt whose cooldown is over is ready again.
local function Recheck()
	if S.dirty then
		Rescan()
		return
	end
	local now = Now()
	if now ~= nil and S.checked ~= nil and now >= S.checked and now - S.checked < RECHECK then
		return
	end
	S.checked = now
	for _, ab in ipairs(Abilities()) do
		if ab.id ~= nil and ab.ready == false and Fresh(ab.id) == true then
			ab.ready = true
		end
	end
end

local function Known()
	for _, ab in ipairs(Abilities()) do
		if ab.id ~= nil then
			return true
		end
	end
	return false
end

-- True while an interrupt that can be cast is ready, false while every one that can be cast is on cooldown, nil when none is known or can be
-- cast, or the game will not say.
local function Ready()
	local answer = nil
	for _, ab in ipairs(Abilities()) do
		if ab.id ~= nil and ab.usable then
			if ab.ready == true then
				return true
			elseif ab.ready == false then
				answer = false
			end
		end
	end
	return answer
end

-- A unit the player can attack (UnitDocumentation.lua:763-772). No answer, or a withheld one, is a friend.
local function Hostile(unit)
	return Ask(UnitCanAttack, "player", unit) == true
end

-- The cast bars ---------------------------------------------------------------------------------------------------------

-- The row is on, and a bar has a cover to colour: the flat fill of the Cast bars page or of the nameplates (Bars.lua, ns.CastFill).
local function BarsOn()
	if ns.Get(BARS_ROW) ~= true then
		return false
	end
	return (ns.Enabled(BARS) and ns.Get("castbars.flat") == true) or (ns.Enabled("nameplates") and ns.Get("nameplates.castFlat") == true)
end

local function Answer(unit)
	if IsSecret(unit) or type(unit) ~= "string" then
		return nil
	end
	if S.dirty then
		Rescan()
	end
	if not Known() or not Hostile(unit) then
		return nil
	end
	Recheck()
	return Ready()
end

-- For Bars.lua, each frame it paints the cover of a cast or a channel: true or false for the bar of `unit` while that unit is an enemy and Colour
-- enemy casts by your interrupt is on, nil for every other bar, which keeps its colours. It never raises.
function ns.InterruptReady(unit)
	if not S.full or not BarsOn() then
		return nil
	end
	local ok, answer = pcall(Answer, unit)
	if ok then
		return answer
	end
	S.fault = S.fault or tostring(answer)
	return nil
end

-- The border on the cooldown row -----------------------------------------------------------------------------------------

local function GlowOn()
	return ns.Enabled(GLOW) and ns.Get(GLOW_ROW) == true and not ns.PartStopped(GLOW, GLOW_PART)
end

-- True while an icon of the row is the class interrupt.
local function Lit()
	for _, glow in pairs(S.glows) do
		if glow.ability ~= nil then
			return true
		end
	end
	return false
end

-- Whether a unit the player can attack casts or channels, and whether that cast cannot be interrupted, plain or withheld (the eighth answer of
-- UnitCastingInfo, the seventh of UnitChannelInfo: UnitDocumentation.lua:847, 888). False for no cast and for a friend.
local function Casting(unit)
	if not Hostile(unit) then
		return false
	end
	local ok, name, _, _, _, _, _, _, locked = pcall(UnitCastingInfo, unit)
	if ok and not IsSecret(name) and name == nil then
		ok, name, _, _, _, _, _, locked = pcall(UnitChannelInfo, unit)
	end
	if not ok or (not IsSecret(name) and name == nil) then
		return false
	end
	return true, locked
end

-- One unit's border on one icon: hidden, shown, or as the game's withheld answer says, hidden when the cast cannot be interrupted.
local function Paint(layer, cast, locked)
	if not cast then
		layer:SetAlpha(0)
	elseif IsSecret(locked) then
		if not (layer.SetAlphaFromBoolean and pcall(layer.SetAlphaFromBoolean, layer, locked, 0, 1)) then
			layer:SetAlpha(0)
			ns.Note(GLOW, NO_BOOLEAN)
		end
	else
		layer:SetAlpha(locked == true and 0 or 1)
	end
end

local function Dark()
	for _, glow in pairs(S.glows) do
		for _, unit in ipairs(UNITS) do
			pcall(glow.layers[unit].SetAlpha, glow.layers[unit], 0)
		end
	end
end

local Loop

-- Every border of the row from the interrupt and the casts of the target and the focus.
local function Glows()
	local on = GlowOn() and Lit()
	local targetCast, targetLocked, focusCast, focusLocked = false, nil, false, nil
	if on then
		if S.dirty then
			Rescan()
		end
		targetCast, targetLocked = Casting("target")
		focusCast, focusLocked = Casting("focus")
		if targetCast or focusCast then
			Recheck()
		end
	end
	for _, glow in pairs(S.glows) do
		local ab = glow.ability
		local ready = on and ab ~= nil and ab.id ~= nil and ab.usable == true and ab.ready == true
		Paint(glow.layers.target, ready and targetCast, targetLocked)
		Paint(glow.layers.focus, ready and focusCast, focusLocked)
	end
	Loop(on and (targetCast or focusCast))
end

-- The row's borders inside its part: one that keeps failing stops the part, and a failure takes every border away.
local function RunGlows()
	if not ns.EachPart(GLOW, GLOW_PART, Glows, {}) then
		Dark()
		S.wantLoop = false
	end
end

local Tick

-- While the target or the focus casts, the row is looked at every RECHECK seconds (C_Timer.After): the interrupt may be ready again in the middle
-- of the cast, and the end of a cast the events missed takes the border away. It stops once neither casts.
function Loop(wanted)
	S.wantLoop = wanted
	if wanted and not S.looping and type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		S.looping = pcall(C_Timer.After, RECHECK, Tick)
	end
end

function Tick()
	S.looping = false
	if S.wantLoop and S.hearing then
		RunGlows()
	end
end

-- The border of one icon: a frame above its sweep with one layer for each unit, each a gold outline of Flat UI's, hidden until wanted.
local function MakeGlow(frame, top)
	local holder = CreateFrame("Frame", nil, frame)
	ns.Own[holder] = true
	holder:SetAllPoints(frame)
	local above = top or frame
	local level = Ask(above.GetFrameLevel, above)
	if type(level) == "number" then
		holder:SetFrameLevel(level + 1)
	end
	local glow = { holder = holder, layers = {} }
	for _, unit in ipairs(UNITS) do
		local layer = CreateFrame("Frame", nil, holder)
		ns.Own[layer] = true
		layer:SetAllPoints(holder)
		layer:SetAlpha(0)
		local outline = ns.Outline(layer, layer)
		ns.SetOutline(outline, true, false)
		ns.SetOutlineColour(outline, GOLD[1], GOLD[2], GOLD[3])
		ns.SetOutlineThickness(outline, BORDER_PX)
		glow.layers[unit] = layer
	end
	return glow
end

-- The interrupt an icon of the cooldown row shows: a rank of one, or a spell of the same name.
local function AbilityOf(spell)
	local list = Abilities()
	if #list == 0 then
		return nil
	end
	for _, ab in ipairs(list) do
		if ab.set[spell] then
			return ab
		end
	end
	local name = SpellName(spell)
	if name == nil then
		return nil
	end
	for _, ab in ipairs(list) do
		if SpellName(ab.id or ab.ids[1]) == name then
			return ab
		end
	end
	return nil
end

-- The events --------------------------------------------------------------------------------------------------------------

local Sync

-- An event of the player's own. A change of the book or the pet may make an interrupt known or unknown, and so what is heard.
local function Own(event)
	if event == "SPELL_UPDATE_COOLDOWN" then
		if S.dirty then
			Rescan()
		end
		if HasCalls() then
			ScanCooldowns(true)
		end
	elseif event == "SPELL_UPDATE_USABLE" or event == "UPDATE_SHAPESHIFT_FORM" or event == "PLAYER_EQUIPMENT_CHANGED" then
		if S.dirty then
			Rescan()
		elseif HasCalls() then
			ScanUsable()
		end
	else
		Rescan()
		Sync()
	end
end

-- The first value of an event is its unit, tested only when the event was registered for every unit.
local function OnEvent(_, event, unit)
	if CAST_EVENT[event] then
		if not S.byUnit and (IsSecret(unit) or (unit ~= "target" and unit ~= "focus")) then
			return
		end
	elseif event == "UNIT_PET" and not S.petByUnit and (IsSecret(unit) or unit ~= "player") then
		return
	elseif event ~= "PLAYER_TARGET_CHANGED" and event ~= "PLAYER_FOCUS_CHANGED" then
		local ok, err = pcall(Own, event)
		if not ok then
			S.fault = S.fault or tostring(err)
		end
	end
	if S.hearing then
		RunGlows()
	end
end

-- Registers an event for the units given where the client can, else for every unit. True when it went by unit.
local function Hear(event, ...)
	local frame = S.frame
	if frame.RegisterUnitEvent then
		local ok, registered = pcall(frame.RegisterUnitEvent, frame, event, ...)
		if ok and (IsSecret(registered) or registered ~= false) then
			return true
		end
	end
	pcall(frame.RegisterEvent, frame, event)
	return false
end

local function HearList(list, on)
	for _, event in ipairs(list) do
		pcall(on and S.frame.RegisterEvent or S.frame.UnregisterEvent, S.frame, event)
	end
end

-- True when the interrupt of the class is the pet's (the Felhunter's Spell Lock).
local function PetClass()
	for _, ab in ipairs(Abilities()) do
		if ab.pet then
			return true
		end
	end
	return false
end

-- level 0 hears nothing, 1 the book, the world and the pet (BOOK), 2 the player's cooldowns, casts and stance too (OWN). hear: the casts of the
-- target and the focus as well. No frame is made until one is wanted.
local function Listen(level, hear)
	if level > 0 and S.frame == nil then
		S.frame = CreateFrame("Frame")
		ns.Own[S.frame] = true
		S.frame:SetScript("OnEvent", OnEvent)
	end
	if S.frame == nil then
		return
	end
	hear = level > 1 and hear or false
	if hear ~= S.hearing then
		if hear then
			for _, event in ipairs(CASTS) do
				S.byUnit = Hear(event, "target", "focus")
			end
		else
			HearList(CASTS, false)
		end
		HearList(CHANGES, hear)
		S.hearing = hear
	end
	local full = level > 1
	if full ~= S.full then
		HearList(OWN, full)
		S.full = full
		-- A cooldown that starts while SPELL_UPDATE_COOLDOWN is not heard is not seen: the next answer is a first one.
		if not full then
			for _, ab in ipairs(Abilities()) do
				ab.ready = nil
			end
		end
	end
	local book = level > 0
	if book ~= S.book then
		HearList(BOOK, book)
		S.book = book
	end
	local pet = book and PetClass()
	if pet ~= S.pet then
		if pet then
			S.petByUnit = Hear("UNIT_PET", "player")
		else
			HearList({ "UNIT_PET" }, false)
		end
		S.pet = pet
	end
end

-- What is wanted now, from the rows, the modules and the book: nothing; the book while the bars or the row could show an interrupt the player does
-- not know yet; the player's own events once one is known; the casts of the two units while the row shows one. Called by Bars.lua when the cast
-- bars apply their settings, by the nameplates when theirs change, by the row of the Colours page, after each layout of the cooldown row, and
-- when the book or the pet changes.
function Sync()
	local able = HasCalls() and #Abilities() > 0
	local wanted = able and (BarsOn() or (GlowOn() and Lit()))
	local level = 0
	if wanted then
		-- What was read while the book was not heard may be old.
		if S.dirty or not S.book then
			Rescan()
		end
		level = Known() and 2 or 1
	end
	local glow = level > 1 and GlowOn() and Lit()
	Listen(level, glow)
	if glow then
		RunGlows()
	else
		Dark()
		S.wantLoop = false
	end
end

-- Sync for the code of other files: it runs inside the refresh of the cast bars, which an error would stop, so a failure is only kept for the status.
local function SafeSync()
	local ok, err = pcall(Sync)
	if not ok then
		S.fault = S.fault or tostring(err)
	end
end
ns.InterruptSync = SafeSync

-- The row Interrupt readiness on enemy casts changed: the covers read it on their next frame, and the events start or stop.
function ns.InterruptChanged()
	SafeSync()
end

-- For Cooldowns.lua, after each layout of the row, out of combat: its icons, each { frame, spell, top }, top the frame above the icon's sweep. The
-- icons of the class interrupt get a border, made once; the others lose theirs.
function ns.InterruptIcons(list)
	local mine = {}
	if HasCalls() and type(list) == "table" then
		for _, entry in ipairs(list) do
			local frame = type(entry) == "table" and entry.frame or nil
			local spell = type(entry) == "table" and entry.spell or nil
			if type(frame) == "table" and not IsSecret(frame) and type(spell) == "number" and not IsSecret(spell) then
				local ab = AbilityOf(spell)
				local glow = ab and S.glows[frame]
				if ab and glow == nil then
					local ok, made = pcall(MakeGlow, frame, entry.top)
					if ok then
						glow = made
						S.glows[frame] = made
					else
						ns.Note(GLOW, "Interrupt glow: an icon could not take its border. " .. tostring(made))
					end
				end
				if glow then
					glow.ability = ab
					mine[frame] = true
				end
			end
		end
	end
	for frame, glow in pairs(S.glows) do
		if not mine[frame] then
			glow.ability = nil
		end
	end
	SafeSync()
end

if type(ns.PlateExtra) == "table" and type(ns.PlateExtra.refresh) == "table" then
	ns.PlateExtra.refresh[#ns.PlateExtra.refresh + 1] = SafeSync
end

-- One line while an interrupt is known: its name and whether it is ready. A failure has a line of its own. The line takes the look the bars and
-- the row take first (Recheck, which reads the book again while it is dirty): a cooldown that ran out while no bar or row asked sent no event
-- (CooldownViewer.lua:517-519), so without it the line would still say on cooldown.
ns.AddStatus(BARS, function()
	local lines = {}
	if S.full then
		pcall(Recheck)
		local names = {}
		for _, ab in ipairs(Abilities()) do
			if ab.id ~= nil then
				names[#names + 1] = SpellName(ab.id) or ab.name
			end
		end
		if #names > 0 then
			local ready = Ready()
			local word = ready == true and "ready" or ready == false and "on cooldown" or "not usable now"
			lines[1] = ("Interrupt: %s, %s."):format(table.concat(names, " and "), word)
		end
	end
	if S.fault then
		lines[#lines + 1] = "Interrupt: a look at your interrupt failed, so a cast bar or the cooldown row may not show it. " .. S.fault
	end
	return lines
end)
