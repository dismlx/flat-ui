local _, ns = ...

local E = ns.Errands
local part = E.Part({ label = "Quests" })

local TALK_GAP = 2
local LOAD_WAIT = 2
local MAX_PICKS = 20
local GREEN = 2
local QUEST_FLAG, AVAILABLE = 1, 0
local NPC_KINDS = { Creature = true, Vehicle = true }
local KEYS = {
	shift = { label = "Shift", down = function() return IsShiftKeyDown end },
	ctrl = { label = "Ctrl", down = function() return IsControlKeyDown end },
	alt = { label = "Alt", down = function() return IsAltKeyDown end },
}
local SAY = {
	full = "Your quest log is full (%d of %d), so %s is left to you.",
	money = "%s takes %s to hand in, so it is left to you.",
	currency = "%s takes a currency to hand in, so it is left to you.",
	item = "%s takes %s, so it is left to you.",
	unrated = "%s takes %s, and the game does not say how good it is, so it is left to you.",
	pvp = "%s would flag you for PvP, so it is left to you.",
}
local WHY = {
	low = "it is a low-level quest", repeatable = "it can be done again", money = "it takes money", currency = "it takes a currency",
	item = "it takes an item of green quality or better", pvp = "it flags you for PvP", full = "your quest log was full",
	unknown = "the game did not say what it takes", unrated = "the game did not say how good an item it takes is",
}

local talk
local pending
local waits = 0
local asked = { accept = {}, turnIn = {} }
local done = { accepted = 0, handedIn = 0, options = 0 }
local lastLeft
local handedIn = {}
local kept, spoken = {}, {}
local RewardWanted, Unmark, Mark, FollowRewards

local Decide

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

local function Log(name, ...)
	local log = C_QuestLog
	if type(log) ~= "table" or ns.IsSecret(log) then
		return nil
	end
	return E.Ask(log[name], ...)
end

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

local function Key()
	return KEYS[E.Opt("questKey")] or KEYS.shift
end

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

local function Saved()
	local lists = E.Lists()
	if not lists then
		return nil
	end
	lists.npcs = type(lists.npcs) == "table" and lists.npcs or {}
	lists.gossip = type(lists.gossip) == "table" and lists.gossip or {}
	return lists
end

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

local function Setting(read)
	local ok, on = pcall(read)
	return ok and not ns.IsSecret(on) and on == true
end

local function Table(value)
	return not ns.IsSecret(value) and type(value) == "table"
end

local function Theirs()
	local other, questie = _G.EnhanceQoL, _G.Questie
	local otherQuests = Table(other) and Setting(function()
		return other.db.autoChooseQuest
	end)
	local otherGossip = Table(other) and Setting(function()
		return other.db.autoChooseGossip
	end)
	local questieAccept = Table(questie) and Setting(function()
		return questie.db.profile.autoAccept.enabled
	end)
	local questieTurnIn = Table(questie) and Setting(function()
		return questie.db.profile.autocomplete
	end)
	return { accept = otherQuests or questieAccept, turnIn = otherQuests or questieTurnIn, gossip = otherGossip, otherQuests = otherQuests,
		otherGossip = otherGossip, questieAccept = questieAccept, questieTurnIn = questieTurnIn }
end

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

local function Closed(window)
	if talk and talk.open and talk.window == window then
		talk.open = false
		EndLater(talk)
	end
end

local function MayAct(current, unit)
	return ns.Enabled("errands") and not current.paused and current.picks < MAX_PICKS and not E.Fighting() and not Withheld(unit)
		and not Skipped(unit)
end

local function Title()
	local title = E.Ask(GetTitleText)
	return type(title) == "string" and title ~= "" and title or nil
end

local function Listed(frequency, repeatable)
	if repeatable == true or frequency == true or (ns.Finite(frequency) and frequency > 0) then
		return true
	end
	if repeatable == false and (frequency == nil or frequency == false or frequency == 0) then
		return false
	end
	return nil
end

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

local function Unwanted(low, repeats)
	if repeats == true and E.Opt("questRepeat") ~= true then
		return "repeatable"
	end
	if low == true and E.Opt("questLow") ~= true then
		return "low"
	end
	return nil
end

local function LogFull()
	local _, quests = Log("GetNumQuestLogEntries")
	local most = Log("GetMaxNumQuestsCanAccept")
	if not ns.Finite(most) or most <= 0 then
		most = ns.Finite(_G.MAX_QUESTLOG_QUESTS) and _G.MAX_QUESTLOG_QUESTS or (ns.Finite(_G.MAX_QUESTS) and _G.MAX_QUESTS or nil)
	end
	if ns.Finite(quests) then
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

local function Loaded(id)
	local log = C_QuestLog
	if type(log) ~= "table" or type(log.GetQuestDifficultyLevel) ~= "function" then
		return true
	end
	local level = Log("GetQuestDifficultyLevel", id)
	return ns.Finite(level) and level > 0
end

Decide = function(current, id, final)
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

local function Detail(fromItem)
	local auto = E.Ask(QuestGetAutoAccept) == true
	if ns.IsSecret(fromItem) or (fromItem ~= nil and fromItem ~= 0) or E.Ask(QuestIsFromAdventureMap) == true
		or (auto and E.Ask(QuestIsFromAreaTrigger) == true) then
		return
	end
	local current = Talk("questnpc", "quest")
	if E.Opt("questAccept") ~= true or not MayAct(current, "questnpc") or Theirs().accept then
		return
	end
	if auto then
		return
	end
	local id = E.Ask(GetQuestID)
	if not ns.Finite(id) or id <= 0 or current.left[id] then
		return
	end
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

local function Flagged(option)
	local flags = Field(option, "flags")
	return ns.Finite(flags) and math.floor(flags) % 2 == QUEST_FLAG
end

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

local function Options()
	local gossip = C_GossipInfo
	local options = type(gossip) == "table" and Entries(gossip.GetOptions) or {}
	table.sort(options, function(a, b)
		local x, y = Field(a, "orderIndex"), Field(b, "orderIndex")
		return (ns.Finite(x) and x or 0) < (ns.Finite(y) and y or 0)
	end)
	return options
end

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
		if Field(only, "selectOptionWhenOnlyOption") == true and E.Ask(C_GossipInfo.ForceGossip) ~= true then
			return
		end
		if not current.tried[OptionKey(only)] and Plain(only) then
			PickOption(current, only)
		end
	end
end

local function Gossip()
	local current = Talk("npc", "gossip")
	local gossip = C_GossipInfo
	if type(gossip) ~= "table" or ns.IsSecret(gossip) then
		return
	end
	local options = Options()
	Remember(options)
	if not MayAct(current, "npc") then
		return
	end
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

local COIN, COIN_SIZE, COIN_INSET = "Interface\\MoneyFrame\\UI-GoldIcon", 14, 3
local HALO, HALO_SIZE, HALO_ALPHA = "Interface\\AddOns\\" .. (... or "FlatUI") .. "\\Media\\Glow.tga", 26, 0.4
local COIN_TEXT = { 1, 0.82, 0 }
local MOST_CHOICES, MOST_TRIES = 10, 10
local ITEM_TIP = 0
local reward = { waiting = false, tries = 0, built = setmetatable({}, { __mode = "k" }) }

function RewardWanted()
	return E.On("rewardValue") and not ns.PartStopped("errands", part.label)
end

local function SellPrice(link)
	if type(C_Item) ~= "table" or type(C_Item.GetItemInfo) ~= "function" then
		return nil
	end
	local ok, _, _, _, _, _, _, _, _, _, _, price = pcall(C_Item.GetItemInfo, link)
	if not ok or not ns.Finite(price) or price < 0 then
		return nil
	end
	return price
end

local function Best()
	local choices = E.Ask(GetNumQuestChoices)
	if not ns.Finite(choices) or choices < 2 then
		return nil
	end
	local best, most, tie = nil, 0, false
	for index = 1, math.min(choices, MOST_CHOICES) do
		local _, _, count = E.Ask(GetQuestItemInfo, "choice", index)
		local link = E.Ask(GetQuestItemLink, "choice", index)
		local price = type(link) == "string" and SellPrice(link) or nil
		if not price then
			return nil, nil, true
		end
		local worth = price * (ns.Finite(count) and count >= 1 and math.floor(count) or 1)
		if worth > most then
			best, most, tie = index, worth, false
		elseif worth == most and worth > 0 then
			tie = true
		end
	end
	if tie or not best then
		return nil
	end
	return best, most
end

local function Visible(frame)
	local ok, shown = pcall(frame.IsVisible, frame)
	return ok and not ns.IsSecret(shown) and shown == true
end

local function ChoiceButton(index)
	local buttons = Field(_G.QuestInfoRewardsFrame, "RewardButtons")
	if type(buttons) ~= "table" then
		return nil
	end
	for slot = 1, 40 do
		local button = Field(buttons, slot)
		if type(button) ~= "table" then
			return nil
		end
		if not ns.Forbidden(button) and Field(button, "type") == "choice" and Visible(button) then
			local ok, id = pcall(button.GetID, button)
			if ok and ns.Finite(id) and id == index then
				return button
			end
		end
	end
	return nil
end

local function Coin()
	if reward.frame then
		return reward.frame
	end
	local frame = CreateFrame("Frame", nil, UIParent)
	ns.Own[frame] = true
	frame:Hide()
	frame:EnableMouse(false)
	frame:SetSize(COIN_SIZE, COIN_SIZE)
	local halo = frame:CreateTexture(nil, "ARTWORK")
	ns.Own[halo] = true
	halo:SetSize(HALO_SIZE, HALO_SIZE)
	halo:SetPoint("CENTER", frame, "CENTER", 0, 0)
	halo:SetTexture(HALO)
	halo:SetBlendMode("ADD")
	halo:SetVertexColor(COIN_TEXT[1], COIN_TEXT[2], COIN_TEXT[3], HALO_ALPHA)
	local icon = frame:CreateTexture(nil, "OVERLAY")
	ns.Own[icon] = true
	icon:SetAllPoints(frame)
	icon:SetTexture(COIN)
	frame:SetScript("OnUpdate", function(self)
		if not (reward.button and Visible(reward.button)) then
			self:Hide()
			reward.index, reward.value, reward.button = nil, nil, nil
		end
	end)
	reward.frame = frame
	return frame
end

function Unmark()
	reward.index, reward.value, reward.button = nil, nil, nil
	if reward.frame then
		reward.frame:Hide()
		reward.frame:ClearAllPoints()
		reward.frame:SetParent(UIParent)
	end
end

local function TipLine(tooltip, data)
	local ok, owner = pcall(tooltip.GetOwner, tooltip)
	local counted, shown = pcall(tooltip.NumLines, tooltip)
	if not (ok and reward.button and rawequal(owner, reward.button) and counted and ns.Finite(shown)) then
		return
	end
	local record = reward.built[tooltip]
	if record and record.data == data and shown >= record.lines then
		return
	end
	local text = ("Sells for %s, the most of these rewards"):format(E.Money(reward.value))
	if pcall(tooltip.AddLine, tooltip, text, COIN_TEXT[1], COIN_TEXT[2], COIN_TEXT[3]) then
		reward.built[tooltip] = { data = data, lines = shown + 1 }
	end
end

local function Post()
	if reward.posted then
		return
	end
	reward.posted = true
	local processor = _G.TooltipDataProcessor
	local kinds = type(Enum) == "table" and not ns.IsSecret(Enum) and Field(Enum, "TooltipDataType") or nil
	local item = Field(kinds, "Item")
	if type(processor) ~= "table" or ns.IsSecret(processor) or type(processor.AddTooltipPostCall) ~= "function" then
		return
	end
	pcall(processor.AddTooltipPostCall, ns.Finite(item) and item or ITEM_TIP, function(tooltip, data)
		if reward.index and rawequal(tooltip, GameTooltip) then
			E.Run(part, TipLine, tooltip, data)
		end
	end)
end

function Mark()
	reward.waiting = false
	Unmark()
	if not RewardWanted() or Field(_G.QuestInfoFrame, "questLog") == true then
		return
	end
	local index, value, unknown = Best()
	if unknown and reward.tries < MOST_TRIES then
		reward.waiting, reward.tries = true, reward.tries + 1
	end
	local button = index and ChoiceButton(index)
	if not button then
		return
	end
	local frame = Coin()
	local icon = Field(button, "Icon")
	if type(icon) ~= "table" or ns.Forbidden(icon) then
		icon = button
	end
	frame:SetParent(button)
	local okStrata, strata = pcall(button.GetFrameStrata, button)
	local okLevel, level = pcall(button.GetFrameLevel, button)
	frame:SetFrameStrata(okStrata and type(strata) == "string" and strata or "HIGH")
	frame:SetFrameLevel(okLevel and ns.Finite(level) and math.min(level + 5, 9000) or 100)
	frame:ClearAllPoints()
	if not pcall(frame.SetPoint, frame, "CENTER", icon, "TOPRIGHT", -COIN_INSET, -COIN_INSET) then
		frame:SetPoint("CENTER", button, "TOPLEFT", 39 - COIN_INSET, -COIN_INSET)
	end
	reward.index, reward.value, reward.button = index, value, button
	frame:Show()
	Post()
end

local function Remark()
	reward.tries = 0
	Mark()
	if not reward.index and RewardWanted() and type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		pcall(C_Timer.After, 0, function()
			if not reward.index then
				E.Run(part, Mark)
			end
		end)
	end
end

local function Follow()
	if RewardWanted() or reward.index then
		E.Run(part, Remark)
	end
end

function FollowRewards()
	if not reward.followedDisplay then
		reward.followedDisplay = ns.FollowGlobal("QuestInfo_Display", Follow) == true
	end
	if not reward.followed then
		reward.followed = ns.FollowGlobal("QuestInfo_ShowRewards", Follow) == true
	end
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
	Unmark()
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
ns.AddEvent("errands", "GET_ITEM_INFO_RECEIVED", function()
	E.Run(part, Mark)
end, function()
	return reward.waiting
end)
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
	FollowRewards()
end

function part.Refresh()
	kept = {}
	if not ns.Enabled("errands") or E.Opt("questAccept") ~= true then
		pending = nil
	end
	if not RewardWanted() then
		Unmark()
	elseif E.Shown(QuestFrame) then
		reward.tries = 0
		Mark()
	end
end

local function Trim(text)
	return tostring(text or ""):match("^%s*(.-)%s*$")
end

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
	if others.otherQuests and (E.Opt("questAccept") == true or E.Opt("questTurnIn") == true) then
		lines[#lines + 1] = "Quests: another addon's quest automation is on, so quests are left to it."
	end
	if others.otherGossip and (mode == "saved" or mode == "all") then
		lines[#lines + 1] = "Quests: another addon's gossip automation is on, so gossip is left to it."
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
