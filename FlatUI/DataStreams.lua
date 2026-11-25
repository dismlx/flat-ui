local ADDON_NAME, ns = ...

-- The streams of the data panels (DataPanels.lua): what a slot shows, what its tooltip says and what a left click on it does. A click that opens a
-- window of the game calls the game's own toggle of it (ToggleCharacter, ToggleQuestLog, ToggleFriendsFrame, ToggleGuildFrame, ToggleTimeManager,
-- ToggleCalendar, ToggleWorldMap, as its keys and buttons do): at once out of a fight, and in one as the fight ends, with a line in chat once
-- ("Flat UI: the quest log opens when the fight ends.", ns.OpenAfterFight, MapText.lua, as the time by the minimap and the quest count do). The
-- tooltip's dim last line says so ("Click: open the quest log, after the fight." in one). Every other button is the panels' own (DataPanels.lua:
-- the right click opens the slot's menu).
--   Bag space: free and total slots of the general bags the player wears, the backpack and the bags of family 0, the only room for any item
--     (C_Container.GetContainerNumSlots and GetContainerNumFreeSlots). A special bag (a trade bag, a quiver, an ammo pouch, a soul bag: its
--     family is not 0) and the reagent bag (Enum.BagIndex 5, of family 0 but for reagents only) hold only certain items, so they count apart,
--     in the tooltip, which says so. While Bags is on, a left click opens or closes Flat UI's bag window (ns.BagsToggle, Bags.lua, the checks
--     of /flatui bags); with Bags off it does nothing, as Flat UI calls none of the game's bag functions.
--   Gold: the player's money (GetMoney) with the game's coins (C_CurrencyInfo.GetCoinTextureString). The tooltip lists the gold of each
--     character of the account that logged in with the data panels on, kept in FlatUIDB.datapanels.gold by "Name - Realm", and under them what
--     this character made (in green) or spent (in red) since it logged in, kept over a /reload (ns.SessionMoney, BagsData.lua, the count the
--     bag window's gold tooltip says too), and from HOURLY_AFTER seconds into the session what that is an hour (its second answer, the seconds
--     since the session began); nothing while it made and spent nothing. The slot itself keeps its width.
--   Durability: of all the equipped items together (GetInventoryItemDurability), coloured by how worn it is, then in red how many items are
--     broken (at 0%: "1 broken"), else how many are at 50% or less; the tooltip opens with a red line while any is broken ("1 item broken: no
--     stats until repaired"), lists each item, the lowest first, and out of a fight the repair cost of the worn items under 100% (repairCost of
--     C_TooltipInfo.GetInventoryItem), as the character window's durability line does (CharacterDurability.lua). The slot takes no room where
--     the game rule that keeps gear from wearing is on (RepairArmorDisabled), as that line hides there. A click opens the character window.
--   Ammunition: for a bow, crossbow or gun in the ranged slot (GetInventoryItemID 18, class and subclass of C_Item.GetItemInfoInstant), the
--     arrows or bullets of the ammunition slot (0), the larger of C_Item.GetItemCount and GetInventoryItemCount, as the ammunition tracker counts
--     them (TrackerKinds.lua): red at 0, also with none in the slot or ammunition the weapon does not fire, gold at or under the Trackers page's
--     Ammunition minimum (trackers.ammoMin). A thrown weapon shows its stack (GetInventoryItemCount 18, gold at Thrown weapon minimum), or its
--     durability where it wears out. Nothing with no such weapon, a wand included. The tooltip names the ammunition (GetInventoryItemLink), the
--     count in the bags, the free slots of quivers and ammo pouches (the family bits 1 and 2 of GetContainerNumFreeSlots) and the minimum.
--   Soul shards: for a warlock (UnitClass), the soul shards in the bags (C_Item.GetItemCount 6265), red at 0, with the free slots of the soul
--     bags (family bit 4) in the tooltip; nothing for another class.
--   Hearthstone: where it is bound (GetBindLocation) and the time left on its cooldown (C_Container.GetItemCooldown).
--   Coordinates: of the player on the map of the zone (C_Map.GetBestMapForUnit, GetPlayerMapPosition, read from the fields x and y of the
--     answer); none where the game gives none, as in a dungeon. A click opens the world map (ToggleWorldMap, as the coordinates by the minimap
--     do), and Shift-click puts the zone and the coordinates in the chat box (ns.PutInChat, MapText.lua), in a fight too.
--   Time: the time of this computer (date) or of the realm (GetGameTime), 24 or 12 hours, as the game's own clock settings say
--     (timeMgrUseLocalTime and timeMgrUseMilitaryTime, read with GetCVarBool; local and 24 hours when the client does not say), in the game's
--     own formats. The tooltip has both times and how long this session has run (GetSessionTime). A click opens the stopwatch and alarm,
--     Shift-click the calendar, as the time by the minimap does (MapText.lua).
--   Quest log: the quests in the log over the most it holds, counted as the quest count on the objective tracker counts them (QuestCount.lua),
--     red while the log is full. The tooltip has how many are ready to hand in (C_QuestLog.IsComplete) and, while Flat UI's experience bar knows
--     it, their experience (ns.XpQuestReady, XpStats.lua). A click opens the quest log.
--   Experience: the share of this level done and, in a rested blue, the rested experience as a share of the level (UnitXP, UnitXPMax,
--     GetXPExhaustion); nothing at the top level or with experience turned off (GameRulesUtil.CanShowExperienceBar, as XpBar.lua asks). The
--     tooltip has the experience over the most, what is left to level, the rested experience, the experience of the quests ready to hand in
--     (ns.XpQuestReady) and, while Flat UI's experience bar counts them, the time to level and the pace (ns.XpStatsText, XpStats.lua).
--     Shift-click puts the experience bar's own chat line in the chat box.
--   Reputation: the faction Flat UI's reputation bar shows (ns.XpRepNow, XpBar.lua; with Errands' Show the reputation you gain, the one last
--     gained with, ns.ErrandsRepFollowed), else the one the game watches (C_Reputation.GetWatchedFactionData, read by its ID with
--     GetFactionDataByID), its standing in the colour of the game's reputation bar (FACTION_BAR_COLORS) and the share of it done; nothing with no
--     faction. The tooltip has the standing, the reputation over the standing's most, what is left to the next standing and, for the faction of
--     Flat UI's bar, its pace and the time to the next standing (ns.XpStatsRepText, XpStats.lua). A click opens the Reputation tab of the character
--     window; Shift-click puts "Stormwind: Honored 4,200 / 12,000 (35%)" in the chat box. The slot is drawn again on UPDATE_FACTION and each time
--     Errands switches the faction of the bar (ns.DataPanelMark, DataPanels.lua), half a second after the gain, so it follows the bar. A faction
--     at the top shows no share, so test mode's sample is "Stormwind Revered 88%".
--   Frame rate and latency: GetFramerate, and the higher of the home and world latency (GetNetStats). The tooltip has both latencies and the
--     memory Flat UI uses (UpdateAddOnMemoryUsage and GetAddOnMemoryUsage, read out of combat when the tooltip opens). With Colour frame rate
--     and latency on, each number is in the panels' green, gold or red by the steps of the minimap's line (ns.PerfColour, MapText.lua).
--   Friends online: counted as the game's own button counts them (BNGetNumFriends, C_FriendList.GetNumOnlineFriends); the tooltip lists who. A
--     click opens the friends list.
--   Guild online: GetNumGuildMembers; the tooltip lists who (GetGuildRosterInfo). The roster is asked for (C_GuildInfo.GuildRoster) when the client
--     holds none, when the game says it may be asked again, and when the tooltip opens, at most every ROSTER_EVERY seconds. In a guild, a click
--     opens the guild window.
--   Equipment set: the set of the game's equipment manager that the player wears, with its icon (C_EquipmentSet.GetEquipmentSetIDs and
--     GetEquipmentSetInfo, in the game's order). The tooltip lists the sets, the one worn in green and one with items missing in red, as the
--     character window colours them (Camelot/PaperDollFrame.lua:3159-3181). A left click opens a menu of Flat UI's own (DataPanels.lua) whose
--     lines put a set on with C_EquipmentSet.UseEquipmentSet, which is neither protected nor restricted (EquipmentManagerDocumentation.lua:
--     286-300) and which the game's own Equip button calls from its own code, after the same two checks made here: not while an item of the
--     set is locked and not while the player casts (EquipmentManager_EquipSet, Blizzard_FrameXML/Mainline/EquipmentManager.lua:259-266). In a
--     fight the game changes only the weapons (INVSLOTS_EQUIPABLE_IN_COMBAT, Blizzard_FrameXMLBase/Constants.lua:158-162), so nothing is
--     offered then: the menu does not open and closes as a fight starts, and a line clicked in one does nothing.
-- Built on the streams of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission. Left out: the warband, the options of each
-- stream, the click of the hearthstone, which used it through a secure button (on Flat UI's panels no click casts anything), the order and
-- the specialisation of the equipment sets (Stream_EquipmentSets.lua:64-74), and its refusal in the game's red error text: Flat UI says it in chat.

local P = ns.DataPanels
local Ask, Read, Count, Field, Text, Labelled = P.Ask, P.Read, P.Count, P.Field, P.Text, P.Labelled
local DIM, GOOD, WARN, BAD = P.DIM, P.GOOD, P.WARN, P.BAD
-- Names in the list of a tooltip; the rest are counted on one line.
local MOST = 25
local HEARTHSTONE, HEARTHSTONE_ICON = 6948, 134414
local ROSTER_EVERY = 15
-- Seconds into a session before the Gold tooltip says what it made an hour.
local HOURLY_AFTER = 600
-- A cooldown this short is the global cooldown, not the hearthstone's own.
local SHORT = 2
-- The reagent bag (Enum.BagIndex.ReagentBag): its family is 0, but it takes only reagents, so it is not general room.
local REAGENT_BAG = 5
-- The equipment slots, by their numbers (INVSLOT_HEAD and the rest).
local SLOT_NAMES = { [1] = "Head", [2] = "Neck", [3] = "Shoulders", [4] = "Shirt", [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet",
	[9] = "Wrists", [10] = "Hands", [11] = "Finger", [12] = "Finger", [13] = "Trinket", [14] = "Trinket", [15] = "Back", [16] = "Main hand",
	[17] = "Off hand", [18] = "Ranged", [19] = "Tabard" }

-- The lines that count the names left out of a list.
local function More(lines, left)
	if left > 0 then
		lines[#lines + 1] = { ("%s and %d more|r"):format(DIM, left) }
	end
end

-- A name in the colour of its class, with the level after it in the dim colour.
local function Who(name, class, level)
	local hex = P.ClassHex(class)
	local text = hex and (hex .. name .. "|r") or name
	if Count(level) and level > 0 then
		text = text .. " " .. DIM .. level .. "|r"
	end
	return text
end

-- The class file name (WARRIOR) of a class name in the client's language, from the game's own lists of them.
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

-- Clicks ----------------------------------------------------------------------------------------------------------------------------------------

local function Shift()
	return Ask(_G.IsShiftKeyDown) == true
end

-- Runs one of the game's own toggles of a window by its global name (ToggleCharacter and the rest, as the game's keys and buttons open them) with
-- its arguments: now out of a fight, and in one as the fight ends, with later said once in chat (ns.OpenAfterFight, MapText.lua, as the time by
-- the minimap and the quest count do). Without ns.OpenAfterFight, out of a fight only. True when it ran now.
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

-- The hint of a click that opens a window, with ", after the fight" at the end of each clause while in one ("Click: open the quest log, after
-- the fight."), as the time by the minimap and the quest count word it.
local function WindowHint(text)
	if P.InCombat() and type(ns.OpenAfterFight) == "function" then
		return (text:gsub("%.", ", after the fight."))
	elseif P.InCombat() then
		return "Out of a fight, " .. text:sub(1, 1):lower() .. text:sub(2)
	end
	return text
end

-- A whole number with the game's thousands marks (BreakUpLargeNumbers), or plain where the client has none.
local function Grouped(value)
	value = math.floor(value + 0.5)
	return Text((Ask(_G.BreakUpLargeNumbers, value))) or tostring(value)
end

-- Bag space ------------------------------------------------------------------------------------------------------------------------------------

-- Free and total slots of the general bags (family 0, not the reagent bag), then of the bags that take only certain items; nothing when the
-- client withholds an answer.
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

-- The line of a tooltip whose numbers the client withholds now.
local UNSAID = { DIM .. "The game does not say now.|r" }

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
		lines[#lines + 1] = { DIM .. "Counts only bags that take any item.|r" }
		return lines
	end,
	Hint = function()
		return ns.Enabled("bags") and type(ns.BagsToggle) == "function" and "Click: open your bags." or nil
	end,
	-- A left click opens Flat UI's bag window or closes it, only while Bags is on.
	Click = function(_, button)
		if button == "LeftButton" and ns.Enabled("bags") and type(ns.BagsToggle) == "function" then
			ns.BagsToggle()
		end
	end,
})

-- Gold ------------------------------------------------------------------------------------------------------------------------------------------

-- An amount of copper with the game's coins, as high as the text of a slot when size is given, or as 1g 20s 5c on a client without them.
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

-- The money of this character, kept for the account by "Name - Realm" with its class.
local function Record()
	local store, key, money = P.Store(true), ns.CharacterKey(), Count((Ask(GetMoney)))
	if not (store and type(key) == "string" and money) then
		return
	end
	local _, class = Ask(UnitClass, "player")
	store.gold[key] = { money = money, class = type(class) == "string" and class or nil }
end

-- The characters whose gold is kept, the richest first: { key, money, class }.
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

P.Stream({
	id = "gold", label = "Gold",
	events = { PLAYER_MONEY = Record },
	Start = Record,
	Text = function()
		local money = Count((Ask(GetMoney)))
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
		-- What this character made or spent since it logged in (ns.SessionMoney, BagsData.lua), the same count as the bag window's gold, and from
		-- HOURLY_AFTER seconds into the session what that is an hour.
		local okSession, session, seconds = pcall(function()
			if type(ns.SessionMoney) == "function" then
				return ns.SessionMoney()
			end
			return nil
		end)
		if okSession and ns.Finite(session) and session ~= 0 then
			local hourly = ""
			if ns.Finite(seconds) and seconds >= HOURLY_AFTER then
				hourly = (" (%s an hour)"):format(P.Money(math.abs(session) * 3600 / seconds))
			end
			lines[#lines + 1] = { " " }
			lines[#lines + 1] = { "This session", (session > 0 and (GOOD .. "+") or (BAD .. "-")) .. P.Money(math.abs(session)) .. hourly .. "|r" }
		end
		return lines
	end,
})

-- The characters whose gold the tooltip lists, for the row Forget a character's gold: numbered in the order of their names.
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

-- Durability -----------------------------------------------------------------------------------------------------------------------------------

-- The colour of a durability: worn below 80%, nearly broken at 50% and below (EnhanceQoL's steps).
local function Worn(percent)
	local whole = math.floor(percent + 0.5)
	return whole > 80 and GOOD or whole > 50 and WARN or BAD
end

-- The durability of all the equipped items together, in percent, each item: { slot, percent }, lowest first, then by slot, as the character
-- window's line lists them (CharacterDurability.lua), how many items are nearly broken (at 50% or less, red in the tooltip) and how many are
-- broken (at 0%, so they give no stats). 100 with no item that wears, and nothing when the client withholds an answer.
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

-- True where the game rule that keeps gear from wearing out is on (Enum.GameRule.RepairArmorDisabled, C_GameRules.IsGameRuleActive), as the
-- character window's durability line and the minimap's read it (CharacterDurability.lua, MapText.lua). An answer the game withholds or does not
-- give counts as off.
local function NoWear()
	local kinds = Field(_G.Enum, "GameRule")
	local rule = Field(kinds, "RepairArmorDisabled")
	local active = Field(_G.C_GameRules, "IsGameRuleActive")
	if rule == nil or type(active) ~= "function" then
		return false
	end
	return Ask(active, rule) == true
end

-- What the worn items under 100% cost to repair: the sum of the repairCost their tooltip data gives (C_TooltipInfo.GetInventoryItem, the figure the
-- game's repair tooltip shows, as the character window's durability line reads it), or nil when none gives one. Never in a fight.
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
	id = "durability", label = "Durability", sample = "Durability 100%",
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
		-- One broken item hardly moves the average, so the items at 0% are counted after it in red ("1 broken"), else the items at 50% or less,
		-- as EnhanceQoL does by default.
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
	-- A left click opens the character window, in a fight as it ends (ToggleCharacter, as the game's key does).
	Click = function(_, button)
		if button == "LeftButton" then
			Toggle("ToggleCharacter", "Flat UI: the character window opens when the fight ends.", "PaperDollFrame")
		end
	end,
})

-- Ammunition and soul shards ------------------------------------------------------------------------------------------------------------------

-- The inventory slots of the ammunition and of the ranged weapon (INVSLOT_AMMO, INVSLOT_RANGED), the item classes of weapons and projectiles, the
-- projectile each weapon subclass fires (bows and crossbows arrows, 2; guns bullets, 3: ItemConstantsDocumentation.lua), the thrown subclass, the
-- soul shard, the bag families (the bits of the family GetContainerNumFreeSlots gives) of quivers and ammo pouches and of soul bags, and the
-- minimums the slots use when the Trackers rows give none.
local AMMO = { slot = 0, ranged = 18, weapon = 2, projectile = 6, fires = { [2] = 2, [18] = 2, [3] = 3 }, thrown = 16, shard = 6265,
	quiver = { 1, 2 }, soul = { 4 }, low = 200, thrownLow = 20, worn = 20 }

-- Free and total slots of the bags of a family, nil when the client withholds an answer; 0 and 0 with no such bag.
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

-- The line of a tooltip with the free slots of the bags of a family, or nil with none.
local function FamilyLine(label, bits)
	local free, total = FamilySpace(bits)
	if free and total > 0 then
		return { label, ("%d of %d free"):format(free, total) }
	end
	return nil
end

-- A minimum of the Trackers page (trackers.ammoMin or trackers.thrownMin), or the fallback.
local function Least(path, fallback)
	local value = ns.Get(path)
	return ns.Finite(value) and value >= 0 and value or fallback
end

-- The colour of a count: red at 0, gold at or under the minimum (0: never).
local function Low(count, least)
	return count <= 0 and BAD or (least > 0 and count <= least) and WARN or ""
end

-- The ranged weapon and what it takes: { fired, ammo = the item ID in the ammunition slot (nil with none), wrong = true for ammunition the weapon
-- does not fire, count }, or { thrown, count } for a stack of thrown weapons, or { thrown, percent } for one that wears out. Nil with no weapon
-- that takes ammunition (none, a wand) or while the game withholds an answer.
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
	-- The larger of the bag count and the slot's, the number on the character window, as the ammunition tracker counts it.
	local bags = Count((Ask(items.GetItemCount, ammo)))
	local held = Count((Ask(GetInventoryItemCount, "player", AMMO.slot)))
	local count = (bags and held) and math.max(bags, held) or bags or held
	return count and { fired = true, ammo = ammo, count = count } or nil
end

P.Stream({
	id = "ammo", label = "Ammunition", sample = "Ammo 8,888",
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

-- True for a warlock; a withheld class is none.
local function Warlock()
	local _, class = Ask(UnitClass, "player")
	return class == "WARLOCK"
end

P.Stream({
	id = "shards", label = "Soul shards", sample = "Shards 88",
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

-- Hearthstone -----------------------------------------------------------------------------------------------------------------------------------

-- Seconds left on the hearthstone's cooldown: 0 when it is ready or the client has no answer, nil when it withholds it.
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

-- Seconds left when the slot was last drawn: the slot is drawn every second only while the hearthstone cools down.
local hearthLeft = 0

P.Stream({
	id = "hearth", label = "Hearthstone",
	events = { HEARTHSTONE_BOUND = true, BAG_UPDATE_COOLDOWN = true },
	every = function()
		return hearthLeft > 0 and 1 or nil
	end,
	live = true,
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
})

-- Coordinates ----------------------------------------------------------------------------------------------------------------------------------

-- The player's place on the map of the zone, from 0 to 100, or nothing where the game gives none.
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
	id = "coords", label = "Coordinates", sample = "88.8, 88.8",
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
	-- A left click opens the world map (ToggleWorldMap, in a fight as it ends), as the coordinates by the minimap do (MapText.lua). Shift and a left
	-- click put the zone and the coordinates in the chat box (ns.PutInChat, MapText.lua), in a fight too: "Elwynn Forest 45.2, 61.8".
	Click = function(_, button)
		if button ~= "LeftButton" then
			return
		elseif not Shift() then
			Toggle("ToggleWorldMap", "Flat UI: the world map opens when the fight ends.")
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

-- Time --------------------------------------------------------------------------------------------------------------------------------------------

-- A setting of the game's clock (GetCVarBool, as GameTimeUtil.lua:10 and 88 read them), or the default when the client does not say.
local function ClockSetting(name, default)
	local cvars = type(C_CVar) == "table" and not ns.IsSecret(C_CVar) and C_CVar or nil
	local value = Ask(cvars and cvars.GetCVarBool or _G.GetCVarBool, name)
	if type(value) == "boolean" then
		return value
	end
	return default
end

-- A text of the game's own format, or the fallback when it has none.
local function Formatted(pattern, fallback, ...)
	if type(pattern) == "string" and not ns.IsSecret(pattern) then
		local ok, text = pcall(string.format, pattern, ...)
		if ok and type(text) == "string" and text ~= "" then
			return text
		end
	end
	return fallback:format(...)
end

-- An hour and a minute as the game's clock writes them, 24 or 12 hours by its setting, or nothing when either is not a number.
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

-- The time of this computer (date) and of the realm (GetGameTime).
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
	-- As the time by the minimap (MapText.lua): a left click opens the game's stopwatch and alarm, Shift and a click its calendar, in a fight as it
	-- ends.
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

-- Quest log -------------------------------------------------------------------------------------------------------------------------------------

local function QuestLog()
	local log = _G.C_QuestLog
	return type(log) == "table" and not ns.IsSecret(log) and type(log.GetNumQuestLogEntries) == "function" and log or nil
end

-- Each quest of the log once, as the quest count on the tracker walks it (QuestCount.lua): no header, not hidden, a quest ID above 0. fn(id) runs
-- for each; the count of them, or nothing when the log cannot be walked.
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

-- The quests in the log and the most it holds (nil when the game does not say), as the quest count on the tracker reads them: the second answer of
-- C_QuestLog.GetNumQuestLogEntries, else the walk, over C_QuestLog.GetMaxNumQuestsCanAccept, else MAX_QUESTLOG_QUESTS or MAX_QUESTS. Nothing
-- when the client withholds the count.
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

-- The quests of the log that are ready to hand in (C_QuestLog.IsComplete), or nothing when the log cannot be walked.
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
	-- A left click opens the game's quest log, in a fight as it ends (ToggleQuestLog, as the game's key does).
	Click = function(_, button)
		if button == "LeftButton" then
			Toggle("ToggleQuestLog", "Flat UI: the quest log opens when the fight ends.")
		end
	end,
})

-- Experience ------------------------------------------------------------------------------------------------------------------------------------

-- The rested share in the slot: the blue of the game's rested bar, made light enough to read on the panel.
local RESTED = "|cff6fa8ff"

-- The player's experience, the most of this level and the rested experience (UnitXP, UnitXPMax, GetXPExhaustion, as Flat UI's experience bar reads
-- them, XpBar.lua). Nothing while the game would show no experience bar (GameRulesUtil.CanShowExperienceBar, as XpBar.lua asks: at the top
-- level, or with experience turned off, IsXPUserDisabled) or withholds a value.
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

-- The line a Shift-click puts in the chat box, as the experience bar's (XpBar.lua): "Level 34: 12,345 / 27,000 (45%), 1h 20m to level".
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
	id = "xp", label = "Experience", sample = "XP 88.8%  +88%",
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
		-- Flat UI's own count of the time to level and the pace (XpStats.lua), while the experience bar knows them.
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

-- Reputation ------------------------------------------------------------------------------------------------------------------------------------

local LATER_REP = "Flat UI: your reputations open when the fight ends."

-- The faction a Reputation slot follows: the one Flat UI's reputation bar shows (ns.XpRepNow, XpBar.lua, which follows Errands' Show the
-- reputation you gain), else the one Show the reputation you gain follows (ns.ErrandsRepFollowed, ErrandsLevelling.lua), else the one the game
-- watches (C_Reputation.GetWatchedFactionData, as XpBar.lua reads it): { name, reaction, value, total, capped, bar }, bar true for the faction of
-- Flat UI's bar, whose pace XpStats.lua counts. Nothing with none, or when the game withholds a value.
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

-- The game's name of a standing (FACTION_STANDING_LABEL1 to 8), or nil.
local function Standing(reaction)
	return reaction and Text(P.Plain(_G["FACTION_STANDING_LABEL" .. reaction])) or nil
end

-- A standing in the colour of the game's reputation bar for it (FACTION_BAR_COLORS), plain where the client gives none.
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

-- The line a Shift-click puts in the chat box: "Stormwind: Honored 4,200 / 12,000 (35%)", or "Stormwind: Exalted" at the top.
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
	id = "rep", label = "Reputation", sample = "Stormwind Revered 88%",
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
		-- Flat UI's own count of the reputation pace and the time to the next standing (XpStats.lua), for the faction of its bar.
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
	-- A left click opens the Reputation tab of the character window, in a fight as it ends (ToggleCharacter, as Flat UI's reputation bar does);
	-- Shift and a click put the faction's line in the chat box (ns.PutInChat, MapText.lua), in a fight too.
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

-- Frame rate and latency ------------------------------------------------------------------------------------------------------------------------

local function Latency()
	local _, _, home, world = Ask(GetNetStats)
	return Count(home), Count(world)
end

-- The memory Flat UI uses, in KB: read when a tooltip opens out of combat, and kept for the tooltips that follow.
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

-- The colours of the panels for a good, a middling and a poor frame rate or latency; ns.PerfColour (MapText.lua) has the steps.
local PERF = { GOOD, WARN, BAD }

-- A number of the frame rate or the latency, written as text (the value itself without it), in its colour while Colour frame rate and latency is
-- on. The code is in the text only, so the slot is as wide as the same digits without it.
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

-- Friends -----------------------------------------------------------------------------------------------------------------------------------------

local function Friendly()
	local list = _G.C_FriendList
	return type(list) == "table" and not ns.IsSecret(list) and list or nil
end

-- Friends online as the game's own button counts them: Battle.net friends online, and the characters of the friends list online while the game
-- keeps that list. Nothing when the client withholds an answer or has neither list.
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

-- Who is online: the characters of the friends list, then Battle.net friends, each once, as { left, right } lines of a tooltip.
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
	-- A left click opens the friends list on its Friends tab, in a fight as it ends (ToggleFriendsFrame, Camelot/FriendsFrame.lua).
	Click = function(_, button)
		if button == "LeftButton" then
			Toggle("ToggleFriendsFrame", "Flat UI: your friends list opens when the fight ends.", Count(_G.FRIEND_TAB_FRIENDS) or 1)
		end
	end,
})

-- Guild -----------------------------------------------------------------------------------------------------------------------------------------

local asked = -math.huge

-- Asks the server for the guild roster, at most every ROSTER_EVERY seconds, while a slot shows the guild.
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
	-- A left click opens the guild window, only in a guild and in a fight as it ends (ToggleGuildFrame, Blizzard_Game/Mainline/Game.lua, as the
	-- game's key).
	Click = function(_, button)
		if button == "LeftButton" and Ask(IsInGuild) == true then
			Toggle("ToggleGuildFrame", "Flat UI: the guild window opens when the fight ends.")
		end
	end,
})

-- Equipment set ---------------------------------------------------------------------------------------------------------------------------------

-- The game's icon for a set that has none (INV_Misc_QuestionMark, Camelot/PaperDollFrame.lua:3167-3171).
local NO_ICON = 134400
-- At most this many sets are read: the game keeps far fewer.
local MOST_SETS = 100
local REFUSED = "Flat UI: a set is not put on while you cast or while one of its items is locked."

local function SetsApi()
	local api = _G.C_EquipmentSet
	return type(api) == "table" and not ns.IsSecret(api) and api or nil
end

-- The sets of the equipment manager in the game's order: { id, name, icon, worn, lost }. Nothing on a client without the manager or when it
-- withholds the list; a set whose name it withholds is left out.
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

-- The icon and the name of a set.
local function Named(set)
	return ("|T%d:0|t %s"):format(set.icon, set.name)
end

-- True in a fight, when no set is offered.
local function Fighting()
	return P.InCombat() or Ask(UnitAffectingCombat, "player") == true
end

-- Puts a set on as the game's own Equip button does (EquipmentManager.lua:259-266), never in a fight. A check whose answer the client withholds
-- leaves the set to the game.
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
		-- The last line of a tooltip that shows says whether a set can be put on now.
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
	-- A left click opens the menu of the sets, or closes it. The set worn is in it, and does nothing.
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
