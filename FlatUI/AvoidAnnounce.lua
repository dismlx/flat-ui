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
	"/flatui announce - where Announce blocks, dodges and parries sends its lines now, or why it sends nothing",
	"/flatui announce test - sample lines in your own chat window only, never sent to the group",
}

local IsSecret, Finite = ns.IsSecret, ns.Finite

local function Empty()
	return { n = 0, count = {}, amount = {}, known = {}, partial = {} }
end

local S = { tank = false, roleStale = true, sent = 0, own = 0, held = 0, refused = 0, total = {}, batch = Empty() }

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

local function Battle()
	if type(IsInInstance) ~= "function" then
		return false
	end
	local ok, _, kind = pcall(IsInInstance)
	return ok and not IsSecret(kind) and (kind == "pvp" or kind == "arena")
end

local function Channel(to)
	if Battle() then
		return nil, "you are in a battleground or arena"
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

local function Out(text, now, wait)
	local to = Channel(Target())
	if to == nil then
		return true
	elseif to == "self" then
		print(OWN .. text)
		S.own, S.sentAt, S.last, S.lastTo = S.own + 1, now, text, to
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
		S.sent, S.sentAt, S.last, S.lastTo = S.sent + 1, now, text, to
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
	local to, why = Reason()
	print(to and ("Now they would go to %s."):format(PLACES[to]) or ("Now nothing would be sent, as %s."):format(why))
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
	if not On() then
		return {}
	end
	return { Summary() }
end)

ns.AddSlash(KEY, "announce", Slash, HELP)
