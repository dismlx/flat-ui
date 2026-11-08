local _, ns = ...

-- Heal over time squares (off by default, All frames: icons and auras, Party and raid frames): on the game's party and raid frames, a small square of
-- Flat UI's own in a corner of the member's health bar for each heal over time of yours on that member, each in a colour of its own, as healers' raid
-- frames have them. The game's raid frames show your heals over time among the member's buff icons (displayBuffs, Shared/CompactUnitFrame.lua:1650;
-- Mainline/CompactUnitFrameOptions.lua:17), its party frames do not, and neither tells them apart at a glance.
--
-- The heals over time are those of the player's class on Forever, each found by the name the client gives one of its spells, so every rank counts:
-- Renew (139) for a priest; Rejuvenation (774), Regrowth (8936), and the runes Lifebloom (408124) and Wild Growth (408120) for a druid; the rune
-- Riptide (408521) for a shaman. Every rank of Rejuvenation and Regrowth is in ProcData.lua, which is read from the DB2 tables of build 1.60.1;
-- Renew's ranks and the three runes are in the client's SkillLineAbility table (Holy 56, the druid runes 573, Restoration 374). A spell the client
-- does not name (C_Spell.GetSpellName gives nil for one it does not have, SpellDocumentation.lua:518-533) has no square, so each is checked in the game.
-- A class without one, or a client that does not read auras by slot, makes nothing. Each heal over time has a place of its own in a row from the
-- corner (Square corner), so a square never moves while the others come and go; Square size is its side in units, with a dark rim of one screen pixel,
-- and the row sits just inside the dispel border of UnitGroupMarks.lua (2 screen pixels inside the health bar).
--
-- What shows is read only from the auras the game lets addons read. C_UnitAuras.GetAuraSlots(unit, "HELPFUL|PLAYER") gives the slots of the buffs
-- the player (or the player's pet) cast on the member (AuraUtil.lua:272-274) and carries no secret predicate (UnitAuraDocumentation.lua:304-322);
-- GetAuraDataBySlot is withheld while auras are restricted (SecretWhenUnitAuraRestricted, UnitAuraDocumentation.lua:227-243): in a fight, an
-- encounter, a challenge mode or a PvP match, unless the game flags the spell as never secret (SecretPredicatesDocumentation.lua:80-82). A withheld
-- aura, or one whose spell ID is withheld, shows nothing and is never read further; the member is read again when the fight or the restriction ends
-- (PLAYER_REGEN_ENABLED, and ADDON_RESTRICTION_STATE_CHANGED with Inactive, RestrictedActionsDocumentation.lua:96-107), as UnitGroupMarks.lua reads
-- its debuffs again. A square read before the fight stays while the member's auras do not change, since each change sends UNIT_AURA. Each frame
-- hears UNIT_AURA for its own unit on a frame of the addon's own (RegisterUnitEvent), whose payload is never read; a burst is read once, a moment
-- after the first. A frame the game hid hears nothing until the game draws it again, through the same calls UnitGroupMarks.lua follows.
--
-- The squares are textures of the addon's own on a frame of its own over the health bar, made and placed out of combat on a frame the game protects;
-- in a fight only whether each shows changes. A new Square corner or Square size waits for the end of a fight. Nothing of the game's is changed.
-- This follows EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission (EnhanceQoLUnitFrames/UF_GroupFrames_HealerBuffs.lua:250-253, 260,
-- 270, its heal over time families of Renew, Rejuvenation, Regrowth, Lifebloom, Wild Growth and Riptide; :1923-1949, a heal over time counts only when
-- it is the player's (HELPFUL|PLAYER) and a withheld spell ID counts for none; :2324-2339, its Square style, a white texture in the colour of each):
-- its square indicators on group frames, here on the game's frames. Its retail spell IDs of Lifebloom, Wild Growth and Riptide are Forever's runes
-- here; its rules, its other styles and its editor are left out.

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART = "Heal over time squares"
local FILTER = "HELPFUL|PLAYER"
local WHITE = "Interface\\Buttons\\WHITE8X8"
-- The dispel border's thickness in screen pixels (UnitGroupMarks.lua), which the row stays inside, the wait before a burst of events is read, and
-- how many times a read asks the game for more slots.
local RIM_PX, SOON, MOST_ASKS = 2, 0.1, 4
-- The heals over time of each class by the class file UnitClass gives, in the order of their places from the corner: the spell the name comes from,
-- and the colour of its square with the word /flatui status says for it.
local HOTS = {
	PRIEST = { { id = 139, colour = { 0.3, 0.9, 0.35 }, word = "green" } },
	DRUID = { { id = 774, colour = { 0.75, 0.3, 1 }, word = "purple" }, { id = 8936, colour = { 0.3, 0.9, 0.35 }, word = "green" },
		{ id = 408124, colour = { 1, 0.85, 0.2 }, word = "yellow" }, { id = 408120, colour = { 0.2, 0.8, 0.9 }, word = "teal" } },
	SHAMAN = { { id = 408521, colour = { 0.25, 0.55, 1 }, word = "blue" } },
}
-- The point of the health bar each Square corner puts the first square on, and the signs of its offsets across and up, which keep the row inside.
local CORNERS = { tl = { "TOPLEFT", 1, -1 }, tr = { "TOPRIGHT", -1, -1 }, bl = { "BOTTOMLEFT", 1, 1 }, br = { "BOTTOMRIGHT", -1, 1 } }
local NOTE_KEPT = "Unit frames: Heal over time squares: the game keeps your auras on a member from addons now, so its squares wait for the end of the fight."

local IsSecret = ns.IsSecret

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

-- The heals over time --------------------------------------------------------------------------------------------------------------------------

-- kinds: the heals over time of the player's class that the client names, { name, colour, word }, nil until the class is known. byName: the place of
-- each by its name. byId: the place of each spell ID read so far, false for one that is none of them.
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

-- The class file of the player, plain (UnitClass, UnitDocumentation.lua:911-928), or nil.
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

-- The place of the heal over time a spell ID is, or false.
local function KindOf(id)
	local kind = byId[id]
	if kind == nil then
		local name = SpellName(id)
		kind = name and byName[name] or false
		byId[id] = kind
	end
	return kind
end

-- True when the client has the calls that read the auras of a unit by slot. Without them nothing is made.
local function Readable()
	local units = C_UnitAuras
	return type(units) == "table" and not IsSecret(units) and type(units.GetAuraSlots) == "function" and type(units.GetAuraDataBySlot) == "function"
end

-- Reading a member --------------------------------------------------------------------------------------------------------------------------------

-- One aura of the player's on a unit: the place of its heal over time, false for another aura or a slot that went, or nil when the game withheld it.
local function KindOfSlot(unit, slot)
	if not ns.Finite(slot) then
		return nil
	end
	local got, aura = pcall(C_UnitAuras.GetAuraDataBySlot, unit, slot)
	if not got or IsSecret(aura) then
		return nil
	elseif aura == nil then
		-- The slot went between the two calls (AuraUtil.lua:100).
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
	return KindOf(id)
end

-- The slots of one answer of GetAuraSlots: its continuation token first, then the slots (AuraUtil.lua:93-114). Marks the heals over time found and
-- returns the token to ask with again (nil when the answer was the last) and whether one aura was withheld.
local function Batch(found, unit, ok, token, ...)
	if not ok or IsSecret(token) then
		return nil, true
	end
	local withheld = false
	for index = 1, select("#", ...) do
		local kind = KindOfSlot(unit, (select(index, ...)))
		if kind == nil then
			withheld = true
		elseif kind then
			found[kind] = true
		end
	end
	if not ns.Finite(token) then
		token = nil
	end
	return token, withheld
end

-- The heals over time of the player's on a unit, by place, and whether the game withheld any of the player's auras there.
local function Scan(unit)
	local found, withheld, token = {}, false, nil
	for _ = 1, MOST_ASKS do
		local more
		token, more = Batch(found, unit, pcall(C_UnitAuras.GetAuraSlots, unit, FILTER, nil, token))
		withheld = withheld or more
		if token == nil then
			break
		end
	end
	return found, withheld
end

-- A line for /flatui status while a frame waits for auras the game withheld: the frames it holds for.
local keeping = setmetatable({}, { __mode = "k" })

local function Say(rec, on)
	keeping[rec] = on or nil
	if next(keeping) ~= nil then
		ns.Note(KEY, NOTE_KEPT)
	else
		ns.ClearNote(KEY, NOTE_KEPT)
	end
end

-- The rows that apply to a frame now: a party or raid frame Flat UI styles, the row on, the part not stopped, a client that reads auras by slot and a
-- class with a heal over time the client names.
local function Wanted(rec, on)
	return on and rec.made and (rec.kind == "party" or rec.kind == "raid") and not ns.PartStopped(KEY, PART) and Opt("hotSquares") == true
		and Readable() and #Kinds() > 0
end

-- The unit a frame shows: the one a raid frame displays (a vehicle), else its own (UnitGroupMarks.lua does the same).
local function UnitOfFrame(rec)
	local ok, shown = pcall(function()
		return rec.frame.displayedUnit
	end)
	if ok and not IsSecret(shown) and type(shown) == "string" and shown ~= "" then
		return shown
	end
	return X.unitOf(rec)
end

-- True when the game hid the frame itself, read from its own flag as UnitGroupMarks.lua reads it: nothing on it can be seen, so it hears no auras.
local function Hidden(rec)
	local ok, shown = pcall(rec.frame.IsShown, rec.frame)
	return ok and not IsSecret(shown) and shown == false
end

-- The squares ------------------------------------------------------------------------------------------------------------------------------------

-- The frame over the health bar of a frame, four levels above it (the dispel border is three, UnitGroupMarks.lua), and one square for each heal over
-- time: a dark rim and the colour inside it, a sublevel above. Made out of combat, as a child of the bar.
local function Make(rec)
	local entry = rec.byRole.health
	local box = entry and entry.target
	if box == nil or ns.Forbidden(box) then
		return nil
	end
	local ok, level = pcall(box.GetFrameLevel, box)
	local holder = X.frame(box, ok and X.number(level) and level + 4 or nil)
	holder:SetAllPoints(box)
	local h = { holder = holder, box = box, squares = {} }
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
		h.squares[index] = { back = back, fill = fill }
	end
	rec.hots = h
	return h
end

-- What the corner, the size and the screen pixel give now, as one key.
local function Key(h)
	return ("%s:%s:%.4f"):format(tostring(Opt("hotCorner")), tostring(Opt("hotSize")), ns.Pixels(h.holder, 1))
end

-- Anchors the squares out of combat, again only when the corner, the size or the size of a screen pixel changed. Each has its place in the row.
local function Place(h)
	local key = Key(h)
	if h.placed == key then
		return
	end
	h.placed = key
	local corner = CORNERS[Opt("hotCorner")] or CORNERS.tr
	local size, px = Opt("hotSize"), ns.Pixels(h.holder, 1)
	local inset = px * (RIM_PX + 1)
	for index, square in ipairs(h.squares) do
		local x = corner[2] * (inset + (index - 1) * (size + px))
		square.back:ClearAllPoints()
		square.back:SetPoint(corner[1], h.box, corner[1], x, corner[3] * inset)
		square.back:SetSize(size, size)
		square.fill:SetPoint("TOPLEFT", square.back, "TOPLEFT", px, -px)
		square.fill:SetPoint("BOTTOMRIGHT", square.back, "BOTTOMRIGHT", -px, px)
	end
end

local function Draw(h, found)
	local lit = false
	for index, square in ipairs(h.squares) do
		local on = found[index] == true
		square.back:SetShown(on)
		square.fill:SetShown(on)
		lit = lit or on
	end
	h.lit = lit or nil
end

local function Clear(h)
	h.withheld = nil
	Draw(h, {})
end

local Hear

-- Reads the unit of a frame and shows the squares of what it found. A frame with nothing to show, or that the game hid, stops hearing its unit.
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
	local found, withheld = Scan(h.unit)
	h.withheld = withheld or nil
	Say(rec, withheld)
	Draw(h, found)
end

-- The frames whose unit changed its auras, read together a moment after the first.
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

-- The frame of the addon's own that hears UNIT_AURA for the unit of one game frame, and nothing once it has no unit.
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
	h.unit, h.heard = unit, nil
	if unit == nil then
		return
	end
	if type(ear.RegisterUnitEvent) == "function" then
		local ok, done = pcall(ear.RegisterUnitEvent, ear, "UNIT_AURA", unit)
		h.heard = ok and (IsSecret(done) or done ~= false) or nil
	end
	-- A client that cannot hear one unit: every change of auras reads this frame again.
	if not h.heard then
		h.heard = pcall(ear.RegisterEvent, ear, "UNIT_AURA") or nil
	end
end

local Squares

-- Runs Squares again once the fight is over, once however often it is asked in the fight.
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
		-- Made out of combat, on a frame the game protects.
		if InCombatLockdown() then
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
		-- A new corner or size waits for the end of the fight; the squares keep their places until then.
		AfterFight(rec)
	end
	Hear(rec, h, not Hidden(rec) and UnitOfFrame(rec) or nil)
	Soon(rec)
end

-- What the game withheld is read again once the restriction that withheld it ends: the end of a fight, or of an encounter, a challenge mode or a PvP
-- match that outlasts it (as UnitGroupMarks.lua does for its debuffs).
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

-- A frame that has a new unit hears that unit and is read again.
local wasUnit = X.unitChanged
function X.unitChanged(rec)
	if wasUnit ~= nil then
		wasUnit(rec)
	end
	if rec.hots then
		X.run(PART, Squares, rec, X.active(rec))
	end
end

-- The line of /flatui status while the row is on: the heals over time of your class in their colours and the frames that show a square now.
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

-- A party frame is drawn again through UnitFrame_Update (X.unitChanged, above) and a raid frame through CompactUnitFrame_UpdateAll (after.raid), as
-- for the marks of UnitGroupMarks.lua.
table.insert(X.after.apply, { part = PART, fn = Squares })
table.insert(X.after.raid, { part = PART, fn = Squares })
