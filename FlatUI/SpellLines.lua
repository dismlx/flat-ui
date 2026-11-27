local _, ns = ...

local KEY, PART = "chat", "spell lines"
local IsSecret = ns.IsSecret

local SL = {
	PATH = { spellPower = "chat.spellPower", spellStats = "chat.spellStats", spellLowRank = "chat.spellLowRank", spellThreat = "chat.spellThreat",
		spellWhen = "chat.spellWhen", spellTotal = "chat.spellTotal", spellRates = "chat.spellRates", tipDetail = "chat.tipDetail",
		spellNextRank = "chat.spellNextRank", spellHint = "chat.spellHint" },
	DEFAULT = { spellPower = true, spellStats = true, spellLowRank = true, spellThreat = "special", spellWhen = "always", spellTotal = true,
		spellRates = true, tipDetail = "compact", spellNextRank = true, spellHint = true },
	HINT = "%s: your numbers for this spell",
	HINT_KEYS = { shift = "Shift", ctrl = "Ctrl", alt = "Alt" },
	HINT_COLOUR = { 0.66, 0.68, 0.62 },
	TYPES = { Spell = 1, PetAction = 11, Macro = 25 },
	SPELL_LINE = 1,
	ACTION = "GetAction",
	TRAIT = "GetTraitEntry",
	STYLE = { header = { 1, 0.82, 0 }, label = { 0.82, 0.82, 0.82 }, value = { 1, 1, 1 }, dim = { 0.66, 0.68, 0.62 }, good = { 0.1, 1, 0.1 } },
	JOIN = "; ",
	OLD = "Your stats from before this fight.",
	NEXT = "Next rank: Rank %d at level %d",
	LEARN = "Rank %d: you can learn it now",
	BOOK = "Rank %d comes from a book, not a trainer",
	BOOKS = {
		[25286] = true, [25288] = true,
		[25292] = true,
		[25295] = true,
		[25300] = true, [25302] = true, [25349] = true,
		[25314] = true, [25315] = true, [25316] = true,
		[25357] = true,
		[25304] = true, [25306] = true, [25345] = true,
		[25307] = true, [25309] = true, [25311] = true,
		[25297] = true, [25298] = true, [25299] = true,
	},
	MOST = 64,
	NO_RANK = -1,
	MARKS = { "state", "stats", "talents", "gear", "spells", "role" },
	ROLES = { tank = true, healer = true, damage = true },
	GRACE = 17,
	STEP = 0.05,
}

local added = setmetatable({}, { __mode = "k" })
local cache, order = {}, {}
local made = {}
local pick = {}
local hinted = setmetatable({}, { __mode = "k" })
local run = { wanting = false, reported = false, syncs = 0 }

local function Opt(key)
	local value = ns.Get(SL.PATH[key])
	if value == nil then
		return SL.DEFAULT[key]
	end
	return value
end

local function Mode()
	local mode = Opt("spellThreat")
	if mode == "all" or mode == "off" then
		return mode
	end
	return "special"
end

local function Wanted()
	return ns.Enabled(KEY) and (Opt("spellPower") == true or Opt("spellTotal") == true or Opt("spellRates") == true or Mode() ~= "off"
		or Opt("spellNextRank") == true)
end

local function Model()
	local M = ns.SpellModel
	if type(M) == "table" then
		return M
	end
	return nil
end

local function Colours()
	local M = Model()
	local fmt = M and type(M.Fmt) == "table" and M.Fmt or nil
	local style = fmt and type(fmt.Style) == "table" and fmt.Style or nil
	if style and type(style.header) == "table" and type(style.label) == "table" and type(style.value) == "table" and type(style.dim) == "table" then
		return style
	end
	return SL.STYLE
end

local function Index(t, key)
	return t[key]
end

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

local function Of(line, name, place)
	local value = line[name]
	if value == nil then
		value = line[place]
	end
	return value
end

local function Whole(value)
	return ns.Finite(value) and value > 0 and value == math.floor(value)
end

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

local function LineSpell(data)
	local first = Field(Field(data, "lines"), 1)
	if Field(first, "tooltipType") ~= SL.SPELL_LINE then
		return nil
	end
	local id = Field(first, "tooltipID")
	return Whole(id) and id or nil
end

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
	local ok, id = pcall(read, slot)
	if not ok or IsSecret(id) then
		return nil
	end
	return Whole(id) and id or nil
end

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
	local waiting = not rawequal(tooltip, ItemRefTooltip) and not KeyHeld(Opt("spellWhen"))
	if waiting and Opt("spellHint") ~= true then
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
	if waiting then
		pick.hint = type(entry) == "table" and SL.HINT_KEYS[Opt("spellWhen")] and id or nil
		return
	end
	if type(entry) ~= "table" then
		entry, index = nil, nil
		if Mode() == "off" then
			return
		end
	end
	pick.id, pick.entry, pick.index, pick.rank, pick.trait = id, entry, index, rank, trait
end

local function Old(stats)
	return type(stats) == "table" and stats.old == true
end

local function Pet(entry)
	return type(entry) == "table" and entry.pet == true
end

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
		local kept = right ~= nil or wrap == false
		return { left = left, right = right, colour = style.dim, rightColour = style.dim, wrap = not kept, note = not kept, dim = true }, false
	end
	local old = right ~= nil and not IsSecret(tone) and tone == "old"
	return { left = left, right = right, colour = style.label, rightColour = old and style.label or style.value, wrap = right == nil and wrap == true },
		old
end

local function NoteText(line)
	return (line.left:gsub("%.$", ""))
end

local function Block(lines, raw, style, full)
	local shaped, notes, figures, aged = {}, {}, 0, false
	for _, line in ipairs(raw) do
		local one, old = Line(line, style)
		aged = aged or old
		if one and one.note and not full then
			notes[#notes + 1] = NoteText(one)
		elseif one then
			shaped[#shaped + 1] = one
			figures = figures + (one.dim and 0 or 1)
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

local function Gather(list)
	return type(list) == "table" and list or nil
end

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
				{ mode = made.mode, petLevel = petLevel, role = Role(state), lowRank = made.lowRank }))
		end
	end
	if made.mode ~= "off" and type(M.RuleLines) == "function" then
		blocks[#blocks + 1] = Gather(M.RuleLines(id, state, rank))
	end
	return Shape(blocks, made.withStats, made.full)
end

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

local function NextRank(entry, index, rank, trait)
	if rank ~= nil or trait ~= nil or Opt("spellNextRank") ~= true or type(entry) ~= "table" or entry.pet == true or entry.seal ~= nil
		or not Whole(index) or type(entry.ranks) ~= "table" or type(ns.SpellKnown) ~= "function" or type(UnitLevel) ~= "function" then
		return nil
	end
	local ranks = entry.ranks
	local after = ranks[index + 1]
	local learn = type(after) == "table" and after[2] or nil
	if not Whole(learn) then
		return nil
	end
	for place = index + 1, #ranks do
		local spell = type(ranks[place]) == "table" and ranks[place][1] or nil
		if Whole(spell) then
			local ok, known = pcall(ns.SpellKnown, spell)
			if not ok or IsSecret(known) or known ~= false then
				return nil
			end
		end
	end
	local ok, level = pcall(UnitLevel, "player")
	if not ok or not ns.Finite(level) or level <= 0 then
		return nil
	end
	local style = Colours()
	if Whole(after[1]) and SL.BOOKS[after[1]] then
		return { left = SL.BOOK:format(index + 1), colour = style.dim, rightColour = style.dim, wrap = true, note = true }
	end
	if level >= learn then
		local good = type(style.good) == "table" and style.good or SL.STYLE.good
		return { left = SL.LEARN:format(index + 1), colour = good, rightColour = good, wrap = true, note = true }
	end
	return { left = SL.NEXT:format(index + 1, learn), colour = style.dim, rightColour = style.dim, wrap = true, note = true }
end

local function Put(tooltip, line)
	local left, right = line.colour, line.rightColour
	if line.right then
		return (pcall(tooltip.AddDoubleLine, tooltip, line.left, line.right, left[1], left[2], left[3], right[1], right[2], right[3]))
	end
	return (pcall(tooltip.AddLine, tooltip, line.left, left[1], left[2], left[3], line.wrap == true))
end

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
	local nextRank = NextRank(entry, index, rank, trait)
	if #lines == 0 and nextRank == nil then
		return
	end
	local before = nil
	if record and trait and record.trait == trait and rank and record.rank and rank > record.rank and shown >= record.lines then
		before = record.notes
	end
	local notes, refused = {}, false
	for _, line in ipairs(lines) do
		local dim = line.note == true and line.right == nil
		if not (dim and before and before[line.left]) then
			if not Put(tooltip, line) then
				refused = true
				break
			end
			shown = shown + 1
			if dim then
				notes[line.left] = true
			end
		end
	end
	if nextRank and not refused and Put(tooltip, nextRank) then
		shown = shown + 1
	end
	if not record then
		record = {}
		added[tooltip] = record
	end
	record.data, record.lines, record.trait, record.rank, record.notes = data, shown, trait, rank, notes
end

local function Hint(_, tooltip, data)
	local key = SL.HINT_KEYS[Opt("spellWhen")]
	local ok, shown = pcall(tooltip.NumLines, tooltip)
	if not key or not ok or not ns.Finite(shown) then
		return
	end
	local record = hinted[tooltip]
	if record and rawequal(record.data, data) and shown >= record.lines then
		return
	end
	local colour = SL.HINT_COLOUR
	if pcall(tooltip.AddLine, tooltip, SL.HINT:format(key), colour[1], colour[2], colour[3]) then
		hinted[tooltip] = { data = data, lines = shown + 1 }
	end
end

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

function ns.SpellTipLines(tooltip, data)
	if not Wanted() then
		return
	end
	if ns.PartStopped(KEY, PART) then
		pcall(Want, false)
		return
	end
	if IsSecret(tooltip) or IsSecret(data) or type(data) ~= "table" then
		return
	end
	pick.id, pick.entry, pick.index, pick.rank, pick.trait, pick.hint = nil, nil, nil, nil, nil, nil
	local ok, err = ns.EachPart(KEY, PART, Find, data, tooltip)
	Report(ok, err)
	local id, entry, index, rank, trait, hint = pick.id, pick.entry, pick.index, pick.rank, pick.trait, pick.hint
	pick.id, pick.entry, pick.index, pick.rank, pick.trait, pick.hint = nil, nil, nil, nil, nil, nil
	if ok and hint then
		Report(ns.EachPart(KEY, PART, Hint, hint, tooltip, data))
	elseif ok and id then
		Report(ns.EachPart(KEY, PART, Work, id, tooltip, data, entry, index, rank, trait))
	end
end

local function Sync()
	cache, order, made = {}, {}, {}
	Want(Wanted() and not ns.PartStopped(KEY, PART), true)
end

function ns.SpellLinesSync()
	run.syncs = run.syncs + 1
	local ok, err = ns.EachPart(KEY, PART, Sync, run.syncs)
	Report(ok, err)
	if not ok then
		pcall(Want, false, true)
	end
end

local function Push(list, text)
	if text then
		list[#list + 1] = text
	end
end

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

local function Withheld()
	local ask = Field(C_Secrets, "ShouldUnitStatsBeSecret")
	if type(ask) ~= "function" then
		return true
	end
	local ok, secret = pcall(ask)
	return not ok or IsSecret(secret) or secret ~= false
end

local function DataLine()
	local D = ns.SpellData
	if type(D) ~= "table" or type(D.BUILD) ~= "string" then
		return nil
	end
	local push = D.HOTFIX ~= nil and (" (hotfix push %s)"):format(tostring(D.HOTFIX)) or ""
	local count = ns.Finite(D.SPELLS) and (", %d spells"):format(D.SPELLS) or ""
	return ("Spell lines: WoW: Forever's values, client build %s%s%s; ~ marks an estimate."):format(D.BUILD, push, count)
end

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

local function Percent(share)
	local text = ("%.1f"):format(share * 100)
	return (text:gsub("%.0$", ""))
end

local function LowRankLine()
	local D = ns.SpellData
	local model = type(D) == "table" and D.MODEL or nil
	local rule = type(model) == "table" and model.downrank or nil
	local grace = type(rule) == "table" and ns.Finite(rule.grace) and rule.grace or SL.GRACE
	local step = type(rule) == "table" and ns.Finite(rule.step) and rule.step or SL.STEP
	return ("Spell lines: low ranks get less spell power, by an estimate from players' tests on heals up to level 30 (in full for %d levels "
		.. "after the rank, then %s%% less a level)."):format(math.floor(grace), Percent(step))
end

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
	local read, state = false, nil
	if M and type(M.State) == "function" then
		read, state = pcall(M.State)
	end
	if read and type(state) == "table" and state.treeWalked == true then
		Push(lines, "Spell lines: your talent tree differs from the data's, so Flat UI looked through all of it.")
	end
	return lines
end)
