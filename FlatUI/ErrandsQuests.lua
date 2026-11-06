local _, ns = ...

-- Quests and gossip.
--
-- Accept quests: the quest an NPC offers in its window (QUEST_DETAIL), or that your group shares, is accepted with AcceptQuest. Left to you: a
-- quest an item starts (the game makes a pop-up of the tracker of it), one the game accepts by itself, one that flags you for PvP (the game asks
-- first), a low-level quest (C_QuestLog.IsQuestTrivial) and one that can be done again (C_QuestLog.IsRepeatableQuest) unless their rows are
-- ticked, and any quest while the quest log is full. A quest the game does not know well enough yet (C_QuestLog.GetQuestDifficultyLevel 0) is
-- asked for (C_QuestLog.RequestLoadQuestByID) and judged when it comes (QUEST_DATA_LOAD_RESULT), or LOAD_WAIT seconds later on what the game
-- says then. An escort a group member starts (QUEST_ACCEPT_CONFIRM, the game's QUEST_ACCEPT popup) is left to you.
-- Hand in finished quests: the progress window (QUEST_PROGRESS) of a quest that can be completed is answered with CompleteQuest, and the reward
-- window (QUEST_COMPLETE) with GetQuestReward when there is one reward or none, as the game's own button does. With a choice of rewards the window
-- stays open for you. Left to you: a quest that takes money (GetQuestMoneyToGet), a currency, or an item of green quality or better, and one that
-- can be done again unless its row is ticked.
-- From an NPC's list (GOSSIP_SHOW with C_GossipInfo, and the old greeting, QUEST_GREETING): a finished quest is picked first, then a new one,
-- under the same rules, each once in a talk. Gossip options: the options you saved (/flatui gossip), everywhere; and, in the open world only, the
-- one option the game marks (Quest), or the NPC's only option when it has no quest for you, unless the game picks that one itself. An option the
-- game does not offer as available, that casts a spell or that says why it would fail is never picked. A pick that the game asks about (a cost,
-- a teleport) still asks: GOSSIP_CONFIRM is left to the game's popup.
-- A talk is the windows of one NPC until TALK_GAP seconds after its last one closed; only the close of the window that shows ends it, since the
-- game may close the gossip just after it opened the quest window. Holding the key of Key to do it yourself at any window of a
-- talk leaves the rest of it to you, and so does the key pressed while the game loads the quest, a fight, a skipped NPC (/flatui npc), an NPC
-- whose GUID the game withholds (its skip list cannot be read then) and more than MAX_PICKS picks. A quest left to you is not opened from a
-- list again this session, until it is taken or handed in or a row changes. The quest and only-option rules are for creatures, not objects.
-- While another addon's own automation is on (EnhanceQoL's quest or gossip automation, Questie's auto accept or auto complete), that part
-- is left to it, and no list is answered that the other addon may answer in the same event. No frame of the game is touched: the windows
-- close as the game closes them.
-- These follow EnhanceQoL's quest and gossip automation, adapted with the permission of its author.

local E = ns.Errands
local part = E.Part({ label = "Quests" })

-- Seconds a talk with an NPC goes on after its last window closed: the game closes the quest window after an accept or a hand-in and shows the
-- NPC's list again a moment later, and that is still the same talk.
local TALK_GAP = 2
-- Seconds the game is given to load an offered quest.
local LOAD_WAIT = 2
-- Quests and options picked from lists in one talk, at most: an NPC that keeps offering the same thing is left to you after that.
local MAX_PICKS = 20
-- The item quality from which a quest's required item is yours to give: green (uncommon).
local GREEN = 2
-- Enum.GossipOptionRecFlags.QuestLabelPrepend and Enum.GossipOptionStatus.Available (GossipConstantsDocumentation.lua, GossipInfoDocumentation.lua).
local QUEST_FLAG, AVAILABLE = 1, 0
local NPC_KINDS = { Creature = true, Vehicle = true }
local KEYS = {
	shift = { label = "Shift", down = function() return IsShiftKeyDown end },
	ctrl = { label = "Ctrl", down = function() return IsControlKeyDown end },
	alt = { label = "Alt", down = function() return IsAltKeyDown end },
}
-- What a window does not show, said in chat when a quest is left to you for it.
local SAY = {
	full = "Your quest log is full (%d of %d), so %s is left to you.",
	money = "%s takes %s to hand in, so it is left to you.",
	currency = "%s takes a currency to hand in, so it is left to you.",
	item = "%s takes %s, so it is left to you.",
	unrated = "%s takes %s, and the game does not say how good it is, so it is left to you.",
	pvp = "%s would flag you for PvP, so it is left to you.",
}
-- Why a quest was left to you, for /flatui status.
local WHY = {
	low = "it is a low-level quest", repeatable = "it can be done again", money = "it takes money", currency = "it takes a currency",
	item = "it takes an item of green quality or better", pvp = "it flags you for PvP", full = "your quest log was full",
	unknown = "the game did not say what it takes", unrated = "the game did not say how good an item it takes is",
}

-- The talk with an NPC: { guid, window ("quest" or "gossip", the one shown last), open, closes, paused, picks, tried, left, said, offered }.
local talk
-- An offered quest waiting for the game to load it: { id, talk, token }. The token counts the waits, so a timer of an older wait does nothing.
local pending
local waits = 0
-- Quests asked to be accepted or handed in, by ID, until the game says it was done.
local asked = { accept = {}, turnIn = {} }
local done = { accepted = 0, handedIn = 0, options = 0 }
local lastLeft
-- Quests the game said were handed in (QUEST_TURNED_IN), until they leave the log (QUEST_REMOVED) or are taken again. The log lists such a
-- quest until its next update, which can come after the follow-up quest the NPC offers at once.
local handedIn = {}
-- Quests left to you this session, by ID, with why: a list does not open them again until they are taken or handed in, or a row changes. The
-- lines said about them, so one is said once a session (a full log is said once a talk). A load that failed is not kept: it may work next time.
local kept, spoken = {}, {}

local Decide

-- A field of a table the game gave, and true when the game withheld it.
local function Read(t, key)
	if type(t) ~= "table" or ns.IsSecret(t) then
		return nil, true
	end
	local ok, value = pcall(function()
		return t[key]
	end)
	if not ok or ns.IsSecret(value) then
		return nil, true
	end
	return value, false
end

local function Field(t, key)
	return (Read(t, key))
end

-- Up to eight answers of a call, each nil when the game withholds it.
local function Answers(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local values = { pcall(fn, ...) }
	if not values[1] then
		return nil
	end
	for index = 2, 9 do
		if ns.IsSecret(values[index]) then
			values[index] = nil
		end
	end
	return values[2], values[3], values[4], values[5], values[6], values[7], values[8], values[9]
end

-- A call of C_QuestLog, or nil when the client has none.
local function Log(name, ...)
	local log = C_QuestLog
	if type(log) ~= "table" or ns.IsSecret(log) then
		return nil
	end
	return E.Ask(log[name], ...)
end

-- The entries of a list the game gives, in its order; an entry it withholds is left out.
local function Entries(fn)
	local list = E.Ask(fn)
	local entries = {}
	if type(list) ~= "table" then
		return entries
	end
	for _, entry in ipairs(list) do
		if type(entry) == "table" and not ns.IsSecret(entry) then
			entries[#entries + 1] = entry
		end
	end
	return entries
end

local function Count(n, most)
	return ns.Finite(n) and n > 0 and math.min(math.floor(n), most) or 0
end

-- Keys -----------------------------------------------------------------------------------------------------------------------------------

local function Key()
	return KEYS[E.Opt("questKey")] or KEYS.shift
end

-- Whether the key is held: true or false, or nil when the game does not say.
local function Held()
	local fn = Key().down()
	if type(fn) ~= "function" then
		return nil
	end
	local ok, down = pcall(fn)
	if not ok or ns.IsSecret(down) then
		return nil
	end
	return down == true or down == 1
end

-- NPCs -----------------------------------------------------------------------------------------------------------------------------------

-- The GUID, kind ("Creature", "Vehicle", "GameObject", "Player"...), NPC ID and name of the one a window is for (questnpc or npc), each nil when
-- the game does not say. The GUID is "Creature-0-<server>-<instance>-<zone>-<NPC ID>-<spawn>".
local function Who(unit)
	local guid = E.Ask(UnitGUID, unit)
	if type(guid) ~= "string" or guid == "" then
		return nil
	end
	local kind = guid:match("^(%a+)%-")
	local id = tonumber(guid:match("^%a+%-[^%-]*%-[^%-]*%-[^%-]*%-[^%-]*%-(%d+)%-"))
	local name = E.Ask(UnitName, unit)
	return guid, kind, id, type(name) == "string" and name ~= "" and name or nil
end

-- The account's skipped NPCs (npcs: NPC ID -> name) and saved gossip options (gossip: option ID -> { text, npc, npcID }), beside the sell and
-- keep lists in FlatUIDB.errands. Nil before the saved variables are loaded.
local function Saved()
	local lists = E.Lists()
	if not lists then
		return nil
	end
	lists.npcs = type(lists.npcs) == "table" and lists.npcs or {}
	lists.gossip = type(lists.gossip) == "table" and lists.gossip or {}
	return lists
end

-- Whether the game withholds the GUID of the one a window is for. The skip list cannot be read then, so the window is left to you, as
-- Questie's Forever code leaves it (Modules/Auto/AutoQuesting.lua:223-229). A unit with no GUID (an item's offer) is not withheld.
local function Withheld(unit)
	if type(UnitGUID) ~= "function" then
		return false
	end
	local ok, guid = pcall(UnitGUID, unit)
	return ok and ns.IsSecret(guid)
end

local function Skipped(unit)
	local lists = Saved()
	local _, kind, id = Who(unit)
	return lists ~= nil and NPC_KINDS[kind] == true and id ~= nil and type(lists.npcs[id]) == "string"
end

-- A setting of another addon, read in a pcall: true only for a plain true.
local function Setting(read)
	local ok, on = pcall(read)
	return ok and not ns.IsSecret(on) and on == true
end

local function Table(value)
	return not ns.IsSecret(value) and type(value) == "table"
end

-- What another addon's own automation answers, read from its settings: EnhanceQoL's quest automation (autoChooseQuest, accepts and hands in)
-- and gossip automation (autoChooseGossip) on its global table, and Questie's auto accept (Questie.db.profile.autoAccept.enabled) and auto
-- complete (Questie.db.profile.autocomplete), both off by default (Modules/Options/QuestieOptionsDefaults.lua:144-147). That part is left to
-- it, so two addons never answer the same window: { accept, turnIn, gossip, eqolQuests, eqolGossip, questieAccept, questieTurnIn }.
local function Theirs()
	local eqol, questie = _G.EnhanceQoL, _G.Questie
	local eqolQuests = Table(eqol) and Setting(function()
		return eqol.db.autoChooseQuest
	end)
	local eqolGossip = Table(eqol) and Setting(function()
		return eqol.db.autoChooseGossip
	end)
	local questieAccept = Table(questie) and Setting(function()
		return questie.db.profile.autoAccept.enabled
	end)
	local questieTurnIn = Table(questie) and Setting(function()
		return questie.db.profile.autocomplete
	end)
	return { accept = eqolQuests or questieAccept, turnIn = eqolQuests or questieTurnIn, gossip = eqolGossip, eqolQuests = eqolQuests,
		eqolGossip = eqolGossip, questieAccept = questieAccept, questieTurnIn = questieTurnIn }
end

-- Talks ----------------------------------------------------------------------------------------------------------------------------------

-- The talk ends TALK_GAP seconds after a window closed, unless another window of it opened since.
local function EndLater(current)
	current.closes = current.closes + 1
	local at = current.closes
	C_Timer.After(TALK_GAP, function()
		E.Run(part, function()
			if talk == current and not current.open and current.closes == at then
				talk = nil
				if pending and pending.talk == current then
					pending = nil
				end
			end
		end)
	end)
end

-- The talk a window belongs to: the one with the same NPC that has not ended, or a new one. The key held at any window of a talk, or a key the
-- game does not tell, leaves the rest of that talk to you. window: "quest" for the quest window, "gossip" for the gossip.
local function Talk(unit, window)
	local guid = Who(unit) or "?"
	if not talk or talk.guid ~= guid then
		talk = { guid = guid, closes = 0, picks = 0, tried = {}, left = {}, said = {}, offered = {} }
		pending = nil
	end
	talk.open, talk.window = true, window
	if Held() ~= false then
		talk.paused = true
	end
	return talk
end

-- GOSSIP_CLOSED and QUEST_FINISHED. A close of the other window is not the end: the gossip may close just after the quest window opened.
local function Closed(window)
	if talk and talk.open and talk.window == window then
		talk.open = false
		EndLater(talk)
	end
end

-- Whether this part may answer a window of the talk now.
local function MayAct(current, unit)
	return ns.Enabled("errands") and not current.paused and current.picks < MAX_PICKS and not E.Fighting() and not Withheld(unit)
		and not Skipped(unit)
end

-- Quests ---------------------------------------------------------------------------------------------------------------------------------

local function Title()
	local title = E.Ask(GetTitleText)
	return type(title) == "string" and title ~= "" and title or nil
end

-- What a list of the game says of a quest: true when it recurs (a frequency above 0, an isDaily of the classic shape, or repeatable), false when
-- it says not, nil when it does not say.
local function Listed(frequency, repeatable)
	if repeatable == true or frequency == true or (ns.Finite(frequency) and frequency > 0) then
		return true
	end
	if repeatable == false and (frequency == nil or frequency == false or frequency == 0) then
		return false
	end
	return nil
end

-- Whether a quest can be done again and again: what a list said, else C_QuestLog.IsRepeatableQuest, or a Recurring classification.
local function Repeats(id, listed)
	if listed ~= nil then
		return listed
	end
	if not ns.Finite(id) then
		return nil
	end
	local repeatable = Log("IsRepeatableQuest", id)
	if repeatable == true then
		return true
	end
	local system = C_QuestInfoSystem
	local recurring = type(Enum) == "table" and type(Enum.QuestClassification) == "table" and Enum.QuestClassification.Recurring or nil
	if recurring ~= nil and type(system) == "table" and E.Ask(system.GetQuestClassification, id) == recurring then
		return true
	end
	return repeatable
end

-- Why the rows leave a quest to you, or nil. An answer the game did not give counts as no.
local function Unwanted(low, repeats)
	if repeats == true and E.Opt("questRepeat") ~= true then
		return "repeatable"
	end
	if low == true and E.Opt("questLow") ~= true then
		return "low"
	end
	return nil
end

-- The quests in the log and the most it holds, while it is full. Nil while there is room or the game does not say.
local function LogFull()
	local _, quests = Log("GetNumQuestLogEntries")
	local most = Log("GetMaxNumQuestsCanAccept")
	if not ns.Finite(most) or most <= 0 then
		most = ns.Finite(_G.MAX_QUESTLOG_QUESTS) and _G.MAX_QUESTLOG_QUESTS or (ns.Finite(_G.MAX_QUESTS) and _G.MAX_QUESTS or nil)
	end
	if ns.Finite(quests) then
		-- A quest handed in that the log still lists has left the server's log already.
		for id in pairs(handedIn) do
			if ns.Finite(Log("GetLogIndexForQuestID", id)) then
				quests = quests - 1
			end
		end
	end
	if ns.Finite(quests) and most and quests >= most then
		return quests, most
	end
	return nil
end

-- Leaves a quest of the talk to you, says why when the window does not show it, and keeps it for /flatui status. A quest left for a full log is
-- not kept as left: a hand-in later in the same talk can make room for it.
local function Leave(current, key, why, title, a, b)
	if why ~= "full" then
		current.left[key] = true
		if why ~= "unknown" and ns.Finite(key) then
			kept[key] = why
		end
	end
	title = title or Title()
	lastLeft = { title = title, why = why }
	local line = SAY[why]
	local said = why == "full" and "full" or (why .. " " .. tostring(key))
	local book = why == "full" and current.said or spoken
	if not line or book[said] then
		return
	end
	book[said] = true
	local named = title or "the quest"
	if why == "full" then
		E.Say(line:format(a, b, named))
	elseif why == "money" then
		E.Say(line:format(named, E.Money(a)))
	elseif why == "item" or why == "unrated" then
		E.Say(line:format(named, a))
	else
		E.Say(line:format(named))
	end
end

local function Pick(current, key, fn, arg, offered)
	current.tried[key] = true
	current.picks = current.picks + 1
	if offered then
		current.offered[key] = offered
	end
	return E.Call(fn, arg)
end

-- The game knows a quest well enough to say whether it is low level: its difficulty level is above 0. A client without the call counts as knowing.
local function Loaded(id)
	local log = C_QuestLog
	if type(log) ~= "table" or type(log.GetQuestDifficultyLevel) ~= "function" then
		return true
	end
	local level = Log("GetQuestDifficultyLevel", id)
	return ns.Finite(level) and level > 0
end

-- Accepts the quest of the window, or leaves it to you. final: the game has had its time to load the quest.
Decide = function(current, id, final)
	-- The key pressed while the game loads the quest counts as held at its window.
	if final and talk == current and Held() ~= false then
		current.paused = true
	end
	if talk ~= current or not current.open or current.window ~= "quest" or current.left[id] or E.Ask(GetQuestID) ~= id
		or E.Opt("questAccept") ~= true or not MayAct(current, "questnpc") then
		return
	end
	local offered = current.offered[id]
	local low, repeats
	if offered then
		low, repeats = offered.low, offered.repeats
	end
	local askLow, askRepeat = E.Opt("questLow") ~= true and low == nil, E.Opt("questRepeat") ~= true and repeats == nil
	if not final and (askLow or askRepeat) and not Loaded(id) then
		waits = waits + 1
		local token = waits
		pending = { id = id, talk = current, token = token }
		local log = C_QuestLog
		if type(log) == "table" and not ns.IsSecret(log) then
			E.Call(log.RequestLoadQuestByID, id)
		end
		C_Timer.After(LOAD_WAIT, function()
			E.Run(part, function()
				if pending and pending.token == token then
					pending = nil
					Decide(current, id, true)
				end
			end)
		end)
		return
	end
	if askLow then
		low = Log("IsQuestTrivial", id)
	end
	if askRepeat then
		repeats = Repeats(id)
	end
	local why = Unwanted(low, repeats)
	if why then
		Leave(current, id, why)
		return
	end
	if E.Call(AcceptQuest) then
		asked.accept[id] = true
	end
end

-- QUEST_DETAIL: the quest an NPC offers, or your group shares.
local function Detail(fromItem)
	-- A quest an item starts, or one of an area the game accepts by itself, becomes a pop-up of the tracker and the game closes the window at
	-- once (QuestFrame.lua:47-60 on Forever); a quest of a map of the game's has no window. None is a window of a talk.
	local auto = E.Ask(QuestGetAutoAccept) == true
	if ns.IsSecret(fromItem) or (fromItem ~= nil and fromItem ~= 0) or E.Ask(QuestIsFromAdventureMap) == true
		or (auto and E.Ask(QuestIsFromAreaTrigger) == true) then
		return
	end
	local current = Talk("questnpc", "quest")
	if E.Opt("questAccept") ~= true or not MayAct(current, "questnpc") or Theirs().accept then
		return
	end
	-- Accepted already: the window only asks to acknowledge it, the game's own.
	if auto then
		return
	end
	local id = E.Ask(GetQuestID)
	if not ns.Finite(id) or id <= 0 or current.left[id] then
		return
	end
	-- The game asks before a quest that flags you for PvP (QuestFrame.lua:569-579).
	local pvp = E.Ask(QuestFlagsPVP)
	if pvp == true or pvp == 1 then
		Leave(current, id, "pvp")
		return
	end
	local quests, most = LogFull()
	if quests then
		Leave(current, id, "full", nil, quests, most)
		return
	end
	Decide(current, id, false)
end

-- What handing in the quest of the window takes besides its own items: "money" (copper), "currency" (how many), "item" (its link), "unrated"
-- (the link of an item whose quality the game does not give) or "unknown" when the game does not say how much money; nil when it takes none.
local function Takes()
	local money = E.Ask(GetQuestMoneyToGet)
	if not ns.Finite(money) then
		return "unknown"
	end
	if money > 0 then
		return "money", money
	end
	if type(GetNumQuestCurrencies) == "function" then
		local currencies = E.Ask(GetNumQuestCurrencies)
		if not ns.Finite(currencies) then
			return "unknown"
		end
		if currencies > 0 then
			return "currency", currencies
		end
	end
	for index = 1, Count(E.Ask(GetNumQuestItems), 10) do
		local hidden = E.Ask(IsQuestItemHidden, index)
		if hidden == nil or hidden == 0 or hidden == false then
			local _, _, _, quality = E.Ask(GetQuestItemInfo, "required", index)
			local link = E.Ask(GetQuestItemLink, "required", index)
			if not ns.Finite(quality) and type(link) == "string" and type(C_Item) == "table" then
				local _, _, linked = E.Ask(C_Item.GetItemInfo, link)
				quality = linked
			end
			if not ns.Finite(quality) then
				return "unrated", type(link) == "string" and link or "an item"
			end
			if quality >= GREEN then
				return "item", type(link) == "string" and link or "an item of green quality or better"
			end
		end
	end
	return nil
end

-- QUEST_PROGRESS: the window that asks for what the quest needs.
local function Progress()
	local current = Talk("questnpc", "quest")
	if E.Opt("questTurnIn") ~= true or not MayAct(current, "questnpc") or Theirs().turnIn then
		return
	end
	local id = E.Ask(GetQuestID)
	if not ns.Finite(id) or id <= 0 or current.left[id] then
		return
	end
	local ready = E.Ask(IsQuestCompletable)
	if ready ~= true and ready ~= 1 then
		return
	end
	local why, what = Takes()
	if why then
		Leave(current, id, why, nil, what)
		return
	end
	if Unwanted(nil, Repeats(id)) then
		Leave(current, id, "repeatable")
		return
	end
	E.Call(CompleteQuest)
end

-- QUEST_COMPLETE: the reward window. One reward or none is taken as the game's own button takes it (QuestFrame.lua:145-162).
local function Complete()
	local current = Talk("questnpc", "quest")
	if E.Opt("questTurnIn") ~= true or not MayAct(current, "questnpc") or Theirs().turnIn then
		return
	end
	local id = E.Ask(GetQuestID)
	if not ns.Finite(id) or id <= 0 or current.left[id] then
		return
	end
	local money = E.Ask(GetQuestMoneyToGet)
	if not ns.Finite(money) then
		Leave(current, id, "unknown")
		return
	elseif money > 0 then
		Leave(current, id, "money", nil, money)
		return
	end
	if Unwanted(nil, Repeats(id)) then
		Leave(current, id, "repeatable")
		return
	end
	local choices = E.Ask(GetNumQuestChoices)
	if not ns.Finite(choices) or choices > 1 then
		return
	end
	if E.Call(GetQuestReward, choices == 1 and 1 or 0) then
		asked.turnIn[id] = Title() or true
	end
end

-- QUEST_GREETING: the old list of an NPC's quests.
local function Greeting()
	local current = Talk("questnpc", "quest")
	local others = Theirs()
	if not MayAct(current, "questnpc") or others.accept or others.turnIn then
		return
	end
	if E.Opt("questTurnIn") == true then
		for index = 1, Count(E.Ask(GetNumActiveQuests), 50) do
			local title, finished = E.Ask(GetActiveTitle, index)
			local id = E.Ask(GetActiveQuestID, index)
			local key = ns.Finite(id) and id or ("active " .. tostring(title))
			if finished == true and not current.tried[key] and not current.left[key] and not kept[key] and not Unwanted(nil, Repeats(id)) then
				Pick(current, key, SelectActiveQuest, index)
				return
			end
		end
	end
	if E.Opt("questAccept") == true then
		for index = 1, Count(E.Ask(GetNumAvailableQuests), 50) do
			-- isTrivial, frequency (isDaily on the classic shape), isRepeatable, isLegendary, questID (Mainline QuestFrame.lua:375, Classic 379).
			local low, frequency, repeatable, _, id = Answers(GetAvailableQuestInfo, index)
			local title = E.Ask(GetAvailableTitle, index)
			local key = ns.Finite(id) and id or ("available " .. tostring(title))
			local repeats = Repeats(id, Listed(frequency, repeatable))
			if not current.tried[key] and not current.left[key] and not kept[key] and not Unwanted(low, repeats) then
				local quests, most = LogFull()
				if quests then
					Leave(current, key, "full", title, quests, most)
				else
					Pick(current, key, SelectAvailableQuest, index, { low = low, repeats = repeats })
					return
				end
			end
		end
	end
end

-- Gossip ---------------------------------------------------------------------------------------------------------------------------------

local function Flagged(option)
	local flags = Field(option, "flags")
	return ns.Finite(flags) and math.floor(flags) % 2 == QUEST_FLAG
end

-- The text the game shows for an option: its name, after (Quest) for an option the game marks.
local function Label(option)
	local name = Field(option, "name")
	if type(name) ~= "string" then
		return ""
	end
	if Flagged(option) and type(GOSSIP_OPTION_PREPEND) == "string" and type(QUEST_PREPEND) == "string" then
		local ok, text = pcall(string.format, GOSSIP_OPTION_PREPEND, QUEST_PREPEND, name)
		if ok and type(text) == "string" then
			return text
		end
	end
	return name
end

local function OptionKey(option)
	local id = Field(option, "gossipOptionID")
	if ns.Finite(id) then
		return "option " .. id
	end
	return "index " .. tostring(Field(option, "orderIndex")) .. " " .. tostring(Field(option, "name"))
end

-- The options of the gossip, in the order the game shows them (GossipFrameShared.lua:194-195).
local function Options()
	local gossip = C_GossipInfo
	local options = type(gossip) == "table" and Entries(gossip.GetOptions) or {}
	table.sort(options, function(a, b)
		local x, y = Field(a, "orderIndex"), Field(b, "orderIndex")
		return (ns.Finite(x) and x or 0) < (ns.Finite(y) and y or 0)
	end)
	return options
end

-- An option that may be picked without your word: one the game offers as available, that casts no spell and gives no reason it would fail. An
-- answer the game withholds counts against it.
local function Plain(option)
	local status, withheld = Read(option, "status")
	if withheld or (status ~= nil and status ~= AVAILABLE) then
		return false
	end
	local spell, spellWithheld = Read(option, "spellID")
	if spellWithheld or spell ~= nil then
		return false
	end
	local failure, failureWithheld = Read(option, "failureDescription")
	return not failureWithheld and (failure == nil or failure == "")
end

-- Inside a dungeon, raid, battleground or arena, or the game does not say.
local function Inside()
	return E.Ask(IsInInstance) ~= false
end

local function PickOption(current, option)
	local key = OptionKey(option)
	local index, id = Field(option, "orderIndex"), Field(option, "gossipOptionID")
	current.tried[key] = true
	current.picks = current.picks + 1
	local ok = false
	if ns.Finite(index) then
		ok = E.Call(C_GossipInfo.SelectOptionByIndex, index)
	elseif ns.Finite(id) then
		ok = E.Call(C_GossipInfo.SelectOption, id)
	end
	if ok then
		done.options = done.options + 1
	end
end

-- A saved option seen again: its text and NPC are kept as the game says them now.
local function Remember(options)
	local lists = Saved()
	if not lists then
		return
	end
	local _, _, npcID, npc = Who("npc")
	for _, option in ipairs(options) do
		local id = Field(option, "gossipOptionID")
		local entry = ns.Finite(id) and lists.gossip[id] or nil
		if type(entry) == "table" then
			local text = Label(option)
			if text ~= "" then
				entry.text = text
			end
			entry.npc, entry.npcID = npc or entry.npc, npcID or entry.npcID
		end
	end
end

-- others: Theirs(). While another addon may pick a quest of this list in the same event, no option is picked beside it.
local function Choose(current, options, quests, others)
	local mode = E.Opt("gossip")
	if (mode ~= "saved" and mode ~= "all") or others.gossip or ((others.accept or others.turnIn) and quests > 0) then
		return
	end
	local lists = Saved()
	for _, option in ipairs(options) do
		local id = Field(option, "gossipOptionID")
		if lists and ns.Finite(id) and type(lists.gossip[id]) == "table" and not current.tried[OptionKey(option)] then
			PickOption(current, option)
			return
		end
	end
	-- The quest and only-option rules are for creatures: an object's gossip can start an event or call up a foe, and /flatui npc cannot skip an
	-- object.
	local _, kind = Who("npc")
	if mode ~= "all" or Inside() or NPC_KINDS[kind] ~= true then
		return
	end
	local flagged, count = nil, 0
	for _, option in ipairs(options) do
		if Flagged(option) then
			flagged, count = option, count + 1
		end
	end
	if count == 1 and not current.tried[OptionKey(flagged)] and Plain(flagged) then
		PickOption(current, flagged)
		return
	end
	if #options == 1 and quests == 0 then
		local only = options[1]
		-- The game picks such an option itself (GossipFrameShared.lua:192-201).
		if Field(only, "selectOptionWhenOnlyOption") == true and E.Ask(C_GossipInfo.ForceGossip) ~= true then
			return
		end
		if not current.tried[OptionKey(only)] and Plain(only) then
			PickOption(current, only)
		end
	end
end

-- GOSSIP_SHOW: a finished quest first, then a new one, then an option.
local function Gossip()
	local current = Talk("npc", "gossip")
	local gossip = C_GossipInfo
	if type(gossip) ~= "table" or ns.IsSecret(gossip) then
		return
	end
	-- A saved option seen is kept up to date also when the talk is left to you.
	local options = Options()
	Remember(options)
	if not MayAct(current, "npc") then
		return
	end
	-- EnhanceQoL's gossip automation picks options whatever quests the list has: nothing of this list is answered beside it.
	local others = Theirs()
	if others.gossip then
		return
	end
	local active, available = Entries(gossip.GetActiveQuests), Entries(gossip.GetAvailableQuests)
	if not others.accept and not others.turnIn then
		if E.Opt("questTurnIn") == true then
			for _, quest in ipairs(active) do
				local id = Field(quest, "questID")
				if ns.Finite(id) and Field(quest, "isComplete") == true and Field(quest, "isIgnored") ~= true and not current.tried[id]
					and not current.left[id] and not kept[id] and not Unwanted(nil, Repeats(id, Listed(Field(quest, "frequency"), Field(quest, "repeatable")))) then
					Pick(current, id, gossip.SelectActiveQuest, id)
					return
				end
			end
		end
		if E.Opt("questAccept") == true then
			for _, quest in ipairs(available) do
				local id = Field(quest, "questID")
				local low = Field(quest, "isTrivial")
				-- Not "x and Repeats() or nil": a list that says the quest does not recur gives false, which must reach the quest window.
				local repeats
				if ns.Finite(id) then
					repeats = Repeats(id, Listed(Field(quest, "frequency"), Field(quest, "repeatable")))
				end
				if ns.Finite(id) and Field(quest, "isIgnored") ~= true and not current.tried[id] and not current.left[id] and not kept[id]
					and not Unwanted(low, repeats) then
					local quests, most = LogFull()
					if quests then
						Leave(current, id, "full", Field(quest, "title"), quests, most)
					else
						Pick(current, id, gossip.SelectAvailableQuest, id, { low = low, repeats = repeats })
						return
					end
				end
			end
		end
	end
	Choose(current, options, #active + #available, others)
end

E.Listen(part, "GOSSIP_SHOW", Gossip)
E.Listen(part, "GOSSIP_CLOSED", function()
	Closed("gossip")
end)
E.Listen(part, "QUEST_GREETING", Greeting)
E.Listen(part, "QUEST_DETAIL", Detail)
E.Listen(part, "QUEST_PROGRESS", Progress)
E.Listen(part, "QUEST_COMPLETE", Complete)
E.Listen(part, "QUEST_FINISHED", function()
	Closed("quest")
end)
E.Listen(part, "QUEST_DATA_LOAD_RESULT", function(id, success)
	if not pending or ns.IsSecret(id) or id ~= pending.id then
		return
	end
	local wait = pending
	pending = nil
	if success == false then
		Leave(wait.talk, id, "unknown")
		return
	end
	Decide(wait.talk, id, true)
end)
-- The game says what it did: the modern event gives the quest's ID, the classic one its index and then its ID.
E.Listen(part, "QUEST_ACCEPTED", function(a, b)
	local id = ns.Finite(b) and b or a
	if ns.Finite(id) then
		handedIn[id], kept[id] = nil, nil
	end
	if ns.Finite(id) and asked.accept[id] then
		asked.accept[id] = nil
		done.accepted = done.accepted + 1
	end
end)
E.Listen(part, "QUEST_TURNED_IN", function(id)
	if ns.Finite(id) then
		handedIn[id], kept[id] = true, nil
	end
	if ns.Finite(id) and asked.turnIn[id] then
		asked.turnIn[id] = nil
		done.handedIn = done.handedIn + 1
	end
end)
E.Listen(part, "QUEST_REMOVED", function(id)
	if ns.Finite(id) then
		handedIn[id] = nil
	end
end)

function part.Start()
	talk, pending, handedIn, kept, spoken = nil, nil, {}, {}, {}
end

function part.Refresh()
	-- A row may have changed: a quest left to you for it may be wanted now.
	kept = {}
	if not ns.Enabled("errands") or E.Opt("questAccept") ~= true then
		pending = nil
	end
end

-- /flatui npc and /flatui gossip, and the list rows ----------------------------------------------------------------------------------------

local function Trim(text)
	return tostring(text or ""):match("^%s*(.-)%s*$")
end

-- The unit of the NPC whose window is open, else the target.
local function Facing()
	if E.Shown(QuestFrame) and E.Ask(UnitExists, "questnpc") == true then
		return "questnpc"
	elseif E.Shown(GossipFrame) and E.Ask(UnitExists, "npc") == true then
		return "npc"
	end
	return "target"
end

local function SkippedNames(lists)
	local names = {}
	for id, name in pairs(lists.npcs) do
		if type(id) == "number" and type(name) == "string" then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	return #names > 0 and table.concat(names, ", ") or "none"
end

E.slash.npc = function(rest)
	local lists = Saved()
	if not lists then
		return
	end
	rest = Trim(rest)
	if rest ~= "" then
		local wanted, number = rest:lower(), tonumber(rest)
		for id, name in pairs(lists.npcs) do
			if type(name) == "string" and (id == number or name:lower() == wanted) then
				lists.npcs[id] = nil
				print(("Flat UI: %s is no longer skipped."):format(name))
				return
			end
		end
		print(("Flat UI: no skipped NPC is called %s. /flatui npc lists them."):format(rest))
		return
	end
	local unit = Facing()
	local _, kind, id, name = Who(unit)
	if not NPC_KINDS[kind] or not id or E.Ask(UnitIsPlayer, unit) == true then
		print(("Flat UI: skipped NPCs: %s."):format(SkippedNames(lists)))
		print("Flat UI: talk to an NPC or target one, then type /flatui npc to skip it or to stop skipping it.")
		return
	end
	name = name or ("NPC " .. id)
	if lists.npcs[id] then
		lists.npcs[id] = nil
		print(("Flat UI: %s is no longer skipped."):format(name))
	else
		lists.npcs[id] = name
		print(("Flat UI: %s is skipped: its quests and gossip are left to you."):format(name))
	end
end

-- The options of the gossip that is open, or nil when none is.
local function OpenOptions()
	if not E.Shown(GossipFrame) then
		return nil
	end
	return Options()
end

local function SavedLabel(id, entry)
	local text = type(entry.text) == "string" and entry.text ~= "" and entry.text or "an option"
	if type(entry.npc) == "string" and entry.npc ~= "" then
		text = entry.npc .. ": " .. text
	end
	return ("%s (%d)"):format(text, id)
end

E.slash.gossip = function(rest)
	local lists = Saved()
	if not lists then
		return
	end
	rest = Trim(rest)
	local forget = tonumber(rest:lower():match("^forget%s+(%d+)$") or "")
	if forget then
		if type(lists.gossip[forget]) == "table" then
			print(("Flat UI: %s is no longer picked for you."):format(SavedLabel(forget, lists.gossip[forget])))
			lists.gossip[forget] = nil
		else
			print(("Flat UI: no saved gossip option has the ID %d."):format(forget))
		end
		return
	end
	local options = OpenOptions()
	if rest == "" then
		if options and #options > 0 then
			for number, option in ipairs(options) do
				local id = Field(option, "gossipOptionID")
				local saved = ns.Finite(id) and type(lists.gossip[id]) == "table"
				print(("Flat UI: %d. %s%s"):format(number, Label(option), saved and " (picked for you)" or ""))
			end
			print("Flat UI: /flatui gossip and a number picks that option for you from now on, or stops.")
		else
			local names = {}
			for id, entry in pairs(lists.gossip) do
				if type(id) == "number" and type(entry) == "table" then
					names[#names + 1] = SavedLabel(id, entry)
				end
			end
			table.sort(names)
			print(("Flat UI: saved gossip options: %s."):format(#names > 0 and table.concat(names, ", ") or "none"))
		end
		return
	end
	local number = tonumber(rest)
	local option = options and number and options[number]
	if not option then
		print("Flat UI: /flatui gossip and a number works while an NPC's gossip is open. /flatui gossip lists its options.")
		return
	end
	local id = Field(option, "gossipOptionID")
	if not ns.Finite(id) then
		print("Flat UI: the game gives that option no ID, so it cannot be saved.")
		return
	end
	if type(lists.gossip[id]) == "table" then
		lists.gossip[id] = nil
		print(('Flat UI: "%s" is no longer picked for you.'):format(Label(option)))
	else
		local _, _, npcID, npc = Who("npc")
		lists.gossip[id] = { text = Label(option), npc = npc, npcID = npcID }
		print(('Flat UI: "%s" is picked for you from now on.'):format(Label(option)))
	end
end
E.help[#E.help + 1] = "/flatui npc - skip the NPC you talk to or target, or stop: its quests and gossip are left to you; alone, the list"
E.help[#E.help + 1] = "/flatui gossip - the options of the open gossip; with a number, that option is picked for you from now on, or stops"
E.help[#E.help + 1] = "/flatui gossip forget <ID> - stop picking a saved gossip option"

function ns.QuestSkippedLines()
	local lists, rows = Saved(), {}
	for id, name in pairs(lists and lists.npcs or {}) do
		if type(id) == "number" and type(name) == "string" then
			rows[#rows + 1] = { id, ("%s (%d)"):format(name, id) }
		end
	end
	table.sort(rows, function(a, b)
		return a[2] < b[2]
	end)
	return rows
end

function ns.QuestSkippedPick(id)
	local lists = Saved()
	local name = lists and lists.npcs[id]
	if type(name) ~= "string" then
		return false
	end
	lists.npcs[id] = nil
	return true, ("Flat UI: %s is no longer skipped."):format(name)
end

function ns.GossipSavedLines()
	local lists, rows = Saved(), {}
	for id, entry in pairs(lists and lists.gossip or {}) do
		if type(id) == "number" and type(entry) == "table" then
			rows[#rows + 1] = { id, SavedLabel(id, entry) }
		end
	end
	table.sort(rows, function(a, b)
		return a[2] < b[2]
	end)
	return rows
end

function ns.GossipSavedPick(id)
	local lists = Saved()
	local entry = lists and lists.gossip[id]
	if type(entry) ~= "table" then
		return false
	end
	lists.gossip[id] = nil
	return true, ("Flat UI: %s is no longer picked for you."):format(SavedLabel(id, entry))
end

function part.Status()
	local does = {}
	if E.Opt("questAccept") == true then
		does[#does + 1] = "accepts quests"
	end
	if E.Opt("questTurnIn") == true then
		does[#does + 1] = "hands in finished quests"
	end
	local mode = E.Opt("gossip")
	if mode == "saved" then
		does[#does + 1] = "picks the gossip options you saved"
	elseif mode == "all" then
		does[#does + 1] = "picks saved, quest and only gossip options"
	end
	if #does == 0 then
		return {}
	end
	local line = ("Quests: %s. Hold %s as you talk to an NPC to do it yourself."):format(table.concat(does, ", "), Key().label)
	local counts = {}
	if done.accepted > 0 then
		counts[#counts + 1] = ("%d accepted"):format(done.accepted)
	end
	if done.handedIn > 0 then
		counts[#counts + 1] = ("%d handed in"):format(done.handedIn)
	end
	if done.options > 0 then
		counts[#counts + 1] = ("%d gossip %s picked"):format(done.options, done.options == 1 and "option" or "options")
	end
	if #counts > 0 then
		line = line .. " This session: " .. table.concat(counts, ", ") .. "."
	end
	if lastLeft then
		line = line .. (" Last left to you: %s, as %s."):format(lastLeft.title or "a quest", WHY[lastLeft.why] or lastLeft.why)
	end
	local lines = { line }
	local kept = {}
	local npcs, options = #ns.QuestSkippedLines(), #ns.GossipSavedLines()
	if npcs > 0 then
		kept[#kept + 1] = ("%d %s skipped"):format(npcs, npcs == 1 and "NPC" or "NPCs")
	end
	if options > 0 then
		kept[#kept + 1] = ("%d gossip %s saved"):format(options, options == 1 and "option" or "options")
	end
	if #kept > 0 then
		lines[#lines + 1] = "Quests: " .. table.concat(kept, ", ") .. "."
	end
	if pending then
		lines[#lines + 1] = "Quests: waiting for the game to load the quest it offers."
	end
	local others = Theirs()
	if others.questieAccept and E.Opt("questAccept") == true then
		lines[#lines + 1] = "Quests: Questie's own auto accept is on, so accepting quests is left to it."
	end
	if others.questieTurnIn and E.Opt("questTurnIn") == true then
		lines[#lines + 1] = "Quests: Questie's own auto complete is on, so handing in quests is left to it."
	end
	if others.eqolQuests and (E.Opt("questAccept") == true or E.Opt("questTurnIn") == true) then
		lines[#lines + 1] = "Quests: EnhanceQoL's own quest automation is on, so quests are left to it."
	end
	if others.eqolGossip and (mode == "saved" or mode == "all") then
		lines[#lines + 1] = "Quests: EnhanceQoL's own gossip automation is on, so gossip is left to it."
	end
	if E.Opt("questAccept") == true and type(AcceptQuest) ~= "function" then
		lines[#lines + 1] = "Quests: this client cannot accept quests for you."
	end
	if E.Opt("questTurnIn") == true and (type(CompleteQuest) ~= "function" or type(GetQuestReward) ~= "function") then
		lines[#lines + 1] = "Quests: this client cannot hand in quests for you."
	end
	if (mode == "saved" or mode == "all") and type(C_GossipInfo) ~= "table" then
		lines[#lines + 1] = "Quests: this client has no gossip calls, so gossip is left to you."
	end
	return lines
end
