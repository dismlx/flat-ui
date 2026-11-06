local _, ns = ...

-- Errands at a merchant: grey items are sold and gear is repaired when the merchant window opens: MERCHANT_SHOW, then the window itself shown,
-- looked for every LOOK seconds for up to LOOKS tries (the game can show it a moment after the event, or load it first). Holding Shift as it
-- opens keeps the items for that visit; the repair is still made. Out of combat only: a merchant opened in a fight waits for its end, and a
-- fight that starts while items are being sold pauses the selling until it ends, if the merchant is still open then.
--
-- Selling walks the bags (C_Container.GetContainerNumSlots and GetContainerItemInfo, bags 0 to NUM_TOTAL_EQUIPPED_BAG_SLOTS) and sells one item
-- every SPACING seconds with C_Container.UseContainerItem, which sells while a merchant is open and uses or equips the item otherwise. So before
-- every sale the merchant window must still be shown (MerchantFrame, asked with the widget call IsShown) and no trade window open (TradeFrame:
-- the same call puts an item in the trade), the module and the row still on, the cursor empty, and the slot must still hold the same unlocked
-- item, whose count is read again there. An item of poor quality (grey) is sold unless it is on the keep list;
-- an item on the sell list is sold whatever its quality. A quest item and an item the game gives no value are never sold. The lists hold item
-- IDs for the whole account (Errands.Lists) and are changed with /flatui sell and /flatui keep. The money is counted from the sell price the
-- game gives (C_Item.GetItemInfo) and said once at the end, with no amount when a price was not known.
--
-- Repair uses RepairAllItems, with the guild's money first when Repair is Guild gold first and the guild lets you (CanGuildBankRepair and
-- GetGuildBankWithdrawMoney, -1 for no limit). Two seconds later, an unpaid bill with the merchant still open is paid with your own gold. A bill
-- you cannot pay is tried again once the selling is done and the money for it has come (PLAYER_MONEY), or MONEY_WAIT seconds later. The cost
-- is GetRepairAllCost before the repair.
-- The selling and repair follow EnhanceQoL's vendor and auto repair, adapted with the permission of its author.

local E = ns.Errands
local part = E.Part({ label = "Merchant" })

-- Seconds between two sales, so the server takes each before the next.
local SPACING = 0.15
-- Seconds before a repair from the guild bank is checked.
local GUILD_CHECK = 2
-- How the merchant window is looked for after MERCHANT_SHOW.
local LOOK, LOOKS = 0.05, 40
-- Seconds the last try of a repair waits for the money of the last sales.
local MONEY_WAIT = 1
local DEFAULT_BAGS = 4
local POOR = 0

local open = false
-- Counts up at each visit and at each stop, so a sale or check queued for an earlier visit does nothing.
local visit = 0
-- The selling of the visit: { queue = sales in order, next = index, sold, value, unknown = a price was not known }, or nil.
local run
-- The selling waits for a fight to end, or the whole visit does.
local paused, waiting = false, false
-- A repair that could not be paid is tried again after the selling; then it waits for the money. The guild bank refused at this visit. A
-- repair asked in a fight waits for its end.
local retryRepair, moneyWait, guildRefused, repairAfterFight = false, false, false, false
-- A visit that waits for the end of a fight: { at, keep }.
local pending
-- What /flatui status says about the last visit: what was repaired and sold, in that order.
local notes = {}

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

-- The sell price of one item, or nil when the game has not said yet (C_Item.GetItemInfo gives it 11th).
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

-- What a slot holds, as a sale, or nil when it is not to be sold.
local function Sale(bag, slot, lists)
	local info = E.Ask(C_Container.GetContainerItemInfo, bag, slot)
	if type(info) ~= "table" then
		return nil
	end
	local id, link, count = Field(info, "itemID"), Field(info, "hyperlink"), Field(info, "stackCount")
	if type(id) ~= "number" or type(link) ~= "string" or Field(info, "isLocked") ~= false or Field(info, "hasNoValue") ~= false then
		return nil
	end
	local listed = lists.sell[id] == true
	if not listed and (lists.keep[id] == true or Field(info, "quality") ~= POOR) then
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
	return { bag = bag, slot = slot, id = id, link = link, count = count, price = price }
end

-- The count the slot holds now, when it still holds the same unlocked item, or nil.
local function Same(sale)
	local info = E.Ask(C_Container.GetContainerItemInfo, sale.bag, sale.slot)
	if type(info) ~= "table" or Field(info, "itemID") ~= sale.id or Field(info, "hyperlink") ~= sale.link or Field(info, "isLocked") ~= false then
		return nil
	end
	local count = Field(info, "stackCount")
	return type(count) == "number" and count > 0 and count or 1
end

local function Scan()
	local lists, queue = E.Lists(), {}
	if not lists then
		return queue
	end
	for bag = 0, Bags() do
		local slots = E.Ask(C_Container.GetContainerNumSlots, bag)
		for slot = 1, type(slots) == "number" and slots or 0 do
			local sale = Sale(bag, slot, lists)
			if sale then
				queue[#queue + 1] = sale
			end
		end
	end
	return queue
end

local function MerchantOpen()
	return open and E.Shown(MerchantFrame)
end

local function Wanted()
	return ns.Enabled("errands") and E.Opt("sell") == true
end

local Repair, WaitForMoney

-- The last try of a repair, once the money of the last sales has come: at the first PLAYER_MONEY that pays the bill, or MONEY_WAIT seconds later.
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

-- Ends the selling of the visit, and says what was sold: why it stopped when it did not end by itself.
local function Finish(why)
	local done = run
	run, paused = nil, false
	if done and done.sold > 0 then
		local amount = done.unknown and "" or (" for " .. E.Money(done.value))
		notes[#notes + 1] = ("sold %d%s"):format(done.sold, amount)
		E.Say(("Sold %d %s%s%s."):format(done.sold, done.sold == 1 and "item" or "items", amount, why and (", then stopped: " .. why) or ""))
	end
	if retryRepair and MerchantOpen() then
		retryRepair = false
		-- The money of a sale comes a moment after it; with nothing sold there is nothing to wait for.
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
	local sale = run.queue[run.next]
	if not sale then
		Finish(nil)
		return
	end
	run.next = run.next + 1
	local count = Same(sale)
	if count and E.Call(C_Container.UseContainerItem, sale.bag, sale.slot) then
		run.sold = run.sold + 1
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
	local queue = Scan()
	if #queue == 0 then
		Finish(nil)
		return
	end
	run = run or { sold = 0, value = 0, unknown = false }
	run.queue, run.next = queue, 1
	paused = false
	SellNext(visit)
end

-- Two seconds after a repair asked of the guild bank: what the bill says now tells whether the guild paid. With the merchant gone, only that
-- is said; with it open, an unpaid bill goes to your own gold, now or once the selling has brought the money.
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

-- Repairs everything. last: the try after the selling, which says when there is not enough gold; the first try waits for the selling instead.
-- In a fight nothing is repaired: the repair waits for its end, if the merchant is still open then.
Repair = function(last)
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
	if how == "guild" and not guildRefused and E.Ask(CanGuildBankRepair) == true then
		local allowed = E.Ask(GetGuildBankWithdrawMoney)
		if type(allowed) == "number" and (allowed < 0 or allowed >= cost) and E.Call(RepairAllItems, true) then
			-- What is said waits for the bill: the guild bank can still refuse.
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
		notes[#notes + 1] = ("repaired for %s"):format(E.Money(cost))
		E.Say(("Repaired for %s."):format(E.Money(cost)))
	end
end

local function Visit(at, keep, tries)
	waiting = false
	if at ~= visit or not open or not ns.Enabled("errands") then
		return
	end
	-- The game may show its window a moment after the event: look again for a while.
	if not E.Shown(MerchantFrame) then
		if (tries or 0) < LOOKS then
			C_Timer.After(LOOK, function()
				E.Run(part, Visit, at, keep, (tries or 0) + 1)
			end)
		end
		return
	end
	Repair(false)
	if keep then
		notes[#notes + 1] = "kept with Shift"
	elseif Wanted() then
		Sell()
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
	-- A merchant that opens over another one: the selling of the first ends with its line.
	if run then
		Finish("the merchant closed")
	end
	visit = visit + 1
	open, notes, run, paused, retryRepair, moneyWait, guildRefused, pending, repairAfterFight = true, {}, nil, false, false, false, false, nil, false
	local keep = E.Ask(IsShiftKeyDown) == true
	if E.Opt("sell") ~= true and E.Opt("repair") == "off" then
		return
	end
	-- In a fight, or the moment before its lockdown, the visit waits for PLAYER_REGEN_ENABLED.
	if E.Fighting() then
		waiting, pending = true, { at = visit, keep = keep }
		return
	end
	Visit(visit, keep)
end)

E.Listen(part, "MERCHANT_CLOSED", function()
	if run then
		Finish("the merchant closed")
	end
	open, waiting, paused, retryRepair, moneyWait, pending, repairAfterFight = false, false, false, false, false, nil, false
	visit = visit + 1
end)

-- A trade window that opens stops the selling: the same call would put the item in the trade.
E.Listen(part, "TRADE_SHOW", function()
	if run then
		Finish("a trade opened")
	end
end)

-- A fight that ended with the merchant still open: a visit that waited runs, and paused selling goes on with what the bags hold now.
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
end)

-- Finish clears the run, so a queued sale does nothing; the visit goes on, and so do its repair checks. Only the merchant opening or closing
-- starts another visit.
function part.Refresh()
	if run and not Wanted() then
		Finish("selling was turned off")
	end
end

-- /flatui sell and /flatui keep -------------------------------------------------------------------------------------------------------------

-- The item ID of what was typed: a number, a shift-clicked link, or the name of an item in the bags.
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
		print(("Flat UI: %s is no longer %s."):format(Named(id), which == "sell" and "always sold" or "kept"))
	else
		list[id], other[id] = true, nil
		print(("Flat UI: %s is %s."):format(Named(id), which == "sell" and "always sold at merchants" or "never sold"))
	end
end

E.slash.sell = function(rest)
	Toggle("sell", rest)
end
E.slash.keep = function(rest)
	Toggle("keep", rest)
end
E.help[#E.help + 1] = "/flatui sell <item> - always sell an item at merchants, or stop; with no item, both lists"
E.help[#E.help + 1] = "/flatui keep <item> - never sell a grey item, or sell it again"

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
		does[#does + 1] = "repairs with guild gold first"
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
	local lines = { line }
	if type(C_Container) ~= "table" or type(C_Container.UseContainerItem) ~= "function" then
		lines[#lines + 1] = "Merchant: this client cannot sell from the bags."
	end
	return lines
end
