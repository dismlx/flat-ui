local _, ns = ...

local KEY = "chat"
local LINKS, TIPS, CHANNELS, MENTIONS = "web links", "link tooltips", "channel names", "name in chat"
local ROW = { [LINKS] = "webLinks", [TIPS] = "linkTips", [MENTIONS] = "mentions" }
local PREFIX = "addon:FlatUI:url:"
local LINK_COLOUR = "ff6cb8ff"
local EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_AFK", "CHAT_MSG_DND",
	"CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT",
	"CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_GUILD_DISCORD", "CHAT_MSG_CHANNEL", "CHAT_MSG_COMMUNITIES_CHANNEL",
	"CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_BN_INLINE_TOAST_BROADCAST", "CHAT_MSG_SYSTEM" }
local TIP_KINDS = { item = true, spell = true, enchant = true, achievement = true, quest = true }
local CLOSING = { T = "|t", A = "|a", K = "|k" }
local BOX_WIDTH, BOX_HEIGHT, FIELD_HEIGHT = 380, 50, 20
local WATCH = 0.1
local FLASH_GAP = 10
local MENTION_EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
	"CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
	"CHAT_MSG_CHANNEL" }
local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
local WORDS = { SHORT = 2, LONG = 24, MOST = 20,
	ADDED = "Flat UI: \"%s\" is coloured in chat now, as your name is.",
	OFF = " Turn on Your name in chat (Chat text) for it to show.",
	HAVE = "Flat UI: \"%s\" is coloured already.",
	FULL = "Flat UI: at most 20 other words; /flatui words remove one first.",
	BAD = "Flat UI: give one word of 2 to 24 letters, with no space, as /flatui words add tank.",
	REMOVED = "Flat UI: \"%s\" is no longer coloured in chat.",
	MISSING = "Flat UI: \"%s\" is not in the list; /flatui words lists them.",
	LIST = "Flat UI: other words coloured in chat: %s.",
	NONE = "Flat UI: no other words are coloured in chat; /flatui words add tank adds one.",
	HELP = "/flatui words - the other words coloured in chat as your name is; words add <word>, words remove <word>",
	ADD_LINE = "Add a word...", FULL_LINE = "At most 20 other words: choose one to stop colouring it",
	TYPE = "Type a word and press Enter. Escape closes this.",
	FIGHT = "Flat UI: words are added out of a fight.",
	LINK_FIGHT = "Flat UI: web addresses open their copy box out of a fight. Click it again then.",
	COPIED = "Copied.",
}

local S = { filtering = false, made = 0, waited = 0, mentioned = 0 }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

local function Wanted(part)
	return ns.Enabled(KEY) and Opt(ROW[part]) == true and not ns.PartStopped(KEY, part)
end

local function Part(part, fn, ...)
	if ns.Enabled(KEY) and not ns.PartStopped(KEY, part) then
		ns.EachPart(KEY, part, fn, ...)
	else
		pcall(fn, ...)
	end
end

local function Fighting()
	if type(InCombatLockdown) ~= "function" then
		return false
	end
	local ok, fighting = pcall(InCombatLockdown)
	return ok and (ns.IsSecret(fighting) or fighting == true)
end

local function Restricted()
	if Fighting() then
		return true
	end
	local api, kinds = C_RestrictedActions, Enum and Enum.AddOnRestrictionType
	if not Plain(api, "table") or not Plain(kinds, "table") then
		return false
	end
	local active, state = api.IsAddOnRestrictionActive, api.GetAddOnRestrictionState
	local states = Enum.AddOnRestrictionState
	local enforced = Plain(states, "table") and Plain(states.Active, "number") and states.Active or 2
	for name, kind in pairs(kinds) do
		if name ~= "Map" and Plain(kind, "number") then
			if type(active) == "function" then
				local ok, on = pcall(active, kind)
				if ok and (ns.IsSecret(on) or on == true) then
					return true
				end
			elseif type(state) == "function" then
				local ok, now = pcall(state, kind)
				if ok and (ns.IsSecret(now) or now == enforced) then
					return true
				end
			end
		end
	end
	return false
end

local function Split(word)
	local lead, core = word:match("^([%(%[{<\"']*)(.*)$")
	local trail = ""
	while core ~= "" do
		local last = core:sub(-1)
		if last == ")" then
			local _, opens = core:gsub("%(", "")
			local _, closes = core:gsub("%)", "")
			if opens >= closes then
				break
			end
		elseif not last:find("^[%.,;:!%?%]}>\"']$") then
			break
		end
		trail = last .. trail
		core = core:sub(1, -2)
	end
	return lead, core, trail
end

local function IsAddress(core)
	local lower = core:lower()
	return lower:find("^https?://[%w%-]") ~= nil or lower:find("^www%.[%w%-]+%.%a") ~= nil or lower:find("^[%w%-]+%.[%w%.%-]*%a%a/.") ~= nil
end

local function Link(address)
	return "|c" .. LINK_COLOUR .. "|H" .. PREFIX .. address .. "|h[" .. address .. "]|h|r"
end

local function Words(text)
	local made = 0
	local out = text:gsub("%S+", function(word)
		local lead, core, trail = Split(word)
		if core ~= "" and IsAddress(core) then
			made = made + 1
			return lead .. Link(core) .. trail
		end
		return nil
	end)
	return out, made
end

local function EscapeEnd(msg, at)
	local size, code = #msg, msg:sub(at + 1, at + 1)
	if code == "H" then
		local data = msg:find("|h", at + 2, true)
		local text = data and msg:find("|h", data + 2, true)
		return text and text + 1 or size
	elseif CLOSING[code] then
		local close = msg:find(CLOSING[code], at + 2, true)
		return close and close + 1 or size
	elseif code == "c" then
		if msg:sub(at + 2, at + 2) == "n" then
			return msg:find(":", at + 3, true) or size
		end
		return math.min(at + 9, size)
	end
	return math.min(at + 1, size)
end

local function Rewrite(msg)
	if not (msg:find("/", 1, true) or msg:find("[Ww][Ww][Ww]%.")) then
		return nil
	end
	local parts, made, at, size = {}, 0, 1, #msg
	while at <= size do
		local bar = msg:find("|", at, true)
		local stop = bar and bar - 1 or size
		if stop >= at then
			local text, n = Words(msg:sub(at, stop))
			parts[#parts + 1] = text
			made = made + n
		end
		if not bar then
			break
		end
		local close = EscapeEnd(msg, bar)
		parts[#parts + 1] = msg:sub(bar, close)
		at = close + 1
	end
	if made == 0 then
		return nil
	end
	return table.concat(parts)
end

local function Line(_, msg, lineID)
	if not Wanted(LINKS) or not Plain(msg, "string") or msg == "" then
		return
	end
	if S.lastIn ~= msg then
		S.lastIn, S.lastOut = msg, Rewrite(msg)
	end
	if S.lastOut ~= nil then
		local id = Plain(lineID, "number") and lineID or nil
		if id == nil or id ~= S.lastLine then
			S.made = S.made + 1
		end
		S.lastLine = id
	end
	S.out = S.lastOut
end

local function Filter(frame, event, msg, ...)
	if not Wanted(LINKS) then
		return false
	end
	S.out = nil
	ns.EachPart(KEY, LINKS, Line, Plain(frame, "table") and frame or Filter, msg, (select(10, ...)))
	local out = S.out
	S.out = nil
	if out ~= nil then
		return false, out, ...
	end
	return false
end

local function Registry()
	local util = ChatFrameUtil
	if Plain(util, "table") and type(util.AddMessageEventFilter) == "function" and type(util.RemoveMessageEventFilter) == "function" then
		return util.AddMessageEventFilter, util.RemoveMessageEventFilter
	end
	if type(ChatFrame_AddMessageEventFilter) == "function" and type(ChatFrame_RemoveMessageEventFilter) == "function" then
		return ChatFrame_AddMessageEventFilter, ChatFrame_RemoveMessageEventFilter
	end
	return nil
end

local function SyncLinks()
	local add, remove = Registry()
	S.noRegistry = add == nil
	if not add then
		S.filtering = false
		return
	end
	local want = Wanted(LINKS) and S.click == true
	if want and not S.filtering then
		for _, event in ipairs(EVENTS) do
			pcall(add, event, Filter)
		end
		S.filtering = true
	elseif not want and S.filtering then
		for _, event in ipairs(EVENTS) do
			pcall(remove, event, Filter)
		end
		S.filtering = false
	end
end

local function ShortNames()
	return ns.Enabled(KEY) and Opt("channelNames") == "short" and not ns.PartStopped(KEY, CHANNELS)
end

local function ShortName(name)
	if not Plain(name, "string") then
		return nil
	end
	local at = name:find(" - ", 1, true)
	local short = at and name:sub(1, at - 1) or nil
	if not short or not short:find("^%d+%. %S") then
		return nil
	end
	return short
end

local function Fits(frame, short, zone, base)
	local list, zones = rawget(frame, "channelList"), rawget(frame, "zoneChannelList")
	if not Plain(list, "table") then
		return false
	end
	local upper = Plain(base, "string") and base:upper() or nil
	local byZone = Plain(zone, "number") and zone > 0
	for index, value in pairs(list) do
		if not Plain(value, "string") then
			return false
		end
		local of = Plain(zones, "table") and zones[index] or nil
		local match = (byZone and Plain(of, "number") and of == zone) or (upper ~= nil and value:upper() == upper)
		if match and #short <= #value then
			return false
		end
	end
	return true
end

local function Shorten(frame, name, zone, base)
	local short = Plain(frame, "table") and ShortName(name) or nil
	if short and Fits(frame, short, zone, base) then
		S.short = short
	end
end

local function Channels(frame, event, msg, a2, a3, a4, ...)
	if not ShortNames() or not Plain(msg, "string") then
		return false
	end
	S.short = nil
	ns.EachPart(KEY, CHANNELS, Shorten, Plain(frame, "table") and frame or Channels, a4, (select(3, ...)), (select(5, ...)))
	local short = S.short
	S.short = nil
	if short ~= nil then
		return false, msg, a2, a3, short, ...
	end
	return false
end

function ns.ChatChannelLabel(name)
	return ShortNames() and ShortName(name) or name
end

local function SyncChannels()
	local add, remove = Registry()
	if not add then
		S.channels = false
		return
	end
	local want = ShortNames()
	if want and not S.channels then
		pcall(add, "CHAT_MSG_CHANNEL", Channels)
		S.channels = true
	elseif not want and S.channels then
		pcall(remove, "CHAT_MSG_CHANNEL", Channels)
		S.channels = false
	end
end

local function MyName()
	if S.name == nil and type(UnitName) == "function" then
		local ok, name = pcall(UnitName, "player")
		if ok and Plain(name, "string") and #name > 1 and name ~= UNKNOWNOBJECT then
			S.name = name
		end
	end
	return S.name
end

local function MentionColour()
	local hex = Opt("mentionColour")
	if Plain(hex, "string") and hex:find("^%x%x%x%x%x%x%x%x$") then
		return "|cff" .. hex:sub(3)
	end
	return "|cffff9933"
end

local function Touches(char)
	return char ~= "" and char:find("[%w\128-\255]") ~= nil
end

local function MarkWord(word, lower, colour)
	local _, core = Split(word)
	if core ~= "" and IsAddress(core) then
		return nil
	end
	local low, size = word:lower(), #lower
	local first = low:find(lower, 1, true)
	local parts, at = nil, 1
	while first do
		local last = first + size - 1
		if not Touches(word:sub(first - 1, first - 1)) and not Touches(word:sub(last + 1, last + 1)) then
			parts = parts or {}
			parts[#parts + 1] = word:sub(at, first - 1)
			parts[#parts + 1] = colour .. word:sub(first, last) .. "|r"
			at = last + 1
		end
		first = low:find(lower, last + 1, true)
	end
	if parts == nil then
		return nil
	end
	parts[#parts + 1] = word:sub(at)
	return table.concat(parts)
end

local function MarkLine(msg, lower, colour)
	if not msg:lower():find(lower, 1, true) then
		return nil
	end
	local parts, made, at, size = {}, 0, 1, #msg
	local function Word(word)
		local out = MarkWord(word, lower, colour)
		if out then
			made = made + 1
		end
		return out
	end
	while at <= size do
		local bar = msg:find("|", at, true)
		local stop = bar and bar - 1 or size
		if stop >= at then
			parts[#parts + 1] = (msg:sub(at, stop):gsub("%S+", Word))
		end
		if not bar then
			break
		end
		local close = EscapeEnd(msg, bar)
		parts[#parts + 1] = msg:sub(bar, close)
		at = close + 1
	end
	if made == 0 then
		return nil
	end
	return table.concat(parts)
end

local function WordList(make)
	local db = ns.Account()
	if type(db) ~= "table" then
		return nil
	end
	if type(db.chatWords) ~= "table" then
		if not make then
			return nil
		end
		db.chatWords = {}
	end
	return db.chatWords
end

local function Fit(word)
	return type(word) == "string" and #word >= WORDS.SHORT and #word <= WORDS.LONG and word == word:lower() and not word:find("[%s|]")
end

local function Targets(name)
	local list, seen = { name:lower() }, { [name:lower()] = true }
	for _, word in ipairs(WordList(false) or {}) do
		if Fit(word) and not seen[word] and #list <= WORDS.MOST then
			seen[word] = true
			list[#list + 1] = word
		end
	end
	return list
end

local function MarkAll(msg, name)
	local colour, out = MentionColour(), nil
	for _, lower in ipairs(Targets(name)) do
		out = MarkLine(out or msg, lower, colour) or out
	end
	return out
end

local function Takes(frame, event, label, zone, base)
	if event ~= "CHAT_MSG_CHANNEL" then
		return true
	end
	local list, zones = rawget(frame, "channelList"), rawget(frame, "zoneChannelList")
	if not Plain(list, "table") or not Plain(label, "string") then
		return false
	end
	local upper = Plain(base, "string") and base:upper() or nil
	local byZone = Plain(zone, "number") and zone > 0
	for index, value in pairs(list) do
		if Plain(value, "string") and #label > #value then
			local of = Plain(zones, "table") and zones[index] or nil
			if (byZone and Plain(of, "number") and of == zone) or (upper ~= nil and value:upper() == upper) then
				return true
			end
		end
	end
	return false
end

local function Mark(frame, msg, author, lineID, event, label, zone, base)
	local name = MyName()
	if not name then
		return
	end
	if Plain(author, "string") and (author:match("^([^%-]+)") or author) == name then
		return
	end
	if S.mentionIn ~= msg then
		S.mentionIn, S.mentionOut = msg, MarkAll(msg, name)
	end
	if S.mentionOut == nil then
		return
	end
	local id = Plain(lineID, "number") and lineID or nil
	if id == nil or id ~= S.mentionLine then
		S.mentioned = S.mentioned + 1
		local sound = ns.SOUNDS and ns.SOUNDS[KITS[Opt("mentionSound")] or 0]
		if sound then
			ns.PlayKit(sound[1], KEY)
		end
		if Opt("mentionFlash") == true and type(FlashClientIcon) == "function" then
			local ok, now = pcall(GetTime)
			if ok and Plain(now, "number") and (S.flashedAt == nil or now - S.flashedAt >= FLASH_GAP or now < S.flashedAt) then
				S.flashedAt = now
				pcall(FlashClientIcon)
			end
		end
	end
	S.mentionLine = id
	S.marked = S.mentionOut
	if Opt("mentionTab") == true and Plain(frame, "table") and type(ns.ChatTabNamed) == "function" and Takes(frame, event, label, zone, base) then
		ns.ChatTabNamed(frame)
	end
end

local function Mentions(frame, event, msg, author, ...)
	if not Wanted(MENTIONS) or not Plain(msg, "string") or msg == "" then
		return false
	end
	S.marked = nil
	ns.EachPart(KEY, MENTIONS, Mark, Plain(frame, "table") and frame or Mentions, msg, author, (select(9, ...)), event, (select(2, ...)),
		(select(5, ...)), (select(7, ...)))
	local out = S.marked
	S.marked = nil
	if out ~= nil then
		return false, out, author, ...
	end
	return false
end

local function SyncMentions()
	S.mentionIn, S.mentionOut = nil, nil
	local add, remove = Registry()
	if not add then
		S.mentions = false
		return
	end
	local want = Wanted(MENTIONS)
	if want and not S.mentions then
		for _, event in ipairs(MENTION_EVENTS) do
			pcall(add, event, Mentions)
		end
		S.mentions = true
	elseif not want and S.mentions then
		for _, event in ipairs(MENTION_EVENTS) do
			pcall(remove, event, Mentions)
		end
		S.mentions = false
	end
end

local function EditWord(verb, typed)
	local word = type(typed) == "string" and typed:lower() or ""
	if not Fit(word) then
		return WORDS.BAD
	end
	local list = WordList(verb == "add")
	if not list then
		return verb == "add" and WORDS.BAD or WORDS.MISSING:format(word)
	end
	local name = MyName()
	for index, have in ipairs(list) do
		if have == word then
			if verb == "add" then
				return WORDS.HAVE:format(word)
			end
			table.remove(list, index)
			S.mentionIn, S.mentionOut = nil, nil
			return WORDS.REMOVED:format(word)
		end
	end
	if verb ~= "add" then
		return WORDS.MISSING:format(word)
	elseif name and name:lower() == word then
		return WORDS.HAVE:format(word)
	elseif #list >= WORDS.MOST then
		return WORDS.FULL
	end
	list[#list + 1] = word
	S.mentionIn, S.mentionOut = nil, nil
	return WORDS.ADDED:format(word) .. (Opt("mentions") == true and "" or WORDS.OFF), true
end

local function WordsSlash(rest)
	local verb, word = (type(rest) == "string" and rest or ""):match("^%s*(%S*)%s*(.-)%s*$")
	verb = (verb or ""):lower()
	if verb == "add" or verb == "remove" then
		print((EditWord(verb, word)))
	elseif verb == "" or verb == "list" then
		local words = {}
		for _, have in ipairs(WordList(false) or {}) do
			if Fit(have) then
				words[#words + 1] = have
			end
		end
		print(#words > 0 and WORDS.LIST:format(table.concat(words, ", ")) or WORDS.NONE)
	else
		print(WORDS.HELP)
	end
end

ns.AddSlash(KEY, "words", WordsSlash, { WORDS.HELP })

function ns.ChatWordLines()
	local rows = {}
	for index, word in ipairs(WordList(false) or {}) do
		if Fit(word) then
			rows[#rows + 1] = { index, word }
		end
	end
	table.sort(rows, function(a, b)
		return a[2] < b[2]
	end)
	table.insert(rows, 1, #rows < WORDS.MOST and { "add", WORDS.ADD_LINE } or { "full", WORDS.FULL_LINE })
	return rows
end

local OpenWordBox

function ns.ChatWordPick(id)
	if id == "add" then
		if Fighting() then
			return false, WORDS.FIGHT
		end
		OpenWordBox()
		return true
	elseif id == "full" then
		return false, WORDS.FULL
	end
	local list = WordList(false)
	local word = list and type(id) == "number" and list[id] or nil
	if not Fit(word) then
		return false
	end
	return true, EditWord("remove", word)
end

local HELP_COLOUR = { 1, 0.82, 0 }
local COPIED_CLOSE = 0.6
local KEEP_KEYS = { LEFT = true, RIGHT = true, UP = true, DOWN = true, HOME = true, END = true }
local WordEntered

local CROSS = { SIZE = 16, INSET = 4, ROOM = 24, DIM = { 0.7, 0.7, 0.7 }, FADE = 0.1 }

local function Shown(frame)
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and not ns.IsSecret(shown) and shown == true
end

function ns.ChatBoxSound(open)
	local kit = type(SOUNDKIT) == "table" and SOUNDKIT[open and "IG_CHARACTER_INFO_OPEN" or "IG_CHARACTER_INFO_CLOSE"] or nil
	if type(PlaySound) == "function" and kit ~= nil then
		pcall(PlaySound, kit)
	end
end

function ns.ChatBoxDress(frame, close)
	local cross = CreateFrame("Button", nil, frame)
	ns.Own[cross] = true
	cross:SetSize(CROSS.SIZE, CROSS.SIZE)
	cross:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -CROSS.INSET, -CROSS.INSET)
	pcall(cross.RegisterForClicks, cross, "LeftButtonUp")
	local label = ns.OwnText(cross, "OVERLAY", "GameFontNormalSmall")
	if label then
		label:SetPoint("CENTER", cross, "CENTER", 0, 1)
		label:SetText("x")
	end
	local function Tint(lit)
		if not label then
			return
		end
		local r, g, b = CROSS.DIM[1], CROSS.DIM[2], CROSS.DIM[3]
		if lit then
			local ok, cr, cg, cb = pcall(ns.WindowColour, "windows.accent")
			if ok and ns.Finite(cr) and ns.Finite(cg) and ns.Finite(cb) then
				r, g, b = cr, cg, cb
			end
		end
		pcall(label.SetTextColor, label, r, g, b)
	end
	Tint(false)
	cross:SetScript("OnEnter", function()
		Tint(true)
	end)
	cross:SetScript("OnLeave", function()
		Tint(false)
	end)
	cross:SetScript("OnClick", function()
		close()
	end)
	local ok, fade = pcall(function()
		local group = frame:CreateAnimationGroup()
		local rise = group:CreateAnimation("Alpha")
		rise:SetFromAlpha(0)
		rise:SetToAlpha(1)
		rise:SetDuration(CROSS.FADE)
		return group
	end)
	return { cross = cross, fade = ok and fade or nil, tint = Tint, room = CROSS.ROOM }
end

function ns.ChatBoxOpened(dress, was)
	if was or type(dress) ~= "table" then
		return
	end
	if dress.fade then
		pcall(dress.fade.Play, dress.fade)
	end
	dress.tint(false)
	ns.ChatBoxSound(true)
end

local function CloseBox()
	local box = S.box
	if not box or S.closing then
		return
	end
	S.closing = true
	local was = Shown(box.frame)
	pcall(box.edit.ClearFocus, box.edit)
	pcall(box.frame.Hide, box.frame)
	S.closing = false
	if was then
		ns.ChatBoxSound(false)
	end
end

local function Select(edit)
	pcall(edit.SetFocus, edit)
	pcall(edit.HighlightText, edit)
end

local function Mac()
	if type(IsMacClient) == "function" then
		local ok, answer = pcall(IsMacClient)
		return ok and not ns.IsSecret(answer) and answer == true
	end
	return false
end

local function Help()
	return ("Press %s to copy it. Enter or Escape closes this."):format(Mac() and "Cmd+C" or "Ctrl+C")
end

function ns.ChatCopyKey(key)
	if key ~= "C" then
		return false
	end
	local function down(name)
		local fn = _G[name]
		if type(fn) ~= "function" then
			return false
		end
		local ok, held = pcall(fn)
		return ok and not ns.IsSecret(held) and held == true
	end
	return down("IsControlKeyDown") or (Mac() and down("IsMetaKeyDown"))
end

local function BuildBox()
	local frame = CreateFrame("Frame", nil, UIParent)
	ns.Own[frame] = true
	frame:SetSize(BOX_WIDTH, BOX_HEIGHT)
	frame:SetFrameStrata("DIALOG")
	pcall(frame.SetClampedToScreen, frame, true)
	frame:EnableMouse(true)
	ns.SetOutlineAlpha(ns.ThemeOutline(ns.SetOutlineArea(ns.Outline(frame, frame, true), KEY), true), nil, 0.95)
	local help = ns.OwnText(frame, "OVERLAY", "GameFontNormalSmall")
	if help then
		help:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -7)
		help:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -CROSS.ROOM, -7)
		pcall(help.SetJustifyH, help, "LEFT")
		help:SetText(Help())
		local ok, r, g, b = pcall(help.GetTextColor, help)
		if ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
			HELP_COLOUR[1], HELP_COLOUR[2], HELP_COLOUR[3] = r, g, b
		end
	end
	local edit = CreateFrame("EditBox", nil, frame)
	ns.Own[edit] = true
	edit:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 6)
	edit:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
	edit:SetHeight(FIELD_HEIGHT)
	edit:SetAutoFocus(false)
	edit:SetFontObject("ChatFontNormal")
	edit:SetTextInsets(6, 6, 0, 0)
	pcall(edit.SetMaxLetters, edit, 0)
	pcall(edit.SetMaxBytes, edit, 0)
	ns.SetOutlineFill(ns.SetOutlineArea(ns.Outline(edit, edit, true), KEY), 0, 0, 0, 0.5)
	local box = { frame = frame, edit = edit, help = help, dress = ns.ChatBoxDress(frame, CloseBox) }
	edit:SetScript("OnEscapePressed", CloseBox)
	edit:SetScript("OnEnterPressed", function()
		if box.mode == "word" then
			WordEntered(box)
		else
			CloseBox()
		end
	end)
	edit:SetScript("OnEditFocusLost", CloseBox)
	edit:SetScript("OnTextChanged", function(self, typed)
		if typed and box.address ~= nil then
			pcall(self.SetText, self, box.address)
			pcall(self.HighlightText, self)
		elseif typed and box.mode == "word" and box.refused and help then
			box.refused = nil
			help:SetText(WORDS.TYPE)
			help:SetTextColor(HELP_COLOUR[1], HELP_COLOUR[2], HELP_COLOUR[3])
		end
	end)
	local function Keep()
		if box.mode == "copy" and box.address ~= nil then
			pcall(edit.HighlightText, edit)
		end
	end
	edit:SetScript("OnMouseUp", Keep)
	edit:SetScript("OnKeyDown", function(_, key)
		if box.mode == "copy" and box.address ~= nil and not ns.IsSecret(key) and type(key) == "string" and KEEP_KEYS[key] then
			local opened = box.opened
			if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
				pcall(C_Timer.After, 0, function()
					local ok, shown = pcall(box.frame.IsShown, box.frame)
					if ok and not ns.IsSecret(shown) and shown == true and box.opened == opened then
						Keep()
					end
				end)
			end
			return
		end
		if box.mode == "copy" and box.address ~= nil and box.address ~= "" and help and ns.ChatCopyKey(key) then
			help:SetText(WORDS.COPIED)
			help:SetTextColor(HELP_COLOUR[1], HELP_COLOUR[2], HELP_COLOUR[3])
			local opened = box.opened
			if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
				pcall(C_Timer.After, COPIED_CLOSE, function()
					local ok, shown = pcall(box.frame.IsShown, box.frame)
					if ok and not ns.IsSecret(shown) and shown == true and box.mode == "copy" and box.opened == opened then
						CloseBox()
					end
				end)
			end
		end
	end)
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED")
	frame:SetScript("OnEvent", CloseBox)
	frame:Hide()
	return box
end

local function Place(frame)
	frame:ClearAllPoints()
	local okScale, scale = pcall(UIParent.GetEffectiveScale, UIParent)
	local okCursor, x, y = false, nil, nil
	if type(GetCursorPosition) == "function" then
		okCursor, x, y = pcall(GetCursorPosition)
	end
	if okScale and okCursor and ns.Finite(scale) and scale > 0 and ns.Finite(x) and ns.Finite(y) then
		frame:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", x / scale, y / scale + 12)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	end
end

local function SayInBox(box, text, refused)
	local help = box.help
	box.refused = refused and true or nil
	if help then
		help:SetText(text)
		if refused then
			help:SetTextColor(1, 0.3, 0.3)
		else
			help:SetTextColor(HELP_COLOUR[1], HELP_COLOUR[2], HELP_COLOUR[3])
		end
	end
end

local function OpenBox(_, address)
	if Fighting() then
		if not S.linkFightSaid then
			S.linkFightSaid = true
			print(WORDS.LINK_FIGHT)
			pcall(ns.OutOfCombat, function()
				S.linkFightSaid = nil
			end)
		end
		return
	end
	if not S.box then
		S.box = BuildBox()
	end
	local box = S.box
	box.mode, box.address = "copy", address
	box.opened = (box.opened or 0) + 1
	SayInBox(box, Help())
	box.edit:SetText(address)
	Place(box.frame)
	local was = Shown(box.frame)
	box.frame:Show()
	ns.ChatBoxOpened(box.dress, was)
	Select(box.edit)
	local ok, focus = pcall(box.edit.HasFocus, box.edit)
	if ok and not ns.IsSecret(focus) and focus == false then
		CloseBox()
		return
	end
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		pcall(C_Timer.After, 0, function()
			local ok, shown = pcall(box.frame.IsShown, box.frame)
			if ok and shown == true and box.address == address then
				pcall(box.edit.HighlightText, box.edit)
			end
		end)
	end
end

function WordEntered(box)
	local ok, typed = pcall(box.edit.GetText, box.edit)
	local word = ok and Plain(typed, "string") and typed:match("^%s*(.-)%s*$") or ""
	local said, done = EditWord("add", word)
	if done then
		print(said)
		CloseBox()
		return
	end
	SayInBox(box, (said:gsub("^Flat UI: ", "")), true)
	pcall(box.edit.HighlightText, box.edit)
end

function OpenWordBox()
	if Fighting() then
		return
	end
	if not S.box then
		S.box = BuildBox()
	end
	local box = S.box
	box.mode, box.address = "word", nil
	SayInBox(box, WORDS.TYPE)
	box.edit:SetText("")
	Place(box.frame)
	local was = Shown(box.frame)
	box.frame:Show()
	ns.ChatBoxOpened(box.dress, was)
	pcall(box.edit.SetFocus, box.edit)
	local okFocus, focus = pcall(box.edit.HasFocus, box.edit)
	if okFocus and not ns.IsSecret(focus) and focus == false then
		CloseBox()
	end
end

local function Clicked(_, link, _, _, frame)
	if not Plain(link, "string") or link:sub(1, #PREFIX) ~= PREFIX then
		return
	end
	local address = link:sub(#PREFIX + 1)
	if address ~= "" then
		Part(LINKS, OpenBox, Plain(frame, "table") and frame or Clicked, address)
	end
end

local function Tooltip()
	local tip = GameTooltip
	if Plain(tip, "table") and not ns.Forbidden(tip) then
		return tip
	end
	return nil
end

local function Owns(tip)
	local ok, owner = pcall(tip.GetOwner, tip)
	return ok and S.owner ~= nil and not ns.IsSecret(owner) and rawequal(owner, S.owner)
end

local Watch

local function HideTip(frame)
	if S.tipFrom == nil or (frame ~= nil and not rawequal(frame, S.tipFrom)) then
		return
	end
	S.tipFrom = nil
	local tip = Tooltip()
	if tip and Owns(tip) then
		pcall(tip.Hide, tip)
	end
	Watch(false)
end

local function Over(frame)
	if not Plain(frame, "table") or ns.Forbidden(frame) then
		return false
	end
	local okShown, shown = pcall(frame.IsVisible, frame)
	local okOver, over = pcall(frame.IsMouseOver, frame)
	if okShown and not ns.IsSecret(shown) and shown == false then
		return false
	end
	return not (okOver and not ns.IsSecret(over) and over == false)
end

local function Look()
	local tip = Tooltip()
	if S.tipFrom == nil or not tip or not Owns(tip) then
		S.tipFrom = nil
		Watch(false)
		return
	end
	local ok, shown = pcall(tip.IsShown, tip)
	if ok and not ns.IsSecret(shown) and shown == false then
		S.tipFrom = nil
		Watch(false)
	elseif Restricted() or not Over(S.tipFrom) or not Wanted(TIPS) then
		HideTip()
	end
end

function Watch(on)
	local owner = S.owner
	if not owner then
		if not on then
			return
		end
		owner = CreateFrame("Frame", nil, UIParent)
		ns.Own[owner] = true
		owner:SetSize(1, 1)
		owner:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
		owner:SetScript("OnUpdate", function(_, elapsed)
			S.waited = S.waited + (type(elapsed) == "number" and elapsed or 0)
			if S.waited >= WATCH then
				S.waited = 0
				if ns.IsStopped(KEY) or ns.PartStopped(KEY, TIPS) or not ns.EachPart(KEY, TIPS, Look) then
					pcall(HideTip)
					S.tipFrom = nil
					pcall(Watch, false)
				end
			end
		end)
		S.owner = owner
	end
	S.waited = 0
	owner:SetShown(on == true)
end

local function ShowTip(frame, link)
	if not Plain(link, "string") or not TIP_KINDS[link:match("^(%a+):") or ""] or Restricted() then
		return
	end
	local tip = Tooltip()
	if not tip then
		return
	end
	Watch(true)
	if not pcall(tip.SetOwner, tip, S.owner, "ANCHOR_CURSOR") then
		Watch(false)
		return
	end
	S.tipFrom = frame
	local ok, err = pcall(tip.SetHyperlink, tip, link)
	if not ok then
		HideTip()
		error(err, 0)
	end
end

local function Entered(_, frame, link)
	if Wanted(TIPS) and Plain(frame, "table") then
		ns.EachPart(KEY, TIPS, ShowTip, frame, link)
	end
end

local function Left(_, frame)
	if S.tipFrom ~= nil then
		Part(TIPS, HideTip, Plain(frame, "table") and frame or nil)
	end
end

local function SyncTips()
	if not Wanted(TIPS) then
		HideTip()
	end
end

local function Listen()
	local registry = EventRegistry
	if S.listened or not Plain(registry, "table") or type(registry.RegisterCallback) ~= "function" then
		return
	end
	S.listened = true
	S.click = pcall(registry.RegisterCallback, registry, "SetItemRef", Clicked, "FlatUI.chat.webLink")
	S.hover = pcall(function()
		registry:RegisterCallback("ChatFrame.OnHyperlinkEnter", Entered, "FlatUI.chat.linkEnter")
		registry:RegisterCallback("ChatFrame.OnHyperlinkLeave", Left, "FlatUI.chat.linkLeave")
	end)
end

function ns.ChatLinksSync()
	if ns.Enabled(KEY) and (Opt(ROW[LINKS]) == true or Opt(ROW[TIPS]) == true) then
		Listen()
	end
	Part(LINKS, SyncLinks)
	Part(TIPS, SyncTips)
	Part(CHANNELS, SyncChannels)
	Part(MENTIONS, SyncMentions)
	if not ns.Enabled(KEY) then
		CloseBox()
	end
end

local function Windows()
	local list = CHAT_FRAMES
	return Plain(list, "table") and list[1] ~= nil
end

ns.AddStatus(KEY, function()
	local lines = {}
	if Wanted(LINKS) then
		if S.noRegistry and Windows() then
			lines[#lines + 1] = "Web addresses: this game has no chat filters, so they stay plain text."
		elseif S.click == false then
			lines[#lines + 1] = "Web addresses: the game would not pass on a click on a link, so they stay plain text."
		elseif S.made > 0 then
			lines[#lines + 1] = ("Web addresses: made into links in %d chat %s."):format(S.made, S.made == 1 and "line" or "lines")
		end
	end
	if Wanted(TIPS) and S.hover == false then
		lines[#lines + 1] = "Link tooltips: the game would not say when the mouse is over a link."
	end
	if Wanted(MENTIONS) then
		if S.noRegistry and Windows() then
			lines[#lines + 1] = "Your name in chat: this game has no chat filters, so it is not coloured."
		elseif S.mentioned > 0 then
			local words = #Targets(MyName() or "") - 1
			lines[#lines + 1] = ("Your name in chat: coloured in %d chat %s%s."):format(S.mentioned, S.mentioned == 1 and "line" or "lines",
				words > 0 and (" (with %d other %s)"):format(words, words == 1 and "word" or "words") or "")
		end
	end
	return lines
end)
