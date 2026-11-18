local _, ns = ...

-- Hit table lines (part "hit table lines" of Chat and tooltips; 0.5.20): under the tooltip of an enemy the player can attack, the player's hit
-- table against it, a line for each attack the hit table under the player frame shows (HitTable.lua), as "Your swing  Miss 8.0 · Dodge 6.5 · Glance
-- 40.0 · Crit 12.1 · Hit 33.4". Its row is On enemy tooltips (hud.hitTableTip, on the Hit table tab of Minimap and buffs): For tanks and damage
-- dealers (the default) adds the lines while the player's role (ns.PlayerRole, Core.lua) is no healer, Always whatever the role, Off never. The
-- lines follow that row alone, not Hit table under the player frame, so a player may hide the table and keep the lines; and they come only while
-- the chat module is on, since its post call adds them. They count what the Hit table tab says: Attacks (hud.hitTableLines, the kinds of
-- C.Kinds by the class and form the inputs were read with), Special attacks (hud.hitTableSpecial) and Hit cap against a boss (hud.hitTableRules);
-- parry and block only from the front: by Where you stand (hud.hitTableFacing), at its first choice while the enemy attacks the player (C.Front)
-- and always for a tank, who stands in front. The enemy counts at its level (C.Target: UnitEffectiveLevel, else UnitLevel); a level the game shows
-- as ?? and a boss (ns.UnitKind) at three levels above the player at least, as the hit table counts a boss (HitTableCalc.lua, ABOVE). It registers
-- no event, makes no frame, hooks nothing and has no switch of its own, as SpellLines.lua; HitTableCalc.lua and SpellModel.lua are looked up when
-- asked, never as the files load.
--
-- The tests, cheapest first: the row and the chat module; the tooltip GameTooltip (rawequal), one addons may touch (ns.Forbidden) and not one
-- inside another tooltip (its field IsEmbedded, read only); the data of a unit (Enum.TooltipDataType.Unit 2, TooltipInfoSharedDocumentation.lua:
-- 98); the same build not already given its lines (as SpellLines.lua tells a build: the same data with at least the lines added then still
-- there); the unit token from the tooltip, GetUnit under pcall (its second answer, Blizzard_GameTooltip/Mainline/GameTooltip.lua:1035-1037,
-- which reads the data's guid with UnitTokenFromGUID, Blizzard_SharedXMLGame/Tooltip/TooltipUtil.lua:34-42), else UnitTokenFromGUID of the
-- data's guid, else "mouseover" while its UnitGUID is that guid; a unit the player can attack (UnitCanAttack) that is not dead
-- (UnitIsDeadOrGhost); and a level the game gives plain (UnitLevel). A guid, a token or a level the game withholds (SecretWhenUnitIdentityRestricted,
-- UnitDocumentation.lua:3296-3310) says nothing; so does every value that is not plain (ns.IsSecret, ns.Finite).
--
-- The stats. Every stat call is SecretWhenUnitStatsRestricted: the game withholds them in fights. So the inputs of the table (C.Inputs, every kind
-- read, against the unit shown) are read only out of combat (InCombatLockdown, UnitAffectingCombat) while the game gives the stats plain
-- (C_Secrets.ShouldUnitStatsBeSecret, SecretPredicateAPIDocumentation.lua:388-396), as the gear comparison reads them (GearModel.lua, StatsPlain),
-- and an answer the game withheld any of (a gap "withheld") is not kept. The last plain answer is kept, so in a fight the table is worked out from
-- it with the unit's own level and facing (C.Target, C.Front and C.Table, which read no stat), and one dim line says the stats are from before the
-- fight, as SpellLines.lua says it. With none kept, nothing is said.
--
-- The cache: a build of a unit's tooltip comes often (TOOLTIP_DATA_UPDATE, GameTooltip.lua:970-973), so a read of the inputs and a look at the
-- role serve every build for AGAIN seconds, whatever unit is shown, until a fight ends, and each read kept counts a version; the enemy (C.Target)
-- is kept by the unit's guid and that version, and the lines by those, the facing, whether the stats are from before the fight and the rows they
-- follow. A build of the same enemy then costs the tests, the facing (C.Front) and the adding, and C.Table only when one of those changed.
--
-- The look (0.5.20, the style of every tooltip line, SpellModel.lua's M.Fmt.Style): a gold header "Hit table" only when more than one line
-- follows; each line its label light grey on the left and its parts white on the right (AddDoubleLine), or light grey while they are from before
-- the fight; a part that does not apply left out, one the game did not give ?; and the notes dim, wrapped at the tooltip's width (AddLine's fifth
-- argument): the stats from before the fight, and an estimate (a level of ?? or a boss counted three above the player, a player's dodge, parry and
-- block counted from 5%, a weapon skill the game did not give counted as the most for the level). In Compact (chat.tipDetail) the notes are joined
-- into one dim line, in Full each is its own.
--
-- The work runs inside ns.EachPart keyed by the data of the build, new for each build, so three builds that fail stop this part alone with a line
-- for /flatui status, and the first error goes once to the game's error handler (geterrorhandler), as SpellLines.lua sends its own. The only
-- writes are widget calls on GameTooltip, each under pcall: NumLines, AddDoubleLine and AddLine; one the game refuses ends the adding for that
-- build. Chat.lua calls ns.HitTableTipLines from its post call of the game's tooltip data (TooltipDataProcessor.AddTooltipPostCall), after the
-- spell and gear lines and before its own ID line.

local KEY, PART = "chat", "hit table lines"
local IsSecret, Finite = ns.IsSecret, ns.Finite

-- The constants of this file, in one table so that the main chunk keeps few locals.
local HT = {
	-- The row of this file and the rows of the Hit table tab the lines follow (Config.lua), and Notes under the lines of Chat and tooltips.
	ROW = "hud.hitTableTip", LINES = "hud.hitTableLines", SPECIAL = "hud.hitTableSpecial", FACING = "hud.hitTableFacing", RULES = "hud.hitTableRules",
	DETAIL = "chat.tipDetail",
	-- Enum.TooltipDataType.Unit, for a client whose Enum does not say (TooltipInfoSharedDocumentation.lua:98).
	UNIT = 2,
	-- The kinds C.Inputs reads: every one, so a change of Attacks or of form later finds the kind it needs among the inputs kept.
	KINDS = { melee = true, ranged = true, spell = true },
	-- Seconds a read of the inputs and a look at the role serve the builds that follow.
	AGAIN = 2,
	-- The levels a boss and a ?? count above the player, as the hit table counts them (HitTableCalc.lua, ABOVE).
	ABOVE = 3,
	-- The parts of a line in the order of the roll, and their words; the crit cap is the hit table's alone.
	PARTS = { { "miss", "Miss" }, { "dodge", "Dodge" }, { "parry", "Parry" }, { "glance", "Glance" }, { "block", "Block" }, { "crit", "Crit" },
		{ "hit", "Hit" } },
	-- Between two parts: a middle dot, as the Overall line of the gear lines has (GearLines.lua, T.SEPARATOR).
	SEPARATOR = " \194\183 ",
	-- The label of each line of C.Table, by its id.
	LABELS = { swing = "Your swing", main = "Your main hand", off = "Your off hand", special = "Your special attacks",
		ranged = "Your ranged attacks", spell = "Your spells" },
	HEADER = "Hit table",
	-- The colours of the style while SpellModel.lua's (M.Fmt.Style) cannot be read, as SpellLines.lua keeps them.
	STYLE = { header = { 1, 0.82, 0 }, label = { 0.82, 0.82, 0.82 }, value = { 1, 1, 1 }, dim = { 0.66, 0.68, 0.62 } },
	-- The notes, and what joins them into one line in Compact.
	OLD = "Your stats from before this fight",
	UNKNOWN = "Level ?? counted as %d",
	BOSS = "A boss counted as level %d",
	PLAYER = "A player's dodge, parry and block counted from 5%",
	ASSUMED = "Weapon skill counted as the most for your level",
	JOIN = "; ",
}

-- Per tooltip: { data, lines } of the build that has the lines: its data and the tooltip's lines after them.
local added = setmetatable({}, { __mode = "k" })
-- held: inputs (the last plain answer of C.Inputs), version (counts the answers kept), at (GetTime of the last look: a read tried and the role),
-- fought (that look was in a fight), role (the player's role at that look: "tank", "healer" or "damage") and stale (the last read tried was
-- withheld).
local held = { version = 0, role = "damage", stale = false, fought = false }
-- made: targetKey and target (C.Target's answer for a guid and a version), key and lines (the lines as they are added, and what they were made for).
local made = {}
-- reported: the first error of the part went to the game's handler.
local run = { reported = false }

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

-- The unit of the tooltip and its guid: the token of GetUnit (under pcall), else UnitTokenFromGUID of the data's guid, else "mouseover" while it is
-- that unit. Nil when the game gives no plain guid or token.
local function UnitOf(tooltip, data)
	local guid, unit = Text(Field(data, "guid")), nil
	local get = Field(tooltip, "GetUnit")
	if type(get) == "function" then
		local ok, _, token, found = pcall(get, tooltip)
		if ok then
			unit, guid = Text(token), guid or Text(found)
		end
	end
	if not guid then
		return nil
	end
	unit = unit or Text(Ask(UnitTokenFromGUID, guid))
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

-- A look, at most once in AGAIN seconds and at once as a fight ends: the role, and, out of a fight while the lines are wanted, the inputs read again
-- against the unit shown; a plain answer is kept and counted. Answers whether the inputs held are from before the fight.
local function Look(C, unit)
	local fighting = Fighting()
	local now = Ask(GetTime)
	now = Finite(now) and now or 0
	if held.at == nil or now - held.at >= HT.AGAIN or now < held.at or (held.fought and not fighting) then
		held.at, held.fought, held.role = now, fighting, Role()
		if not fighting and not (Choice() == "role" and held.role == "healer") then
			local inputs = C.Inputs({ kinds = HT.KINDS, unit = unit, facing = ns.Get(HT.FACING) })
			held.stale = not Plain(inputs)
			if not held.stale then
				held.inputs, held.version = inputs, held.version + 1
			end
		end
	end
	return fighting or held.stale
end

-- The table -------------------------------------------------------------------------------------------------------------------------------------

-- The enemy at its level (C.Target against the unit), a boss three levels above the player at least; kept by the guid and the version of the
-- inputs. Nil when C.Target does not count it an enemy or gives no level.
local function Against(C, inputs, unit, guid)
	local key = guid .. "|" .. held.version
	if made.targetKey ~= key then
		local target = C.Target(nil, inputs.level, unit)
		if type(target) ~= "table" or not target.enemy or not Finite(target.level) then
			target = nil
		elseif target.kind == "boss" and target.level < inputs.level + HT.ABOVE then
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
local function Parts(line)
	local parts, known = {}, false
	for _, part in ipairs(HT.PARTS) do
		local value = line.parts[part[1]]
		if value ~= false then
			known = known or Finite(value)
			parts[#parts + 1] = part[2] .. " " .. (Finite(value) and ("%.1f"):format(value) or "?")
		end
	end
	return known and table.concat(parts, HT.SEPARATOR) or nil
end

-- The notes of a table: the stats from before the fight, then each estimate.
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
		lines[1] = { left = HT.HEADER, colour = style.header, wrap = false }
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
-- version, the facing, the age of the stats and the rows are the same.
local function LinesFor(C, unit, guid, old)
	local inputs = held.inputs
	local target = Against(C, inputs, unit, guid)
	if not target then
		return nil
	end
	local front = Front(C, target)
	local key = table.concat({ guid, held.version, tostring(front), tostring(old), tostring(ns.Get(HT.LINES)), tostring(ns.Get(HT.SPECIAL)),
		tostring(ns.Get(HT.RULES)), tostring(ns.Get(HT.DETAIL)) }, "|")
	if made.key == key then
		return made.lines
	end
	-- A copy of the inputs with the enemy, the facing and the kinds Attacks asks for by the class and form they were read with.
	local copy = {}
	for field, value in pairs(inputs) do
		copy[field] = value
	end
	copy.target, copy.front, copy.facingUnsure = target, front, false
	local kinds = C.Kinds(ns.Get(HT.LINES), inputs.class, inputs.power)
	if type(kinds) == "table" then
		copy.melee = kinds.melee and inputs.melee or nil
		copy.ranged = kinds.ranged and inputs.ranged or nil
		copy.spell = kinds.spell and inputs.spell or nil
	end
	local read = C.Table({ special = ns.Get(HT.SPECIAL) ~= false, rules = ns.Get(HT.RULES) }, copy)
	made.key, made.lines = key, type(read) == "table" and Shape(read, target, old) or {}
	return made.lines
end

-- Adding -----------------------------------------------------------------------------------------------------------------------------------------

-- Adds one line to the tooltip: a label and its parts side by side, or a line alone, wrapped when it asks. True when the game took it.
local function Put(tooltip, line)
	local left, right = line.colour, line.rightColour
	if line.right then
		return (pcall(tooltip.AddDoubleLine, tooltip, line.left, line.right, left[1], left[2], left[3], right[1], right[2], right[3]))
	end
	return (pcall(tooltip.AddLine, tooltip, line.left, left[1], left[2], left[3], line.wrap == true))
end

-- The tests and the lines of one build (header), once for each build: the same data with at least the lines added then still there is the same
-- build, so a second post call of it adds none, and a refused line ends the adding for that build.
local function Work(data, tooltip)
	if not rawequal(tooltip, GameTooltip) or ns.Forbidden(tooltip) then
		return
	end
	local readable, embedded = pcall(Index, tooltip, "IsEmbedded")
	if not readable or IsSecret(embedded) or embedded == true or Field(data, "type") ~= UnitType() then
		return
	end
	local C = ns.HitTableCalc
	if type(C) ~= "table" or type(C.Inputs) ~= "function" or type(C.Table) ~= "function" or type(C.Target) ~= "function"
		or type(C.Front) ~= "function" or type(C.Kinds) ~= "function" then
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
	local unit, guid = UnitOf(tooltip, data)
	if not unit or not Enemy(unit) then
		return
	end
	local old = Look(C, unit)
	if (Choice() == "role" and held.role == "healer") or not held.inputs then
		return
	end
	local lines = LinesFor(C, unit, guid, old)
	if not lines or #lines == 0 then
		return
	end
	for _, line in ipairs(lines) do
		if not Put(tooltip, line) then
			break
		end
		shown = shown + 1
	end
	added[tooltip] = { data = data, lines = shown }
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
