local ADDON_NAME, ns = ...

local P = ns.DataPanels
local Ask, Read, Count, Field, Text, Labelled = P.Ask, P.Read, P.Count, P.Field, P.Text, P.Labelled
local DIM, GOOD, WARN, BAD = P.DIM, P.GOOD, P.WARN, P.BAD
local MOST = 25
local HEARTHSTONE, HEARTHSTONE_ICON = 6948, 134414
local ROSTER_EVERY = 15
local HOURLY_AFTER = 600
local SHORT = 2
local REAGENT_BAG = 5
local SLOT_NAMES = { [1] = "Head", [2] = "Neck", [3] = "Shoulders", [4] = "Shirt", [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet",
	[9] = "Wrists", [10] = "Hands", [11] = "Finger", [12] = "Finger", [13] = "Trinket", [14] = "Trinket", [15] = "Back", [16] = "Main hand",
	[17] = "Off hand", [18] = "Ranged", [19] = "Tabard" }

local function More(lines, left)
	if left > 0 then
		lines[#lines + 1] = { ("%s and %d more|r"):format(DIM, left) }
	end
end

local function Who(name, class, level)
	local hex = P.ClassHex(class)
	local text = hex and (hex .. name .. "|r") or name
	if Count(level) and level > 0 then
		text = text .. " " .. DIM .. level .. "|r"
	end
	return text
end

local classFiles
local function ClassFile(localised)
	if type(localised) ~= "string" then
		return nil
	end
	if classFiles == nil then
		classFiles = {}
		for _, list in ipairs({ _G.LOCALIZED_CLASS_NAMES_MALE, _G.LOCALIZED_CLASS_NAMES_FEMALE }) do
			if type(list) == "table" and not ns.IsSecret(list) then
				pcall(function()
					for file, name in pairs(list) do
						if type(file) == "string" and type(name) == "string" and not ns.IsSecret(file) and not ns.IsSecret(name) then
							classFiles[name] = file
						end
					end
				end)
			end
		end
	end
	return classFiles[localised]
end

local function Shift()
	return Ask(_G.IsShiftKeyDown) == true
end

local function Ctrl()
	return Ask(_G.IsControlKeyDown) == true
end

local function Toggle(name, later, ...)
	local toggle = _G[name]
	if type(toggle) ~= "function" then
		return false
	end
	if type(ns.OpenAfterFight) == "function" then
		local count, args = select("#", ...), { ... }
		return ns.OpenAfterFight(function()
			_G[name](unpack(args, 1, count))
		end, later) == true
	end
	if P.InCombat() then
		return false
	end
	return (pcall(toggle, ...))
end

local function WindowHint(text)
	if P.InCombat() and type(ns.OpenAfterFight) == "function" then
		return (text:gsub("%.", ", after the fight."))
	elseif P.InCombat() then
		return "Out of a fight, " .. text:sub(1, 1):lower() .. text:sub(2)
	end
	return text
end

local function Grouped(value)
	value = math.floor(value + 0.5)
	return Text((Ask(_G.BreakUpLargeNumbers, value))) or tostring(value)
end

local function BagSpace()
	local bags = type(C_Container) == "table" and C_Container or nil
	local slots = bags and bags.GetContainerNumSlots or _G.GetContainerNumSlots
	local empties = bags and bags.GetContainerNumFreeSlots or _G.GetContainerNumFreeSlots
	local last = math.min(Count(NUM_TOTAL_EQUIPPED_BAG_SLOTS) or Count(NUM_BAG_SLOTS) or 4, 12)
	local free, total, otherFree, otherTotal = 0, 0, 0, 0
	for bag = 0, last do
		local hidden, size = Read(slots, bag)
		size = Count(size)
		if hidden then
			return nil
		elseif size and size > 0 then
			local withheld, empty, family = Read(empties, bag)
			empty = Count(empty)
			if withheld then
				return nil
			elseif empty then
				empty = math.min(empty, size)
				if bag ~= REAGENT_BAG and (family == nil or family == 0) then
					free, total = free + empty, total + size
				else
					otherFree, otherTotal = otherFree + empty, otherTotal + size
				end
			end
		end
	end
	return free, total, otherFree, otherTotal
end

local UNSAID = { DIM .. "The game does not say now.|r" }

local function Junk()
	local count = ns.ErrandsJunkCount
	if type(count) ~= "function" then
		return 0, 0, 0, false
	end
	local ok, n, waits, value, unknown = pcall(count)
	if not ok then
		return 0, 0, 0, false
	end
	return Count(n) or 0, Count(waits) or 0, Count(value) or 0, not ns.IsSecret(unknown) and unknown == true
end

P.Stream({
	id = "bags", label = "Bag space", sample = "Bags 888/888",
	events = { BAG_UPDATE_DELAYED = true },
	Text = function()
		local free, total = BagSpace()
		if not free or total == 0 then
			return nil
		end
		local colour = free == 0 and BAD or free * 10 <= total and WARN or ""
		return Labelled("Bags", ("%s%d/%d%s"):format(colour, free, total, colour ~= "" and "|r" or ""))
	end,
	Tip = function()
		local free, total, otherFree, otherTotal = BagSpace()
		if not free then
			return { title = "Bags", UNSAID }
		end
		local lines = { title = "Bags", { "Free", free }, { "Used", total - free }, { "Slots", total } }
		if otherTotal > 0 then
			lines[#lines + 1] = { "Special bags", ("%d of %d free"):format(otherFree, otherTotal) }
		end
		local n, waits, value, unknown = Junk()
		if n > 0 then
			lines[#lines + 1] = { "To sell", ("%d %s, %s%s"):format(n, n == 1 and "item" or "items", P.Money(value), unknown and " (some prices unknown)" or "") }
		end
		if waits > 0 then
			lines[#lines + 1] = { ("%sand %d more of your sell list|r"):format(DIM, waits) }
		end
		lines[#lines + 1] = { DIM .. "Counts only bags that take any item.|r" }
		return lines
	end,
	Hint = function()
		return "Click: open your bags."
	end,
	Click = function(_, button)
		if button ~= "LeftButton" then
			return
		elseif ns.Enabled("bags") and type(ns.BagsToggle) == "function" then
			ns.BagsToggle()
		elseif type(_G.ToggleAllBags) == "function" then
			pcall(_G.ToggleAllBags)
		end
	end,
})

function P.Money(copper, size)
	copper = math.max(0, math.floor(copper))
	local currency = type(C_CurrencyInfo) == "table" and not ns.IsSecret(C_CurrencyInfo) and C_CurrencyInfo or nil
	local coins
	if currency and size then
		coins = Ask(currency.GetCoinTextureString, copper, math.floor(size + 0.5))
	elseif currency then
		coins = Ask(currency.GetCoinTextureString, copper)
	end
	if type(coins) == "string" and coins ~= "" then
		return coins
	end
	local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	local parts = {}
	if gold > 0 then
		parts[#parts + 1] = gold .. "g"
	end
	if silver > 0 then
		parts[#parts + 1] = silver .. "s"
	end
	if rest > 0 or #parts == 0 then
		parts[#parts + 1] = rest .. "c"
	end
	return table.concat(parts, " ")
end

local function ClockSetting(name, default)
	local cvars = type(C_CVar) == "table" and not ns.IsSecret(C_CVar) and C_CVar or nil
	local value = Ask(cvars and cvars.GetCVarBool or _G.GetCVarBool, name)
	if type(value) == "boolean" then
		return value
	end
	return default
end

local function Formatted(pattern, fallback, ...)
	if type(pattern) == "string" and not ns.IsSecret(pattern) then
		local ok, text = pcall(string.format, pattern, ...)
		if ok and type(text) == "string" and text ~= "" then
			return text
		end
	end
	return fallback:format(...)
end

local function ClockText(hour, minute)
	if not (ns.Finite(hour) and ns.Finite(minute)) then
		return nil
	end
	hour, minute = math.floor(hour) % 24, math.floor(minute) % 60
	if ClockSetting("timeMgrUseMilitaryTime", true) then
		return Formatted(_G.TIMEMANAGER_TICKER_24HOUR, "%02d:%02d", hour, minute)
	end
	local shown = hour % 12
	shown = shown == 0 and 12 or shown
	if hour < 12 then
		return Formatted(_G.TIME_TWELVEHOURAM, "%d:%02d AM", shown, minute)
	end
	return Formatted(_G.TIME_TWELVEHOURPM, "%d:%02d PM", shown, minute)
end

local function Record()
	local store, key, money = P.Store(true), ns.CharacterKey(), Count((Ask(GetMoney)))
	if not (store and type(key) == "string" and money) then
		return
	end
	local _, class = Ask(UnitClass, "player")
	store.gold[key] = { money = money, class = type(class) == "string" and class or nil }
end

local function Characters()
	local list = {}
	for key, entry in pairs(P.Kept("gold")) do
		if type(key) == "string" and type(entry) == "table" and Count(entry.money) then
			list[#list + 1] = { key = key, money = entry.money, class = entry.class }
		end
	end
	table.sort(list, function(a, b)
		if a.money ~= b.money then
			return a.money > b.money
		end
		return a.key < b.key
	end)
	return list
end

local lastMoney

local function MoneyChanged()
	Record()
	local money = Count((Ask(GetMoney)))
	local mode = ns.TestMode
	if money and lastMoney and money ~= lastMoney and not (mode ~= nil and mode.IsOn() == true) then
		P.Float("gold", money - lastMoney)
	end
	lastMoney = money
end

local function SessionSince()
	local char = ns.Character()
	local began = type(char) == "table" and Count(char.sessionStartAt) or nil
	if not began or type(date) ~= "function" then
		return nil
	end
	local ok, parts = pcall(date, "*t", began)
	return ok and ClockText(Field(parts, "hour"), Field(parts, "min")) or nil
end

local function SessionFromNow()
	local char = ns.Character()
	local money, now = Count((Ask(GetMoney))), Count((Ask(_G.time)))
	if type(char) ~= "table" or not (money and now) then
		return
	end
	char.sessionMoney, char.sessionStartAt = money, now
	print("Flat UI: the gold count of this session starts again now.")
	P.Mark("gold")
end

P.Stream({
	id = "gold", label = "Gold",
	through = true,
	events = { PLAYER_MONEY = MoneyChanged },
	Start = Record,
	Text = function()
		local money = Count((Ask(GetMoney)))
		lastMoney = money
		return money and P.Money(money, P.size) or nil
	end,
	Tip = function()
		Record()
		local realm = Ask(GetRealmName)
		local suffix = type(realm) == "string" and (" - " .. realm) or nil
		local lines, total, list = { title = "Gold" }, 0, Characters()
		for index, entry in ipairs(list) do
			total = total + entry.money
			if index <= MOST then
				local name = entry.key
				if suffix and name:sub(-#suffix) == suffix then
					name = name:sub(1, -#suffix - 1)
				end
				lines[#lines + 1] = { Who(name, entry.class), P.Money(entry.money) }
			end
		end
		More(lines, #list - MOST)
		if #list > 1 then
			lines[#lines + 1] = { " " }
			lines[#lines + 1] = { "Total", P.Money(total) }
		end
		local okSession, session, seconds = pcall(function()
			if type(ns.SessionMoney) == "function" then
				return ns.SessionMoney()
			end
			return nil
		end)
		if okSession and ns.Finite(session) then
			local shown
			if session == 0 then
				shown = DIM .. P.Money(0) .. "|r"
			else
				local hourly = ""
				if ns.Finite(seconds) and seconds >= HOURLY_AFTER then
					hourly = (" (%s an hour)"):format(P.Money(math.abs(session) * 3600 / seconds))
				end
				shown = (session > 0 and (GOOD .. "+") or (BAD .. "-")) .. P.Money(math.abs(session)) .. hourly .. "|r"
			end
			local since = SessionSince()
			if since then
				shown = shown .. DIM .. "  since " .. since .. "|r"
			end
			lines[#lines + 1] = { " " }
			lines[#lines + 1] = { "This session", shown }
		end
		return lines
	end,
	Hint = function()
		return "Ctrl-click: count this session from now."
	end,
	Click = function(_, button)
		if button == "LeftButton" and Ctrl() then
			SessionFromNow()
		end
	end,
})

local function Forgettable()
	local list = Characters()
	table.sort(list, function(a, b)
		return a.key < b.key
	end)
	return list
end

function ns.DataPanelGoldLines()
	local rows = {}
	for index, entry in ipairs(Forgettable()) do
		rows[#rows + 1] = { index, ("%s, %s"):format(entry.key, P.Money(entry.money)) }
	end
	return rows
end

function ns.DataPanelGoldForget(index)
	local entry = type(index) == "number" and Forgettable()[index]
	if not entry then
		return false
	end
	P.Kept("gold")[entry.key] = nil
	P.Mark("gold")
	return true, ("Flat UI: the gold of %s is forgotten."):format(entry.key)
end

local function Worn(percent)
	local whole = math.floor(percent + 0.5)
	return whole > 80 and GOOD or whole > 50 and WARN or BAD
end

local function Durability()
	if type(GetInventoryItemDurability) ~= "function" then
		return nil
	end
	local items, now, most, broken, zero = {}, 0, 0, 0, 0
	for slot = 1, 19 do
		local hidden, current, maximum = Read(GetInventoryItemDurability, slot)
		current, maximum = Count(current), Count(maximum)
		if hidden then
			return nil
		elseif current and maximum and maximum > 0 then
			current = math.min(current, maximum)
			now, most = now + current, most + maximum
			items[#items + 1] = { slot = slot, percent = current / maximum * 100 }
			if Worn(current / maximum * 100) == BAD then
				broken = broken + 1
			end
			if current <= 0 then
				zero = zero + 1
			end
		end
	end
	table.sort(items, function(a, b)
		if a.percent ~= b.percent then
			return a.percent < b.percent
		end
		return a.slot < b.slot
	end)
	return most > 0 and now / most * 100 or 100, items, broken, zero
end

local function NoWear()
	local kinds = Field(_G.Enum, "GameRule")
	local rule = Field(kinds, "RepairArmorDisabled")
	local active = Field(_G.C_GameRules, "IsGameRuleActive")
	if rule == nil or type(active) ~= "function" then
		return false
	end
	return Ask(active, rule) == true
end

local function RepairCost(items)
	local call = Field(_G.C_TooltipInfo, "GetInventoryItem")
	if type(call) ~= "function" or P.InCombat() then
		return nil
	end
	local total = 0
	for _, item in ipairs(items) do
		if item.percent < 100 then
			local cost = Field((Ask(call, "player", item.slot)), "repairCost")
			if ns.Finite(cost) and cost > 0 then
				total = total + cost
			end
		end
	end
	return total > 0 and total or nil
end

P.Stream({
	id = "durability", label = "Durability", sample = "Durability 100%", idle = "gear does not wear here",
	events = { UPDATE_INVENTORY_DURABILITY = true, PLAYER_EQUIPMENT_CHANGED = true },
	Text = function()
		if NoWear() then
			return nil
		end
		local percent, _, broken, zero = Durability()
		if not percent then
			return nil
		end
		local text = Labelled("Durability", ("%s%d%%|r"):format(Worn(percent), math.floor(percent + 0.5)))
		if zero > 0 then
			return ("%s  %s%d broken|r"):format(text, BAD, zero)
		end
		return broken > 0 and ("%s  %s%d|r%s at 50%% or less|r"):format(text, BAD, broken, DIM) or text
	end,
	Tip = function()
		if NoWear() then
			return { title = "Durability", { DIM .. "Gear does not wear out here.|r" } }
		end
		local percent, items, _, zero = Durability()
		if not percent then
			return { title = "Durability", UNSAID }
		end
		local lines = { title = "Durability" }
		if zero > 0 then
			lines[#lines + 1] = { ("%s%d %s broken: no stats until repaired|r"):format(BAD, zero, zero == 1 and "item" or "items") }
		end
		for _, item in ipairs(items) do
			local link = Text((Ask(GetInventoryItemLink, "player", item.slot)))
			lines[#lines + 1] = { link or SLOT_NAMES[item.slot] or ("Slot %d"):format(item.slot),
				("%s%d%%|r"):format(Worn(item.percent), math.floor(item.percent + 0.5)) }
		end
		if #items == 0 then
			lines[#lines + 1] = { DIM .. "Nothing you wear wears out.|r" }
		else
			lines[#lines + 1] = { " " }
			lines[#lines + 1] = { "All items", ("%s%d%%|r"):format(Worn(percent), math.floor(percent + 0.5)) }
			local cost = RepairCost(items)
			if cost then
				lines[#lines + 1] = { "Repair cost", P.Money(cost) }
			end
		end
		return lines
	end,
	Hint = function()
		return WindowHint("Click: open the character window.")
	end,
	Click = function(_, button)
		if button == "LeftButton" then
			Toggle("ToggleCharacter", "Flat UI: the character window opens when the fight ends.", "PaperDollFrame")
		end
	end,
})

local AMMO = { slot = 0, ranged = 18, weapon = 2, projectile = 6, fires = { [2] = 2, [18] = 2, [3] = 3 }, thrown = 16, shard = 6265,
	quiver = { 1, 2 }, soul = { 4 }, low = 200, thrownLow = 20, worn = 20 }

local function FamilySpace(bits)
	local bags = type(C_Container) == "table" and C_Container or nil
	local slots = bags and bags.GetContainerNumSlots or _G.GetContainerNumSlots
	local empties = bags and bags.GetContainerNumFreeSlots or _G.GetContainerNumFreeSlots
	local last = math.min(Count(NUM_TOTAL_EQUIPPED_BAG_SLOTS) or Count(NUM_BAG_SLOTS) or 4, 12)
	local free, total = 0, 0
	for bag = 1, last do
		local hidden, size = Read(slots, bag)
		size = Count(size)
		if hidden then
			return nil
		elseif size and size > 0 then
			local withheld, empty, family = Read(empties, bag)
			empty, family = Count(empty), Count(family)
			if withheld then
				return nil
			end
			local match = false
			for _, bit in ipairs(bits) do
				match = match or (family ~= nil and math.floor(family / bit) % 2 == 1)
			end
			if match and empty then
				free, total = free + math.min(empty, size), total + size
			end
		end
	end
	return free, total
end

local function FamilyLine(label, bits)
	local free, total = FamilySpace(bits)
	if free and total > 0 then
		return { label, ("%d of %d free"):format(free, total) }
	end
	return nil
end

local function Least(path, fallback)
	local value = ns.Get(path)
	return ns.Finite(value) and value >= 0 and value or fallback
end

local function Low(count, least)
	return count <= 0 and BAD or (least > 0 and count <= least) and WARN or ""
end

local function Ammunition()
	local hidden, weapon = Read(GetInventoryItemID, "player", AMMO.ranged)
	local items = type(C_Item) == "table" and C_Item or nil
	if hidden or not Count(weapon) or not (items and type(items.GetItemInfoInstant) == "function") then
		return nil
	end
	local ok, _, _, _, _, _, class, subclass = pcall(items.GetItemInfoInstant, weapon)
	if not ok or ns.IsSecret(class) or ns.IsSecret(subclass) or class ~= AMMO.weapon then
		return nil
	end
	if subclass == AMMO.thrown then
		local now, most = Ask(GetInventoryItemDurability, AMMO.ranged)
		if ns.Finite(now) and ns.Finite(most) and most > 0 then
			return { thrown = true, percent = math.max(0, now) * 100 / most }
		end
		local count = Count((Ask(GetInventoryItemCount, "player", AMMO.ranged)))
		return count and { thrown = true, count = count } or nil
	end
	local fires = AMMO.fires[subclass]
	if not fires then
		return nil
	end
	local withheld, ammo = Read(GetInventoryItemID, "player", AMMO.slot)
	if withheld then
		return nil
	elseif not Count(ammo) then
		return { fired = true, count = 0 }
	end
	local okAmmo, _, _, _, _, _, ammoClass, ammoSub = pcall(items.GetItemInfoInstant, ammo)
	if okAmmo and not ns.IsSecret(ammoClass) and not ns.IsSecret(ammoSub) and (ammoClass ~= AMMO.projectile or ammoSub ~= fires) then
		return { fired = true, ammo = ammo, wrong = true, count = 0 }
	end
	local bags = Count((Ask(items.GetItemCount, ammo)))
	local held = Count((Ask(GetInventoryItemCount, "player", AMMO.slot)))
	local count = (bags and held) and math.max(bags, held) or bags or held
	return count and { fired = true, ammo = ammo, count = count } or nil
end

P.Stream({
	id = "ammo", label = "Ammunition", sample = "Ammo 8,888", idle = "no bow, crossbow, gun or thrown weapon",
	events = { BAG_UPDATE_DELAYED = true, PLAYER_EQUIPMENT_CHANGED = true, UNIT_INVENTORY_CHANGED = true },
	Text = function()
		local ammo = Ammunition()
		if not ammo then
			return nil
		elseif ammo.percent then
			local colour = ammo.percent <= 0 and BAD or ammo.percent <= AMMO.worn and WARN or ""
			return Labelled("Thrown", ("%s%d%%%s"):format(colour, math.floor(ammo.percent + 0.5), colour ~= "" and "|r" or ""))
		end
		local least = ammo.thrown and Least("trackers.thrownMin", AMMO.thrownLow) or Least("trackers.ammoMin", AMMO.low)
		local colour = Low(ammo.count, least)
		return Labelled("Ammo", ("%s%s%s"):format(colour, Grouped(ammo.count), colour ~= "" and "|r" or ""))
	end,
	Tip = function()
		local ammo = Ammunition()
		if not ammo then
			return { title = "Ammunition", { DIM .. "No bow, crossbow, gun or thrown weapon in your ranged slot.|r" } }
		end
		local lines = { title = "Ammunition" }
		if ammo.percent then
			lines[#lines + 1] = { Text((Ask(GetInventoryItemLink, "player", AMMO.ranged))) or "Thrown weapon", ("%d%%"):format(math.floor(ammo.percent + 0.5)) }
			lines[#lines + 1] = { DIM .. "It wears out as you throw it; a merchant who repairs mends it.|r" }
			return lines
		end
		local least
		if ammo.thrown then
			least = Least("trackers.thrownMin", AMMO.thrownLow)
			lines[#lines + 1] = { Text((Ask(GetInventoryItemLink, "player", AMMO.ranged))) or "Thrown weapon", Grouped(ammo.count) }
		else
			least = Least("trackers.ammoMin", AMMO.low)
			local link = ammo.ammo and Text((Ask(GetInventoryItemLink, "player", AMMO.slot))) or nil
			if not ammo.ammo then
				lines[#lines + 1] = { BAD .. "No arrows or bullets in the ammunition slot.|r" }
			elseif ammo.wrong then
				lines[#lines + 1] = { link or "Ammunition", BAD .. "Does not fit this weapon|r" }
			else
				lines[#lines + 1] = { link or "Ammunition" }
				lines[#lines + 1] = { "In your bags", Grouped(ammo.count) }
			end
			lines[#lines + 1] = FamilyLine("Quiver or ammo pouch", AMMO.quiver)
		end
		lines[#lines + 1] = { " " }
		local row = ammo.thrown and "Thrown weapon minimum" or "Ammunition minimum"
		lines[#lines + 1] = { DIM .. (least > 0 and ("Low at %s: %s on the Trackers page."):format(Grouped(least), row)
			or ("Never low: %s is 0 on the Trackers page."):format(row)) .. "|r" }
		return lines
	end,
})

local function Warlock()
	local _, class = Ask(UnitClass, "player")
	return class == "WARLOCK"
end

P.Stream({
	id = "shards", label = "Soul shards", sample = "Shards 88", idle = "only for a warlock",
	events = { BAG_UPDATE_DELAYED = true },
	Text = function()
		local count = Warlock() and type(C_Item) == "table" and Count((Ask(C_Item.GetItemCount, AMMO.shard))) or nil
		if not count then
			return nil
		end
		local colour = count == 0 and BAD or ""
		return Labelled("Shards", ("%s%d%s"):format(colour, count, colour ~= "" and "|r" or ""))
	end,
	Tip = function()
		local count = Warlock() and type(C_Item) == "table" and Count((Ask(C_Item.GetItemCount, AMMO.shard))) or nil
		if not count then
			return { title = "Soul shards", { DIM .. (Warlock() and "The game does not say now." or "Only a warlock keeps soul shards.") .. "|r" } }
		end
		local lines = { title = "Soul shards", { "In your bags", count == 0 and (BAD .. "0|r") or Grouped(count) } }
		lines[#lines + 1] = FamilyLine("Soul bags", AMMO.soul)
		return lines
	end,
})

local function HearthLeft()
	local hidden, start, duration = false, nil, nil
	if type(C_Container) == "table" then
		hidden, start, duration = Read(C_Container.GetItemCooldown, HEARTHSTONE)
	end
	if not hidden and start == nil and type(C_Item) == "table" then
		hidden, start, duration = Read(C_Item.GetItemCooldown, HEARTHSTONE)
	end
	if hidden then
		return nil
	elseif not (ns.Finite(start) and ns.Finite(duration)) or start <= 0 or duration <= SHORT then
		return 0
	end
	return math.max(0, start + duration - P.Now())
end

local function HearthCount()
	if type(C_Item) == "table" then
		return Count((Ask(C_Item.GetItemCount, HEARTHSTONE))) or 0
	end
	return Count((Ask(_G.GetItemCount, HEARTHSTONE))) or 0
end

local hearthLeft = 0

P.Stream({
	id = "hearth", label = "Hearthstone", idle = "no hearthstone bound",
	events = { HEARTHSTONE_BOUND = true, BAG_UPDATE_COOLDOWN = true, BAG_UPDATE_DELAYED = true },
	every = function()
		return hearthLeft > 0 and 1 or nil
	end,
	live = true,
	secure = function()
		return HearthCount() > 0 and ("item:" .. HEARTHSTONE) or nil
	end,
	Text = function()
		local place = Text((Ask(GetBindLocation)))
		hearthLeft = HearthCount() > 0 and HearthLeft() or 0
		if not place then
			return nil
		end
		local icon = type(C_Item) == "table" and Count((Ask(C_Item.GetItemIconByID, HEARTHSTONE))) or nil
		local text = ("|T%d:0|t %s"):format(icon and icon > 0 and icon or HEARTHSTONE_ICON, place)
		if hearthLeft > 0 then
			text = text .. " " .. DIM .. P.Time(hearthLeft) .. "|r"
		end
		return text
	end,
	Tip = function()
		local lines = { title = "Hearthstone", { "Bound to", Text((Ask(GetBindLocation))) or "Unknown" } }
		if HearthCount() > 0 then
			local left = HearthLeft()
			lines[#lines + 1] = { "Cooldown", not left and "Unknown" or left > 0 and P.Time(left) or (GOOD .. "Ready|r") }
		else
			lines[#lines + 1] = { DIM .. "Not in your bags.|r" }
		end
		return lines
	end,
	Hint = function()
		if HearthCount() == 0 then
			return nil
		end
		return P.InCombat() and "Out of a fight, click: use your Hearthstone." or "Click: use your Hearthstone."
	end,
})

local function Position()
	local maps = type(C_Map) == "table" and C_Map or nil
	local map = maps and Count((Ask(maps.GetBestMapForUnit, "player")))
	if not map then
		return nil
	end
	local position = Ask(maps.GetPlayerMapPosition, map, "player")
	local x, y = Field(position, "x"), Field(position, "y")
	if not (ns.Finite(x) and ns.Finite(y)) or (x == 0 and y == 0) then
		return nil
	end
	return x * 100, y * 100
end

P.Stream({
	id = "coords", label = "Coordinates", sample = "88.8, 88.8", idle = "none here",
	events = { ZONE_CHANGED_NEW_AREA = true, ZONE_CHANGED = true, ZONE_CHANGED_INDOORS = true },
	every = 0.5,
	live = true,
	Text = function()
		local x, y = Position()
		return x and ("%.1f, %.1f"):format(x, y) or nil
	end,
	Tip = function()
		local x, y = Position()
		local zone, sub = Text((Ask(GetZoneText))), Text((Ask(GetSubZoneText)))
		local lines = { title = zone or "Coordinates" }
		if sub and sub ~= zone then
			lines[#lines + 1] = { DIM .. sub .. "|r" }
		end
		lines[#lines + 1] = { "Coordinates", x and ("%.1f, %.1f"):format(x, y) or "None here" }
		return lines
	end,
	Hint = function()
		return WindowHint("Click: open the world map.") .. " Shift-click: put this in chat."
	end,
	Click = function(_, button)
		if button ~= "LeftButton" then
			return
		elseif not Shift() then
			Toggle("ToggleWorldMap", "Flat UI: the map opens when the fight ends.")
			return
		elseif type(ns.PutInChat) ~= "function" then
			return
		end
		local x, y = Position()
		if x then
			local zone = Text((Ask(GetZoneText)))
			local shown = ("%.1f, %.1f"):format(x, y)
			ns.PutInChat(zone and (zone .. " " .. shown) or shown)
		end
	end,
})

local ZONE_STATES = {
	sanctuary = { "|cff68ccef", "Sanctuary" },
	friendly = { "|cff19ff19", "Friendly territory" },
	hostile = { "|cffff1919", "Hostile territory" },
	contested = { "|cffffb200", "Contested territory" },
	arena = { "|cffff1919", "Free-for-all territory" },
	combat = { "|cffff1919", "Combat zone" },
}

local function ZoneState()
	local pvp = type(C_PvP) == "table" and not ns.IsSecret(C_PvP) and C_PvP.GetZonePVPInfo or nil
	local kind = Ask(type(pvp) == "function" and pvp or _G.GetZonePVPInfo)
	return type(kind) == "string" and ZONE_STATES[kind] or nil
end

local function Place()
	local zone, sub = Text((Ask(GetZoneText))), Text((Ask(GetSubZoneText)))
	return zone, sub ~= zone and sub or nil
end

P.Stream({
	id = "zone", label = "Zone", sample = "Goldshire", idle = "no zone name here",
	events = { ZONE_CHANGED_NEW_AREA = true, ZONE_CHANGED = true, ZONE_CHANGED_INDOORS = true },
	live = true,
	Text = function()
		local zone, sub = Place()
		local name = sub or zone
		if not name then
			return nil
		end
		local state = ZoneState()
		return state and (state[1] .. name .. "|r") or name
	end,
	Tip = function()
		local zone, sub = Place()
		local state = ZoneState()
		local lines = { title = zone or "Zone" }
		if sub then
			lines[#lines + 1] = { DIM .. sub .. "|r" }
		end
		if state then
			lines[#lines + 1] = { "State", state[1] .. state[2] .. "|r" }
		end
		local x, y = Position()
		lines[#lines + 1] = { "Coordinates", x and ("%.1f, %.1f"):format(x, y) or "None here" }
		return lines
	end,
	Hint = function()
		return WindowHint("Click: open the world map.") .. " Shift-click: put this in chat."
	end,
	Click = function(_, button)
		if button ~= "LeftButton" then
			return
		elseif not Shift() then
			Toggle("ToggleWorldMap", "Flat UI: the map opens when the fight ends.")
			return
		elseif type(ns.PutInChat) ~= "function" then
			return
		end
		local zone, sub = Place()
		local name = sub and zone and (sub .. ", " .. zone) or zone or sub
		if not name then
			return
		end
		local x, y = Position()
		ns.PutInChat(x and ("%s %.1f, %.1f"):format(name, x, y) or name)
	end,
})

local function LocalClock()
	if type(date) ~= "function" then
		return nil
	end
	local ok, parts = pcall(date, "*t")
	return ok and ClockText(Field(parts, "hour"), Field(parts, "min")) or nil
end

local function RealmClock()
	local hour, minute = Ask(GetGameTime)
	return ClockText(hour, minute)
end

P.Stream({
	id = "clock", label = "Time", sample = "88:88 PM",
	every = 1,
	live = true,
	Text = function()
		if ClockSetting("timeMgrUseLocalTime", true) then
			return LocalClock()
		end
		return RealmClock()
	end,
	Tip = function()
		local lines = { title = "Time", { "Local time", LocalClock() or "Unknown" }, { "Realm time", RealmClock() or "Unknown" } }
		local session = Ask(_G.GetSessionTime)
		if ns.Finite(session) and session >= 0 then
			lines[#lines + 1] = { "This session", P.Time(session) }
		end
		lines[#lines + 1] = { DIM .. "Local or realm time and 12 or 24 hours follow the game's clock settings.|r" }
		return lines
	end,
	Hint = function()
		return WindowHint("Click: stopwatch and alarm. Shift-click: calendar.")
	end,
	Click = function(_, button)
		if button == "LeftButton" then
			if Shift() then
				Toggle("ToggleCalendar", "Flat UI: the calendar opens when the fight ends.")
			else
				Toggle("ToggleTimeManager", "Flat UI: the stopwatch opens when the fight ends.")
			end
		end
	end,
})

local function QuestLog()
	local log = _G.C_QuestLog
	return type(log) == "table" and not ns.IsSecret(log) and type(log.GetNumQuestLogEntries) == "function" and log or nil
end

local function EachQuest(log, fn)
	local entries = type(log.GetInfo) == "function" and Count((Ask(log.GetNumQuestLogEntries))) or nil
	if not entries then
		return nil
	end
	local count, seen = 0, {}
	for index = 1, math.min(entries, 100) do
		local info = Ask(log.GetInfo, index)
		local id = Count(Field(info, "questID"))
		if id and id > 0 and not seen[id] and Field(info, "isHeader") ~= true and Field(info, "isHidden") ~= true then
			seen[id], count = true, count + 1
			if fn then
				fn(id)
			end
		end
	end
	return count
end

local function Quests()
	local log = QuestLog()
	if not log then
		return nil
	end
	local hidden, _, quests = Read(log.GetNumQuestLogEntries)
	if hidden then
		return nil
	end
	quests = Count(quests) or EachQuest(log)
	if not quests then
		return nil
	end
	local _, most = Read(log.GetMaxNumQuestsCanAccept)
	most = Count(most)
	if not (most and most > 0) then
		most = Count(_G.MAX_QUESTLOG_QUESTS) or Count(_G.MAX_QUESTS)
	end
	return quests, most and most > 0 and most or nil
end

local function ReadyQuests()
	local log = QuestLog()
	if not (log and type(log.IsComplete) == "function") then
		return nil
	end
	local ready = 0
	local walked = EachQuest(log, function(id)
		if Ask(log.IsComplete, id) == true then
			ready = ready + 1
		end
	end)
	return walked and ready or nil
end

P.Stream({
	id = "quests", label = "Quest log", sample = "Quests 88/88",
	events = { QUEST_LOG_UPDATE = true },
	Text = function()
		local quests, most = Quests()
		if not quests then
			return nil
		elseif not most then
			return Labelled("Quests", quests)
		end
		local full = quests >= most
		return Labelled("Quests", ("%s%d/%d%s"):format(full and BAD or "", quests, most, full and "|r" or ""))
	end,
	Tip = function()
		local quests, most = Quests()
		if not quests then
			return { title = "Quest log", UNSAID }
		end
		local lines = { title = "Quest log", { "Quests", most and ("%d of %d"):format(quests, most) or quests } }
		if most and quests >= most then
			lines[#lines + 1] = { BAD .. "Your quest log is full.|r" }
		end
		local ready = ReadyQuests()
		if ready then
			lines[#lines + 1] = { "Ready to hand in", ready > 0 and (GOOD .. ready .. "|r") or ready }
		end
		local xp = type(ns.XpQuestReady) == "function" and ns.XpQuestReady() or 0
		if ready and ready > 0 and ns.Finite(xp) and xp > 0 then
			xp = math.floor(xp)
			lines[#lines + 1] = { "Their experience", Text((Ask(_G.BreakUpLargeNumbers, xp))) or tostring(xp) }
		end
		return lines
	end,
	Hint = function()
		return WindowHint("Click: open the quest log.")
	end,
	Click = function(_, button)
		if button == "LeftButton" then
			Toggle("ToggleQuestLog", "Flat UI: the quest log opens when the fight ends.")
		end
	end,
})

local RESTED = "|cff6fa8ff"

local function Experience()
	local can, shown = Field(_G.GameRulesUtil, "CanShowExperienceBar"), nil
	if type(can) == "function" then
		shown = Ask(can)
	end
	if type(shown) ~= "boolean" then
		local level, top = Count((Ask(UnitLevel, "player"))), Count((Ask(_G.GetMaxPlayerLevel)))
		shown = Ask(_G.IsXPUserDisabled) ~= true and not (level and top and top > 0 and level >= top)
	end
	if shown ~= true then
		return nil
	end
	local value, total = Count((Ask(UnitXP, "player"))), Count((Ask(UnitXPMax, "player")))
	if not (value and total and total > 0) then
		return nil
	end
	return math.min(value, total), total, Count((Ask(GetXPExhaustion))) or 0
end

local function XpChatLine()
	local value, total = Experience()
	if not value then
		return nil
	end
	local line = ("%s / %s (%d%%)"):format(Grouped(value), Grouped(total), math.floor(value * 100 / total))
	local level = Count((Ask(UnitLevel, "player")))
	if level then
		line = ("Level %d: %s"):format(level, line)
	end
	local eta = type(ns.XpStatsText) == "function" and Text(ns.XpStatsText("time")) or nil
	return eta and (line .. ", " .. eta) or line
end

P.Stream({
	id = "xp", label = "Experience", sample = "XP 88.8%  +88%", idle = "at the top level or with experience off",
	events = { PLAYER_XP_UPDATE = true, UPDATE_EXHAUSTION = true, PLAYER_LEVEL_UP = true, PLAYER_UPDATE_RESTING = true, ENABLE_XP_GAIN = true,
		DISABLE_XP_GAIN = true },
	Text = function()
		local value, total, rest = Experience()
		if not value then
			return nil
		end
		local text = Labelled("XP", ("%.1f%%"):format(value / total * 100))
		local share = math.floor(rest / total * 100 + 0.5)
		return share > 0 and ("%s  %s+%d%%|r"):format(text, RESTED, share) or text
	end,
	Tip = function()
		local value, total, rest = Experience()
		if not value then
			return { title = "Experience", { DIM .. "No experience to gain now.|r" } }
		end
		local lines = { title = "Experience", { "Experience", ("%s / %s (%.1f%%)"):format(Grouped(value), Grouped(total), value / total * 100) },
			{ "To level", Grouped(total - value) } }
		if rest > 0 then
			lines[#lines + 1] = { "Rested", ("%s%s (%d%%)|r"):format(RESTED, Grouped(rest), math.floor(rest / total * 100 + 0.5)) }
		end
		local ready = type(ns.XpQuestReady) == "function" and ns.XpQuestReady() or 0
		if ns.Finite(ready) and ready > 0 then
			lines[#lines + 1] = { "Quests ready to hand in", GOOD .. Grouped(ready) .. "|r" }
		end
		local eta = type(ns.XpStatsText) == "function" and Text(ns.XpStatsText("time")) or nil
		local pace = type(ns.XpStatsText) == "function" and Text(ns.XpStatsText("rate")) or nil
		if eta then
			lines[#lines + 1] = { "Time to level", (eta:gsub(" to level$", "")) }
		end
		if pace then
			lines[#lines + 1] = { "Pace", pace }
		end
		return lines
	end,
	Hint = function()
		return "Shift-click: put this in chat."
	end,
	Click = function(_, button)
		if button == "LeftButton" and Shift() and type(ns.PutInChat) == "function" then
			local line = XpChatLine()
			if line then
				ns.PutInChat(line)
			end
		end
	end,
})

local LATER_REP = "Flat UI: your reputations open when the fight ends."

local function Reputation()
	local api = _G.C_Reputation
	api = type(api) == "table" and not ns.IsSecret(api) and api or nil
	local data, bar
	local okNow, id = pcall(function()
		return type(ns.XpRepNow) == "function" and ns.XpRepNow() or nil
	end)
	if okNow and Count(id) and id > 0 and api then
		data = Ask(api.GetFactionDataByID, id)
		bar = type(data) == "table"
	end
	if type(data) ~= "table" and type(ns.ErrandsRepFollowed) == "function" then
		local okFollow, followed = pcall(ns.ErrandsRepFollowed)
		data = okFollow and P.Plain(followed) or nil
	end
	if type(data) ~= "table" and api then
		data = Ask(api.GetWatchedFactionData)
	end
	if type(data) ~= "table" then
		return nil
	end
	local name, faction, reaction = Text(Field(data, "name")), Count(Field(data, "factionID")), Count(Field(data, "reaction"))
	local low, high, value = Field(data, "currentReactionThreshold"), Field(data, "nextReactionThreshold"), Field(data, "currentStanding")
	if not (name and faction and faction > 0 and ns.Finite(low) and ns.Finite(high) and ns.Finite(value)) then
		return nil
	end
	local total = high - low
	local capped = total <= 0 or (reaction ~= nil and reaction >= 8)
	return { name = name, reaction = reaction, total = math.max(total, 0), value = math.max(0, math.min(value - low, math.max(total, 0))),
		capped = capped, bar = bar == true }
end

local function Standing(reaction)
	return reaction and Text(P.Plain(_G["FACTION_STANDING_LABEL" .. reaction])) or nil
end

local function StandingText(rep)
	local text = Standing(rep.reaction) or "Unknown"
	local colour = rep.reaction and Field(_G.FACTION_BAR_COLORS, rep.reaction)
	local r, g, b = Field(colour, "r"), Field(colour, "g"), Field(colour, "b")
	if ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		return P.Hex(r, g, b) .. text .. "|r"
	end
	return text
end

local function RepShare(rep)
	return rep.total > 0 and math.floor(rep.value * 100 / rep.total) or 100
end

local function RepChatLine()
	local rep = Reputation()
	if not rep then
		return nil
	end
	local standing = Standing(rep.reaction) or "Unknown"
	if rep.capped then
		return ("%s: %s"):format(rep.name, standing)
	end
	return ("%s: %s %s / %s (%d%%)"):format(rep.name, standing, Grouped(rep.value), Grouped(rep.total), RepShare(rep))
end

P.Stream({
	id = "rep", label = "Reputation", sample = "Stormwind Revered 88%", idle = "no faction to show",
	events = { UPDATE_FACTION = true },
	Text = function()
		local rep = Reputation()
		if not rep then
			return nil
		end
		local text = ("%s %s"):format(rep.name, StandingText(rep))
		return rep.capped and text or ("%s %d%%"):format(text, RepShare(rep))
	end,
	Tip = function()
		local rep = Reputation()
		if not rep then
			return { title = "Reputation", { DIM .. "No faction is watched. Tick Show as Experience Bar for one in your reputations.|r" } }
		end
		local lines = { title = rep.name, { "Standing", StandingText(rep) } }
		if not rep.capped then
			lines[#lines + 1] = { "Reputation", ("%s / %s (%d%%)"):format(Grouped(rep.value), Grouped(rep.total), RepShare(rep)) }
			local following = Standing(rep.reaction and rep.reaction + 1)
			lines[#lines + 1] = { following and ("To " .. following) or "To the next standing", Grouped(rep.total - rep.value) }
		end
		if rep.bar and type(ns.XpStatsRepText) == "function" then
			local pace, eta = Text(ns.XpStatsRepText("rate")), Text(ns.XpStatsRepText("time"))
			if pace then
				lines[#lines + 1] = { "Pace", pace }
			end
			if eta then
				lines[#lines + 1] = { "Next standing in", (eta:gsub(" to next standing$", "")) }
			end
		end
		return lines
	end,
	Hint = function()
		return WindowHint("Click: open your reputations.") .. " Shift-click: put this in chat."
	end,
	Click = function(_, button)
		if button ~= "LeftButton" then
			return
		elseif Shift() then
			local line = type(ns.PutInChat) == "function" and RepChatLine() or nil
			if line then
				ns.PutInChat(line)
			end
			return
		end
		Toggle("ToggleCharacter", LATER_REP, "ReputationFrame")
	end,
})

local function Latency()
	local _, _, home, world = Ask(GetNetStats)
	return Count(home), Count(world)
end

local memory

local function Memory(fresh)
	if fresh and not P.InCombat() and type(UpdateAddOnMemoryUsage) == "function" and pcall(UpdateAddOnMemoryUsage) then
		local kb = Ask(GetAddOnMemoryUsage, ADDON_NAME)
		memory = ns.Finite(kb) and kb >= 0 and kb or memory
	end
	if not memory then
		return nil
	end
	return memory >= 1024 and ("%.1f MB"):format(memory / 1024) or ("%d KB"):format(math.floor(memory + 0.5))
end

local PERF = { GOOD, WARN, BAD }

local function Perf(kind, value, text)
	text = text or tostring(value)
	local code = ns.Get("datapanels.perfColour") == true and type(ns.PerfColour) == "function" and ns.PerfColour(kind, value, PERF) or nil
	return code and (code .. text .. "|r") or text
end

P.Stream({
	id = "fps", label = "Frame rate and latency", sample = "888 fps  888 ms",
	every = 1,
	live = true,
	Text = function()
		local rate = Ask(GetFramerate)
		local home, world = Latency()
		local parts = {}
		if ns.Finite(rate) and rate >= 0 then
			parts[#parts + 1] = Perf("fps", math.floor(rate + 0.5)) .. DIM .. " fps|r"
		end
		if home or world then
			parts[#parts + 1] = Perf("ms", math.max(home or 0, world or 0)) .. DIM .. " ms|r"
		end
		return #parts > 0 and table.concat(parts, "  ") or nil
	end,
	Tip = function(fresh)
		local rate = Ask(GetFramerate)
		local home, world = Latency()
		local lines = { title = "Frame rate and latency" }
		if ns.Finite(rate) and rate >= 0 then
			lines[#lines + 1] = { "Frame rate", Perf("fps", rate, ("%.1f"):format(rate)) .. " fps" }
		end
		lines[#lines + 1] = { "Home latency", home and (Perf("ms", home) .. " ms") or "Unknown" }
		lines[#lines + 1] = { "World latency", world and (Perf("ms", world) .. " ms") or "Unknown" }
		local used = Memory(fresh)
		if used then
			lines[#lines + 1] = { "Flat UI memory", used }
		end
		return lines
	end,
})

local function Friendly()
	local list = _G.C_FriendList
	return type(list) == "table" and not ns.IsSecret(list) and list or nil
end

local function FriendCount()
	local list = Friendly()
	if not list and type(BNGetNumFriends) ~= "function" then
		return nil
	end
	local hidden, _, online = Read(BNGetNumFriends)
	if hidden then
		return nil
	end
	local count = Count(online) or 0
	if list then
		local withheld, legacy = Read(list.IsLegacyFriendSystemEnabled)
		local unsaid, characters = Read(list.GetNumOnlineFriends)
		if withheld or (legacy ~= false and unsaid) then
			return nil
		elseif legacy ~= false then
			count = count + (Count(characters) or 0)
		end
	end
	return count
end

local function FriendLines()
	local found, seen = {}, {}
	local list = Friendly()
	for index = 1, list and Count((Ask(list.GetNumFriends))) or 0 do
		local info = Ask(list.GetFriendInfoByIndex, index)
		local name = Text(Field(info, "name"))
		if name and Field(info, "connected") == true and not seen[name] then
			seen[name] = true
			found[#found + 1] = { Who(name, ClassFile(Field(info, "className")), Field(info, "level")), Text(Field(info, "area")) or "" }
		end
	end
	local battleNet = _G.C_BattleNet
	local total = Count((Ask(BNGetNumFriends))) or 0
	for index = 1, type(battleNet) == "table" and not ns.IsSecret(battleNet) and total or 0 do
		local account = Ask(battleNet.GetFriendAccountInfo, index)
		local game = Field(account, "gameAccountInfo")
		if Field(game, "isOnline") == true then
			local character = Text(Field(game, "characterName"))
			local label = Text(Field(account, "accountName")) or Text(Field(account, "battleTag")) or "Battle.net"
			if character and Field(game, "clientProgram") == (_G.BNET_CLIENT_WOW or "WoW") then
				if not seen[character] then
					seen[character] = true
					found[#found + 1] = { Who(character, Field(game, "classFilename") or ClassFile(Field(game, "className")), Field(game, "characterLevel")),
						Text(Field(game, "areaName")) or label }
				end
			else
				found[#found + 1] = { label, Text(Field(game, "richPresence")) or "Battle.net" }
			end
		end
	end
	return found
end

P.Stream({
	id = "friends", label = "Friends online", sample = "Friends 888",
	events = { FRIENDLIST_UPDATE = true, BN_FRIEND_ACCOUNT_ONLINE = true, BN_FRIEND_ACCOUNT_OFFLINE = true, BN_FRIEND_INFO_CHANGED = true,
		BN_CONNECTED = true, BN_DISCONNECTED = true },
	Text = function()
		local count = FriendCount()
		return count and Labelled("Friends", count) or nil
	end,
	Tip = function()
		local found = FriendLines()
		local lines = { title = "Friends online" }
		for index = 1, math.min(#found, MOST) do
			lines[#lines + 1] = found[index]
		end
		More(lines, #found - MOST)
		if #found == 0 then
			lines[#lines + 1] = { DIM .. "None of your friends is online.|r" }
		end
		return lines
	end,
	Hint = function()
		return WindowHint("Click: open your friends list.")
	end,
	Click = function(_, button)
		if button == "LeftButton" then
			Toggle("ToggleFriendsFrame", "Flat UI: your friends list opens when the fight ends.", Count(_G.FRIEND_TAB_FRIENDS) or 1)
		end
	end,
})

local asked = -math.huge

local function AskRoster(always)
	if not P.used.guild or Ask(IsInGuild) ~= true then
		return
	end
	local total = Count((Ask(GetNumGuildMembers)))
	local now = P.Now()
	if (always or not total or total == 0) and now - asked >= ROSTER_EVERY then
		asked = now
		local info = _G.C_GuildInfo
		local request = type(info) == "table" and not ns.IsSecret(info) and info.GuildRoster or _G.GuildRoster
		Ask(request)
	end
end

P.Stream({
	id = "guild", label = "Guild online", sample = "Guild 888",
	events = {
		GUILD_ROSTER_UPDATE = function(canRequest)
			if not ns.IsSecret(canRequest) and canRequest == true then
				AskRoster(true)
			end
		end,
		PLAYER_GUILD_UPDATE = function()
			AskRoster(false)
		end,
	},
	Start = function()
		AskRoster(false)
	end,
	Text = function()
		local hidden, member = Read(IsInGuild)
		if hidden or type(IsInGuild) ~= "function" then
			return nil
		elseif member ~= true then
			return DIM .. "No guild|r"
		end
		local withheld, _, online = Read(GetNumGuildMembers)
		return not withheld and Labelled("Guild", Count(online) or 0) or nil
	end,
	Tip = function(fresh)
		local hidden, member = Read(IsInGuild)
		if hidden then
			return { title = "Guild", UNSAID }
		elseif member ~= true then
			return { title = "Guild", { DIM .. "You are not in a guild.|r" } }
		end
		if fresh then
			AskRoster(true)
		end
		local total, online = Ask(GetNumGuildMembers)
		total = Count(total) or 0
		local found = {}
		for index = 1, type(GetGuildRosterInfo) == "function" and math.min(total, 1000) or 0 do
			local ok, name, _, _, level, _, zone, _, _, isOnline, _, class = pcall(GetGuildRosterInfo, index)
			name = ok and Text(P.Plain(name)) or nil
			if name and P.Plain(isOnline) == true then
				found[#found + 1] = { Who(Text((Ask(Ambiguate, name, "guild"))) or name, P.Plain(class), P.Plain(level)), Text(P.Plain(zone)) or "" }
			end
		end
		local lines = { title = Text((Ask(GetGuildInfo, "player"))) or "Guild" }
		for index = 1, math.min(#found, MOST) do
			lines[#lines + 1] = found[index]
		end
		More(lines, #found - MOST)
		lines[#lines + 1] = { " " }
		lines[#lines + 1] = { "Online", ("%d of %d"):format(Count(online) or #found, total) }
		return lines
	end,
	Hint = function()
		return Ask(IsInGuild) == true and WindowHint("Click: open the guild window.") or nil
	end,
	Click = function(_, button)
		if button == "LeftButton" and Ask(IsInGuild) == true then
			Toggle("ToggleGuildFrame", "Flat UI: the guild window opens when the fight ends.")
		end
	end,
})

local NO_ICON = 134400
local MOST_SETS = 100
local REFUSED = "Flat UI: a set is not put on while you cast or while one of its items is locked."

local function SetsApi()
	local api = _G.C_EquipmentSet
	return type(api) == "table" and not ns.IsSecret(api) and api or nil
end

local function EquipmentSets()
	local api = SetsApi()
	if not api or type(api.GetEquipmentSetInfo) ~= "function" then
		return nil
	end
	local hidden, ids = Read(api.GetEquipmentSetIDs)
	if hidden or type(ids) ~= "table" then
		return nil
	end
	local list = {}
	for index = 1, math.min(#ids, MOST_SETS) do
		local id = Count(Field(ids, index))
		local ok, name, icon, worn, lost = false, nil, nil, nil, nil
		if id then
			local _
			ok, name, icon, _, worn, _, _, _, lost = pcall(api.GetEquipmentSetInfo, id)
		end
		name = ok and Text(P.Plain(name)) or nil
		if name then
			icon = Count(P.Plain(icon))
			list[#list + 1] = { id = id, name = name, icon = icon and icon > 0 and icon or NO_ICON, worn = P.Plain(worn) == true,
				lost = Count(P.Plain(lost)) or 0 }
		end
	end
	return list
end

local function WornSet(list)
	for _, set in ipairs(list) do
		if set.worn then
			return set
		end
	end
	return nil
end

local function Named(set)
	return ("|T%d:0|t %s"):format(set.icon, set.name)
end

local function Fighting()
	return P.InCombat() or Ask(UnitAffectingCombat, "player") == true
end

local function PutOn(set)
	local api = SetsApi()
	if not api or type(api.UseEquipmentSet) ~= "function" or Fighting() then
		return
	end
	local _, locked = Read(api.EquipmentSetContainsLockedItems, set.id)
	local _, casting = Read(UnitCastingInfo, "player")
	if locked == true or casting ~= nil then
		if type(print) == "function" then
			print(REFUSED)
		end
		return
	end
	Ask(api.UseEquipmentSet, set.id)
end

P.Stream({
	id = "sets", label = "Equipment set",
	events = { EQUIPMENT_SETS_CHANGED = true, EQUIPMENT_SWAP_FINISHED = true, PLAYER_EQUIPMENT_CHANGED = true,
		PLAYER_REGEN_DISABLED = true, PLAYER_REGEN_ENABLED = true },
	Text = function()
		local list = EquipmentSets()
		if not list then
			return nil
		end
		local set = WornSet(list)
		if set then
			return Named(set)
		end
		return DIM .. (#list > 0 and "No set worn" or "No sets") .. "|r"
	end,
	Tip = function()
		local list = EquipmentSets()
		if not list then
			return { title = "Equipment sets", UNSAID }
		end
		local lines = { title = "Equipment sets" }
		if #list == 0 then
			lines[1] = { DIM .. "You have no sets. The equipment manager of the character window saves them.|r" }
			return lines
		end
		for index = 1, math.min(#list, MOST) do
			local set = list[index]
			if set.lost > 0 then
				lines[#lines + 1] = { BAD .. Named(set) .. "|r", ("%s%d missing|r"):format(BAD, set.lost) }
			elseif set.worn then
				lines[#lines + 1] = { GOOD .. Named(set) .. "|r", GOOD .. "Worn|r" }
			else
				lines[#lines + 1] = { Named(set) }
			end
		end
		More(lines, #list - MOST)
		lines[#lines + 1] = { " " }
		lines[#lines + 1] = { DIM .. (Fighting() and "No set can be put on in a fight." or "Click to put on another set.") .. "|r" }
		return lines
	end,
	Click = function(slot, button)
		if button ~= "LeftButton" then
			return
		end
		if P.MenuOpen(slot) then
			P.CloseMenu()
			return
		end
		local list = not Fighting() and EquipmentSets() or nil
		if not list or #list == 0 then
			return
		end
		local items = {}
		for _, set in ipairs(list) do
			local text = Named(set)
			if set.lost > 0 then
				text = BAD .. text .. "|r"
			elseif set.worn then
				text = GOOD .. text .. "|r"
			end
			items[#items + 1] = { text = text, inert = set.worn, pick = function()
				PutOn(set)
			end }
		end
		P.OpenMenu(slot, P.streams.sets, "Equipment sets", items)
	end,
})
