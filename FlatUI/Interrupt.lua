local _, ns = ...

local BARS, GLOW = "castbars", "cooldowns"
local BARS_ROW, GLOW_ROW = "castbars.interrupt", "cooldowns.interruptGlow"
local GLOW_PART = "interrupt glow"
local RECHECK, BORDER_PX = 0.2, 2
local GOLD = { 1, 0.82, 0 }
local UNITS = { "target", "focus" }
local BOOK = { "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD" }
local OWN = { "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE", "UPDATE_SHAPESHIFT_FORM", "PLAYER_EQUIPMENT_CHANGED" }
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

local S = { class = nil, list = nil, dirty = true, checked = nil, frame = nil, book = false, pet = false, full = false, hearing = false, byUnit = false,
	petByUnit = false, glows = setmetatable({}, { __mode = "k" }), looping = false, wantLoop = false, fault = nil, range = {} }

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

local function HasCalls()
	local spells, book = C_Spell, C_SpellBook
	return type(spells) == "table" and type(spells.GetSpellCooldown) == "function" and type(book) == "table"
		and (type(book.IsSpellKnown) == "function" or type(book.IsSpellKnownOrInSpellBook) == "function")
end

local function Class()
	if S.class == nil and type(UnitClass) == "function" then
		local ok, _, class = pcall(UnitClass, "player")
		if ok and not IsSecret(class) and type(class) == "string" and class ~= "" then
			S.class = class
		end
	end
	return S.class
end

local function InterruptKind()
	for index, name in ipairs(type(ns.COOLDOWN_KINDS) == "table" and ns.COOLDOWN_KINDS or {}) do
		if name == "interrupt" then
			return index
		end
	end
	return nil
end

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

local function Bank(pet)
	local banks = type(Enum) == "table" and Enum.SpellBookSpellBank or nil
	local value = type(banks) == "table" and banks[pet and "Pet" or "Player"] or nil
	return type(value) == "number" and value or (pet and 1 or 0)
end

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

local function Far(unit)
	local now = Now()
	local kept = S.range[unit]
	if kept and now and now >= kept.at and now - kept.at < RECHECK then
		return kept.far
	end
	local call, far = type(C_Spell) == "table" and C_Spell.IsSpellInRange or nil, false
	if type(call) == "function" then
		for _, ab in ipairs(Abilities()) do
			if ab.id ~= nil and ab.usable and ab.ready == true then
				if ab.pet or Ask(call, ab.id, unit) ~= false then
					far = false
					break
				end
				far = true
			end
		end
	end
	kept = kept or {}
	kept.at, kept.far = now or 0, far
	S.range[unit] = kept
	return far
end

local function Hostile(unit)
	return Ask(UnitCanAttack, "player", unit) == true
end

local function BarsOn()
	if ns.Get(BARS_ROW) ~= true then
		return false
	end
	return ns.Enabled(BARS) or (ns.Enabled("nameplates") and ns.Get("nameplates.castFlat") == true)
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
	local ready = Ready()
	if ready == true and Far(unit) then
		return "far"
	end
	return ready
end

function ns.InterruptKnown()
	return S.full == true
end

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

function ns.InterruptCooldown()
	if not S.full then
		return nil
	end
	local call = type(C_Spell) == "table" and C_Spell.GetSpellCooldownDuration or nil
	if type(call) ~= "function" then
		return nil
	end
	local petDuration, petId = nil, nil
	for _, ab in ipairs(Abilities()) do
		if ab.id ~= nil and ab.usable and ab.ready == false then
			local ok, duration = pcall(call, ab.id, true)
			if ok and duration ~= nil then
				if not ab.pet then
					return duration, ab.id
				elseif petDuration == nil then
					petDuration, petId = duration, ab.id
				end
			end
		end
	end
	return petDuration, petId
end

local function GlowOn()
	return ns.Enabled(GLOW) and ns.Get(GLOW_ROW) == true and not ns.PartStopped(GLOW, GLOW_PART)
end

local function Lit()
	for _, glow in pairs(S.glows) do
		if glow.ability ~= nil then
			return true
		end
	end
	return false
end

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
		Paint(glow.layers.target, ready and targetCast and not Far("target"), targetLocked)
		Paint(glow.layers.focus, ready and focusCast and not Far("focus"), focusLocked)
	end
	Loop(on and (targetCast or focusCast))
end

local function RunGlows()
	if not ns.EachPart(GLOW, GLOW_PART, Glows, {}) then
		Dark()
		S.wantLoop = false
	end
end

local Tick

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

function ns.InterruptSpell(id)
	if IsSecret(id) or type(id) ~= "number" then
		return false
	end
	local ok, ab = pcall(AbilityOf, id)
	return ok and ab ~= nil
end

local Sync

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

local function PetClass()
	for _, ab in ipairs(Abilities()) do
		if ab.pet then
			return true
		end
	end
	return false
end

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

function Sync()
	local able = HasCalls() and #Abilities() > 0
	local wanted = able and (BarsOn() or (GlowOn() and Lit()))
	local level = 0
	if wanted then
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
	if type(ns.CastKickSync) == "function" then
		ns.CastKickSync()
	end
end

local function SafeSync()
	local ok, err = pcall(Sync)
	if not ok then
		S.fault = S.fault or tostring(err)
	end
end
ns.InterruptSync = SafeSync

function ns.InterruptChanged()
	SafeSync()
	if type(ns.CastTimeSync) == "function" then
		pcall(ns.CastTimeSync)
	end
end

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
			if ready == true and Hostile("target") and Far("target") then
				word = word .. ", out of range of your target"
			end
			lines[1] = ("Interrupt: %s, %s."):format(table.concat(names, " and "), word)
		end
	end
	if S.fault then
		lines[#lines + 1] = "Interrupt: a look at your interrupt failed, so a cast bar or the cooldown row may not show it. " .. S.fault
	end
	return lines
end)
