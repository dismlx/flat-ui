local _, ns = ...

-- The levelling numbers of Flat UI's own experience bar, which XpBar.lua draws: the experience of this session and the pace, the time to the next
-- level, about how many kills and quests that takes, the time at this level, and the experience of the quests in the log. A helper of the hud
-- module, as XpBar.lua is: its events come with ns.AddEvent and each one runs inside ns.EachPart, so a fault stops this part alone and the bar
-- draws on without its numbers.
--
-- The session starts when the module starts, and goes on when the module starts again within RESUME_GAP seconds of the last save, as after a
-- reload: the gap counts as time away. Every gain of experience counts, rested and group bonuses with it, from two plain reads of UnitLevel,
-- UnitXP and UnitXPMax, the calls the game's own bar reads (ExpBar.lua:18-25): at one level the difference, over a level up what was left of the
-- old level and the new value. A withheld read counts nothing and the next plain one counts the gap. The pace is the experience of the last
-- WINDOW seconds of play, or of the whole session while it is shorter, and is given after MIN_PLAY seconds of play; time flagged away
-- (UnitIsAFK) is left out. A level up starts the time at this level and the kill count again, and leaves the pace alone.
-- Kills come from the game's kill line, CHAT_MSG_COMBAT_XP_GAIN in the form of COMBATLOG_XPGAIN_FIRSTPERSON, whose number is the whole gain. The
-- base of a kill is that number without the rested bonus, which the game takes from the rested pool (GetXPExhaustion), up to the base of the kill.
-- Kills to level spends what is left of the pool first. The count starts again at a new level or a new size of group. Quests come from
-- QUEST_TURNED_IN, whose second value is the experience the game gave. The quests ready to hand in are those of the log that C_QuestLog.IsComplete
-- calls done, as the game's own log marks them (QuestMapFrame.lua:2097), each with GetQuestLogRewardXP(questID).
-- Nothing of the game's is written or hooked and no frame is made here. The played time is never asked for, since RequestTimePlayed prints two
-- lines in every chat window (ChatFrameUtil.lua:184-196): the time at this level is known after a level up, or after a /played of the player's own.
-- These follow EnhanceQoL's experience bar by Philipp Barth, adapted with his permission.

local KEY, PART = "hud", "levelling stats"
-- Seconds of play the pace is taken over, and before it is given.
local WINDOW, MIN_PLAY = 1800, 300
-- Gains closer together than this are one mark of the session; marks kept at most.
local STEP, MAX_MARKS = 10, 400
-- Seconds from the last save within which a new start goes on with the session.
local RESUME_GAP = 300
-- Kills and quests averaged, and how many are needed for a guess.
local KILLS, MIN_KILLS, QUESTS, MIN_QUESTS = 10, 3, 10, 2
-- Lines of the quest log read at most: 20 quests and their headers fit many times over.
local MAX_ENTRIES = 100
local VERSION, SAVED = 1, "xpSession"

-- s: the session, { v, started, savedAt, away, awaySince, gained, marks = { { play, gained } }, last = { level, value, total }, levelSince,
-- played = { level, at, seconds }, kills = { level, group, list }, quests = { list }, pool, resumed }. In memory while the module runs, and in
-- FlatUICharDB.xpSession from the logout or reload on, until the next start reads it.
local s
-- What the last look at the quest log found: { ready, readyXP, all, allXP }, or { missing = true } on a client without the calls.
local quest
local queued = false
-- The kill line as a Lua pattern, the place of its number among the captures, and the format both were made from.
local pattern, numberAt, patternFrom

local Finite, IsSecret = ns.Finite, ns.IsSecret

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- The first value of a call that may be missing, raise or be withheld; nil then.
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

-- A field of a table the game gave, or nil when the read raises or the value is withheld.
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

-- Runs fn as this part: a fault is counted by ns.EachPart, and three stop the part alone. fn's first value comes back, or nil.
local function Safe(fn, ...)
	local out
	ns.EachPart(KEY, PART, function(_, ...)
		out = fn(...)
	end, {}, ...)
	return out
end

-- The rested pool, 0 when the game does not say, and the rate of a rested kill (2 for the game's 200%).
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

-- Session ---------------------------------------------------------------------------------------------------------------------------------

local function Fresh(now)
	return { v = VERSION, started = now, savedAt = now, away = 0, gained = 0, marks = {} }
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

-- The saved session when it may go on: well formed, and saved RESUME_GAP seconds ago or less by this computer's clock. The gap, and an away
-- span open at the save, become time away.
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
	local open = Finite(saved.awaySince) and math.max(0, saved.savedAt - saved.awaySince) or 0
	saved.away, saved.awaySince = saved.away + open + gap, nil
	saved.pool = nil
	saved.resumed = true
	return saved
end

-- Seconds of play in the session: the time since it started, less the time away.
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
	-- The last mark at or before the start of the window stays: it holds the experience of the session then.
	while #marks > 1 and marks[2][1] <= play - WINDOW do
		table.remove(marks, 1)
	end
	while #marks > MAX_MARKS do
		table.remove(marks, 1)
	end
end

-- A plain read of the level and the experience, and what it adds to the session.
local function Read()
	if not s then
		return
	end
	local level, value, total = Ask(UnitLevel, "player"), Ask(UnitXP, "player"), Ask(UnitXPMax, "player")
	local now = Now()
	if not (now and Finite(level) and Finite(value) and Finite(total)) or total <= 0 or value < 0 then
		return
	end
	local last = s.last
	if last and ((level > last[1] and value == last[2]) or (level == last[1] and value < last[2])) then
		-- Half of a level up: the level has turned and the value not yet, or the value has and the level not yet. The next read has both.
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
		-- What was left of the old level, then the new value. A jump of more than one level leaves the levels between out.
		gain = math.max(last[3] - last[2], 0) + value
		s.levelSince, s.played, s.kills = now, nil, nil
	else
		s.levelSince, s.played, s.kills = nil, nil, nil
	end
	if gain > 0 then
		Gain(now, gain)
	end
end

-- The away flag: a span opens when the game flags the player away and closes when it takes the flag off. A withheld answer (UnitIsAFK is secret
-- in a dungeon, a raid or a battleground) opens nothing and closes a span opened outside: a change of the flags there means the player acted.
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
	-- The saved copy is read once: the next one is written at the logout or reload.
	if type(char) == "table" then
		char[SAVED] = nil
	end
	s.pool = Rest()
	Away()
	Read()
end

-- The session as it stands, kept for the reload. Nothing is written for a session that never read the experience.
local function Save()
	local now, char = Now(), ns.Character()
	if s and now and s.last and type(char) == "table" then
		s.savedAt = now
		char[SAVED] = s
	end
end

-- Kills -----------------------------------------------------------------------------------------------------------------------------------

-- The game's kill line as a Lua pattern anchored at the start, and the place of its number among the captures. The forms of the line with a
-- bonus or a penalty (rested, group, raid) start with the same sentence, so one pattern finds them all. Nil for a client without the format.
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
	local pool, rate = Rest()
	local share = total * (rate - 1) / rate
	local bonus = 0
	if pool > 0 then
		-- The pool lasted the whole kill, so the bonus was the base of the kill.
		bonus = share
	elseif Finite(s.pool) and s.pool > 0 then
		-- The kill used up what was left of the pool.
		bonus = math.min(s.pool, share)
	end
	s.pool = pool
	local list = kills.list
	list[#list + 1] = total - bonus
	while #list > KILLS do
		table.remove(list, 1)
	end
end

local function Group()
	local group = Ask(GetNumGroupMembers) or 0
	if s and type(s.kills) == "table" and Finite(group) and group ~= s.kills.group then
		s.kills = nil
	end
end

local function TurnedIn(_, xp)
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

-- The time at this level from /played, whoever typed it.
local function Played(_, thisLevel)
	local now, level = Now(), Ask(UnitLevel, "player")
	if s and now and Finite(thisLevel) and thisLevel >= 0 and Finite(level) then
		s.played = { level = level, at = now, seconds = thisLevel }
	end
end

-- The quest log ------------------------------------------------------------------------------------------------------------------------------

local function QuestCalls()
	local log = _G.C_QuestLog
	return type(log) == "table" and not IsSecret(log) and type(log.GetNumQuestLogEntries) == "function" and type(log.GetInfo) == "function"
		and type(log.IsComplete) == "function" and type(_G.GetQuestLogRewardXP) == "function"
end

-- The quests of the log: headers and hidden lines are left out, and a quest that shows twice counts once. Collapsed headers keep their quests in
-- the list (QuestMapFrame.lua:1586-1592, 1627-1637).
local function Scan()
	queued = false
	if not (ns.XpOwn and ns.XpOwn()) then
		return
	end
	if not QuestCalls() then
		quest = { missing = true }
		return
	end
	local log = _G.C_QuestLog
	local count = Ask(log.GetNumQuestLogEntries)
	local found, seen = { ready = 0, readyXP = 0, all = 0, allXP = 0 }, {}
	for index = 1, Finite(count) and math.min(count, MAX_ENTRIES) or 0 do
		local info = Ask(log.GetInfo, index)
		local id = Field(info, "questID")
		if info and Field(info, "isHeader") ~= true and Field(info, "isHidden") ~= true and Finite(id) and id > 0 and not seen[id] then
			seen[id] = true
			local xp = Ask(_G.GetQuestLogRewardXP, id)
			xp = Finite(xp) and math.max(xp, 0) or 0
			found.all, found.allXP = found.all + 1, found.allXP + xp
			if Ask(log.IsComplete, id) == true then
				found.ready, found.readyXP = found.ready + 1, found.readyXP + xp
			end
		end
	end
	quest = found
end

-- Draws the bar again (XpBar.lua) while it is Flat UI's: what the numbers changed shows at once.
local function Redraw()
	if ns.XpBarRedraw and ns.Enabled(KEY) then
		ns.Try(KEY, ns.XpBarRedraw)
	end
end

local function Look()
	Safe(Scan)
	Redraw()
end

-- One look at the log on the next frame however many events come in this one (QUEST_LOG_UPDATE comes often). Without a timer it looks at once.
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

-- The numbers ------------------------------------------------------------------------------------------------------------------------------

local function Remaining()
	local last = s and s.last
	return last and math.max(last[3] - last[2], 0) or nil
end

-- Experience an hour over the last WINDOW seconds of play, or the whole session while it is shorter; nil before MIN_PLAY seconds of play. The
-- seconds of play come second.
local function Pace(now)
	local play = Play(now)
	if play < MIN_PLAY then
		return nil, play
	end
	local from, base = math.max(0, play - WINDOW), 0
	-- The experience of the session up to the start of a window that is shorter than the session: the last mark at or before it. A window of
	-- the whole session counts every gain, those of its first seconds too.
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

-- About how many kills to the next level, the base of a kill, and whether the rested pool doubles the next ones. What is left of the pool goes
-- first: each kill then gives rate x base and takes (rate - 1) x base from it.
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

-- Seconds at this level: from /played at this level, else from a level up seen in this session; nil when not known.
local function LevelTime(now)
	local level = s.last and s.last[1]
	local played = s.played
	if type(played) == "table" and level and played.level == level then
		return played.seconds + math.max(0, now - played.at)
	elseif s.levelSince then
		return math.max(0, now - s.levelSince)
	end
	return nil
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

-- Words ------------------------------------------------------------------------------------------------------------------------------------

-- A whole number as the game writes large ones (BreakUpLargeNumbers, as in the game's experience tooltip, ExpBarOverrides.lua:31), or plain.
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

-- Seconds as 45m, 1h 20m or 2d 3h. up: a time still to come, rounded up to the next minute and at least 1m.
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

-- The levelling text of the bar by the row Levelling text, or nil when there is nothing to say yet.
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

-- The lines of the tooltip after the rested line: the quests of the log with Quests ready to hand in, the numbers with Levelling in the tooltip.
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
		lines[#lines + 1] = ("Kills to level: about %d (%s a kill%s)"):format(n.kills, Grouped(n.perKill), n.restRate == 2 and ", twice that while rested" or "")
	end
	if n.quests then
		lines[#lines + 1] = ("Quests to level: about %d (%s a quest)"):format(n.quests, Grouped(n.perQuest))
	end
	if n.levelTime then
		lines[#lines + 1] = "Time at this level: " .. Elapsed(n.levelTime)
	end
	return lines
end

-- Lines for /flatui status, while Flat UI's bar is chosen and the session has read the experience.
local function StatusLines()
	local lines = {}
	if not (ns.XpOwn and ns.XpOwn()) or not s or not s.last then
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

-- Interface for XpBar.lua ------------------------------------------------------------------------------------------------------------------

-- The levelling text by the row Levelling text, or nil.
function ns.XpStatsText(mode)
	return Safe(Text, mode)
end

-- The lines of the tooltip: quests with Quests ready to hand in, numbers with Levelling in the tooltip.
function ns.XpStatsLines(quests, numbers)
	return Safe(Lines, quests, numbers) or {}
end

-- The experience of the quests ready to hand in, 0 when there is none or nothing is known.
function ns.XpQuestReady()
	return Safe(function()
		return quest and not quest.missing and quest.readyXP or 0
	end) or 0
end

-- The bar was set up or a row changed: the log is read again.
function ns.XpStatsRefresh()
	Safe(Queue)
end

-- Events -------------------------------------------------------------------------------------------------------------------------------------

local function ForPlayer(unit)
	return not IsSecret(unit) and unit == "player"
end

local function Listen(event, fn, filter)
	ns.AddEvent(KEY, event, function(...)
		Safe(fn, ...)
	end, filter)
end

Listen("PLAYER_ENTERING_WORLD", function()
	Read()
	Queue()
end)
Listen("PLAYER_XP_UPDATE", Read, ForPlayer)
Listen("UNIT_LEVEL", Read, ForPlayer)
Listen("PLAYER_LEVEL_UP", function()
	Read()
	Queue()
end)
Listen("UPDATE_EXHAUSTION", function()
	if s then
		s.pool = Rest()
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
for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_DATA_LOAD_RESULT" }) do
	Listen(event, Queue)
end
Listen("GROUP_ROSTER_UPDATE", function()
	Group()
	Redraw()
end)
Listen("PLAYER_FLAGS_CHANGED", function()
	Away()
	Redraw()
end, ForPlayer)
Listen("TIME_PLAYED_MSG", Played)
Listen("PLAYER_LOGOUT", Save)
-- At login with the page on, or when the page is turned on later.
ns.AddStart(KEY, function()
	Safe(Begin)
	Safe(Queue)
end)

-- /flatui xp and its status lines ----------------------------------------------------------------------------------------------------------

local function Reset()
	local now = Now()
	if not s or not now then
		return false
	end
	local kept = { last = s.last, levelSince = s.levelSince, played = s.played, kills = s.kills, quests = s.quests, pool = s.pool }
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

local function Slash(rest)
	if not ns.Enabled(KEY) then
		Say("the levelling numbers need the Minimap and buffs page on.")
		return
	end
	local word = type(rest) == "string" and rest:lower():match("^%s*(%S*)") or ""
	if word == "reset" then
		if Safe(Reset) then
			Redraw()
			Say("the experience count starts again now.")
		else
			Say("the experience count starts with the next login.")
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
end

ns.AddSlash(KEY, "xp", Slash, { "/flatui xp - experience this session, the pace and the time to level", "/flatui xp reset - count this session from now" })
ns.AddStatus(KEY, function()
	return Safe(StatusLines) or {}
end)

-- For the tests and /flatui xp: the numbers as they stand.
ns.XpStatsNumbers = function()
	return Safe(Numbers)
end
