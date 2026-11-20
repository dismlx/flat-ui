local _, ns = ...

-- Hit table lines (part "hit table lines" of Chat and tooltips; 0.5.20): under the tooltip of an enemy the player can attack, the player's hit table
-- against it, a line for each attack the hit table under the player frame shows (HitTable.lua), as "Swing  M8 D6.5 G40 C12.1 H33.4" (0.5.21: a letter
-- for each part, M miss, D dodge, P parry, G glance, B block, C crit, H hit, and one decimal unless it is 0; 0.5.26: R on the Spells line, the share
-- of a spell's damage resisted on average, signed, as R-2.5 for damage taken more from Spell Piercing, HitTableCalc.lua's Resist). Its row is On
-- enemy tooltips (hud.hitTableTip, on the Hit table page of Minimap and HUD): For tanks and damage dealers (the default) adds the lines while the
-- player's role (ns.PlayerRole, Core.lua) is no healer, Always whatever the role, Off never. The lines follow that row alone, not Hit table under the
-- player frame, so a player may hide the table and keep the lines; and they come only while the chat module is on, since its post call adds them.
-- They count what the Hit table page says: Attacks (hud.hitTableLines, the kinds of C.Kinds by the class and the player's power type now,
-- UnitPowerType, which carries no secret tag, so a druid who takes Bear or Cat Form in a fight gets the melee lines), Special attacks
-- (hud.hitTableSpecial) and Hit cap against a boss (hud.hitTableRules); parry and block only from the front: by Where you stand (hud.hitTableFacing),
-- at its first choice while the enemy attacks the player (C.Front) and always for a tank, who stands in front. The enemy counts at its level
-- (C.Target: UnitEffectiveLevel, else UnitLevel); a level the game shows as ?? at three levels above the player, and a boss (ns.UnitKind) of the
-- player's level or above at three levels above the player at least, as the hit table counts a boss (HitTableCalc.lua, ABOVE), while a boss below the
-- player (a dungeon's, for a player far above it) keeps its level. It has no switch of its own, as SpellLines.lua, follows one call only, for the
-- size of its lines (below), and hears one event on one frame of its own, for the Ctrl key (below); HitTableCalc.lua and SpellModel.lua are looked
-- up when asked, never as the files load.
--
-- Ctrl (0.5.28, the owner: "hide hit on tooltip unless holding ctrl key"): with Only while Ctrl is held (hud.hitTableTipCtrl, on by default) the
-- lines are added to a build only while Ctrl is down (IsControlKeyDown) as the tooltip is built; with Hint while Ctrl is up (hud.hitTableTipHint, off
-- by default) one dim line, Hold Ctrl for the hit table, stands in for them while it is up. A build of an enemy's tooltip made while Ctrl is up is
-- kept (its data and its owner), and while one is kept a frame of Flat UI's own hears MODIFIER_STATE_CHANGED (KeyBindingsDocumentation.lua:158-167:
-- the key, as LCTRL or RCTRL, and whether it went down). When Ctrl goes down and GameTooltip still shows that build (IsShown, its owner, and the
-- data of its first info, its field infoList read only), the lines are added to it there and then, with the same AddDoubleLine and AddLine a build
-- adds them with, under the game's lines and any added since, and GameTooltip is shown again (Show) so it takes their size. The hint, where it still
-- shows, becomes their header: SetText and SetTextColor on its left font string, a line Flat UI added, while it still reads the hint. Once they are
-- added the build is no longer kept, so a build gets them once. Nothing is built again and no Lua method of GameTooltip is called: a rebuild run
-- from here (RefreshData, GameTooltip.lua:959-962) would be tainted, and the game warns that tainted tooltip info can make a later tooltip whose
-- data holds a secret text show no lines (GameTooltip.lua:994-1003); so the tooltip, its place, owner and fade, and every one after it stay the
-- game's. Ctrl let go leaves the lines until the game builds that tooltip again: GameTooltip has no widget call that takes off some of its lines
-- (ClearLines takes the game's too, and a font string emptied or hidden stays a line of the tooltip, NumLines), so they leave when the tooltip
-- next changes. An owner with an UpdateTooltip, as a unit frame has (Mainline/UnitFrame.lua:396-407), or a tooltip with one, has the game build it
-- again within 0.2 seconds (GameTooltip_OnUpdate, GameTooltip.lua:451-463), and that build follows the key as any does, so there nothing is done
-- and the lines come and go with the key. A world tooltip fading out has no info (the game clears it first, GameTooltip.lua:1014-1017), so it is
-- never touched. A kept build goes at the next build that is not kept again, or at the next press of Ctrl, and the event with it.
--
-- The tests, cheapest first: the row and the chat module; the tooltip GameTooltip (rawequal), one addons may touch (ns.Forbidden) and not one
-- inside another tooltip (its field IsEmbedded, read only); then the look at the stats and the role (Look, below), at a build of any kind; the
-- data of a unit (Enum.TooltipDataType.Unit 2, TooltipInfoSharedDocumentation.lua:98), the role no healer at For tanks and damage dealers and
-- inputs kept; the same build not already given its lines (as SpellLines.lua tells a build: the same data with at least the lines added then still
-- there); the unit token, UnitTokenFromGUID of the data's guid, as the game's GetUnit reads it (Blizzard_SharedXMLGame/Tooltip/TooltipUtil.lua:
-- 34-42; GetUnit itself, a Lua method of GameTooltip, Blizzard_GameTooltip/Mainline/GameTooltip.lua:1035-1037, is not called), else "mouseover"
-- while its UnitGUID is that guid; a unit the player can attack (UnitCanAttack) that is not dead
-- (UnitIsDeadOrGhost); and a level the game gives plain (UnitLevel). A guid, a token or a level the game withholds (SecretWhenUnitIdentityRestricted,
-- UnitDocumentation.lua:3296-3310) says nothing; so does every value that is not plain (ns.IsSecret, ns.Finite).
--
-- The stats. Every stat call is SecretWhenUnitStatsRestricted: the game withholds them in fights. So the inputs of the table (C.Inputs, every kind
-- read, against no unit: an enemy of the player's level, which the unit shown replaces) are read only out of combat (InCombatLockdown,
-- UnitAffectingCombat) while the game gives the stats plain (C_Secrets.ShouldUnitStatsBeSecret, SecretPredicateAPIDocumentation.lua:388-396), as
-- the gear comparison reads them (GearModel.lua, StatsPlain), and an answer the game withheld any of (a gap "withheld") is not kept. They are read
-- at a build of GameTooltip of any kind, not only an enemy's, so the answer kept is that of the last tooltip out of a fight: the gear and buffs the
-- player pulled with. So in a fight the table is worked out from it with the unit's own level and facing (C.Target, C.Front and C.Table, which read
-- no stat), and one dim line says the stats are from before the fight, as SpellLines.lua says it. With none kept, nothing is said.
--
-- The cache: a build of a unit's tooltip comes often (TOOLTIP_DATA_UPDATE, GameTooltip.lua:970-973), so a read of the inputs and a look at the
-- role serve every build for AGAIN seconds, whatever the tooltip shows, until a fight ends or, out of one, the form or stance changes
-- (GetShapeshiftForm), and each read kept counts a version; the enemy (C.Target) is kept by the unit's guid and that version, and the lines by
-- those, the facing, the power type, whether the stats are from before the fight and the rows they follow. A build of the same enemy then costs
-- the tests, the facing (C.Front) and the adding, and C.Table only when one of those changed.
--
-- The look (0.5.20, the style of every tooltip line, SpellModel.lua's M.Fmt.Style): a gold header "Hit table" only when more than one line
-- follows; each line its label light grey on the left and its parts white on the right (AddDoubleLine), or light grey while they are from before
-- the fight; a part that does not apply left out, one the game did not give ?; and the notes dim, wrapped at the tooltip's width (AddLine's fifth
-- argument): the stats from before the fight, and an estimate (a level of ?? or a boss counted three above the player, a player's dodge, parry and
-- block counted from 5%, a weapon skill the game did not give counted as the most for the level, for a hand or a ranged weapon of a line shown);
-- and, while R is not 0, what it counts: the player's Spell Piercing against resistances not known, counted as 0, the share for the levels a
-- creature is above the player (an estimate, which piercing does not lower), which a spell with an effect beyond its damage does not take: it pays
-- for the levels with its higher miss. In Compact (chat.tipDetail) the notes are joined into one dim line, in Full each is its own.
--
-- The size (0.5.26): Text size on enemy tooltips (hud.hitTableTipSize, 70 to 200%, its ids the percent in text) sizes these lines alone, in a
-- share of the size the game gave each, with the face and flags it had (GetFont, SetFont): the left text of each line and the right text of a
-- pair, GameTooltipTextLeftN and GameTooltipTextRightN, the tooltip's own font strings, which every tooltip after it reuses. So each goes back as
-- the game had it when GameTooltip is next cleared, as the game clears it before it shows anything new: in the font object it had (GetFontObject;
-- the game gives the first two lines theirs with SetFontObject, SharedTooltipTemplates.lua:1-18), and at the font read before where it had none
-- or that object does not give it its own size. The OnTooltipCleared of its template calls GameTooltip_ClearMoney by name (Mainline/GameTooltip.xml:4, 31-34, 249;
-- Blizzard_MoneyFrame/Shared/MoneyFrame.lua:660), which this file follows (ns.FollowGlobal) from the first size other than 100% on; a client
-- without that function keeps the lines at the game's size. A font string still sized as new lines come is put back before they are added.
--
-- The work runs inside ns.EachPart keyed by the data of the build, new for each build, so three builds that fail stop this part alone with a line for
-- /flatui status, and the first error goes once to the game's error handler (geterrorhandler), as SpellLines.lua sends its own. The only writes are
-- widget calls on GameTooltip, each under pcall: NumLines, AddDoubleLine and AddLine, one the game refuses ending the adding for that build; on
-- the font strings of the lines added, SetFont, put back with SetFontObject (and SetFont) at the next clear (The size, above); and, as Ctrl goes
-- down over a kept build, Show, and SetText and SetTextColor on the hint's own font string (Ctrl, above). Chat.lua calls
-- ns.HitTableTipLines from its post call of the game's tooltip data (TooltipDataProcessor.AddTooltipPostCall), after the spell and gear lines and
-- before its own ID line.

local KEY, PART = "chat", "hit table lines"
local IsSecret, Finite = ns.IsSecret, ns.Finite

-- The constants of this file, in one table so that the main chunk keeps few locals.
local HT = {
	-- The row of this file and the rows of the Hit table page the lines follow (Config.lua), and Notes under the lines of Chat and tooltips.
	ROW = "hud.hitTableTip", LINES = "hud.hitTableLines", SPECIAL = "hud.hitTableSpecial", FACING = "hud.hitTableFacing", RULES = "hud.hitTableRules",
	DETAIL = "chat.tipDetail",
	-- Text size on enemy tooltips (Config.lua), and the names of the font strings of a line of GameTooltip: the side and the number of the line.
	SIZE = "hud.hitTableTipSize", FONT_STRING = "GameTooltipText%s%d",
	-- Only while Ctrl is held and Hint while Ctrl is up (Config.lua), the hint, and the keys of MODIFIER_STATE_CHANGED that are Ctrl.
	CTRL = "hud.hitTableTipCtrl", HINT = "hud.hitTableTipHint", HINT_TEXT = "Hold Ctrl for the hit table",
	CTRL_KEYS = { LCTRL = true, RCTRL = true },
	-- Enum.TooltipDataType.Unit, for a client whose Enum does not say (TooltipInfoSharedDocumentation.lua:98).
	UNIT = 2,
	-- The kinds C.Inputs reads: every one, so a change of Attacks or of form later finds the kind it needs among the inputs kept.
	KINDS = { melee = true, ranged = true, spell = true },
	-- Seconds a read of the inputs and a look at the role serve the builds that follow.
	AGAIN = 2,
	-- The levels a boss and a ?? count above the player, as the hit table counts them (HitTableCalc.lua, ABOVE).
	ABOVE = 3,
	-- The parts of a line in the order of the roll, each a letter with its figure (the owner: "make more concise parry = p, block = b, etc"):
	-- M miss, D dodge, P parry, G glance, B block, C crit, H hit, then R, the Spells line's resist; the row's tip says what each letter is. The crit
	-- cap is the hit table's alone.
	PARTS = { { "miss", "M" }, { "dodge", "D" }, { "parry", "P" }, { "glance", "G" }, { "block", "B" }, { "crit", "C" }, { "hit", "H" },
		{ "resist", "R" } },
	-- Between two parts: a space.
	SEPARATOR = " ",
	-- The label of each line of C.Table, by its id: short, as the line is.
	LABELS = { swing = "Swing", main = "Main hand", off = "Off hand", special = "Special", ranged = "Ranged", spell = "Spells" },
	HEADER = "Hit table",
	-- The colours of the style while SpellModel.lua's (M.Fmt.Style) cannot be read, as SpellLines.lua keeps them.
	STYLE = { header = { 1, 0.82, 0 }, label = { 0.82, 0.82, 0.82 }, value = { 1, 1, 1 }, dim = { 0.66, 0.68, 0.62 } },
	-- The notes, and what joins them into one line in Compact.
	OLD = "Your stats from before this fight",
	UNKNOWN = "Level ?? counted as %d",
	BOSS = "A boss counted as level %d",
	PLAYER = "A player's dodge, parry and block counted from 5%",
	ASSUMED = "Weapon skill counted as the most for your level",
	-- What R counts, one note: the piercing, then the share for the levels above (an estimate), which a spell that also slows or roots does not take.
	PIERCE = "R counts your Spell Piercing %d against resistances not known, counted as 0",
	LEVEL_RESIST = ", and ~%s for its levels above you, which piercing does not lower; a spell that also slows or roots pays for them with its higher miss instead",
	JOIN = "; ",
}

-- Per tooltip: { data, lines, hint } of the build that has the lines: its data, the tooltip's lines after them and the number of the hint's line.
local added = setmetatable({}, { __mode = "k" })
-- held: inputs (the last plain answer of C.Inputs), version (counts the answers kept), at (GetTime of the last look: a read tried and the role),
-- fought (that look was in a fight), role (the player's role at that look: "tank", "healer" or "damage"), form (GetShapeshiftForm at that look)
-- and stale (the last read tried was withheld).
local held = { version = 0, role = "damage", stale = false, fought = false }
-- made: targetKey and target (C.Target's answer for a guid and a version), key and lines (the lines as they are added, and what they were made for).
local made = {}
-- reported: the first error of the part went to the game's handler.
local run = { reported = false }
-- sized: the font strings of GameTooltip this file sized, each { fs, object, file, size, flags }: the font object and the font it had. follow: nil
-- until the first size other than 100%, then whether the clear of GameTooltip is followed.
local sizing = { sized = {} }
-- The build of an enemy's tooltip made while Ctrl was up: data and owner (the tooltip's owner then); frame hears the key.
local waiting = {}

-- Reading -----------------------------------------------------------------------------------------------------------------------------------

-- t[key], for pcall.
local function Index(t, key)
	return t[key]
end

-- A field of a table the game gave (the data, the tooltip), or nil when the table or the field is withheld or reading it raises.
local function Field(t, key)
	if IsSecret(t) or type(t) ~= "table" then
		return nil
	end
	local ok, value = pcall(Index, t, key)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

-- The first answer of a call of the client, or nil when the call is missing, raises or the answer is withheld.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

-- A plain string that is not empty, or nil.
local function Text(value)
	if IsSecret(value) or type(value) ~= "string" or value == "" then
		return nil
	end
	return value
end

-- On enemy tooltips: "role" (For tanks and damage dealers, the default), "on" (Always) or "off".
local function Choice()
	local value = ns.Get(HT.ROW)
	if value == "on" or value == "off" then
		return value
	end
	return "role"
end

-- The colours of the style: SpellModel.lua's M.Fmt.Style, else this file's.
local function Style()
	local M = ns.SpellModel
	local fmt = type(M) == "table" and type(M.Fmt) == "table" and M.Fmt or nil
	local style = fmt and type(fmt.Style) == "table" and fmt.Style or nil
	if style and type(style.header) == "table" and type(style.label) == "table" and type(style.value) == "table" and type(style.dim) == "table" then
		return style
	end
	return HT.STYLE
end

-- The value of Enum.TooltipDataType.Unit.
local function UnitType()
	local types = type(Enum) == "table" and Field(Enum, "TooltipDataType") or nil
	local value = Field(types, "Unit")
	return Finite(value) and value or HT.UNIT
end

-- The unit of the tooltip and its guid: UnitTokenFromGUID of the data's guid, as the game's GetUnit reads it (never called: a Lua method of
-- GameTooltip), else "mouseover" while it is that unit. Nil when the game gives no plain guid or token.
local function UnitOf(data)
	local guid = Text(Field(data, "guid"))
	if not guid then
		return nil
	end
	local unit = Text(Ask(UnitTokenFromGUID, guid))
	if not unit and Ask(UnitGUID, "mouseover") == guid then
		unit = "mouseover"
	end
	return unit, guid
end

-- True for a unit the player can attack that is not dead, whose level the game gives plain.
local function Enemy(unit)
	if Ask(UnitCanAttack, "player", unit) ~= true or Ask(UnitIsDeadOrGhost, unit) == true or type(UnitLevel) ~= "function" then
		return false
	end
	local ok, level = pcall(UnitLevel, unit)
	return ok and Finite(level)
end

-- The player's role (ns.PlayerRole's first answer), "damage" when it gives none.
local function Role()
	local role
	if type(ns.PlayerRole) == "function" then
		local ok, found = pcall(ns.PlayerRole)
		role = ok and Text(found) or nil
	end
	return (role == "tank" or role == "healer") and role or "damage"
end

-- True while the game withholds the stats now: in combat, or C_Secrets says so (a client without the call is asked nothing more).
local function Fighting()
	if Ask(InCombatLockdown) == true or Ask(UnitAffectingCombat, "player") == true then
		return true
	end
	local api = type(C_Secrets) == "table" and C_Secrets or nil
	local ask = api and Field(api, "ShouldUnitStatsBeSecret") or nil
	if type(ask) ~= "function" then
		return false
	end
	local ok, secret = pcall(ask)
	return not ok or IsSecret(secret) or secret ~= false
end

-- True for an answer of C.Inputs the game gave plain: the player's level, and no value withheld.
local function Plain(inputs)
	if type(inputs) ~= "table" or not Finite(inputs.level) then
		return false
	end
	for _, why in pairs(type(inputs.gaps) == "table" and inputs.gaps or {}) do
		if why == "withheld" then
			return false
		end
	end
	return true
end

-- A look, at most once in AGAIN seconds, at once as a fight ends and, out of one, at once after a change of form or stance: the role, and, out of
-- a fight while the lines are wanted, the inputs read again against no unit (an enemy of the player's level, which LinesFor replaces with the
-- unit shown); a plain answer is kept and counted. Answers whether the inputs held are from before the fight.
local function Look(C)
	local fighting = Fighting()
	local now = Ask(GetTime)
	now = Finite(now) and now or 0
	local form = Ask(GetShapeshiftForm)
	if held.at == nil or now - held.at >= HT.AGAIN or now < held.at or (held.fought and not fighting)
		or (not fighting and form ~= held.form) then
		held.at, held.fought, held.role, held.form = now, fighting, Role(), form
		if not fighting and not (Choice() == "role" and held.role == "healer") then
			local inputs = C.Inputs({ kinds = HT.KINDS, against = "level" })
			held.stale = not Plain(inputs)
			if not held.stale then
				held.inputs, held.version = inputs, held.version + 1
			end
		end
	end
	return fighting or held.stale
end

-- The table -------------------------------------------------------------------------------------------------------------------------------------

-- The enemy at its level (C.Target against the unit), a boss of the player's level or above three levels above the player at least (a boss below
-- the player, a dungeon's for a player far above it, keeps its level); kept by the guid and the version of the inputs. Nil, and nothing kept, when
-- C.Target does not count it an enemy or gives no level.
local function Against(C, inputs, unit, guid)
	local key = guid .. "|" .. held.version
	if made.targetKey ~= key then
		local target = C.Target(nil, inputs.level, unit)
		if type(target) ~= "table" or not target.enemy or not Finite(target.level) then
			return nil
		elseif target.kind == "boss" and target.level >= inputs.level and target.level < inputs.level + HT.ABOVE then
			target.level, target.raised = inputs.level + HT.ABOVE, true
		end
		made.targetKey, made.target = key, target
	end
	if made.target then
		-- The same guid may come under another token (the mouseover, a nameplate): C.Front asks the one shown now.
		made.target.unit = unit
	end
	return made.target
end

-- True while parries and blocks count: In front; Behind never; the first choice of Where you stand while the enemy attacks the player (C.Front),
-- and always for a tank.
local function Front(C, target)
	local facing = ns.Get(HT.FACING)
	if facing == "front" then
		return true
	elseif facing == "behind" then
		return false
	end
	return C.Front("auto", target) == true or held.role == "tank"
end

-- The right text of a line: each part that applies, in the order of the roll, with one decimal, ? where the game did not give it. Nil when no part
-- is known.

-- A part's figure: one decimal, without a trailing .0 (8.0 reads 8), and a figure that rounds to 0 without its sign.
local function Short(value)
	if math.abs(value) < 0.05 then
		value = 0
	end
	local text = ("%.1f"):format(value)
	text = text:gsub("%.0$", "")
	return text
end

local function Parts(line)
	local parts, known = {}, false
	for _, part in ipairs(HT.PARTS) do
		local value = line.parts[part[1]]
		if value ~= false then
			known = known or Finite(value)
			parts[#parts + 1] = part[2] .. (Finite(value) and Short(value) or "?")
		end
	end
	return known and table.concat(parts, HT.SEPARATOR) or nil
end

-- What R counts, in one note, while the Spells line shows one that is not 0: the piercing and the share for the levels above (C.Resist with none),
-- which a spell that also slows or roots does not take.
local function ResistNote(notes, read, target)
	local spell
	for _, line in ipairs(type(read.lines) == "table" and read.lines or {}) do
		if line.id == "spell" then
			spell = line
		end
	end
	local resist = spell and type(spell.parts) == "table" and spell.parts.resist
	if not Finite(resist) or math.abs(resist) < 0.05 or not Finite(spell.pen) then
		return
	end
	local note = HT.PIERCE:format(math.floor(spell.pen + 0.5))
	local C = ns.HitTableCalc
	local level = spell.levelResist and type(C) == "table" and type(C.Resist) == "function" and C.Resist(read.level, target.level, false, 0) or nil
	if Finite(level) and level >= 0.05 then
		note = note .. HT.LEVEL_RESIST:format(Short(level) .. "%")
	end
	notes[#notes + 1] = note
end

-- The notes of a table: the stats from before the fight, then each estimate, then what R counts.
local function Notes(read, target, old)
	local notes = {}
	if old then
		notes[#notes + 1] = HT.OLD
	end
	if target.unknown then
		notes[#notes + 1] = HT.UNKNOWN:format(target.level)
	elseif target.raised then
		notes[#notes + 1] = HT.BOSS:format(target.level)
	end
	if target.player then
		notes[#notes + 1] = HT.PLAYER
	end
	if type(read.assumed) == "table" and #read.assumed > 0 then
		notes[#notes + 1] = HT.ASSUMED
	end
	ResistNote(notes, read, target)
	return notes
end

-- The lines as they are added: the header where more than one line follows, a line for each attack, and the notes (joined in Compact).
local function Shape(read, target, old)
	local style, figures = Style(), {}
	for _, line in ipairs(type(read.lines) == "table" and read.lines or {}) do
		local right = type(line.parts) == "table" and Parts(line) or nil
		if right then
			figures[#figures + 1] = { left = HT.LABELS[line.id] or line.label, right = right, colour = style.label,
				rightColour = old and style.label or style.value }
		end
	end
	local lines = {}
	if #figures == 0 then
		return lines
	elseif #figures > 1 then
		lines[1] = { left = HT.HEADER, colour = style.header, wrap = false, header = true }
	end
	for _, line in ipairs(figures) do
		lines[#lines + 1] = line
	end
	local notes = Notes(read, target, old)
	if #notes > 0 and ns.Get(HT.DETAIL) == "full" then
		for _, note in ipairs(notes) do
			lines[#lines + 1] = { left = note .. ".", colour = style.dim, wrap = true }
		end
	elseif #notes > 0 then
		lines[#lines + 1] = { left = table.concat(notes, HT.JOIN) .. ".", colour = style.dim, wrap = true }
	end
	return lines
end

-- The lines against the enemy, from the inputs held with the enemy and the facing of now (C.Table, which reads nothing); kept while the guid, the
-- version, the facing, the power type, the age of the stats and the rows are the same.
local function LinesFor(C, unit, guid, old)
	local inputs = held.inputs
	local target = Against(C, inputs, unit, guid)
	if not target then
		return nil
	end
	local front = Front(C, target)
	-- The power type now, which By your class and form picks a druid's kinds by: a form taken in a fight counts, the stats kept being every kind's.
	local power = Ask(UnitPowerType, "player")
	if not Finite(power) then
		power = inputs.power
	end
	local key = table.concat({ guid, held.version, tostring(front), tostring(old), tostring(power), tostring(ns.Get(HT.LINES)),
		tostring(ns.Get(HT.SPECIAL)), tostring(ns.Get(HT.RULES)), tostring(ns.Get(HT.DETAIL)) }, "|")
	if made.key == key then
		return made.lines
	end
	-- A copy of the inputs with the enemy, the facing and the kinds Attacks asks for by the class and the power type now.
	local copy = {}
	for field, value in pairs(inputs) do
		copy[field] = value
	end
	copy.target, copy.front, copy.facingUnsure = target, front, false
	local kinds = C.Kinds(ns.Get(HT.LINES), inputs.class, power)
	if type(kinds) == "table" then
		copy.melee = kinds.melee and inputs.melee or nil
		copy.ranged = kinds.ranged and inputs.ranged or nil
		copy.spell = kinds.spell and inputs.spell or nil
	end
	-- The hands whose skill stood in (HitTableCalc.lua, HandSkill: "main hand", "off hand", "ranged weapon") of the kinds shown only, so a note of a
	-- weapon skill never hangs under a spell line alone.
	local assumed = {}
	for _, hand in ipairs(type(inputs.assumed) == "table" and inputs.assumed or {}) do
		if (hand == "ranged weapon" and copy.ranged) or (hand ~= "ranged weapon" and copy.melee) then
			assumed[#assumed + 1] = hand
		end
	end
	copy.assumed = assumed
	local read = C.Table({ special = ns.Get(HT.SPECIAL) ~= false, rules = ns.Get(HT.RULES) }, copy)
	made.key, made.lines = key, type(read) == "table" and Shape(read, target, old) or {}
	return made.lines
end

-- Sizing -----------------------------------------------------------------------------------------------------------------------------------------

-- The size of a font string or a font object, or nil.
local function SizeOf(font)
	local ok, _, size = pcall(font.GetFont, font)
	return ok and Finite(size) and size or nil
end

-- Puts back every font string sized: in its font object, or, where it had none or that does not give it the object's size, at the font read before.
local function Unsize()
	local sized = sizing.sized
	for index = #sized, 1, -1 do
		local entry = sized[index]
		sized[index] = nil
		local fs, object = entry.fs, entry.object
		local back = object ~= nil and pcall(fs.SetFontObject, fs, object)
		if back then
			local want, have = SizeOf(object), SizeOf(fs)
			back = want ~= nil and have ~= nil and math.abs(want - have) < 0.5
		end
		if not back then
			pcall(fs.SetFont, fs, entry.file, entry.size, entry.flags)
		end
	end
end

-- After each clear of a tooltip whose OnTooltipCleared calls GameTooltip_ClearMoney: GameTooltip's sized lines go back.
local function Cleared(tooltip)
	if #sizing.sized > 0 and rawequal(tooltip, GameTooltip) then
		Unsize()
	end
end

-- Text size on enemy tooltips in percent: 100 for none.
local function Percent()
	local value = tonumber(ns.Get(HT.SIZE))
	return Finite(value) and value > 0 and value or 100
end

-- Sizes the font strings of line number `index` of GameTooltip, its right one too for a pair, to percent of the size the game gave them, once the
-- clear of GameTooltip is followed, and keeps what each had.
local function Size(index, pair, percent)
	if sizing.follow == nil then
		sizing.follow = ns.FollowGlobal("GameTooltip_ClearMoney", Cleared) == true
	end
	if not sizing.follow then
		return
	end
	for side = 1, pair and 2 or 1 do
		local fs = _G[HT.FONT_STRING:format(side == 1 and "Left" or "Right", index)]
		local ok, file, size, flags = false, nil, nil, nil
		if not ns.Forbidden(fs) then
			ok, file, size, flags = pcall(fs.GetFont, fs)
		end
		if ok and Text(file) and Finite(size) and size > 0 and not IsSecret(flags) then
			local found, object = pcall(fs.GetFontObject, fs)
			object = found and not IsSecret(object) and type(object) == "table" and object or nil
			flags = type(flags) == "string" and flags or ""
			if pcall(fs.SetFont, fs, file, size * percent / 100, flags) then
				local sized = sizing.sized
				sized[#sized + 1] = { fs = fs, object = object, file = file, size = size, flags = flags }
			end
		end
	end
end

-- Adding -----------------------------------------------------------------------------------------------------------------------------------------

-- ns.HitTableCalc while it has every call the lines need, else nil.
local function Calc()
	local C = ns.HitTableCalc
	if type(C) ~= "table" or type(C.Inputs) ~= "function" or type(C.Table) ~= "function" or type(C.Target) ~= "function"
		or type(C.Front) ~= "function" or type(C.Kinds) ~= "function" then
		return nil
	end
	return C
end

-- Adds one line to the tooltip: a label and its parts side by side, or a line alone, wrapped when it asks. True when the game took it.
local function Put(tooltip, line)
	local left, right = line.colour, line.rightColour
	if line.right then
		return (pcall(tooltip.AddDoubleLine, tooltip, line.left, line.right, left[1], left[2], left[3], right[1], right[2], right[3]))
	end
	return (pcall(tooltip.AddLine, tooltip, line.left, left[1], left[2], left[3], line.wrap == true))
end

-- Adds the lines from number `first` on under the `shown` lines of the tooltip, each sized by Text size on enemy tooltips; a line the game refuses
-- ends the adding. Answers the tooltip's lines after them.
local function Add(tooltip, lines, shown, first)
	local percent = Percent()
	for index = first, #lines do
		local line = lines[index]
		if not Put(tooltip, line) then
			break
		end
		shown = shown + 1
		if percent ~= 100 then
			Size(shown, line.right ~= nil, percent)
		end
	end
	return shown
end

-- Sends the first error of this part once to the game's error handler, as SpellLines.lua sends its own.
local function Report(ok, err)
	if ok or err == nil or run.reported then
		return
	end
	run.reported = true
	local found, handler = false, nil
	if type(geterrorhandler) == "function" then
		found, handler = pcall(geterrorhandler)
	end
	if found and type(handler) == "function" then
		pcall(handler, ("Flat UI Chat and tooltips, %s: %s"):format(PART, tostring(err)))
	end
end

-- Ctrl -------------------------------------------------------------------------------------------------------------------------------------------

-- True while Ctrl is down. A key the game does not say is down counts as up.
local function CtrlDown()
	return Ask(IsControlKeyDown) == true
end

-- The owner of the tooltip, or nil.
local function OwnerOf(tooltip)
	local ok, owner = pcall(tooltip.GetOwner, tooltip)
	if ok and not IsSecret(owner) then
		return owner
	end
	return nil
end

-- The first info of the tooltip (its field infoList, read only), or nil.
local function FirstInfo(tooltip)
	return Field(Field(tooltip, "infoList"), 1)
end

-- The kept build goes, and the event with it.
local function Unwait()
	waiting.data, waiting.owner = nil, nil
	if waiting.frame then
		pcall(waiting.frame.UnregisterEvent, waiting.frame, "MODIFIER_STATE_CHANGED")
	end
end

-- The left font string of line number `index` of the tooltip while it still reads the hint, else nil.
local function HintString(index, shown)
	if not Finite(index) or index > shown then
		return nil
	end
	local fs = _G[HT.FONT_STRING:format("Left", index)]
	if ns.Forbidden(fs) then
		return nil
	end
	local ok, text = pcall(fs.GetText, fs)
	if ok and not IsSecret(text) and text == HT.HINT_TEXT then
		return fs
	end
	return nil
end

-- Ctrl went down over the kept build (KeyChanged, inside ns.EachPart): its lines, added there and then with the calls a build adds them with,
-- under every line the tooltip has; the hint, where it still shows, becomes their header. Then GameTooltip is shown again so it takes their size.
-- Once for the build: it is no longer kept, and the record of the lines says it has them.
local function Pressed(data, tooltip)
	Unwait()
	local C = Calc()
	if not C then
		return
	end
	local old = Look(C)
	if (Choice() == "role" and held.role == "healer") or not held.inputs then
		return
	end
	local ok, shown = pcall(tooltip.NumLines, tooltip)
	if not ok or not Finite(shown) then
		return
	end
	local unit, guid = UnitOf(data)
	if not unit or not Enemy(unit) then
		return
	end
	local lines = LinesFor(C, unit, guid, old)
	if not lines or #lines == 0 then
		return
	end
	local record, first = added[tooltip], 1
	local fs = record and rawequal(record.data, data) and HintString(record.hint, shown) or nil
	if fs and pcall(fs.SetText, fs, HT.HEADER) then
		local colour = Style().header
		pcall(fs.SetTextColor, fs, colour[1], colour[2], colour[3])
		first = lines[1].header and 2 or 1
	end
	shown = Add(tooltip, lines, shown, first)
	added[tooltip] = { data = data, lines = shown }
	pcall(tooltip.Show, tooltip)
end

-- A change of a modifier key: as Ctrl goes down while GameTooltip still shows the kept build, its lines are added (Pressed). Ctrl let go does
-- nothing: the lines stay until the game builds the tooltip again. An owner or a tooltip with an UpdateTooltip, as a unit frame, is left to the
-- game, which builds it again within 0.2 seconds with the key as it is then.
local function KeyChanged(_, _, key)
	if IsSecret(key) or not HT.CTRL_KEYS[key] or waiting.data == nil or not CtrlDown() then
		return
	end
	local tip, data = GameTooltip, waiting.data
	if ns.Get(HT.CTRL) ~= true or Choice() == "off" or not ns.Enabled(KEY) or ns.PartStopped(KEY, PART)
		or type(tip) ~= "table" or ns.Forbidden(tip) then
		Unwait()
		return
	end
	if Ask(tip.IsShown, tip) ~= true or not rawequal(Field(FirstInfo(tip), "tooltipData"), data)
		or not rawequal(OwnerOf(tip), waiting.owner) then
		Unwait()
		return
	end
	if type(Field(waiting.owner, "UpdateTooltip")) == "function" or type(Field(tip, "UpdateTooltip")) == "function" then
		return
	end
	Report(ns.EachPart(KEY, PART, Pressed, data, tip))
end

-- Keeps the build of an enemy's tooltip made while Ctrl is up, and hears the key while it is kept.
local function Wait(tooltip, data)
	if not waiting.frame and type(CreateFrame) == "function" then
		local ok, frame = pcall(CreateFrame, "Frame")
		if ok and not IsSecret(frame) and type(frame) == "table" then
			ns.Own[frame] = true
			frame:SetScript("OnEvent", KeyChanged)
			waiting.frame = frame
		end
	end
	if not waiting.frame then
		return
	end
	waiting.data, waiting.owner = data, OwnerOf(tooltip)
	pcall(waiting.frame.RegisterEvent, waiting.frame, "MODIFIER_STATE_CHANGED")
end

-- Building ---------------------------------------------------------------------------------------------------------------------------------------

-- The tests and the lines of one build (header), once for each build: the same data with at least the lines added then still there is the same
-- build, so a second post call of it adds none, and a refused line ends the adding for that build. Every build of GameTooltip looks first, so the
-- inputs kept are those of the last tooltip shown out of a fight, whatever it showed.
local function Work(data, tooltip)
	if not rawequal(tooltip, GameTooltip) or ns.Forbidden(tooltip) then
		return
	end
	local readable, embedded = pcall(Index, tooltip, "IsEmbedded")
	if not readable or IsSecret(embedded) or embedded == true then
		return
	end
	-- A new build: the one kept for Ctrl goes, unless this one is kept again below.
	if waiting.data ~= nil and not rawequal(waiting.data, data) then
		Unwait()
	end
	local C = Calc()
	if not C then
		return
	end
	local old = Look(C)
	if Field(data, "type") ~= UnitType() or (Choice() == "role" and held.role == "healer") or not held.inputs then
		return
	end
	local ok, shown = pcall(tooltip.NumLines, tooltip)
	if not ok or not Finite(shown) then
		return
	end
	local record = added[tooltip]
	if record and rawequal(record.data, data) and shown >= record.lines then
		return
	end
	local unit, guid = UnitOf(data)
	if not unit or not Enemy(unit) then
		return
	end
	-- Only while Ctrl is held: a build made while it is up is kept for the key, and only the hint, with Hint while Ctrl is up, stands for the lines.
	local hint = ns.Get(HT.CTRL) == true and not CtrlDown()
	if hint then
		Wait(tooltip, data)
		if ns.Get(HT.HINT) ~= true then
			return
		end
	end
	local lines = LinesFor(C, unit, guid, old)
	if not lines or #lines == 0 then
		return
	elseif hint then
		lines = { { left = HT.HINT_TEXT, colour = Style().dim, wrap = false } }
	end
	if #sizing.sized > 0 then
		Unsize()
	end
	local before = shown
	shown = Add(tooltip, lines, shown, 1)
	added[tooltip] = { data = data, lines = shown, hint = hint and shown > before and shown or nil }
end

-- Called by Chat.lua's post call for every build of a tooltip of any kind: nothing unless the chat module is on and On enemy tooltips is not Off;
-- then the work inside ns.EachPart keyed by the data of the build, so a fault stops this part alone and never reaches the post call.
function ns.HitTableTipLines(tooltip, data)
	if Choice() == "off" or not ns.Enabled(KEY) or ns.PartStopped(KEY, PART) then
		return
	end
	-- The first argument of ns.EachPart is the key of its failures, which a withheld value may not be.
	if IsSecret(tooltip) or IsSecret(data) or type(data) ~= "table" then
		return
	end
	Report(ns.EachPart(KEY, PART, Work, data, tooltip))
end
