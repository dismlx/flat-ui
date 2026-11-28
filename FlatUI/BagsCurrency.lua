local _, ns = ...

local B = ns.Bags
if type(B) ~= "table" or type(B.Currency) ~= "table" or type(ns.Errands) ~= "table" then
	return
end
local Currency = B.Currency
local E = ns.Errands

local KEY, PART = "bags", "currency"
local TOKEN_W, COMBINED_W, BACKPACK_W, MOST = 50, 430, 178, 20
local TEMPLATE = "BackpackTokenTemplate"
local GAP, HEIGHT, CROP = 8, 22, 8
local LONGEST = 5
local HOVER = 0.2
local DIM = { 0.66, 0.68, 0.62 }
local CLICK_LINE, FIGHT_LINE = "Click: open the Currency tab.", "Click: open the Currency tab, after the fight."
local SHIFT_LINE, LINK_LINE = "Shift-click: link it in chat, or take it off the footer.", "Shift-click: link it in chat."
local LATER_LINE = "Flat UI: the Currency tab opens when the fight ends."
local TAB_OPEN_LINE = "Flat UI: untick Show on Backpack on the Currency tab."

local states = setmetatable({}, { __mode = "k" })
local queued = false
local placed, placedW

local function Usable(value)
	return value ~= nil and not ns.IsSecret(value) and type(value) == "table"
end

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

local function Wanted()
	local opt = B.Opt
	return type(opt) ~= "function" or opt("currencies") ~= false
end

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

local function Count(value)
	if ns.Finite(value) and value >= 0 and value % 1 == 0 then
		return value
	end
	return nil
end

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

local function Crop()
	local look = B.Look
	local crop = type(look) == "function" and look("crop") or nil
	crop = ns.Finite(crop) and crop or CROP
	return math.floor(math.max(0, math.min(crop, 15)) + 0.5)
end

local function IconText(icon, crop)
	return ("|T%s:0:0:2:0:100:100:%d:%d:%d:%d|t"):format(tostring(icon), crop, 100 - crop, crop, 100 - crop)
end

local function Accent()
	local ok, r, g, b = pcall(ns.WindowColour, "windows.accent")
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

local function Modified(kind)
	if type(IsModifiedClick) ~= "function" then
		return false
	end
	local ok, held = pcall(IsModifiedClick, kind)
	return ok and not ns.IsSecret(held) and held == true
end

local function TabShown()
	local frame = _G.TokenFrame
	if not Usable(frame) or ns.Forbidden(frame) then
		return false
	end
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and not ns.IsSecret(shown) and shown == true
end

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
for _, name in ipairs({ "SetCurrencyBackpack", "SetCurrencyBackpackByID" }) do
	ns.FollowTable(_G.C_CurrencyInfo, name, Soon)
end
