local _, ns = ...

local B = ns.Bags
if type(B) ~= "table" or type(B.Slots) ~= "table" then
	return
end
local Slots = B.Slots
local E = ns.Errands

local KEY, PART = "bags", "slots"
local FIRST, LAST = 0, 5
local KEYRING = ns.Finite(KEYRING_CONTAINER) and KEYRING_CONTAINER or -1
local SLOT, GAP = 28, 4
local BACKPACK_ICON = "Interface\\Icons\\ui-hud-actionbar-bag"
local KEYRING_ICON = "Interface\\Icons\\ui-hud-actionbar-keyring"
local EMPTY_ART = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
local SLOT_NAMES = { [1] = "Bag0Slot", [2] = "Bag1Slot", [3] = "Bag2Slot", [4] = "Bag3Slot", [5] = "ReagentBag0Slot" }
local HOVER = { 1, 1, 1, 0.3 }
local DIM = { 0.8, 0.8, 0.8 }
local COUNT_FONT, COUNT_SIZE = "NumberFontNormal", 11
local ROOM, SHORT, FULL, LOW = { 1, 1, 1 }, { 1, 0.82, 0 }, { 1, 0.35, 0.24 }, 4
local CONTAINER, KEY_CLASS, REAGENT_SUB = 1, 13, 11
local BAG_EQUIP = "INVTYPE_BAG"
local SIZE_WORDS = "%d Slot %s"
local TIP_GAP = 4
local CROP = 8
local FLY_SCALE, FLY_SECONDS, FLY_FADE = 1.8, 0.45, 0.15
local FIGHT_LINE = "Flat UI: the bag slots of the bag window take no clicks in a fight."
local KEY_LINES, KEY_ICON = 12, 14
local NO_ROOM_LINE = "Flat UI: your keyring is full."

local row
local sizes = {}

local function Usable(value)
	return value ~= nil and not ns.IsSecret(value) and type(value) == "table"
end

local function Run(fn, ...)
	local part = B.Part
	if type(part) ~= "function" then
		return false
	end
	return part(PART, fn, ...)
end

local function Container(name)
	local api = C_Container
	if not Usable(api) then
		return nil
	end
	local fn = api[name]
	return type(fn) == "function" and fn or nil
end

local function Word(name, fallback)
	local text = _G[name]
	if type(text) == "string" and not ns.IsSecret(text) and text ~= "" then
		return text
	end
	return fallback
end

local function Texture(value)
	if ns.Finite(value) or (type(value) == "string" and not ns.IsSecret(value) and value ~= "") then
		return value
	end
	return nil
end

local function InventorySlot(bag)
	if bag == 0 or bag == KEYRING then
		return nil
	end
	local slot = E.Ask(Container("ContainerIDToInventoryID"), bag)
	if ns.Finite(slot) and slot > 0 then
		return slot
	end
	return nil
end

local function BagIcon(bag)
	if bag == 0 then
		return BACKPACK_ICON
	elseif bag == KEYRING then
		return KEYRING_ICON
	end
	local slot = InventorySlot(bag)
	return slot and Texture(E.Ask(GetInventoryItemTexture, "player", slot)) or nil
end

local function EmptyArt(bag)
	local name = SLOT_NAMES[bag]
	if name and type(GetInventorySlotInfo) == "function" then
		local ok, _, art = pcall(GetInventorySlotInfo, name)
		if ok and Texture(art) then
			return art
		end
	end
	return EMPTY_ART
end

local function Room(bag)
	local free = E.Ask(Container("GetContainerNumFreeSlots"), bag)
	local total = E.Ask(Container("GetContainerNumSlots"), bag)
	if ns.Finite(free) and ns.Finite(total) and total > 0 then
		return math.max(0, math.floor(free)), math.floor(total)
	end
	return nil, nil
end

local function Keys(list)
	local total = E.Ask(Container("GetContainerNumSlots"), KEYRING)
	local info = Container("GetContainerItemInfo")
	if not (info and ns.Finite(total) and total > 0) then
		return nil, nil, nil
	end
	local keys, empty = 0, nil
	for index = 1, math.floor(total) do
		local ok, item = pcall(info, KEYRING, index)
		if ok and not ns.IsSecret(item) and item == nil then
			empty = empty or index
		elseif ok and Usable(item) then
			keys = keys + 1
			local link = item.hyperlink
			if list and type(link) == "string" and not ns.IsSecret(link) and link:find("|H", 1, true) then
				list[#list + 1] = { link = link, icon = Texture(item.iconFileID), name = link:match("|h%[(.-)%]|h") or link }
			end
		end
	end
	return keys, math.floor(total), empty
end

local function Instant(id)
	local api = C_Item
	local fn = Usable(api) and api.GetItemInfoInstant or GetItemInfoInstant
	if type(fn) ~= "function" or not ns.Finite(id) then
		return nil
	end
	local ok, _, _, _, equip, _, class, sub = pcall(fn, id)
	if ok and type(equip) == "string" and not ns.IsSecret(equip) and ns.Finite(class) and ns.Finite(sub) then
		return equip, class, sub
	end
	return nil
end

local sizePattern
local function SizePattern()
	if not sizePattern then
		local words = Word("CONTAINER_SLOTS", SIZE_WORDS)
		local text = words:gsub("%%%d*%$?d", "\1"):gsub("%%%d*%$?s", "\2")
		text = text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
		sizePattern = "^" .. text:gsub("\1", "(%%d+)"):gsub("\2", ".+")
	end
	return sizePattern
end

local function ReadSize(id, get, ...)
	local known = sizes[id]
	if known then
		return known
	end
	if type(get) ~= "function" then
		return 0
	end
	local ok, data = pcall(get, ...)
	if not (ok and Usable(data) and Usable(data.lines)) then
		return 0
	end
	local pattern, size = SizePattern(), 0
	for _, line in ipairs(data.lines) do
		local text = Usable(line) and line.leftText or nil
		if type(text) == "string" and not ns.IsSecret(text) then
			local n = tonumber(text:match(pattern) or "")
			if n and n > 0 then
				size = math.floor(n)
				break
			end
		end
	end
	if size > 0 or #data.lines >= 2 then
		sizes[id] = size
	end
	return size
end

local function Tooltips(name)
	local api = C_TooltipInfo
	local fn = Usable(api) and api[name] or nil
	return type(fn) == "function" and fn or nil
end

local function BagSize(bag, slot, id)
	return ReadSize(id, Tooltips("GetBagItem"), bag, slot)
end

function Slots.SizeOf(id, link, bag, slot)
	if not ns.Finite(id) then
		return 0
	end
	if ns.Finite(bag) and ns.Finite(slot) then
		return ReadSize(id, Tooltips("GetBagItem"), bag, slot)
	end
	if type(link) == "string" and not ns.IsSecret(link) and link ~= "" then
		return ReadSize(id, Tooltips("GetHyperlink"), link)
	end
	return sizes[id] or 0
end

local function Spares()
	local count, info = Container("GetContainerNumSlots"), Container("GetContainerItemInfo")
	if not (count and info) then
		return nil, nil
	end
	local best = {}
	for bag = FIRST, LAST do
		local slots = E.Ask(count, bag)
		for slot = 1, ns.Finite(slots) and math.floor(slots) or 0 do
			local ok, item = pcall(info, bag, slot)
			local locked = ok and Usable(item) and item.isLocked
			local id = ok and Usable(item) and not ns.IsSecret(locked) and locked ~= true and item.itemID or nil
			local equip, class, sub = Instant(ns.Finite(id) and id or nil)
			if equip == BAG_EQUIP and class == CONTAINER then
				local reagent = sub == REAGENT_SUB
				local size, top = BagSize(bag, slot, id), best[reagent]
				if not top or size > top.size or (size == top.size and sub == 0 and top.sub ~= 0) then
					local link = item.hyperlink
					best[reagent] = { bag = bag, slot = slot, size = size, sub = sub, id = id,
						link = type(link) == "string" and not ns.IsSecret(link) and link or nil }
				end
			end
		end
	end
	return best[false], best[true]
end

local function SpareLabel(spare)
	local name = spare.link and spare.link:match("|h%[(.-)%]|h") or nil
	if not name then
		local api = C_Item
		name = Usable(api) and E.Ask(api.GetItemNameByID, spare.id) or nil
	end
	name = type(name) == "string" and name ~= "" and name or "a bag"
	if spare.size > 0 then
		return ("%s (%d slots)"):format(name, spare.size)
	end
	return name
end

local function Crop()
	local look = B.Look
	local crop = type(look) == "function" and look("crop") or nil
	crop = ns.Finite(crop) and crop or CROP
	return math.max(0, math.min(crop, 15)) / 100
end

local function Paint(box)
	if box then
		local r, g, b = ns.WindowColour("windows.panel")
		ns.SetOutlineFill(box, r, g, b, 1)
	end
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

local function LayoutFn(name)
	local layout = B.Layout
	local fn = Usable(layout) and layout[name] or nil
	return type(fn) == "function" and fn or nil
end

local function Light(bag)
	local light = LayoutFn("Light")
	if light then
		B.Part("layout", light, "bags", bag)
	end
end

local function Stuck()
	local stuck = LayoutFn("Stuck")
	if not stuck then
		return nil
	end
	local ok, bag = pcall(stuck, "bags")
	return ok and ns.Finite(bag) and bag or nil
end

local function Holds(bag)
	return bag == 0 or BagIcon(bag) ~= nil
end

local function SpareFor(bag, fresh)
	if bag == 0 or bag == KEYRING or not row or not InventorySlot(bag) or Holds(bag) then
		return nil
	end
	local general, reagent
	if fresh then
		general, reagent = Spares()
	else
		general, reagent = row.general, row.reagent
	end
	if bag == LAST then
		return reagent
	end
	return general
end

local function Fill(bag)
	local spare = SpareFor(bag, true)
	local inventory = InventorySlot(bag)
	if not (spare and inventory) then
		return
	end
	if E.Fighting() then
		print(FIGHT_LINE)
		return
	end
	if not E.Call(Container("PickupContainerItem"), spare.bag, spare.slot) or E.Ask(CursorHasItem) ~= true then
		return
	end
	local api = C_PaperDollInfo
	if E.Ask(Usable(api) and api.CursorCanGoInSlot or nil, inventory) == true then
		E.Call(PutItemInBag, inventory)
	else
		E.Call(ClearCursor)
	end
end

local function PutKey()
	local _, _, empty = Keys()
	if empty then
		E.Call(Container("PickupContainerItem"), KEYRING, empty)
	else
		print(NO_ROOM_LINE)
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
		local ok, frame = pcall(get, "bags")
		window = ok and Usable(frame) and frame or nil
	end
	local at, screen = window and Middle(window), Middle(UIParent)
	if not (at and screen) then
		tip:SetOwner(button, "ANCHOR_TOP")
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

local function Edge(slot, bag)
	if Stuck() == bag and Holds(bag) then
		local r, g, b = ns.WindowColour("windows.accent")
		ns.SetOutlineColour(slot.box, r, g, b)
	else
		ns.SetOutlineColour(slot.box, nil, nil, nil)
	end
end

local function Stick(bag)
	local stick = LayoutFn("Stick")
	if not stick or not Holds(bag) then
		return
	end
	B.Part("layout", stick, "bags", Stuck() ~= bag and bag or nil)
	for other, slot in pairs(row and row.slots or {}) do
		Edge(slot, other)
	end
end

local function Use(bag, how)
	local holding = E.Ask(CursorHasItem) == true
	if not holding and how ~= "drag" then
		if how == "click" and Holds(bag) then
			Stick(bag)
		elseif how == "click" then
			Fill(bag)
		end
		return
	end
	if bag == KEYRING and not (holding and how ~= "drag") then
		return
	end
	if E.Fighting() then
		print(FIGHT_LINE)
		return
	end
	if bag == KEYRING then
		PutKey()
		return
	end
	if bag == 0 then
		if holding and how ~= "drag" then
			E.Call(PutItemInBackpack)
		end
		return
	end
	local slot = InventorySlot(bag)
	if not slot then
		return
	end
	if holding and how ~= "drag" then
		local kind, id = E.Ask(GetCursorInfo)
		if kind == "item" and Instant(id) == BAG_EQUIP and Stuck() == bag then
			Stick(bag)
		end
		E.Call(PutItemInBag, slot)
	elseif not holding and how == "drag" then
		if Stuck() == bag then
			Stick(bag)
		end
		E.Call(PickupBagFromSlot, slot)
	end
end

local function Click(button, bag, mouse)
	if mouse == "RightButton" and E.Ask(CursorHasItem) ~= true then
		local menu = bag ~= KEYRING and LayoutFn("BagMenuOf") or nil
		if menu then
			B.Part("layout", menu, "bags", bag, button)
		end
		return
	end
	Use(bag, "click")
end

local function FlagLines(tip, bag)
	local flags = LayoutFn("BagFlags")
	if not flags then
		return
	end
	local ok, sortOff, junkOff, assigned = pcall(flags, bag)
	if not ok then
		return
	end
	if type(assigned) == "string" and assigned ~= "" then
		tip:AddLine(("Assigned to: %s"):format(assigned), 1, 1, 1, true)
	end
	if sortOff == true then
		tip:AddLine("Clean up leaves this bag alone.", DIM[1], DIM[2], DIM[3], true)
	end
	if junkOff == true then
		tip:AddLine("Sell junk leaves this bag alone.", DIM[1], DIM[2], DIM[3], true)
	end
end

local function KeyTip(tip, button)
	Anchor(tip, button)
	tip:SetText(Word("KEYRING", "Keyring"), 1, 1, 1)
	local list = {}
	local keys = Keys(list)
	if keys == 0 then
		tip:AddLine("No keys yet.", DIM[1], DIM[2], DIM[3])
	elseif keys then
		tip:AddLine(keys == 1 and "1 key" or ("%d keys"):format(keys), 1, 1, 1)
		table.sort(list, function(a, b)
			return a.name < b.name
		end)
		for index = 1, math.min(#list, KEY_LINES) do
			local key = list[index]
			local icon = key.icon and ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t "):format(tostring(key.icon), KEY_ICON, KEY_ICON) or ""
			tip:AddLine(icon .. key.link, 1, 1, 1)
		end
		if #list > KEY_LINES then
			tip:AddLine(("and %d more"):format(#list - KEY_LINES), DIM[1], DIM[2], DIM[3])
		end
	end
	tip:AddLine("Drop a key here to put it on your keyring.", DIM[1], DIM[2], DIM[3], true)
	tip:AddLine(Stuck() == KEYRING and "Click again to show every bag." or "Click to show only your keyring.", DIM[1], DIM[2], DIM[3], true)
	tip:Show()
end

local function SlotTip(button, bag)
	local tip = GameTooltip
	if not Usable(tip) or ns.Forbidden(tip) then
		return
	end
	if bag == KEYRING then
		KeyTip(tip, button)
		return
	end
	local slot = InventorySlot(bag)
	local held = bag == 0 or BagIcon(bag) ~= nil
	Anchor(tip, button)
	local shown = false
	if held and slot and not E.Fighting() then
		local ok, has = pcall(tip.SetInventoryItem, tip, "player", slot)
		shown = ok and not ns.IsSecret(has) and has == true
		if not shown then
			Anchor(tip, button)
		end
	end
	if not shown then
		if bag == 0 then
			tip:SetText(Word("BAG_NAME_BACKPACK", "Backpack"))
		elseif held then
			local name = E.Ask(Container("GetBagName"), bag)
			tip:SetText(type(name) == "string" and name ~= "" and name or "Bag")
		else
			tip:SetText(bag == LAST and Word("EQUIP_CONTAINER_REAGENT", "Equip Reagent Bag") or Word("EQUIP_CONTAINER", "Equip Container"))
			local spare = SpareFor(bag, true)
			if spare then
				tip:AddLine(("Click to put in %s from your bags."):format(SpareLabel(spare)), 1, 1, 1, true)
				tip:AddLine("Or drag a bag from your bags here.", DIM[1], DIM[2], DIM[3], true)
			else
				tip:AddLine("Drag a bag from your bags here to put it in this slot.", DIM[1], DIM[2], DIM[3], true)
			end
		end
	end
	local free, total = Room(bag)
	if held and free then
		tip:AddLine(("%d of %d slots free"):format(free, total), 1, 1, 1)
	end
	if held then
		FlagLines(tip, bag)
		local click = Stuck() == bag and "Click again to show every bag" or "Click to show only this bag"
		if bag ~= 0 then
			click = click .. "; drag it to pick it up, or drop another bag on it to swap."
		else
			click = click .. "."
		end
		tip:AddLine(click, DIM[1], DIM[2], DIM[3], true)
		tip:AddLine("Right-click for this bag's settings.", DIM[1], DIM[2], DIM[3], true)
	end
	tip:Show()
end

local function Retip(button, bag)
	local tip = GameTooltip
	if not Usable(tip) or ns.Forbidden(tip) then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, button)
	if ok and not ns.IsSecret(owned) and owned == true then
		SlotTip(button, bag)
	end
end

local function MakeSlot(bag)
	local button = CreateFrame("Button", nil, row.frame)
	ns.Own[button] = true
	button:SetSize(SLOT, SLOT)
	local slot = { button = button, box = ns.Outline(button, button) }
	slot.icon = button:CreateTexture(nil, "ARTWORK")
	ns.Own[slot.icon] = true
	slot.icon:SetAllPoints(button)
	local hover = button:CreateTexture(nil, "HIGHLIGHT")
	ns.Own[hover] = true
	hover:SetAllPoints(button)
	hover:SetColorTexture(HOVER[1], HOVER[2], HOVER[3], HOVER[4])
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
		Run(Click, self, bag, mouse)
		if mouse ~= "RightButton" then
			Run(Retip, self, bag)
		end
	end)
	button:SetScript("OnDragStart", function()
		Run(Use, bag, "drag")
	end)
	button:SetScript("OnReceiveDrag", function()
		Run(Use, bag, "drop")
	end)
	button:SetScript("OnEnter", function(self)
		Run(SlotTip, self, bag)
		if Holds(bag) then
			Light(bag)
		end
	end)
	button:SetScript("OnLeave", function(self)
		Run(TipGone, self)
		Light(nil)
	end)
	button:SetScript("OnHide", function(self)
		Run(TipGone, self)
	end)
	row.slots[bag] = slot
	return slot
end

local function DrawCount(slot, bag, held)
	local text = slot.count
	if not text then
		return
	end
	if bag == KEYRING then
		local keys = Keys()
		if keys then
			text:SetTextColor(ROOM[1], ROOM[2], ROOM[3], 1)
			text:SetText(tostring(keys))
			text:Show()
		else
			text:Hide()
		end
		return
	end
	local free = held and Room(bag) or nil
	if not free then
		text:Hide()
		return
	end
	local colour = free == 0 and FULL or free <= LOW and SHORT or ROOM
	text:SetTextColor(colour[1], colour[2], colour[3], 1)
	text:SetText(tostring(free))
	text:Show()
end

local function Lifted(bag)
	local slot = InventorySlot(bag)
	return slot ~= nil and E.Ask(IsInventoryItemLocked, slot) == true
end

local function DrawSlot(slot, bag, crop)
	local icon = BagIcon(bag)
	if icon then
		slot.icon:SetTexture(icon)
		slot.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
		slot.icon:SetAlpha(1)
		pcall(slot.icon.SetDesaturated, slot.icon, Lifted(bag))
	else
		slot.icon:SetTexture(EmptyArt(bag))
		slot.icon:SetTexCoord(0, 1, 0, 1)
		slot.icon:SetAlpha(0.5)
		pcall(slot.icon.SetDesaturated, slot.icon, false)
	end
	slot.icon:Show()
	DrawCount(slot, bag, icon ~= nil)
	Paint(slot.box)
	Edge(slot, bag)
end

local function Showing()
	if not row then
		return false
	end
	local ok, visible = pcall(row.frame.IsVisible, row.frame)
	return ok and visible == true
end

local function KeyHeld()
	local kind, id = E.Ask(GetCursorInfo)
	if kind ~= "item" then
		return false
	end
	local _, class = Instant(id)
	return class == KEY_CLASS
end

local function Fits()
	local api = C_PaperDollInfo
	local can = Usable(api) and api.CursorCanGoInSlot or nil
	local holding = E.Ask(CursorHasItem) == true
	local key = holding and row.slots[KEYRING] ~= nil and KeyHeld()
	for bag, slot in pairs(row.slots) do
		local inventory = InventorySlot(bag)
		local lit
		if bag == KEYRING then
			lit = key
		elseif holding then
			lit = inventory ~= nil and E.Ask(can, inventory) == true
		else
			lit = SpareFor(bag) ~= nil
		end
		if lit then
			slot.button:LockHighlight()
		else
			slot.button:UnlockHighlight()
		end
	end
end

local function Fly(slot, icon)
	if slot.fly == nil then
		local ok, fly, group = pcall(function()
			local texture = slot.button:CreateTexture(nil, "OVERLAY", nil, 7)
			ns.Own[texture] = true
			texture:SetAllPoints(slot.button)
			texture:Hide()
			local made = texture:CreateAnimationGroup()
			local scale = made:CreateAnimation("Scale")
			scale:SetScaleFrom(FLY_SCALE, FLY_SCALE)
			scale:SetScaleTo(1, 1)
			scale:SetOrigin("CENTER", 0, 0)
			scale:SetDuration(FLY_SECONDS)
			scale:SetSmoothing("IN")
			local alpha = made:CreateAnimation("Alpha")
			alpha:SetFromAlpha(1)
			alpha:SetToAlpha(0)
			alpha:SetStartDelay(FLY_FADE)
			alpha:SetDuration(FLY_SECONDS - FLY_FADE)
			made:SetScript("OnFinished", function()
				texture:Hide()
			end)
			made:SetScript("OnStop", function()
				texture:Hide()
			end)
			return texture, made
		end)
		slot.fly = ok and fly or false
		slot.flyGroup = ok and group or nil
	end
	if not slot.fly then
		return
	end
	local crop = Crop()
	slot.flyGroup:Stop()
	slot.fly:SetTexture(icon)
	slot.fly:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	slot.fly:Show()
	slot.flyGroup:Play()
end

local function Update()
	local frame = row.frame
	local crop, x, empty = Crop(), 0, false
	for bag = FIRST, LAST do
		local slot = row.slots[bag]
		if bag == 0 or InventorySlot(bag) then
			slot = slot or MakeSlot(bag)
			slot.button:ClearAllPoints()
			slot.button:SetPoint("LEFT", frame, "LEFT", x, 0)
			DrawSlot(slot, bag, crop)
			slot.button:Show()
			x = x + SLOT + GAP
			empty = empty or not Holds(bag)
		elseif slot then
			slot.button:Hide()
		end
	end
	local keyring = row.slots[KEYRING]
	if Usable(C_ActionBar) and E.Ask(C_ActionBar.ShouldShowKeyring) == true then
		keyring = keyring or MakeSlot(KEYRING)
		x = x + GAP
		keyring.button:ClearAllPoints()
		keyring.button:SetPoint("LEFT", frame, "LEFT", x, 0)
		DrawSlot(keyring, KEYRING, crop)
		keyring.button:Show()
		x = x + SLOT + GAP
	elseif keyring then
		keyring.button:Hide()
	end
	if empty then
		row.general, row.reagent = Spares()
	else
		row.general, row.reagent = nil, nil
	end
	local width = math.max(x - GAP, 1)
	frame:SetSize(width, SLOT)
	frame:Show()
	Fits()
	return width, SLOT
end

function Slots.Row(frame)
	local width, height = 0, 0
	Run(function()
		if not Usable(frame) or ns.Forbidden(frame) then
			return
		end
		if not row then
			local holder = CreateFrame("Frame", nil, frame)
			ns.Own[holder] = true
			holder:SetSize(1, SLOT)
			row = { frame = holder, parent = frame, slots = {} }
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

local function SlotOf(inventory)
	for bag, slot in pairs(row.slots) do
		if (bag == 0 and inventory == 0) or (bag ~= 0 and InventorySlot(bag) == inventory) then
			return slot, bag
		end
	end
	return nil
end

ns.AddEvent(KEY, "CURSOR_CHANGED", function()
	if Showing() then
		Run(Fits)
	end
end)

ns.AddEvent(KEY, "ITEM_LOCK_CHANGED", function(inventory)
	if Showing() then
		Run(function()
			local slot, bag = SlotOf(inventory)
			if slot and slot.button:IsShown() then
				DrawSlot(slot, bag, Crop())
			end
		end)
	end
end, function(inventory, slot)
	return ns.Finite(inventory) and slot == nil
end)

ns.AddEvent(KEY, "ITEM_PUSH", function(inventory, icon)
	if Showing() then
		Run(function()
			local slot = SlotOf(inventory)
			icon = Texture(icon)
			if slot and icon and slot.button:IsShown() then
				Fly(slot, icon)
			end
		end)
	end
end, function(inventory)
	return ns.Finite(inventory)
end)
