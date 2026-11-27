local _, ns = ...

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART = "Heal over time squares"
local FILTER = "HELPFUL|PLAYER"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local RIM_PX, SOON, MOST_ASKS = 2, 0.1, 4
local FADE_FOR, FADE_LOW, FADE_STEP = 3, 0.35, 0.1
local LATE = 0.5
local HOTS = {
	PRIEST = { { id = 139, colour = { 0.3, 0.9, 0.35 }, word = "green" }, { id = 17, colour = { 1, 1, 1 }, word = "white" },
		{ id = 401859, colour = { 1, 0.85, 0.2 }, word = "yellow" } },
	DRUID = { { id = 774, colour = { 0.75, 0.3, 1 }, word = "purple" }, { id = 8936, colour = { 0.3, 0.9, 0.35 }, word = "green" },
		{ id = 408124, colour = { 1, 0.85, 0.2 }, word = "yellow" }, { id = 408120, colour = { 0.2, 0.8, 0.9 }, word = "teal" } },
	SHAMAN = { { id = 408521, colour = { 0.25, 0.55, 1 }, word = "blue" }, { id = 408514, colour = { 1, 0.55, 0.1 }, word = "orange" } },
	PALADIN = { { id = 412019, colour = { 1, 0.75, 0.2 }, word = "gold" } },
}
function X.hotColours(class)
	local list = HOTS[class]
	if list == nil then
		return nil
	end
	local colours = {}
	for index, spec in ipairs(list) do
		colours[index] = { spec.colour[1], spec.colour[2], spec.colour[3] }
	end
	return colours
end
local CORNERS = { tl = { "TOPLEFT", 1, -1 }, tr = { "TOPRIGHT", -1, -1 }, bl = { "BOTTOMLEFT", 1, 1 }, br = { "BOTTOMRIGHT", -1, 1 } }
local TELL_MOVE, TELL_MAKE = "Flat UI: the heal over time squares move when the fight ends.", "Flat UI: the heal over time squares show when the fight ends."
local NOTE_KEPT = "Unit frames: Heal over time squares: the game keeps your auras on a member from addons now, so a square read before stays until one of your buffs there ends, and a new one waits for the end of the fight."

local IsSecret = ns.IsSecret

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

local kinds, byName, byId = nil, {}, {}

local function SpellName(id)
	local spells = C_Spell
	if type(spells) ~= "table" or type(spells.GetSpellName) ~= "function" then
		return nil
	end
	local ok, name = pcall(spells.GetSpellName, id)
	if ok and not IsSecret(name) and type(name) == "string" and name ~= "" then
		return name
	end
	return nil
end

local function PlayerClass()
	if type(UnitClass) ~= "function" then
		return nil
	end
	local ok, _, class = pcall(UnitClass, "player")
	if ok and not IsSecret(class) and type(class) == "string" and class ~= "" then
		return class
	end
	return nil
end

local function Kinds()
	if kinds then
		return kinds
	end
	local class = PlayerClass()
	if class == nil then
		return {}
	end
	kinds = {}
	for _, spec in ipairs(HOTS[class] or {}) do
		local name = SpellName(spec.id)
		if name and byName[name] == nil then
			kinds[#kinds + 1] = { name = name, colour = spec.colour, word = spec.word }
			byName[name] = #kinds
		end
	end
	return kinds
end

local function KindOf(id)
	local kind = byId[id]
	if kind == nil then
		local name = SpellName(id)
		kind = name and byName[name] or false
		byId[id] = kind
	end
	return kind
end

local function Readable()
	local units = C_UnitAuras
	return type(units) == "table" and not IsSecret(units) and type(units.GetAuraSlots) == "function" and type(units.GetAuraDataBySlot) == "function"
end

local function EndOf(aura)
	local ok, ends = pcall(function()
		return aura.expirationTime
	end)
	if ok and ns.Finite(ends) and ends > 0 then
		return ends
	end
	return 0
end

local function KindOfSlot(unit, slot)
	if not ns.Finite(slot) then
		return nil
	end
	local got, aura = pcall(C_UnitAuras.GetAuraDataBySlot, unit, slot)
	if not got or IsSecret(aura) then
		return nil
	elseif aura == nil then
		return false
	elseif type(aura) ~= "table" then
		return false
	end
	local ok, id = pcall(function()
		return aura.spellId
	end)
	if not ok or IsSecret(id) then
		return nil
	end
	if not ns.Finite(id) then
		return false
	end
	local kind = KindOf(id)
	return kind, kind and EndOf(aura) or nil
end

local function Batch(found, ends, unit, ok, token, ...)
	if not ok or IsSecret(token) then
		return nil, true, nil
	end
	local withheld, count = false, select("#", ...)
	for index = 1, count do
		local kind, endsAt = KindOfSlot(unit, (select(index, ...)))
		if kind == nil then
			withheld = true
		elseif kind then
			found[kind] = true
			local was = ends[kind]
			ends[kind] = (was == 0 or endsAt == 0) and 0 or math.max(was or 0, endsAt or 0)
		end
	end
	if not ns.Finite(token) then
		token = nil
	end
	return token, withheld, count
end

local function Scan(unit)
	local found, ends, withheld, token, count = {}, {}, false, nil, 0
	for _ = 1, MOST_ASKS do
		local more, slots
		token, more, slots = Batch(found, ends, unit, pcall(C_UnitAuras.GetAuraSlots, unit, FILTER, nil, token))
		withheld = withheld or more
		count = count and slots and count + slots or nil
		if token == nil then
			break
		end
	end
	return found, withheld, count, ends
end

local keeping = setmetatable({}, { __mode = "k" })

local function Say(rec, on)
	keeping[rec] = on or nil
	if next(keeping) ~= nil then
		ns.Note(KEY, NOTE_KEPT)
	else
		ns.ClearNote(KEY, NOTE_KEPT)
	end
end

local function Wanted(rec, on)
	return on and rec.made and (rec.kind == "party" or rec.kind == "raid") and not ns.PartStopped(KEY, PART) and Opt("hotSquares") == true
		and Readable() and #Kinds() > 0
end

local function UnitOfFrame(rec)
	local ok, shown = pcall(function()
		return rec.frame.displayedUnit
	end)
	if ok and not IsSecret(shown) and type(shown) == "string" and shown ~= "" then
		return shown
	end
	return X.unitOf(rec)
end

local function Hidden(rec)
	local ok, shown = pcall(rec.frame.IsShown, rec.frame)
	return ok and not IsSecret(shown) and shown == false
end

local function Make(rec)
	local entry = rec.byRole.health
	local box = entry and entry.target
	if box == nil or ns.Forbidden(box) then
		return nil
	end
	local ok, level = pcall(box.GetFrameLevel, box)
	local holder = X.frame(box, ok and X.number(level) and level + 4 or nil)
	holder:SetAllPoints(box)
	local h = { holder = holder, box = box, squares = {}, party = rec.kind == "party" }
	local px = ns.Pixels(holder, 1)
	for index, kind in ipairs(Kinds()) do
		local back = Own(holder:CreateTexture(nil, "OVERLAY", nil, 4))
		back:SetTexture(WHITE)
		back:SetVertexColor(0, 0, 0, 1)
		back:Hide()
		local fill = Own(holder:CreateTexture(nil, "OVERLAY", nil, 5))
		fill:SetTexture(WHITE)
		fill:SetVertexColor(kind.colour[1], kind.colour[2], kind.colour[3], 1)
		fill:SetPoint("TOPLEFT", back, "TOPLEFT", px, -px)
		fill:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -px, px)
		fill:Hide()
		h.squares[index] = { back = back, fill = fill, alpha = 1 }
	end
	rec.hots = h
	return h
end

local function Tall(h)
	if not h.party then
		return nil
	end
	local ok, tall = pcall(h.box.GetHeight, h.box)
	if ok and ns.Finite(tall) and tall > 0 then
		return tall
	end
	return nil
end

local function Side(h, px)
	local size, tall = tonumber(Opt("hotSize")) or 6, Tall(h)
	if tall ~= nil then
		size = math.max(2, math.min(size, tall - px * (RIM_PX + 1) - px))
	end
	return size
end

local function Key(h)
	local tall = Tall(h)
	return ("%s:%s:%.4f:%s:%s"):format(tostring(Opt("hotCorner")), tostring(Opt("hotSize")), ns.Pixels(h.holder, 1), tostring(Opt("dispelIcon")),
		tall and ("%.1f"):format(tall) or "-")
end

local ICON_ROOM = { 12, 1 }

local function Across(h, corner, px)
	if h.party and corner[2] < 0 and Opt("dispelIcon") == true then
		return ICON_ROOM[2] + px * RIM_PX + ICON_ROOM[1] + px
	end
	return px * (RIM_PX + 1)
end

local function Place(h)
	local key = Key(h)
	if h.placed == key then
		return
	end
	h.placed = key
	local corner = CORNERS[Opt("hotCorner")] or CORNERS.tr
	local px = ns.Pixels(h.holder, 1)
	local size = Side(h, px)
	local inset, from = px * (RIM_PX + 1), Across(h, corner, px)
	for index, square in ipairs(h.squares) do
		local x = corner[2] * (from + (index - 1) * (size + px))
		square.back:ClearAllPoints()
		square.back:SetPoint(corner[1], h.box, corner[1], x, corner[3] * inset)
		square.back:SetSize(size, size)
		square.fill:SetPoint("TOPLEFT", square.back, "TOPLEFT", px, -px)
		square.fill:SetPoint("BOTTOMRIGHT", square.back, "BOTTOMRIGHT", -px, px)
	end
end

local fading = setmetatable({}, { __mode = "k" })
local fader, fadeWait, fadeWaited = nil, 0, 0

local function Now()
	local ok, now = pcall(GetTime)
	if ok and ns.Finite(now) then
		return now
	end
	return nil
end

local function Fade(h, now)
	local on, soon = Opt("hotFade") == true and now ~= nil, nil
	for index, square in ipairs(h.squares) do
		local ends = h.shownEnds and h.shownEnds[index]
		local alpha = 1
		if on and square.lit and ns.Finite(ends) and ends > 0 then
			local left = ends - now
			if left < FADE_FOR then
				alpha = FADE_LOW + (1 - FADE_LOW) * math.max(0, left) / FADE_FOR
			end
			if left > 0 then
				local wait = math.max(0, left - FADE_FOR)
				soon = soon and math.min(soon, wait) or wait
			end
		end
		if square.alpha ~= alpha then
			square.alpha = alpha
			square.back:SetAlpha(alpha)
			square.fill:SetAlpha(alpha)
		end
	end
	return soon
end

local function FadeAll()
	local now, soonest = Now(), nil
	for h in pairs(fading) do
		local soon = h.lit and Fade(h, now) or nil
		if soon == nil then
			fading[h] = nil
		else
			soonest = soonest and math.min(soonest, soon) or soon
		end
	end
	fadeWaited = 0
	if soonest == nil then
		fader:Hide()
	else
		fadeWait = math.max(FADE_STEP, soonest)
	end
end

local function Faded(h)
	local soon = Fade(h, Now())
	if soon == nil then
		fading[h] = nil
		return
	end
	fading[h] = true
	if fader == nil then
		fader = Own(CreateFrame("Frame"))
		fader:Hide()
		fader:SetScript("OnUpdate", function(_, elapsed)
			fadeWaited = fadeWaited + (ns.Finite(elapsed) and elapsed or 0)
			if fadeWaited >= fadeWait then
				X.run(PART, FadeAll)
			end
		end)
	end
	if not fader:IsShown() then
		fadeWaited, fadeWait = 0, math.max(FADE_STEP, soon)
		fader:Show()
	else
		fadeWait = math.min(fadeWait, math.max(FADE_STEP, soon))
	end
end

local function Draw(h, found, ends)
	local lit = false
	for index, square in ipairs(h.squares) do
		local on = found[index] == true
		square.back:SetShown(on)
		square.fill:SetShown(on)
		square.lit = on
		lit = lit or on
	end
	h.lit = lit or nil
	h.shownEnds = lit and ends or nil
	Faded(h)
end

local function Clear(h)
	h.withheld, h.kept, h.count, h.ends = nil, nil, nil, nil
	Draw(h, {})
end

local function Merged(found, kept)
	local all = {}
	for index in pairs(kept) do
		all[index] = true
	end
	for index in pairs(found) do
		all[index] = true
	end
	return all
end

local function Live(h)
	local live, gone = {}, 0
	local ok, now = pcall(GetTime)
	local timed = ok and ns.Finite(now)
	for index in pairs(h.kept or {}) do
		local ends = h.ends and h.ends[index]
		if timed and ns.Finite(ends) and ends > 0 and ends <= now + LATE then
			gone = gone + 1
		else
			live[index] = true
		end
	end
	return live, gone
end

local Hear

local function Read(rec)
	local h = rec.hots
	if h == nil then
		return
	end
	if not Wanted(rec, X.active(rec)) or h.unit == nil or Hidden(rec) then
		Clear(h)
		Hear(rec, h, nil)
		Say(rec, false)
		return
	end
	local found, withheld, count, ends = Scan(h.unit)
	h.withheld = withheld or nil
	Say(rec, withheld)
	if not withheld then
		h.kept, h.count, h.ends = found, count, ends
	else
		local live, gone = Live(h)
		local hold = h.count and h.count - gone
		if count == nil then
			found = Merged(found, live)
		elseif h.kept and hold and count >= hold then
			found = Merged(found, live)
			if gone > 0 then
				h.kept, h.count = live, hold
			end
		else
			h.kept, h.count, h.ends = found, count, ends
		end
	end
	local times = ends
	if h.ends ~= ends then
		times = {}
		for index, at in pairs(h.ends or {}) do
			times[index] = at
		end
		for index, at in pairs(ends) do
			times[index] = at
		end
	end
	Draw(h, found, times)
end

local dirty, pending = setmetatable({}, { __mode = "k" }), false

local function Pass()
	pending = false
	local list = {}
	for rec in pairs(dirty) do
		list[#list + 1] = rec
	end
	for _, rec in ipairs(list) do
		dirty[rec] = nil
		X.run(PART, Read, rec)
	end
end

local function Soon(rec)
	dirty[rec] = true
	if pending then
		return
	end
	pending = true
	if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" or not pcall(C_Timer.After, SOON, Pass) then
		Pass()
	end
end

function Hear(rec, h, unit)
	if h.unit == unit and (h.heard or unit == nil) then
		return
	end
	local ear = h.ear
	if ear == nil then
		ear = Own(CreateFrame("Frame"))
		ear:SetScript("OnEvent", function()
			Soon(rec)
		end)
		h.ear = ear
	end
	pcall(ear.UnregisterAllEvents, ear)
	if h.unit ~= unit then
		h.kept, h.count, h.ends = nil, nil, nil
	end
	h.unit, h.heard = unit, nil
	if unit == nil then
		return
	end
	if type(ear.RegisterUnitEvent) == "function" then
		local ok, done = pcall(ear.RegisterUnitEvent, ear, "UNIT_AURA", unit)
		h.heard = ok and (IsSecret(done) or done ~= false) or nil
	end
	if not h.heard then
		h.heard = pcall(ear.RegisterEvent, ear, "UNIT_AURA") or nil
	end
end

local Squares

local told = false

local function Tell(line)
	if told or type(ns.PanelShown) ~= "function" or ns.PanelShown() ~= true then
		return
	end
	told = true
	print(line)
	ns.OutOfCombat(function()
		told = false
	end)
end

local function AfterFight(rec)
	if rec.hotsQueued then
		return
	end
	rec.hotsQueued = true
	ns.OutOfCombat(function()
		rec.hotsQueued = nil
		X.run(PART, Squares, rec, X.active(rec))
	end)
end

function Squares(rec, on)
	if rec.kind ~= "party" and rec.kind ~= "raid" then
		return
	end
	local h = rec.hots
	if not Wanted(rec, on) then
		if h then
			Clear(h)
			Hear(rec, h, nil)
		end
		Say(rec, false)
		return
	end
	if h == nil then
		if InCombatLockdown() then
			Tell(TELL_MAKE)
			AfterFight(rec)
			return
		end
		h = Make(rec)
		if h == nil then
			return
		end
		Place(h)
	elseif not InCombatLockdown() then
		Place(h)
	elseif h.placed ~= Key(h) then
		Tell(TELL_MOVE)
		AfterFight(rec)
	end
	Hear(rec, h, not Hidden(rec) and UnitOfFrame(rec) or nil)
	Soon(rec)
end

local function Reread()
	for _, rec in pairs(X.records) do
		if rec.hots and rec.hots.withheld then
			Soon(rec)
		end
	end
end

local function AurasOpenAgain(kind, state)
	local types = type(Enum) == "table" and Enum.AddOnRestrictionType or nil
	local states = type(Enum) == "table" and Enum.AddOnRestrictionState or nil
	if IsSecret(kind) or IsSecret(state) or type(types) ~= "table" or type(states) ~= "table" or state ~= states.Inactive then
		return false
	end
	return kind == types.Combat or kind == types.Encounter or kind == types.ChallengeMode or kind == types.PvPMatch
end

ns.AddEvent(KEY, "PLAYER_REGEN_ENABLED", Reread)
ns.AddEvent(KEY, "ADDON_RESTRICTION_STATE_CHANGED", Reread, AurasOpenAgain)

local wasUnit = X.unitChanged
function X.unitChanged(rec)
	if wasUnit ~= nil then
		wasUnit(rec)
	end
	if rec.hots then
		X.run(PART, Squares, rec, X.active(rec))
	end
end

ns.AddStatus(KEY, function()
	if not ns.Enabled(KEY) or ns.IsStopped(KEY) or Opt("hotSquares") ~= true then
		return {}
	end
	local list = Kinds()
	if #list == 0 then
		return { "Heal over time squares: your class has no heal over time the game names, so none shows." }
	end
	local names, lit = {}, 0
	for _, kind in ipairs(list) do
		names[#names + 1] = kind.name .. " " .. kind.word
	end
	for _, rec in pairs(X.records) do
		if rec.hots and rec.hots.lit then
			lit = lit + 1
		end
	end
	return { ("Heal over time squares: %s; on %d %s now"):format(table.concat(names, ", "), lit, lit == 1 and "frame" or "frames") }
end)

table.insert(X.after.apply, { part = PART, fn = Squares })
table.insert(X.after.raid, { part = PART, fn = Squares })
