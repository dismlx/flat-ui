local _, ns = ...

-- Links in the chat windows: a web address in a chat line becomes a link of Flat UI's own that opens a box to copy it, and the tooltip of an item,
-- spell or achievement link shows while the mouse is over it. Runs with the chat module: Chat.lua calls ns.ChatLinksSync at the end of each refresh.
-- Web addresses: a filter in the game's own chat filter registry (ChatFrameUtil.AddMessageEventFilter, Blizzard_ChatFrameBase/Shared/
-- ChatFrameFilters.lua:112-124 and 202-215) reads the text of the lines players write and of the game's system lines. The registry calls it securely
-- and only with a line whose every value an addon may read (canaccessvalue), so a line of the chat lockdown is passed on untouched, and the filter
-- leaves a withheld text alone too. Only plain text is looked at: a link, a texture, an atlas, a Battle.net name and the code of a colour are passed
-- over whole. A web address there (http:// or https://, www., or a name with a dot and a path) is written as a link of the game's addon type,
-- |Haddon:FlatUI:url:<address>|h[<address>]|h; the rest of the line and every other value of the event stay as they were. A click on any link of a
-- chat window goes to SetItemRef (ChatFrameMixin:OnHyperlinkClick, Shared/ChatFrame.lua:19-25, Blizzard_UIPanels_Game/Mainline/ItemRef.lua:6-27),
-- whose handler for addon links (Shared/ItemRefHandlersShared.lua:279-282) fires EventRegistry's SetItemRef and counts the click as handled, so the
-- ItemRef tooltip stays shut. Flat UI listens to that callback: no function of the game is hooked or replaced, nothing is written in its link
-- handlers, and a click on any other link takes the game's own path. The click opens a small box of Flat UI's own at the cursor, with the address
-- selected; Enter or Escape closes it, and so does the loss of its focus or the start of a fight. Typing in it puts the address back.
-- Link tooltips: every chat window fires ChatFrame.OnHyperlinkEnter and ChatFrame.OnHyperlinkLeave through EventRegistry (Shared/ChatFrame.lua:27-33,
-- the scripts of ChatFrameTemplate, Mainline/ChatFrame.xml:16-18), so no script of a chat window is hooked, and a window the game opens later counts
-- too. GameTooltip gets a frame of Flat UI's own as its owner, at the cursor, and is filled from the link with SetHyperlink, a secure accessor of the
-- game's tooltip data (Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua:488-519, 590), as OwnPaint.lua fills it with SetAction; Chat.lua's
-- lines and border apply to it as to any tooltip. It is hidden when the mouse leaves the link, the window hides or a fight starts, and only while
-- that frame still owns it. None is shown in a fight, nor while the game restricts addons (C_RestrictedActions, every restriction but the map's).
-- These follow the clickable addresses and the link tooltips of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission
-- (EnhanceQoLChatSocial/ChatIcons.lua). Left out: its item and currency icons and the item levels in links.

local KEY = "chat"
local LINKS, TIPS = "web links", "link tooltips"
local ROW = { [LINKS] = "webLinks", [TIPS] = "linkTips" }
-- What comes after |H in a link this file makes: the game's addon link type, then Flat UI's own name and kind.
local PREFIX = "addon:FlatUI:url:"
local LINK_COLOUR = "ff6cb8ff"
-- The chat events of what players write, and the game's system lines (Blizzard_ChatFrameBase/Shared/ChatTypeInfoConstants.lua).
local EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_AFK", "CHAT_MSG_DND",
	"CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT",
	"CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_GUILD_DISCORD", "CHAT_MSG_CHANNEL", "CHAT_MSG_COMMUNITIES_CHANNEL",
	"CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_BN_INLINE_TOAST_BROADCAST", "CHAT_MSG_SYSTEM" }
-- The kinds of link that show a tooltip: an enchant link is the spell of a profession.
local TIP_KINDS = { item = true, spell = true, enchant = true, achievement = true }
-- An escape whose end is a closing code of its own: a texture, an atlas, a Battle.net name.
local CLOSING = { T = "|t", A = "|a", K = "|k" }
local BOX_WIDTH, BOX_HEIGHT, FIELD_HEIGHT = 380, 50, 20
-- Seconds between two looks at a link tooltip that is up.
local WATCH = 0.1

-- The state of the file: whether the filter is in the registry, whether each callback was given (true) or refused (false), the last line
-- rewritten (the same line comes once for each window that shows it), the lines with a link made, the copy box and the tooltip's owner.
local S = { filtering = false, made = 0, waited = 0 }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

-- True while a part is to work: the module on, its row on, the part not stopped.
local function Wanted(part)
	return ns.Enabled(KEY) and Opt(ROW[part]) == true and not ns.PartStopped(KEY, part)
end

-- A part run as ChatText.lua runs one: with the module on and the part not stopped, a failure counts toward stopping the part alone; otherwise a
-- failure is let go, since the part is only putting things away.
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

-- True in a fight, and while the game restricts addons in any way but on the map (RestrictedActionsConstantsDocumentation.lua). An answer the
-- game withholds counts as a restriction.
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

-- Web addresses ------------------------------------------------------------------------------

-- Splits a word into what comes before an address, the address, and the punctuation after it. A closing bracket stays in the address while it
-- closes one of its own, as in a wiki address.
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

-- True for a web address: a scheme of the web, www., or a name with a dot and a path whose last part before the path is letters.
local function IsAddress(core)
	local lower = core:lower()
	return lower:find("^https?://[%w%-]") ~= nil or lower:find("^www%.[%w%-]+%.%a") ~= nil or lower:find("^[%w%-]+%.[%w%.%-]*%a%a/.") ~= nil
end

local function Link(address)
	return "|c" .. LINK_COLOUR .. "|H" .. PREFIX .. address .. "|h[" .. address .. "]|h|r"
end

-- The words of a run of plain text (no escape in it), with each address made a link, and how many were.
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

-- Where the escape that starts at `at` ends. A link runs to the end of its text, a texture, an atlas and a name to their closing code, a colour
-- over its eight digits (or its name up to the colon), and any other escape (|r, ||, |n and the rest) is two characters. An escape that does
-- not end runs to the end of the line.
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

-- The line with every address in its plain text made a link, or nil when it has none.
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

-- One line of one window: S.out is the line to show in its place, or nil to leave it. The game gives the same line to each window that shows
-- it, so the last answer is kept, and a line with a link made is counted once by its lineID.
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

-- The game's registry calls it with the window, the event and the values of the event (the line first, lineID eleventh). False alone leaves the
-- line; false and the values put the line in their place, every other value as it came.
local function Filter(frame, event, msg, ...)
	if not Wanted(LINKS) then
		return false
	end
	S.out = nil
	-- A part that fails is counted once for each window it fails on.
	ns.EachPart(KEY, LINKS, Line, Plain(frame, "table") and frame or Filter, msg, (select(10, ...)))
	local out = S.out
	S.out = nil
	if out ~= nil then
		return false, out, ...
	end
	return false
end

-- The game's own chat filter registry: ChatFrameUtil on this client, ChatFrame_AddMessageEventFilter on an older one, or nil.
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

-- The filter is given once for each event and taken back with the same function value. An address is made a link only while the click on it
-- is heard.
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

-- The copy box --------------------------------------------------------------------------------

local function CloseBox()
	local box = S.box
	if not box or S.closing then
		return
	end
	S.closing = true
	pcall(box.edit.ClearFocus, box.edit)
	pcall(box.frame.Hide, box.frame)
	S.closing = false
end

local function Select(edit)
	pcall(edit.SetFocus, edit)
	pcall(edit.HighlightText, edit)
end

local function Help()
	local mac = false
	if type(IsMacClient) == "function" then
		local ok, answer = pcall(IsMacClient)
		mac = ok and not ns.IsSecret(answer) and answer == true
	end
	return ("Press %s to copy it. Enter or Escape closes this."):format(mac and "Cmd+C" or "Ctrl+C")
end

-- Built the first time an address is clicked: a frame of Flat UI's own on UIParent, its look from the chat page, a line of help and the box.
local function BuildBox()
	local frame = CreateFrame("Frame", nil, UIParent)
	ns.Own[frame] = true
	frame:SetSize(BOX_WIDTH, BOX_HEIGHT)
	frame:SetFrameStrata("DIALOG")
	pcall(frame.SetClampedToScreen, frame, true)
	frame:EnableMouse(true)
	ns.SetOutlineAlpha(ns.Outline(frame, frame, true), nil, 0.95)
	local help = ns.OwnText(frame, "OVERLAY", "GameFontNormalSmall")
	if help then
		help:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -7)
		help:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -7)
		pcall(help.SetJustifyH, help, "LEFT")
		help:SetText(Help())
	end
	local edit = CreateFrame("EditBox", nil, frame)
	ns.Own[edit] = true
	edit:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 6)
	edit:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
	edit:SetHeight(FIELD_HEIGHT)
	edit:SetAutoFocus(false)
	edit:SetFontObject("ChatFontNormal")
	edit:SetTextInsets(6, 6, 0, 0)
	-- No limit, so a long address is never cut.
	pcall(edit.SetMaxLetters, edit, 0)
	pcall(edit.SetMaxBytes, edit, 0)
	ns.SetOutlineFill(ns.Outline(edit, edit, true), 0, 0, 0, 0.5)
	local box = { frame = frame, edit = edit }
	edit:SetScript("OnEscapePressed", CloseBox)
	edit:SetScript("OnEnterPressed", CloseBox)
	edit:SetScript("OnEditFocusLost", CloseBox)
	-- What is typed over the address is taken back: the box is for copying.
	edit:SetScript("OnTextChanged", function(self, typed)
		if typed and box.address ~= nil then
			pcall(self.SetText, self, box.address)
			pcall(self.HighlightText, self)
		end
	end)
	-- The keyboard goes back to the game when a fight starts.
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED")
	frame:SetScript("OnEvent", CloseBox)
	frame:Hide()
	return box
end

-- The box goes above the cursor, where the address was clicked, or above the middle of the screen when the cursor cannot be read.
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

local function OpenBox(_, address)
	if not S.box then
		S.box = BuildBox()
	end
	local box = S.box
	box.address = address
	box.edit:SetText(address)
	Place(box.frame)
	box.frame:Show()
	Select(box.edit)
	-- The box is only up while it has the keyboard, so Enter or Escape always closes it.
	local ok, focus = pcall(box.edit.HasFocus, box.edit)
	if ok and not ns.IsSecret(focus) and focus == false then
		CloseBox()
		return
	end
	-- The game may move the selection as the box gets the keyboard, so it is made again on the next frame.
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		pcall(C_Timer.After, 0, function()
			local ok, shown = pcall(box.frame.IsShown, box.frame)
			if ok and shown == true and box.address == address then
				pcall(box.edit.HighlightText, box.edit)
			end
		end)
	end
end

-- EventRegistry's SetItemRef: the game fires it for every addon link clicked, with the link, its text, the mouse button and the window. A link
-- that is not one of Flat UI's addresses is left to whoever made it. An address made while the row was on still opens while the module is on.
local function Clicked(_, link, _, _, frame)
	if not Plain(link, "string") or link:sub(1, #PREFIX) ~= PREFIX or not ns.Enabled(KEY) or ns.PartStopped(KEY, LINKS) then
		return
	end
	local address = link:sub(#PREFIX + 1)
	if address ~= "" then
		ns.EachPart(KEY, LINKS, OpenBox, Plain(frame, "table") and frame or Clicked, address)
	end
end

-- Link tooltips -------------------------------------------------------------------------------

local function Tooltip()
	local tip = GameTooltip
	if Plain(tip, "table") and not ns.Forbidden(tip) then
		return tip
	end
	return nil
end

-- True while GameTooltip's owner is the frame of this file. An owner that cannot be read is not.
local function Owns(tip)
	local ok, owner = pcall(tip.GetOwner, tip)
	return ok and S.owner ~= nil and not ns.IsSecret(owner) and rawequal(owner, S.owner)
end

local Watch

-- Takes the tooltip of a link away: hidden only while the frame of this file owns it. A leave from another window than the one shown for is not this
-- tooltip's.
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

-- True while the window is shown and under the mouse. An answer that cannot be read keeps the tooltip; the leave of the link takes it away.
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
		-- Another frame has the tooltip now: nothing of this file is up.
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

-- The owner frame: one of Flat UI's own, shown only while a link tooltip is up, and looking at it a few times a second.
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
				-- A look that fails takes the tooltip away, so the watch never runs on.
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

-- EventRegistry's ChatFrame.OnHyperlinkEnter and ChatFrame.OnHyperlinkLeave: the window, then for the enter the link and its text.
local function Entered(_, frame, link)
	if Wanted(TIPS) and Plain(frame, "table") then
		ns.EachPart(KEY, TIPS, ShowTip, frame, link)
	end
end

-- A window that cannot be read is taken for the one shown for.
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

-- Hooks and the pass of the module ------------------------------------------------------------

-- The three callbacks are given once, the first time the module is on with a row of this file on, and each asks its row when it comes. S.click
-- and S.hover are false when EventRegistry refused them.
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

-- Called by Chat.lua at the end of every refresh of the module: at its start, at a change of a row, when it goes off and when it stops.
function ns.ChatLinksSync()
	if ns.Enabled(KEY) and (Opt(ROW[LINKS]) == true or Opt(ROW[TIPS]) == true) then
		Listen()
	end
	Part(LINKS, SyncLinks)
	Part(TIPS, SyncTips)
	if not ns.Enabled(KEY) then
		CloseBox()
	end
end

-- True when the game has made a chat window: without one there is nothing to say about the links in it.
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
	return lines
end)
