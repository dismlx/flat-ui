local _, ns = ...

local KEY, PART = "combattext", "announce to your group"
local KINDS = { "DODGE", "PARRY", "BLOCK", "MISS", "RESIST", "IMMUNE", "ABSORB" }
local ROWS = { DODGE = "announceDodge", PARRY = "announceParry", BLOCK = "announceBlock", MISS = "announceMiss", RESIST = "announceResist",
	IMMUNE = "announceImmune", ABSORB = "announceAbsorb" }
local SAID = { DODGE = "Dodged", PARRY = "Parried", BLOCK = "Blocked", MISS = "Missed me", RESIST = "Resisted", IMMUNE = "Immune", ABSORB = "Absorbed" }
local NOUNS = { DODGE = { "dodge", "dodges" }, PARRY = { "parry", "parries" }, BLOCK = { "block", "blocks" }, MISS = { "miss", "misses" },
	RESIST = { "resist", "resists" }, IMMUNE = { "immunity", "immunities" }, ABSORB = { "absorb", "absorbs" } }
local WHOLE = { DODGE = true, PARRY = true, BLOCK = true, MISS = true, RESIST = true, IMMUNE = true, ABSORB = true }
local ZERO = { BLOCK = true, ABSORB = true, RESIST = true }
local PLACES = { RAID = "raid chat", PARTY = "party chat", INSTANCE_CHAT = "instance chat", self = "your own chat window only" }
local TO = { group = "Your group's chat", party = "Party chat only", raid = "Raid chat only", self = "Only me" }
local EVERY = { each = "Each one", summary = "A summary every few seconds", fight = "One line when the fight ends" }
local GAP, TICK, HOLD, SECONDS, LOW, HIGH = 1, 0.2, 30, 5, 3, 15
local OWN = "Announce (only you): "
local SAMPLE_EACH = { { "DODGE" }, { "PARRY" }, { "BLOCK", 245 }, { "BLOCK", false, true }, { "MISS" }, { "RESIST" }, { "IMMUNE" }, { "ABSORB" } }
local SAMPLE_COUNTS = { summary = { DODGE = 3, PARRY = 2, BLOCK = 4, MISS = 1, RESIST = 1, IMMUNE = 1, ABSORB = 1 },
	fight = { DODGE = 12, PARRY = 8, BLOCK = 15, MISS = 3, RESIST = 2, IMMUNE = 1, ABSORB = 2 } }
local SAMPLE_BLOCK = 120
local STALE_EVENTS = { "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "UPDATE_SHAPESHIFT_FORM",
	"PLAYER_ENTERING_WORLD" }
local HELP = {
	"/flatui announce - where Announce blocks, dodges and parries and Announce your interrupts send their lines now, or why they send nothing",
	"/flatui announce test - sample lines in your own chat window only, never sent to the group",
}
local KICK_SAMPLE, DEF_SAMPLE, DEF_LEAST = "Shadow Bolt", { "Shield Wall", 12 }, 60

local IsSecret, Finite = ns.IsSecret, ns.Finite

local function Empty()
	return { n = 0, count = {}, amount = {}, known = {}, partial = {} }
end

local S = { tank = false, roleStale = true, sent = 0, own = 0, held = 0, refused = 0, total = {}, batch = Empty(), kicks = 0, defs = 0 }

local Run, Flush

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function On()
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and Opt("announce") == true
end

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

local function Now()
	local now = Ask(GetTime)
	return Finite(now) and now or nil
end

local function InFight()
	local fight = Ask(UnitAffectingCombat, "player")
	if type(fight) == "boolean" then
		return fight
	end
	return Ask(InCombatLockdown) == true
end

local function Every()
	local every = Opt("announceEvery")
	return EVERY[every] and every or "each"
end

local function Target()
	local to = Opt("announceTo")
	return TO[to] and to or "group"
end

local function Seconds()
	local seconds = Opt("announceSeconds")
	if not Finite(seconds) then
		return SECONDS
	end
	return math.max(LOW, math.min(HIGH, math.floor(seconds + 0.5)))
end

local function Grouped(category)
	if category == nil then
		return Ask(IsInGroup) == true, Ask(IsInRaid) == true
	end
	return Ask(IsInGroup, category) == true, Ask(IsInRaid, category) == true
end

local function Place()
	if type(IsInInstance) ~= "function" then
		return nil
	end
	local ok, _, kind = pcall(IsInInstance)
	if ok and not IsSecret(kind) and type(kind) == "string" then
		return kind
	end
	return nil
end

local function Battle()
	local kind = Place()
	return kind == "pvp" or kind == "arena"
end

local function Channel(to)
	if Battle() then
		return nil, "you are in a battleground or arena"
	end
	if Opt("announceInstance") == true then
		local kind = Place()
		if kind ~= "party" and kind ~= "raid" then
			return nil, "you are not in a dungeon or raid"
		end
	end
	local home, instance = _G.LE_PARTY_CATEGORY_HOME, _G.LE_PARTY_CATEGORY_INSTANCE
	local inHome, homeRaid = Grouped(Finite(home) and home or nil)
	local inInstance, instanceRaid = false, false
	if Finite(instance) then
		inInstance, instanceRaid = Grouped(instance)
	end
	if not (inHome or inInstance) then
		return nil, "you are not in a group"
	elseif to == "self" then
		return "self"
	elseif to == "party" then
		if inHome then
			return "PARTY"
		elseif not instanceRaid then
			return "INSTANCE_CHAT"
		end
		return nil, "you are in an instance raid and Send to is Party chat only"
	elseif to == "raid" then
		if instanceRaid then
			return "INSTANCE_CHAT"
		elseif homeRaid then
			return "RAID"
		end
		return nil, "you are not in a raid and Send to is Raid chat only"
	elseif inInstance then
		return "INSTANCE_CHAT"
	end
	return homeRaid and "RAID" or "PARTY"
end

local function ReadRole()
	S.roleStale = false
	if type(ns.PlayerRole) ~= "function" then
		S.tank, S.by = false, nil
		return
	end
	local ok, role, _, by = pcall(ns.PlayerRole)
	S.tank = ok and not IsSecret(role) and role == "tank" or false
	S.by = ok and not IsSecret(by) and type(by) == "string" and by or nil
end

local function ReadBlock()
	local value = Ask(GetShieldBlock)
	if Finite(value) then
		S.block = value >= 1 and math.floor(value + 0.5) or nil
	end
	return S.block
end

local function Kind(action, flag, amount)
	if IsSecret(action) or type(action) ~= "string" then
		return nil
	elseif action ~= "WOUND" then
		if not WHOLE[action] then
			return nil
		elseif action == "BLOCK" and Finite(amount) and amount >= 1 then
			return "BLOCK", math.floor(amount + 0.5)
		end
		return action
	elseif IsSecret(flag) then
		return nil
	end
	flag = type(flag) == "string" and flag or ""
	if IsSecret(amount) then
		if flag == "BLOCK" then
			return "BLOCK"
		elseif flag == "BLOCK_REDUCED" then
			return "BLOCK", nil, true
		end
		return nil
	elseif not Finite(amount) or amount == 0 then
		return ZERO[flag] and flag or "MISS"
	elseif amount > 0 and (flag == "BLOCK_REDUCED" or flag == "BLOCK") then
		return "BLOCK", nil, true
	end
	return nil
end

local function Add(batch, kind, amount, partial, times)
	times = times or 1
	batch.n = batch.n + times
	batch.count[kind] = (batch.count[kind] or 0) + times
	if amount then
		batch.amount[kind] = (batch.amount[kind] or 0) + amount * times
		batch.known[kind] = (batch.known[kind] or 0) + times
	end
	if partial then
		batch.partial[kind] = (batch.partial[kind] or 0) + times
	end
end

local function Piece(batch, kind)
	local count = batch.count[kind]
	local amount = batch.known[kind] == count and batch.amount[kind] or nil
	if count == 1 then
		if batch.partial[kind] == 1 then
			return amount and ("Blocked %d of a hit"):format(amount) or "Blocked part of a hit"
		end
		return amount and ("%s %d"):format(SAID[kind], amount) or SAID[kind]
	elseif amount then
		return ("%s x%d (%d)"):format(SAID[kind], count, amount)
	end
	return ("%s x%d"):format(SAID[kind], count)
end

local function Line(batch)
	local parts = {}
	for _, kind in ipairs(KINDS) do
		if (batch.count[kind] or 0) > 0 then
			parts[#parts + 1] = Piece(batch, kind)
		end
	end
	return table.concat(parts, ", ")
end

local function Tally(batch)
	local parts = {}
	for _, kind in ipairs(KINDS) do
		local count = batch.count[kind] or 0
		if count > 0 then
			parts[#parts + 1] = ("%d %s"):format(count, NOUNS[kind][count == 1 and 1 or 2])
		end
	end
	return table.concat(parts, ", ")
end

local function Text(batch, every)
	if every == "summary" then
		return ("Last %d s: %s"):format(Seconds(), Tally(batch))
	elseif every == "fight" then
		return "Fight: " .. Tally(batch)
	end
	return Line(batch)
end

local function Send(text, to)
	local info = C_ChatInfo
	local fn = type(info) == "table" and not IsSecret(info) and info.SendChatMessage or nil
	if type(fn) ~= "function" then
		fn = _G.SendChatMessage
	end
	if type(fn) ~= "function" then
		return false, "the game gives no way to send a chat line"
	end
	local ok, err = pcall(fn, text, to)
	if not ok then
		return false, tostring(err)
	end
	return true
end

local function Out(text, now, wait, choice, stamp)
	local to = Channel(choice or Target())
	stamp = stamp or "sentAt"
	if to == nil then
		return true
	elseif to == "self" then
		print(OWN .. text)
		S.own, S[stamp], S.last, S.lastTo = S.own + 1, now, text, to
		return true
	elseif type(ns.MessagesOpen) == "function" and ns.MessagesOpen() == false then
		if wait then
			return false
		end
		S.held = S.held + 1
		return true
	end
	local ok, why = Send(text, to)
	if ok then
		S.sent, S[stamp], S.last, S.lastTo = S.sent + 1, now, text, to
	else
		S.refused, S.why = S.refused + 1, S.why or why
	end
	return true
end

local function Clear()
	S.batch, S.windowEnd, S.overAt = Empty(), nil, nil
end

local function Tick(_, elapsed)
	S.wait = (S.wait or 0) + (Finite(elapsed) and elapsed or TICK)
	if S.wait >= TICK then
		S.wait = 0
		Run(Flush)
	end
end

local function Wake(on)
	if on == (S.awake == true) then
		return
	end
	if on and not S.frame then
		local ok, frame = pcall(CreateFrame, "Frame")
		if not ok or IsSecret(frame) or type(frame) ~= "table" then
			S.unmade = true
			return
		end
		ns.Own[frame] = true
		S.frame = frame
	end
	if S.frame and pcall(S.frame.SetScript, S.frame, "OnUpdate", on and Tick or nil) then
		S.awake = on
	end
end

Flush = function()
	if not On() then
		Clear()
		Wake(false)
		return
	end
	local batch, now, every = S.batch, Now(), Every()
	if batch.n > 0 and now and (S.sentAt == nil or now - S.sentAt >= GAP) then
		if every == "each" then
			Out(Text(batch, every), now)
			S.batch = Empty()
		elseif every == "summary" then
			if S.windowEnd == nil or now >= S.windowEnd then
				Out(Text(batch, every), now)
				S.batch, S.windowEnd = Empty(), nil
			end
		elseif S.overAt and not InFight() then
			if Out(Text(batch, every), now, now - S.overAt < HOLD) then
				S.batch, S.overAt = Empty(), nil
			end
		end
	end
	Wake(S.batch.n > 0 and (every ~= "fight" or S.overAt ~= nil))
end

Run = function(fn, ...)
	if ns.PartStopped(KEY, PART) or ns.IsStopped(KEY) then
		Clear()
		pcall(Wake, false)
		return
	end
	if not ns.EachPart(KEY, PART, fn, {}, ...) and ns.PartStopped(KEY, PART) then
		Clear()
		pcall(Wake, false)
	end
end

local function Hit(_, action, flag, amount)
	if not On() then
		return
	end
	local kind, value, partial = Kind(action, flag, amount)
	if kind == nil or Opt(ROWS[kind]) ~= true then
		return
	end
	if S.roleStale then
		ReadRole()
	end
	if not S.tank or Channel(Target()) == nil then
		return
	end
	if partial then
		value = ReadBlock()
	end
	Add(S.batch, kind, value, partial)
	S.total[kind] = (S.total[kind] or 0) + 1
	if Every() == "summary" and S.windowEnd == nil then
		local now = Now()
		S.windowEnd = now and now + Seconds() or nil
	end
	Flush()
end

local function Begin()
	ReadBlock()
	if S.overAt and Every() == "fight" then
		S.held = S.held + 1
		Clear()
	end
end

local function Finish()
	ReadBlock()
	if Every() == "fight" and S.batch.n > 0 then
		S.overAt = S.overAt or Now()
	end
	Flush()
end

local function Apply()
	Clear()
	S.roleStale = true
	if On() and not InFight() then
		ReadBlock()
	end
	Wake(false)
end

local function Defensives()
	if S.defSet ~= nil then
		return S.defSet
	end
	local data, byClass, kind = ns.ABILITIES, ns.ABILITIES_BY_CLASS, nil
	for index, name in ipairs(type(ns.COOLDOWN_KINDS) == "table" and ns.COOLDOWN_KINDS or {}) do
		if name == "defensive" then
			kind = index
		end
	end
	local ok, _, class = pcall(UnitClass, "player")
	if not ok or IsSecret(class) or type(class) ~= "string" or type(data) ~= "table" or type(byClass) ~= "table" or kind == nil then
		return {}
	end
	local set = {}
	for _, group in ipairs({ class, "ALL" }) do
		for _, index in ipairs(type(byClass[group]) == "table" and byClass[group] or {}) do
			local a = data[index]
			if type(a) == "table" and a.kind == kind and Finite(a.cd) and a.cd >= DEF_LEAST and Finite(a.secs) and a.secs > 0 and type(a.casts) == "table" then
				for _, id in ipairs(a.casts) do
					set[id] = a
				end
			end
		end
	end
	S.defSet = set
	return set
end

local function DefLine(name, secs)
	return ("%s up (%d s)"):format(name, math.floor(secs + 0.5))
end

local function Used(_, _, _, spell)
	if not On() or Opt("announceDefensives") ~= true or IsSecret(spell) or type(spell) ~= "number" then
		return
	end
	local a = Defensives()[spell]
	if a == nil then
		return
	end
	if S.roleStale then
		ReadRole()
	end
	local now = Now()
	if not S.tank or now == nil or Channel(Target()) == nil or (S.defAt and now >= S.defAt and now - S.defAt < GAP) then
		return
	end
	S.defAt, S.defs = now, S.defs + 1
	Out(DefLine(a.name, a.secs), now, nil, nil, "defAt")
end

local function KickChoice()
	local choice = Opt("announceKicks")
	return TO[choice] and choice or nil
end

function ns.AnnounceKicksOn()
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and KickChoice() ~= nil
end

local function KickLine(name)
	return type(name) == "string" and name ~= "" and ("Interrupted " .. name) or "Interrupted"
end

local function Kicked(_, spell)
	local choice = ns.AnnounceKicksOn() and KickChoice()
	local now = Now()
	if not choice or now == nil or (S.kickAt and now >= S.kickAt and now - S.kickAt < GAP) or Channel(choice) == nil then
		return
	end
	local name = nil
	if Finite(spell) and type(C_Spell) == "table" then
		name = Ask(C_Spell.GetSpellName, spell)
	end
	S.kickAt, S.kicks = now, S.kicks + 1
	Out(KickLine(name), now, nil, choice, "kickAt")
end

function ns.AnnounceKick(spell)
	Run(Kicked, spell)
end

local function KickSummary()
	local choice = KickChoice()
	if not choice then
		return "Announce your interrupts: off."
	end
	local to, why = nil, nil
	if not ns.Enabled(KEY) then
		why = "Place combat numbers is off"
	elseif ns.PartStopped(KEY, PART) then
		why = "it stopped after an error, until /reload"
	else
		to, why = Channel(choice)
	end
	return ("Announce your interrupts: %s; %s. %d %s."):format(TO[choice], to and ("now to " .. PLACES[to]) or ("nothing sent now, as " .. why), S.kicks,
		S.kicks == 1 and "line" or "lines")
end

local function Reason()
	if not ns.Enabled(KEY) then
		return nil, "Place combat numbers is off"
	elseif ns.PartStopped(KEY, PART) then
		return nil, "it stopped after an error, until /reload"
	elseif Opt("announce") ~= true then
		return nil, "Announce blocks, dodges and parries is off"
	end
	local to, why = Channel(Target())
	if to == nil then
		return nil, why
	end
	ReadRole()
	if not S.tank then
		return nil, S.by and ("you do not count as a tank (%s)"):format(S.by) or "you do not count as a tank"
	end
	return to
end

local function Summary()
	local to, why = Reason()
	local line = ("Announce to your group: %s, %s; %s. %d %s sent"):format(EVERY[Every()], TO[Target()],
		to and ("now to " .. PLACES[to]) or ("nothing sent now, as " .. why), S.sent, S.sent == 1 and "line" or "lines")
	if S.own > 0 then
		line = ("%s, %d shown only to you"):format(line, S.own)
	end
	if S.held > 0 then
		line = ("%s, %d not sent while the game closed addon chat"):format(line, S.held)
	end
	if S.refused > 0 then
		line = ("%s, %d refused by the game (%s)"):format(line, S.refused, tostring(S.why))
	end
	if Opt("announceDefensives") == true then
		line = ("%s; %d %s"):format(line, S.defs, S.defs == 1 and "defensive" or "defensives")
	end
	return line .. "."
end

local function Wanted()
	local list = {}
	for _, kind in ipairs(KINDS) do
		if Opt(ROWS[kind]) == true then
			list[#list + 1] = NOUNS[kind][2]
		end
	end
	return list
end

local function Report()
	if Opt("announce") ~= true then
		print("Announce blocks, dodges and parries: off. It is under Announce to your group on the You and warnings tab of Combat text.")
	else
		print(Summary())
	end
	ReadRole()
	if S.tank then
		print(("You count as a tank (%s)."):format(S.by or "your role"))
	else
		print(S.by and ("You do not count as a tank (%s)."):format(S.by) or "You do not count as a tank.")
	end
	local kinds = Wanted()
	print(("Kinds sent: %s."):format(#kinds > 0 and table.concat(kinds, ", ") or "none, as every kind is off"))
	local counted = Empty()
	for kind, count in pairs(S.total) do
		Add(counted, kind, nil, nil, count)
	end
	print(counted.n > 0 and ("Counted this session: %s."):format(Tally(counted)) or "Counted this session: none.")
	if S.last then
		print(("Last line: %s (%s)."):format(S.last, PLACES[S.lastTo] or "chat"))
	end
	if S.unmade then
		print("The game would not make a timer frame, so a line held back waits for your next block, dodge, parry or miss.")
	end
	print(KickSummary())
	print(HELP[2])
end

local function Samples(every)
	local lines, kinds = {}, {}
	for _, kind in ipairs(KINDS) do
		if Opt(ROWS[kind]) == true then
			kinds[#kinds + 1] = kind
		end
	end
	if every == "each" then
		for _, sample in ipairs(SAMPLE_EACH) do
			if Opt(ROWS[sample[1]]) == true then
				local batch = Empty()
				Add(batch, sample[1], sample[2] or (sample[3] and (S.block or SAMPLE_BLOCK)) or nil, sample[3])
				lines[#lines + 1] = Line(batch)
			end
		end
		if kinds[1] then
			local batch = Empty()
			Add(batch, kinds[1], nil, nil, 3)
			lines[#lines + 1] = Line(batch)
		end
		return lines
	end
	local batch = Empty()
	for _, kind in ipairs(kinds) do
		Add(batch, kind, nil, nil, SAMPLE_COUNTS[every][kind])
	end
	if batch.n > 0 then
		lines[1] = Text(batch, every)
	end
	return lines
end

local function Test()
	local every = Every()
	if not InFight() then
		ReadBlock()
	end
	print(("Announce blocks, dodges and parries (%s), sample lines shown only to you, never sent:"):format(EVERY[every]))
	local lines = Samples(every)
	if #lines == 0 then
		print("  None, as every kind is off.")
	end
	for _, line in ipairs(lines) do
		print("  " .. line)
	end
	if Opt("announce") == true and Opt("announceDefensives") == true then
		local most = nil
		for _, a in pairs(Defensives()) do
			if most == nil or a.cd > most.cd then
				most = a
			end
		end
		print("  " .. DefLine(most and most.name or DEF_SAMPLE[1], most and most.secs or DEF_SAMPLE[2]))
	end
	local to, why = Reason()
	print(to and ("Now they would go to %s."):format(PLACES[to]) or ("Now nothing would be sent, as %s."):format(why))
	local choice = KickChoice()
	if choice then
		print(("Announce your interrupts (%s), a sample line shown only to you, never sent:"):format(TO[choice]))
		print("  " .. KickLine(KICK_SAMPLE))
		local kickTo, kickWhy = Channel(choice)
		print(kickTo and ("Now it would go to %s."):format(PLACES[kickTo]) or ("Now nothing would be sent, as %s."):format(kickWhy))
	end
end

function ns.AnnounceKicksChanged()
	Run(Apply)
	if type(ns.CastLandSync) == "function" then
		ns.CastLandSync()
	end
end

function ns.AnnounceInstanceUnused()
	return Opt("announce") ~= true and KickChoice() == nil
end

function ns.AnnounceChanged(path)
	Run(Apply)
	if path == KEY .. ".announce" and Opt("announce") == true and not InFight() and type(ns.PanelShown) == "function" and ns.PanelShown() == true then
		print("Announce blocks, dodges and parries: on. /flatui announce test shows sample lines in your own chat window only.")
	end
end

local function Slash(rest)
	local word = (type(rest) == "string" and rest or ""):lower():match("^%s*(%S*)") or ""
	if word == "test" then
		Test()
	elseif word == "" then
		Report()
	else
		for _, line in ipairs(HELP) do
			print(line)
		end
	end
end

ns.AddEvent(KEY, "UNIT_COMBAT", function(_, action, flag, amount)
	Run(Hit, action, flag, amount)
end, function(unit)
	return not IsSecret(unit) and unit == "player" and Opt("announce") == true
end)

ns.AddEvent(KEY, "UNIT_SPELLCAST_SUCCEEDED", function(unit, cast, spell)
	Run(Used, unit, cast, spell)
end, function(unit)
	return not IsSecret(unit) and unit == "player" and Opt("announceDefensives") == true and Opt("announce") == true
end)

ns.AddEvent(KEY, "PLAYER_ENTERING_WORLD", function()
	if ns.AnnounceKicksOn() and type(ns.CastLandSync) == "function" then
		ns.CastLandSync()
	end
end)

for _, event in ipairs(STALE_EVENTS) do
	ns.AddEvent(KEY, event, function()
		S.roleStale = true
	end)
end

ns.AddEvent(KEY, "PLAYER_REGEN_DISABLED", function()
	S.roleStale = true
	if Opt("announce") == true then
		Run(Begin)
	end
end)

ns.AddEvent(KEY, "PLAYER_REGEN_ENABLED", function()
	if Opt("announce") == true then
		Run(Finish)
	end
end)

ns.AddEvent(KEY, "PLAYER_EQUIPMENT_CHANGED", function()
	if Opt("announce") == true and not InFight() then
		Run(ReadBlock)
	end
end)

ns.AddStatus(KEY, function()
	local lines = {}
	if On() then
		lines[1] = Summary()
	end
	if ns.AnnounceKicksOn() then
		lines[#lines + 1] = KickSummary()
	end
	return lines
end)

ns.AddSlash(KEY, "announce", Slash, HELP)
