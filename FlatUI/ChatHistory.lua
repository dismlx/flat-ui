local _, ns = ...

-- Show recent chat after a reload (chat.restore on the Chat text page of Chat and tooltips, off by default), with Lines to show again and Numbered
-- channels too. A reload, Flat UI's Uprank and reload among them, empties the chat windows, and the game keeps no chat across one: its history keeper
-- maps the targets of replies only (Blizzard_ChatFrameBase/Shared/HistoryKeeper.lua). This file adds to the chat module and has no switch of its own:
-- Chat.lua calls ns.ChatHistorySync at the end of each refresh.
-- Kept: while the row is on, a frame of Flat UI's own hears what players write, registered only then: say, yell, emotes, party, raid, raid warnings,
-- instance chat, guild, officer and whispers both ways, and with Numbered channels too the numbered channels (the CHAT_MSG_* events of
-- ChatInfoDocumentation.lua; wowless, data/products/wowf/events.yaml). The newest 200 lines of this character are kept in FlatUICharDB.chatLog.lines,
-- each { time (GetServerTime, SystemTimeDocumentation.lua:30-37), event, sender, text } and for a channel its name and number, and in
-- FlatUICharDB.chatLog.colours the colour the game gave each kind of line when one was heard. The game makes the text and the sender secret in its
-- chat messaging lockdown: in an encounter, a challenge mode or a PvP match, and on a map that restricts communication such as a dungeon or a raid
-- (SecretInChatMessagingLockdown, ChatInfoDocumentation.lua:2063-2067; SecretPredicatesDocumentation.lua:65-67). Such a line is never kept, only
-- counted for /flatui status, as EnhanceQoL skips it (EnhanceQoLChatSocial/ChatIM/ChannelHistory.lua:791). Battle.net whispers are other events,
-- not heard: their sender is the client's |K token for a name. Nor is a line the game shows in no chat window kept: a whisper of a Game Master, which
-- goes to a window of its own, and a line it shows only in the letterbox of a cinematic (Mainline/ChatFrameOverrides.lua:306-320). A line the chat
-- filters of other addons drop is heard all the same.
-- Shown: Core.lua listens for a module's events from ADDON_LOADED and hands them to it once it has started (Core.lua:3174-3186, 3226-3244,
-- 3294-3302), so PLAYER_LOGIN, which comes at every login and every reload, is heard through the module (ns.AddEvent) and not on the frame, which
-- is made in the refresh that the start of the module runs inside that same PLAYER_LOGIN. Once a session, one Flat UI line and then the newest kept
-- lines go to the main chat window: up to Lines to show again, none older than an hour, oldest first, each as "[hh:mm] [sender]: text" with the
-- kind before the sender as the game names it, in the colour of its kind (ChatTypeInfo, read only: ChatFrameOverrides.lua:145-151 sets it, and
-- Shared/ChatTypeInfoColors.lua gives every kind white until the chat settings come, so the colour kept from the last session comes first),
-- dimmed. They go out through print(), whose handler writes to DEFAULT_CHAT_FRAME (Blizzard_PrintHandler/Blizzard_PrintHandler.lua:66-72, 93-95),
-- since the AddMessage of a chat window is a Lua method of the game (Shared/ChatFrame.lua:35-41). The links in a text stay as they came.
-- A window keeps only its newest lines (Blizzard_SharedXML/CircularBuffer.lua:29-40): 128 as the game sets it up, or Lines kept per window. At most
-- three quarters of that is printed, the Flat UI line with them, so that line and the other lines of the login stay in the window.
-- Turning the row or its page off stops the hearing and empties FlatUICharDB.chatLog; with Numbered channels too off the lines of channels go.
-- This follows the chat history of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission (EnhanceQoLChatSocial/ChatIM/ChannelHistory.lua:
-- 777-898, 1884-1910, 2293-2305; Settings_ChatFrame.lua:720-735). Left out: its history window with search and lists per channel, the other lines
-- it keeps (system, loot, achievements and Battle.net), and the lines of other characters.

-- A part of its own: "chat history" is the part of Lines kept per window in ChatText.lua (149), which fails and stops apart from this one.
local KEY, PART = "chat", "recent chat"
-- The most lines kept for a character, and the age in seconds of the oldest line shown again.
local MOST, HOUR = 200, 3600
-- The lines a chat window keeps when the game sets it up (ChatFrameMixin:OnLoad, Mainline/ChatFrameOverrides.lua:3).
local GAME_LINES = 128
-- The share of its colour a line shown again keeps.
local DIM = 0.75
local CHANNEL = "CHAT_MSG_CHANNEL"
local EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
	"CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER",
	"CHAT_MSG_WHISPER_INFORM", CHANNEL }
local HEARD = {}
for _, event in ipairs(EVENTS) do
	HEARD[event] = true
end
-- The kind before the sender, as the game names it in English.
local TAGS = { CHAT_MSG_PARTY = "[Party] ", CHAT_MSG_PARTY_LEADER = "[Party Leader] ", CHAT_MSG_RAID = "[Raid] ", CHAT_MSG_RAID_LEADER = "[Raid Leader] ",
	CHAT_MSG_RAID_WARNING = "[Raid Warning] ", CHAT_MSG_INSTANCE_CHAT = "[Instance] ", CHAT_MSG_INSTANCE_CHAT_LEADER = "[Instance Leader] ",
	CHAT_MSG_GUILD = "[Guild] ", CHAT_MSG_OFFICER = "[Officer] " }

-- The frame that hears the lines, the events it is given, the lines withheld since login, and whether the lines were shown this session.
local S = { frame = nil, given = {}, withheld = 0, shown = false }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

-- True while lines are kept: the module on, the row on and the part not stopped.
local function Wanted()
	return ns.Enabled(KEY) and Opt("restore") == true and not ns.PartStopped(KEY, PART)
end

-- The seconds of the server clock, or nil when the client does not say.
local function Now()
	local clock = type(GetServerTime) == "function" and GetServerTime or (type(time) == "function" and time or nil)
	if not clock then
		return nil
	end
	local ok, now = pcall(clock)
	if ok and Plain(now, "number") and now > 0 then
		return now
	end
	return nil
end

-- What is kept for this character: { lines, colours }. A list that is not one is made again with make, else read as none.
local function Log(make)
	local char = ns.Character()
	if type(char) ~= "table" then
		return nil
	end
	local log = char.chatLog
	if type(log) ~= "table" or type(log.lines) ~= "table" then
		if not make then
			return nil
		end
		log = { lines = {}, colours = {} }
		char.chatLog = log
	end
	if type(log.colours) ~= "table" then
		log.colours = {}
	end
	return log
end

local function Forget()
	local char = ns.Character()
	if type(char) == "table" and char.chatLog ~= nil then
		char.chatLog = nil
	end
end

-- The colour the game gives a kind of line now, as "rrggbb", or nil.
local function GameColour(kind)
	local info = ChatTypeInfo
	if not Plain(info, "table") then
		return nil
	end
	info = info[kind]
	if not Plain(info, "table") then
		return nil
	end
	local r, g, b = info.r, info.g, info.b
	if not (Plain(r, "number") and Plain(g, "number") and Plain(b, "number")) then
		return nil
	end
	local function byte(value)
		return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5)
	end
	return ("%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

-- The kind of a line in ChatTypeInfo: the event without CHAT_MSG_, and a channel by its number (Mainline/ChatFrameOverrides.lua:311-353).
local function KindOf(event, index)
	if event == CHANNEL then
		return Plain(index, "number") and index == math.floor(index) and ("CHANNEL%d"):format(index) or "CHANNEL"
	end
	return event:sub(10)
end

-- A line kept, or nil for one that is not whole.
local function Whole(line)
	return Plain(line, "table") and Plain(line.time, "number") and Plain(line.event, "string") and HEARD[line.event] == true and Plain(line.sender, "string")
		and Plain(line.text, "string")
		and (line.event ~= CHANNEL or (Plain(line.channel, "string") and Plain(line.index, "number") and line.index == math.floor(line.index)))
end

-- A line players wrote, as the event gives it: the text, the sender, and for a channel its name (4th) and number (8th); the 6th is the flag of a
-- Game Master and the 16th whether the game shows the line only in the letterbox.
local function Keep(event, ...)
	local text, sender, _, channel, _, flag, _, index = ...
	local letterbox = select(16, ...)
	if ns.IsSecret(text) or ns.IsSecret(sender) then
		S.withheld = S.withheld + 1
		return
	end
	if type(text) ~= "string" or type(sender) ~= "string" or text == "" or sender == "" or sender:find("|K", 1, true) then
		return
	end
	if (Plain(letterbox, "boolean") and letterbox) or (event == "CHAT_MSG_WHISPER" and Plain(flag, "string") and flag == "GM") then
		return
	end
	local now = Now()
	if not now then
		return
	end
	local line = { time = now, event = event, sender = sender, text = text }
	if event == CHANNEL then
		if Opt("restoreChannels") ~= true or not Plain(channel, "string") or channel == "" or not Plain(index, "number") or index ~= math.floor(index) then
			return
		end
		line.channel, line.index = channel, index
	end
	local log = Log(true)
	if not log then
		return
	end
	local lines = log.lines
	lines[#lines + 1] = line
	while #lines > MOST do
		table.remove(lines, 1)
	end
	local kind = KindOf(event, line.index)
	local colour = GameColour(kind)
	if colour then
		log.colours[kind] = colour
	end
end

-- The sender without the realm when it is the player's own (Ambiguate, PlayerScriptDocumentation.lua:22-36).
local function Short(sender)
	if type(Ambiguate) == "function" then
		local ok, name = pcall(Ambiguate, sender, "none")
		if ok and Plain(name, "string") and name ~= "" then
			return name
		end
	end
	return sender
end

-- "hh:mm" of a time of the server clock in the time of this computer.
local function Clock(seconds)
	if type(date) == "function" then
		local ok, text = pcall(date, "%H:%M", seconds)
		if ok and Plain(text, "string") then
			return text
		end
	end
	return "--:--"
end

-- "rrggbb" darkened to the share DIM.
local function Dimmed(hex)
	local out = {}
	for index = 1, 5, 2 do
		local value = tonumber(hex:sub(index, index + 1), 16) or 255
		out[#out + 1] = ("%02x"):format(math.floor(value * DIM + 0.5))
	end
	return table.concat(out)
end

-- The text of a line shown again, in the colour of its kind. A colour code a text ends with |r is begun again after it.
local function Text(line, colours)
	local kind = KindOf(line.event, line.index)
	local hex = colours[kind]
	if not (Plain(hex, "string") and hex:find("^%x%x%x%x%x%x$")) then
		hex = GameColour(kind) or "ffffff"
	end
	local code = "|cff" .. Dimmed(hex)
	local name, body = Short(line.sender), nil
	if line.event == "CHAT_MSG_EMOTE" then
		body = name .. " " .. line.text
	elseif line.event == "CHAT_MSG_WHISPER" then
		body = "[" .. name .. "] whispers: " .. line.text
	elseif line.event == "CHAT_MSG_WHISPER_INFORM" then
		body = "To [" .. name .. "]: " .. line.text
	elseif line.event == CHANNEL then
		body = "[" .. line.channel .. "] [" .. name .. "]: " .. line.text
	else
		body = (TAGS[line.event] or "") .. "[" .. name .. "]: " .. line.text
	end
	return code .. "[" .. Clock(line.time) .. "] " .. (body:gsub("|r", "|r" .. code)) .. "|r"
end

-- The lines the main chat window keeps: Lines kept per window, which ChatText.lua sets on every window at each pass of the module (ChatText.lua:
-- 120-123), the start of the module at login among them, and the game's 128 once that part of ChatText.lua has stopped and put the game's back.
local function Room()
	local lines = Opt("history")
	if ns.PartStopped(KEY, "chat history") or not Plain(lines, "number") or lines < 1 then
		return GAME_LINES
	end
	return lines
end

-- At PLAYER_LOGIN, once a session: one line that says what they are, then the newest kept lines of the last hour, up to Lines to show again and,
-- with that line, no more than three quarters of what the main window keeps.
local function Show()
	if S.shown then
		return
	end
	S.shown = true
	local log, now = Log(false), Now()
	if not (log and now) then
		return
	end
	local most = Opt("restoreLines")
	if not Plain(most, "number") then
		return
	end
	most = math.min(most, math.floor(Room() * 3 / 4) - 1)
	if most < 1 then
		return
	end
	local channels = Opt("restoreChannels") == true
	local picked = {}
	for index = #log.lines, 1, -1 do
		local line = log.lines[index]
		if Whole(line) and line.time > now - HOUR and line.time <= now + 60 and (channels or line.event ~= CHANNEL) then
			table.insert(picked, 1, line)
			if #picked >= most then
				break
			end
		end
	end
	if #picked == 0 then
		return
	end
	print(("Flat UI: recent chat, %d %s from the last hour."):format(#picked, #picked == 1 and "line" or "lines"))
	for _, line in ipairs(picked) do
		print(Text(line, log.colours))
	end
end

ns.AddEvent(KEY, "PLAYER_LOGIN", function()
	if Wanted() then
		ns.EachPart(KEY, PART, Show)
	end
end)

-- The frame hears the events of the lines while the row is on, and channels only with Numbered channels too.
local function Listen(on)
	if on and not S.frame and type(CreateFrame) == "function" then
		local ok, frame = pcall(CreateFrame, "Frame")
		if ok and Plain(frame, "table") then
			ns.Own[frame] = true
			frame:SetScript("OnEvent", function(_, event, ...)
				if Wanted() then
					ns.EachPart(KEY, PART, Keep, event, ...)
				end
			end)
			S.frame = frame
		end
	end
	local frame = S.frame
	if not frame then
		return
	end
	local channels = Opt("restoreChannels") == true
	for _, event in ipairs(EVENTS) do
		local want = on and (event ~= CHANNEL or channels)
		if want and not S.given[event] then
			S.given[event] = pcall(frame.RegisterEvent, frame, event) or nil
		elseif not want and S.given[event] then
			pcall(frame.UnregisterEvent, frame, event)
			S.given[event] = nil
		end
	end
end

-- The lines of channels go when Numbered channels too is off.
local function DropChannels()
	local log = Log(false)
	if not log then
		return
	end
	local function channel(line)
		return Plain(line, "table") and line.event == CHANNEL
	end
	local any = false
	for _, line in ipairs(log.lines) do
		any = any or channel(line)
	end
	if not any then
		return
	end
	local kept = {}
	for _, line in ipairs(log.lines) do
		if not channel(line) then
			kept[#kept + 1] = line
		end
	end
	log.lines = kept
end

-- Called by Chat.lua at the end of every refresh of the module: at its start, at a change of a row, when it goes off and when it stops. As in
-- ChatLinks.lua, a failure counts toward stopping the part while it is to work, and is let go while it only stops hearing.
function ns.ChatHistorySync()
	local on = Wanted()
	if on then
		ns.EachPart(KEY, PART, Listen, true)
	else
		pcall(Listen, false)
	end
	if Opt("restore") ~= true or ns.Get(KEY .. ".enabled") ~= true then
		-- The row or its page is off: nothing more is heard, and what was kept goes.
		Forget()
	elseif Opt("restoreChannels") ~= true then
		DropChannels()
	end
end

ns.AddStatus(KEY, function()
	if not Wanted() then
		return {}
	end
	local log = Log(false)
	local kept = log and #log.lines or 0
	local line = ("Recent chat: %d %s kept for this character"):format(kept, kept == 1 and "line" or "lines")
	if S.withheld > 0 then
		line = line .. (", %d the game withheld left out since login"):format(S.withheld)
	end
	return { line .. "." }
end)
