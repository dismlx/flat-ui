local _, ns = ...

-- Heal over time squares (off by default, All frames: icons and auras, Party and raid frames): on the game's party and raid frames, a small square of
-- Flat UI's own in a corner of the member's health bar for each heal over time of yours on that member, each in a colour of its own, as healers' raid
-- frames have them. The game's raid frames show your heals over time among the member's buff icons (displayBuffs, Shared/CompactUnitFrame.lua:1650;
-- Mainline/CompactUnitFrameOptions.lua:17), its party frames do not, and neither tells them apart at a glance.
--
-- The heals over time are those of the player's class on Forever, each found by the name the client gives one of its spells, so every rank counts:
-- Renew (139), Power Word: Shield (17) and the rune Prayer of Mending (401859) for a priest; Rejuvenation (774), Regrowth (8936), and the runes
-- Lifebloom (408124) and Wild Growth (408120) for a druid; the runes Riptide (408521) and Earth Shield (408514) for a shaman; the rune Sacred Shield
-- (412019) for a paladin, whose aura is found by its name whichever of its IDs it carries (412019 or 412018, CooldownData.lua). The shields count as
-- the buffs of the player's that healers watch on a tank, and Prayer of Mending's square moves with the bounce, since the aura stays the caster's. At
-- most four for a class, the squares the drawings of the setup and test mode make (SetupDrawUnits.lua MakeMarks). Every rank of Rejuvenation and
-- Regrowth is in ProcData.lua, which is read from the DB2 tables of build 1.60.1; Renew's ranks, Lifebloom, Wild Growth and Riptide are in the
-- client's SkillLineAbility table (Holy 56, the druid runes 573, Restoration 374), Power Word: Shield's ranks, Earth Shield and Sacred Shield in
-- CooldownData.lua, Sacred Shield also in ClassData.lua (SpellName_1.60.1.70245.csv), and Power Word: Shield and Prayer of Mending in
-- tools/dev/spelltips/client_spells.json (build 70938). A spell the client does not name (C_Spell.GetSpellName
-- gives nil for one it does not have, SpellDocumentation.lua:518-533) has no square, so each is checked in the game.
-- A class without one, or a client that does not read auras by slot, makes nothing. Each heal over time has a place of its own in a row from the
-- corner (Square corner), so a square never moves while the others come and go; Square size is its side in units, with a dark rim of one screen pixel,
-- and the row sits just inside the dispel border of UnitGroupMarks.lua (2 screen pixels inside the health bar). On a party frame, whose health bar is
-- 10 units high (Blizzard_UnitFrame/Camelot/PartyMemberFrame.lua:9-11), the side is at most the bar's height less the row's inset and the dispel
-- border on the far side, so a large size picked for raid cells stays inside the bar; raid cells keep the full size. On a party frame with Debuff type icon
-- on party frames and Top right or Bottom right, the row starts just left of the spot of the type icon at the right end of the bar, so the two show
-- side by side; raid frames, where the game draws its own type icons, keep the corner.
--
-- What shows is read only from the auras the game lets addons read. C_UnitAuras.GetAuraSlots(unit, "HELPFUL|PLAYER") gives the slots of the buffs
-- the player (or the player's pet) cast on the member (AuraUtil.lua:272-274) and carries no secret predicate (UnitAuraDocumentation.lua:304-322);
-- GetAuraDataBySlot is withheld while auras are restricted (SecretWhenUnitAuraRestricted, UnitAuraDocumentation.lua:227-243): in a fight, an
-- encounter, a challenge mode or a PvP match, unless the game flags the spell as never secret (SecretPredicatesDocumentation.lua:80-82). A withheld
-- aura, or one whose spell ID is withheld, is never read further; the member is read again when the fight or the restriction ends
-- (PLAYER_REGEN_ENABLED, and ADDON_RESTRICTION_STATE_CHANGED with Inactive, RestrictedActionsDocumentation.lua:96-107), as UnitGroupMarks.lua reads
-- its debuffs again. The number of slots GetAuraSlots gives is a plain answer too, and a plain read also gives each heal over time's end
-- (expirationTime, 0 for one that never ends). So in a fight, where the game hides which aura is which, each square of the last plain read stays until
-- its time runs out, while the member has at least as many auras of yours as that read less those whose time ran out since: a Sunder, a debuff or
-- another healer's buff changes nothing, and nor does a buff of yours that comes and goes in the fight (Inspiration, a bounce of Prayer of Mending, a
-- Lifebloom), since the count to hold is never raised in the fight. A square whose time ran out goes, and the count to hold drops by one with it, so
-- a heal over time that ends on time leaves the others lit and is never counted twice. When the number drops below the count to hold one of yours
-- ended early (a shield used up), and as the game does not say which, the squares it hides go and only those read plainly now stay, the new number
-- the count to hold; a new heal over time cast in the fight waits for its end, and one recast in the fight loses its square at its old end. An end
-- sends UNIT_AURA (the aura goes), so no timer runs. Each frame
-- hears UNIT_AURA for its own unit on a frame of the addon's own (RegisterUnitEvent), whose payload is never read; a burst is read once, a moment
-- after the first. A frame the game hid hears nothing until the game draws it again, through the same calls UnitGroupMarks.lua follows.
--
-- The squares are textures of the addon's own on a frame of its own over the health bar, made and placed out of combat on a frame the game protects;
-- in a fight only whether each shows changes. A new Square corner or Square size, or Debuff type icon on party frames turned on or off, waits for
-- the end of a fight, and while the options window is open chat says so once a fight (Tell). Nothing of the game's is changed.
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
-- How soon before its end time a kept heal over time counts as run out when the member is read in a fight: the read comes the wait above after the
-- aura went, and the end the game gave and the moment it goes can differ by the server's timing.
local LATE = 0.5
-- The heals over time of each class by the class file UnitClass gives, in the order of their places from the corner: the spell the name comes from,
-- and the colour of its square with the word /flatui status says for it.
local HOTS = {
	PRIEST = { { id = 139, colour = { 0.3, 0.9, 0.35 }, word = "green" }, { id = 17, colour = { 1, 1, 1 }, word = "white" },
		{ id = 401859, colour = { 1, 0.85, 0.2 }, word = "yellow" } },
	DRUID = { { id = 774, colour = { 0.75, 0.3, 1 }, word = "purple" }, { id = 8936, colour = { 0.3, 0.9, 0.35 }, word = "green" },
		{ id = 408124, colour = { 1, 0.85, 0.2 }, word = "yellow" }, { id = 408120, colour = { 0.2, 0.8, 0.9 }, word = "teal" } },
	SHAMAN = { { id = 408521, colour = { 0.25, 0.55, 1 }, word = "blue" }, { id = 408514, colour = { 1, 0.55, 0.1 }, word = "orange" } },
	PALADIN = { { id = 412019, colour = { 1, 0.75, 0.2 }, word = "gold" } },
}
-- The colours of the squares of a class file in the order of their places, for the setup's drawing of Bex (SetupDrawUnits.lua Sample), or nil for a
-- class with none. A new list each time, so the drawing cannot change HOTS.
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
-- The point of the health bar each Square corner puts the first square on, and the signs of its offsets across and up, which keep the row inside.
local CORNERS = { tl = { "TOPLEFT", 1, -1 }, tr = { "TOPRIGHT", -1, -1 }, bl = { "BOTTOMLEFT", 1, 1 }, br = { "BOTTOMRIGHT", -1, 1 } }
-- What chat says, once a fight and only while the options window is open, when the squares wait for the end of the fight (Tell).
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

-- The end time of a plain aura (expirationTime, AuraUtil.lua), 0 for one that never ends or whose end cannot be read.
local function EndOf(aura)
	local ok, ends = pcall(function()
		return aura.expirationTime
	end)
	if ok and ns.Finite(ends) and ends > 0 then
		return ends
	end
	return 0
end

-- One aura of the player's on a unit: the place of its heal over time, false for another aura or a slot that went, or nil when the game withheld it,
-- and for a heal over time its end time (EndOf).
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
	local kind = KindOf(id)
	return kind, kind and EndOf(aura) or nil
end

-- The slots of one answer of GetAuraSlots: its continuation token first, then the slots (AuraUtil.lua:93-114). Marks the heals over time found, with
-- the end of each in ends (0 when one of them never ends, else the latest), and returns the token to ask with again (nil when the answer was the
-- last), whether one aura was withheld, and how many slots the answer gave, nil when the game gave no answer. The number of slots is plain: the call
-- carries no secret predicate.
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

-- The heals over time of the player's on a unit, by place, whether the game withheld any of the player's auras there, how many auras of the
-- player's the unit has (nil when the game would not say), and the end time of each heal over time found, by place.
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
		h.squares[index] = { back = back, fill = fill }
	end
	rec.hots = h
	return h
end

-- The height of a party frame's health bar in its units, plain, or nil (and nil on a raid frame, whose squares keep their full size).
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

-- The side of a square: Square size, and on a party frame at most the room the health bar has from the row's inset to the dispel border on its far
-- side, so a size picked for raid cells does not hang out of the 10-unit party bar over the name row or the power bar.
local function Side(h, px)
	local size, tall = tonumber(Opt("hotSize")) or 6, Tall(h)
	if tall ~= nil then
		size = math.max(2, math.min(size, tall - px * (RIM_PX + 1) - px * RIM_PX))
	end
	return size
end

-- What the corner, the size, the screen pixel, the type icon row and the height of a party frame's health bar give now, as one key.
local function Key(h)
	local tall = Tall(h)
	return ("%s:%s:%.4f:%s:%s"):format(tostring(Opt("hotCorner")), tostring(Opt("hotSize")), ns.Pixels(h.holder, 1), tostring(Opt("dispelIcon")),
		tall and ("%.1f"):format(tall) or "-")
end

-- How far across from the corner the first square sits: just inside the dispel border, or on a party frame with Debuff type icon on party frames and
-- a right-hand corner, one screen pixel left of the spot of the type icon, which UnitGroupMarks.lua puts ICON_ROOM[1] units wide, ICON_ROOM[2] unit
-- and the border in from the right end of the bar (PlaceDispel), so a square never covers the icon a healer dispels by. The spot is kept whether a
-- debuff is there or not, so the squares never move in a fight.
local ICON_ROOM = { 12, 1 }

local function Across(h, corner, px)
	if h.party and corner[2] < 0 and Opt("dispelIcon") == true then
		return ICON_ROOM[2] + px * RIM_PX + ICON_ROOM[1] + px
	end
	return px * (RIM_PX + 1)
end

-- Anchors the squares out of combat, again only when the corner, the size, the size of a screen pixel or the type icon row changed. Each has its
-- place in the row.
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
	h.withheld, h.kept, h.count, h.ends = nil, nil, nil, nil
	Draw(h, {})
end

-- The heals over time found, with those kept from the last plain read where the game withheld an aura.
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

-- The squares kept from the last plain read whose time has not run out (an end of 0 never does, nor one with no time to compare), and how many of the
-- kept ones ran out.
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
	local found, withheld, count, ends = Scan(h.unit)
	h.withheld = withheld or nil
	Say(rec, withheld)
	-- A plain read is what the member has, and is kept with the end of each. Where the game withheld an aura of yours, a kept square whose time ran
	-- out goes, and the others stay while the member has at least as many auras of yours as at the last plain read less those that ran out: fewer
	-- means one of yours ended early, and the game does not say which, so only those read plainly now stay, and the count to hold is the new one.
	-- With no count at all only the squares whose time ran out go.
	if not withheld then
		h.kept, h.count, h.ends = found, count, ends
	else
		local live, gone = Live(h)
		local hold = h.count and h.count - gone
		if count == nil then
			found = Merged(found, live)
		elseif h.kept and hold and count >= hold then
			-- The count to hold stays that of the last plain read (or of the last drop), less the heals over time that ran out: a buff of yours that
			-- comes and goes in the fight, such as Inspiration, Prayer of Mending bouncing off or a Lifebloom that ends, takes the count back to it and
			-- leaves the squares alone. Those that ran out leave the kept squares and the count, so an end is never counted twice.
			found = Merged(found, live)
			if gone > 0 then
				h.kept, h.count = live, hold
			end
		else
			h.kept, h.count, h.ends = found, count, ends
		end
	end
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
	if h.unit ~= unit then
		-- A new member, or none: nothing read of the last one is kept.
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
	-- A client that cannot hear one unit: every change of auras reads this frame again.
	if not h.heard then
		h.heard = pcall(ear.RegisterEvent, ear, "UNIT_AURA") or nil
	end
end

local Squares

-- While the options window is open, chat says once a fight that the squares wait for its end, as Hide.lua and /flatui move say theirs, so a new
-- Square corner or Square size in a fight does not look broken. A frame made or read in a fight with the window closed (zoning, a change of the
-- group) stays silent. The flag goes once the fight is over.
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
		-- A new corner or size, or the type icon row turned on or off, waits for the end of the fight; the squares keep their places until then.
		Tell(TELL_MOVE)
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
