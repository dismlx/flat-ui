local _, ns = ...

local E = ns.Errands
local part = E.Part({ label = "Bulk buy" })

local POPUP = "FLATUI_BULK_BUY"
local DELIVERY, PAUSE = 5, 0.15
local LOOK = 0.1
local WIDTH, GAP, BESIDE = 84, 4, 2
local DEFAULT_BAGS = 4
local REAGENT_BAG = 5
local HIGH_COST = 1500000
local NONE = { gold = "Your gold does not pay for one purchase.", room = "Your bags have no room for it.", stock = "The merchant has none left.",
	unavailable = "The merchant does not sell it to you." }
local REASONS = { gold = "As many as your gold pays for.", room = "As many as your bags hold.", stock = "All the merchant has." }
local RAN_OUT = { gold = "your gold ran out", room = "your bags are full", stock = "the merchant ran out", unavailable = "the merchant does not sell it to you" }

local followed = false
local bar
local buttons = {}
local broken = false
local looking
local shown
local order
local open = false
local visit = 0
local last, leftWhy

local Field = E.PopupField

local function Bags()
	for _, n in ipairs({ NUM_TOTAL_EQUIPPED_BAG_SLOTS, NUM_BAG_SLOTS }) do
		if type(n) == "number" and not ns.IsSecret(n) and n >= 0 and n <= 20 then
			return n
		end
	end
	return DEFAULT_BAGS
end

local function Word(name, fallback)
	local text = _G[name]
	if type(text) == "string" and not ns.IsSecret(text) and text ~= "" then
		return text
	end
	return fallback
end

local function Band(a, b)
	if type(bit) == "table" and type(bit.band) == "function" then
		local ok, value = pcall(bit.band, a, b)
		if ok and ns.Finite(value) then
			return value
		end
	end
	local result, place = 0, 1
	while a > 0 and b > 0 do
		if a % 2 == 1 and b % 2 == 1 then
			result = result + place
		end
		a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
	end
	return result
end

local function MerchantOpen()
	return open and E.Shown(MerchantFrame)
end

local function HighCost()
	local n = MERCHANT_HIGH_PRICE_COST
	return ns.Finite(n) and n > 0 and n or HIGH_COST
end

local function StackKey(link)
	local item = type(link) == "string" and link:match("item:([^|]+)") or nil
	if not item then
		return nil
	end
	local fields = {}
	for value in (item .. ":"):gmatch("(.-):") do
		fields[#fields + 1] = value ~= "" and value or "0"
	end
	for _, index in ipairs({ 8, 9, 10 }) do
		if fields[index] then
			fields[index] = "0"
		end
	end
	while fields[#fields] == "0" do
		fields[#fields] = nil
	end
	return table.concat(fields, ":")
end

local function Reagent(link)
	local info = type(C_Item) == "table" and C_Item.GetItemInfo or nil
	if type(info) ~= "function" then
		return false
	end
	local ok, value = pcall(function()
		return (select(17, info(link)))
	end)
	return ok and not ns.IsSecret(value) and value == true
end

local function Room(link, size)
	if type(C_Container) ~= "table" then
		return nil
	end
	local family = type(C_Item) == "table" and E.Ask(C_Item.GetItemFamily, link) or nil
	family = ns.Finite(family) and family or 0
	local key, room = StackKey(link), 0
	for bag = 0, Bags() do
		local free, bagFamily = E.Ask(C_Container.GetContainerNumFreeSlots, bag)
		if ns.Finite(free) and free > 0 and ns.Finite(bagFamily) and (bagFamily == 0 or (family ~= 0 and Band(family, bagFamily) ~= 0))
			and (bag ~= REAGENT_BAG or Reagent(link)) then
			room = room + free * size
		end
		local slots = E.Ask(C_Container.GetContainerNumSlots, bag)
		for slot = 1, ns.Finite(slots) and slots or 0 do
			local info = E.Ask(C_Container.GetContainerItemInfo, bag, slot)
			if key and type(info) == "table" and Field(info, "isLocked") == false and StackKey(Field(info, "hyperlink")) == key then
				local count = Field(info, "stackCount")
				if ns.Finite(count) and count < size then
					room = room + size - count
				end
			end
		end
	end
	return room
end

local function Offer(index)
	if not ns.Finite(index) or index < 1 or type(C_MerchantFrame) ~= "table" then
		return nil
	end
	local link = E.Ask(GetMerchantItemLink, index)
	local info = E.Ask(C_MerchantFrame.GetItemInfo, index)
	if type(link) ~= "string" or link == "" or type(info) ~= "table" then
		return nil
	end
	local bundle, price, stock, name = Field(info, "stackCount"), Field(info, "price"), Field(info, "numAvailable"), Field(info, "name")
	if not ns.Finite(bundle) or bundle < 1 or bundle ~= math.floor(bundle) or not ns.Finite(price) or price < 0 then
		return nil
	end
	if Field(info, "hasExtendedCost") ~= false then
		return nil, "tokens"
	end
	if price >= HighCost() and E.Ask(C_MerchantFrame.IsMerchantItemRefundable, index) ~= true then
		return nil, "refund"
	end
	local chunk = E.Ask(GetMerchantItemMaxStack, index)
	local id = tonumber(link:match("item:(%d+)"))
	local size = id and type(C_Item) == "table" and E.Ask(C_Item.GetItemMaxStackSizeByID, id) or nil
	if not ns.Finite(chunk) or chunk < bundle or not ns.Finite(size) or size < 1 then
		return nil
	end
	local offer = { index = index, link = link, name = type(name) == "string" and name ~= "" and name or link, bundle = bundle, price = price,
		merchant = E.Ask(UnitGUID, "npc"), chunk = math.floor(chunk / bundle) * bundle, stack = math.max(bundle, math.floor(size / bundle) * bundle) }
	local limit, by = math.huge, nil
	if Field(info, "isPurchasable") == false then
		limit, by = 0, "unavailable"
	elseif ns.Finite(stock) and stock >= 0 then
		limit, by = stock, "stock"
	end
	if price > 0 then
		local money = E.Ask(GetMoney)
		if not ns.Finite(money) then
			return nil
		end
		local afford = math.floor(money / price) * bundle
		if afford < limit then
			limit, by = afford, "gold"
		end
	end
	local room = Room(link, size)
	if room == nil then
		return nil
	end
	if room < limit then
		limit, by = room, "room"
	end
	offer.limit, offer.by = math.floor(limit / bundle) * bundle, by
	return offer
end

local function SameOffer(a, b)
	return a ~= nil and b ~= nil and a.index == b.index and a.link == b.link and a.price == b.price and a.bundle == b.bundle and a.merchant == b.merchant
end

local function StackCount(offer)
	return math.min(offer.stack, offer.limit)
end

local function Cost(offer, count)
	return offer.price * count / offer.bundle
end

local function Held(link)
	local count = type(C_Item) == "table" and E.Ask(C_Item.GetItemCount, link) or nil
	return ns.Finite(count) and count or nil
end

local function BoxFor(button)
	local box = StackSplitFrame
	return button ~= nil and E.Shown(box) and Field(box, "owner") == button
end

local Done

local function Arrived(o)
	local wait = o.pending
	if not wait then
		return false
	end
	local now = Held(o.offer.link)
	if not now or now - wait.before < wait.amount then
		return false
	end
	o.left, o.bought, o.spent, o.pending = o.left - wait.amount, o.bought + wait.amount, o.spent + wait.cost, nil
	return true
end

local function Next()
	local o = order
	if not o or o.pending then
		return
	end
	if o.left < o.offer.bundle then
		Done(nil)
		return
	end
	local why
	if not MerchantOpen() then
		why = "the merchant closed"
	elseif E.Fighting() then
		why = "a fight started"
	elseif not E.On("bulkBuy") then
		why = "Buy in bulk was turned off"
	end
	local fresh, amount, before
	if not why then
		fresh = Offer(o.offer.index)
		if not fresh or not SameOffer(o.offer, fresh) then
			why = "the merchant's offer changed"
		end
	end
	if not why then
		amount = math.floor(math.min(o.left, fresh.chunk, fresh.limit) / fresh.bundle) * fresh.bundle
		if amount < fresh.bundle then
			why = RAN_OUT[fresh.by] or "nothing more could be bought"
		end
	end
	if not why then
		before = Held(fresh.link)
		if not before then
			why = "the game did not say how many you have"
		elseif not E.Call(BuyMerchantItem, fresh.index, amount) then
			why = "the game did not take the purchase"
		end
	end
	if why then
		Done(why)
		return
	end
	local wait = { before = before, amount = amount, cost = Cost(fresh, amount) }
	o.pending = wait
	C_Timer.After(DELIVERY, function()
		if order == o and o.pending == wait then
			E.Run(part, Done, ("nothing came for %d seconds"):format(DELIVERY))
		end
	end)
end

Done = function(why)
	local o = order
	order = nil
	if not o then
		return
	end
	Arrived(o)
	if o.bought > 0 then
		last = ("%d %s for %s"):format(o.bought, o.offer.name, E.Money(o.spent))
		E.Say(("Bought %s%s."):format(last, why and (", then stopped: " .. why) or ""))
	elseif why then
		E.Say(("Bought no %s: %s."):format(o.offer.name, why))
	end
end

local function Start(offer, count)
	order = { offer = offer, total = count, left = count, bought = 0, spent = 0 }
	Next()
end

local function Delivered()
	local o = order
	if o and Arrived(o) then
		C_Timer.After(PAUSE, function()
			if order == o then
				E.Run(part, Next)
			end
		end)
	end
end

local function NoLonger(by, count)
	if by == "gold" then
		return ("your gold no longer pays for %d"):format(count)
	elseif by == "room" then
		return ("your bags no longer hold %d"):format(count)
	end
	return ("the merchant no longer has %d"):format(count)
end

local function Accept(data)
	if type(data) ~= "table" or type(data.offer) ~= "table" or not ns.Finite(data.count) then
		return
	end
	local why, fresh
	if order then
		why = "another purchase is under way"
	elseif not E.On("bulkBuy") then
		why = "Buy in bulk is off"
	elseif data.visit ~= visit or not MerchantOpen() then
		why = "the merchant closed"
	elseif E.Fighting() then
		why = "a fight started"
	else
		fresh = Offer(data.offer.index)
		if not fresh or not SameOffer(data.offer, fresh) then
			why = "the merchant's offer changed"
		elseif data.count > fresh.limit then
			why = NoLonger(fresh.by, data.count)
		end
	end
	if why then
		print(("Flat UI: Bought no %s: %s."):format(data.offer.name, why))
		return
	end
	Start(fresh, data.count)
end

local function Register()
	local list = StaticPopupDialogs
	if type(list) ~= "table" or ns.IsSecret(list) or type(StaticPopup_Show) ~= "function" then
		return false
	end
	if list[POPUP] == nil then
		list[POPUP] = {
			text = "%s",
			button1 = Word("YES", "Yes"),
			button2 = Word("NO", "No"),
			timeout = 0,
			whileDead = false,
			hideOnEscape = true,
			OnAccept = function(_, data)
				E.Run(part, Accept, data)
			end,
		}
	end
	return true
end

local function Ask(offer, count)
	if not Register() then
		print("Flat UI: Buy in bulk cannot ask first on this client, so it buys nothing.")
		return
	end
	local text = ("Buy %d %s for %s?\nThe game's box stays open: Cancel closes it, and its Okay would buy more."):format(count, offer.name,
		E.Money(Cost(offer, count)))
	local ok, popup = pcall(StaticPopup_Show, POPUP, text, nil, { offer = offer, count = count, visit = visit })
	if not ok or popup == nil or popup == false then
		print("Flat UI: Buy in bulk could not ask first, so it buys nothing.")
	end
end

local function HideBar()
	shown, looking = nil, nil
	if bar then
		bar:Hide()
	end
end

local function BarWanted()
	return shown ~= nil and order == nil and E.On("bulkBuy") and not ns.PartStopped("errands", part.label) and not E.Gamepad() and not E.Fighting()
		and MerchantOpen() and BoxFor(shown.button)
end

local function Watch()
	local token = {}
	looking = token
	local function Look()
		if looking ~= token then
			return
		end
		local ok, keep = pcall(BarWanted)
		if not ok or not keep then
			HideBar()
			return
		end
		C_Timer.After(LOOK, Look)
	end
	C_Timer.After(LOOK, Look)
end

local function Paint()
	local offer = shown and shown.offer
	if buttons.stack then
		buttons.stack.SetUsable(offer ~= nil and StackCount(offer) >= offer.bundle)
	end
	if buttons.most then
		buttons.most.SetUsable(offer ~= nil and offer.limit >= offer.bundle)
	end
end

local function Tip(owner, which)
	if not GameTooltip or ns.Forbidden(GameTooltip) or not shown then
		return
	end
	local offer = Offer(shown.index) or shown.offer
	local count = which == "stack" and StackCount(offer) or offer.limit
	GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM", 0, -4)
	GameTooltip:SetText(which == "stack" and "Stack" or "Most")
	local function Line(text)
		GameTooltip:AddLine(text, 1, 1, 1, true)
	end
	if count < offer.bundle then
		Line(NONE[offer.by] or "Nothing to buy now.")
	else
		Line(("%d %s for %s."):format(count, offer.name, E.Money(Cost(offer, count))))
		if which == "most" and REASONS[offer.by] then
			Line(REASONS[offer.by])
		end
		if count > offer.chunk then
			Line(("Asks first, then buys %d at a time."):format(offer.chunk))
		else
			Line("Asks first.")
		end
	end
	GameTooltip:Show()
end

local function Click(which)
	if not shown then
		return
	end
	if E.Fighting() or not MerchantOpen() or not BoxFor(shown.button) then
		HideBar()
		return
	end
	local fresh = Offer(shown.index)
	if not fresh or not SameOffer(shown.offer, fresh) then
		HideBar()
		print("Flat UI: The merchant's offer changed. Shift-click the item again.")
		return
	end
	local count = which == "stack" and StackCount(fresh) or fresh.limit
	if count < fresh.bundle then
		shown.offer = fresh
		Paint()
		return
	end
	HideBar()
	Ask(fresh, count)
end

local function Make()
	if bar then
		return true
	end
	if broken or type(UIParent) ~= "table" then
		return false
	end
	local ok = pcall(function()
		local holder = CreateFrame("Frame", nil, UIParent)
		ns.Own[holder] = true
		holder:Hide()
		holder:SetFrameStrata("HIGH")
		holder:SetSize(WIDTH * 2 + GAP, 22)
		pcall(holder.SetClampedToScreen, holder, true)
		local stack = E.Button(holder, "Stack", WIDTH, function()
			E.Run(part, Click, "stack")
		end, function(owner)
			E.Run(part, Tip, owner, "stack")
		end)
		stack:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
		local most = E.Button(holder, "Most", WIDTH, function()
			E.Run(part, Click, "most")
		end, function(owner)
			E.Run(part, Tip, owner, "most")
		end)
		most:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
		bar, buttons.stack, buttons.most = holder, stack, most
	end)
	if not ok then
		broken = true
		return false
	end
	return true
end

local function Opened(button)
	if not E.On("bulkBuy") or E.Gamepad() or E.Fighting() or order or not MerchantOpen() or ns.Forbidden(button) then
		return
	end
	if Field(MerchantFrame, "selectedTab") ~= 1 or E.Ask(IsModifiedClick, "SPLITSTACK") ~= true then
		return
	end
	local okFocus, focus = pcall(GetCurrentKeyBoardFocus)
	if not okFocus or ns.IsSecret(focus) or focus ~= nil then
		return
	end
	if not BoxFor(button) then
		HideBar()
		return
	end
	local okId, index = pcall(button.GetID, button)
	if not okId or not ns.Finite(index) then
		return
	end
	local offer, why = Offer(index)
	leftWhy = why
	if not offer or not Make() then
		HideBar()
		return
	end
	shown = { button = button, index = index, offer = offer }
	Paint()
	bar:ClearAllPoints()
	bar:SetPoint("LEFT", StackSplitFrame, "RIGHT", BESIDE, 0)
	bar:Show()
	Watch()
end

local function Follow()
	if followed or not E.On("bulkBuy") then
		return
	end
	followed = ns.FollowGlobal("MerchantItemButton_OnModifiedClick", function(button)
		E.Run(part, Opened, button)
	end) == true
end

E.Listen(part, "MERCHANT_SHOW", function()
	visit = visit + 1
	open = true
	Follow()
end)

E.Listen(part, "MERCHANT_CLOSED", function()
	open = false
	visit = visit + 1
	HideBar()
	if order then
		Done("the merchant closed")
	end
end)

E.Listen(part, "BAG_UPDATE_DELAYED", Delivered)

E.Listen(part, "UI_ERROR_MESSAGE", function(_, message)
	if order then
		local said = type(message) == "string" and not ns.IsSecret(message) and message:gsub("%.$", "") or nil
		Done(said and said ~= "" and ('the game said "%s"'):format(said) or "the game showed an error")
	end
end)

E.Listen(part, "PLAYER_REGEN_DISABLED", function()
	HideBar()
	if order then
		Done("a fight started")
	end
end)

E.Listen(part, "INPUT_DEVICE_INTERFACE_TRANSITION", function()
	if E.Gamepad() then
		HideBar()
	end
end)

function part.Refresh()
	Follow()
	if not E.On("bulkBuy") then
		HideBar()
		if order then
			Done("Buy in bulk was turned off")
		end
	end
end

function part.Start()
	open = E.Shown(MerchantFrame)
	part.Refresh()
end

function part.Status()
	if E.Opt("bulkBuy") ~= true then
		return {}
	end
	if type(BuyMerchantItem) ~= "function" or type(C_MerchantFrame) ~= "table" or type(MerchantItemButton_OnModifiedClick) ~= "function" then
		return { "Bulk buy: this client cannot buy from a merchant here, so there are no Stack and Most buttons." }
	end
	if E.Gamepad() then
		return { "Bulk buy: no Stack and Most buttons while the gamepad interface is on." }
	end
	local line = "Bulk buy: Stack and Most beside the game's box when you Shift-click an item at a merchant; both ask first."
	if order then
		line = line .. (" Buying %s: %d of %d so far."):format(order.offer.name, order.bought, order.total)
	elseif last then
		line = line .. " Last bought " .. last .. "."
	end
	local lines = { line }
	if leftWhy == "refund" then
		lines[#lines + 1] = "Bulk buy: the last item you Shift-clicked is left to the game, which asks before it sells an item of 150 gold or more that it cannot refund."
	elseif leftWhy == "tokens" then
		lines[#lines + 1] = "Bulk buy: the last item you Shift-clicked costs items or currency, so it is left to the game."
	end
	return lines
end
