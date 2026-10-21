local _, ns = ...

-- Party cooldowns shared between players who run Flat UI. Each client sends its own cooldowns as addon messages, text only, and
-- starts the timers of the members it hears from. The messages, all with the prefix "FlatUI" and the version 1 first:
--   1 H <GUID or -> <spell ID> ...   the abilities the sender has, sent on joining, on a roster change and when his spells change
--   1 C <spell ID> [seconds]         his own use of an ability of the list, with the length of its cooldown when the game gives it plain
--   1 S <spell ID>:<seconds left> ...  his running timers, sent only as the answer to an H
-- Only plain values of the player's own are put in a message (SendAddonMessage takes no secret argument). The channel is chosen as
-- Blizzard's cooldown broadcaster chooses it (Blizzard_CooldownBroadcaster.lua:146-152), at most 250 characters to a message and a bucket
-- of 10 sends refilled 1 a second (the same file, line 8, and MessageQueue.lua:3-4; the limits of the call itself are not seen). The
-- game's own answer rules: a chat lockdown, or the result AddOnMessageLockdown, closes sharing until the Chat restriction ends.
-- Receiving does not depend on the switch. The helpers are in one table, S.

local KEY = "partycd"
local PREFIX = "FlatUI"
local VERSION = "1"
local LENGTH = 250
local BUCKET, REFILL = 10, 1
local LATE = 0.5
local HELLO_WAIT = 1
local MOST_QUEUE = 60
local MOST_ID, MOST_SECONDS = 9999999, 3600
local GCD = 1.5
local LINE_BLOCKED = "Party cooldowns: the game blocks addon messages here, so cooldowns are not shared."

local IsSecret = ns.IsSecret
local T = ns.Tracking
local S = { queue = {}, pending = {}, tokens = BUCKET, senders = {} }
ns.PartySync = S

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

local function Text(fn, ...)
	local answer = T.Ask(fn, ...)
	return Plain(answer, "string") and answer ~= "" and answer or nil
end

-- A whole number from 1 to most, written in digits, or nil.
local function Whole(text, most)
	if type(text) ~= "string" or #text > 7 or not text:match("^%d+$") then
		return nil
	end
	local number = tonumber(text)
	return number >= 1 and number <= most and number or nil
end

local function Timers()
	return type(C_Timer) == "table" and type(C_Timer.After) == "function"
end

-- True when this player shares his cooldowns: the module is on and so is the switch.
function S.Active()
	if not (ns.Enabled(KEY) and ns.Get(KEY .. ".share") == true) then
		return false
	end
	local P = ns.PartyCooldownsModule
	return not (P and P.Look() == "raid")
end

-- True when addon messages can pass now.
function S.Open()
	return not S.closed and ns.MessagesOpen() ~= false
end

-- The ability of a class that a cast ID is, or nil.
function S.Ability(class, id)
	local by = ns.ABILITY_BY_CAST
	if type(by) ~= "table" or type(ns.ABILITIES) ~= "table" then
		return nil
	end
	for _, group in ipairs({ type(class) == "string" and class or "ALL", "ALL" }) do
		local index = by[group] and by[group][id]
		local a = index and ns.ABILITIES[index]
		if a then
			return a
		end
	end
	return nil
end

-- The channel, as Blizzard's cooldown broadcaster picks it: the instance group's, else the raid's, else the party's.
function S.Channel()
	local channel = T.Ask(IsInRaid) == true and "RAID" or (T.Ask(IsInGroup) == true and "PARTY" or nil)
	local instance, home = _G.LE_PARTY_CATEGORY_INSTANCE, _G.LE_PARTY_CATEGORY_HOME
	if channel and instance and home and T.Ask(IsInGroup, instance) == true and T.Ask(IsInGroup, home) ~= true then
		return "INSTANCE_CHAT"
	end
	return channel
end

-- Sending -------------------------------------------------------------------------------------------------------------------------

-- The game blocks messages: nothing waits to be sent, and the status says so. A result of AddOnMessageLockdown keeps it closed until
-- the Chat restriction ends.
function S.Block(closed)
	S.blocked = true
	S.closed = S.closed or closed or nil
	S.queue, S.pending = {}, {}
	ns.Note(KEY, LINE_BLOCKED)
end

function S.Unblock()
	if S.blocked or S.closed then
		S.blocked, S.closed = nil, nil
		ns.ClearNote(KEY, LINE_BLOCKED)
	end
end

-- Sends one message. true: sent. false: not sent and dropped. nil: the game asks to wait.
function S.Send(text)
	local info = type(C_ChatInfo) == "table" and C_ChatInfo or nil
	if not (info and type(info.SendAddonMessage) == "function") then
		return false
	end
	if S.closed or ns.MessagesOpen() == false then
		S.Block()
		return false
	end
	S.Unblock()
	local channel = S.Channel()
	if not channel then
		return false
	end
	local ok, result = pcall(info.SendAddonMessage, PREFIX, text, channel)
	if not ok or IsSecret(result) then
		return false
	end
	local codes = type(Enum) == "table" and type(Enum.SendAddonMessageResult) == "table" and Enum.SendAddonMessageResult or {}
	if result == (codes.AddOnMessageLockdown or 11) then
		S.Block(true)
		return false
	elseif result == (codes.AddonMessageThrottle or 3) then
		return nil
	end
	return result == (codes.Success or 0) or result == true
end

-- Sends what the bucket allows and keeps the rest for the next second.
function S.Drain()
	local now = T.Now()
	S.at = S.at or now
	S.tokens = math.min(BUCKET, S.tokens + math.max(0, now - S.at) * REFILL)
	S.at = now
	while #S.queue > 0 and S.tokens >= 1 do
		local text = table.remove(S.queue, 1)
		local sent = S.Send(text)
		if sent == nil then
			table.insert(S.queue, 1, text)
			break
		elseif sent then
			S.tokens = S.tokens - 1
		end
	end
	if #S.queue > 0 and not S.waiting and Timers() then
		S.waiting = true
		C_Timer.After(1, function()
			S.waiting = nil
			ns.Try(KEY, S.Drain)
		end)
	end
end

function S.Push(text)
	if #S.queue >= MOST_QUEUE then
		table.remove(S.queue, 1)
	end
	S.queue[#S.queue + 1] = text
	S.Drain()
end

-- Messages of at most LENGTH characters: the head and as many items as fit, then the head again.
function S.Pack(head, items)
	local out, line = {}, head
	for _, item in ipairs(items) do
		if #line + #item + 1 > LENGTH then
			out[#out + 1] = line
			line = head
		end
		line = line .. " " .. item
	end
	out[#out + 1] = line
	return out
end

-- The length of the cooldown a spell just started, in whole seconds, when the game gives it plain. nil when it does not, false when
-- only the global cooldown runs or none has started yet.
function S.Seconds(id)
	local spells = type(C_Spell) == "table" and C_Spell or {}
	local info = T.Ask(spells.GetSpellCooldown, id)
	if type(info) ~= "table" then
		return nil
	end
	local ok, duration, global = pcall(function()
		return info.duration, info.isOnGCD
	end)
	if not ok or not Plain(duration, "number") or not ns.Finite(duration) then
		return nil
	end
	if duration <= GCD or global == true then
		return false
	end
	local seconds = math.floor(duration + 0.5)
	return seconds <= MOST_SECONDS and seconds or nil
end

-- A cast of the player's own that the game let through. An ability of the list waits for the next change of cooldowns, which is when the
-- length of its cooldown can be read, and goes out then, or after half a second without it.
function S.OnCast(unit, spell)
	if (unit ~= "player" and unit ~= "pet") or not S.Active() then
		return
	end
	local owner, class = ns.PartyCooldownsModule.Who(unit)
	local a = owner and S.Ability(class, spell)
	if not a then
		return
	end
	T.Cast(owner, class, spell, T.Now())
	S.pending[a.key] = { a = a, id = spell, owner = owner }
	if not S.late and Timers() then
		S.late = true
		C_Timer.After(LATE, function()
			S.late = nil
			ns.Try(KEY, S.Flush, true)
		end)
	end
end

function S.Flush(all)
	for key, item in pairs(S.pending) do
		local seconds = S.Seconds(item.id)
		if seconds ~= false or all then
			S.pending[key] = nil
			local text = ("%s C %d"):format(VERSION, item.id)
			if seconds then
				local book = T.Book(item.owner, true)
				local timer = book and book.timers[key]
				if timer then
					timer.seconds = seconds
				end
				text = text .. " " .. seconds
			end
			S.Push(text)
		end
	end
end

function S.Cooldown()
	if next(S.pending) ~= nil then
		S.Flush(false)
	end
end

-- The abilities the player has, to the party.
function S.SendHello()
	if not S.Active() or not S.Channel() then
		return
	end
	local P = ns.PartyCooldownsModule
	local class = Text(UnitClassBase, "player")
	local ids, done = {}, {}
	for _, group in ipairs({ class or "ALL", "ALL" }) do
		for _, index in ipairs(type(ns.ABILITIES_BY_CLASS) == "table" and ns.ABILITIES_BY_CLASS[group] or {}) do
			local a = ns.ABILITIES[index]
			if a and not done[index] and not a.flags:find("n", 1, true)
				and (a.classes or a.flags:find("t", 1, true) or a.flags:find("r", 1, true) or a.flags:find("p", 1, true)) and P.Knows(a) == true then
				done[index] = true
				ids[#ids + 1] = tostring(a.casts[1])
			end
		end
	end
	for _, text in ipairs(S.Pack(("%s H %s"):format(VERSION, Text(UnitGUID, "player") or "-"), ids)) do
		S.Push(text)
	end
end

-- One hello for a burst of changes.
function S.Hello()
	if not S.Active() or S.helloWait or not S.Channel() then
		return
	end
	if Timers() then
		S.helloWait = true
		C_Timer.After(HELLO_WAIT, function()
			S.helloWait = nil
			ns.Try(KEY, S.SendHello)
		end)
	else
		S.SendHello()
	end
end

-- The running timers of the player, to the party: the answer to a hello.
function S.Answer()
	local P = ns.PartyCooldownsModule
	local owner, class = P.Who("player")
	if not owner then
		return
	end
	local now, items, done = T.Now(), {}, {}
	for _, group in ipairs({ class or "ALL", "ALL" }) do
		for _, index in ipairs(type(ns.ABILITIES_BY_CLASS) == "table" and ns.ABILITIES_BY_CLASS[group] or {}) do
			local a = ns.ABILITIES[index]
			local start, seconds = nil, nil
			if a and not done[index] then
				done[index] = true
				start, seconds = T.Timer(owner, a.key)
			end
			local left = start and math.floor(start + seconds - now + 0.5)
			if left and left >= 1 and left <= MOST_SECONDS then
				items[#items + 1] = ("%d:%d"):format(a.casts[1], left)
			end
		end
	end
	if #items > 0 then
		for _, text in ipairs(S.Pack(VERSION .. " S", items)) do
			S.Push(text)
		end
	end
end

-- Listening, and what the settings and the game change -----------------------------------------------------------------------------

function S.Start()
	local info = type(C_ChatInfo) == "table" and C_ChatInfo or nil
	if info and type(info.RegisterAddonMessagePrefix) == "function" then
		pcall(info.RegisterAddonMessagePrefix, PREFIX)
	end
	T.Subscribe("partysync", function(unit, spell)
		ns.Try(KEY, S.OnCast, unit, spell)
	end)
	S.on = nil
	S.Refresh()
end

-- The player's own casts are heard while he shares and is in a group; the abilities go out when he starts to.
function S.Refresh()
	local active = S.Active() and S.Channel() ~= nil
	if active then
		T.Hear("partysync", "player", true, false)
		T.Hear("partysync", "pet", true, false)
		if not S.on then
			S.Hello()
		end
	else
		T.Deafen("partysync", "player")
		T.Deafen("partysync", "pet")
		S.queue, S.pending = {}, {}
	end
	S.on = active
end

function S.Roster()
	S.Refresh()
	S.Hello()
end

-- The Chat restriction ends: messages pass again.
function S.Restriction(kind, state)
	local types = type(Enum) == "table" and type(Enum.AddOnRestrictionType) == "table" and Enum.AddOnRestrictionType or {}
	local states = type(Enum) == "table" and type(Enum.AddOnRestrictionState) == "table" and Enum.AddOnRestrictionState or {}
	if Plain(kind, "number") and Plain(state, "number") and kind == (types.Chat or 5) and state == (states.Inactive or 0) and (S.blocked or S.closed) then
		S.Unblock()
	end
end

-- Receiving -----------------------------------------------------------------------------------------------------------------------

-- The party unit that a sender is: by name, with or without the realm, else by the GUID his hello carried. nil for anyone else.
function S.Match(sender, guid)
	local base = sender:match("^([^%-]+)") or sender
	for index = 1, 4 do
		local unit = "party" .. index
		local ok, name, realm = pcall(UnitName, unit)
		if ok and Plain(name, "string") and name ~= "" then
			realm = Plain(realm, "string") and realm ~= "" and realm or nil
			if sender == name or (realm and sender == name .. "-" .. realm) or (not realm and base == name) then
				return unit
			end
		end
	end
	local known = guid or S.senders[sender]
	if known then
		for index = 1, 4 do
			local unit = "party" .. index
			if Text(UnitGUID, unit) == known then
				if guid then
					S.senders[sender] = guid
				end
				return unit
			end
		end
	end
	return nil
end

-- The numbers of a message, checked before anything is changed: { guid = , ids = , seconds = , left = } or nil when the text is broken.
function S.Parse(kind, tokens)
	local out = { ids = {}, left = {} }
	if kind == "H" then
		local guid = tokens[1]
		if not (guid and #guid <= 64 and guid:match("^[%w%-]+$")) then
			return nil
		end
		out.guid = guid ~= "-" and guid or nil
		for position = 2, #tokens do
			out.ids[#out.ids + 1] = Whole(tokens[position], MOST_ID) or false
		end
	elseif kind == "C" then
		if #tokens < 1 or #tokens > 2 then
			return nil
		end
		out.ids[1] = Whole(tokens[1], MOST_ID) or false
		if tokens[2] then
			out.seconds = Whole(tokens[2], MOST_SECONDS) or false
		end
	elseif kind == "S" then
		for position, token in ipairs(tokens) do
			local id, left = token:match("^(%d+):(%d+)$")
			out.ids[position], out.left[position] = Whole(id, MOST_ID) or false, Whole(left, MOST_SECONDS) or false
		end
	else
		return nil
	end
	for _, id in ipairs(out.ids) do
		if id == false then
			return nil
		end
	end
	for _, left in pairs(out.left) do
		if left == false then
			return nil
		end
	end
	if out.seconds == false then
		return nil
	end
	return out
end

-- CHAT_MSG_ADDON: prefix, text, channel, sender. Another prefix, a sender who is not in the party, a withheld value and broken text are
-- ignored.
function S.Receive(prefix, text, _, sender)
	if not (Plain(prefix, "string") and prefix == PREFIX and Plain(text, "string") and Plain(sender, "string")) or #text > 255 or sender == "" then
		return
	end
	local version, kind, rest = text:match("^(%d+) (%u)(.*)$")
	if version ~= VERSION or (rest ~= "" and rest:sub(1, 1) ~= " ") then
		return
	end
	local tokens = {}
	for token in rest:gmatch("%S+") do
		tokens[#tokens + 1] = token
		if #tokens > 80 then
			return
		end
	end
	local got = S.Parse(kind, tokens)
	local unit = got and S.Match(sender, got.guid)
	if not unit then
		return
	end
	local P = ns.PartyCooldownsModule
	local owner, class = P.Who(unit)
	local book = owner and type(class) == "string" and T.Book(owner, true)
	if not book then
		return
	end
	book.shares = true
	local now = T.Now()
	if kind == "H" then
		for _, id in ipairs(got.ids) do
			local a = S.Ability(class, id)
			if a then
				book.seen[a.key] = true
			end
		end
	elseif kind == "C" then
		local a = S.Ability(class, got.ids[1])
		if a then
			T.Use(owner, class, a, now, got.ids[1])
			local timer = got.seconds and book.timers[a.key]
			if timer then
				timer.seconds = got.seconds
			end
		end
	else
		for position, id in ipairs(got.ids) do
			local a = S.Ability(class, id)
			if a then
				book.seen[a.key] = true
				book.timers[a.key] = { start = now, seconds = got.left[position] }
			end
		end
	end
	P.Render()
	if kind == "H" and S.Active() then
		S.Answer()
	end
end

-- True when this member's client sends cooldowns and messages can pass now: his ready icons can be trusted.
function S.Shares(owner)
	local book = T.Book(owner)
	return book ~= nil and book.shares == true and S.Open()
end
