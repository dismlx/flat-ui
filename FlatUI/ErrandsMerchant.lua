local _, ns = ...

local E = ns.Errands
local part = E.Part({ label = "Merchant" })

local SPACING = 0.15
local GUILD_CHECK = 2
local LOOK, LOOKS = 0.05, 40
local MONEY_WAIT = 1
local DEFAULT_BAGS = 4
local POOR = 0
local BUYBACK = 12
local EXCLUDE_JUNK = 64
local NEXT_LABEL, NEXT_WIDTH = "Sell next 12", 100
local PLACES = {
	group = { raid = true, dungeon = true, battleground = true, group = true },
	instance = { raid = true, dungeon = true, battleground = true },
	raid = { raid = true },
}
local PLACE_WORDS = { group = "groups and instances", instance = "dungeons, raids and battlegrounds", raid = "raids" }
local STATUS_WHERE = { group = "in a group or an instance", instance = "in dungeons, raids and battlegrounds", raid = "in raids" }

local open = false
local visit = 0
local run
local manual = false
local paused, waiting = false, false
local retryRepair, moneyWait, guildRefused, repairAfterFight = false, false, false, false
local pending
local repairSaid
local notes = {}
local more = 0
local nextButton
local nextBroken = false

local function Count(list)
	local n = 0
	for _, on in pairs(list or {}) do
		if on == true then
			n = n + 1
		end
	end
	return n
end

local function Bags()
	for _, n in ipairs({ NUM_TOTAL_EQUIPPED_BAG_SLOTS, NUM_BAG_SLOTS }) do
		if type(n) == "number" and not ns.IsSecret(n) and n >= 0 and n <= 20 then
			return n
		end
	end
	return DEFAULT_BAGS
end

local function Field(info, key)
	local value = info[key]
	if ns.IsSecret(value) then
		return nil
	end
	return value
end

local function Price(link)
	if type(C_Item) ~= "table" or type(C_Item.GetItemInfo) ~= "function" then
		return nil
	end
	local ok, name, _, _, _, _, _, _, _, _, _, price = pcall(C_Item.GetItemInfo, link)
	if not ok or name == nil or ns.IsSecret(price) or type(price) ~= "number" or price < 0 then
		return nil
	end
	return price
end

local function Quest(bag, slot)
	local quest = E.Ask(C_Container.GetContainerItemQuestInfo, bag, slot)
	return type(quest) == "table" and (Field(quest, "isQuestItem") == true or Field(quest, "questID") ~= nil)
end

local function Buyback()
	local n = BUYBACK_ITEMS_PER_PAGE
	if ns.Finite(n) and n >= 1 and n <= 100 and n == math.floor(n) then
		return n
	end
	return BUYBACK
end

local function Capped()
	return E.Opt("sellTwelve") == true
end

local function ExcludeFlag()
	local enum = type(Enum) == "table" and not ns.IsSecret(Enum) and Enum.BagSlotFlags or nil
	local flag = type(enum) == "table" and not ns.IsSecret(enum) and enum.ExcludeJunkSell or nil
	return ns.Finite(flag) and flag or EXCLUDE_JUNK
end

local function JunkExcluded(bag)
	if type(C_Container) ~= "table" then
		return false
	end
	if bag == 0 then
		return E.Ask(C_Container.GetBackpackSellJunkDisabled) == true
	end
	return E.Ask(C_Container.GetBagSlotFlag, bag, ExcludeFlag()) == true
end

local function Sale(bag, slot, lists, excluded, anyLock)
	local info = E.Ask(C_Container.GetContainerItemInfo, bag, slot)
	if type(info) ~= "table" then
		return nil
	end
	local id, link, count = Field(info, "itemID"), Field(info, "hyperlink"), Field(info, "stackCount")
	if type(id) ~= "number" or type(link) ~= "string" or (not anyLock and Field(info, "isLocked") ~= false) or Field(info, "hasNoValue") ~= false then
		return nil
	end
	local listed = lists.sell[id] == true
	local grey = Field(info, "quality") == POOR
	if not listed and (lists.keep[id] == true or not grey or excluded) then
		return nil
	end
	if Quest(bag, slot) then
		return nil
	end
	local price = Price(link)
	if price == 0 then
		return nil
	end
	count = type(count) == "number" and count > 0 and count or 1
	return { bag = bag, slot = slot, id = id, link = link, count = count, price = price, listed = listed and not grey }
end

local function Same(sale)
	local info = E.Ask(C_Container.GetContainerItemInfo, sale.bag, sale.slot)
	if type(info) ~= "table" or Field(info, "itemID") ~= sale.id or Field(info, "hyperlink") ~= sale.link or Field(info, "isLocked") ~= false then
		return nil
	end
	local count = Field(info, "stackCount")
	return type(count) == "number" and count > 0 and count or 1
end

local function Scan(allowance, sold)
	local lists, inOrder, greys, listed, waits = E.Lists(), {}, {}, {}, 0
	if not lists then
		return inOrder, 0
	end
	for bag = 0, Bags() do
		local excluded = JunkExcluded(bag)
		local slots = E.Ask(C_Container.GetContainerNumSlots, bag)
		for slot = 1, type(slots) == "number" and slots or 0 do
			local sale = Sale(bag, slot, lists, excluded)
			if sale and sale.listed and allowance ~= nil and #listed >= allowance then
				waits = waits + 1
			elseif sale then
				inOrder[#inOrder + 1] = sale
				if sale.listed then
					listed[#listed + 1] = sale
				else
					greys[#greys + 1] = sale
				end
			end
		end
	end
	if #listed == 0 or sold + #inOrder <= Buyback() then
		return inOrder, waits
	end
	for _, sale in ipairs(listed) do
		greys[#greys + 1] = sale
	end
	return greys, waits
end

local function MerchantOpen()
	return open and E.Shown(MerchantFrame)
end

local function Targeting()
	return E.Ask(SpellIsTargeting) == true or E.Ask(SpellCanTargetItem) == true or E.Ask(SpellCanTargetItemID) == true
end

local function SellOn()
	return ns.Enabled("errands") and E.Opt("sell") == true
end

local function Wanted()
	return manual or SellOn()
end

local function ExcludedBags()
	local names = {}
	for bag = 0, Bags() do
		if JunkExcluded(bag) then
			local name = bag ~= 0 and type(C_Container) == "table" and E.Ask(C_Container.GetBagName, bag) or nil
			names[#names + 1] = bag == 0 and "your backpack" or (type(name) == "string" and name ~= "" and name or ("bag %d"):format(bag))
		end
	end
	return names
end

local Repair, WaitForMoney, ShowNext

WaitForMoney = function()
	moneyWait = true
	local at = visit
	C_Timer.After(MONEY_WAIT, function()
		if at == visit and moneyWait then
			moneyWait = false
			E.Run(part, Repair, true)
		end
	end)
end

local function Items(n)
	return n == 1 and "item" or "items"
end

local function Wait(n)
	return n == 1 and "waits" or "wait"
end

local function WaitsFor()
	if more <= 0 or not Wanted() or not Capped() then
		return nil
	end
	if manual and not SellOn() then
		return "for Sell junk"
	end
	return E.Gamepad() and "until you next open a merchant" or "for Sell next"
end

local function SayRepair()
	if repairSaid then
		E.Say(("Repaired for %s."):format(repairSaid))
		repairSaid = nil
	end
end

local function Finish(why)
	local done = run
	run, paused = nil, false
	if why then
		more = 0
	end
	local waits = WaitsFor()
	if done and done.sold > 0 then
		local amount = done.unknown and "" or (" for " .. E.Money(done.value))
		notes[#notes + 1] = ("sold %d%s"):format(done.sold, amount)
		local repaired = repairSaid and (" and repaired for " .. repairSaid) or ""
		repairSaid = nil
		local tail = ""
		if why then
			tail = ", then stopped: " .. why
		elseif waits then
			tail = ("; %d more on your sell list %s %s"):format(more, Wait(more), waits)
		end
		E.Say(("Sold %d %s%s%s%s."):format(done.sold, Items(done.sold), amount, repaired, tail))
	else
		SayRepair()
		if waits then
			E.Say(("%d %s of your sell list %s %s."):format(more, Items(more), Wait(more), waits))
		end
	end
	manual = false
	ShowNext()
	if retryRepair and MerchantOpen() then
		retryRepair = false
		if done and done.sold > 0 then
			WaitForMoney()
		else
			Repair(true)
		end
	end
end

local function SellNext(at)
	if at ~= visit or not run or paused then
		return
	end
	if not Wanted() then
		Finish("selling was turned off")
		return
	end
	if not MerchantOpen() then
		Finish("the merchant closed")
		return
	end
	if E.Shown(TradeFrame) then
		Finish("a trade opened")
		return
	end
	if E.Fighting() then
		paused = true
		return
	end
	if E.Ask(GetCursorInfo) ~= nil or E.Ask(CursorHasItem) == true then
		Finish("the cursor held something")
		return
	end
	if Targeting() then
		Finish("a spell waited for its target")
		return
	end
	local sale = run.queue[run.next]
	if not sale then
		Finish(nil)
		return
	end
	run.next = run.next + 1
	local count = Same(sale)
	if count and E.Call(C_Container.UseContainerItem, sale.bag, sale.slot) then
		run.sold = run.sold + 1
		if sale.listed then
			run.listed = run.listed + 1
		end
		if sale.price then
			run.value = run.value + sale.price * count
		else
			run.unknown = true
		end
	end
	C_Timer.After(SPACING, function()
		E.Run(part, SellNext, at)
	end)
end

local function Sell()
	if type(C_Container) ~= "table" or type(C_Container.UseContainerItem) ~= "function" then
		return
	end
	local allowance = Capped() and math.max(0, Buyback() - (run and run.listed or 0)) or nil
	local queue, waits = Scan(allowance, run and run.sold or 0)
	more = waits
	if #queue == 0 then
		Finish(nil)
		return
	end
	run = run or { sold = 0, value = 0, unknown = false, listed = 0 }
	run.queue, run.next = queue, 1
	paused = false
	SellNext(visit)
end

local function NextWanted()
	return more > 0 and run == nil and open and E.Shown(MerchantFrame) and Wanted() and Capped() and not E.Gamepad() and not E.Fighting()
		and not ns.PartStopped("errands", part.label)
end

local function NextTip(owner)
	if not GameTooltip or ns.Forbidden(GameTooltip) then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM", 0, -4)
	GameTooltip:SetText(NEXT_LABEL)
	GameTooltip:AddLine(("%d more %s of your sell list %s. A click sells up to %d of them, and the merchant's buyback holds them."):format(more,
		Items(more), Wait(more), Buyback()), 1, 1, 1, true)
	GameTooltip:Show()
end

local function SellMore()
	if run or not MerchantOpen() or not Wanted() or E.Fighting() then
		return
	end
	local why
	if E.Shown(TradeFrame) then
		why = "a trade window is open"
	elseif E.Ask(GetCursorInfo) ~= nil or E.Ask(CursorHasItem) == true then
		why = "the cursor holds something"
	elseif Targeting() then
		why = "a spell waits for its target"
	end
	if why then
		print(("Flat UI: Sold nothing: %s."):format(why))
		return
	end
	more = 0
	if nextButton then
		nextButton:Hide()
	end
	Sell()
end

local function MakeNext()
	if nextButton then
		return true
	end
	local frame = MerchantFrame
	if nextBroken or E.Fighting() or type(frame) ~= "table" or ns.Forbidden(frame) or (ns.MaybeProtected and ns.MaybeProtected(frame)) then
		return false
	end
	local ok, made = pcall(E.Button, frame, NEXT_LABEL, NEXT_WIDTH, function()
		E.Run(part, SellMore)
	end, function(owner)
		E.Run(part, NextTip, owner)
	end)
	if not ok or type(made) ~= "table" then
		nextBroken = true
		return false
	end
	nextButton = made
	nextButton:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -4)
	nextButton.Keep(NextWanted)
	return true
end

ShowNext = function()
	if not NextWanted() then
		if nextButton then
			nextButton:Hide()
		end
		return
	end
	if not MakeNext() then
		return
	end
	nextButton:Show()
	if E.TipOwned(nextButton) then
		NextTip(nextButton)
	end
end

local function GuildCheck(at, cost)
	local left = E.Ask(GetRepairAllCost)
	if type(left) ~= "number" then
		return
	end
	if left <= 0 then
		notes[#notes + 1] = ("repaired for %s from the guild"):format(E.Money(cost))
		E.Say(("Repaired for %s from the guild bank."):format(E.Money(cost)))
		return
	end
	if at ~= visit or not MerchantOpen() or not ns.Enabled("errands") then
		E.Say(("The guild bank did not pay for the %s repair."):format(E.Money(left)))
		return
	end
	guildRefused = true
	if E.Fighting() then
		E.Say(("The guild bank did not pay for the %s repair."):format(E.Money(left)))
		repairAfterFight = true
		return
	end
	local money = E.Ask(GetMoney)
	if type(money) == "number" and money >= left and E.Call(RepairAllItems) then
		notes[#notes + 1] = ("repaired for %s with your gold"):format(E.Money(left))
		E.Say(("The guild bank did not pay; repaired for %s with your gold."):format(E.Money(left)))
	elseif run then
		retryRepair = true
	else
		notes[#notes + 1] = ("could not pay %s for repairs"):format(E.Money(left))
		E.Say(("The guild bank did not pay, and your gold does not cover the %s repair."):format(E.Money(left)))
	end
end

local function Place()
	local inside, kind = E.Ask(IsInInstance)
	if inside == true then
		if kind == "raid" then
			return "raid"
		elseif kind == "party" then
			return "dungeon"
		elseif kind == "pvp" or kind == "arena" then
			return "battleground"
		end
	end
	if E.Ask(IsInRaid) == true then
		return "raid"
	elseif E.Ask(IsInGroup) == true then
		return "group"
	end
	return "world"
end

local function GuildHere()
	local places = PLACES[E.Opt("guildWhere")]
	return places == nil or places[Place()] == true
end

Repair = function(last, hold)
	local how = E.Opt("repair")
	if how ~= "own" and how ~= "guild" or not ns.Enabled("errands") then
		return
	end
	if E.Fighting() then
		repairAfterFight = true
		return
	end
	if E.Ask(CanMerchantRepair) ~= true then
		return
	end
	local cost = E.Ask(GetRepairAllCost)
	if type(cost) ~= "number" or cost <= 0 then
		return
	end
	local elsewhere = how == "guild" and not GuildHere()
	if how == "guild" and not elsewhere and not guildRefused and E.Ask(CanGuildBankRepair) == true then
		local allowed = E.Ask(GetGuildBankWithdrawMoney)
		if type(allowed) == "number" and (allowed < 0 or allowed >= cost) and E.Call(RepairAllItems, true) then
			local at = visit
			C_Timer.After(GUILD_CHECK, function()
				E.Run(part, GuildCheck, at, cost)
			end)
			return
		end
	end
	local money = E.Ask(GetMoney)
	if type(money) == "number" and money < cost then
		if not last and E.Opt("sell") == true then
			retryRepair = true
			return
		end
		notes[#notes + 1] = ("could not pay %s for repairs"):format(E.Money(cost))
		E.Say(("Not enough gold to repair: it costs %s."):format(E.Money(cost)))
		return
	end
	if E.Call(RepairAllItems) then
		if elsewhere then
			notes[#notes + 1] = ("repaired for %s with your gold"):format(E.Money(cost))
			E.Say(("Repaired for %s with your gold: guild gold is for %s."):format(E.Money(cost), PLACE_WORDS[E.Opt("guildWhere")] or "other places"))
		else
			notes[#notes + 1] = ("repaired for %s"):format(E.Money(cost))
			if hold then
				repairSaid = E.Money(cost)
			else
				E.Say(("Repaired for %s."):format(E.Money(cost)))
			end
		end
	end
end

local function Kept()
	if not SellOn() then
		return
	end
	local queue = Scan(nil, 0)
	local grey = true
	for _, sale in ipairs(queue) do
		grey = grey and not sale.listed
	end
	if #queue > 0 then
		E.Say(("Kept %d %s%s this visit (Shift was held as the merchant opened)."):format(#queue, grey and "grey " or "", Items(#queue)))
	end
end

local function Visit(at, keep, tries)
	waiting = false
	if at ~= visit or not open or not ns.Enabled("errands") then
		return
	end
	if not E.Shown(MerchantFrame) then
		if (tries or 0) < LOOKS then
			C_Timer.After(LOOK, function()
				E.Run(part, Visit, at, keep, (tries or 0) + 1)
			end)
		end
		return
	end
	local selling = not keep and Wanted()
	Repair(false, selling)
	if keep then
		notes[#notes + 1] = "kept with Shift"
		Kept()
	elseif selling then
		Sell()
	end
	if not run then
		SayRepair()
	end
	if retryRepair and not run then
		retryRepair = false
		Repair(true)
	end
end

E.Listen(part, "PLAYER_MONEY", function()
	if not moneyWait or not MerchantOpen() then
		return
	end
	local cost, money = E.Ask(GetRepairAllCost), E.Ask(GetMoney)
	if type(cost) ~= "number" or cost <= 0 then
		moneyWait = false
	elseif type(money) == "number" and money >= cost then
		moneyWait = false
		Repair(true)
	end
end)

E.Listen(part, "MERCHANT_SHOW", function()
	if run then
		Finish("the merchant closed")
	end
	SayRepair()
	visit = visit + 1
	open, notes, run, paused, retryRepair, moneyWait, guildRefused, pending, repairAfterFight = true, {}, nil, false, false, false, false, nil, false
	more, manual = 0, false
	if nextButton then
		nextButton:Hide()
	end
	local keep = E.Ask(IsShiftKeyDown) == true
	if E.Opt("sell") ~= true and E.Opt("repair") == "off" then
		return
	end
	if E.Fighting() then
		waiting, pending = true, { at = visit, keep = keep }
		return
	end
	Visit(visit, keep)
end)

local function Closed()
	if run then
		Finish("the merchant closed")
	end
	SayRepair()
	open, waiting, paused, retryRepair, moneyWait, pending, repairAfterFight = false, false, false, false, false, nil, false
	more, manual = 0, false
	if nextButton then
		nextButton:Hide()
	end
	visit = visit + 1
end

E.Listen(part, "MERCHANT_CLOSED", Closed)

E.Listen(part, "TRADE_SHOW", function()
	if run then
		Finish("a trade opened")
	end
end)

E.Listen(part, "PLAYER_REGEN_ENABLED", function()
	if pending then
		local wait = pending
		pending = nil
		if wait.at == visit and not E.Fighting() then
			Visit(wait.at, wait.keep)
		else
			waiting = false
		end
	elseif run and paused and MerchantOpen() and Wanted() then
		Sell()
	end
	if repairAfterFight and MerchantOpen() and not E.Fighting() then
		repairAfterFight = false
		Repair(true)
	end
	if more > 0 then
		ShowNext()
	end
end)

E.Listen(part, "INPUT_DEVICE_INTERFACE_TRANSITION", function()
	if more > 0 or nextButton then
		ShowNext()
	end
end)

function part.Refresh()
	if run and not Wanted() then
		Finish("selling was turned off")
	end
	ShowNext()
end

local function ItemId(text)
	text = tostring(text or ""):match("^%s*(.-)%s*$")
	local id = tonumber(text:match("^(%d+)$") or text:match("|Hitem:(%d+)") or text:match("^item:(%d+)"))
	if id and id > 0 and id == math.floor(id) then
		return id
	end
	local wanted = text:lower()
	if wanted == "" or type(C_Container) ~= "table" then
		return nil
	end
	for bag = 0, Bags() do
		local slots = E.Ask(C_Container.GetContainerNumSlots, bag)
		for slot = 1, type(slots) == "number" and slots or 0 do
			local info = E.Ask(C_Container.GetContainerItemInfo, bag, slot)
			local name = type(info) == "table" and Field(info, "itemName") or nil
			if type(name) == "string" and name:lower() == wanted and type(Field(info, "itemID")) == "number" then
				return Field(info, "itemID")
			end
		end
	end
	return nil
end

local function Named(id)
	local name = type(C_Item) == "table" and E.Ask(C_Item.GetItemNameByID, id) or nil
	if type(name) == "string" and name ~= "" then
		return ("%s (%d)"):format(name, id)
	end
	return tostring(id)
end

local function Listing(list)
	local ids = {}
	for id, on in pairs(list) do
		if on == true and type(id) == "number" then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	local names = {}
	for _, id in ipairs(ids) do
		names[#names + 1] = Named(id)
	end
	return #names > 0 and table.concat(names, ", ") or "none"
end

local function Unlisted(which, id)
	return ("Flat UI: %s is no longer %s."):format(Named(id), which == "sell" and "always sold" or "kept")
end

local listWatchers = {}

local function ListsChanged()
	for _, fn in ipairs(listWatchers) do
		pcall(fn)
	end
end

function ns.ErrandsListsWatch(fn)
	if type(fn) ~= "function" then
		return false
	end
	for _, known in ipairs(listWatchers) do
		if known == fn then
			return true
		end
	end
	listWatchers[#listWatchers + 1] = fn
	return true
end

local function Toggle(which, rest)
	local lists = E.Lists()
	if not lists then
		return
	end
	if rest == nil or rest:match("^%s*$") then
		print(("Flat UI: always sold: %s."):format(Listing(lists.sell)))
		print(("Flat UI: never sold: %s."):format(Listing(lists.keep)))
		return
	end
	local id = ItemId(rest)
	if not id then
		print(("Flat UI: /flatui %s takes an item link, an item ID or the name of an item in your bags."):format(which))
		return
	end
	local list, other = lists[which], which == "sell" and lists.keep or lists.sell
	if list[id] then
		list[id] = nil
		print(Unlisted(which, id))
	else
		list[id], other[id] = true, nil
		print(("Flat UI: %s is %s."):format(Named(id), which == "sell" and "always sold at merchants" or "never sold"))
	end
	ListsChanged()
end

E.slash.sell = function(rest)
	Toggle("sell", rest)
end
E.slash.keep = function(rest)
	Toggle("keep", rest)
end
E.help[#E.help + 1] = "/flatui sell <item> - always sell an item at merchants, or stop; with no item, both lists"
E.help[#E.help + 1] = "/flatui keep <item> - never sell a grey item, or sell it again"

local function ListLines(which)
	local lists, rows = E.Lists(), {}
	for id, on in pairs(lists and lists[which] or {}) do
		if on == true and type(id) == "number" then
			rows[#rows + 1] = { id, Named(id) }
		end
	end
	table.sort(rows, function(a, b)
		return a[2] < b[2]
	end)
	return rows
end

local function ListPick(which, id)
	local lists = E.Lists()
	if not lists or type(id) ~= "number" or lists[which][id] ~= true then
		return false
	end
	lists[which][id] = nil
	ListsChanged()
	return true, Unlisted(which, id)
end

function ns.ErrandsSellLines()
	return ListLines("sell")
end

function ns.ErrandsSellPick(id)
	return ListPick("sell", id)
end

function ns.ErrandsKeepLines()
	return ListLines("keep")
end

function ns.ErrandsKeepPick(id)
	return ListPick("keep", id)
end

function part.Status()
	local lists = E.Lists() or { sell = {}, keep = {} }
	local does = {}
	if E.Opt("sell") == true then
		does[#does + 1] = ("sells grey items (%d always sold, %d kept)"):format(Count(lists.sell), Count(lists.keep))
	end
	local how = E.Opt("repair")
	if how == "own" then
		does[#does + 1] = "repairs with your gold"
	elseif how == "guild" then
		local where = STATUS_WHERE[E.Opt("guildWhere")]
		does[#does + 1] = "repairs with guild gold first" .. (where and (" " .. where) or "")
	end
	if #does == 0 then
		return {}
	end
	local line = "Merchant: " .. table.concat(does, ", ") .. "."
	if waiting or paused then
		line = line .. " Waiting for the fight to end."
	elseif #notes > 0 then
		line = line .. " Last visit: " .. table.concat(notes, ", ") .. "."
	end
	local waits = open and WaitsFor()
	if waits then
		line = line .. (" %d more of your sell list %s %s."):format(more, Wait(more), waits)
	end
	local lines = { line }
	if type(C_Container) ~= "table" or type(C_Container.UseContainerItem) ~= "function" then
		lines[#lines + 1] = "Merchant: this client cannot sell from the bags."
	end
	if E.Opt("sell") == true then
		local bags = ExcludedBags()
		if #bags > 0 then
			local named = #bags == 1 and bags[1] or (table.concat(bags, ", ", 1, #bags - 1) .. " and " .. bags[#bags])
			lines[#lines + 1] = ("Merchant: grey items in %s stay: the game's bag menu leaves %s out of junk selling."):format(named, #bags == 1 and "it" or "them")
		end
	end
	return lines
end

function ns.ErrandsJunk(bag, slot, anyLock)
	if not (ns.Finite(bag) and ns.Finite(slot)) or bag < 0 or bag > Bags() or type(C_Container) ~= "table" then
		return false
	end
	local lists = E.Lists()
	if not lists then
		return false
	end
	return Sale(bag, slot, lists, JunkExcluded(bag), anyLock == true) ~= nil
end

function ns.ErrandsJunkRule(id, quality, noValue, quest)
	if not ns.Finite(id) or ns.IsSecret(noValue) or ns.IsSecret(quest) or noValue == true or quest == true then
		return false
	end
	local lists = E.Lists()
	if not lists then
		return false
	end
	if lists.sell[id] == true then
		return true
	end
	return ns.Finite(quality) and quality == POOR and lists.keep[id] ~= true
end

function ns.ErrandsJunkCount()
	if type(C_Container) ~= "table" or type(C_Container.UseContainerItem) ~= "function" then
		return 0, 0, 0, false
	end
	local queue, waits = Scan(Capped() and Buyback() or nil, 0)
	local value, unknown = 0, false
	for _, sale in ipairs(queue) do
		if ns.Finite(sale.price) and ns.Finite(sale.count) then
			value = value + sale.price * sale.count
		else
			unknown = true
		end
	end
	return #queue, waits, value, unknown
end

local function SellJunk()
	if not E.Shown(MerchantFrame) then
		return false, "no merchant is open"
	elseif E.Fighting() then
		return false, "you are in a fight"
	elseif run and not paused then
		return false, "busy"
	elseif E.Shown(TradeFrame) then
		return false, "a trade window is open"
	elseif E.Ask(GetCursorInfo) ~= nil or E.Ask(CursorHasItem) == true then
		return false, "the cursor holds something"
	elseif Targeting() then
		return false, "a spell waits for its target"
	elseif type(C_Container) ~= "table" or type(C_Container.UseContainerItem) ~= "function" then
		return false, "this client cannot sell from the bags"
	end
	manual = true
	if run then
		Sell()
		return true
	end
	if not open then
		visit = visit + 1
		open = true
	end
	more = 0
	if nextButton then
		nextButton:Hide()
	end
	Sell()
	if run == nil then
		return false, "there is nothing to sell"
	end
	return true
end

function ns.ErrandsSellJunk()
	local stopped = "selling stopped after an error (/flatui status)"
	if ns.IsStopped("errands") or ns.PartStopped("errands", part.label) then
		return false, stopped
	end
	local done, why = false, nil
	if not E.Run(part, function()
		done, why = SellJunk()
	end) then
		return false, stopped
	end
	return done, why
end

function ns.ErrandsMerchantClosed()
	E.Run(part, Closed)
end

function ns.ErrandsSelling()
	return run ~= nil
end

function ns.ErrandsJunkMark(id, junk, noValue)
	if not ns.Finite(id) or id <= 0 or id ~= math.floor(id) then
		return false
	end
	local lists = E.Lists()
	if not lists then
		return false
	end
	if junk == true then
		if ns.IsSecret(noValue) or noValue == true or Price("item:" .. id) == 0 then
			return false
		end
		lists.sell[id], lists.keep[id] = true, nil
		print(("Flat UI: %s is always sold at merchants."):format(Named(id)))
		ListsChanged()
		return true
	end
	local changed = false
	if lists.sell[id] == true then
		lists.sell[id] = nil
		print(Unlisted("sell", id))
		changed = true
	end
	local quality = type(C_Item) == "table" and E.Ask(C_Item.GetItemQualityByID, id) or nil
	if ns.Finite(quality) and quality == POOR and lists.keep[id] ~= true then
		lists.keep[id] = true
		print(("Flat UI: %s is never sold."):format(Named(id)))
		changed = true
	end
	if changed then
		ListsChanged()
	end
	return true
end
