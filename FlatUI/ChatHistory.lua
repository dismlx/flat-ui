local _, ns = ...

local KEY, PART = "chat", "recent chat"
local MOST, HOUR = 200, 3600
local GAME_LINES = 128
local DIM = 0.75
local CHANNEL = "CHAT_MSG_CHANNEL"
local EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
	"CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER",
	"CHAT_MSG_WHISPER_INFORM", CHANNEL }
local HEARD = {}
for _, event in ipairs(EVENTS) do
	HEARD[event] = true
end
local TAGS = { CHAT_MSG_PARTY = "[Party] ", CHAT_MSG_PARTY_LEADER = "[Party Leader] ", CHAT_MSG_RAID = "[Raid] ", CHAT_MSG_RAID_LEADER = "[Raid Leader] ",
	CHAT_MSG_RAID_WARNING = "[Raid Warning] ", CHAT_MSG_INSTANCE_CHAT = "[Instance] ", CHAT_MSG_INSTANCE_CHAT_LEADER = "[Instance Leader] ",
	CHAT_MSG_GUILD = "[Guild] ", CHAT_MSG_OFFICER = "[Officer] " }

local S = { frame = nil, given = {}, withheld = 0, shown = false, session = {}, box = nil, closing = false }
local COPY = { LINES = { { 50, "The last 50 lines" }, { 200, "The last 200 lines" } }, FIRST = 50, WIDTH = 560, HEIGHT = 340, PAD = 8, HELP = 24,
	WHEEL = 42,
	MOVES = { LEFT = true, RIGHT = true, UP = true, DOWN = true, HOME = true, END = true, PAGEUP = true, PAGEDOWN = true },
	SAY = "The last %d %s heard: press %s to copy %s, or select a part first. Escape closes this.",
	COPIED = "Copied %d %s. Paste %s where you like; Escape closes this.",
	COPIED_PART = "Copied what you selected. Paste it where you like; Escape closes this.",
	NONE = "Flat UI: no chat heard yet to copy. Lines are heard while Chat and tooltips is on.",
	FIGHT = "Flat UI: chat is copied out of a fight.",
	OFF = "Flat UI: Chat and tooltips is off, so no chat is heard to copy.",
	HELP = "/flatui copy - the last 50 chat lines in a box to copy from; copy 200 for up to 200" }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

local function Wanted()
	return ns.Enabled(KEY) and Opt("restore") == true and not ns.PartStopped(KEY, PART)
end

local function Hearing()
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, PART)
end

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

local function KindOf(event, index)
	if event == CHANNEL then
		return Plain(index, "number") and index == math.floor(index) and ("CHANNEL%d"):format(index) or "CHANNEL"
	end
	return event:sub(10)
end

local function Whole(line)
	return Plain(line, "table") and Plain(line.time, "number") and Plain(line.event, "string") and HEARD[line.event] == true and Plain(line.sender, "string")
		and Plain(line.text, "string")
		and (line.event ~= CHANNEL or (Plain(line.channel, "string") and Plain(line.index, "number") and line.index == math.floor(line.index)))
end

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
	local session = S.session
	session[#session + 1] = line
	while #session > MOST do
		table.remove(session, 1)
	end
	if not Wanted() then
		return
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

local function Short(sender)
	if type(Ambiguate) == "function" then
		local ok, name = pcall(Ambiguate, sender, "none")
		if ok and Plain(name, "string") and name ~= "" then
			return name
		end
	end
	return sender
end

local function Clock(seconds)
	if type(date) == "function" then
		local ok, text = pcall(date, "%H:%M", seconds)
		if ok and Plain(text, "string") then
			return text
		end
	end
	return "--:--"
end

local function Dimmed(hex)
	local out = {}
	for index = 1, 5, 2 do
		local value = tonumber(hex:sub(index, index + 1), 16) or 255
		out[#out + 1] = ("%02x"):format(math.floor(value * DIM + 0.5))
	end
	return table.concat(out)
end

local function Line(line)
	local name, body = Short(line.sender), nil
	if line.event == "CHAT_MSG_EMOTE" then
		body = name .. " " .. line.text
	elseif line.event == "CHAT_MSG_WHISPER" then
		body = "[" .. name .. "] whispers: " .. line.text
	elseif line.event == "CHAT_MSG_WHISPER_INFORM" then
		body = "To [" .. name .. "]: " .. line.text
	elseif line.event == CHANNEL then
		local label = type(ns.ChatChannelLabel) == "function" and ns.ChatChannelLabel(line.channel) or line.channel
		body = "[" .. (Plain(label, "string") and label or line.channel) .. "] [" .. name .. "]: " .. line.text
	else
		body = (TAGS[line.event] or "") .. "[" .. name .. "]: " .. line.text
	end
	return "[" .. Clock(line.time) .. "] " .. body
end

local function Text(line, colours)
	local kind = KindOf(line.event, line.index)
	local hex = colours[kind]
	if not (Plain(hex, "string") and hex:find("^%x%x%x%x%x%x$")) then
		hex = GameColour(kind) or "ffffff"
	end
	local code = "|cff" .. Dimmed(hex)
	return code .. (Line(line):gsub("|r", "|r" .. code)) .. "|r"
end

local function Room()
	local lines = Opt("history")
	if ns.PartStopped(KEY, "chat history") or not Plain(lines, "number") or lines < 1 then
		return GAME_LINES
	end
	return lines
end

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

local function Recent()
	local session = S.session
	local log = Wanted() and Log(false) or nil
	if not log then
		return session
	end
	local first, out = session[1], {}
	for _, line in ipairs(log.lines) do
		if Whole(line) and (first == nil or line.time < first.time) then
			out[#out + 1] = line
		end
	end
	for _, line in ipairs(session) do
		out[#out + 1] = line
	end
	return out
end

local function Bare(text)
	local out = text:gsub("||", "\001")
	out = out:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:|]*:", ""):gsub("|r", "")
	out = out:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|K.-|k", "")
	return (out:gsub("\001", "||"))
end

function ns.ChatCopyText(count)
	local lines = Recent()
	local most = Plain(count, "number") and math.max(1, math.floor(count)) or COPY.FIRST
	local first = math.max(1, #lines - most + 1)
	local out = {}
	for index = first, #lines do
		local line = lines[index]
		if Whole(line) then
			out[#out + 1] = Bare(Line(line))
		end
	end
	return table.concat(out, "\n"), #out
end

local function Fighting()
	if type(InCombatLockdown) ~= "function" then
		return false
	end
	local ok, fighting = pcall(InCombatLockdown)
	return ok and (ns.IsSecret(fighting) or fighting == true)
end

local function CloseCopy()
	local box = S.box
	if not box or S.closing then
		return
	end
	S.closing = true
	pcall(box.edit.ClearFocus, box.edit)
	pcall(box.frame.Hide, box.frame)
	S.closing = false
end

local function Scroll(box, to)
	local scroll = box.scroll
	pcall(scroll.UpdateScrollChildRect, scroll)
	local ok, range = pcall(scroll.GetVerticalScrollRange, scroll)
	range = ok and ns.Finite(range) and range or 0
	pcall(scroll.SetVerticalScroll, scroll, math.max(0, math.min(range, to)))
end

local function BuildCopy()
	local frame = CreateFrame("Frame", nil, UIParent)
	ns.Own[frame] = true
	frame:SetSize(COPY.WIDTH, COPY.HEIGHT)
	frame:SetFrameStrata("DIALOG")
	pcall(frame.SetClampedToScreen, frame, true)
	frame:EnableMouse(true)
	ns.SetOutlineAlpha(ns.SetOutlineArea(ns.Outline(frame, frame, true), KEY), nil, 0.95)
	local help = ns.OwnText(frame, "OVERLAY", "GameFontNormalSmall")
	if help then
		help:SetPoint("TOPLEFT", frame, "TOPLEFT", COPY.PAD, -7)
		help:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -COPY.PAD, -7)
		pcall(help.SetJustifyH, help, "LEFT")
	end
	local scroll = CreateFrame("ScrollFrame", nil, frame)
	ns.Own[scroll] = true
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", COPY.PAD, -COPY.HELP)
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -COPY.PAD, COPY.PAD)
	ns.SetOutlineFill(ns.SetOutlineArea(ns.Outline(scroll, scroll, true), KEY), 0, 0, 0, 0.5)
	local edit = CreateFrame("EditBox", nil, scroll)
	ns.Own[edit] = true
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject("ChatFontNormal")
	edit:SetSize(COPY.WIDTH - 2 * COPY.PAD, 1)
	edit:SetTextInsets(6, 6, 4, 4)
	pcall(edit.SetMaxLetters, edit, 0)
	pcall(edit.SetMaxBytes, edit, 0)
	scroll:SetScrollChild(edit)
	scroll:EnableMouse(true)
	scroll:SetScript("OnMouseDown", function()
		pcall(edit.SetFocus, edit)
	end)
	local box = { frame = frame, help = help, scroll = scroll, edit = edit }
	local function Wheel(_, delta)
		if ns.Finite(delta) then
			local ok, now = pcall(scroll.GetVerticalScroll, scroll)
			Scroll(box, (ok and ns.Finite(now) and now or 0) - delta * COPY.WHEEL)
		end
	end
	for _, part in ipairs({ scroll, edit }) do
		pcall(part.EnableMouseWheel, part, true)
		part:SetScript("OnMouseWheel", Wheel)
	end
	edit:SetScript("OnCursorChanged", function(_, _, y, _, height)
		if not (ns.Finite(y) and ns.Finite(height)) then
			return
		end
		local okNow, now = pcall(scroll.GetVerticalScroll, scroll)
		local okSeen, seen = pcall(scroll.GetHeight, scroll)
		if not (okNow and okSeen and ns.Finite(now) and ns.Finite(seen)) then
			return
		end
		local at = -y
		if at < now then
			Scroll(box, at)
		elseif at + height > now + seen then
			Scroll(box, at + height - seen)
		end
	end)
	edit:SetScript("OnEscapePressed", CloseCopy)
	edit:SetScript("OnEditFocusLost", CloseCopy)
	edit:SetScript("OnTextChanged", function(self, typed)
		if typed and box.text ~= nil then
			pcall(self.SetText, self, box.text)
			pcall(self.HighlightText, self)
			box.part = nil
		end
	end)
	edit:SetScript("OnMouseDown", function()
		box.part = true
	end)
	edit:SetScript("OnKeyDown", function(_, key)
		if ns.IsSecret(key) or type(key) ~= "string" or box.text == nil or box.text == "" then
			return
		end
		if type(ns.ChatCopyKey) == "function" and ns.ChatCopyKey(key) then
			if box.help then
				local count = box.lines or 0
				box.help:SetText(box.part and COPY.COPIED_PART or COPY.COPIED:format(count, count == 1 and "line" or "lines", count == 1 and "it" or "them"))
			end
		elseif key == "A" then
			for _, name in ipairs({ "IsControlKeyDown", "IsMetaKeyDown" }) do
				local fn = _G[name]
				local ok, held = false, nil
				if type(fn) == "function" then
					ok, held = pcall(fn)
				end
				if ok and not ns.IsSecret(held) and held == true then
					box.part = nil
				end
			end
		elseif COPY.MOVES[key] then
			box.part = true
		end
	end)
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED")
	frame:SetScript("OnEvent", CloseCopy)
	frame:Hide()
	return box
end

local function OpenCopy(count)
	if Fighting() then
		return
	end
	local text, lines = ns.ChatCopyText(count)
	if lines == 0 then
		return
	end
	if not S.box then
		S.box = BuildCopy()
	end
	local box = S.box
	box.text, box.lines, box.part = nil, lines, nil
	box.edit:SetText(text)
	box.text = text
	local mac = false
	if type(IsMacClient) == "function" then
		local ok, answer = pcall(IsMacClient)
		mac = ok and not ns.IsSecret(answer) and answer == true
	end
	if box.help then
		box.help:SetText(COPY.SAY:format(lines, lines == 1 and "line" or "lines", mac and "Cmd+C" or "Ctrl+C", lines == 1 and "it" or "them"))
	end
	box.frame:ClearAllPoints()
	box.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
	box.frame:Show()
	pcall(box.edit.SetFocus, box.edit)
	pcall(box.edit.HighlightText, box.edit)
	local ok, focus = pcall(box.edit.HasFocus, box.edit)
	if ok and not ns.IsSecret(focus) and focus == false then
		CloseCopy()
		return
	end
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		pcall(C_Timer.After, 0, function()
			local okShown, shown = pcall(box.frame.IsShown, box.frame)
			if okShown and shown == true and box.text == text then
				Scroll(box, math.huge)
				pcall(box.edit.HighlightText, box.edit)
			end
		end)
	end
end

local function CopyRefusal()
	if Fighting() then
		return COPY.FIGHT
	elseif not ns.Enabled(KEY) then
		return COPY.OFF
	end
	local _, lines = ns.ChatCopyText(1)
	if lines == 0 then
		return COPY.NONE
	end
	return nil
end

local function CopyLater(count)
	local function run()
		if Hearing() then
			ns.EachPart(KEY, PART, OpenCopy, count)
		end
	end
	if not (type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, 0, run)) then
		run()
	end
end

function ns.ChatCopyLines()
	return COPY.LINES
end

function ns.ChatCopyPick(id)
	if id ~= 50 and id ~= 200 then
		return false
	end
	local refusal = CopyRefusal()
	if refusal then
		return false, refusal
	end
	CopyLater(id)
	return true
end

ns.AddSlash(KEY, "copy", function(rest)
	local count = tonumber((type(rest) == "string" and rest or ""):match("^%s*(%d+)")) or COPY.FIRST
	local refusal = CopyRefusal()
	if refusal then
		print(refusal)
		return
	end
	CopyLater(math.max(1, math.min(MOST, count)))
end, { COPY.HELP })

local function Listen(on)
	if on and not S.frame and type(CreateFrame) == "function" then
		local ok, frame = pcall(CreateFrame, "Frame")
		if ok and Plain(frame, "table") then
			ns.Own[frame] = true
			frame:SetScript("OnEvent", function(_, event, ...)
				if Hearing() then
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

function ns.ChatHistorySync()
	local on = Hearing()
	if on then
		ns.EachPart(KEY, PART, Listen, true)
	else
		pcall(Listen, false)
		CloseCopy()
	end
	if Opt("restoreChannels") ~= true then
		local kept = {}
		for _, line in ipairs(S.session) do
			if line.event ~= CHANNEL then
				kept[#kept + 1] = line
			end
		end
		S.session = kept
	end
	if Opt("restore") ~= true or ns.Get(KEY .. ".enabled") ~= true then
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
