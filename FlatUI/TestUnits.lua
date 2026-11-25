local _, ns = ...

-- Test mode's unit frames (TestMode.lua, spec Part B): stand-ins for the party and raid frames first, as the owner asked for them by name, then the
-- target, target of target, focus, focus target, pet, boss and totem frames. Each is a TM.StandIn of the unitframes module: a frame of Flat UI's own
-- at the place, scale, strata and level of the game's frame, painted by the drawings of the setup (ns.DrawUnits, SetupDrawUnits.lua) from the live
-- profile, so every row of the Unit frames page changes it at once. Every number shown is fixed (the real ones are secret values). Each picture is a
-- real one (SetupDrawUnits.lua Sample and E.picture): the player's own face on the target of target, which is the player, a class icon on a party
-- member and on a humanoid enemy (a mage's on the target Defias Pillager, a warrior's on the focus target), the hunter's pet family icon on a beast
-- (the pet Wolf, the focus Gruff Swiftbite) and the Voidwalker's icon on the warlock's party pet, in place of a grey silhouette.
--
-- Party (the bar's Party, while the player is in no group): four members, as the game lays its party frames out under PartyFrame (Shared/
-- PartyFrame.xml:3-36, a VerticalLayoutFrame 10 units apart, 26 with showPartyPets; each member 120 by 53, Mainline/PartyFrameTemplates.xml:79-80,
-- its pet at 23,-43, :364-368). With Edit Mode's Raid-Style Party Frames on they are the cells of CompactPartyFrame instead, the player first, a title
-- of 14 units above them and 2 in from PartyFrame's left (Shared/CompactRaidGroup.xml:52-56, PartyFrame.lua:124-143), down a column or, with Display
-- Horizontal Groups, along a row. Raid (Raid 10, 20 or 40, while the player is in no raid): the first 10, 20 or 40 of the roster below at the top left of
-- CompactRaidFrameContainer, at the cell size and in the group layout of the Edit Mode layout in use: separate groups, a column each with its title
-- (14 units), side by side with no gap and 8 units wider and 2 taller with Display Border, or a row each, one under the other, 4 units wider and
-- no taller with it (Shared/CompactRaidGroup.lua:95-160), or all the members in one flow of Row Size per line (Blizzard_EditMode/Shared/
-- EditModeManager.lua:477-503, Blizzard_FrameXMLBase/FlowContainer.lua:125-185).
-- A group starts a line of its own (FlowContainer.lua:161-166).
--
-- What it reads: the layout in use, from C_EditMode.GetLayouts and, for a preset, the game's own table of presets (EditModePresetLayoutManager.
-- presetLayoutInfo, read with rawget; no method is called), its unit frame systems Party and Raid: Frame Width and Frame Height (stored as the
-- difference from 72 and 36, Shared/EditModeSettingDisplayInfo.lua:16-22, 276-299), Raid Group Display Type, Row Size, Display Border, Opacity,
-- Raid-Style Party Frames and Display Horizontal Groups, and of Boss its Cast Bar on Side; anything missing or not finite takes the Modern preset's
-- (Mainline/EditModePresetLayouts.lua:292-356). The raid frame options, read with C_CVar.GetCVarBool and GetCVar and never written:
-- raidFramesDisplayClassColor, raidFramesDisplayPowerBars, raidFramesDisplayOnlyHealerPowerBars, raidFramesHealthText, raidFramesDisplayDebuffs and
-- raidFramesDispelIndicatorType (defaults: Mainline/CompactUnitFrameOptions.lua:2-40), showPartyPets and showTargetOfTarget. Whether a target,
-- focus, pet, boss, group or raid exists (UnitExists, IsInGroup, IsInRaid), the player's class (ns.DrawUnits.Me), whether Edit Mode is open
-- (ns.EditModeOpen) and the shown flag of the game's first party member frame (PartyFrame.MemberFrame1, read with rawget), of CompactPartyFrame and
-- of Boss1TargetFrame, and the effective scale of Boss1TargetFrame against its container's. It writes nothing on any of them. While test mode is on
-- it hears CVAR_UPDATE (TM.Watch), so a change of the raid frame options or showPartyPets in the game's own options paints the samples again
-- (TM.Repaint).
--
-- Shown by (TestMode.lua runs the rules; each also needs the game frame hidden, its own `real` rule saying so, unless named):
--   party     PartyFrame: the bar's Party and no group; real while Edit Mode is open or a party member frame or CompactPartyFrame shows.
--   raid      CompactRaidFrameContainer: the bar's Raid 10, 20 or 40 and no raid; real while Edit Mode is open, in a raid, or while the party
--             stand-in's real frames show (a real party is where the raid frames would be, Mainline/EditModePresetLayouts.lua:292-340).
--   target    TargetFrame: no target. tot: TargetFrameToT, while the target's stand-in shows and showTargetOfTarget is on.
--   focus     FocusFrame: no focus. focustot: FocusFrameToT, while the focus's stand-in shows and showTargetOfTarget is on.
--   pet       PetFrame: no pet, any class. boss: BossTargetFrameContainer, from its top right: no boss1; real while Edit Mode is open or
--             Boss1TargetFrame shows. totem: TotemFrame, a shaman's, while the game shows no totem.
-- Animate (while the bar's Moving is on): Eli's health drifts from 64% to 40% and back over 6 seconds on the party frames, three raid members' drift
-- too, and the totem's time counts down from 2:00 and starts again. It sets fills and words only (ns.DrawUnits.Fill and FillCell).
--
-- The roster of the raid (spec 2.4): 8 groups of 5, the first a tank, the second a healer and the rest damage, the classes in turn by role; health
-- 30 + (index * 37) % 71 percent and power 20 + (index * 53) % 81 percent; leader 1, assistants 6 and 11; markers on the tanks (Skull 1, Cross 6,
-- Square 11, Moon 16, Triangle 21, Diamond 26, Circle 31, Star 36); dead 7 and 24, offline 13 and 33, out of range 4, 18, 29 and 38; a debuff the
-- player can dispel on 3 (magic), 9 (curse), 15 (poison), 22 (disease) and 35 (magic); aggro on each tank; a buff on every third; the player's
-- heals over time on 2, 5 and 12 (UnitHots.lua's colours: a priest's Renew, a druid's Rejuvenation and Regrowth, a shaman's Riptide); the first 10
-- names are the setup's raid (SetupDrawUnits.lua RAID).

local TM = ns.TestMode
if type(TM) ~= "table" or type(TM.StandIn) ~= "function" then
	return
end

local KEY = "unitframes"
local TAU = 2 * math.pi
-- The friendly colour of the setup's samples (SetupDrawUnits.lua FRIENDLY), and the most health a raid member's health text counts from.
local FRIENDLY = { 0.18, 0.78, 0.24 }
local MAX_HEALTH = 5000

-- The roster --------------------------------------------------------------------------------------------------------------------------------

local TANKS = { "WARRIOR", "PALADIN", "DRUID" }
local HEALERS = { "PRIEST", "DRUID", "SHAMAN", "PALADIN" }
local DAMAGE = { "MAGE", "ROGUE", "HUNTER", "WARLOCK", "WARRIOR", "SHAMAN", "PRIEST", "DRUID" }
local NAMES = { "Aria", "Bex", "Cole", "Dru", "Eli", "Fay", "Gus", "Hale", "Ivo", "Jun", "Kai", "Lena", "Milo", "Nell", "Oren", "Pia", "Quin", "Rhea",
	"Sol", "Tam", "Uma", "Vic", "Wren", "Xan", "Yara", "Zed", "Ada", "Bram", "Cora", "Dax", "Edda", "Finn", "Gwen", "Hugo", "Iris", "Jory", "Kira",
	"Lars", "Mae", "Nico" }
-- The raid target index of each marker (1 Star to 8 Skull).
local MARKERS = { [1] = 8, [6] = 7, [11] = 6, [16] = 5, [21] = 4, [26] = 3, [31] = 2, [36] = 1 }
local DEAD, OFFLINE, AWAY = { [7] = true, [24] = true }, { [13] = true, [33] = true }, { [4] = true, [18] = true, [29] = true, [38] = true }
local DISPEL = { [3] = "magic", [9] = "curse", [15] = "poison", [22] = "disease", [35] = "magic" }
local HOT_ON = { [2] = true, [5] = true, [12] = true }
-- The members whose health drifts, and how far either way.
local DRIFT, DRIFT_BY = { 2, 10, 17 }, 0.15
-- The power of a class that has no mana; a druid tank is in bear form.
local POWER = { WARRIOR = "RAGE", ROGUE = "ENERGY" }
-- The colours of the player's heals over time by class (UnitHots.lua HOTS): Renew; Rejuvenation and Regrowth; Riptide.
local HOTS = { PRIEST = { { 0.3, 0.9, 0.35 } }, DRUID = { { 0.75, 0.3, 1 }, { 0.3, 0.9, 0.35 } }, SHAMAN = { { 0.25, 0.55, 1 } } }

local ROSTER = {}
do
	local damage = 0
	for index = 1, 40 do
		local group, slot = math.floor((index - 1) / 5) + 1, (index - 1) % 5 + 1
		local role, class
		if slot == 1 then
			role, class = "tank", TANKS[(group - 1) % #TANKS + 1]
		elseif slot == 2 then
			role, class = "healer", HEALERS[(group - 1) % #HEALERS + 1]
		else
			damage = damage + 1
			role, class = "damage", DAMAGE[(damage - 1) % #DAMAGE + 1]
		end
		ROSTER[index] = { name = NAMES[index], class = class, role = role, base = (30 + (index * 37) % 71) / 100, power = (20 + (index * 53) % 81) / 100,
			powerType = POWER[class] or ((class == "DRUID" and role == "tank") and "RAGE") or "MANA", leader = index == 1, assist = index == 6 or index == 11,
			marker = MARKERS[index], dead = DEAD[index], offline = OFFLINE[index], away = AWAY[index], dispel = DISPEL[index], threat = slot == 1,
			buff = index % 3 == 0, hot = HOT_ON[index], debuffs = DISPEL[index] and { DISPEL[index] } or nil }
	end
end

-- The party (spec 1.3): a leader tank with a marker, a buff and aggro; a healer out of range with a magic debuff and your heals over time; a
-- warlock with a curse and a Voidwalker; a dead rogue.
local PARTY = {
	{ name = "Mara", class = "PALADIN", role = "tank", base = 0.82, power = 0.64, powerType = "MANA", leader = true, marker = 1, threat = true, buff = true },
	{ name = "Eli", class = "PRIEST", role = "healer", base = 0.64, power = 0.38, powerType = "MANA", dispel = "magic", away = true, hot = true,
		debuffs = { "magic" } },
	{ name = "Ivo", class = "WARLOCK", role = "damage", base = 0.47, power = 0.71, powerType = "MANA", dispel = "curse", debuffs = { "curse" },
		pet = { kind = "partypet", name = "Voidwalker", react = FRIENDLY, owner = "WARLOCK", health = 0.9, face = "Interface\\Icons\\Spell_Shadow_SummonVoidWalker" } },
	{ name = "Fay", class = "ROGUE", role = "damage", base = 0, power = 0, powerType = "ENERGY", dead = true },
}
-- Eli's drift: from 64% to 40% and back over 6 seconds.
local ELI, ELI_MID, ELI_BY, ELI_EVERY = 2, 0.52, 0.12, 6
-- The bosses: name, health (a share of 1) and whether dead.
local BOSSES = { { "Hogger", 1 }, { "Kobold Digger", 0.64 }, { "Defias Overseer", 0.25 }, { "Murloc Lurker", 0, true }, { "Gnoll Brute", 1 } }

-- Reads ----------------------------------------------------------------------------------------------------------------------------------------

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Plain(ok, value)
	if ok and not ns.IsSecret(value) then
		return value
	end
	return nil
end

-- A game variable as true or false, or `default` when the client will not say.
local function CvarBool(name, default)
	local api = C_CVar
	if type(api) == "table" and type(api.GetCVarBool) == "function" then
		local value = Plain(pcall(api.GetCVarBool, name))
		if type(value) == "boolean" then
			return value
		end
	end
	return default
end

local function Cvar(name)
	local get = type(C_CVar) == "table" and C_CVar.GetCVar or GetCVar
	if type(get) ~= "function" then
		return nil
	end
	local value = Plain(pcall(get, name))
	return type(value) == "string" and value or nil
end

-- True when the unit exists; a withheld answer counts as one that does, so no stand-in covers it.
local function Exists(unit)
	if type(UnitExists) ~= "function" then
		return false
	end
	local ok, value = pcall(UnitExists, unit)
	if not ok then
		return false
	end
	return ns.IsSecret(value) or value == true
end

local function Asks(fn)
	if type(fn) ~= "function" then
		return false
	end
	local ok, value = pcall(fn)
	return ok and (ns.IsSecret(value) or value == true)
end

local function Shown(frame)
	return type(frame) == "table" and not ns.Forbidden(frame) and ns.MoverShown(frame) == true
end

local function EditMode()
	return type(ns.EditModeOpen) == "function" and ns.EditModeOpen() == true
end

-- The player's heals over time, by the class (HOTS), or nil.
local function Hots()
	local D = ns.DrawUnits
	local _, _, class = D.Me()
	return HOTS[class]
end

-- The layout of Edit Mode ----------------------------------------------------------------------------------------------------------------------

-- The settings of the Modern preset (Mainline/EditModePresetLayouts.lua:292-340, Party and Raid), by setting number, and the setting numbers
-- (EditModeManagerConstantsDocumentation.lua:783-812) for a client whose Enum will not say.
local SETTING = { UseRaidStylePartyFrames = 4, UseHorizontalGroups = 6, CastBarOnSide = 7, FrameWidth = 10, FrameHeight = 11, DisplayBorder = 12,
	RaidGroupDisplayType = 13, RowSize = 15, Opacity = 20 }
local PRESET = { [4] = 0, [6] = 0, [7] = 1, [10] = 26, [11] = 8, [12] = 0, [13] = 0, [15] = 5, [20] = 100 }
-- The system numbers: UnitFrame 3, its Party 4, Raid 5 and Boss 6 (EditModeManagerConstantsDocumentation.lua:741, 826-828).
local SYSTEM = { UnitFrame = 3, Party = 4, Raid = 5, Boss = 6 }
-- The smallest cell (Shared/CompactUnitFrame.lua:11-12), the height of a group's title (Shared/CompactRaidGroup.xml:52-56), and how long a read of
-- the layout is kept.
local CELL_W, CELL_H, TITLE, KEEP = 72, 36, 14, 1
local layouts = { at = nil }

local function EnumValue(group, name, fallback)
	local enum = type(Enum) == "table" and not ns.IsSecret(Enum) and Enum[group]
	local value = type(enum) == "table" and enum[name]
	return ns.Finite(value) and value or fallback
end

-- The settings of the unit frame system `index` of the layout in use, { [setting] = value }, or an empty table when the game will not say. Saved
-- layouts follow the presets in the numbering of activeLayout (LayoutSpots.lua Load).
local function ReadSystem(index)
	local api = C_EditMode
	if type(api) ~= "table" or type(api.GetLayouts) ~= "function" then
		return {}
	end
	local info = Plain(pcall(api.GetLayouts))
	local active = type(info) == "table" and rawget(info, "activeLayout")
	if not ns.Finite(active) then
		return {}
	end
	local manager = rawget(_G, "EditModePresetLayoutManager")
	local presets = type(manager) == "table" and rawget(manager, "presetLayoutInfo") or nil
	local count = type(presets) == "table" and #presets or 0
	local saved = rawget(info, "layouts")
	local layout
	if active <= count then
		layout = presets[active]
	elseif type(saved) == "table" then
		layout = saved[active - count]
	end
	local systems = type(layout) == "table" and rawget(layout, "systems")
	if type(systems) ~= "table" then
		return {}
	end
	local unitFrame = EnumValue("EditModeSystem", "UnitFrame", SYSTEM.UnitFrame)
	for _, system in ipairs(systems) do
		if type(system) == "table" and system.system == unitFrame and system.systemIndex == index and type(system.settings) == "table" then
			local out = {}
			for _, entry in ipairs(system.settings) do
				if type(entry) == "table" and ns.Finite(entry.setting) and ns.Finite(entry.value) then
					out[entry.setting] = entry.value
				end
			end
			return out
		end
	end
	return {}
end

-- A setting by name, from a system's settings or the preset's.
local function Setting(settings, name)
	local number = EnumValue("EditModeUnitFrameSetting", name, SETTING[name])
	local value = settings[number]
	if ns.Finite(value) then
		return value
	end
	return PRESET[SETTING[name]]
end

-- The party and raid layouts: cell width and height, the display type, row size, border, opacity, raid style and horizontal groups; and whether
-- the boss frames have their cast bars on the side. Read again after KEEP seconds, and at once after Edit Mode was open.
local function Layouts()
	local now = GetTime()
	if layouts.at and now - layouts.at < KEEP then
		return layouts.party, layouts.raid, layouts.side
	end
	layouts.at = now
	local out = {}
	for which, index in pairs({ party = EnumValue("EditModeUnitFrameSystemIndices", "Party", SYSTEM.Party),
		raid = EnumValue("EditModeUnitFrameSystemIndices", "Raid", SYSTEM.Raid) }) do
		local settings = ReadSystem(index)
		out[which] = { width = CELL_W + math.max(0, Setting(settings, "FrameWidth")), height = CELL_H + math.max(0, Setting(settings, "FrameHeight")),
			display = Setting(settings, "RaidGroupDisplayType"), rowSize = math.max(1, math.floor(Setting(settings, "RowSize"))),
			border = Setting(settings, "DisplayBorder") == 1, opacity = math.min(1, math.max(0.1, Setting(settings, "Opacity") / 100)),
			raidStyle = Setting(settings, "UseRaidStylePartyFrames") == 1, horizontal = Setting(settings, "UseHorizontalGroups") == 1 }
	end
	layouts.party, layouts.raid = out.party, out.raid
	layouts.side = Setting(ReadSystem(EnumValue("EditModeUnitFrameSystemIndices", "Boss", SYSTEM.Boss)), "CastBarOnSide") == 1
	return out.party, out.raid, layouts.side
end

-- The raid frame options (Mainline/CompactUnitFrameOptions.lua:2-40 for their defaults).
local options = {}
local function Options()
	options.classColour = CvarBool("raidFramesDisplayClassColor", true)
	options.power = CvarBool("raidFramesDisplayPowerBars", true)
	options.healerPower = CvarBool("raidFramesDisplayOnlyHealerPowerBars", false)
	options.healthText = Cvar("raidFramesHealthText") or "none"
	options.debuffs = CvarBool("raidFramesDisplayDebuffs", true)
	options.dispelIcons = (Cvar("raidFramesDispelIndicatorType") or "2") ~= "0"
	return options
end

-- The game's health text on a raid frame for a share of MAX_HEALTH: perc, health, losthealth or none (CompactUnitFrame.lua's healthText).
local function HealthText(mode, share)
	local cur = math.floor(MAX_HEALTH * share + 0.5)
	if mode == "perc" then
		return ("%d%%"):format(math.floor(share * 100 + 0.5))
	elseif mode == "health" then
		return tostring(cur)
	elseif mode == "losthealth" and cur < MAX_HEALTH then
		return "-" .. tostring(MAX_HEALTH - cur)
	end
	return nil
end

-- Samples --------------------------------------------------------------------------------------------------------------------------------------

-- The sample of a raid cell for a member of the roster or the party, kept on the member and filled again at each paint.
local function CellSample(m, opts)
	local s = m.cell or {}
	m.cell = s
	s.name, s.class, s.role = m.name, m.class, m.role
	s.dead, s.offline, s.away, s.threat = m.dead, m.offline, m.away, m.threat
	s.health, s.power, s.powerType = m.now or m.base, m.power, m.powerType
	s.powerBar = opts.power and (not opts.healerPower or m.role == "healer")
	s.classColour = opts.classColour
	s.text = not (m.dead or m.offline) and HealthText(opts.healthText, s.health) or nil
	s.dispel, s.gameDispel = m.dispel, opts.dispelIcons
	s.debuffs = opts.debuffs and m.debuffs or nil
	s.buffs = m.buff and 1 or 0
	s.marker, s.leader, s.assist = m.marker, m.leader, m.assist
	s.hots = m.hot and Hots() or nil
	return s
end

-- The sample of a party frame for a member of the party, kept on the member.
local function UnitSample(m, level)
	local D = ns.DrawUnits
	local s = m.unit or { kind = "party", player = true, react = FRIENDLY, auras = {} }
	m.unit = s
	s.name, s.class, s.role, s.level = m.name, m.class, m.role, level
	s.leader, s.marker, s.threat, s.dead, s.away = m.leader, m.marker, m.threat, m.dead, m.away
	s.health, s.power, s.powerType = m.now or m.base, m.power, m.powerType
	s.dispel, s.hots = m.dispel, m.hot and Hots() or nil
	-- The top debuff colours the border of the health bar with Threat border (UnitFrames.lua:1480-1497), as on the setup's party frame.
	s.debuff = m.dispel and D.TYPE[m.dispel] or nil
	local auras = s.auras
	for index = #auras, 1, -1 do
		auras[index] = nil
	end
	if m.buff then
		auras[#auras + 1] = { "buff", "none" }
	end
	if m.dispel then
		auras[#auras + 1] = { "debuff", m.dispel, false, nil, "8" }
	end
	return s
end

-- Party ------------------------------------------------------------------------------------------------------------------------------------------

local party = { members = {}, pets = {}, cells = {} }

local function BuildParty(holder)
	local D = ns.DrawUnits
	for index = 1, #PARTY do
		party.members[index] = D.Unit(holder, "party")
		party.pets[index] = D.Unit(holder, "partypet")
	end
	for index = 1, #PARTY + 1 do
		party.cells[index] = D.Cell(holder)
	end
	party.title = Own(holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
	party.title:SetText("Party")
	local name, _, class = D.Me()
	party.me = { name = name, class = class, base = 1, power = 1, powerType = POWER[class] or "MANA" }
end

-- The game's party frames: each member 53 high and 10 apart (26 with showPartyPets), its pet at 23,-43 (see the header). Returns the size.
local function PaintMembers(holder, g)
	local D = ns.DrawUnits
	local pets = CvarBool("showPartyPets", true)
	local pitch = 53 + (pets and 26 or 10)
	local _, level = D.Me()
	local width, height = 1, 1
	for index, m in ipairs(PARTY) do
		local o, pet = party.members[index], party.pets[index]
		o.root:Show()
		local w, h = D.PaintUnit(o, UnitSample(m, level), g)
		local x, y = D.Offset(o)
		y = y + (index - 1) * pitch
		o.root:ClearAllPoints()
		o.root:SetPoint("TOPLEFT", holder, "TOPLEFT", x, -y)
		width, height = math.max(width, x + w), math.max(height, y + h)
		local shows = pets and m.pet ~= nil
		pet.root:SetShown(shows)
		if shows then
			m.pet.level = level
			local pw, ph = D.PaintUnit(pet, m.pet, g)
			local px, py = D.Offset(pet)
			px, py = 23 + px, (index - 1) * pitch + 43 + py
			pet.root:ClearAllPoints()
			pet.root:SetPoint("TOPLEFT", holder, "TOPLEFT", px, -py)
			width, height = math.max(width, px + pw), math.max(height, py + ph)
		end
	end
	for _, cell in ipairs(party.cells) do
		cell.frame:Hide()
	end
	party.title:Hide()
	return width, height
end

-- Raid-Style Party Frames: the cells of CompactPartyFrame, the player first, in a column or a row under the title, 2 in from the left.
local function PaintCells(holder, g, layout)
	local D = ns.DrawUnits
	local opts = Options()
	local w, h = layout.width, layout.height
	party.title:Show()
	party.title:ClearAllPoints()
	party.title:SetPoint("BOTTOM", holder, "TOPLEFT", 2 + w / 2, -TITLE)
	local width, height = 2 + w, TITLE + h
	for index, cell in ipairs(party.cells) do
		local m = index == 1 and party.me or PARTY[index - 1]
		local x, y = 2, TITLE + (index - 1) * h
		if layout.horizontal then
			x, y = 2 + (index - 1) * w, TITLE
		end
		cell.frame:Show()
		cell.frame:ClearAllPoints()
		cell.frame:SetPoint("TOPLEFT", holder, "TOPLEFT", x, -y)
		cell.frame:SetSize(w, h)
		D.PaintCell(cell, CellSample(m, opts), w, h, g)
		width, height = math.max(width, x + w), math.max(height, y + h)
	end
	for index, o in ipairs(party.members) do
		o.root:Hide()
		party.pets[index].root:Hide()
	end
	return width, height
end

local function PaintParty(holder)
	local D = ns.DrawUnits
	local g = D.Settings(holder)
	local layout = Layouts()
	party.style = layout.raidStyle and "cells" or "members"
	if layout.raidStyle then
		return PaintCells(holder, g, layout)
	end
	return PaintMembers(holder, g)
end

local function AnimateParty(_, _, now)
	local D = ns.DrawUnits
	local m = PARTY[ELI]
	m.now = ELI_MID + ELI_BY * math.cos(TAU * now / ELI_EVERY)
	if party.style == "cells" then
		-- The health text of the raid frame options as the last paint read them (Options).
		D.FillCell(party.cells[ELI + 1], m.now, HealthText(options.healthText, m.now))
	elseif party.style == "members" then
		D.Fill(party.members[ELI], m.now)
	end
end

-- Raid -------------------------------------------------------------------------------------------------------------------------------------------

local raid = { cells = {}, titles = {} }

local function BuildRaid(holder)
	local D = ns.DrawUnits
	raid.root = Own(CreateFrame("Frame", nil, holder))
	raid.root:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
	raid.root:SetSize(1, 1)
	for index = 1, #ROSTER do
		raid.cells[index] = D.Cell(raid.root)
	end
	for index = 1, #ROSTER / 5 do
		local title = Own(raid.root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
		title:SetText(("Group %d"):format(index))
		raid.titles[index] = title
	end
end

-- The top left of member `index` and of its group's title, from the container's top left, by the display type: 0 separate groups in columns, 1
-- separate groups in rows, 2 one flow down columns of Row Size, 3 one flow along rows of Row Size.
local function Spot(layout, index)
	local w, h = layout.width, layout.height
	local group, slot = math.floor((index - 1) / 5) + 1, (index - 1) % 5
	if layout.display == 1 then
		local x, y = slot * w, (group - 1) * (TITLE + h) + TITLE
		return x, y, 0, y - TITLE
	elseif layout.display == 2 or layout.display == 3 then
		local line, at = math.floor((index - 1) / layout.rowSize), (index - 1) % layout.rowSize
		if layout.display == 2 then
			return line * w, at * h
		end
		return at * w, line * h
	end
	local pitch = w + (layout.border and 8 or 0)
	local x = (group - 1) * pitch + (layout.border and 4 or 0)
	return x, TITLE + slot * h, x + w / 2, 0
end

local function PaintRaid(holder)
	local D = ns.DrawUnits
	local g = D.Settings(holder)
	local _, layout = Layouts()
	local opts = Options()
	local count = TM.GroupSize()
	local w, h = layout.width, layout.height
	raid.root:SetAlpha(layout.opacity)
	local width, height = 1, 1
	for index, cell in ipairs(raid.cells) do
		local shows = index <= count
		cell.frame:SetShown(shows)
		if shows then
			local x, y = Spot(layout, index)
			cell.frame:ClearAllPoints()
			cell.frame:SetPoint("TOPLEFT", raid.root, "TOPLEFT", x, -y)
			cell.frame:SetSize(w, h)
			D.PaintCell(cell, CellSample(ROSTER[index], opts), w, h, g)
			width, height = math.max(width, x + w), math.max(height, y + h)
		end
	end
	local titled = layout.display == 0 or layout.display == 1
	for index, title in ipairs(raid.titles) do
		local shows = titled and index * 5 <= count
		title:SetShown(shows)
		if shows then
			local _, _, tx, ty = Spot(layout, (index - 1) * 5 + 1)
			title:ClearAllPoints()
			title:SetPoint(layout.display == 1 and "TOPLEFT" or "TOP", raid.root, "TOPLEFT", tx, -ty)
		end
	end
	raid.root:SetSize(width, height)
	return width, height
end

local function AnimateRaid(_, _, now)
	local D = ns.DrawUnits
	local count = TM.GroupSize()
	local text = options.healthText
	for turn, index in ipairs(DRIFT) do
		local m = ROSTER[index]
		if index <= count and not (m.dead or m.offline) then
			m.now = math.min(1, math.max(0.05, m.base + DRIFT_BY * math.sin(TAU * now / ELI_EVERY + turn * 2)))
			D.FillCell(raid.cells[index], m.now, HealthText(text, m.now))
		end
	end
end

-- The other unit frames ------------------------------------------------------------------------------------------------------------------------

-- One frame of a kind at the game frame's top left, its health bar on the game's (ns.DrawUnits.Offset). sample(): the sample, made once.
local function Single(kind, sample)
	local view = {}
	local function Build(holder)
		view.o = ns.DrawUnits.Unit(holder, kind)
	end
	local function Paint(holder)
		local D = ns.DrawUnits
		view.s = view.s or sample()
		local w, h = D.PaintUnit(view.o, view.s, D.Settings(holder))
		local x, y = D.Offset(view.o)
		view.o.root:ClearAllPoints()
		view.o.root:SetPoint("TOPLEFT", holder, "TOPLEFT", x, -y)
		return math.max(1, x + w), math.max(1, y + h)
	end
	return Build, Paint, view
end

local function Fixed(id)
	return function()
		return ns.DrawUnits.Sample(id)
	end
end

-- The player as the target of the target, with the player's own face in the picture (me), as the game's frame shows it.
local function MeAsTarget()
	local name, level, class = ns.DrawUnits.Me()
	return { kind = "tot", name = name, level = level, class = class, player = true, me = true, react = FRIENDLY }
end

-- The pet: the setup's, with the happiness face for a hunter only.
local function PetSample()
	local s = ns.DrawUnits.Sample("pet")
	local _, _, class = ns.DrawUnits.Me()
	s.happy = class == "HUNTER"
	return s
end

-- Boss frames: five in a column down from the container's top right, each 232 by 100 at its own scale (Boss1TargetFrame's against the container's:
-- 0.75 small, 1 large, Mainline/TargetFrame.lua:12-13, 1116-1128), as the container lays them out (TargetFrame.xml:607-617, TargetFrame.lua:
-- 1081-1104, Blizzard_SharedXML/LayoutFrame.lua:276-361): 10 apart plus the bottom padding of each, in container units (small: -20 with the cast
-- bar on the side, else 0; large: -50 on the side, else -20), with each right edge 70 less its right padding (30 small, 15 large) right of the
-- container's.
local boss = { frames = {} }

local function BuildBoss(holder)
	for index = 1, #BOSSES do
		boss.frames[index] = ns.DrawUnits.Unit(holder, "boss")
	end
end

local function BossScale()
	local child, container = rawget(_G, "Boss1TargetFrame"), rawget(_G, "BossTargetFrameContainer")
	if type(child) ~= "table" or type(container) ~= "table" or ns.Forbidden(child) or ns.Forbidden(container) then
		return 1
	end
	local mine = Plain(pcall(child.GetEffectiveScale, child))
	local base = Plain(pcall(container.GetEffectiveScale, container))
	if ns.Finite(mine) and ns.Finite(base) and mine > 0 and base > 0 then
		return mine / base
	end
	return 1
end

local function PaintBoss(holder)
	local D = ns.DrawUnits
	local g = D.Settings(holder)
	local scale = BossScale()
	local small = scale < 0.875
	local _, _, side = Layouts()
	local pad = small and (side and -20 or 0) or (side and -50 or -20)
	local right = 70 - (small and 30 or 15)
	local pitch = 100 * scale + pad + 10
	local height = 1
	for index, o in ipairs(boss.frames) do
		local spec = BOSSES[index]
		if not boss.samples then
			boss.samples = {}
		end
		local s = boss.samples[index]
		if not s then
			s = D.Sample(index == 1 and "boss" or "boss2")
			s.name, s.health, s.dead = spec[1], spec[2], spec[3] == true
			boss.samples[index] = s
		end
		o.root:SetScale(scale)
		D.PaintUnit(o, s, g)
		local x, y = D.Offset(o)
		o.root:ClearAllPoints()
		o.root:SetPoint("TOPLEFT", holder, "TOPRIGHT", x - 232 + right / scale, -(y + (index - 1) * pitch / scale))
		height = (index - 1) * pitch + 100 * scale
	end
	return 232 * scale, height
end

-- The totem: its time counts down from 2:00 and starts again.
local totem = {}
local TOTEM_TIME = 120

local function TotemTime(now)
	local left = TOTEM_TIME - math.floor(now % TOTEM_TIME)
	return ("%d:%02d"):format(math.floor(left / 60), left % 60)
end

local function PaintTotem(holder)
	local D = ns.DrawUnits
	totem.s = totem.s or {}
	totem.s.time = TotemTime(GetTime())
	totem.o.root:ClearAllPoints()
	totem.o.root:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
	return D.PaintUnit(totem.o, totem.s, D.Settings(holder))
end

local function AnimateTotem(_, _, now)
	local o = totem.o
	if o and o.time:IsShown() then
		o.time:SetText(TotemTime(now))
	end
end

-- The stand-ins ------------------------------------------------------------------------------------------------------------------------------------

local function Group(which)
	return function()
		local group = TM.Group()
		if which == "party" then
			return group == "party" and not Asks(IsInGroup)
		end
		return group ~= "party" and group ~= "solo" and not Asks(IsInRaid)
	end
end

-- True while the game's party frames show: its first party member frame or CompactPartyFrame.
local function PartyShows()
	local frame = rawget(_G, "PartyFrame")
	local first = type(frame) == "table" and not ns.Forbidden(frame) and rawget(frame, "MemberFrame1") or nil
	return Shown(first) or Shown(rawget(_G, "CompactPartyFrame"))
end

TM.StandIn({ id = "party", module = KEY, game = "PartyFrame", label = "Party frames", gate = Group("party"),
	real = function()
		if EditMode() then
			layouts.at = nil
			return true
		end
		return PartyShows()
	end,
	Build = BuildParty, Paint = PaintParty, Animate = AnimateParty })

TM.StandIn({ id = "raid", module = KEY, game = "CompactRaidFrameContainer", label = "Raid frames", gate = Group("raid"),
	real = function()
		if EditMode() then
			layouts.at = nil
			return true
		end
		return Asks(IsInRaid) or PartyShows()
	end,
	Build = BuildRaid, Paint = PaintRaid, Animate = AnimateRaid })

do
	local build, paint = Single("target", Fixed("target"))
	TM.StandIn({ id = "target", module = KEY, game = "TargetFrame", label = "Target frame", gate = function() return not Exists("target") end,
		Build = build, Paint = paint })
	build, paint = Single("tot", MeAsTarget)
	TM.StandIn({ id = "tot", module = KEY, game = "TargetFrameToT", label = "Target of target",
		gate = function() return TM.Shown("target") and CvarBool("showTargetOfTarget", true) end, Build = build, Paint = paint })
	build, paint = Single("focus", Fixed("focus"))
	TM.StandIn({ id = "focus", module = KEY, game = "FocusFrame", label = "Focus frame", gate = function() return not Exists("focus") end,
		Build = build, Paint = paint })
	build, paint = Single("tot", Fixed("tot"))
	TM.StandIn({ id = "focustot", module = KEY, game = "FocusFrameToT", label = "Focus target",
		gate = function() return TM.Shown("focus") and CvarBool("showTargetOfTarget", true) end, Build = build, Paint = paint })
	build, paint = Single("pet", PetSample)
	TM.StandIn({ id = "pet", module = KEY, game = "PetFrame", label = "Pet frame", gate = function() return not Exists("pet") end,
		Build = build, Paint = paint })
end

TM.StandIn({ id = "boss", module = KEY, game = "BossTargetFrameContainer", label = "Boss frames", corner = "TOPRIGHT",
	gate = function() return not Exists("boss1") end,
	real = function() return EditMode() or Shown(rawget(_G, "Boss1TargetFrame")) end,
	Build = BuildBoss, Paint = PaintBoss })

TM.StandIn({ id = "totem", module = KEY, game = "TotemFrame", label = "Totem bar",
	gate = function()
		local D = ns.DrawUnits
		if not D then
			return false
		end
		local _, _, class = D.Me()
		return class == "SHAMAN"
	end,
	Build = function(holder) totem.o = ns.DrawUnits.Unit(holder, "totem") end, Paint = PaintTotem, Animate = AnimateTotem })

-- The game variables the party and raid samples are drawn from (Options, PaintMembers): a change of one, in the game's own options, paints the
-- shown stand-ins again. Heard only while test mode is on.
local CVARS = { raidframesdisplayclasscolor = true, raidframesdisplaypowerbars = true, raidframesdisplayonlyhealerpowerbars = true,
	raidframeshealthtext = true, raidframesdisplaydebuffs = true, raidframesdispelindicatortype = true, showpartypets = true }
local cvars = CreateFrame("Frame")
ns.Own[cvars] = true
cvars:SetScript("OnEvent", function(_, _, name)
	if not ns.IsSecret(name) and type(name) == "string" and CVARS[name:lower()] then
		TM.Repaint()
	end
end)
if type(TM.Watch) == "function" then
	TM.Watch(function(on)
		if on then
			cvars:RegisterEvent("CVAR_UPDATE")
		else
			cvars:UnregisterEvent("CVAR_UPDATE")
		end
	end)
end
