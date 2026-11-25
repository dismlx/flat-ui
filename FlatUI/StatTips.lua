local _, ns = ...

-- Explain the stats (windows.statTips, in the Character window section of Item slots, on by default; part "stat tips" of Windows, as Show thorns
-- is its part "thorns"): the tooltip of each stat on the Character window's stats list gains a few plain lines in Flat UI's voice after the
-- game's own, in the player's numbers now: what the stat does, what it is worth against an enemy of the player's level and against the boss three
-- levels above that Against names (chat.gearAgainst, as GearAvoid.lua reads it), and where it matters what to aim for. The owner asked for it ("i
-- want to improve the way i understand block, block vanlue, avoidance, etc - things in the character stats that arent well enough described").
-- This file holds the hook and the registry, and the lines of Defense, Dodge, Parry, Block, Armor and the resistances; StatTipsMore.lua sets
-- those of the other stats.
--
-- The registry. ns.StatTips.text[TOKEN] = function(tooltip, unit) adds the lines of one stat. TOKEN is the stat of PAPERDOLL_STATCATEGORIES
-- (Camelot/PaperDollFrameConstants.lua:35-117), or for a resistance the sheet's own token of its school, HOLY_RESIST to ARCANE_RESIST
-- (PAPERDOLL_STATINFO, Camelot/PaperDollFrame.lua:255-273); unit is "player" or "pet" (the pet's list shows some of the same stats, and a stat may
-- add nothing for it). tooltip stands in for GameTooltip: its AddLine and AddDoubleLine are kept in order and written to GameTooltip only once
-- the function has returned without an error, so a function that fails adds nothing (its first error goes to /flatui status); its NumLines
-- counts them with the tooltip's, its GetOwner, IsOwned, IsShown, IsVisible, IsForbidden, GetName, GetWidth and GetHeight answer as GameTooltip
-- does, and any other method does nothing, so no line of the game's is cleared, hidden or moved. A function reads its own values and checks each
-- with ns.IsSecret or ns.Finite, or uses a plain snapshot; in a fight it says nothing, or gives the numbers of the last plain read with a line
-- that says they are from before the fight. ns.StatTips.Head, Pair, Note and Old write a gold heading after a blank line, a label with its value
-- (AddDoubleLine), a dim wrapped note and that line, in the one style of Flat UI's tooltip lines (SpellModel.lua's M.Fmt.Style, looked up when
-- first written); ns.StatTips.Sheet gives GearAvoid.lua's A.Sheet.
--
-- The hook. The stats list is a scroll box of rows (CharacterStatsPaneScrollBox and CharacterStatsPanePetScrollBox, Camelot/CharacterFrame.xml:463,
-- 479), each a frame of CharacterStatFrameScrollBoxLabelElementTemplate or, for a resistance, of CharacterStatFrameScrollBoxIconElementTemplate
-- (:175-233), given its stat by Init (Camelot/CharacterFrame.lua:1239-1284): elementData.name is the token and elementData.unit the unit, and Init
-- runs that stat's updateFunc of PAPERDOLL_STATINFO, which writes the row's tooltip fields; a resistance row has no name, only its atlas
-- ("UI-Character-Info-Resistance-Fire") and its label (DAMAGE_SCHOOL2 to 7, :76-82, 1192-1222). Its OnEnter (CharacterStatFrameMixin:OnEnter,
-- :1028-1034) runs the row's onEnterFunc or PaperDollStatTooltip, which own GameTooltip (SetOwner) and show it. So the hook follows, with
-- ns.FollowTable, the Init of CharacterStatFrameScrollBoxBaseElementMixin (the icon rows' Init calls it by name, :1279-1280; the label rows copy
-- it when they are made) and the updateFunc of each stat of PAPERDOLL_STATCATEGORIES (called by name at every update, so a row made before the
-- hook is found too), and keeps each row's token and unit in a weak table of its own; a resistance row's unit is "pet" under
-- CharacterStatsPanePetScrollBox (GetParent). Each row found gets one post-hook of its OnEnter and OnLeave (HookScript, which writes nothing on
-- the row; never on a protected frame in a fight). After the game's OnEnter, while the row is on (Windows on, windows.statTips, the part not
-- stopped) and GameTooltip shows and is owned by the row (IsOwned, IsShown), the stat's function runs under pcall into the stand-in, its lines
-- go to GameTooltip (AddLine, AddDoubleLine) and GameTooltip is shown again (Show) so it takes their size. Movement speed's tooltip is written
-- again while it shows (the row's UpdateTooltip is MovementSpeed_OnEnter, Camelot/PaperDollFrame.lua:1407-1421, which GameTooltip_OnUpdate runs,
-- Blizzard_GameTooltip/Mainline/GameTooltip.lua:451-461), so MovementSpeed_OnEnter is followed with ns.FollowGlobal and its lines come again:
-- once a build, as the tooltip's count of lines after them (NumLines) tells, until the mouse leaves the row. The hooks go in as Windows starts
-- and when the row changes (ns.StatTipsChanged), so a profile that turns the row on finds them in, and stay; while the row is off they add
-- nothing. With taintLog on, hooks on the game's tables are refused (ns.HookMethod, Core.lua), and the lines wait for a session without it, as
-- /flatui status says.
--
-- The lines of this file, English as all of Flat UI's lines are. They read GearAvoid.lua's snapshot through A.Sheet (the level, defense skill,
-- dodge, parry and block chance, block value, armor, Strength and Agility of SpellModel.lua's last plain read; old in a fight) and its rules: the
-- table of one enemy swing (miss and crit from defense against the attacker's skill at 0.04% a point and 5 skill a level, crushing blows from 15
-- skill above, Camelot/PaperDollFrameStats.lua:7-10, 46-82; a boss's dodge, parry and block by Classic's rule, marked ~), armor's share from
-- C_PaperDollInfo.GetArmorEffectiveness (A.ArmorPct) and the enemy Against names (A.Against). Defense: out of 100 melee swings from an enemy of
-- the player's level and from that boss, how many miss, are dodged, parried or blocked, crit (200% damage) or crush (150%), and how many hit
-- normally ("Critical Strikes from creatures deal 200% damage. Creatures 3+ levels above you can land Crushing Blows for 150% damage",
-- DEFAULT_STATDEFENSE_TOOLTIP, WoW: Forever's GlobalStrings enUS.lua:5767); that from behind a swing cannot be dodged, parried or blocked
-- (CR_DODGE_BASE_STAT_TOOLTIP, CR_PARRY_BASE_STAT_TOOLTIP and STAT_BLOCK_VALUE_FLAT_TOOLTIP, :5524, 5540, 22312); and the two marks a tank aims
-- for, with how far the player is from each: the defense at which the boss no longer crits (5 skill a level of the boss and 125 more: 440 against
-- a raid boss of level 63, as that string says), and the boss's swings missed, dodged, parried and blocked together reaching 100%, past which its
-- one roll has no room for a crushing blow (GearAvoid.lua's table, its CRUSH_STOP). Dodge, Parry and Block: how many of 100 swings each stops
-- against both enemies, and the 0.04% a point of defense over 5 a level adds to each (STAT_PER_DEFENSE, Camelot/PaperDollFrameStats.lua:348,
-- 364, and the same string); Dodge also the dodge all of Agility gives (GetDodgeChanceFromAttribute, as the sheet shows it, :316) and the Agility
-- for 1% more; Block also how much one block stops (GetShieldBlock), and, only where the three add up to it, the shield's own block (SpellModel.lua's
-- state.shieldBlock, read from the shield's lines) and a point for 20 Strength (BLOCK_VALUE_PER_STRENGTH, :2, 313; "Increases Block Value by %d",
-- WARRIOR_STRENGTH_TOOLTIP, enUS.lua:25596), and that only melee and ranged hits from the front are blocked. Armor: the share of physical damage
-- it takes off against both enemies, what 100 more would add, and that it does nothing against spells ("Reduces Physical Damage taken",
-- STAT_ARMOR_TOOLTIP, :22298). A resistance: the average share of that school's damage it resists against both (the client's
-- ExpectedSpellResistance, Camelot/PaperDollFrameStats.lua:234-236, with the enemy's level as the caster's, as the sheet's own line reads it,
-- RESISTANCE_TOOLTIP_SUBTEXT, enUS.lua:18716), what 10 more would add, and that it does nothing against physical hits; the resistance is
-- UnitResistance's effective answer (UnitDocumentation.lua:3014-3032), read as the tooltip opens, else the last plain one, said to be from before
-- the fight. A boss's lines show only while Against names one (at its first choice from level 60 on), and Defense says how to see them. None of
-- these stats says anything for the pet.
-- Beyond those hooks it writes nothing of the game's: no field of a frame or table, no method of a row, no frame of its own and no event heard.

ns.StatTips = ns.StatTips or {}
ns.StatTips.text = ns.StatTips.text or {}

local ST = ns.StatTips
local KEY, PART, ROW = "windows", "stat tips", "windows.statTips"
local IsSecret, Finite = ns.IsSecret, ns.Finite

-- The constants of the file, in one table so its functions stay under the client's count of upvalues.
local K = {
	-- A resistance row by the end of its atlas (Camelot/CharacterFrame.lua:76-82): its school's Enum.Damageclass (DamageConstantsDocumentation.lua:
	-- 47-53), the sheet's token for it (PAPERDOLL_STATINFO) and the word the lines name it by.
	SCHOOLS = { Holy = 1, Fire = 2, Nature = 3, Frost = 4, Shadow = 5, Arcane = 6 },
	TOKENS = { "HOLY_RESIST", "FIRE_RESIST", "NATURE_RESIST", "FROST_RESIST", "SHADOW_RESIST", "ARCANE_RESIST" },
	WORDS = { "holy", "fire", "nature", "frost", "shadow", "arcane" },
	-- The parents walked from a row to find the pet's stats list.
	DEPTH = 6,
	-- The rows of one enemy swing, in the order of GearAvoid.lua's roll, with their words, and those a tank counts as avoided.
	ROWS = { { "missed", "Missed" }, { "dodged", "Dodged" }, { "parried", "Parried" }, { "blocked", "Blocked" },
		{ "crit", "Critical hit, 200% damage" }, { "crush", "Crushing blow, 150% damage" }, { "hit", "Normal hit" } },
	AVOIDED = { "missed", "dodged", "parried", "blocked" },
	-- The sheet's rules (Camelot/PaperDollFrameStats.lua:2, 313, 348): a point of block value for 20 Strength, 0.04% a point of defense over the cap.
	PER_STRENGTH = 20, PER_DEFENSE = 0.04,
	-- What the "more" lines add, and 100% avoided with the least under it that shows as 100.0.
	MORE_ARMOR = 100, MORE_RESIST = 10, FULL = 100, NEAR = 0.05,
	-- The reads of GameTooltip the stand-in answers as the tooltip does.
	READS = { "GetOwner", "IsOwned", "IsShown", "IsVisible", "IsForbidden", "GetName", "GetWidth", "GetHeight" },
	-- The colours where SpellModel.lua's style has none: the gold of a header, the light grey of a label, the white of a value and the dim of a
	-- note, as GearAvoid.lua's K.STYLE has them.
	STYLE = { header = { 1, 0.82, 0 }, label = { 0.82, 0.82, 0.82 }, value = { 1, 1, 1 }, dim = { 0.66, 0.68, 0.62 } },
}

-- The words.
local T = {
	SWINGS = "Out of 100 melee swings",
	COLUMNS = "Level %d  ·  Boss %d",
	COLUMN = "Level %d",
	BOTH = "%s  ·  %s",
	FRONT = "From the front. From behind, a swing cannot be dodged, parried or blocked.",
	ESTIMATE = "~ marks an estimate by Classic's rules, which the game's own data does not show.",
	AIMS = "What a tank aims for",
	NO_CRITS = "Defense %d: no crits from a boss",
	NO_CRUSH = "100% avoided: no crushing blows",
	TO_GO = "%s now, %s to go",
	REACHED = "%s now, reached",
	AVOIDED = "Avoided adds up a boss's swings missed, dodged, parried and blocked. Once it reaches 100%, the boss lands no crushing blows.",
	NO_SHIELD = "With no shield nothing is blocked, so a boss's crushing blows stay.",
	NO_BOSS_AUTO = "A boss's numbers show from level 60, or with Against on the Gear comparison page set to a boss.",
	NO_BOSS_LEVEL = "A boss's numbers show with Against on the Gear comparison page set to a boss.",
	OLD = "From before the fight: the game hides your stats during one.",
	POINTER = "Defense's tooltip shows every way an enemy's swing can land.",
	ENEMY = "Level %d enemy",
	BOSS = "Level %d boss",
	IN_100 = "%s in 100 swings",
	DODGE = "What your dodge does",
	PARRY = "What your parry does",
	BLOCK = "What your block does",
	ARMOR = "What your armor does",
	RESIST = "What your %s resistance does",
	FROM_AGILITY = "From Agility",
	FROM_DEFENSE = "From defense over %d",
	AGILITY_FOR = "Agility for 1% more dodge",
	BLOCK_STOPS = "One block stops",
	DAMAGE = "%s damage",
	FROM_SHIELD = "From your shield",
	FROM_STRENGTH = "From Strength, 1 for 20",
	FROM_REST = "From other gear and talents",
	BLOCK_NOTE = "Only melee and ranged hits from the front are blocked, and a block takes your block value off the hit.",
	ARMOR_CUT = "%s%% less physical damage",
	MORE_ARMOR = "%d more armor",
	MORE_CUT = "+%s%% against level %d",
	ARMOR_NOTE = "Armor cuts physical hits only, never spells: resistances cut those.",
	RESISTED = "%d%% of %s damage, on average",
	MORE_RESIST = "%d more resistance",
	MORE_RESISTED = "+%s%% against level %d",
	RESIST_NOTE = "It cuts %s damage only, and does nothing against physical hits: armor cuts those.",
	FAILED = "Explain the stats: the lines of %s failed: %s",
	TAINT = "Explain the stats: waits while the game's taintLog is on, as hooks on its tables fail then.",
}
-- The words StatTipsMore.lua shares (0.5.36), so every stat has the same columns, the same mark between two values and the same line for a fight.
ST.OLD, ST.COLUMNS, ST.COLUMN, ST.BOTH = T.OLD, T.COLUMNS, T.COLUMN, T.BOTH

-- Reading ----------------------------------------------------------------------------------------------------------------------------------------

local function Index(t, key)
	return t[key]
end

-- A field of a table, or nil when the table or the field is withheld, or reading it raises.
local function Field(t, key)
	if t == nil or IsSecret(t) or type(t) ~= "table" then
		return nil
	end
	local ok, value = pcall(Index, t, key)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

local function Num(value)
	if Finite(value) then
		return value
	end
	return nil
end

local function Text(value)
	if not IsSecret(value) and type(value) == "string" then
		return value
	end
	return nil
end

local function Gear()
	local A = ns.GearAvoid
	if type(A) == "table" then
		return A
	end
	return nil
end

-- The player's level, or nil.
local function PlayerLevel()
	local ok, level = pcall(UnitLevel, "player")
	if ok and Finite(level) and level > 0 then
		return level
	end
	return nil
end

-- The style -------------------------------------------------------------------------------------------------------------------------------------

local function Colour(value)
	local r, g, b = Num(Field(value, 1)) or Num(Field(value, "r")), Num(Field(value, 2)) or Num(Field(value, "g")),
		Num(Field(value, 3)) or Num(Field(value, "b"))
	if r and g and b then
		return { r, g, b }
	end
	return nil
end

local held = { style = nil }

-- The colours of the lines: SpellModel.lua's one style (M.Fmt.Style), kept once it is there; K.STYLE stands in for one it does not have.
function ST.Style()
	if held.style then
		return held.style
	end
	local given = Field(Field(ns.SpellModel, "Fmt"), "Style")
	local out = {}
	for name, fallback in pairs(K.STYLE) do
		out[name] = Colour(Field(given, name)) or fallback
	end
	if given then
		held.style = out
	end
	return out
end

-- A gold heading after a blank line; with right, a heading of two columns.
function ST.Head(tip, text, right)
	local c = ST.Style().header
	tip:AddLine(" ")
	if right then
		tip:AddDoubleLine(text, right, c[1], c[2], c[3], c[1], c[2], c[3])
	else
		tip:AddLine(text, c[1], c[2], c[3])
	end
end

-- A label in light grey and its value in white.
function ST.Pair(tip, left, right)
	local style = ST.Style()
	local l, v = style.label, style.value
	tip:AddDoubleLine(left, right, l[1], l[2], l[3], v[1], v[2], v[3])
end

-- A dim note, wrapped.
function ST.Note(tip, text)
	local c = ST.Style().dim
	tip:AddLine(text, c[1], c[2], c[3], true)
end

-- The line that says the numbers are from before the fight.
function ST.Old(tip)
	ST.Note(tip, T.OLD)
end

-- GearAvoid.lua's numbers of the sheet (A.Sheet): { snap, cap, level, boss, old }, or nil.
function ST.Sheet()
	local fn = Field(Gear(), "Sheet")
	if type(fn) ~= "function" then
		return nil
	end
	local ok, sheet = pcall(fn)
	if ok and type(sheet) == "table" and type(sheet.snap) == "table" and type(sheet.level) == "table" then
		return sheet
	end
	return nil
end

-- Numbers ---------------------------------------------------------------------------------------------------------------------------------------

local function One(value)
	return ("%.1f"):format(value)
end

local function Two(value)
	return ("%.2f"):format(value)
end

-- A whole number, its thousands broken as the game breaks them (BreakUpLargeNumbers).
local function Whole(value)
	local rounded = math.floor(value + 0.5)
	local fn = _G.BreakUpLargeNumbers
	if type(fn) == "function" then
		local ok, text = pcall(fn, rounded)
		if ok and Text(text) then
			return text
		end
	end
	return ("%d"):format(rounded)
end

local function Estimated(t, key)
	return Field(Field(t, "estimate"), key) == true
end

local function Mark(text, estimate)
	if estimate then
		return "~" .. text
	end
	return text
end

-- A row of a table of GearAvoid.lua's (Work) to one decimal, ~ first for an estimate.
local function Cell(t, key)
	local value = Num(Field(t, key))
	if not value then
		return "-"
	end
	return Mark(One(value), Estimated(t, key))
end

local function Old(tip, sheet)
	if sheet.old then
		ST.Old(tip)
	end
end

-- The lines -------------------------------------------------------------------------------------------------------------------------------------

-- Out of 100 melee swings from an enemy of the player's level, and from the boss while Against names one: each row with a number in either.
local function Swings(tip, sheet)
	local L, B = sheet.level, sheet.boss
	ST.Head(tip, T.SWINGS, B and T.COLUMNS:format(L.attacker, B.attacker) or T.COLUMN:format(L.attacker))
	local estimate = false
	for _, row in ipairs(K.ROWS) do
		local key = row[1]
		local mine, boss = Num(L[key]) or 0, B and Num(B[key]) or 0
		if key == "hit" or mine > 0 or boss > 0 then
			local right = Cell(L, key)
			if B then
				right = T.BOTH:format(right, Cell(B, key))
			end
			ST.Pair(tip, row[2], right)
			estimate = estimate or Estimated(L, key) or (B ~= nil and Estimated(B, key))
		end
	end
	ST.Note(tip, T.FRONT)
	if estimate then
		ST.Note(tip, T.ESTIMATE)
	end
end

-- The two marks a tank aims for against the boss, with how far the player is from each; with no boss, how to see them.
local function Aims(tip, sheet)
	local B, s = sheet.boss, sheet.snap
	if not B then
		ST.Note(tip, ns.Get("chat.gearAgainst") == "level" and T.NO_BOSS_LEVEL or T.NO_BOSS_AUTO)
		return
	end
	ST.Head(tip, T.AIMS)
	local defense, immune = math.floor(s.defense + 0.5), math.floor((Num(B.immuneAt) or 0) + 0.5)
	local right
	if defense >= immune then
		right = T.REACHED:format(defense)
	else
		right = T.TO_GO:format(defense, immune - defense)
	end
	ST.Pair(tip, T.NO_CRITS:format(immune), right)
	local sum, estimate = 0, false
	for _, key in ipairs(K.AVOIDED) do
		sum = sum + (Num(B[key]) or 0)
		estimate = estimate or Estimated(B, key)
	end
	local now = Mark(One(sum) .. "%", estimate)
	if sum >= K.FULL - K.NEAR then
		right = T.REACHED:format(now)
	else
		right = T.TO_GO:format(now, Mark(One(K.FULL - sum) .. "%", estimate))
	end
	ST.Pair(tip, T.NO_CRUSH, right)
	ST.Note(tip, T.AVOIDED)
	if not s.shield then
		ST.Note(tip, T.NO_SHIELD)
	end
end

-- How many of 100 swings a row stops against an enemy of the player's level and against the boss.
local function Chance(tip, sheet, key)
	ST.Pair(tip, T.ENEMY:format(sheet.level.attacker), T.IN_100:format(Cell(sheet.level, key)))
	if sheet.boss then
		ST.Pair(tip, T.BOSS:format(sheet.boss.attacker), T.IN_100:format(Cell(sheet.boss, key)))
	end
end

-- What defense over the cap adds to dodge, parry and block.
local function OverCap(tip, sheet)
	local over = (Num(sheet.snap.defense) or 0) - (Num(sheet.cap) or 0)
	if over > 0 then
		ST.Pair(tip, T.FROM_DEFENSE:format(sheet.cap), Two(over * K.PER_DEFENSE) .. "%")
	end
end

-- The shield's own block (SpellModel.lua's state, read from the shield's lines), or nil.
local function ShieldBlock()
	local fn = Field(ns.SpellModel, "State")
	if type(fn) ~= "function" then
		return nil
	end
	local ok, state = pcall(fn)
	return ok and Num(Field(state, "shieldBlock")) or nil
end

-- Where the block value comes from, only where the shield, Strength and the rest add up to it.
local function BlockParts(tip, value, s)
	local strength = Num(s.strength) and math.floor(s.strength / K.PER_STRENGTH) or nil
	local shield = ShieldBlock()
	if strength and shield and value - shield - strength >= 0 then
		ST.Pair(tip, T.FROM_SHIELD, Whole(shield))
		ST.Pair(tip, T.FROM_STRENGTH, Whole(strength))
		local rest = value - shield - strength
		if rest >= 0.5 then
			ST.Pair(tip, T.FROM_REST, Whole(rest))
		end
	elseif strength and strength <= value then
		ST.Pair(tip, T.FROM_STRENGTH, Whole(strength))
	end
end

-- The sheet for a stat of the player's list, or nil for the pet's or with no snapshot yet.
local function PlayerSheet(unit)
	if unit == "pet" then
		return nil
	end
	return ST.Sheet()
end

ST.text.DEFENSE = function(tip, unit)
	local sheet = PlayerSheet(unit)
	if not sheet then
		return
	end
	Swings(tip, sheet)
	Aims(tip, sheet)
	Old(tip, sheet)
end

ST.text.DODGE = function(tip, unit)
	local sheet = PlayerSheet(unit)
	if not sheet then
		return
	end
	local s = sheet.snap
	ST.Head(tip, T.DODGE)
	Chance(tip, sheet, "dodged")
	if Num(s.fromAgility) then
		ST.Pair(tip, T.FROM_AGILITY, Two(s.fromAgility * 100) .. "%")
	end
	OverCap(tip, sheet)
	if Num(s.perAgility) and s.perAgility > 0 then
		ST.Pair(tip, T.AGILITY_FOR, Whole(1 / s.perAgility))
	end
	ST.Note(tip, T.POINTER)
	Old(tip, sheet)
end

ST.text.PARRY = function(tip, unit)
	local sheet = PlayerSheet(unit)
	if not sheet then
		return
	end
	ST.Head(tip, T.PARRY)
	Chance(tip, sheet, "parried")
	OverCap(tip, sheet)
	ST.Note(tip, T.POINTER)
	Old(tip, sheet)
end

ST.text.BLOCK = function(tip, unit)
	local sheet = PlayerSheet(unit)
	if not (sheet and sheet.snap.shield) then
		return
	end
	local s = sheet.snap
	ST.Head(tip, T.BLOCK)
	Chance(tip, sheet, "blocked")
	OverCap(tip, sheet)
	local value = Num(s.blockValue)
	if value then
		ST.Pair(tip, T.BLOCK_STOPS, T.DAMAGE:format(Whole(value)))
		BlockParts(tip, value, s)
	end
	ST.Note(tip, T.BLOCK_NOTE)
	ST.Note(tip, T.POINTER)
	Old(tip, sheet)
end

ST.text.ARMOR = function(tip, unit)
	local sheet = PlayerSheet(unit)
	local L = sheet and sheet.level
	if not (L and Num(L.armor) and Num(sheet.snap.armor)) then
		return
	end
	local B = sheet.boss
	ST.Head(tip, T.ARMOR)
	ST.Pair(tip, T.ENEMY:format(L.attacker), T.ARMOR_CUT:format(One(L.armor)))
	if B and Num(B.armor) then
		ST.Pair(tip, T.BOSS:format(B.attacker), T.ARMOR_CUT:format(One(B.armor)))
	end
	local against = B and Num(B.armor) and B or L
	local fn = Field(Gear(), "ArmorPct")
	local ok, more = false, nil
	if type(fn) == "function" then
		ok, more = pcall(fn, sheet.snap.armor + K.MORE_ARMOR, against.attacker)
	end
	if ok and Num(more) then
		ST.Pair(tip, T.MORE_ARMOR:format(K.MORE_ARMOR), T.MORE_CUT:format(Two(more - against.armor), against.attacker))
	end
	ST.Note(tip, T.ARMOR_NOTE)
	Old(tip, sheet)
end

-- The last plain resistance of each school, by Enum.Damageclass.
local resisted = {}

-- The player's effective resistance of a school (UnitResistance's third answer) and whether it is the last plain one, from before a fight.
local function Resistance(class)
	local fn = _G.UnitResistance
	if type(fn) ~= "function" then
		return nil
	end
	local ok, _, _, effective = pcall(fn, "player", class)
	if ok and Finite(effective) then
		resisted[class] = effective
		return effective, false
	end
	if resisted[class] then
		return resisted[class], true
	end
	return nil
end

-- The average share of a school's damage a resistance resists against a caster of a level, in percent: the client's ExpectedSpellResistance.
local function Share(level, resistance)
	local fn = _G.ExpectedSpellResistance
	if type(fn) ~= "function" then
		return nil
	end
	local ok, share = pcall(fn, level, resistance)
	if ok and Finite(share) then
		return share * 100
	end
	return nil
end

-- The lines of a resistance of a school.
local function Resist(class)
	local word = K.WORDS[class]
	return function(tip, unit)
		local level = unit ~= "pet" and PlayerLevel() or nil
		local value, old = Resistance(class)
		local now = level and value and value >= 0 and Share(level, value)
		if not now then
			return
		end
		local attacker, boss = nil, false
		local fn = Field(Gear(), "Against")
		if type(fn) == "function" then
			local ok, at, isBoss = pcall(fn, level)
			if ok and Num(at) and isBoss == true then
				attacker, boss = at, true
			end
		end
		ST.Head(tip, T.RESIST:format(word))
		ST.Pair(tip, T.ENEMY:format(level), T.RESISTED:format(math.floor(now), word))
		local against = level
		if boss then
			local share = Share(attacker, value)
			if share then
				ST.Pair(tip, T.BOSS:format(attacker), T.RESISTED:format(math.floor(share), word))
				against = attacker
			end
		end
		local base, more = Share(against, value), Share(against, value + K.MORE_RESIST)
		if base and more then
			ST.Pair(tip, T.MORE_RESIST:format(K.MORE_RESIST), T.MORE_RESISTED:format(One(more - base), against))
		end
		ST.Note(tip, T.RESIST_NOTE:format(word))
		if old then
			ST.Old(tip)
		end
	end
end

for class, token in ipairs(K.TOKENS) do
	ST.text[token] = Resist(class)
end

-- The stand-in tooltip -----------------------------------------------------------------------------------------------------------------------------

local function Nothing()
end

local function Lines(tip)
	local ok, count = pcall(tip.NumLines, tip)
	return ok and Finite(count) and count or 0
end

-- The stand-in (header): its methods, and nothing for any other.
local Buffer = setmetatable({}, { __index = function()
	return Nothing
end })
Buffer.__index = Buffer

local function Keep(buffer, method, ...)
	buffer.calls[#buffer.calls + 1] = { method, select("#", ...), ... }
end

function Buffer.AddLine(buffer, ...)
	Keep(buffer, "AddLine", ...)
end

function Buffer.AddDoubleLine(buffer, ...)
	Keep(buffer, "AddDoubleLine", ...)
end

function Buffer.NumLines(buffer)
	return Lines(buffer.tip) + #buffer.calls
end

local function After(ok, ...)
	if ok then
		return ...
	end
	return nil
end

for _, name in ipairs(K.READS) do
	Buffer[name] = function(buffer, ...)
		local tip = buffer.tip
		local fn = Field(tip, name)
		if type(fn) ~= "function" then
			return nil
		end
		return After(pcall(fn, tip, ...))
	end
end

-- The lines kept, written to the tooltip in order, and the tooltip shown again so it takes their size.
local function Flush(tip, buffer)
	for _, call in ipairs(buffer.calls) do
		local fn = Field(tip, call[1])
		if type(fn) == "function" then
			pcall(fn, tip, unpack(call, 3, call[2] + 2))
		end
	end
	pcall(tip.Show, tip)
end

-- The hook -------------------------------------------------------------------------------------------------------------------------------------

-- seen: each row's token and unit, by its frame; hooked: the rows whose OnEnter and OnLeave are followed; last: the row whose lines the tooltip
-- has now, and its count of lines after them; failed and order: the first error of each stat's lines, for /flatui status; followers: the
-- function that follows each stat's updateFunc; installed: the hooks are in; taint: they wait for a session without taintLog.
local hook = { seen = setmetatable({}, { __mode = "k" }), hooked = setmetatable({}, { __mode = "k" }), last = {}, failed = {}, order = {},
	followers = {}, installed = false, taint = false }

local function Wanted()
	return ns.Enabled(KEY) and ns.Get(ROW) == true and not ns.PartStopped(KEY, PART)
end

local function Tooltip()
	local tip = _G.GameTooltip
	if tip == nil or ns.Forbidden(tip) then
		return nil
	end
	return tip
end

-- True while the tooltip shows and the row owns it, so the game wrote its lines for this row.
local function Owns(tip, frame)
	local ok, owned = pcall(tip.IsOwned, tip, frame)
	if not ok or IsSecret(owned) or owned ~= true then
		return false
	end
	local okShown, shown = pcall(tip.IsShown, tip)
	return okShown and not IsSecret(shown) and shown == true
end

local function Failed(token, err)
	if hook.failed[token] == nil then
		hook.failed[token] = tostring(err)
		hook.order[#hook.order + 1] = token
	end
end

-- After the game wrote a row's tooltip: that stat's lines after the game's (header), once a build.
local function Decorate(frame)
	local seen = hook.seen[frame]
	local tip = seen and Wanted() and Tooltip()
	if not (tip and Owns(tip, frame)) then
		return
	end
	local fill = ST.text[seen.token]
	if type(fill) ~= "function" then
		return
	end
	local count, last = Lines(tip), hook.last
	if last.frame == frame and last.count == count then
		return
	end
	local buffer = setmetatable({ tip = tip, calls = {} }, Buffer)
	local ok, err = pcall(fill, buffer, seen.unit)
	if not ok then
		Failed(seen.token, err)
	elseif #buffer.calls > 0 then
		Flush(tip, buffer)
	end
	last.frame, last.count = frame, Lines(tip)
end

local function Entered(frame)
	ns.EachPart(KEY, PART, Decorate, frame)
end

-- The mouse left the row: its next tooltip is a new build.
local function Left(frame)
	if hook.last.frame == frame then
		hook.last.frame, hook.last.count = nil, nil
	end
end

-- One post-hook of a row's OnEnter and OnLeave, never on a frame the game protects in a fight (a later Init tries again).
local function Hook(frame)
	if hook.hooked[frame] or ns.Forbidden(frame) then
		return
	end
	local fn = Field(frame, "HookScript")
	if type(fn) ~= "function" then
		return
	end
	if InCombatLockdown() then
		local ok, protected = pcall(frame.IsProtected, frame)
		if not ok or IsSecret(protected) or protected ~= false then
			return
		end
	end
	if pcall(fn, frame, "OnEnter", Entered) then
		hook.hooked[frame] = true
		pcall(fn, frame, "OnLeave", Left)
	end
end

-- A row shows a stat for a unit.
local function Seen(frame, token, unit)
	if frame == nil or IsSecret(frame) or type(frame) ~= "table" or not Text(token) then
		return
	end
	unit = Text(unit) == "pet" and "pet" or "player"
	local seen = hook.seen[frame]
	if seen then
		seen.token, seen.unit = token, unit
	else
		hook.seen[frame] = { token = token, unit = unit }
	end
	Hook(frame)
end

-- "pet" for a row under the pet's stats list, else "player".
local function PaneUnit(frame)
	local pet, at = _G.CharacterStatsPanePetScrollBox, frame
	for _ = 1, K.DEPTH do
		local ok, parent = pcall(at.GetParent, at)
		if not ok or parent == nil or IsSecret(parent) or type(parent) ~= "table" then
			return "player"
		elseif rawequal(parent, pet) then
			return "pet"
		end
		at = parent
	end
	return "player"
end

-- The sheet's token of a resistance row, by the school its atlas ends with, else by its label (DAMAGE_SCHOOL2 to 7).
local function ResistToken(data)
	local atlas = Text(Field(data, "atlas"))
	local class = atlas and K.SCHOOLS[atlas:match("Resistance%-(%a+)$") or ""]
	if not class then
		local label = Text(Field(data, "labelText"))
		for index = 1, #K.TOKENS do
			if label and label == Text(_G["DAMAGE_SCHOOL" .. (index + 1)]) then
				class = index
				break
			end
		end
	end
	return class and K.TOKENS[class] or nil
end

-- After a row's Init: its stat by elementData.name and unit, or for a resistance row by its atlas or label.
local function Initialised(frame, data)
	if data == nil or IsSecret(data) or type(data) ~= "table" then
		return
	end
	local name = Text(Field(data, "name"))
	if name then
		Seen(frame, name, Field(data, "unit"))
		return
	end
	local token = ResistToken(data)
	if token then
		Seen(frame, token, PaneUnit(frame))
	end
end

local function OnInit(frame, data)
	ns.EachPart(KEY, PART, Initialised, frame, data)
end

local function OnSpeed(frame)
	ns.EachPart(KEY, PART, Decorate, frame)
end

-- The function that follows a stat's updateFunc, one a stat.
local function Follower(token)
	local fn = hook.followers[token]
	if not fn then
		fn = function(frame, unit)
			ns.EachPart(KEY, PART, Seen, frame, token, unit)
		end
		hook.followers[token] = fn
	end
	return fn
end

-- The hooks (header); true once they are in.
local function Install()
	if hook.installed then
		return true
	end
	local any = ns.FollowTable(Field(_G, "CharacterStatFrameScrollBoxBaseElementMixin"), "Init", OnInit) == true
	local info = Field(_G, "PAPERDOLL_STATINFO")
	for _, category in ipairs(Field(_G, "PAPERDOLL_STATCATEGORIES") or {}) do
		for _, stat in ipairs(Field(category, "stats") or {}) do
			local token = Text(Field(stat, "stat"))
			local entry = token and Field(info, token)
			if entry and ns.FollowTable(entry, "updateFunc", Follower(token)) == true then
				any = true
			end
		end
	end
	ns.FollowGlobal("MovementSpeed_OnEnter", OnSpeed)
	hook.installed, hook.taint = any, not any and ns.TaintLogging()
	return any
end

-- The row changed (Config.lua, changed): the hooks go in if they are not in yet.
function ns.StatTipsChanged()
	ns.EachPart(KEY, PART, Install)
end

-- /flatui status: why the lines wait, and the first error of each stat's lines.
local function Status()
	if not Wanted() then
		return {}
	end
	local lines = {}
	if not hook.installed and hook.taint then
		lines[1] = T.TAINT
	end
	for _, token in ipairs(hook.order) do
		lines[#lines + 1] = T.FAILED:format(token, hook.failed[token])
	end
	return lines
end

if type(ns.AddStatus) == "function" then
	ns.AddStatus(KEY, Status)
end

if type(ns.AddStart) == "function" then
	ns.AddStart(KEY, function()
		ns.EachPart(KEY, PART, Install)
	end)
end
