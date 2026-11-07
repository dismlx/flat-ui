local ADDON_NAME, ns = ...

-- The streams of the data panels (DataPanels.lua): what a slot shows and what its tooltip says.
--   Bag space: free and total slots of the bags the player wears (C_Container.GetContainerNumSlots and GetContainerNumFreeSlots). A bag of a
--     special kind (a quiver, an ammo pouch, a soul bag: its family is not 0) holds only its own kind of item, so it counts apart, in the tooltip.
--   Gold: the player's money (GetMoney) with the game's coins (C_CurrencyInfo.GetCoinTextureString). The tooltip lists the gold of each
--     character of the account that logged in with the data panels on, kept in FlatUIDB.datapanels.gold by "Name - Realm".
--   Durability: of all the equipped items together (GetInventoryItemDurability), coloured by how worn it is; the tooltip lists each item.
--   Hearthstone: where it is bound (GetBindLocation) and the time left on its cooldown (C_Container.GetItemCooldown).
--   Coordinates: of the player on the map of the zone (C_Map.GetBestMapForUnit, GetPlayerMapPosition, read from the fields x and y of the
--     answer); none where the game gives none, as in a dungeon.
--   Frame rate and latency: GetFramerate, and the higher of the home and world latency (GetNetStats). The tooltip has both latencies and the
--     memory Flat UI uses (UpdateAddOnMemoryUsage and GetAddOnMemoryUsage, read out of combat when the tooltip opens).
--   Friends online: counted as the game's own button counts them (BNGetNumFriends, C_FriendList.GetNumOnlineFriends); the tooltip lists who.
--   Guild online: GetNumGuildMembers; the tooltip lists who (GetGuildRosterInfo). The roster is asked for (C_GuildInfo.GuildRoster) when the client
--     holds none, when the game says it may be asked again, and when the tooltip opens, at most every ROSTER_EVERY seconds.
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
-- A cooldown this short is the global cooldown, not the hearthstone's own.
local SHORT = 2
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

-- Bag space ------------------------------------------------------------------------------------------------------------------------------------

-- Free and total slots of the ordinary bags, then of the special ones; nothing when the client withholds an answer.
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
				if family == nil or family == 0 then
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
		return lines
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

-- The durability of all the equipped items together, in percent, each item: { slot, percent }, and how many items are nearly broken (at 50% or
-- less, red in the tooltip). 100 with no item that wears, and nothing when the client withholds an answer.
local function Durability()
	if type(GetInventoryItemDurability) ~= "function" then
		return nil
	end
	local items, now, most, broken = {}, 0, 0, 0
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
		end
	end
	return most > 0 and now / most * 100 or 100, items, broken
end

P.Stream({
	id = "durability", label = "Durability", sample = "Durability 100%",
	events = { UPDATE_INVENTORY_DURABILITY = true, PLAYER_EQUIPMENT_CHANGED = true },
	Text = function()
		local percent, _, broken = Durability()
		if not percent then
			return nil
		end
		local text = Labelled("Durability", ("%s%d%%|r"):format(Worn(percent), math.floor(percent + 0.5)))
		-- One broken item hardly moves the average, so the items at 50% or less are counted after it in red, as EnhanceQoL does by default.
		return broken > 0 and ("%s  %s%d|r%s at 50%% or less|r"):format(text, BAD, broken, DIM) or text
	end,
	Tip = function()
		local percent, items = Durability()
		if not percent then
			return { title = "Durability", UNSAID }
		end
		local lines = { title = "Durability" }
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
		end
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

P.Stream({
	id = "fps", label = "Frame rate and latency", sample = "888 fps  888 ms",
	every = 1,
	live = true,
	Text = function()
		local rate = Ask(GetFramerate)
		local home, world = Latency()
		local parts = {}
		if ns.Finite(rate) and rate >= 0 then
			parts[#parts + 1] = math.floor(rate + 0.5) .. DIM .. " fps|r"
		end
		if home or world then
			parts[#parts + 1] = math.max(home or 0, world or 0) .. DIM .. " ms|r"
		end
		return #parts > 0 and table.concat(parts, "  ") or nil
	end,
	Tip = function(fresh)
		local rate = Ask(GetFramerate)
		local home, world = Latency()
		local lines = { title = "Frame rate and latency" }
		if ns.Finite(rate) and rate >= 0 then
			lines[#lines + 1] = { "Frame rate", ("%.1f fps"):format(rate) }
		end
		lines[#lines + 1] = { "Home latency", home and (home .. " ms") or "Unknown" }
		lines[#lines + 1] = { "World latency", world and (world .. " ms") or "Unknown" }
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
