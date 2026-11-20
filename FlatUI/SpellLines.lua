local _, ns = ...

-- Spell lines (part "spell lines" of Chat and tooltips, on its Spell tooltips page; design 1 and 4): inside the game's build of a spell tooltip,
-- lines with the share of spell damage, spell healing or attack power the spell adds and what that is with the player's stats (Spell power and
-- attack power lines, With your stats, Less for low ranks), the total of one cast with the player's stats, base and bonus together (Total,
-- chat.spellTotal; 0.5.20) and its rates (chat.spellRates: the expected value with crits, misses and a spell's piercing, a second of cast time, a
-- point of mana), its threat on WoW: Forever with each multiplier in force (Threat lines), the lines a stance, form, aura or talent tooltip needs
-- that its own text leaves out, and, while a number shown is from before the fight now on, one dim line that says so, last. SpellModel.lua makes
-- the texts (M.PowerLines, M.TotalLines, M.ThreatLines, M.RuleLines, each a block with its title) from the data of SpellData.lua and the player's
-- state and stats, and listens to the game while a part wants it (M.Want); this file finds the spell, keeps its lines and adds them. It registers
-- no event, adds to the chat module and has no switch of its own, as ChatTips.lua. SpellModel.lua, SpellData.lua and ns.ActionSpell of
-- Cooldowns.lua are looked up when asked, never as the files load, since each may load after this one or fail.
-- What it touches of the game, in the order it does: the frames GameTooltip and ItemRefTooltip, IsForbidden (through ns.Forbidden), the
-- tooltip's field IsEmbedded, Enum.TooltipDataType and the data's type, IsShiftKeyDown, IsControlKeyDown and IsAltKeyDown, the data's id and
-- lines, the tooltip's field processingInfo, GetActionInfo and GetMacroSpell (through ns.ActionSpell), the tooltip's NumLines, UnitLevel, the
-- tooltip's AddDoubleLine and AddLine, geterrorhandler, and for /flatui status C_Secrets.ShouldUnitStatsBeSecret and GetTime. No event.
-- Chat.lua calls ns.SpellTipLines from its post call of the game's tooltip data (TooltipDataProcessor.AddTooltipPostCall, AllTypes) right after
-- ChatTips.lua's lines and before its own ID and count lines, so Spell ID stays the last line, and ns.SpellLinesSync at the end of each refresh.
-- The game runs the post calls after its own lines and before it shows the tooltip (Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua:
-- 292-300), so the tooltip takes the size of the new lines. The spell book adds two lines after its own build (Blizzard_PlayerSpells/SpellBook/
-- Blizzard_SpellBookItem.lua:489-499), which so come after these.
--
-- The tests, cheapest first (design 4.4). The tooltip: GameTooltip or ItemRefTooltip (Blizzard_GameTooltip/Mainline/GameTooltip.xml:249;
-- Blizzard_UIPanels_Game/Mainline/ItemRef.xml:5), each compared with rawequal as BagsTooltip.lua compares them, one addons may touch
-- (ns.Forbidden, which asks IsForbidden) and not one inside another tooltip (its field IsEmbedded, GameTooltip.xml:88-91, read only). The data: a
-- spell, a pet action or a macro (Enum.TooltipDataType Spell 1, PetAction 11 and Macro 25, Blizzard_APIDocumentationGenerated/
-- TooltipInfoSharedDocumentation.lua:97, 107, 121), never a buff or a debuff (UnitAura 7). The key: Show spell lines at Always, or its key held
-- (IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown); ItemRefTooltip at every choice, since the game builds it only for a plain click on a link, a
-- modified one going to HandleModifiedItemClick (SetItemRef, Blizzard_UIPanels_Game/Mainline/ItemRef.lua:17-26), and builds it again only when its
-- data changes (its OnUpdate, :351-355), never as a key goes down, so lines that waited for a key would never come there. A bar button's tooltip is
-- built again five times a second (GameTooltip.lua:451-463; Blizzard_ActionBar/Shared/ActionButton.lua:1125-1129), so there the lines come as the
-- key goes down, and elsewhere at the next build, as Show IDs works (ChatTips.lua:28-31). The spell: one of the data for the player's class, its pet
-- or every class (M.Find), or, while Threat lines is on, any other spell, which may be the tooltip of a rule (M.RuleLines answers nothing for the
-- rest).
-- The spell ID (design 1.1). A spell's data has it in its id (Blizzard_SharedXMLGame/Tooltip/TooltipUtil.lua:25-32): the rank on the button, in
-- the book or in the link. A macro's and a pet action's data name it in their first line, by tooltipID while tooltipType is 1 (0 is an item), the
-- fields retail addons read for it, not yet seen on WoW: Forever (design 6.4). A macro whose first line names none is read from its action slot:
-- the game builds an action's tooltip through GetAction with the slot (TooltipDataHandler.lua:499-502, 586) and keeps the getterName and the
-- getterArgs of the build, packed in order (SafePack, Blizzard_SharedXMLBase/TableUtil.lua:414-418), in processingInfo on the tooltip while it
-- builds (TooltipDataHandler.lua:281), a field read only; ns.ActionSpell (Cooldowns.lua) reads the slot as Add the spells of a bar reads one
-- (GetActionInfo, and GetMacroSpell for a macro). A pet action whose first line names no spell gets nothing. A talent's tooltip appends a build
-- through GetTraitEntry with the entry and the rank, one for the rank the player has and one for the next (Blizzard_SharedTalentUI/
-- Blizzard_TalentDisplay.lua:365, 371; TooltipDataHandler.lua:434-438): each has data of its own and gets its own lines, for the rank in its
-- getterArgs, but the next rank's block leaves out a dim line the block before it of the same entry added to that tooltip (a rule's note, which no
-- rank changes), so it shows once. The talent's title is plain text and gets nothing.
--
-- The work, keyed (design 4.4): ns.EachPart counts a failure once for each first argument it is given (Core.lua:2193-2224) and stops a part at
-- the third (MAX_PART_FAILURES, Core.lua:260). The tests run keyed by the data of the build, which is new for each build, the lines keyed by the
-- spell ID, and a sync by its number, so a test that fails on three builds, three spells that fail or three syncs that fail stop this part alone,
-- with a line for /flatui status; the first error also goes once to the game's error handler (geterrorhandler), as Bags' parts send theirs
-- (Bags.lua:356-372). A part that stops wants nothing more of SpellModel.
-- The cache: the lines of a spell are kept until SpellModel's version changes (M.Version, which changes only when a value it read differs or a
-- row of the tab changes), a row this file reads changes, the stats turn old, or SpellModel's check of the game's texts answers; at most MOST
-- spells, the oldest forgotten first. Each build asks SpellModel for the state and the stats first (M.State, M.Stats), which read the game only
-- after an event marked them, so what changed shows at the next build. A pet's entry is kept for the pet's level (UnitLevel of "pet",
-- Blizzard_APIDocumentationGenerated/UnitDocumentation.lua:2474-2487), which its threat may gain by.
-- Once for each build (Chat.lua:795-806): the game makes new data for each build and may run the post calls more than once for one, so the same
-- data with at least the lines added then still there is the same build. The only writes are widget calls on the tooltip, each under pcall:
-- NumLines, AddDoubleLine for a share and its number, AddLine for a line alone; one the game refuses ends the adding for that build.
-- The look (0.5.20: one style for every line, SpellModel.lua's M.Fmt.Style): each block SpellModel gives (the power lines, the total, the threat
-- block, a rule's lines) opens with its title as one gold header (the game's NORMAL_FONT_COLOR) only where more than one line that is no note
-- follows; a figure's label light grey (0.82) and its value white, or light grey while it is from before the fight; and the notes dim (0.66,
-- 0.68, 0.62, HitTable.lua's DIM), wrapped at the tooltip's width by AddLine's fifth argument (Blizzard_SharedXML/SharedTooltipTemplates.lua:
-- 166-172), so a long note does not widen the tooltip: in Compact (chat.tipDetail) a block's notes are joined into one dim line at its end with
-- "; " between them, in Full each shows where it comes.
-- /flatui status (design 4.12), while the module is on and a row wants lines: the build of the data and its number of spells (D.SPELLS, which the
-- generator counts, so no other class's constructor runs), that the game withholds the stats in this fight (C_Secrets.ShouldUnitStatsBeSecret,
-- Blizzard_APIDocumentationGenerated/SecretPredicateAPIDocumentation.lua:388-396) or when they were read (GetTime), what SpellModel's check of the
-- game's texts found, the low rank rule while its row is on, and, once SpellModel had to look through the talent tree (S.state.treeWalked, design
-- 6.25), that it did.

local KEY, PART = "chat", "spell lines"
local IsSecret = ns.IsSecret

-- The constants of this file, in one table so that the main chunk keeps few locals (as Cooldowns.lua keeps CD).
local SL = {
	-- The rows of the Spell tooltips page this file reads (Config.lua, saved as chat.<key>), and their defaults of design 4.9 for a profile that has
	-- none of them yet.
	PATH = { spellPower = "chat.spellPower", spellStats = "chat.spellStats", spellLowRank = "chat.spellLowRank", spellThreat = "chat.spellThreat",
		spellWhen = "chat.spellWhen", spellTotal = "chat.spellTotal", spellRates = "chat.spellRates", tipDetail = "chat.tipDetail" },
	DEFAULT = { spellPower = true, spellStats = true, spellLowRank = true, spellThreat = "special", spellWhen = "always", spellTotal = true,
		spellRates = true, tipDetail = "compact" },
	-- The kinds of tooltip data a spell line goes on, for a client whose Enum.TooltipDataType does not say (TooltipInfoSharedDocumentation.lua:97,
	-- 107, 121).
	TYPES = { Spell = 1, PetAction = 11, Macro = 25 },
	-- The tooltipType of a first line that names a spell; 0 names an item.
	SPELL_LINE = 1,
	-- The getters of a build of an action slot and of a talent's block (TooltipDataHandler.lua:586, 598).
	ACTION = "GetAction",
	TRAIT = "GetTraitEntry",
	-- The colours of the style while SpellModel.lua's (M.Fmt.Style) cannot be read: a block's gold header (the game's NORMAL_FONT_COLOR), a
	-- figure's light grey label and white value, and a dim note.
	STYLE = { header = { 1, 0.82, 0 }, label = { 0.82, 0.82, 0.82 }, value = { 1, 1, 1 }, dim = { 0.66, 0.68, 0.62 } },
	-- The notes of a block in Compact are joined into one dim line with this between them (chat.tipDetail).
	JOIN = "; ",
	-- The dim line that ends the spell lines while a number shown is from before the fight now on.
	OLD = "Your stats from before this fight.",
	-- Spells whose lines are kept at most (design 4.6).
	MOST = 64,
	-- The key of the lines of a build that names no talent rank.
	NO_RANK = -1,
	-- What SpellModel is asked to read again when this part starts to want its events, which it may not have heard while no part wanted them.
	MARKS = { "state", "stats", "talents", "gear", "spells", "role" },
	-- The roles of ns.PlayerRole (Core.lua).
	ROLES = { tank = true, healer = true, damage = true },
	-- The low rank rule for its status line while the data does not say (design 6.2: in full for 17 levels after the rank, then 5% less a level).
	GRACE = 17,
	STEP = 0.05,
}

-- Per tooltip: { data, lines, trait, rank, notes } of the build that has the spell lines: its data, the tooltip's lines after them, the entry and
-- rank of a talent's block, and the dim lines it added, by their text.
local added = setmetatable({}, { __mode = "k" })
-- The lines by spell ID, then by talent rank (NO_RANK for none): { pet = the pet's level they were made for, lines = the lines as Put adds them };
-- order holds the spell IDs, the one kept longest first.
local cache, order = {}, {}
-- What the lines of the cache were made for (Fresh): SpellModel's version, whether the stats were old, the text check's answer, and the rows.
local made = {}
-- What Find found, for Work: ns.EachPart gives back no answer of the function it runs.
local pick = {}
-- wanting: what SpellModel was told last (M.Want); reported: the first error of the part went to the game's handler; syncs: the number of the
-- last sync; kinds: the values of Enum.TooltipDataType, once.
local run = { wanting = false, reported = false, syncs = 0 }

-- Rows -----------------------------------------------------------------------------------------------------------------------------------------

-- A row of the tab, or its default while the profile has none.
local function Opt(key)
	local value = ns.Get(SL.PATH[key])
	if value == nil then
		return SL.DEFAULT[key]
	end
	return value
end

-- Threat lines: "special" (Where threat is special or changed), "all" (On every spell) or "off".
local function Mode()
	local mode = Opt("spellThreat")
	if mode == "all" or mode == "off" then
		return mode
	end
	return "special"
end

-- True while the module is on and a row wants lines: the power lines, the total or its rates, or the threat lines with the lines of stances,
-- forms, auras and talents.
local function Wanted()
	return ns.Enabled(KEY) and (Opt("spellPower") == true or Opt("spellTotal") == true or Opt("spellRates") == true or Mode() ~= "off")
end

-- SpellModel (SpellModel.lua), looked up when asked; nil while it is not there.
local function Model()
	local M = ns.SpellModel
	if type(M) == "table" then
		return M
	end
	return nil
end

-- The colours of the style: SpellModel.lua's M.Fmt.Style, else this file's.
local function Colours()
	local M = Model()
	local fmt = M and type(M.Fmt) == "table" and M.Fmt or nil
	local style = fmt and type(fmt.Style) == "table" and fmt.Style or nil
	if style and type(style.header) == "table" and type(style.label) == "table" and type(style.value) == "table" and type(style.dim) == "table" then
		return style
	end
	return SL.STYLE
end

-- Reading the game's tables ---------------------------------------------------------------------------------------------------------------------

-- t[key], for pcall.
local function Index(t, key)
	return t[key]
end

-- A field of a table the game gave (the data, its lines, the tooltip's processingInfo and its getterArgs), or nil when the table or the field is
-- withheld or reading it raises.
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

-- A field of a line SpellModel gave, by its name, else by its place in { left, right, tone, dim, wrap }.
local function Of(line, name, place)
	local value = line[name]
	if value == nil then
		value = line[place]
	end
	return value
end

-- True for a whole number above 0 the game gave plainly: a spell ID or an action slot.
local function Whole(value)
	return ns.Finite(value) and value > 0 and value == math.floor(value)
end

-- The values of Enum.TooltipDataType a spell line goes on, read once.
local function Kinds()
	local kinds = run.kinds
	if kinds == nil then
		local enum = Field(Enum, "TooltipDataType")
		kinds = {}
		for name, fallback in pairs(SL.TYPES) do
			local value = Field(enum, name)
			kinds[name] = ns.Finite(value) and value or fallback
		end
		run.kinds = kinds
	end
	return kinds
end

-- True while Show spell lines lets the lines show: Always, or its key is down. A key the game does not say is down counts as up, as ChatTips.lua
-- reads Show IDs.
local function KeyHeld(choice)
	local down
	if choice == "shift" then
		down = IsShiftKeyDown
	elseif choice == "ctrl" then
		down = IsControlKeyDown
	elseif choice == "alt" then
		down = IsAltKeyDown
	else
		return true
	end
	if type(down) ~= "function" then
		return false
	end
	local ok, held = pcall(down)
	return ok and not IsSecret(held) and held == true
end

-- The spell ----------------------------------------------------------------------------------------------------------------------------------

-- The spell the first line of a macro's or a pet action's data names (its tooltipID while its tooltipType says a spell), or nil.
local function LineSpell(data)
	local first = Field(Field(data, "lines"), 1)
	if Field(first, "tooltipType") ~= SL.SPELL_LINE then
		return nil
	end
	local id = Field(first, "tooltipID")
	return Whole(id) and id or nil
end

-- The spell of the macro on the action slot this build is of, or nil when the build is not of an action slot or the slot holds no spell.
-- ns.ActionSpell (Cooldowns.lua, design 4.3) answers the spell's ID, or nil.
local function SlotSpell(tooltip)
	local info = Field(tooltip, "processingInfo")
	if Field(info, "getterName") ~= SL.ACTION then
		return nil
	end
	local slot = Field(Field(info, "getterArgs"), 1)
	local read = ns.ActionSpell
	if not Whole(slot) or type(read) ~= "function" then
		return nil
	end
	-- A fault of the slot's read leaves a macro without lines and does not count against this part.
	local ok, id = pcall(read, slot)
	if not ok or IsSecret(id) then
		return nil
	end
	return Whole(id) and id or nil
end

-- The rank and the entry of a talent's block: the getterArgs of a build through GetTraitEntry (the entry, then the rank), or nil for any other
-- build. A talent the player has no point in yet shows rank 0.
local function TalentRank(tooltip)
	local info = Field(tooltip, "processingInfo")
	if Field(info, "getterName") ~= SL.TRAIT then
		return nil
	end
	local args = Field(info, "getterArgs")
	local rank, trait = Field(args, 2), Field(args, 1)
	if ns.Finite(rank) and rank >= 0 and rank == math.floor(rank) then
		return rank, Whole(trait) and trait or nil
	end
	return nil
end

-- The tests of design 4.4 and the spell ID of design 1.1, keyed by the data of the build. What it finds goes to Work through pick.
local function Find(data, tooltip)
	if not (rawequal(tooltip, GameTooltip) or rawequal(tooltip, ItemRefTooltip)) or ns.Forbidden(tooltip) then
		return
	end
	local readable, embedded = pcall(Index, tooltip, "IsEmbedded")
	if not readable or IsSecret(embedded) or embedded == true then
		return
	end
	local kinds, kind = Kinds(), Field(data, "type")
	local spell, macro = kind == kinds.Spell, kind == kinds.Macro
	if not (spell or macro or kind == kinds.PetAction) then
		return
	end
	-- A clicked link's tooltip is never built with a key down (header): its lines show at every choice.
	if not rawequal(tooltip, ItemRefTooltip) and not KeyHeld(Opt("spellWhen")) then
		return
	end
	local id, rank, trait
	if spell then
		id, rank, trait = Field(data, "id"), TalentRank(tooltip)
	else
		id = LineSpell(data)
		if id == nil and macro then
			id = SlotSpell(tooltip)
		end
	end
	local M = Model()
	if not Whole(id) or not M or type(M.Find) ~= "function" then
		return
	end
	local entry, index = M.Find(id)
	if type(entry) ~= "table" then
		entry, index = nil, nil
		-- No entry: only the lines of a rule could show, and only with Threat lines on.
		if Mode() == "off" then
			return
		end
	end
	pick.id, pick.entry, pick.index, pick.rank, pick.trait = id, entry, index, rank, trait
end

-- The lines --------------------------------------------------------------------------------------------------------------------------------

-- True while SpellModel's stats are from before the fight now on.
local function Old(stats)
	return type(stats) == "table" and stats.old == true
end

-- True for an entry of the player's pet (design 3.2).
local function Pet(entry)
	return type(entry) == "table" and entry.pet == true
end

-- The pet's level, or nil with no pet or no plain answer.
local function PetLevel()
	if type(UnitLevel) ~= "function" then
		return nil
	end
	local ok, level = pcall(UnitLevel, "pet")
	if ok and ns.Finite(level) and level > 0 then
		return level
	end
	return nil
end

-- The player's role for the threat block: SpellModel's state has it (ns.PlayerRole's first answer, Core.lua), else ns.PlayerRole is asked.
local function Role(state)
	local role = type(state) == "table" and state.role or nil
	if not IsSecret(role) and SL.ROLES[role] then
		return role
	end
	if type(ns.PlayerRole) == "function" then
		local ok, kind = pcall(ns.PlayerRole)
		if ok and not IsSecret(kind) and SL.ROLES[kind] then
			return kind
		end
	end
	return nil
end

-- A line of SpellModel's as Put adds it, { left, right, colour, rightColour, wrap, note }, and true when its number is from before the fight. Nil
-- for a line with no text, and for the sentence that the stats are old, which Shape adds once, last. In the style (M.Fmt.Style): a figure's label
-- light grey and its value white, or light grey while the value is old; a dim line is a note, in the dim colour, and wraps unless it says not
-- to; a share with no number is a line alone, wrapped when it asks.
local function Line(line, style)
	if type(line) ~= "table" then
		return nil, false
	end
	local left, right, tone = Of(line, "left", 1), Of(line, "right", 2), Of(line, "tone", 3)
	local dim, wrap = Of(line, "dim", 4) == true, Of(line, "wrap", 5)
	if IsSecret(left) or type(left) ~= "string" or left == "" then
		return nil, false
	end
	if IsSecret(right) or type(right) ~= "string" or right == "" then
		right = nil
	end
	if dim and left == SL.OLD then
		return nil, true
	end
	if dim then
		return { left = left, right = right, colour = style.dim, rightColour = style.dim, wrap = right == nil and wrap ~= false, note = true }, false
	end
	local old = right ~= nil and not IsSecret(tone) and tone == "old"
	return { left = left, right = right, colour = style.label, rightColour = old and style.label or style.value, wrap = right == nil and wrap == true },
		old
end

-- A note's text for a joined line: its own words, with its right text after them, and no full stop at the end.
local function NoteText(line)
	local text = line.right and (line.left .. " " .. line.right) or line.left
	return (text:gsub("%.$", ""))
end

-- The lines of one block as they are added (0.5.20, the style): the block's title (its list's title) as one gold header where more than one line
-- that is no note follows; its lines in their order; and its notes, in Full each where it comes, in Compact joined into one dim line at its end
-- (chat.tipDetail). aged says a number shown is from before the fight.
local function Block(lines, raw, style, full)
	local shaped, notes, figures, aged = {}, {}, 0, false
	for _, line in ipairs(raw) do
		local one, old = Line(line, style)
		aged = aged or old
		if one and one.note and not full then
			notes[#notes + 1] = NoteText(one)
		elseif one then
			shaped[#shaped + 1] = one
			figures = figures + (one.note and 0 or 1)
		end
	end
	if #notes > 0 then
		shaped[#shaped + 1] = { left = table.concat(notes, SL.JOIN), colour = style.dim, rightColour = style.dim, wrap = true, note = true }
	end
	local title = raw.title
	if figures > 1 and not IsSecret(title) and type(title) == "string" and title ~= "" then
		lines[#lines + 1] = { left = title, colour = style.header, rightColour = style.header, wrap = false }
	end
	for _, line in ipairs(shaped) do
		lines[#lines + 1] = line
	end
	return aged
end

-- The lines as they are added: SpellModel's blocks in their order, each shaped by Block, and, while a number shown is from before the fight, the
-- dim line that says so once at the end of them, in place of a mark on every line (design 1.2).
local function Shape(blocks, withStats, full)
	local lines, aged, style = {}, false, Colours()
	for _, raw in ipairs(blocks) do
		if type(raw) == "table" and Block(lines, raw, style, full) then
			aged = true
		end
	end
	if aged and withStats then
		lines[#lines + 1] = { left = SL.OLD, colour = style.dim, rightColour = style.dim, wrap = true, note = true }
	end
	return lines
end

-- Empties the cache when what its lines were made for changed: SpellModel's version, whether the stats are old, the text check's answer (which
-- turns "+417" into "of which 417"), or a row (now: the same fields). made then holds what the next lines are made for, which Build reads.
local function Fresh(now)
	local same = true
	for key, value in pairs(now) do
		same = same and made[key] == value
	end
	for key in pairs(made) do
		same = same and now[key] ~= nil
	end
	if not same then
		cache, order = {}, {}
		made = now
	end
end

-- The list SpellModel gave as one block, or nil.
local function Gather(list)
	return type(list) == "table" and list or nil
end

-- Works out the lines of a spell from SpellModel, for the rows made holds, block by block: the power lines, the total and its rates (which need
-- the stats), the threat block, then the lines of a rule whose tooltip this is. With your stats off, no right text that needs a stat shows (design
-- 1.4), so the threat block gets no stats either and the total does not show.
local function Build(M, id, entry, index, rank, state, stats, petLevel)
	local blocks = {}
	if entry then
		if made.power and type(M.PowerLines) == "function" then
			blocks[#blocks + 1] = Gather(M.PowerLines(entry, index, state, stats, { stats = made.withStats, lowRank = made.lowRank }))
		end
		if (made.total or made.rates) and made.withStats and type(M.TotalLines) == "function" then
			blocks[#blocks + 1] = Gather(M.TotalLines(entry, index, state, stats, { total = made.total, rates = made.rates, lowRank = made.lowRank }))
		end
		if made.mode ~= "off" and type(M.ThreatLines) == "function" then
			blocks[#blocks + 1] = Gather(M.ThreatLines(entry, index, state, made.withStats and stats or nil,
				{ mode = made.mode, petLevel = petLevel, role = Role(state) }))
		end
	end
	if made.mode ~= "off" and type(M.RuleLines) == "function" then
		blocks[#blocks + 1] = Gather(M.RuleLines(id, state, rank))
	end
	return Shape(blocks, made.withStats, made.full)
end

-- Keeps the lines of a spell, forgetting the spell kept longest when MOST are kept.
local function Remember(id, rank, kept)
	local slot = cache[id]
	if slot == nil then
		if #order >= SL.MOST then
			cache[table.remove(order, 1)] = nil
		end
		slot = {}
		cache[id] = slot
		order[#order + 1] = id
	end
	slot[rank or SL.NO_RANK] = kept
end

-- The lines of a spell for the player now, from the cache while nothing they show has changed. SpellModel's reads come first, since they may
-- change its version.
local function LinesOf(M, id, entry, index, rank)
	local state = type(M.State) == "function" and M.State() or nil
	local stats = type(M.Stats) == "function" and M.Stats() or nil
	local version = type(M.Version) == "function" and M.Version() or nil
	local check = type(M.TextCheck) == "function" and M.TextCheck() or nil
	local withStats = Opt("spellStats") == true
	Fresh({ version = version or false, old = withStats and Old(stats), check = check or false, power = Opt("spellPower") == true,
		withStats = withStats, lowRank = Opt("spellLowRank") == true, mode = Mode(), total = Opt("spellTotal") == true,
		rates = Opt("spellRates") == true, full = Opt("tipDetail") == "full" })
	local petLevel = Pet(entry) and PetLevel() or nil
	local slot = cache[id]
	local kept = slot and slot[rank or SL.NO_RANK]
	if kept and kept.pet == petLevel then
		return kept.lines
	end
	local lines = Build(M, id, entry, index, rank, state, stats, petLevel)
	Remember(id, rank, { pet = petLevel, lines = lines })
	return lines
end

-- Adding ---------------------------------------------------------------------------------------------------------------------------------

-- Adds one line to the tooltip: a share and its number side by side, or a line alone, wrapped when it asks. True when the game took it.
local function Put(tooltip, line)
	local left, right = line.colour, line.rightColour
	if line.right then
		return (pcall(tooltip.AddDoubleLine, tooltip, line.left, line.right, left[1], left[2], left[3], right[1], right[2], right[3]))
	end
	return (pcall(tooltip.AddLine, tooltip, line.left, left[1], left[2], left[3], line.wrap == true))
end

-- The lines of one spell on the tooltip, once for each build, keyed by the spell ID. The same data with at least the lines added then still there
-- is the same build, so a second post call of it adds none, and a refused line ends the adding for that build. A talent's block of a higher rank
-- right after a block of the same entry, whose lines are still there, is the next rank's of the same tooltip (header): a dim line that block
-- added is not added again.
local function Work(id, tooltip, data, entry, index, rank, trait)
	local ok, shown = pcall(tooltip.NumLines, tooltip)
	if not ok or not ns.Finite(shown) then
		return
	end
	local record = added[tooltip]
	if record and rawequal(record.data, data) and shown >= record.lines then
		return
	end
	local M = Model()
	if not M then
		return
	end
	local lines = LinesOf(M, id, entry, index, rank)
	if #lines == 0 then
		return
	end
	local before = nil
	if record and trait and record.trait == trait and rank and record.rank and rank > record.rank and shown >= record.lines then
		before = record.notes
	end
	local notes = {}
	for _, line in ipairs(lines) do
		local dim = line.note == true and line.right == nil
		if not (dim and before and before[line.left]) then
			if not Put(tooltip, line) then
				break
			end
			shown = shown + 1
			if dim then
				notes[line.left] = true
			end
		end
	end
	if not record then
		record = {}
		added[tooltip] = record
	end
	record.data, record.lines, record.trait, record.rank, record.notes = data, shown, trait, rank, notes
end

-- Sends the first error of this part once to the game's error handler, as Bags' parts send theirs (Bags.lua:360-367).
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

-- Tells SpellModel whether this part wants its events (M.Want), when that changes or a sync asks again. As this part starts to want them,
-- SpellModel is asked to read everything again at the next build (M.Mark), since it may have heard nothing while no part wanted them.
local function Want(on, again)
	on = on == true
	local was = run.wanting
	if was == on and not again then
		return
	end
	run.wanting = on
	local M = Model()
	if not M then
		return
	end
	if type(M.Want) == "function" then
		M.Want(PART, on)
	end
	if on and not was and type(M.Mark) == "function" then
		for _, what in ipairs(SL.MARKS) do
			M.Mark(what)
		end
	end
end

-- Called by Chat.lua's post call for every build of a tooltip of any kind (design 4.4): nothing unless the module is on and a row wants lines;
-- then the tests keyed by the data of the build and the lines keyed by the spell ID, each inside ns.EachPart, so a fault stops this part alone
-- and never reaches the post call.
function ns.SpellTipLines(tooltip, data)
	if not Wanted() then
		return
	end
	if ns.PartStopped(KEY, PART) then
		pcall(Want, false)
		return
	end
	-- The first argument of ns.EachPart is the key of its failures, which a withheld value may not be.
	if IsSecret(tooltip) or IsSecret(data) or type(data) ~= "table" then
		return
	end
	pick.id, pick.entry, pick.index, pick.rank, pick.trait = nil, nil, nil, nil, nil
	local ok, err = ns.EachPart(KEY, PART, Find, data, tooltip)
	Report(ok, err)
	local id, entry, index, rank, trait = pick.id, pick.entry, pick.index, pick.rank, pick.trait
	pick.id, pick.entry, pick.index, pick.rank, pick.trait = nil, nil, nil, nil, nil
	if ok and id then
		Report(ns.EachPart(KEY, PART, Work, id, tooltip, data, entry, index, rank, trait))
	end
end

-- A sync: the rows may have changed, so the cache goes, and SpellModel hears whether this part wants its events.
local function Sync()
	cache, order, made = {}, {}, {}
	Want(Wanted() and not ns.PartStopped(KEY, PART), true)
end

-- Called by Chat.lua at the end of each refresh, also as the module goes off. Each sync is keyed by its number, so three that fail stop the part;
-- a sync that fails, or a part or module that is stopped, wants nothing of SpellModel.
function ns.SpellLinesSync()
	run.syncs = run.syncs + 1
	local ok, err = ns.EachPart(KEY, PART, Sync, run.syncs)
	Report(ok, err)
	if not ok then
		pcall(Want, false, true)
	end
end

-- /flatui status ---------------------------------------------------------------------------------------------------------------------------

-- Puts a line after those of a list, when there is one.
local function Push(list, text)
	if text then
		list[#list + 1] = text
	end
end

-- How long ago a time of GetTime was, in words, or nil.
local function Ago(at)
	if not ns.Finite(at) or type(GetTime) ~= "function" then
		return nil
	end
	local ok, now = pcall(GetTime)
	if not ok or not ns.Finite(now) then
		return nil
	end
	local seconds = math.max(0, now - at)
	if seconds < 60 then
		return "less than a minute ago"
	elseif seconds < 3600 then
		return ("%d min ago"):format(math.floor(seconds / 60))
	end
	local hours = math.floor(seconds / 3600)
	return hours == 1 and "an hour ago" or ("%d hours ago"):format(hours)
end

-- True while the game withholds the player's stats, and when it does not say.
local function Withheld()
	local ask = Field(C_Secrets, "ShouldUnitStatsBeSecret")
	if type(ask) ~= "function" then
		return true
	end
	local ok, secret = pcall(ask)
	return not ok or IsSecret(secret) or secret ~= false
end

-- The status line of the data: its client build, its hotfix push and its number of spells (D.SPELLS, every class's, as the generator counts them;
-- a data file without it says no number).
local function DataLine()
	local D = ns.SpellData
	if type(D) ~= "table" or type(D.BUILD) ~= "string" then
		return nil
	end
	local push = D.HOTFIX ~= nil and (" (hotfix push %s)"):format(tostring(D.HOTFIX)) or ""
	local count = ns.Finite(D.SPELLS) and (", %d spells"):format(D.SPELLS) or ""
	return ("Spell lines: WoW: Forever's values, client build %s%s%s; ~ marks an estimate."):format(D.BUILD, push, count)
end

-- The status line of the stats, while With your stats is on: when they were read, that the game withholds them in this fight, or that it has not
-- given them yet. Stats from before a fight that the game no longer withholds are what it gave last, since no event has marked them since.
local function StatsLine(M)
	if type(M.Stats) ~= "function" then
		return nil
	end
	local ok, stats = pcall(M.Stats)
	if not ok then
		return nil
	end
	if type(stats) ~= "table" then
		return "Spell lines: the game has not given your stats yet, so only the shares show."
	end
	if Old(stats) and Withheld() then
		return "Spell lines: the game withholds your stats in this fight; the numbers are from before it."
	end
	local ago = Ago(stats.time)
	return ago and ("Spell lines: your stats were read %s."):format(ago) or "Spell lines: your stats were read."
end

-- The name of the spell the text check read, with its rank, as "Fireball Rank 12", or nil.
local function Probe(name, rank)
	if IsSecret(name) or type(name) ~= "string" or name == "" then
		return nil
	end
	if ns.Finite(rank) then
		return ("%s Rank %d"):format(name, math.floor(rank))
	elseif not IsSecret(rank) and type(rank) == "string" and rank ~= "" then
		return ("%s %s"):format(name, rank)
	end
	return name
end

-- The status line of SpellModel's check whether the game's spell texts count spell power (M.TextCheck, design 6.1).
local function CheckLine(M)
	if type(M.TextCheck) ~= "function" then
		return nil
	end
	local ok, answer, name, rank = pcall(M.TextCheck)
	if not ok then
		return nil
	end
	local probe = Probe(name, rank)
	local on = probe and (" (checked on %s)"):format(probe) or ""
	if answer == "base" then
		return ("Spell lines: the game's spell texts give base values, so the lines add your stats on top%s."):format(on)
	elseif answer == "with" then
		return ("Spell lines: the game's spell texts already count your spell power%s, so the lines say of which."):format(on)
	end
	return "Spell lines: not checked yet whether the game's spell texts count your spell power (it needs an English client and some spell power); "
		.. "the lines add your stats on top, as the game's data says."
end

-- A share of 1 as a number of percent with no ".0": 0.05 is "5".
local function Percent(share)
	local text = ("%.1f"):format(share * 100)
	return (text:gsub("%.0$", ""))
end

-- The status line of the low rank rule while its row is on (design 6.2), with the data's numbers.
local function LowRankLine()
	local D = ns.SpellData
	local model = type(D) == "table" and D.MODEL or nil
	local rule = type(model) == "table" and model.downrank or nil
	local grace = type(rule) == "table" and ns.Finite(rule.grace) and rule.grace or SL.GRACE
	local step = type(rule) == "table" and ns.Finite(rule.step) and rule.step or SL.STEP
	return ("Spell lines: low ranks get less spell power, by an estimate from players' tests on heals up to level 30 (in full for %d levels "
		.. "after the rank, then %s%% less a level)."):format(math.floor(grace), Percent(step))
end

-- The lines of /flatui status, while the module is on and a row wants lines (design 4.12). A stopped part has its own line from ns.EachPart.
ns.AddStatus(KEY, function()
	if not Wanted() or ns.PartStopped(KEY, PART) then
		return {}
	end
	local lines, M = {}, Model()
	local power, withStats = Opt("spellPower") == true, Opt("spellStats") == true
	Push(lines, DataLine())
	if M and withStats then
		Push(lines, StatsLine(M))
		if power then
			Push(lines, CheckLine(M))
		end
	end
	if power and Opt("spellLowRank") == true then
		Push(lines, LowRankLine())
	end
	-- Once seen: a talent's node did not answer with the data's definition, so SpellModel looked through the whole tree (design 4.12, 6.25).
	local read, state = false, nil
	if M and type(M.State) == "function" then
		read, state = pcall(M.State)
	end
	if read and type(state) == "table" and state.treeWalked == true then
		Push(lines, "Spell lines: your talent tree differs from the data's, so Flat UI looked through all of it.")
	end
	return lines
end)
