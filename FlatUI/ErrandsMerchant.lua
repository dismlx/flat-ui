local _, ns = ...

-- Errands at a merchant: grey items are sold and gear is repaired when the merchant window opens: MERCHANT_SHOW, then the window itself shown,
-- looked for every LOOK seconds for up to LOOKS tries (the game can show it a moment after the event, or load it first). Holding Shift as it opens
-- keeps the items for that visit, and one line says so with how many would have sold ("Kept 7 grey items this visit (Shift was held as the merchant
-- opened)."), only when there were some and Say what was done is on; the repair is still made, with its own line. Out of combat only: a merchant
-- opened in a fight waits for its end, and a fight that starts while items are being sold pauses the selling until it ends, if the merchant is
-- still open then.
--
-- Selling walks the bags (C_Container.GetContainerNumSlots and GetContainerItemInfo, bags 0 to NUM_TOTAL_EQUIPPED_BAG_SLOTS) and sells one item
-- every SPACING seconds with C_Container.UseContainerItem, which sells while a merchant is open and uses or equips the item otherwise. So before
-- every sale the merchant window must still be shown (MerchantFrame, asked with the widget call IsShown) and no trade window open (TradeFrame:
-- the same call puts an item in the trade), the module and the row still on, the cursor empty, no spell waiting for its target (SpellIsTargeting,
-- SpellCanTargetItem, SpellCanTargetItemID: the same call would give it the item, Mainline/ContainerFrame.lua:1508-1510), and the slot must still
-- hold the same unlocked item, whose count is read again there. An item of poor quality (grey) is sold unless it is on the keep list;
-- an item on the sell list is sold whatever its quality. A quest item and an item the game gives no value are never sold. The lists hold item
-- IDs for the whole account (Errands.Lists) and are changed with /flatui sell and /flatui keep, or taken off with the two list rows of the page.
-- The money is counted from the sell price the game gives (C_Item.GetItemInfo) and said once at the end, with no amount when a price was not known.
-- No grey item is sold from a bag the game's own bag menu leaves out of junk selling (Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua:688-709):
-- the backpack while C_Container.GetBackpackSellJunkDisabled plainly answers true, another bag while C_Container.GetBagSlotFlag(bag,
-- Enum.BagSlotFlags.ExcludeJunkSell) does (ContainerDocumentation.lua:57-64 and 81-95; any other answer sells as before). An item of the sell
-- list is still sold from such a bag.
--
-- Grey items are sold first, all of them. The items of the sell list that are not grey come after them, and with Sell at most 12 at a time on, no
-- more of them in a pass than the merchant's buyback holds (BUYBACK_ITEMS_PER_PAGE, 12, Mainline/MerchantFrame.lua:2), so they are the last sold
-- and the buyback, which keeps the last sales, still holds them. A pass of no more sales than the buyback holds keeps the order of the bags, since
-- the buyback then holds every one of them. When items of the list wait, a Sell next 12 button of Flat UI's own lies just under the merchant
-- window at its right, where it covers none of the game's buttons: Repair Item, Repair All, Guild Bank Repair and Sell All Junk lie in the
-- bottom left of the window and move as the merchant can repair or not (MerchantFrame.lua:987-1019, Mainline/MerchantFrame.xml:200-330), the
-- buyback slot lies on its right half (MerchantFrame.xml:409-413), and the Merchant and Buyback tabs hang under its left edge
-- (MerchantFrame.xml:583-614, 32 units high, SharedUIPanelTemplates.xml:932-933). Its click sells the next ones through the same checks; a click
-- the trade window, the cursor or a spell waiting for its target stops before its first sale says why and leaves the button. It is made out of
-- combat only, never under the gamepad interface, and hides itself whenever it is no longer wanted. Under the gamepad interface the cap still
-- holds, and chat and /flatui status say that the rest wait until a merchant is opened again.
--
-- Repair uses RepairAllItems, with the guild's money first when Repair is Guild gold first and the guild lets you (CanGuildBankRepair and
-- GetGuildBankWithdrawMoney, -1 for no limit). Two seconds later, an unpaid bill with the merchant still open is paid with your own gold. A bill
-- you cannot pay is tried again once the selling is done and the money for it has come (PLAYER_MONEY), or MONEY_WAIT seconds later. The cost
-- is GetRepairAllCost before the repair. Guild gold where keeps the guild's money for some places: inside an instance (IsInInstance,
-- InstanceDocumentation.lua:170-177) a raid, a dungeon (party) or a battleground (pvp or arena); outside one, a raid group (IsInRaid) or a
-- group (IsInGroup); anywhere else, a withheld answer included, the open world. Elsewhere the bill is paid with your own gold. A repair paid
-- with your own gold as the opening of the merchant starts a sell pass is said in the pass's line at its end (Sold 9 items for 38s 2c and
-- repaired for 1g 4s.), or alone when the pass sells nothing; a repair of the guild's, one paid with your gold because of Guild gold where, and
-- one tried again after the selling keep lines of their own.
-- The Sell junk button of Bags (BagsWindow.lua) sells through the same pass, with all its checks, whatever the switch of Errands and of Sell grey
-- items: ns.ErrandsSellJunk starts a pass (or goes on with one a fight paused), the pass then counts as wanted until it ends (manual), and since
-- this module hears no event while it is off, Bags ends the visit at its own MERCHANT_CLOSED with ns.ErrandsMerchantClosed, which does what
-- MERCHANT_CLOSED does here; when both run, either order does the same. The junk coin and the Junk section of Bags are this file's own test of a
-- slot (ns.ErrandsJunk, Sale below), and the count on its button is the queue Scan makes for a new pass (ns.ErrandsJunkCount); an item no pass can
-- sell from where it lies, in the bank or in another character's bags, has the part of the test that reads the two lists (ns.ErrandsJunkRule).
-- An item dropped on a section title of Bags goes on or off the two lists as /flatui sell and /flatui keep put it there (ns.ErrandsJunkMark).
-- Every change of the lists (those two commands, their list rows and a drop) is told to the functions given to ns.ErrandsListsWatch, so the junk
-- coin and the Sell junk count of Bags follow it at once.
-- The selling and repair follow EnhanceQoL's vendor and auto repair, adapted with the permission of its author. The sale of the sell list in
-- twelves, the bags left out of junk selling and the places of guild gold follow EnhanceQoL by Philipp Barth (R41Z0R), adapted with his
-- permission (EnhanceQoLVendor/EnhanceQoLVendor.lua:77-95, 1403-1418, 1789-1823; EnhanceQoL/EnhanceQoL.lua:3976-3996).

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
-- The sales the merchant's buyback keeps, when the game does not say (BUYBACK_ITEMS_PER_PAGE, MerchantFrame.lua:2).
local BUYBACK = 12
-- The flag of a bag left out of junk selling, when the game does not say (Enum.BagSlotFlags.ExcludeJunkSell).
local EXCLUDE_JUNK = 64
local NEXT_LABEL, NEXT_WIDTH = "Sell next 12", 100
-- The places where guild gold pays, for each choice of Guild gold where but Everywhere, and the words of each.
local PLACES = {
	group = { raid = true, dungeon = true, battleground = true, group = true },
	instance = { raid = true, dungeon = true, battleground = true },
	raid = { raid = true },
}
local PLACE_WORDS = { group = "groups and instances", instance = "dungeons, raids and battlegrounds", raid = "raids" }
local STATUS_WHERE = { group = "in a group or an instance", instance = "in dungeons, raids and battlegrounds", raid = "in raids" }

local open = false
-- Counts up at each visit and at each stop, so a sale or check queued for an earlier visit does nothing.
local visit = 0
-- The selling of the visit: { queue = sales in order, next = index, sold, value, unknown = a price was not known, listed = items of the sell
-- list that are not grey sold in this pass }, or nil.
local run
-- The pass was asked for by the Sell junk button of Bags (ns.ErrandsSellJunk): it sells whatever the switch of Errands and of Sell grey items until
-- it ends (Finish). Set only while there is a pass.
local manual = false
-- The selling waits for a fight to end, or the whole visit does.
local paused, waiting = false, false
-- A repair that could not be paid is tried again after the selling; then it waits for the money. The guild bank refused at this visit. A
-- repair asked in a fight waits for its end.
local retryRepair, moneyWait, guildRefused, repairAfterFight = false, false, false, false
-- A visit that waits for the end of a fight: { at, keep }.
local pending
-- The cost of a repair made with your gold as a sell pass starts, said in the pass's own line (Finish) rather than a line of its own.
local repairSaid
-- What /flatui status says about the last visit: what was repaired and sold, in that order.
local notes = {}
-- Items of the sell list that wait for Sell next at this visit, and the button. A make of the button failed: it is not tried again.
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

-- How many sales the merchant's buyback keeps: BUYBACK_ITEMS_PER_PAGE when it is a plain whole number, else BUYBACK.
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

-- The flag the game's bag menu sets on a bag left out of junk selling (BagSlotFlags.ExcludeJunkSell).
local function ExcludeFlag()
	local enum = type(Enum) == "table" and not ns.IsSecret(Enum) and Enum.BagSlotFlags or nil
	local flag = type(enum) == "table" and not ns.IsSecret(enum) and enum.ExcludeJunkSell or nil
	return ns.Finite(flag) and flag or EXCLUDE_JUNK
end

-- Whether the game leaves a bag out of junk selling: only a plain true counts (ContainerFrame.lua:690-697 asks the same two calls).
local function JunkExcluded(bag)
	if type(C_Container) ~= "table" then
		return false
	end
	if bag == 0 then
		return E.Ask(C_Container.GetBackpackSellJunkDisabled) == true
	end
	return E.Ask(C_Container.GetBagSlotFlag, bag, ExcludeFlag()) == true
end

-- What a slot holds, as a sale, or nil when it is not to be sold. excluded: the bag is left out of junk selling, so a grey item stays unless it
-- is on the sell list; anyLock: a locked item counts too (ns.ErrandsJunk for Bags). A sale marked listed is an item of the sell list that is not grey.
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

-- The count the slot holds now, when it still holds the same unlocked item, or nil.
local function Same(sale)
	local info = E.Ask(C_Container.GetContainerItemInfo, sale.bag, sale.slot)
	if type(info) ~= "table" or Field(info, "itemID") ~= sale.id or Field(info, "hyperlink") ~= sale.link or Field(info, "isLocked") ~= false then
		return nil
	end
	local count = Field(info, "stackCount")
	return type(count) == "number" and count > 0 and count or 1
end

-- The sales of a pass in order, and how many items of the sell list wait for the next pass. allowance: how many items of the sell list that are
-- not grey the pass may sell, or nil for all of them; sold: the sales made already in this pass, before a fight paused it. Grey items come first
-- and the listed ones after them; a pass the buyback holds whole keeps the order of the bags.
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

-- A spell waits for its target, which the cursor does not say: C_Container.UseContainerItem would then give the item to the spell instead of selling
-- it, as the game's own bag slot does (Mainline/ContainerFrame.lua:1508-1510). Only a plain true counts.
local function Targeting()
	return E.Ask(SpellIsTargeting) == true or E.Ask(SpellCanTargetItem) == true or E.Ask(SpellCanTargetItemID) == true
end

-- Errands' own selling: the module and Sell grey items are on.
local function SellOn()
	return ns.Enabled("errands") and E.Opt("sell") == true
end

-- Errands' own selling, or a pass of the Sell junk button of Bags.
local function Wanted()
	return manual or SellOn()
end

-- The names of the bags the game leaves out of junk selling, for /flatui status: the backpack, and the others by the name the game gives them.
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

local function Items(n)
	return n == 1 and "item" or "items"
end

local function Wait(n)
	return n == 1 and "waits" or "wait"
end

-- What the items of the sell list that wait are waiting for: Sell next 12, or under the gamepad interface, where Flat UI puts no button on the
-- merchant window, the next visit. Nil when none wait, or when selling or its cap is off, as for the button itself. After a pass of the Sell junk
-- button of Bags with Errands' own selling off, Sell next never shows, and that button sells the next ones.
local function WaitsFor()
	if more <= 0 or not Wanted() or not Capped() then
		return nil
	end
	if manual and not SellOn() then
		return "for Sell junk"
	end
	return E.Gamepad() and "until you next open a merchant" or "for Sell next"
end

-- A repair line kept for the pass, said alone: the pass sold nothing, or there was none.
local function SayRepair()
	if repairSaid then
		E.Say(("Repaired for %s."):format(repairSaid))
		repairSaid = nil
	end
end

-- Ends the selling of the visit, and says what was sold: why it stopped when it did not end by itself, else how many of the sell list wait. A
-- repair made as the pass started is said in the same line, or alone first when nothing was sold.
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
	-- A pass of the Sell junk button of Bags ends here, after its line: Sell next follows Errands' own selling again.
	manual = false
	ShowNext()
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

-- A pass: the bags are read again, and with Sell at most 12 at a time on, the items of the sell list already sold in this pass (before a fight
-- paused it) count against the buyback.
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

-- Sell next 12 ------------------------------------------------------------------------------------------------------------------------------

-- Whether the button is still wanted: asked by the button every frame while it shows, outside the part, so a stopped part or an event missed
-- while the module was off cannot leave it on the merchant window.
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

-- A click: a new pass, with every check of SellNext. The checks of its first sale that a click can fail are made here first, so such a click says
-- why it sold nothing and leaves the count and the button as they were.
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

-- Makes the button on the merchant window, out of the lockdown only, as Train all is made (ErrandsTrainer.lua:241-276). False while it cannot be.
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
	-- Just under the window at its right: the game's four buttons and the tabs lie at its left, the buyback slot inside it (see the top of the file).
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

-- Repairs -----------------------------------------------------------------------------------------------------------------------------------

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

-- Where you are, for Guild gold where, from plain answers only (EnhanceQoL/EnhanceQoL.lua:3976-3996, without its Mythic+ place, which Forever
-- does not have): raid, dungeon or battleground inside an instance; raid or group outside one; world anywhere else.
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

-- Whether guild gold may pay where you are: Everywhere, or a place Guild gold where names.
local function GuildHere()
	local places = PLACES[E.Opt("guildWhere")]
	return places == nil or places[Place()] == true
end

-- Repairs everything. last: the try after the selling, which says when there is not enough gold; the first try waits for the selling instead.
-- hold: a sell pass follows at once, so a repair with your gold is said in its line (repairSaid). In a fight nothing is repaired: the repair
-- waits for its end, if the merchant is still open then.
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
	-- Guild gold first, but not where Guild gold where leaves the bill to your own gold.
	local elsewhere = how == "guild" and not GuildHere()
	if how == "guild" and not elsewhere and not guildRefused and E.Ask(CanGuildBankRepair) == true then
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

-- Shift held as the merchant opened: one line says what a pass would have sold, so a Shift held by chance does not read as selling broken. Only
-- while Sell grey items is on and there was something to sell; "grey items" while all of it is grey.
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
	-- The game may show its window a moment after the event: look again for a while.
	if not E.Shown(MerchantFrame) then
		if (tries or 0) < LOOKS then
			C_Timer.After(LOOK, function()
				E.Run(part, Visit, at, keep, (tries or 0) + 1)
			end)
		end
		return
	end
	-- A pass that follows says the repair in its own line.
	local selling = not keep and Wanted()
	Repair(false, selling)
	if keep then
		notes[#notes + 1] = "kept with Shift"
		Kept()
	elseif selling then
		Sell()
	end
	-- A pass that could not start says the repair alone.
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
	-- A merchant that opens over another one: the selling of the first ends with its line.
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
	-- In a fight, or the moment before its lockdown, the visit waits for PLAYER_REGEN_ENABLED.
	if E.Fighting() then
		waiting, pending = true, { at = visit, keep = keep }
		return
	end
	Visit(visit, keep)
end)

-- The merchant closed: the selling ends with its line, and what was queued for the visit does nothing. Errands hears MERCHANT_CLOSED while it is
-- on, and Bags calls this at its own (ns.ErrandsMerchantClosed) for a pass of its Sell junk button; when both run, the second finds nothing left.
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

-- A trade window that opens stops the selling: the same call would put the item in the trade.
E.Listen(part, "TRADE_SHOW", function()
	if run then
		Finish("a trade opened")
	end
end)

-- A fight that ended with the merchant still open: a visit that waited runs, and paused selling goes on with what the bags hold now. Sell next
-- comes back once the fight is over.
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

-- Finish clears the run, so a queued sale does nothing; the visit goes on, and so do its repair checks. Only the merchant opening or closing
-- starts another visit.
function part.Refresh()
	if run and not Wanted() then
		Finish("selling was turned off")
	end
	ShowNext()
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

-- The line said when an item leaves its list.
local function Unlisted(which, id)
	return ("Flat UI: %s is no longer %s."):format(Named(id), which == "sell" and "always sold" or "kept")
end

-- The functions told when the sell or keep list changes (ns.ErrandsListsWatch): the junk coin and the Sell junk count of Bags read these lists, so
-- its windows draw them again. Each is called inside pcall, so none can stop the change.
local listWatchers = {}

local function ListsChanged()
	for _, fn in ipairs(listWatchers) do
		pcall(fn)
	end
end

-- Adds a function to them, called with no values after /flatui sell, /flatui keep, a pick of the two list rows or a drop on a section of Bags
-- changed a list. A function given twice is called once. True once it is in the list.
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

-- The rows Items always sold and Items never sold: the items of a list by name and ID, and a pick takes one off with the line of /flatui sell or
-- /flatui keep (Toggle above), as Skipped NPCs does (ErrandsQuests.lua:1021-1042).
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

-- The Sell junk button and the Junk section of Bags ---------------------------------------------------------------------------------------

-- Errands' own test of a slot of the bags (Sale above), for the junk coin and the Junk section of Bags: true when a pass would sell what the slot
-- holds now. False for a bag no pass sells from (the keyring, the bank), for one with no price, and before the saved variables load. A locked item
-- is false too, unless anyLock is true: Bags asks so, since the game holds an item locked only for a moment (in the trade window, on a mail not
-- sent yet, on the cursor), and its coin and section stay meanwhile. A pass and the count of Sell junk (Scan) still leave a locked item.
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

-- The part of that test that reads the two lists (Sale above), for an item no pass can sell from where it lies: in the bank, or in the bags of
-- another character. True for an item of the sell list, or a grey one (quality 0) not on the keep list; never for an item with no vendor value or a
-- quest item, and a value the game withholds counts as either.
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

-- What the next click of the Sell junk button sells: the length of the queue Scan makes for a new pass, how many items of the sell list wait for
-- the click after it with Sell at most 12 at a time on (Sell), what the queue is worth at the merchant in copper (each sale's price times its
-- count), and true when the price of one of them has not loaded, so the worth is at least that. 0, 0, 0 on a client that cannot sell.
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

-- A click of the Sell junk button. Before anything is sold it makes the checks of a click of Sell next 12 (SellMore), so a click they refuse says
-- why and leaves the pass as it was.
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
		-- A pass a fight paused goes on with what the bags hold now, as Errands' own PLAYER_REGEN_ENABLED has it go on.
		Sell()
		return true
	end
	if not open then
		-- Errands' own MERCHANT_SHOW did not run for this merchant: Errands is off, or was switched on after the merchant opened. When it did run,
		-- the visit stays as it is, so the repair checks queued for it still hold.
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

-- The Sell junk button of Bags: a pass of Errands' own selling with all its checks, whatever the switch of Errands and of Sell grey items, or the
-- pass a fight paused going on. True when it sells, or false and why not: "busy" while a pass is selling, else a few words a line can end with
-- ("Sold nothing: ..."). With Errands off, Bags calls it again at PLAYER_REGEN_ENABLED while ns.ErrandsSelling() says a pass waits, as Errands'
-- own handler goes on with one.
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

-- Bags at its own MERCHANT_CLOSED: what MERCHANT_CLOSED does here (Closed), which this module does not hear while it is off. When both run, the
-- second finds nothing left to end.
function ns.ErrandsMerchantClosed()
	E.Run(part, Closed)
end

-- True while a pass sells, or waits for a fight to end.
function ns.ErrandsSelling()
	return run ~= nil
end

-- A drop on a section title of Bags. On Junk (junk true) the item goes on the sell list and off the keep list, as /flatui sell puts it there;
-- dropped on another section it comes off the sell list, and a grey one (C_Item.GetItemQualityByID) goes on the keep list, as /flatui keep puts it
-- there. Each change says the line of those commands. True once the lists hold what the drop asked; false before the saved variables load, and
-- for an item no merchant buys (noValue, or a sell price of 0 from C_Item.GetItemInfo), which no pass would sell and Bags refuses with a line of
-- its own.
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
