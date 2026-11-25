local _, ns = ...

-- Bags: the currencies in the bag window's footer (B.Currency), the ones the Currency tab of the Character window marks Show on Backpack, which
-- the game's backpack shows under its slots (BackpackTokenFrameMixin, Camelot/Blizzard_TokenUI.lua:632-695) and which showed nowhere while Flat
-- UI's bag window stands in for the game's. Bags.lua makes ns.Bags with B.Currency; this file only adds its fields, and makes frames and font
-- strings of its own only, in a frame of its own inside the footer of BagsWindow.lua (w.foot), which that file hangs after the gold.
--
-- What the footer shows. While the bag window shows the player's own bags, the currencies as the game has them now: C_CurrencyInfo.
-- GetBackpackCurrencyInfo(index) (CurrencyInfoDocumentation.lua:97-111, MayReturnNothing; its fields name, quantity, iconFileID and
-- currencyTypesID, :645-655), index 1 up to the most the game's backpack shows, in that order, as the game reads them (:660-695). That most is
-- worked out as BackpackTokenFrameMixin:GetMaxTokensWatched does (:741-753), with widget calls and the client's API only, never that mixin's
-- method: as many of the game's tokens as fit across BackpackTokenFrame (GetWidth), each as wide as its template says (C_XMLUtil.GetTemplateInfo
-- of BackpackTokenTemplate, 50 units, Camelot/Blizzard_TokenUI.xml:294-295); while that frame has had no width (its template's is 1, :320-321),
-- as many as fit across the game's bag window as it would be drawn (ContainerFrame_GetApproximateWidth, Mainline/ContainerFrame.lua:2974-2987,
-- not called): the combined window of 10 slots of 37 units 5 apart with 15 of padding while the CVar combinedBags is on, else the backpack's 178
-- (:24-26, 892-898, 953-955; ContainerFrame.xml:77-78). While it shows another character's bags, that character's currencies as Flat UI last
-- read them (B.Data.Currencies, BagsData.lua), and none when none were kept; never this character's. Each is its count and then its icon, as
-- the gold is drawn (the count first, the icon at the text's height 2 units after it, GetMoneyString's way), in the footer's font
-- (GameFontHighlightSmall), the icon cropped by Icon crop of the Windows page (B.Look), the count as the game's backpack writes it
-- (BreakUpLargeNumbers, and AbbreviateNumbers once that is longer than 5 characters, :677-680). Every answer goes through ns.IsSecret or
-- ns.Finite: an entry with no whole ID above 0, no icon (a file ID, or a path with no | or :) or no whole count of 0 or more is left out.
--
-- Room. BagsWindow's ArrangeFoot gives B.Currency.Fit the room between the gold and the shortest text of the free slots, and Fit lays out what
-- fits there and gives back its frame and width, or nothing: with too little room the last currencies lose their counts first, one by one from
-- the last, then the last icons go, so the gold and the free slots are never reached. The currencies take no room in the window's least width
-- (BagsWindow's FootLeast), so the window never changes width for them; the footer has one line only.
--
-- When it is read. B.Currency.Read runs from BagsWindow's Footer, at each update of the footer and at each opening of the window; for the
-- player's own bags it also keeps what it read (B.Data.KeepCurrencies, written only when it changed and only while the record may be written).
-- CURRENCY_DISPLAY_UPDATE (CurrencyInfoDocumentation.lua:592-605, also as the currencies arrive at a login), added to the module with
-- ns.AddEvent (so heard only while the page is on), and a tick or an untick of Show on Backpack, which the Currency tab sends through
-- C_CurrencyInfo.SetCurrencyBackpack (TokenFrameMixin:SetTokenWatched, Camelot/Blizzard_TokenUI.lua:459-472) and the game's backpack token
-- through SetCurrencyBackpackByID (:770-787), both followed once at load with ns.FollowTable, each read the currencies again on the next frame,
-- once for a run of them (C_Timer.After), keep them, and ask for the footer of the bag window (B.Request); with the page or the row off they do
-- nothing. Each step runs as the part currency of the module (B.Part): one that keeps failing stops this part alone, and the footer then shows no
-- currencies.
--
-- The mouse. Each currency is a button of Flat UI's own, lit under the cursor in the Highlight colour of the Windows page. Its tooltip is
-- GameTooltip: out of a fight and for the player's own bags the game's own of that backpack currency (SetBackpackToken, as the game's token does,
-- :758-764; TooltipDataHandler.lua:555), else plain lines (SetText, AddLine) of its name (C_CurrencyInfo.GetCurrencyInfo,
-- CurrencyInfoDocumentation.lua:249-262, for another character's) and its count, then a line of what a click does; it is hidden when the cursor
-- leaves the button that owns it (IsOwned). A click goes as the game's token takes it (BackpackTokenMixin:OnClick, Blizzard_TokenUI.lua:770-787):
-- with the link modifier (IsModifiedClick CHATLINK, Shift) the currency's link (C_CurrencyInfo.GetCurrencyLink) goes in chat while a chat box
-- takes it (ChatFrameUtil.InsertLink, in a fight too); else, for the player's own bags, the backpack modifier (TOKENWATCHTOGGLE, Shift) takes it
-- off the backpack and so off the footer (C_CurrencyInfo.SetCurrencyBackpackByID with false), only while the Currency tab is not open (its list
-- would not be drawn again, as its Update is a mixin's: one line says to untick it there); else a plain left click opens the Currency tab of the
-- Character window as the game's token does (CharacterFrameMixin:ToggleTokenFrame, Camelot/CharacterFrame.lua:98-104: only while
-- C_CurrencyInfo.GetCurrencyListSize says there is a list, then the game's own ToggleCharacter("TokenFrame"), :3-30, as Data panels and the
-- reputation bar open their tabs), in a fight once it ends, with one line (ns.OpenAfterFight, MapText.lua). Another character's currency takes
-- the link alone, and its tooltip names no plain click.
-- Hidden by the window's hiding, a button may hear that before the window does, so a slot that owns the game's split box is left to the game
-- first (B.Buttons.Unsplit, BagsItems.lua), as BagsWindow's own footer buttons do.
--
-- It never writes a field on a frame of the game's or calls a mixin's method (not BackpackTokenFrame's or TokenFrame's Update, or
-- GetMaxTokensWatched), never ticks a currency, unticks one only on the player's Shift-click on it, calls nothing protected, and registers
-- nothing with Movers: it is part of the bag window. The bank window has no
-- currencies. Every frame and font string here is Flat UI's own.

local B = ns.Bags
if type(B) ~= "table" or type(B.Currency) ~= "table" or type(ns.Errands) ~= "table" then
	return
end
local Currency = B.Currency
local E = ns.Errands

local KEY, PART = "bags", "currency"
-- The width of one of the game's backpack tokens, the game's bag windows it falls back on (the combined window, the backpack), and the most this
-- file shows whatever a width says.
local TOKEN_W, COMBINED_W, BACKPACK_W, MOST = 50, 430, 178, 20
local TEMPLATE = "BackpackTokenTemplate"
-- The space between two currencies, the height of the footer when the client does not say, and the crop of an icon when the Windows page does
-- not say.
local GAP, HEIGHT, CROP = 8, 22, 8
-- The game's backpack writes a count shorter once it is longer than this.
local LONGEST = 5
-- The tint under the cursor, in the Highlight colour, and the colour of the plain lines of a tooltip (BagsWindow.lua, DIM).
local HOVER = 0.2
local DIM = { 0.66, 0.68, 0.62 }
local CLICK_LINE, FIGHT_LINE = "Click: open the Currency tab.", "Click: open the Currency tab, after the fight."
local SHIFT_LINE, LINK_LINE = "Shift-click: link it in chat, or take it off the footer.", "Shift-click: link it in chat."
local LATER_LINE = "Flat UI: the Currency tab opens when the fight ends."
local TAB_OPEN_LINE = "Flat UI: untick Show on Backpack on the Currency tab."

-- Per window (BagsWindow's w, the bag window's only): { w, holder, slots = { { button, text, hover, index } }, list = { entries }, live }. An
-- entry is { id, icon, count, index (the backpack's, live only), name (live only), full, short (its texts), fullW, shortW (their widths) }.
local states = setmetatable({}, { __mode = "k" })
-- A read waits for the next frame; what the last Fit laid out.
local queued = false
local placed, placedW

local function Usable(value)
	return value ~= nil and not ns.IsSecret(value) and type(value) == "table"
end

-- Runs fn as the currency part of Bags (B.Part, Bags.lua): a failure stops this part alone. False when it did not run through.
local function Run(fn, ...)
	local part = B.Part
	if type(part) ~= "function" then
		return false
	end
	return (part(PART, fn, ...))
end

local function Enabled()
	local ok, on = pcall(ns.Enabled, KEY)
	return ok and on == true
end

-- The row Currencies in the footer of the Bags page.
local function Wanted()
	local opt = B.Opt
	return type(opt) ~= "function" or opt("currencies") ~= false
end

-- A function of C_CurrencyInfo, or nil when the client has none.
local function Api(name)
	local api = _G.C_CurrencyInfo
	if not Usable(api) then
		return nil
	end
	local fn = api[name]
	return type(fn) == "function" and fn or nil
end

local function Ask(fn, ...)
	return E.Ask(fn, ...)
end

-- A whole number of 0 or more the client gave, or nil.
local function Count(value)
	if ns.Finite(value) and value >= 0 and value % 1 == 0 then
		return value
	end
	return nil
end

-- An icon the client gave that the footer can draw in a text: a file ID, or a path with no | or :, else nil.
local function Icon(value)
	if ns.Finite(value) then
		return value > 0 and value or nil
	end
	if type(value) == "string" and not ns.IsSecret(value) and value ~= "" and not value:find("[|:]") then
		return value
	end
	return nil
end

local function Text(value)
	if type(value) == "string" and not ns.IsSecret(value) and value ~= "" then
		return value
	end
	return nil
end

-- The most currencies the game's backpack shows (above).
local function Most()
	local tokenW = TOKEN_W
	local xml = _G.C_XMLUtil
	local info = Usable(xml) and Ask(xml.GetTemplateInfo, TEMPLATE) or nil
	if Usable(info) and ns.Finite(info.width) and info.width > 0 then
		tokenW = info.width
	end
	local width
	local frame = _G.BackpackTokenFrame
	if not ns.Forbidden(frame) then
		local ok, frameW = pcall(frame.GetWidth, frame)
		if ok and ns.Finite(frameW) and frameW > 1 then
			width = frameW
		end
	end
	if not width then
		local cvar = _G.C_CVar
		local combined = Usable(cvar) and Ask(cvar.GetCVarBool, "combinedBags") == true
		width = combined and COMBINED_W or BACKPACK_W
	end
	return math.max(1, math.min(MOST, math.floor(width / tokenW)))
end

-- The currencies of my backpack as the game has them now, in its order.
local function Live()
	local list = {}
	local read = Api("GetBackpackCurrencyInfo")
	if not read then
		return list
	end
	for index = 1, Most() do
		local info = Ask(read, index)
		if Usable(info) then
			local id, icon, count = Count(info.currencyTypesID), Icon(info.iconFileID), Count(info.quantity)
			if id and id > 0 and icon and count then
				list[#list + 1] = { id = id, icon = icon, count = count, index = index, name = Text(info.name) }
			end
		end
	end
	return list
end

-- A character's currencies as BagsData last kept them, or an empty list.
local function Kept(key)
	local data = B.Data
	local read = Usable(data) and data.Currencies or nil
	local list = {}
	if type(read) ~= "function" then
		return list
	end
	local ok, kept = pcall(read, key)
	if not ok or not Usable(kept) then
		return list
	end
	for _, entry in ipairs(kept) do
		if Usable(entry) then
			local id, icon, count = Count(entry[1]), Icon(entry[2]), Count(entry[3])
			if id and id > 0 and icon and count then
				list[#list + 1] = { id = id, icon = icon, count = count }
			end
		end
	end
	return list
end

-- Keeps my currencies with my record (B.Data.KeepCurrencies), which writes only when they changed.
local function Keep(list)
	local data = B.Data
	local keep = Usable(data) and data.KeepCurrencies or nil
	if type(keep) ~= "function" then
		return
	end
	local kept = {}
	for _, entry in ipairs(list) do
		kept[#kept + 1] = { entry.id, entry.icon, entry.count }
	end
	keep(kept)
end

-- A count as the game's backpack writes it.
local function Short(count)
	local text = Text(Ask(_G.BreakUpLargeNumbers, count)) or tostring(count)
	local okLength, length = pcall(_G.strlenutf8 or string.len, text)
	if not (okLength and ns.Finite(length)) then
		length = #text
	end
	if length > LONGEST then
		text = Text(Ask(_G.AbbreviateNumbers, count)) or text
	end
	return text
end

-- The crop of the icons, from the Windows page (B.Look, Bags.lua), as hundredths of each edge.
local function Crop()
	local look = B.Look
	local crop = type(look) == "function" and look("crop") or nil
	crop = ns.Finite(crop) and crop or CROP
	return math.floor(math.max(0, math.min(crop, 15)) + 0.5)
end

-- An icon in a text at the text's height, 2 units after what comes before it, as the game draws its coins, cropped.
local function IconText(icon, crop)
	return ("|T%s:0:0:2:0:100:100:%d:%d:%d:%d|t"):format(tostring(icon), crop, 100 - crop, crop, 100 - crop)
end

-- Red, green and blue of the Highlight colour of the Windows page.
local function Accent()
	local ok, r, g, b = pcall(ns.Colour, "windows.accent")
	if ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		return r, g, b
	end
	return 0.85, 0.85, 0.85
end

local function TextWidth(text)
	local ok, width = pcall(text.GetUnboundedStringWidth, text)
	if not (ok and ns.Finite(width)) then
		ok, width = pcall(text.GetStringWidth, text)
	end
	return ok and ns.Finite(width) and math.ceil(width) + 1 or 0
end

local function Own(object)
	ns.Own[object] = true
	return object
end

-- Tooltips and clicks --------------------------------------------------------------------------------------------------------------------------

local function Fighting()
	return E.Fighting() == true
end

local function Untip(owner)
	local tip = GameTooltip
	if not Usable(tip) or ns.Forbidden(tip) then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, owner)
	if ok and not ns.IsSecret(owned) and owned == true then
		tip:Hide()
	end
end

-- The name of a currency the client knows by its ID, for another character's.
local function NameOf(id)
	local info = Ask(Api("GetCurrencyInfo"), id)
	return Usable(info) and Text(info.name) or nil
end

local function Entered(state, slot)
	local entry = state.list[slot.index]
	local tip = GameTooltip
	if entry == nil or not Usable(tip) or ns.Forbidden(tip) then
		return
	end
	local button = slot.button
	tip:SetOwner(button, "ANCHOR_TOP")
	local shown = false
	local fighting = Fighting()
	if state.live and entry.index and not fighting then
		local ok, built = pcall(tip.SetBackpackToken, tip, entry.index)
		shown = ok and not ns.IsSecret(built) and built == true
		if not shown then
			-- The game hides the tooltip when it has nothing to show, so the owner is set again.
			tip:SetOwner(button, "ANCHOR_TOP")
		end
	end
	if not shown then
		tip:SetText(entry.name or NameOf(entry.id) or "Currency", 1, 1, 1)
		local count = Text(Ask(_G.BreakUpLargeNumbers, entry.count)) or tostring(entry.count)
		tip:AddLine(state.live and count or (count .. ", as Flat UI last saw it"), 1, 1, 1)
	end
	if state.live then
		tip:AddLine(fighting and FIGHT_LINE or CLICK_LINE, DIM[1], DIM[2], DIM[3], true)
		tip:AddLine(SHIFT_LINE, DIM[1], DIM[2], DIM[3], true)
	else
		tip:AddLine(LINK_LINE, DIM[1], DIM[2], DIM[3], true)
	end
	tip:Show()
end

-- True while the modifier of a modified click of the game's is held (IsModifiedClick).
local function Modified(kind)
	if type(IsModifiedClick) ~= "function" then
		return false
	end
	local ok, held = pcall(IsModifiedClick, kind)
	return ok and not ns.IsSecret(held) and held == true
end

-- True while the Currency tab of the Character window shows (TokenFrame, IsShown).
local function TabShown()
	local frame = _G.TokenFrame
	if not Usable(frame) or ns.Forbidden(frame) then
		return false
	end
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and not ns.IsSecret(shown) and shown == true
end

-- A click on a currency, in the order of the game's token (BackpackTokenMixin:OnClick): the chat link with the link modifier (Shift) while a chat
-- box takes it (ChatFrameUtil.InsertLink, in a fight too); else, for the player's own, the backpack modifier (Shift) takes it off the backpack
-- and so off the footer (C_CurrencyInfo.SetCurrencyBackpackByID, which the follower below hears), while the Currency tab is not open, as its list
-- would not be drawn again (its Update is a mixin's); else a plain click opens the Currency tab, after the fight in one (ns.OpenAfterFight).
local function Clicked(state, slot)
	local entry = state and slot and state.list[slot.index]
	if entry == nil then
		return
	end
	if Modified("CHATLINK") then
		local link = Text(Ask(Api("GetCurrencyLink"), entry.id))
		local util = _G.ChatFrameUtil
		if link and link:find("|H", 1, true) and Usable(util) and type(util.InsertLink) == "function" then
			local ok, linked = pcall(util.InsertLink, link)
			if ok and not ns.IsSecret(linked) and linked == true then
				return
			end
		end
	end
	if not state.live then
		return
	end
	if Modified("TOKENWATCHTOGGLE") then
		if TabShown() then
			print(TAB_OPEN_LINE)
		else
			E.Call(Api("SetCurrencyBackpackByID"), entry.id, false)
		end
		return
	end
	local size = Ask(Api("GetCurrencyListSize"))
	local toggle = _G.ToggleCharacter
	if not (ns.Finite(size) and size > 0 and type(toggle) == "function") then
		return
	end
	local function Open()
		toggle("TokenFrame")
	end
	if type(ns.OpenAfterFight) == "function" then
		ns.OpenAfterFight(Open, LATER_LINE)
	elseif not Fighting() then
		pcall(Open)
	end
end

-- The frames --------------------------------------------------------------------------------------------------------------------------------

-- The state of the bag window, with its frame in the footer, made the first time.
local function State(w)
	local state = states[w]
	if state then
		return state
	end
	if not Usable(w) or ns.Forbidden(w.foot) then
		return nil
	end
	local holder = Own(CreateFrame("Frame", nil, w.foot))
	holder:SetSize(1, HEIGHT)
	holder:Hide()
	state = { w = w, holder = holder, slots = {}, list = {}, live = false }
	states[w] = state
	return state
end

local function Height(state)
	local foot = state.w.foot
	local ok, height = pcall(foot.GetHeight, foot)
	return ok and ns.Finite(height) and height > 0 and height or HEIGHT
end

-- The button of the index-th currency, made the first time.
local function Slot(state, index)
	local slot = state.slots[index]
	if slot then
		return slot
	end
	local button = Own(CreateFrame("Button", nil, state.holder))
	button:RegisterForClicks("LeftButtonUp")
	button:SetSize(1, HEIGHT)
	local hover = Own(button:CreateTexture(nil, "HIGHLIGHT"))
	hover:SetAllPoints(button)
	local text = ns.OwnText(button, "OVERLAY", "GameFontHighlightSmall")
	text:SetAllPoints(button)
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)
	slot = { button = button, text = text, hover = hover, index = index }
	state.slots[index] = slot
	button:SetScript("OnEnter", function()
		Run(Entered, state, slot)
	end)
	button:SetScript("OnLeave", function()
		Untip(button)
	end)
	button:SetScript("OnClick", function()
		Run(Clicked, state, slot)
	end)
	-- Hidden by the window's hiding, it may hear that before the window does, so the game's split box is left to the game first.
	button:SetScript("OnHide", function()
		local frame = state.w.frame
		local okVisible, visible = pcall(frame.IsVisible, frame)
		local buttons = B.Buttons
		if not (okVisible and visible == true) and Usable(buttons) and type(buttons.Unsplit) == "function" then
			pcall(buttons.Unsplit)
		end
		Untip(button)
	end)
	return slot
end

local function Hide(state)
	if state then
		state.holder:Hide()
	end
end

-- Reading and laying out -------------------------------------------------------------------------------------------------------------------

-- What the footer shows for the character the window shows (key, mine: Layout.Viewed), with the texts and widths of each currency.
local function Read(w, key, mine)
	local state = State(w)
	if not state then
		return
	end
	local list = {}
	if Wanted() then
		if mine then
			list = Live()
			Keep(list)
		else
			list = Kept(key)
		end
	end
	state.list, state.live = list, mine == true
	local crop = Crop()
	local r, g, b = Accent()
	for index, entry in ipairs(list) do
		local slot = Slot(state, index)
		slot.hover:SetColorTexture(r, g, b, HOVER)
		entry.short = IconText(entry.icon, crop)
		entry.full = Short(entry.count) .. entry.short
		slot.text:SetText(entry.full)
		entry.fullW = TextWidth(slot.text)
		slot.text:SetText(entry.short)
		entry.shortW = TextWidth(slot.text)
	end
	for index = #list + 1, #state.slots do
		state.slots[index].button:Hide()
	end
end

-- Lays out what fits in room: every currency with its count, else the last ones without it, from the last, else fewer. Its frame and width, or
-- nil when nothing shows.
local function Arrange(w, room)
	local state = states[w]
	local list = state and state.list or {}
	local shown, counted = #list, #list
	if shown == 0 or not ns.Finite(room) or room <= 0 then
		Hide(state)
		return nil, nil
	end
	local width
	while shown > 0 do
		width = (shown - 1) * GAP
		for index = 1, shown do
			local entry = list[index]
			width = width + (index <= counted and entry.fullW or entry.shortW)
		end
		if width <= room then
			break
		end
		if counted > 0 then
			counted = counted - 1
		else
			shown = shown - 1
		end
	end
	if shown == 0 then
		Hide(state)
		return nil, nil
	end
	local height = Height(state)
	local x = 0
	for index = 1, shown do
		local entry, slot = list[index], state.slots[index]
		local full = index <= counted
		local slotW = full and entry.fullW or entry.shortW
		slot.text:SetText(full and entry.full or entry.short)
		slot.button:ClearAllPoints()
		slot.button:SetPoint("LEFT", state.holder, "LEFT", x, 0)
		slot.button:SetSize(math.max(1, slotW), height)
		slot.button:Show()
		x = x + slotW + GAP
	end
	for index = shown + 1, #state.slots do
		state.slots[index].button:Hide()
	end
	state.holder:SetSize(math.max(1, width), height)
	state.holder:Show()
	return state.holder, width
end

local function Place(w, room)
	placed, placedW = Arrange(w, room)
end

-- B.Currency.Read(w, key, mine), from BagsWindow's Footer for the bag window: reads the currencies of the character it shows. A part that failed
-- or stopped shows none.
function Currency.Read(w, key, mine)
	if not Usable(w) or w.which ~= "bags" then
		return
	end
	if not Run(Read, w, key, mine) then
		local state = states[w]
		if state then
			state.list = {}
			pcall(Hide, state)
		end
	end
end

-- B.Currency.Fit(w, room), from BagsWindow's ArrangeFoot: lays the currencies out in room and gives back their frame, a child of the footer for
-- BagsWindow to hang after the gold, and its width; nothing when none shows.
function Currency.Fit(w, room)
	placed, placedW = nil, nil
	if not Usable(w) or w.which ~= "bags" then
		return nil
	end
	if not Run(Place, w, room) then
		pcall(Hide, states[w])
		return nil
	end
	if placed and ns.Finite(placedW) then
		return placed, placedW
	end
	return nil
end

-- The game's currencies changed ---------------------------------------------------------------------------------------------------------------

-- My currencies are read again and kept, and the bag window's footer asked for again.
local function Changed()
	if not Enabled() or not Wanted() then
		return
	end
	Keep(Live())
	local request = B.Request
	if type(request) == "function" then
		request("footer", "bags")
	end
end

local function Soon()
	if queued then
		return
	end
	queued = true
	local function Go()
		queued = false
		Run(Changed)
	end
	local timer = type(C_Timer) == "table" and C_Timer.After or nil
	if not (type(timer) == "function" and pcall(timer, 0, Go)) then
		Go()
	end
end

ns.AddEvent(KEY, "CURRENCY_DISPLAY_UPDATE", Soon)
-- A tick or an untick of Show on Backpack: the Currency tab, and the game's backpack token.
for _, name in ipairs({ "SetCurrencyBackpack", "SetCurrencyBackpackByID" }) do
	ns.FollowTable(_G.C_CurrencyInfo, name, Soon)
end
