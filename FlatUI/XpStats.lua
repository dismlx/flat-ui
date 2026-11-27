local _, ns = ...

local KEY, PART = "hud", "levelling stats"
local WINDOW, MIN_PLAY = 1800, 300
local STEP, MAX_MARKS = 10, 400
local RESUME_GAP = 300
local KILLS, MIN_KILLS, QUESTS, MIN_QUESTS = 10, 3, 10, 2
local MAX_ENTRIES = 100
local VERSION, SAVED = 1, "xpSession"

local s
local quest
local queued = false
local pattern, numberAt, patternFrom

local Finite, IsSecret = ns.Finite, ns.IsSecret

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if not ok or IsSecret(value) then
		return nil
	end
	return value
end

local function Field(info, key)
	if type(info) ~= "table" or IsSecret(info) then
		return nil
	end
	local ok, value = pcall(function()
		return info[key]
	end)
	if not ok or IsSecret(value) then
		return nil
	end
	return value
end

local function Now()
	local now = Ask(GetTime)
	return Finite(now) and now or nil
end

local function Safe(fn, ...)
	local out
	ns.EachPart(KEY, PART, function(_, ...)
		out = fn(...)
	end, {}, ...)
	return out
end

local function Rest()
	local pool = Ask(GetXPExhaustion)
	local rate
	if type(GetRestState) == "function" then
		local ok, _, _, factor = pcall(GetRestState)
		if ok and Finite(factor) and factor > 1 then
			rate = factor
		end
	end
	return Finite(pool) and math.max(pool, 0) or 0, rate or 2
end

local function Fresh(now)
	return { v = VERSION, started = now, savedAt = now, away = 0, gained = 0, marks = {}, spent = 0, unseen = 0 }
end

local SETTLE = 2

local function Pool()
	local pool, now = Rest(), Now() or 0
	local was = Finite(s.pool) and s.pool or pool
	if s.settleBy and now > s.settleBy then
		s.spent, s.unseen, s.settleBy = 0, 0, nil
	end
	if pool > was then
		s.spent, s.unseen = 0, 0
	else
		local matched = math.min(was - pool, s.spent)
		s.spent, s.unseen = s.spent - matched, s.unseen + (was - pool) - matched
		if s.unseen > 0 then
			s.settleBy = now + SETTLE
		end
	end
	s.pool = pool
end

local function Count(list)
	local out = {}
	if type(list) == "table" then
		for _, value in ipairs(list) do
			if Finite(value) and value > 0 then
				out[#out + 1] = value
			end
		end
	end
	return out
end

local function Kept(saved, now)
	if type(saved) ~= "table" or saved.v ~= VERSION then
		return nil
	end
	for _, key in ipairs({ "started", "savedAt", "away", "gained" }) do
		if not Finite(saved[key]) then
			return nil
		end
	end
	local gap = now - saved.savedAt
	if gap < 0 or gap > RESUME_GAP or saved.started > saved.savedAt or saved.away < 0 or saved.gained < 0 or type(saved.marks) ~= "table"
		or #saved.marks > MAX_MARKS then
		return nil
	end
	for _, mark in ipairs(saved.marks) do
		if type(mark) ~= "table" or not Finite(mark[1]) or not Finite(mark[2]) then
			return nil
		end
	end
	local last = saved.last
	if not (type(last) == "table" and Finite(last[1]) and Finite(last[2]) and Finite(last[3])) then
		saved.last = nil
	end
	if not Finite(saved.levelSince) then
		saved.levelSince = nil
	end
	if not Finite(saved.saidLevel) then
		saved.saidLevel = nil
	end
	local played = saved.played
	if not (type(played) == "table" and Finite(played.level) and Finite(played.at) and Finite(played.seconds)) then
		saved.played = nil
	end
	local kills = saved.kills
	if type(kills) == "table" and Finite(kills.level) and Finite(kills.group) then
		kills.list = Count(kills.list)
	else
		saved.kills = nil
	end
	saved.quests = { list = Count(type(saved.quests) == "table" and saved.quests.list or nil) }
	local rep = saved.rep
	local whole = type(rep) == "table" and Finite(rep.id) and Finite(rep.at) and Finite(rep.started) and Finite(rep.gained) and rep.gained >= 0
		and type(rep.marks) == "table" and #rep.marks <= MAX_MARKS
	for _, mark in ipairs(whole and rep.marks or {}) do
		whole = whole and type(mark) == "table" and Finite(mark[1]) and Finite(mark[2])
	end
	if not whole then
		saved.rep = nil
	end
	local open = Finite(saved.awaySince) and math.max(0, saved.savedAt - saved.awaySince) or 0
	saved.away, saved.awaySince = saved.away + open + gap, nil
	saved.pool, saved.spent, saved.unseen, saved.settleBy = nil, 0, 0, nil
	saved.resumed = true
	return saved
end

local function Play(now)
	local away = s.away + (s.awaySince and math.max(0, now - s.awaySince) or 0)
	return math.max(0, now - s.started - away)
end

local function Gain(now, amount)
	s.gained = s.gained + amount
	s.savedAt = now
	local play, marks = Play(now), s.marks
	local last = marks[#marks]
	if last and play - last[1] < STEP then
		last[2] = s.gained
	else
		marks[#marks + 1] = { play, s.gained }
	end
	while #marks > 1 and marks[2][1] <= play - WINDOW do
		table.remove(marks, 1)
	end
	while #marks > MAX_MARKS do
		table.remove(marks, 1)
	end
end

local LevelLine

local function Read()
	if not s or type(UnitXP) ~= "function" or type(UnitXPMax) ~= "function" then
		return
	end
	Pool()
	local level, value, total = Ask(UnitLevel, "player"), Ask(UnitXP, "player"), Ask(UnitXPMax, "player")
	local now = Now()
	if not (now and Finite(level) and Finite(value) and Finite(total)) or total <= 0 or value < 0 then
		return
	end
	local last = s.last
	if last and ((level > last[1] and value == last[2]) or (level == last[1] and value < last[2])) then
		return
	end
	s.last = { level, value, total }
	if not last then
		return
	end
	local gain = 0
	if level == last[1] then
		gain = value - last[2]
	elseif level > last[1] then
		gain = math.max(last[3] - last[2], 0) + value
		local before = { level = last[1], since = s.levelSince, played = s.played }
		s.levelSince, s.played, s.kills = now, nil, nil
		LevelLine(level, before, now)
	else
		s.levelSince, s.played, s.kills = nil, nil, nil
	end
	if gain > 0 then
		Gain(now, gain)
	end
end

local function Away()
	local now = Now()
	local away = Ask(UnitIsAFK, "player")
	if not s or not now then
		return
	end
	if away ~= true and away ~= false then
		away = false
	end
	if away and not s.awaySince then
		s.awaySince = now
	elseif not away and s.awaySince then
		s.away = s.away + math.max(0, now - s.awaySince)
		s.awaySince = nil
	end
end

local function Begin()
	local now, char = Now(), ns.Character()
	if not now or s then
		return
	end
	local saved = type(char) == "table" and char[SAVED] or nil
	s = Kept(saved, now) or Fresh(now)
	if type(char) == "table" then
		char[SAVED] = nil
	end
	s.pool = Rest()
	Away()
	Read()
end

local function Save()
	local now, char = Now(), ns.Character()
	if s and now and s.last and type(char) == "table" then
		s.savedAt = now
		char[SAVED] = s
	end
end

local function KillPattern()
	local format = _G.COMBATLOG_XPGAIN_FIRSTPERSON
	if IsSecret(format) or type(format) ~= "string" or format == "" then
		return nil
	end
	if format ~= patternFrom then
		patternFrom, pattern, numberAt = format, nil, nil
		local text = format:gsub("%%%%", "\3")
		local index = 0
		for kind in text:gmatch("%%%d*%$?([sd])") do
			index = index + 1
			if kind == "d" and not numberAt then
				numberAt = index
			end
		end
		text = text:gsub("%%%d*%$?s", "\1"):gsub("%%%d*%$?d", "\2")
		text = text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
		text = text:gsub("\1", "(.-)"):gsub("\2", "(%%d+)"):gsub("\3", "%%%%")
		if numberAt then
			pattern = "^" .. text
		end
	end
	return pattern, numberAt
end

local function Kill(text)
	if not s or IsSecret(text) or type(text) ~= "string" then
		return
	end
	local find, at = KillPattern()
	if not find then
		return
	end
	local total = tonumber(({ text:match(find) })[at])
	local level, group = Ask(UnitLevel, "player"), Ask(GetNumGroupMembers) or 0
	if not total or total <= 0 or not Finite(level) or not Finite(group) then
		return
	end
	local kills = s.kills
	if type(kills) ~= "table" or kills.level ~= level or kills.group ~= group then
		kills = { level = level, group = group, list = {} }
		s.kills = kills
	end
	Pool()
	local _, rate = Rest()
	local share = total * (rate - 1) / rate
	local before = math.max(0, s.pool + s.unseen - s.spent)
	local bonus = math.min(before, share)
	local explained = math.min(s.unseen, bonus)
	s.unseen, s.spent = s.unseen - explained, s.spent + bonus - explained
	if s.spent > 0 then
		s.settleBy = (Now() or 0) + SETTLE
	end
	local list = kills.list
	list[#list + 1] = total - bonus
	while #list > KILLS do
		table.remove(list, 1)
	end
end

local function Group()
	if not (s and type(s.kills) == "table") then
		return false
	end
	local group = Ask(GetNumGroupMembers) or 0
	if Finite(group) and group ~= s.kills.group then
		s.kills = nil
		return true
	end
	return false
end

local handedIn = {}

local function TurnedIn(id, xp)
	local entry = Finite(id) and quest and quest.ids and quest.ids[id] or nil
	if entry then
		handedIn[id] = true
		quest.ids[id] = nil
		quest.all, quest.allXP = quest.all - 1, quest.allXP - entry.xp
		if entry.ready then
			quest.ready, quest.readyXP = quest.ready - 1, quest.readyXP - entry.xp
		end
	end
	if not s or not Finite(xp) or xp <= 0 then
		return
	end
	local list = s.quests and s.quests.list or {}
	s.quests = { list = list }
	list[#list + 1] = xp
	while #list > QUESTS do
		table.remove(list, 1)
	end
end

local function Played(_, thisLevel)
	local now, level = Now(), Ask(UnitLevel, "player")
	if s and now and Finite(thisLevel) and thisLevel >= 0 and Finite(level) then
		s.played = { level = level, at = now, seconds = thisLevel }
	end
end

local function QuestCalls()
	local log = _G.C_QuestLog
	return type(log) == "table" and not IsSecret(log) and type(log.GetNumQuestLogEntries) == "function" and type(log.GetInfo) == "function"
		and type(log.IsComplete) == "function" and type(_G.GetQuestLogRewardXP) == "function"
end

local function Levelling()
	return ns.XpBarShowsXp == nil or ns.XpBarShowsXp() == true
end

local function Scan()
	queued = false
	if not (ns.XpOwn and ns.XpOwn()) or not Levelling() then
		quest = nil
		return
	end
	if not QuestCalls() then
		quest = { missing = true }
		return
	end
	local log = _G.C_QuestLog
	local count = Ask(log.GetNumQuestLogEntries)
	local found, seen = { ready = 0, readyXP = 0, all = 0, allXP = 0, ids = {} }, {}
	for index = 1, Finite(count) and math.min(count, MAX_ENTRIES) or 0 do
		local info = Ask(log.GetInfo, index)
		local id = Field(info, "questID")
		if info and Field(info, "isHeader") ~= true and Field(info, "isHidden") ~= true and Field(info, "isTask") ~= true and Field(info, "isBounty") ~= true
			and Finite(id) and id > 0 and not seen[id] and not handedIn[id] then
			seen[id] = true
			local xp = Ask(_G.GetQuestLogRewardXP, id)
			xp = Finite(xp) and math.max(xp, 0) or 0
			local ready = Ask(log.IsComplete, id) == true
			found.ids[id] = { xp = xp, ready = ready }
			found.all, found.allXP = found.all + 1, found.allXP + xp
			if ready then
				found.ready, found.readyXP = found.ready + 1, found.readyXP + xp
			end
		end
	end
	quest = found
end

local function Redraw()
	if ns.XpBarRedraw and ns.Enabled(KEY) then
		ns.Try(KEY, ns.XpBarRedraw)
	end
end

local function Look()
	queued = false
	Safe(Scan)
	Redraw()
end

local function Queue()
	if queued or not s or not (ns.XpOwn and ns.XpOwn()) or type(_G.C_QuestLog) ~= "table" then
		return
	end
	queued = true
	local after = type(C_Timer) == "table" and C_Timer.After or nil
	if type(after) ~= "function" or not pcall(after, 0, Look) then
		Look()
	end
end

local function Remaining()
	local last = s and s.last
	return last and math.max(last[3] - last[2], 0) or nil
end

local function Pace(now)
	local play = Play(now)
	if play < MIN_PLAY then
		return nil, play
	end
	local from, base = math.max(0, play - WINDOW), 0
	if from > 0 then
		for _, mark in ipairs(s.marks) do
			if mark[1] <= from then
				base = mark[2]
			else
				break
			end
		end
	end
	return math.max(0, s.gained - base) * 3600 / (play - from), play
end

local function Average(list)
	local sum = 0
	for _, value in ipairs(list) do
		sum = sum + value
	end
	return #list > 0 and sum / #list or 0
end

local function KillsToLevel(remaining)
	local list = s.kills and s.kills.list
	if not remaining or remaining <= 0 or type(list) ~= "table" or #list < MIN_KILLS then
		return nil
	end
	local base = Average(list)
	if base <= 0 then
		return nil
	end
	local pool, rate = Rest()
	local kills
	if pool > 0 then
		local cover = pool * rate / (rate - 1)
		if remaining <= cover then
			kills = remaining / (rate * base)
		else
			kills = pool / ((rate - 1) * base) + (remaining - cover) / base
		end
	else
		kills = remaining / base
	end
	return math.max(1, math.ceil(kills - 1e-9)), base, pool > 0 and rate or nil
end

local function QuestsToLevel(remaining)
	local list = s.quests and s.quests.list
	if not remaining or remaining <= 0 or type(list) ~= "table" or #list < MIN_QUESTS then
		return nil
	end
	local each = Average(list)
	if each <= 0 then
		return nil
	end
	return math.max(1, math.ceil(remaining / each - 1e-9)), each
end

local function Spent(level, played, since, now)
	if type(played) == "table" and level and played.level == level then
		return played.seconds + math.max(0, now - played.at)
	elseif since then
		return math.max(0, now - since)
	end
	return nil
end

local function LevelTime(now)
	return Spent(s.last and s.last[1], s.played, s.levelSince, now)
end

local function Numbers()
	local now = Now()
	if not s or not now then
		return nil
	end
	local n = { gained = s.gained, remaining = Remaining() }
	n.pace, n.play = Pace(now)
	if n.pace and n.pace > 0 and n.remaining and n.remaining > 0 then
		n.eta = n.remaining * 3600 / n.pace
	end
	n.kills, n.perKill, n.restRate = KillsToLevel(n.remaining)
	n.quests, n.perQuest = QuestsToLevel(n.remaining)
	n.levelTime = LevelTime(now)
	if quest and not quest.missing then
		n.ready, n.readyXP, n.all, n.allXP = quest.ready, quest.readyXP, quest.all, quest.allXP
	end
	return n
end

local function Grouped(value)
	value = math.floor(value + 0.5)
	if type(BreakUpLargeNumbers) == "function" then
		local ok, text = pcall(BreakUpLargeNumbers, value)
		if ok and type(text) == "string" and not IsSecret(text) and text ~= "" then
			return text
		end
	end
	return tostring(value)
end

local function Plain(value)
	return tostring(math.floor(value + 0.5))
end

local function Duration(seconds, up)
	local minutes = up and math.max(1, math.ceil(seconds / 60 - 1e-9)) or math.floor(seconds / 60)
	if minutes < 60 then
		return ("%dm"):format(minutes)
	end
	local hours, rest = math.floor(minutes / 60), minutes % 60
	if hours < 24 then
		return rest > 0 and ("%dh %dm"):format(hours, rest) or ("%dh"):format(hours)
	end
	local days, left = math.floor(hours / 24), hours % 24
	return left > 0 and ("%dd %dh"):format(days, left) or ("%dd"):format(days)
end

local function Elapsed(seconds)
	return seconds < 60 and "under a minute" or Duration(seconds)
end

local function Quests(count)
	return count == 1 and "1 quest" or ("%d quests"):format(count)
end

LevelLine = function(level, before, now)
	if Opt("xpLevelLine") ~= true or not (ns.XpOwn and ns.XpOwn()) or (Finite(s.saidLevel) and s.saidLevel >= level) then
		return
	end
	s.saidLevel = level
	local took = Spent(before.level, before.played, before.since, now)
	local play = ("%s of play this session"):format(Elapsed(Play(now)))
	if took then
		print(("Flat UI: level %d, after %s at level %d (%s)."):format(level, Elapsed(took), before.level, play))
	else
		print(("Flat UI: level %d (%s)."):format(level, play))
	end
end

local function Text(mode)
	local n = Numbers()
	if not n or mode == "none" then
		return nil
	end
	local time = n.eta and (Duration(n.eta, true) .. " to level") or nil
	local rate = n.pace and n.pace > 0 and (Grouped(n.pace) .. " an hour") or nil
	if mode == "time" then
		return time
	elseif mode == "rate" then
		return rate
	elseif mode == "both" then
		return (time and rate) and (time .. ", " .. rate) or time or rate
	elseif mode == "kills" and n.kills then
		return n.kills == 1 and "1 kill to level" or ("%d kills to level"):format(n.kills)
	end
	return nil
end

local function Lines(quests, numbers)
	local lines = {}
	local n = Numbers()
	if not n then
		return lines
	end
	local ready = quests and n.readyXP or 0
	if quests and n.all then
		if n.ready > 0 then
			local enough = n.remaining and n.readyXP > 0 and n.readyXP >= n.remaining
			lines[#lines + 1] = ("Ready to hand in: %s, %s experience%s"):format(Quests(n.ready), Grouped(n.readyXP), enough and " (enough to level)" or "")
		end
		if n.all > 0 then
			lines[#lines + 1] = ("In your log: %s, %s experience"):format(Quests(n.all), Grouped(n.allXP))
		end
	end
	if not numbers then
		return lines
	end
	if n.gained > 0 then
		lines[#lines + 1] = ("This session: %s experience in %s"):format(Grouped(n.gained), Elapsed(n.play))
	end
	if not n.pace then
		lines[#lines + 1] = ("Experience per hour: after %d minutes of play"):format(MIN_PLAY / 60)
	elseif n.pace <= 0 then
		lines[#lines + 1] = "Experience per hour: none lately"
	else
		lines[#lines + 1] = ("Experience per hour: %s (%s)"):format(Grouped(n.pace), n.play > WINDOW and ("the last %d minutes"):format(WINDOW / 60) or "this session")
	end
	if n.eta then
		local line = "Time to level: " .. Duration(n.eta, true)
		if ready > 0 and ready < n.remaining then
			line = line .. (", %s with your quests handed in"):format(Duration((n.remaining - ready) * 3600 / n.pace, true))
		end
		lines[#lines + 1] = line
	end
	if n.kills then
		lines[#lines + 1] = ("Kills to level: about %d (%s a kill%s)"):format(n.kills, Grouped(n.perKill), n.restRate and (", %s while rested"):format(Grouped(n.perKill * n.restRate)) or "")
	end
	if n.quests then
		lines[#lines + 1] = ("Quests to level: about %d (%s a quest)"):format(n.quests, Grouped(n.perQuest))
	end
	if n.levelTime then
		lines[#lines + 1] = "Time at this level: " .. Elapsed(n.levelTime)
	end
	return lines
end

local function Track()
	if not s or ns.XpRepNow == nil then
		return nil
	end
	local id, at, toGo, name = ns.XpRepNow()
	local now = Now()
	if not (Finite(id) and Finite(at) and now) then
		return nil
	end
	local play, r = Play(now), s.rep
	if type(r) ~= "table" or r.id ~= id or at < r.at then
		r = { id = id, at = at, started = play, gained = 0, marks = {} }
		s.rep = r
	elseif at > r.at then
		r.at, r.gained = at, r.gained + (at - r.at)
		local marks = r.marks
		local last = marks[#marks]
		if last and play - last[1] < STEP then
			last[2] = r.gained
		else
			marks[#marks + 1] = { play, r.gained }
		end
		while #marks > 1 and marks[2][1] <= play - WINDOW do
			table.remove(marks, 1)
		end
		while #marks > MAX_MARKS do
			table.remove(marks, 1)
		end
	end
	return r, play, toGo, name
end

local function RepPace(r, play)
	local span = math.max(0, play - r.started)
	if span < MIN_PLAY then
		return nil, span
	end
	local from, base = math.max(r.started, play - WINDOW), 0
	if from > r.started then
		for _, mark in ipairs(r.marks) do
			if mark[1] <= from then
				base = mark[2]
			else
				break
			end
		end
	end
	return math.max(0, r.gained - base) * 3600 / (play - from), span
end

local function RepNumbers()
	local r, play, toGo, name = Track()
	if not r or not toGo then
		return nil
	end
	local n = { gained = r.gained, toGo = toGo, name = type(name) == "string" and name or "the faction" }
	n.pace, n.play = RepPace(r, play)
	if n.pace and n.pace > 0 and toGo > 0 then
		n.eta = toGo * 3600 / n.pace
	end
	return n
end

local function RepText(mode)
	local n = RepNumbers()
	if not n or mode == "none" then
		return nil
	end
	local time = n.eta and (Duration(n.eta, true) .. " to next standing") or nil
	local rate = n.pace and n.pace > 0 and (Grouped(n.pace) .. " an hour") or nil
	if mode == "time" then
		return time
	elseif mode == "rate" then
		return rate
	elseif mode == "both" then
		return (time and rate) and (time .. ", " .. rate) or time or rate
	end
	return nil
end

local function RepLines()
	local lines = {}
	local n = RepNumbers()
	if not n then
		return lines
	end
	if n.gained > 0 then
		lines[#lines + 1] = ("This session: %s reputation in %s"):format(Grouped(n.gained), Elapsed(n.play))
	end
	if not n.pace then
		lines[#lines + 1] = ("Reputation per hour: after %d minutes of play"):format(MIN_PLAY / 60)
	elseif n.pace <= 0 then
		lines[#lines + 1] = "Reputation per hour: none lately"
	else
		lines[#lines + 1] = ("Reputation per hour: %s (%s)"):format(Grouped(n.pace), n.play > WINDOW and ("the last %d minutes"):format(WINDOW / 60) or "this session")
	end
	if n.eta then
		lines[#lines + 1] = "Next standing in: " .. Duration(n.eta, true)
	end
	return lines
end

local function StatusLines()
	local lines = {}
	if not (ns.XpOwn and ns.XpOwn()) or not s or not s.last or not Levelling() then
		return lines
	end
	local n = Numbers()
	if n and n.gained > 0 then
		local line = ("Experience bar: %s experience this session, in %s of play"):format(Plain(n.gained), Elapsed(n.play))
		if n.pace and n.pace > 0 then
			line = line .. (", %s an hour"):format(Plain(n.pace))
		end
		lines[#lines + 1] = line .. (s.resumed and ". It went on after a reload." or ".")
	end
	if Opt("xpQuest") == true then
		if not QuestCalls() then
			lines[#lines + 1] = "Experience bar: this client gives no experience for the quests in the log, so Quests ready to hand in shows nothing."
		elseif quest and not quest.missing and quest.all > 0 and quest.allXP == 0 then
			lines[#lines + 1] = ("Experience bar: the game gave no experience for any of the %d quests in your log."):format(quest.all)
		end
	end
	local kills = Opt("xpStats") == "kills" or (Opt("xpStatsTip") == true and Opt("xpTooltip") == true)
	if kills and not KillPattern() then
		lines[#lines + 1] = "Experience bar: this client has no kill line to read, so kills to level are not counted."
	end
	return lines
end

function ns.XpStatsText(mode)
	return Safe(Text, mode)
end

function ns.XpStatsLines(quests, numbers)
	return Safe(Lines, quests, numbers) or {}
end

function ns.XpStatsRepText(mode)
	return Safe(RepText, mode)
end

function ns.XpStatsRepLines()
	return Safe(RepLines) or {}
end

function ns.XpQuestReady()
	return Safe(function()
		return quest and not quest.missing and quest.readyXP or 0
	end) or 0
end

function ns.XpStatsRefresh()
	Safe(Queue)
end

local function ForPlayer(unit)
	return not IsSecret(unit) and unit == "player"
end

local function Listen(event, fn, filter)
	ns.AddEvent(KEY, event, function(...)
		Safe(fn, ...)
	end, filter)
end

Listen("PLAYER_ENTERING_WORLD", function()
	if Ask(UnitIsAFK, "player") ~= nil then
		Away()
	end
	Read()
	Queue()
end)
Listen("PLAYER_XP_UPDATE", Read, ForPlayer)
Listen("UNIT_LEVEL", function()
	Read()
	Queue()
end, ForPlayer)
Listen("PLAYER_LEVEL_UP", function()
	Read()
	Queue()
end)
Listen("UPDATE_EXHAUSTION", function()
	if s then
		Pool()
	end
end)
Listen("CHAT_MSG_COMBAT_XP_GAIN", function(text)
	Kill(text)
	Redraw()
end)
Listen("QUEST_TURNED_IN", function(id, xp)
	TurnedIn(id, xp)
	Redraw()
end)
for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_DATA_LOAD_RESULT" }) do
	Listen(event, Queue)
end
Listen("QUEST_ACCEPTED", function()
	handedIn = {}
	Queue()
end)
Listen("QUEST_REMOVED", function(id)
	if Finite(id) then
		handedIn[id] = nil
	end
	Queue()
end)
Listen("GROUP_ROSTER_UPDATE", function()
	if Group() then
		Redraw()
	end
end)
Listen("PLAYER_FLAGS_CHANGED", function()
	Away()
	Redraw()
end, ForPlayer)
Listen("TIME_PLAYED_MSG", Played)
Listen("PLAYER_LOGOUT", Save)
ns.AddStart(KEY, function()
	Safe(Begin)
	Safe(Queue)
end)

local function Reset()
	local now = Now()
	if not s or not now then
		return false
	end
	local kept = { last = s.last, levelSince = s.levelSince, played = s.played, kills = s.kills, quests = s.quests, pool = s.pool,
		saidLevel = s.saidLevel }
	s = Fresh(now)
	for key, value in pairs(kept) do
		s[key] = value
	end
	Away()
	return true
end

local function Say(text)
	print("Flat UI: " .. text)
end

function ns.XpStatsReset()
	if Safe(Reset) then
		Redraw()
		return true
	end
	return false
end

local function Slash(rest)
	if not ns.Enabled(KEY) then
		Say("the levelling numbers need Restyle the minimap and HUD on (Minimap page).")
		return
	end
	local word = type(rest) == "string" and rest:lower():match("^%s*(%S*)") or ""
	if word == "reset" then
		if ns.XpStatsReset() then
			Say("the experience and reputation count starts again now.")
		else
			Say("the experience and reputation count starts with the next login.")
		end
		return
	end
	local n = Safe(Numbers)
	if not n then
		Say("no experience counted yet.")
		return
	end
	local line = n.gained > 0 and ("%s experience this session, in %s of play"):format(Plain(n.gained), Elapsed(n.play)) or "no experience this session yet"
	if n.pace and n.pace > 0 then
		line = line .. (", %s an hour"):format(Plain(n.pace))
	end
	Say(line .. ".")
	local parts = {}
	if n.eta then
		parts[#parts + 1] = Duration(n.eta, true) .. " to level at this pace"
	end
	if n.kills then
		parts[#parts + 1] = ("about %d %s"):format(n.kills, n.kills == 1 and "kill" or "kills")
	end
	if n.quests then
		parts[#parts + 1] = ("about %s"):format(Quests(n.quests))
	end
	if #parts > 0 then
		Say(table.concat(parts, ", ") .. ".")
	end
	if n.ready and n.ready > 0 then
		Say(("ready to hand in: %s, %s experience."):format(Quests(n.ready), Plain(n.readyXP)))
	end
	local rep = Safe(RepNumbers)
	if rep then
		local said = rep.gained > 0 and ("%s reputation with %s in %s of play"):format(Plain(rep.gained), rep.name, Elapsed(rep.play))
			or ("no reputation with %s yet"):format(rep.name)
		if rep.pace and rep.pace > 0 then
			said = said .. (", %s an hour"):format(Plain(rep.pace))
		end
		if rep.eta then
			said = said .. (", %s to the next standing"):format(Duration(rep.eta, true))
		end
		Say(said .. ".")
	end
end

ns.AddSlash(KEY, "xp", Slash, { "/flatui xp - experience and reputation this session, their pace and the time to level and to the next standing",
	"/flatui xp reset - count this session from now" })
ns.AddStatus(KEY, function()
	return Safe(StatusLines) or {}
end)

ns.XpStatsNumbers = function()
	return Safe(Numbers)
end
