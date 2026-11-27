local _, ns = ...

local B = ns.Bags
if type(B) ~= "table" or type(B.Bank) ~= "table" then
	return
end
local Bank = B.Bank
local E = ns.Errands

local KEY = "bags"
local PART = "bank"
local CHARACTER, BANK_BAGS, TAB_OF_SLOT = 0, -2, 5
local BANKERS = { Banker = 8, CharacterBanker = 67, AccountBanker = 68 }
local FIRST_BAG, MOST_BAGS = 2, 9
local BAGS = { 0, 1, 2, 3, 4, 5 }
local MOST_SLOTS = 200
local SPACING = 0.15
local WAIT, LOOKS = 1, 3
local POLL = 1
local PER_CLICK = false
local BLOCKERS = {
	{ "MerchantFrame", "merchant window" },
	{ "TradeFrame", "trade window" },
	{ "MailFrame", "mailbox" },
	{ "AuctionHouseFrame", "auction house" },
	{ "GuildBankFrame", "guild bank" },
}
local WORDS = {
	deposit = { label = "Deposit", done = "Deposited", none = "Deposited nothing", room = "the bank has no room for %s",
		empty = "no item in your bags matches the search", emptyOf = "no item of that section is in your bags" },
	takeout = { label = "Take out", done = "Took out", none = "Took nothing out", room = "your bags have no room for %s",
		empty = "no item in your bank matches the search", emptyOf = "no item of that section is in your bank" },
}
local SLOT, GAP = 28, 4
local BUY_WIDTH, BUY_HEIGHT = 56, 22
local TEMPLATE = "BankPanelPurchaseButtonScriptTemplate"
local BUY_POPUP = "CONFIRM_BUY_BANK_TAB"
local LOCK = "bankslot-icon-lock"
local EMPTY_ART = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
local NO_SPACE = "Your bank has no space yet."
local HOVER = { 1, 1, 1, 0.3 }
local DIM = { 0.8, 0.8, 0.8 }
local RED = { 1, 0.35, 0.24 }
local COUNT_FONT, COUNT_SIZE = "NumberFontNormal", 11
local ROOM, SHORT, LOW = { 1, 1, 1 }, { 1, 0.82, 0 }, 4
local CROP, TIP_GAP = 8, 4

local BUTTON = "FlatUIBankButton"
local BINDING = "CLICK " .. BUTTON .. ":LeftButton"

_G["BINDING_NAME_" .. BINDING] = "Flat UI bank"

local open, flat, closing = false, false, false
local closeWait
local sent = {}
local pass
local row
local buyQueued, buyBroken = false, false
local watched
local following = false

local Finish, Resume, Update

local function Usable(value)
	return value ~= nil and not ns.IsSecret(value) and type(value) == "table"
end

local function Field(info, key)
	local value = info[key]
	if ns.IsSecret(value) then
		return nil
	end
	return value
end

local function EnumValue(group, name, fallback)
	local enum = type(Enum) == "table" and not ns.IsSecret(Enum) and Enum[group] or nil
	local value = Usable(enum) and enum[name] or nil
	return ns.Finite(value) and value or fallback
end

local function Character()
	return EnumValue("BankType", "Character", CHARACTER)
end

local function Container(name)
	local api = C_Container
	if not Usable(api) then
		return nil
	end
	local fn = api[name]
	return type(fn) == "function" and fn or nil
end

local function BankAsk(name)
	local api = C_Bank
	if not Usable(api) then
		return nil
	end
	return (E.Ask(api[name], Character()))
end

local function After(seconds, fn)
	if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		return false
	end
	return (pcall(C_Timer.After, seconds, fn))
end

local function Clock()
	local now = E.Ask(GetTime)
	return ns.Finite(now) and now or nil
end

local function On()
	local on = B.On
	if type(on) ~= "function" then
		return false
	end
	local ok, yes = pcall(on)
	return ok and yes == true
end

local function Run(fn, ...)
	local part = B.Part
	if type(part) ~= "function" then
		return false
	end
	return part(PART, fn, ...)
end

local function Call(part, owner, name, ...)
	local fn = Usable(owner) and owner[name] or nil
	local run = B.Part
	if type(fn) ~= "function" or type(run) ~= "function" then
		return false
	end
	return run(part, fn, ...)
end

local function RequestFooter()
	Call("window", B, "Request", "footer", "bank")
end

local function Items(n)
	return n == 1 and "item" or "items"
end

local function CursorBusy()
	return E.Ask(GetCursorInfo) ~= nil or E.Ask(CursorHasItem) == true
end

local function Targeting()
	return E.Ask(SpellIsTargeting) == true or E.Ask(SpellCanTargetItem) == true or E.Ask(SpellCanTargetItemID) == true
end

local function Blocker()
	for _, entry in ipairs(BLOCKERS) do
		if E.Shown(_G[entry[1]]) then
			return entry[2]
		end
	end
	return nil
end

local function Held(bag, slot)
	local get = Container("GetContainerItemInfo")
	local info = get and E.Ask(get, bag, slot) or nil
	if not Usable(info) then
		return nil
	end
	local id = Field(info, "itemID")
	if not ns.Finite(id) then
		return nil
	end
	local link, count, locked = Field(info, "hyperlink"), Field(info, "stackCount"), Field(info, "isLocked")
	local icon, name = Field(info, "iconFileID"), Field(info, "itemName")
	return {
		id = id,
		link = type(link) == "string" and link or nil,
		count = ns.Finite(count) and count > 0 and count or 1,
		locked = locked ~= false,
		icon = (ns.Finite(icon) or type(icon) == "string") and icon or nil,
		name = type(name) == "string" and name ~= "" and name or nil,
	}
end

local function TipGone(owner)
	local tip = GameTooltip
	if not Usable(tip) or ns.Forbidden(tip) then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, owner)
	if ok and not ns.IsSecret(owned) and owned == true then
		tip:Hide()
	end
end

local function Parked()
	local parked, frame = ns.BagsParked, _G.BankFrame
	if type(parked) ~= "function" or not Usable(frame) then
		return false
	end
	local ok, yes = pcall(parked, frame)
	return ok and yes == true
end

function Bank.Live()
	return open and flat and not closing and On()
end

function Bank.Visiting()
	return open == true
end

local function Sent(move)
	local now = Clock()
	local kept = {}
	if now then
		for _, entry in ipairs(sent) do
			if now - entry.at < WAIT then
				kept[#kept + 1] = entry
			end
		end
		kept[#kept + 1] = { bag = move.bag, slot = move.slot, id = move.id, link = move.link, at = now }
	end
	sent = kept
end

local function Unanswered()
	local now = Clock()
	if not now then
		return false
	end
	for _, entry in ipairs(sent) do
		if now - entry.at < WAIT then
			local held = Held(entry.bag, entry.slot)
			if held and held.locked and held.id == entry.id and held.link == entry.link then
				return true
			end
		end
	end
	return false
end

local function CloseBank(token)
	if closeWait ~= token or not open or not closing then
		return
	end
	closeWait = nil
	local api = C_Bank
	if Usable(api) and type(api.CloseBankFrame) == "function" then
		local bank = _G.BankFrame
		if Parked() and E.Shown(bank) then
			pcall(bank.Hide, bank)
		end
		pcall(api.CloseBankFrame)
	end
end

local function Await(token)
	if closeWait ~= token or not open or not closing then
		return
	end
	if Unanswered() and After(0, function()
		Await(token)
	end) then
		return
	end
	if not After(0, function()
		CloseBank(token)
	end) then
		CloseBank(token)
	end
end

local function EndVisit()
	if not open or not flat or closing then
		return
	end
	closing = true
	local token = {}
	closeWait = token
	local hold = B.Hold
	if type(hold) == "function" then
		pcall(hold, "bank", false)
	end
	if Unanswered() and After(0, function()
		Await(token)
	end) then
		return
	end
	CloseBank(token)
end

local function WindowHidden(window)
	if open and flat and not closing and not E.Shown(window) then
		EndVisit()
	end
end

function Bank.Hidden()
	if open and flat and not closing then
		EndVisit()
	end
end

local function Watch()
	local window = B.Window.Get("bank")
	if window == watched or not Usable(window) or ns.Forbidden(window) or type(window.HookScript) ~= "function" then
		return
	end
	if pcall(window.HookScript, window, "OnHide", WindowHidden) then
		watched = window
	end
end

local function PanelHidden(frame)
	if not open or not flat or closing or frame == nil or ns.IsSecret(frame) then
		return
	end
	local bank = _G.BankFrame
	if bank == nil or ns.IsSecret(bank) or not rawequal(frame, bank) or E.Shown(bank) then
		return
	end
	EndVisit()
end

local function Follow()
	if not following then
		following = ns.FollowGlobal("HideUIPanel", PanelHidden) == true
	end
end

local function Bought()
	local n = BankAsk("FetchNumPurchasedBankTabs")
	return ns.Finite(n) and n >= 0 and math.floor(n) or 0
end

local function MostBags()
	local n = BankAsk("FetchMaxNumBankTabs")
	if ns.Finite(n) and n >= 1 then
		return math.min(math.floor(n), MOST_BAGS)
	end
	return MOST_BAGS
end

local function Crop()
	local look = B.Look
	local crop = type(look) == "function" and look("crop") or nil
	crop = ns.Finite(crop) and crop or CROP
	return math.max(0, math.min(crop, 15)) / 100
end

local function Paint(box)
	if box then
		local r, g, b = ns.Colour("windows.panel")
		ns.SetOutlineFill(box, r, g, b, 1)
	end
end

local function Hover(button)
	local hover = button:CreateTexture(nil, "HIGHLIGHT")
	ns.Own[hover] = true
	hover:SetAllPoints(button)
	hover:SetColorTexture(HOVER[1], HOVER[2], HOVER[3], HOVER[4])
end

local function Room(n)
	local free = E.Ask(Container("GetContainerNumFreeSlots"), n + TAB_OF_SLOT)
	local total = E.Ask(Container("GetContainerNumSlots"), n + TAB_OF_SLOT)
	if ns.Finite(free) and ns.Finite(total) and total > 0 then
		return math.max(0, math.floor(free)), math.floor(total)
	end
	return nil, nil
end

local function RoomLine(n)
	local free, total = Room(n)
	if free then
		return ("%d of %d slots free"):format(free, total)
	end
	return nil
end

local function Stuck()
	local layout = B.Layout
	local stuck = Usable(layout) and layout.Stuck or nil
	if type(stuck) ~= "function" then
		return nil
	end
	local ok, c = pcall(stuck, "bank")
	return ok and ns.Finite(c) and (c - TAB_OF_SLOT) or nil
end

local function Edge(slot, n)
	if Stuck() == n then
		local r, g, b = ns.Colour("windows.accent")
		ns.SetOutlineColour(slot.box, r, g, b)
	else
		ns.SetOutlineColour(slot.box, nil, nil, nil)
	end
end

local function Pickup(n)
	if not Bank.Live() or n > Bought() then
		return
	end
	if E.Fighting() then
		print("Flat UI: the bank's bag slots take no clicks in a fight.")
		return
	end
	local layout = B.Layout
	if Stuck() == n and Usable(layout) and type(layout.Stick) == "function" then
		local kind, id = E.Ask(GetCursorInfo)
		local api = C_Item
		local equip = kind == "item" and ns.Finite(id) and Usable(api) and select(4, E.Ask(api.GetItemInfoInstant, id)) or nil
		if E.Ask(CursorHasItem) ~= true or equip == "INVTYPE_BAG" then
			B.Part("layout", layout.Stick, "bank", nil)
			for other, slot in pairs(row and row.slots or {}) do
				Edge(slot, other)
			end
		end
	end
	E.Call(Container("PickupContainerItem"), BANK_BAGS, n)
end

local function Click(n)
	if E.Ask(CursorHasItem) == true then
		Pickup(n)
		return
	end
	local layout = B.Layout
	if not (Bank.Live() and n <= Bought() and Held(BANK_BAGS, n)) or not Usable(layout) or type(layout.Stick) ~= "function" then
		return
	end
	B.Part("layout", layout.Stick, "bank", Stuck() ~= n and (n + TAB_OF_SLOT) or nil)
	for other, slot in pairs(row and row.slots or {}) do
		Edge(slot, other)
	end
end

local function Middle(frame)
	local ok, left, right, scale = pcall(function()
		return frame:GetLeft(), frame:GetRight(), frame:GetEffectiveScale()
	end)
	if ok and ns.Finite(left) and ns.Finite(right) and ns.Finite(scale) and scale > 0 then
		return (left + right) / 2 * scale
	end
	return nil
end

local function Anchor(tip, button)
	local window
	local get = Usable(B.Window) and B.Window.Get or nil
	if type(get) == "function" then
		local ok, frame = pcall(get, "bank")
		window = ok and Usable(frame) and frame or nil
	end
	local at, screen = window and Middle(window), Middle(UIParent)
	if not (at and screen) then
		tip:SetOwner(button, "ANCHOR_RIGHT")
		return
	end
	tip:SetOwner(button, "ANCHOR_NONE")
	tip:ClearAllPoints()
	if at > screen then
		tip:SetPoint("BOTTOMRIGHT", window, "BOTTOMLEFT", -TIP_GAP, 0)
	else
		tip:SetPoint("BOTTOMLEFT", window, "BOTTOMRIGHT", TIP_GAP, 0)
	end
end

local function ClickLines(tip, n)
	local click = Stuck() == n and "Click again to show every bag" or "Click to show only this bag"
	tip:AddLine(click .. "; drag it to pick it up, or drop another bag on it to swap.", DIM[1], DIM[2], DIM[3], true)
end

local function SlotTip(button, n)
	local tip = GameTooltip
	if not Usable(tip) or ns.Forbidden(tip) then
		return
	end
	local bought = n <= Bought()
	local held = bought and Held(BANK_BAGS, n) or nil
	local room = held and RoomLine(n) or nil
	Anchor(tip, button)
	if held and not E.Fighting() then
		local ok, shown = pcall(tip.SetBagItem, tip, BANK_BAGS, n)
		if ok and not ns.IsSecret(shown) and shown ~= false then
			if room then
				tip:AddLine(room, 1, 1, 1)
			end
			ClickLines(tip, n)
			tip:Show()
			return
		end
		Anchor(tip, button)
	end
	if not bought then
		tip:SetText("Bank bag slot")
		tip:AddLine("Not bought yet. The Buy button beside these slots shows the price.", DIM[1], DIM[2], DIM[3], true)
	elseif held then
		tip:SetText(held.name or "Bank bag")
		if room then
			tip:AddLine(room, 1, 1, 1)
		end
		tip:AddLine("In a bank bag slot.", DIM[1], DIM[2], DIM[3], true)
		ClickLines(tip, n)
	else
		tip:SetText("Bank bag slot")
		tip:AddLine("Drop a bag here, or click with one on your cursor, to add its slots to your bank.", DIM[1], DIM[2], DIM[3], true)
	end
	tip:Show()
end

local function Retip(button, n)
	local tip = GameTooltip
	if not Usable(tip) or ns.Forbidden(tip) then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, button)
	if ok and not ns.IsSecret(owned) and owned == true then
		SlotTip(button, n)
	end
end

local function Light(n)
	local layout = B.Layout
	if Usable(layout) and type(layout.Light) == "function" then
		B.Part("layout", layout.Light, "bank", n and (n + TAB_OF_SLOT) or nil)
	end
end

local function MakeSlot(n)
	local button = CreateFrame("Button", nil, row.frame)
	ns.Own[button] = true
	button:SetSize(SLOT, SLOT)
	local slot = { button = button, box = ns.Outline(button, button) }
	slot.icon = button:CreateTexture(nil, "ARTWORK")
	ns.Own[slot.icon] = true
	slot.icon:SetAllPoints(button)
	slot.lock = button:CreateTexture(nil, "OVERLAY")
	ns.Own[slot.lock] = true
	slot.lock:SetAllPoints(button)
	pcall(slot.lock.SetAtlas, slot.lock, LOCK)
	Hover(button)
	slot.count = ns.OwnText(button, "OVERLAY", COUNT_FONT)
	if slot.count then
		local ok, file = pcall(slot.count.GetFont, slot.count)
		if ok and type(file) == "string" and not ns.IsSecret(file) and file ~= "" then
			pcall(slot.count.SetFont, slot.count, file, COUNT_SIZE, "OUTLINE")
		end
		slot.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
		slot.count:SetJustifyH("RIGHT")
	end
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetScript("OnClick", function(self, mouse)
		if mouse == "LeftButton" or E.Ask(CursorHasItem) == true then
			Run(Click, n)
		end
		Run(Retip, self, n)
	end)
	button:SetScript("OnDragStart", function()
		Run(Pickup, n)
	end)
	button:SetScript("OnReceiveDrag", function()
		Run(Pickup, n)
	end)
	button:SetScript("OnEnter", function(self)
		Run(SlotTip, self, n)
		if n <= Bought() then
			Light(n)
		end
	end)
	button:SetScript("OnLeave", function(self)
		Run(TipGone, self)
		Light(nil)
	end)
	button:SetScript("OnHide", function(self)
		Run(TipGone, self)
		Light(nil)
	end)
	row.slots[n] = slot
	return slot
end

local function DrawSlot(slot, n, bought, crop)
	local isBought = n <= bought
	local held = isBought and Held(BANK_BAGS, n) or nil
	slot.lock:SetShown(not isBought)
	if held and held.icon then
		slot.icon:SetTexture(held.icon)
		slot.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
		slot.icon:SetAlpha(1)
		pcall(slot.icon.SetDesaturated, slot.icon, held.locked == true)
		slot.icon:Show()
	elseif isBought and not held then
		slot.icon:SetTexture(EMPTY_ART)
		slot.icon:SetTexCoord(0, 1, 0, 1)
		slot.icon:SetAlpha(0.5)
		pcall(slot.icon.SetDesaturated, slot.icon, false)
		slot.icon:Show()
	else
		slot.icon:Hide()
	end
	local free = held and Room(n) or nil
	if slot.count and free then
		local colour = free == 0 and RED or free <= LOW and SHORT or ROOM
		slot.count:SetTextColor(colour[1], colour[2], colour[3], 1)
		slot.count:SetText(tostring(free))
		slot.count:Show()
	elseif slot.count then
		slot.count:Hide()
	end
	slot.button:SetAlpha(isBought and 1 or 0.6)
	Paint(slot.box)
	Edge(slot, n)
end

local function RowShowing()
	if not row or not Bank.Live() then
		return false
	end
	local ok, visible = pcall(row.frame.IsVisible, row.frame)
	return ok and visible == true
end

local function Redraw()
	if not RowShowing() then
		return
	end
	local bought, crop = Bought(), Crop()
	for n, slot in pairs(row.slots) do
		if slot.button:IsShown() then
			DrawSlot(slot, n, bought, crop)
		end
	end
end

local function Fits()
	if not row then
		return
	end
	local lit = false
	if RowShowing() then
		local kind, id = E.Ask(GetCursorInfo)
		local api = C_Item
		local equip = kind == "item" and ns.Finite(id) and Usable(api) and select(4, E.Ask(api.GetItemInfoInstant, id)) or nil
		lit = equip == "INVTYPE_BAG"
	end
	local bought = Bought()
	for n, slot in pairs(row.slots) do
		if lit and n <= bought then
			slot.button:LockHighlight()
		else
			slot.button:UnlockHighlight()
		end
	end
end

local function BuyTip(button)
	local tip = GameTooltip
	if not Usable(tip) or ns.Forbidden(tip) then
		return
	end
	tip:SetOwner(button, "ANCHOR_TOP")
	tip:SetText(Bought() == 0 and "Buy your bank's first slots" or "Buy a bank bag slot")
	local data = BankAsk("FetchNextPurchasableBankTabData")
	if Usable(data) then
		local cost = Field(data, "tabCost")
		if ns.Finite(cost) then
			tip:AddLine(cost > 0 and ("Costs %s"):format(E.Money(cost)) or "Free", 1, 1, 1)
		end
		if Field(data, "canAfford") == false then
			tip:AddLine("You do not have that much gold yet.", RED[1], RED[2], RED[3], true)
		end
	end
	tip:AddLine("The game asks before it buys.", DIM[1], DIM[2], DIM[3], true)
	tip:Show()
end

local function MakeBuy()
	if not row or row.buy or buyBroken then
		return
	end
	if E.InCombat() then
		if not buyQueued then
			buyQueued = true
			ns.OutOfCombat(function()
				buyQueued = false
				Run(function()
					MakeBuy()
					Update()
					if row and row.buy then
						RequestFooter()
					end
				end)
			end)
		end
		return
	end
	local ok, button = pcall(CreateFrame, "Button", nil, row.frame, TEMPLATE)
	if not ok or not Usable(button) then
		buyBroken = true
		return
	end
	ns.Own[button] = true
	if not pcall(button.SetAttribute, button, "overrideBankType", Character()) then
		buyBroken = true
		button:Hide()
		return
	end
	button:SetSize(BUY_WIDTH, BUY_HEIGHT)
	local box = ns.Outline(button, button, true)
	local label = ns.OwnText(button, "OVERLAY", "GameFontHighlightSmall")
	if label then
		label:SetPoint("CENTER", button, "CENTER", 0, 0)
		label:SetText("Buy")
	end
	Hover(button)
	button:SetScript("OnEnter", function(self)
		Run(BuyTip, self)
	end)
	button:SetScript("OnLeave", function(self)
		Run(TipGone, self)
	end)
	button:SetScript("OnHide", function(self)
		Run(TipGone, self)
	end)
	button:Hide()
	row.buy, row.buyBox = button, box
end

Update = function()
	if not row then
		return 0, 0
	end
	local frame = row.frame
	if not Bank.Live() then
		frame:Hide()
		return 0, 0
	end
	MakeBuy()
	local bought, x = Bought(), 0
	if bought == 0 then
		for _, slot in pairs(row.slots) do
			slot.button:Hide()
		end
		if row.text then
			row.text:Show()
			local ok, width = pcall(row.text.GetStringWidth, row.text)
			x = (ok and ns.Finite(width) and math.ceil(width) or 160) + GAP
		end
	else
		if row.text then
			row.text:Hide()
		end
		local most, crop = MostBags(), Crop()
		for n = FIRST_BAG, MOST_BAGS do
			local slot = row.slots[n]
			if n <= most then
				slot = slot or MakeSlot(n)
				slot.button:ClearAllPoints()
				slot.button:SetPoint("LEFT", frame, "LEFT", x, 0)
				DrawSlot(slot, n, bought, crop)
				slot.button:Show()
				x = x + SLOT + GAP
			elseif slot then
				slot.button:Hide()
			end
		end
	end
	local buy = row.buy
	if buy then
		if BankAsk("CanPurchaseBankTab") == true then
			buy:ClearAllPoints()
			buy:SetPoint("LEFT", frame, "LEFT", x, 0)
			Paint(row.buyBox)
			buy:Show()
			x = x + BUY_WIDTH + GAP
		else
			buy:Hide()
		end
	end
	local width = math.max(x - GAP, 1)
	frame:SetSize(width, SLOT)
	frame:Show()
	return width, SLOT
end

local function MakeRow(parent)
	local frame = CreateFrame("Frame", nil, parent)
	ns.Own[frame] = true
	frame:SetSize(1, SLOT)
	local text = ns.OwnText(frame, "OVERLAY", "GameFontHighlightSmall")
	if text then
		text:SetPoint("LEFT", frame, "LEFT", 0, 0)
		text:SetText(NO_SPACE)
	end
	row = { frame = frame, parent = parent, slots = {}, text = text }
end

function Bank.Slots(frame)
	local width, height = 0, 0
	Run(function()
		if not Usable(frame) or ns.Forbidden(frame) then
			return
		end
		if not row then
			MakeRow(frame)
		elseif row.parent ~= frame then
			row.frame:SetParent(frame)
			row.parent = frame
		end
		row.frame:ClearAllPoints()
		row.frame:SetPoint("LEFT", frame, "LEFT", 0, 0)
		width, height = Update()
	end)
	return width, height
end

local function Sources(kind, me)
	if kind == "deposit" then
		return BAGS
	end
	local list = B.Data.Containers("bank", me)
	return type(list) == "table" and list or {}
end

local function Takes(record, filter)
	if filter then
		local ok, yes = pcall(filter, record)
		return ok and yes == true
	end
	return B.Search.Match(record) == true
end

local function Queue(kind, filter)
	local queue, me = {}, B.Me()
	local slotsOf = Container("GetContainerNumSlots")
	if type(me) ~= "string" or not slotsOf then
		return queue
	end
	for _, bag in ipairs(Sources(kind, me)) do
		if ns.Finite(bag) and bag >= 0 then
			local slots = E.Ask(slotsOf, bag)
			slots = ns.Finite(slots) and slots > 0 and slots <= MOST_SLOTS and slots or 0
			for slot = 1, slots do
				local held = Held(bag, slot)
				if held and held.link and not held.locked then
					local record = B.Data.Item(me, bag, slot)
					if Usable(record) and record.id == held.id and Takes(record, filter) then
						queue[#queue + 1] = { bag = bag, slot = slot, id = held.id, link = held.link }
					end
				end
			end
		end
	end
	return queue
end

local function Refusal(filter)
	if not Bank.Live() then
		return "the bank is not open"
	end
	if E.Fighting() then
		return "you are in a fight"
	end
	if CursorBusy() then
		return "the cursor holds something"
	end
	if Targeting() then
		return "a spell waits for its target"
	end
	local blocker = Blocker()
	if blocker then
		return ("the %s is open"):format(blocker)
	end
	if not filter and B.Search.Active() ~= true then
		return "type a search first, and what matches it moves"
	end
	return nil
end

local function Stopper()
	if not Bank.Live() then
		return "the bank closed"
	end
	if CursorBusy() then
		return "the cursor held something"
	end
	if Targeting() then
		return "a spell waited for its target"
	end
	local blocker = Blocker()
	if blocker then
		return ("the %s opened"):format(blocker)
	end
	return nil
end

local function Use(kind, move)
	local use = Container("UseContainerItem")
	if not use then
		return false
	end
	if kind == "deposit" then
		return E.Call(use, move.bag, move.slot, nil, Character(), false)
	end
	return E.Call(use, move.bag, move.slot)
end

local function Verify(run, move, count, looks)
	if pass ~= run then
		return
	end
	local held = Held(move.bag, move.slot)
	local same = held ~= nil and held.id == move.id and held.link == move.link and held.count == count
	if same and held.locked and looks < LOOKS then
		if After(WAIT, function()
			Run(Verify, run, move, count, looks + 1)
		end) then
			return
		end
	end
	run.checks = run.checks - 1
	if same then
		run.moved = math.max(0, run.moved - 1)
		Finish(WORDS[run.kind].room:format(move.link))
	elseif run.draining and run.checks <= 0 then
		Finish(nil)
	end
end

local function Move(run, move)
	local held = Held(move.bag, move.slot)
	if not held or held.locked or held.id ~= move.id or held.link ~= move.link then
		return false
	end
	if not Use(run.kind, move) then
		return false
	end
	Sent(move)
	run.moved = run.moved + 1
	run.checks = run.checks + 1
	local count = held.count
	if not After(WAIT, function()
		Run(Verify, run, move, count, 1)
	end) then
		run.checks = run.checks - 1
	end
	return true
end

local function Drain(run)
	run.draining = true
	if run.checks <= 0 then
		Finish(nil)
	end
end

local function Pause(run)
	run.paused = true
	RequestFooter()
	if not After(POLL, function()
		Run(Resume, run)
	end) then
		Finish("a fight started")
	end
end

local function Step(run)
	if pass ~= run or run.paused or run.draining then
		return
	end
	local why = Stopper()
	if why then
		Finish(why)
		return
	end
	if E.Fighting() then
		Pause(run)
		return
	end
	local move = run.queue[run.next]
	if not move then
		Drain(run)
		return
	end
	run.next = run.next + 1
	Move(run, move)
	RequestFooter()
	if not After(SPACING, function()
		Run(Step, run)
	end) then
		Finish("the game gave no timer")
	end
end

Resume = function(run)
	if pass ~= run or not run.paused then
		return
	end
	if E.Fighting() then
		if not After(POLL, function()
			Run(Resume, run)
		end) then
			Finish("a fight started")
		end
		return
	end
	if not run.filter and B.Search.Active() ~= true then
		Finish("the search was cleared")
		return
	end
	run.paused = false
	run.queue, run.next = Queue(run.kind, run.filter), 1
	Step(run)
end

Finish = function(why)
	local run = pass
	pass = nil
	if not run then
		return
	end
	local words = WORDS[run.kind]
	if run.moved > 0 then
		local tail = ""
		if why == true then
			tail = ", then stopped"
		elseif why then
			tail = ", then stopped: " .. why
		end
		E.Say(("%s %d %s%s."):format(words.done, run.moved, Items(run.moved), tail))
	elseif why and why ~= true then
		E.Say(("%s: %s."):format(words.none, why))
	end
	RequestFooter()
end

local function Start(kind, filter)
	local run = pass
	if run and run.draining then
		Finish(nil)
		run = nil
	end
	if run and run.kind == kind and not PER_CLICK and not filter then
		Finish(true)
		return true
	end
	if run and (run.kind ~= kind or filter or run.filter) then
		Finish(true)
		run = nil
	end
	local why = Refusal(filter)
	if why then
		print(("Flat UI: %s: %s."):format(WORDS[kind].none, why))
		return false, why
	end
	local queue = Queue(kind, filter)
	if #queue == 0 then
		if run then
			Drain(run)
		else
			print(("Flat UI: %s: %s."):format(WORDS[kind].none, filter and WORDS[kind].emptyOf or WORDS[kind].empty))
		end
		RequestFooter()
		return false, "nothing matches"
	end
	if PER_CLICK then
		run = run or { kind = kind, moved = 0, checks = 0, filter = filter }
		pass = run
		run.left = #queue - 1
		Move(run, queue[1])
		if run.left <= 0 then
			Drain(run)
		end
		RequestFooter()
		return true
	end
	run = { kind = kind, queue = queue, next = 1, moved = 0, checks = 0, filter = filter }
	pass = run
	Step(run)
	RequestFooter()
	return true
end

function Bank.Deposit(filter)
	local ok, why = false, nil
	Run(function()
		ok, why = Start("deposit", type(filter) == "function" and filter or nil)
	end)
	return ok, why
end

function Bank.TakeOut(filter)
	local ok, why = false, nil
	Run(function()
		ok, why = Start("takeout", type(filter) == "function" and filter or nil)
	end)
	return ok, why
end

function Bank.Busy()
	local run = pass
	if not run or run.draining then
		return nil, 0, PER_CLICK
	end
	if PER_CLICK then
		return run.kind, run.left or 0, true
	end
	return run.kind, math.max(0, #run.queue - run.next + 1), false
end

function Bank.Toggle(key)
	if not On() then
		return false
	end
	local me = B.Me()
	if key == me then
		key = nil
	end
	local viewing = B.Viewing("bank")
	if viewing == me then
		viewing = nil
	end
	if E.Shown(B.Window.Get("bank")) and viewing == key then
		B.Window.Hide("bank")
		return true
	end
	B.SetViewing("bank", key)
	B.Window.Show("bank")
	Watch()
	return true
end

local function KeyPressed()
	if Bank.Toggle(nil) then
		return
	end
	if ns.Enabled(KEY) then
		print("Flat UI: Bags is not in use now, so the bank key does nothing. /flatui status says why.")
	else
		print("Flat UI: the bank key opens Flat UI's bank window. Turn on Flat UI bags on the Bags page of /flatui first.")
	end
end

do
	local ok, button = pcall(CreateFrame, "Button", BUTTON, UIParent)
	if ok and Usable(button) then
		ns.Own[button] = true
		pcall(button.RegisterForClicks, button, "LeftButtonUp")
		button:SetScript("OnClick", function()
			Run(KeyPressed)
		end)
	end
end

local function Banker(kind)
	if not ns.Finite(kind) then
		return false
	end
	for name, number in pairs(BANKERS) do
		if kind == EnumValue("PlayerInteractionType", name, number) then
			return true
		end
	end
	return false
end

local function Refresh()
	if row then
		Run(Update)
	end
end

local Closed

local function Opened()
	if open and not closing then
		return
	end
	if open then
		Closed()
	end
	open, closing = true, false
	flat = Parked()
	Call("cache", B.Data, "BankScan")
	Call("follow", B, "BankOpened")
	if flat then
		Call("window", B, "SetViewing", "bank", nil)
		Call("window", B.Window, "Show", "bank")
		pcall(Watch)
		Follow()
	end
	Refresh()
end

Closed = function(late)
	if not open then
		return
	end
	local wasFlat = flat
	open, flat, closing, closeWait = false, false, false, nil
	sent = {}
	if pass then
		Run(Finish, not PER_CLICK and "the bank closed" or nil)
		pass = nil
	end
	if wasFlat and type(E.HideAlone) == "function" then
		pcall(E.HideAlone, BUY_POPUP)
	end
	Call("cache", B.Data, "BankClosed", late == true)
	Call("follow", B, "BankClosed")
	Call("window", B, "Request", "layout", "bank")
	Refresh()
end

local function Changed()
	if not open then
		return
	end
	local read, ran, moved = Usable(B.Data) and B.Data.BankTabs or nil, false, false
	local run = B.Part
	if type(read) == "function" and type(run) == "function" then
		run("cache", function()
			moved = read() == true
			ran = true
		end)
	end
	Refresh()
	if moved or not ran then
		Call("window", B, "Request", "layout", "bank")
	end
end

local function AtBanker()
	local api = C_PlayerInteractionManager
	local ask = Usable(api) and api.IsInteractingWithNpcOfType or nil
	if type(ask) ~= "function" then
		return true
	end
	for name, number in pairs(BANKERS) do
		local ok, yes = pcall(ask, EnumValue("PlayerInteractionType", name, number))
		if not ok or ns.IsSecret(yes) or yes ~= false then
			return true
		end
	end
	return false
end

function Bank.Settle()
	local shown = E.Shown(_G.BankFrame)
	if open and not shown then
		Closed(true)
	elseif not open and shown and AtBanker() then
		Opened()
	end
end

ns.AddEvent(KEY, "BANKFRAME_OPENED", function()
	Opened()
end)
ns.AddEvent(KEY, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(kind)
	if Banker(kind) then
		Opened()
	end
end)
ns.AddEvent(KEY, "BANKFRAME_CLOSED", function()
	Closed()
end)
ns.AddEvent(KEY, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(kind)
	if Banker(kind) then
		Closed()
	end
end)
ns.AddEvent(KEY, "PLAYERBANKSLOTS_CHANGED", function()
	Changed()
end)
ns.AddEvent(KEY, "ITEM_LOCK_CHANGED", function()
	if RowShowing() then
		Run(Redraw)
	end
end, function(bag, slot)
	return ns.Finite(bag) and (bag == BANK_BAGS or (not ns.IsSecret(slot) and slot == nil))
end)
ns.AddEvent(KEY, "CURSOR_CHANGED", function()
	if row then
		Run(Fits)
	end
end)
ns.AddEvent(KEY, "BANK_TABS_CHANGED", function(kind)
	if not ns.Finite(kind) or kind == Character() then
		Changed()
	end
end)

ns.AddStatus(KEY, function()
	local lines = {}
	local run = pass
	if run and run.paused then
		lines[#lines + 1] = ("Bags: %s waits for the end of the fight."):format(WORDS[run.kind].label)
	end
	if buyBroken then
		lines[#lines + 1] = "Bags: the game did not make the bank's Buy button. With At the banker set to the game's bank window, its own button buys."
	end
	if PER_CLICK then
		lines[#lines + 1] = "Bags: Deposit and Take out move one item for each click."
	end
	return lines
end)
