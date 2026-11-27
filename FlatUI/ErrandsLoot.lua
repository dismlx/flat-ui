local _, ns = ...

local E = ns.Errands
local part = E.Part({ label = "Loot" })

local POOR = 0
local PICKUP_BIND = 1
local QUEST_BIND = 4
local ITEM_SLOT = 1
local MASTER = 2
local DEFAULT_BAGS = 4
local DEFAULT_THRESHOLD = 2
local GENERIC = "Make room: delete a grey item"
local QUESTION_ICON = 134400

local lootOpen = false
local looted = false
local button
local target
local waitBags
local fighting = false
local lastTaken, lastDeleted

local function Field(info, key)
	local value = info[key]
	if ns.IsSecret(value) then
		return nil
	end
	return value
end

local function Facts(link)
	if type(C_Item) ~= "table" or type(C_Item.GetItemInfo) ~= "function" then
		return nil
	end
	local ok, name, _, quality, _, _, _, _, _, _, _, price, _, _, bind = pcall(C_Item.GetItemInfo, link)
	if not ok or name == nil or ns.IsSecret(price) or ns.IsSecret(bind) or ns.IsSecret(quality) then
		return nil
	end
	return price, bind, quality
end

local AsksFirst

local function GameLoots()
	local on = type(C_CVar) == "table" and E.Ask(C_CVar.GetCVarBool, "autoLootDefault")
	local flipped = E.Ask(IsModifiedClick, "AUTOLOOTTOGGLE")
	if type(on) ~= "boolean" or type(flipped) ~= "boolean" then
		return false
	end
	return on ~= flipped
end

local function MasterThreshold()
	local method
	if type(C_PartyInfo) == "table" and type(C_PartyInfo.GetLootMethod) == "function" then
		method = E.Ask(C_PartyInfo.GetLootMethod)
		local master = type(Enum) == "table" and type(Enum.LootMethod) == "table" and Enum.LootMethod.Masterlooter or MASTER
		method = method == master and "master" or method
	elseif type(GetLootMethod) == "function" then
		method = E.Ask(GetLootMethod)
	end
	if method ~= "master" then
		return nil
	end
	local threshold = E.Ask(GetLootThreshold)
	return type(threshold) == "number" and threshold or DEFAULT_THRESHOLD
end

local function HoldsItem(slot)
	if type(GetLootSlotType) == "function" then
		local kind = E.Ask(GetLootSlotType, slot)
		if type(kind) == "number" then
			local item = type(Enum) == "table" and type(Enum.LootSlotType) == "table" and Enum.LootSlotType.Item or ITEM_SLOT
			return kind == item
		end
	end
	if type(LootSlotHasItem) == "function" then
		local has = E.Ask(LootSlotHasItem, slot)
		if type(has) == "boolean" then
			return has
		end
	end
	return nil
end

AsksFirst = function(slot)
	local item = HoldsItem(slot)
	if item == false then
		return false
	end
	local link = E.Ask(GetLootSlotLink, slot)
	if type(link) ~= "string" then
		return item == true
	end
	local _, bind = Facts(link)
	return bind == nil or bind == PICKUP_BIND
end

local function QuickLoot(autoLoot)
	if E.Opt("quickLoot") ~= true or looted then
		return
	end
	if ns.IsSecret(autoLoot) or type(autoLoot) ~= "boolean" then
		autoLoot = GameLoots()
	end
	if autoLoot ~= true then
		return
	end
	local count = E.Ask(GetNumLootItems)
	if type(count) ~= "number" or count < 1 or type(GetLootSlotInfo) ~= "function" then
		return
	end
	looted = true
	local threshold = MasterThreshold()
	local taken = 0
	for slot = 1, count do
		local ok, icon, _, _, _, quality, locked = pcall(GetLootSlotInfo, slot)
		local readable = ok and icon ~= nil and not ns.IsSecret(locked) and not ns.IsSecret(quality)
		local kept = readable and threshold ~= nil and type(quality) == "number" and quality >= threshold
		if readable and locked ~= true and not kept and not AsksFirst(slot) and E.Call(LootSlot, slot) then
			taken = taken + 1
		end
	end
	lastTaken = taken
end

E.Listen(part, "LOOT_READY", QuickLoot)

local function Bags()
	for _, n in ipairs({ NUM_BAG_SLOTS }) do
		if type(n) == "number" and not ns.IsSecret(n) and n >= 0 and n <= 20 then
			return n
		end
	end
	return DEFAULT_BAGS
end

local function Candidate(bag, slot)
	local info = E.Ask(C_Container.GetContainerItemInfo, bag, slot)
	if type(info) ~= "table" then
		return nil
	end
	local id, link, count = Field(info, "itemID"), Field(info, "hyperlink"), Field(info, "stackCount")
	if type(id) ~= "number" or type(link) ~= "string" or Field(info, "quality") ~= POOR or Field(info, "isLocked") ~= false then
		return nil
	end
	if type(count) ~= "number" or count < 1 or E.Kept(id) then
		return nil
	end
	local quest = E.Ask(C_Container.GetContainerItemQuestInfo, bag, slot)
	if type(quest) ~= "table" or Field(quest, "isQuestItem") ~= false or Field(quest, "questID") ~= nil then
		return nil
	end
	local price, bind, quality = Facts(link)
	if bind == nil or bind == QUEST_BIND or quality ~= POOR then
		return nil
	end
	price = type(price) == "number" and price >= 0 and price or 0
	local icon, name = Field(info, "iconFileID"), link:match("%[(.-)%]") or Field(info, "itemName")
	return { bag = bag, slot = slot, id = id, link = link, count = count, value = price * count, icon = type(icon) == "number" and icon or nil,
		name = type(name) == "string" and name ~= "" and name or nil }
end

local function Cheapest()
	if type(C_Container) ~= "table" then
		return nil
	end
	local cheapest, ordinary = nil, 0
	for bag = 0, Bags() do
		local slots = E.Ask(C_Container.GetContainerNumSlots, bag)
		if type(slots) ~= "number" then
			return nil
		end
		if slots > 0 then
			local free, family = E.Ask(C_Container.GetContainerNumFreeSlots, bag)
			if type(free) ~= "number" or type(family) ~= "number" then
				return nil
			end
			if family == 0 then
				ordinary = ordinary + 1
				if free > 0 then
					return nil
				end
				for slot = 1, slots do
					local candidate = Candidate(bag, slot)
					if candidate and (not cheapest or candidate.value < cheapest.value) then
						cheapest = candidate
					end
				end
			end
		end
	end
	return ordinary > 0 and cheapest or nil
end

local function CursorEmpty()
	return E.Ask(GetCursorInfo) == nil and E.Ask(CursorHasItem) ~= true
end

local function Fight()
	return fighting or E.Fighting()
end

local function Worth(entry)
	return entry.count > 1 and ("%s x%d, worth %s"):format(entry.link, entry.count, E.Money(entry.value)) or ("%s, worth %s"):format(entry.link, E.Money(entry.value))
end

local function Explain(owner)
	if not target or not GameTooltip or ns.Forbidden(GameTooltip) then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText("Make room")
	GameTooltip:AddLine(("Deletes %s. Your bags are full."):format(Worth(target)), 1, 1, 1, true)
	GameTooltip:Show()
end

local Update

local function Label(entry)
	if not entry.name then
		return GENERIC
	end
	return ("Delete |T%d:0|t %s%s"):format(entry.icon or QUESTION_ICON, entry.name, entry.count > 1 and (" x%d"):format(entry.count) or "")
end

local function ItemLeft()
	local count = E.Ask(GetNumLootItems)
	if type(count) ~= "number" then
		return true
	end
	for slot = 1, count do
		if HoldsItem(slot) ~= false then
			return true
		end
	end
	return false
end

local function Settle()
	if not waitBags then
		return
	end
	local info = E.Ask(C_Container.GetContainerItemInfo, waitBags.bag, waitBags.slot)
	if type(info) ~= "table" or Field(info, "hyperlink") ~= waitBags.link then
		waitBags = nil
	end
end

local function DeleteNow()
	if waitBags or not lootOpen or not target or Fight() or not CursorEmpty() then
		return
	end
	local shown, now = target, Cheapest()
	if not now or now.bag ~= shown.bag or now.slot ~= shown.slot or now.id ~= shown.id or now.link ~= shown.link or now.count ~= shown.count then
		Update()
		return
	end
	E.Call(C_Container.PickupContainerItem, shown.bag, shown.slot)
	local kind, id, link = E.Ask(GetCursorInfo)
	if kind ~= "item" or id ~= shown.id or link ~= shown.link then
		E.Call(ClearCursor)
		Update()
		return
	end
	E.Call(DeleteCursorItem)
	if not CursorEmpty() then
		E.Call(ClearCursor)
		print("Flat UI: the game did not delete the item. Delete it by hand.")
		Update()
		return
	end
	lastDeleted = shown.link
	E.Say(("Deleted %s. Loot again."):format(Worth(shown)))
	waitBags, target = { bag = shown.bag, slot = shown.slot, link = shown.link }, nil
	if button then
		button:Hide()
	end
end

local function Delete()
	local ok, err = pcall(DeleteNow)
	if not ok then
		if not CursorEmpty() then
			E.Call(ClearCursor)
		end
		error(err, 0)
	end
end

local function Wanted()
	return lootOpen and target ~= nil and not waitBags and E.On("makeRoom") and not E.Gamepad() and not ns.PartStopped("errands", part.label)
end

local function Hide()
	target = nil
	if button then
		button:Hide()
	end
end

Update = function()
	if not lootOpen or waitBags or not E.On("makeRoom") or E.Gamepad() or ns.PartStopped("errands", part.label) or not ItemLeft() then
		Hide()
		return
	end
	target = Cheapest()
	if not target then
		Hide()
		return
	end
	local frame = LootFrame
	if not button then
		if Fight() or type(frame) ~= "table" or ns.Forbidden(frame) or ns.MaybeProtected and ns.MaybeProtected(frame) then
			target = nil
			return
		end
		button = E.Button(frame, GENERIC, 200, function()
			if not E.Run(part, Delete) then
				Hide()
			end
		end, function(owner)
			E.Run(part, Explain, owner)
		end)
		button:SetPoint("TOP", frame, "BOTTOM", 0, -4)
		button.Keep(Wanted)
	end
	button.SetLabel(Label(target))
	button.SetUsable(not Fight() and CursorEmpty())
	button:Show()
	if E.TipOwned(button) then
		Explain(button)
	end
end

E.Listen(part, "LOOT_OPENED", function()
	lootOpen = true
	Settle()
	Update()
end)
E.Listen(part, "LOOT_CLOSED", function()
	lootOpen, looted, waitBags = false, false, nil
	Update()
end)
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED" }) do
	E.Listen(part, event, function()
		Settle()
		if lootOpen or (button and button:IsShown()) then
			Update()
		end
	end)
end
E.Listen(part, "PLAYER_REGEN_DISABLED", function()
	fighting = true
	if button then
		Update()
	end
end)
E.Listen(part, "PLAYER_REGEN_ENABLED", function()
	fighting = false
	if lootOpen then
		Update()
	end
end)
for _, event in ipairs({ "CURSOR_CHANGED", "GET_ITEM_INFO_RECEIVED", "INPUT_DEVICE_INTERFACE_TRANSITION", "LOOT_SLOT_CLEARED" }) do
	E.Listen(part, event, function()
		if lootOpen or (button and button:IsShown()) then
			Update()
		end
	end)
end

function part.Refresh()
	local count = E.Ask(GetNumLootItems)
	lootOpen = type(count) == "number" and count > 0 and E.Shown(LootFrame)
	looted, waitBags, fighting = lootOpen, nil, E.InCombat()
	Update()
end
part.Start = part.Refresh

function part.Status()
	local lines = {}
	local does = {}
	if E.Opt("quickLoot") == true then
		does[#does + 1] = lastTaken and ("quick loot, %d taken last time"):format(lastTaken) or "quick loot"
	end
	if E.Opt("makeRoom") == true then
		does[#does + 1] = lastDeleted and ("makes room in full bags, last deleted %s"):format(lastDeleted) or "makes room in full bags"
	end
	if #does == 0 then
		return lines
	end
	lines[1] = "Loot: " .. table.concat(does, ", ") .. "."
	if E.Opt("quickLoot") == true and type(C_CVar) == "table" and E.Ask(C_CVar.GetCVarBool, "autoLootDefault") == false then
		lines[#lines + 1] = "Loot: the game's Auto Loot is off, so Quick loot works only while its key is held."
	end
	if E.Opt("makeRoom") == true and E.Gamepad() then
		lines[#lines + 1] = "Loot: Make room has no button under the gamepad interface."
	end
	return lines
end
