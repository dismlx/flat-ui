local _, ns = ...

-- Window titles and item slots. This is not a module: the windows module calls ns.Items from its window frames, its item slots and its bag
-- and bank hooks, and its Refresh calls ns.Items.Apply. The title of a window is TitleContainer.TitleText (Blizzard_SharedXML/PortraitFrame.lua:4-14);
-- a dialog whose title is in a Header has none and is left alone. A slot's bag is read with button:GetBagID() (Blizzard_UIPanels_Game/
-- Mainline/ContainerFrame.lua:1845-1847) and a bank slot's with GetBankTabID and GetContainerSlotID (Mainline/BankFrameTemplates.lua:494, 521).
-- Every item button has a GetBagID, which reads the field bagID of ItemButtonMixin (Blizzard_ItemButton/Shared/ItemButtonTemplate.lua:247-253;
-- Shared/ItemButtonTemplate.xml:4 gives the mixin to every ItemButton), so the slots of the Character and Inspect windows and the buttons of the
-- equipment flyout are known by their names, before that.
-- Every row at its default makes no call the game does not make, and a row put back to its default gives the game's own value back, with one
-- exception: Item level on the Inspect window is on, and reads the items of the player the window shows once the game says it has them.
-- The levels of the equipment flyout and of the Inspect window, the inspected player's average and the corner of a level on gear follow
-- EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission.

local KEY = "windows"
local PART = "item details"

-- The lowest quality each choice of Quality border from draws, and the quality colours that are compared to find where a colour belongs.
local MIN_QUALITY = { all = 0, uncommon = 2, rare = 3, epic = 4 }
local WEAPON, ARMOUR = 2, 4
local LEVEL_FONT = "NumberFontNormal"
local AVERAGE_FONT = "GameFontHighlightSmall"
local WHITE, GOLD = { 1, 1, 1 }, { 1, 0.82, 0 }
-- Where the item level of a slot of the Character or Inspect window sits (Item level corner on gear): the point of the text and of the slot, and
-- the offset. Every other slot keeps the first.
local CORNERS = {
	bottomLeft = { "BOTTOMLEFT", 2, 2 },
	bottomRight = { "BOTTOMRIGHT", -2, 2 },
	topLeft = { "TOPLEFT", 2, -2 },
	topRight = { "TOPRIGHT", -2, -2 },
}
local GEAR = { char = true, inspect = true }
-- The slots of the Inspect window (INSPECTPAPERDOLLFRAME_SLOTS, Blizzard_InspectUI/Camelot/Blizzard_InspectUI.lua:13-33), the function that
-- fills one (Mainline/InspectPaperDollFrame.lua:245-273) and the addon that holds them, which the game loads the first time it inspects.
local INSPECT_SLOTS = { "InspectHeadSlot", "InspectNeckSlot", "InspectShoulderSlot", "InspectBackSlot", "InspectChestSlot", "InspectShirtSlot",
	"InspectTabardSlot", "InspectWristSlot", "InspectHandsSlot", "InspectWaistSlot", "InspectLegsSlot", "InspectFeetSlot", "InspectFinger0Slot",
	"InspectFinger1Slot", "InspectTrinket0Slot", "InspectTrinket1Slot", "InspectMainHandSlot", "InspectSecondaryHandSlot", "InspectRangedSlot" }
local INSPECT_UPDATE = "InspectPaperDollItemSlotButton_Update"
local INSPECT_ADDON = "Blizzard_InspectUI"
-- The function that fills a button of the equipment flyout with the item at its location (Blizzard_FrameXML/Camelot/EquipmentFlyout.lua:533-580).
local FLYOUT_BUTTON = "EquipmentFlyout_DisplayButton"
-- How a location of the flyout is made, for a client whose globals do not say: the flags of a worn item, a bag and the bank, the shift of the bag
-- (Blizzard_FrameXMLBase/Constants.lua:129-132), and the first of the three locations that hold no item (EquipmentFlyout.lua:32-35).
local LOCATION = { player = 0x00100000, bags = 0x00200000, bank = 0x00400000, shift = 8, special = 0xFFFFFFFD }

-- The slots this file looks at, by button: { kind = "bag", "bank", "char" (the player's slots), "inspect" (the Inspect window's) or "flyout" (the
-- buttons of the equipment flyout), level = the item level text, corner = the spot it was put at, dim = the dim texture, hidGlow = true while the
-- new item glow is hidden here }.
local buttons = setmetatable({}, { __mode = "k" })
-- What the game answers for the colour of each quality from 0 to 4, read at each refresh: { quality, r, g, b }.
local ranks
-- True once a row of the bag, bank or character slots away from its default has been applied, so that nothing is read for those slots while
-- every one of their rows is at its default.
local touched = false
-- Parts the game refused: the part is off and says so on /flatui status.
local refused = {}
local burst = false
-- The Inspect window: ready is the GUID INSPECT_READY last named for the unit the window shows, average the text of that player's average,
-- queued true while a pass over the average waits for the next frame, and seen true once the slots of the window were dressed.
local inspect = { ready = nil, average = nil, queued = false, seen = false }

local Items = {}
ns.Items = Items

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Usable(value)
	return value ~= nil and not ns.IsSecret(value) and type(value) == "table"
end

-- A frame or region held in a field of a frame that may not be touched or withheld.
local function Held(frame, key)
	if ns.Forbidden(frame) then
		return nil
	end
	local value = frame[key]
	if Usable(value) then
		return value
	end
	return nil
end

-- Any value held in a field of a frame, unless the frame may not be touched or the client withholds the value.
local function FieldOf(frame, key)
	if ns.Forbidden(frame) then
		return nil
	end
	local value = frame[key]
	if ns.IsSecret(value) then
		return nil
	end
	return value
end

-- A number the game keeps in a global, or the fallback when it keeps none.
local function Constant(name, fallback)
	local value = _G[name]
	if ns.Finite(value) then
		return value
	end
	return fallback
end

-- Runs fn on the next frame.
local function Soon(fn)
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(0, fn)
	else
		fn()
	end
end

local function Refuse(part, text)
	refused[part] = true
	ns.Note(KEY, text)
end

local function NameOf(frame)
	local ok, name = pcall(frame.GetName, frame)
	if ok and not ns.IsSecret(name) and type(name) == "string" then
		return name
	end
	return nil
end

-- True when the game would refuse to make a texture or text on the frame now.
local function Blocked(frame)
	if not InCombatLockdown() then
		return false
	end
	local ok, protected = pcall(frame.IsProtected, frame)
	return not ok or ns.IsSecret(protected) or protected == true
end

-- Titles ----------------------------------------------------------------------------------

local function TitleOf(frame)
	local container = Held(frame, "TitleContainer")
	return container and Held(container, "TitleText") or nil
end

-- The game colours a title only through SetTitleColor, which sets the text colour. Its windows call it from their own methods (the
-- character window in UpdateTitle, CharacterFrame.lua:242-246, on show, on a tab change and on the name and rank events), so the colour
-- is set again a frame after each of those: when a titled window is shown, and when the windows module calls Items.Retitle.
local titled = setmetatable({}, { __mode = "k" })
local shownHooked = setmetatable({}, { __mode = "k" })
local retitleQueued = false

local function OnTitleColour(frame)
	if ns.Enabled(KEY) and Opt("titleOwn") and not refused.titles then
		local text = TitleOf(frame)
		if text then
			local r, g, b = ns.Colour(KEY .. ".titleColour")
			pcall(text.SetTextColor, text, r, g, b, 1)
		end
	end
end

-- Sets the size and colour of the title of a window, or gives the game's back.
function Items.Title(frame, on)
	local text = TitleOf(frame)
	if text == nil then
		return
	end
	local spec = {}
	local live = on and not refused.titles
	if live then
		spec.percent = Opt("titleSize")
		if Opt("titleOwn") then
			spec.r, spec.g, spec.b = ns.Colour(KEY .. ".titleColour")
			spec.a = 1
		end
	end
	if ns.TextStyle(text, spec) == false and live then
		Refuse("titles", "Windows: Title size and Own title colour stopped, the game refused the font of a title.")
		ns.TextStyle(text, {})
	end
	if live and spec.r then
		titled[frame] = true
		if not shownHooked[frame] and type(frame.HookScript) == "function" then
			shownHooked[frame] = pcall(frame.HookScript, frame, "OnShow", function()
				Items.Retitle()
			end)
		end
	else
		titled[frame] = nil
	end
end

local function Retitled()
	retitleQueued = false
	for frame in pairs(titled) do
		ns.EachPart(KEY, PART, OnTitleColour, frame)
	end
end

-- Sets the own colour of every titled window again, a frame from now.
function Items.Retitle()
	if retitleQueued or next(titled) == nil then
		return
	end
	retitleQueued = true
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(0, Retitled)
	else
		Retitled()
	end
end

-- Quality ---------------------------------------------------------------------------------

local function ReadRanks()
	local list = {}
	local manager = _G.ColorManager
	if type(manager) == "table" and not ns.IsSecret(manager) and type(manager.GetColorDataForBagItemQuality) == "function" then
		for quality = 0, 4 do
			local ok, colour = pcall(manager.GetColorDataForBagItemQuality, quality)
			if ok and Usable(colour) and ns.Finite(colour.r) and ns.Finite(colour.g) and ns.Finite(colour.b) then
				list[#list + 1] = { quality, colour.r, colour.g, colour.b }
			end
		end
	end
	return list
end

-- True when a slot whose border has this colour is drawn with it. Poor to epic are found by comparing the colour, within 0.01, with the game's
-- colour of each quality; a colour that is none of them is a better quality than epic.
function Items.Passes(colour)
	local least = MIN_QUALITY[Opt("qualityMin")] or 0
	if least == 0 then
		return true
	end
	ranks = ranks or ReadRanks()
	if #ranks == 0 then
		Refuse("qualityMin", "Windows: Quality border from stopped, the game's item colours were not found.")
		return true
	end
	local rank = 5
	for _, entry in ipairs(ranks) do
		if math.abs(entry[2] - colour[1]) <= 0.01 and math.abs(entry[3] - colour[2]) <= 0.01 and math.abs(entry[4] - colour[3]) <= 0.01 then
			rank = entry[1]
			break
		end
	end
	return rank >= least
end

-- The inspected player ------------------------------------------------------------------------

-- The Inspect window keeps the unit it shows in its field unit: InspectFrame_Show sets it before the game asks the server for that player's
-- items, and the window clears it when it hides (Camelot/Blizzard_InspectUI.lua:41-50, 144-152). The game names the player's GUID in INSPECT_READY
-- once it has them (PaperDollInfoDocumentation.lua:349-358) and fills its slots then (Mainline/InspectPaperDollFrame.lua:12-27, 63-73); its own
-- window asks for every inspection, and this file never does.
local function InspectedUnit()
	local frame = _G.InspectFrame
	if not Usable(frame) then
		return nil
	end
	local unit = FieldOf(frame, "unit")
	return type(unit) == "string" and unit or nil
end

local function GuidOf(unit)
	if type(UnitGUID) ~= "function" then
		return nil
	end
	local ok, guid = pcall(UnitGUID, unit)
	if ok and not ns.IsSecret(guid) and type(guid) == "string" then
		return guid
	end
	return nil
end

-- The unit the Inspect window shows, once INSPECT_READY has named it: only then are its items read.
local function ReadyUnit()
	local unit = InspectedUnit()
	if unit and inspect.ready and GuidOf(unit) == inspect.ready then
		return unit
	end
	return nil
end

-- Slots --------------------------------------------------------------------------------------

local function AllDefault()
	return Opt("countSize") == 100 and not Opt("ilvlBags") and not Opt("ilvlCharacter") and Opt("newGlow") and not Opt("junkDim")
end

local function Idle()
	return not touched and AllDefault()
end

-- The size of the stack count of a slot.
local function Count(button, live)
	local text = Held(button, "Count")
	if text == nil then
		local name = NameOf(button)
		local found = name and _G[name .. "Count"]
		text = Usable(found) and found or nil
	end
	if text == nil then
		return
	end
	local percent = live and not refused.counts and Opt("countSize") or 100
	if ns.TextSize(text, percent) == false and percent ~= 100 then
		Refuse("counts", "Windows: Stack count size stopped, the game refused the font of a stack count.")
		ns.TextSize(text, 100)
	end
end

-- The link of an item a unit wears in an inventory slot.
local function WornLink(unit, slot)
	if type(GetInventoryItemLink) ~= "function" then
		return nil
	end
	local ok, link = pcall(GetInventoryItemLink, unit, slot)
	return ok and not ns.IsSecret(link) and type(link) == "string" and link or nil
end

-- The link and the container item info of a bag slot, and the bag and slot.
local function BagItem(bag, slot)
	if type(C_Container) ~= "table" or not ns.Finite(bag) or not ns.Finite(slot) then
		return nil
	end
	local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
	if not ok or not Usable(info) then
		return nil, nil, bag, slot
	end
	local link = info.hyperlink
	if ns.IsSecret(link) or type(link) ~= "string" then
		link = nil
	end
	return link, info, bag, slot
end

-- The bag and slot of an item of the equipment flyout, or nil and the inventory slot of a worn one, from the location the game gave its button
-- (EquipmentFlyout.lua:373), read as EquipmentManager_GetLocationData reads it (Blizzard_FrameXML/Shared/EquipmentManager.lua:1-28). Nothing for a
-- location that holds no item: none, Leave this slot alone, Put in bags (EquipmentFlyout.lua:533-542, 582-628), and a bank bag the game has no
-- offset for (Constants.lua:172).
local function Located(location)
	if not ns.Finite(location) or location < 0 or location % 1 ~= 0
		or location >= Constant("EQUIPMENTFLYOUT_FIRST_SPECIAL_LOCATION", LOCATION.special) then
		return nil
	end
	local player = Constant("ITEM_INVENTORY_LOCATION_PLAYER", LOCATION.player)
	local bags = Constant("ITEM_INVENTORY_LOCATION_BAGS", LOCATION.bags)
	local bank = Constant("ITEM_INVENTORY_LOCATION_BANK", LOCATION.bank)
	local function Has(flag)
		return flag > 0 and math.floor(location / flag) % 2 == 1
	end
	local inBags, inBank, slot = Has(bags), Has(bank), location
	if Has(player) then
		slot = slot - player
	elseif inBank then
		slot = slot - bank
	end
	if not inBags then
		return nil, math.floor(slot)
	end
	local step = math.floor(2 ^ Constant("ITEM_INVENTORY_BAG_BIT_OFFSET", LOCATION.shift) + 0.5)
	slot = slot - bags
	local bag = math.floor(slot / step)
	slot = slot - bag * step
	if inBank then
		local offset = Constant("ITEM_INVENTORY_BANK_BAG_OFFSET", nil)
		if offset == nil then
			return nil
		end
		bag = bag + offset
	end
	return math.floor(bag), math.floor(slot)
end

-- The item link and the container item info of a slot, and the bag and slot they came from.
local function Source(button, kind)
	if kind == "char" then
		return WornLink("player", button:GetID())
	elseif kind == "inspect" then
		local unit = ReadyUnit()
		return unit and WornLink(unit, button:GetID()) or nil
	elseif kind == "flyout" then
		local bag, slot = Located(FieldOf(button, "location"))
		if slot == nil then
			return nil
		elseif bag == nil then
			return WornLink("player", slot)
		end
		return BagItem(bag, slot)
	end
	if type(C_Container) ~= "table" then
		return nil
	end
	local bag, slot
	if kind == "bank" then
		bag, slot = button:GetBankTabID(), button:GetContainerSlotID()
	else
		bag, slot = button:GetBagID(), button:GetID()
	end
	return BagItem(bag, slot)
end

-- True for an item of poor quality that a vendor buys.
local function Junk(info)
	if info == nil then
		return false
	end
	local quality, noValue = info.quality, info.hasNoValue
	if ns.IsSecret(quality) or ns.IsSecret(noValue) then
		return false
	end
	return quality == 0 and noValue == false
end

local function LevelOf(link)
	if link == nil or type(C_Item) ~= "table" then
		return nil
	end
	local ok, _, _, _, _, _, class = pcall(C_Item.GetItemInfoInstant, link)
	if not ok or ns.IsSecret(class) or (class ~= WEAPON and class ~= ARMOUR) then
		return nil
	end
	local okLevel, level = pcall(C_Item.GetDetailedItemLevelInfo, link)
	if okLevel and ns.Finite(level) and level > 0 then
		return level
	end
	return nil
end

local function LevelColour(link, info)
	local choice = Opt("ilvlColour")
	if choice == "white" then
		return WHITE[1], WHITE[2], WHITE[3]
	elseif choice == "gold" then
		return GOLD[1], GOLD[2], GOLD[3]
	end
	local quality = info and info.quality
	if not ns.Finite(quality) and type(C_Item) == "table" then
		local ok, found = pcall(C_Item.GetItemQualityByID, link)
		quality = ok and found or nil
	end
	local manager = _G.ColorManager
	if ns.Finite(quality) and type(manager) == "table" and not ns.IsSecret(manager) and type(manager.GetColorDataForBagItemQuality) == "function" then
		local ok, colour = pcall(manager.GetColorDataForBagItemQuality, quality)
		if ok and Usable(colour) and ns.Finite(colour.r) and ns.Finite(colour.g) and ns.Finite(colour.b) then
			return colour.r, colour.g, colour.b
		end
	end
	return WHITE[1], WHITE[2], WHITE[3]
end

local Dress

-- Takes up the slot again once the game lets text and textures be made on it.
local function Later(button, entry)
	if not entry.queued then
		entry.queued = true
		ns.OutOfCombat(function()
			entry.queued = nil
			ns.EachPart(KEY, PART, Dress, button, entry)
		end)
	end
end

-- Puts the item level of a slot in its corner: a slot of the Character or Inspect window where Item level corner on gear says, any other at the
-- bottom left. It is moved only when the corner changes.
local function Place(text, button, entry)
	local spot = GEAR[entry.kind] and CORNERS[Opt("ilvlCorner")] or CORNERS.bottomLeft
	if entry.corner == spot then
		return
	end
	if entry.corner ~= nil then
		pcall(text.ClearAllPoints, text)
	end
	pcall(text.SetPoint, text, spot[1], button, spot[1], spot[2], spot[3])
	entry.corner = spot
end

-- Gives an item level text of this file the size of Item level size, a colour and its words, and shows it. A font the game refuses stops the
-- item details.
local function Fill(text, record, r, g, b, words)
	local size = Opt("ilvlSize")
	if record.levelSize ~= size and record.levelFile then
		if not pcall(text.SetFont, text, record.levelFile, size, "OUTLINE") then
			Refuse(PART, "Windows: item level stopped, the game refused the font of an item level.")
			pcall(text.Hide, text)
			return
		end
		record.levelSize = size
	end
	pcall(text.SetTextColor, text, r, g, b, 1)
	pcall(text.SetText, text, words)
	pcall(text.Show, text)
end

local function Level(button, entry, link, info, want)
	local text = entry.level
	local value = want and LevelOf(link) or nil
	if value == nil then
		if text then
			pcall(text.Hide, text)
		end
		return
	end
	if text == nil then
		if Blocked(button) then
			Later(button, entry)
			return
		end
		text = ns.OwnText(button, "OVERLAY", LEVEL_FONT)
		if text == nil then
			Refuse(PART, "Windows: item level stopped, the game refused a text on an item slot.")
			return
		end
		entry.level = text
		local ok, file = pcall(text.GetFont, text)
		entry.levelFile = ok and not ns.IsSecret(file) and type(file) == "string" and file or nil
	end
	Place(text, button, entry)
	local r, g, b = LevelColour(link, info)
	Fill(text, entry, r, g, b, tostring(value))
end

local function Dim(button, entry, want)
	local texture = entry.dim
	if not want then
		if texture then
			pcall(texture.Hide, texture)
		end
		return
	end
	if texture == nil then
		if Blocked(button) then
			Later(button, entry)
			return
		end
		local ok, made = pcall(button.CreateTexture, button, nil, "OVERLAY", nil, 3)
		if not ok or not Usable(made) then
			Refuse(PART, "Windows: dim grey items stopped, the game refused a texture on an item slot.")
			return
		end
		ns.Own[made] = true
		made:SetColorTexture(0, 0, 0, 0.5)
		made:SetAllPoints(Held(button, "icon") or Held(button, "Icon") or button)
		texture = made
		entry.dim = made
	end
	pcall(texture.Show, texture)
end

-- The new item glow and its flash are shown by the game on every update of the bag, so they are hidden again after it.
local function Glow(button, entry, hide, bag, slot)
	if hide then
		ns.SetHidden(Held(button, "NewItemTexture"), true)
		ns.SetHidden(Held(button, "flash"), true)
		entry.hidGlow = true
	elseif entry.hidGlow then
		entry.hidGlow = nil
		ns.SetHidden(Held(button, "flash"), false)
		local isNew = false
		if bag and slot and type(C_NewItems) == "table" then
			local ok, found = pcall(C_NewItems.IsNewItem, bag, slot)
			isNew = ok and found == true
		end
		ns.SetHidden(Held(button, "NewItemTexture"), not isNew)
	end
end

-- Whether the rows want an item level on a slot of this kind. The flyout shows the bag items for a slot of the Character window, so it has
-- them only with Item level on equipped gear.
local function Wanted(kind)
	if kind == "bag" or kind == "bank" then
		return Opt("ilvlBags")
	elseif kind == "char" then
		return Opt("ilvlCharacter")
	elseif kind == "flyout" then
		return Opt("ilvlCharacter") and Opt("ilvlFlyout")
	end
	return Opt("ilvlInspect")
end

-- Applies the rows to one slot.
function Dress(button, entry)
	local live = ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and not refused[PART]
	Count(button, ns.Enabled(KEY))
	local bagLike = entry.kind == "bag" or entry.kind == "bank"
	local wantLevel = live and Wanted(entry.kind) or false
	local wantDim = live and bagLike and Opt("junkDim") or false
	local hideGlow = live and entry.kind == "bag" and not Opt("newGlow")
	if (wantLevel and (bagLike or entry.kind == "char")) or wantDim or hideGlow or Opt("countSize") ~= 100 then
		touched = true
	end
	if not (wantLevel or wantDim or entry.level or entry.dim or hideGlow or entry.hidGlow) then
		return
	end
	local read, link, info, bag, slot = pcall(Source, button, entry.kind)
	if not read then
		link, info, bag, slot = nil, nil, nil, nil
	end
	Level(button, entry, link, info, wantLevel)
	if bagLike then
		Dim(button, entry, wantDim and Junk(info))
	end
	if entry.kind == "bag" then
		Glow(button, entry, hideGlow, bag, slot)
	end
end

-- The kind of a slot, by its name first (see the top of this file). The bag bar's slots are named CharacterBag0Slot and the like.
local function KindOf(button)
	local name = NameOf(button)
	if name then
		if name:find("^Character%u%w*Slot$") and not name:find("Bag", 1, true) then
			return "char"
		elseif name:find("^Inspect%u%w*Slot$") then
			return "inspect"
		elseif name:find("^EquipmentFlyoutFrameButton%d+$") then
			return "flyout"
		end
	end
	if type(button.GetBankTabID) == "function" and type(button.GetContainerSlotID) == "function" then
		return "bank"
	elseif type(button.GetBagID) == "function" then
		return "bag"
	end
	return nil
end

local function EntryOf(button, kind)
	local entry = buttons[button]
	if entry == nil then
		entry = { kind = kind }
		buttons[button] = entry
	end
	return entry
end

local function OnBank(button)
	if Usable(button) and (buttons[button] or not Idle()) then
		ns.EachPart(KEY, PART, Dress, button, EntryOf(button, "bank"))
	end
end

-- The game's Refresh of a bank slot ends by setting the slot's quality (BankFrameTemplates.lua:567-571) and then its frame art
-- (Camelot/BankFrame.lua:254-262), so a slot is dressed a frame after SetItemButtonQuality is called for it.
local bankPending, bankQueued = {}, false

local function BankDressed()
	bankQueued = false
	local work = bankPending
	bankPending = {}
	for button in pairs(work) do
		OnBank(button)
	end
end

local function OnQuality(button)
	if Usable(button) and buttons[button] and buttons[button].kind == "bank" then
		bankPending[button] = true
		if not bankQueued then
			bankQueued = true
			if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
				C_Timer.After(0, BankDressed)
			else
				BankDressed()
			end
		end
	end
end

local function OnPaperDoll(button)
	if Usable(button) and (buttons[button] or not Idle()) and not ns.Forbidden(button) and KindOf(button) == "char" then
		ns.EachPart(KEY, PART, Dress, button, EntryOf(button, "char"))
	end
end

-- The game filled a button of the equipment flyout. It does so for every button of the page each time it fills the flyout, which is every
-- frame while the flyout is pinned open (EquipmentFlyout.lua:142-162, 646-653), and dressing a button reads only its item.
local function OnFlyoutButton(button)
	if Usable(button) and not ns.Forbidden(button) and (buttons[button] or (ns.Enabled(KEY) and Opt("ilvlCharacter") and Opt("ilvlFlyout"))) then
		ns.EachPart(KEY, PART, Dress, button, EntryOf(button, "flyout"))
	end
end

-- The Inspect window ------------------------------------------------------------------------

-- The inspected player's average: C_PaperDollInfo.GetInspectItemLevel (PaperDollInfoDocumentation.lua:122-135), or nil.
local function InspectLevel(unit)
	local info = C_PaperDollInfo
	local call = type(info) == "table" and not ns.IsSecret(info) and info.GetInspectItemLevel or nil
	if type(call) ~= "function" then
		return nil
	end
	local ok, level = pcall(call, unit)
	if ok and ns.Finite(level) and level > 0 then
		return level
	end
	return nil
end

-- The words of the average: the game's name for it (STAT_AVERAGE_ITEM_LEVEL, the title of the average on the character page,
-- Camelot/CharacterFrame.xml:494), in English when the client has none, and the level to one decimal.
local function AverageWords(level)
	local label = _G.STAT_AVERAGE_ITEM_LEVEL
	if ns.IsSecret(label) or type(label) ~= "string" or label == "" then
		label = "Item level"
	end
	return ("%s %.1f"):format(label, level)
end

-- Shows the average in a small font under the level on the window's character page (InspectLevelText, Camelot/InspectPaperDollFrame.xml:58-75),
-- or hides it. The text is made on that page, and while the page is protected in a fight it waits for the next pass.
local function Average()
	local record = inspect.average
	local live = ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and not refused[PART] and Opt("ilvlInspect")
	local unit = live and ReadyUnit() or nil
	local level = unit and InspectLevel(unit) or nil
	if level == nil then
		if record then
			pcall(record.text.Hide, record.text)
		end
		return
	end
	if record == nil then
		local page = _G.InspectPaperDollFrame
		if not Usable(page) or ns.Forbidden(page) or Blocked(page) then
			return
		end
		local text = ns.OwnText(page, "OVERLAY", AVERAGE_FONT)
		if text == nil then
			Refuse(PART, "Windows: item level stopped, the game refused a text on the Inspect window.")
			return
		end
		local below = _G.InspectLevelText
		if not (Usable(below) and pcall(text.SetPoint, text, "TOP", below, "BOTTOM", 0, -2)) then
			pcall(text.SetPoint, text, "TOP", page, "TOP", 0, -56)
		end
		record = { text = text }
		inspect.average = record
	end
	local colour = Opt("ilvlColour") == "gold" and GOLD or WHITE
	pcall(record.text.SetTextColor, record.text, colour[1], colour[2], colour[3], 1)
	pcall(record.text.SetText, record.text, AverageWords(level))
	pcall(record.text.Show, record.text)
end

local function AverageSoon()
	if not inspect.queued then
		inspect.queued = true
		Soon(function()
			inspect.queued = false
			ns.EachPart(KEY, PART, Average)
		end)
	end
end

-- Dresses every slot of the Inspect window, and its average.
local function DressInspect()
	inspect.seen = true
	for _, name in ipairs(INSPECT_SLOTS) do
		local button = _G[name]
		if Usable(button) and not ns.Forbidden(button) then
			ns.EachPart(KEY, PART, Dress, button, EntryOf(button, "inspect"))
		end
	end
	ns.EachPart(KEY, PART, Average)
end

-- The game filled a slot of the Inspect window: on INSPECT_READY, when its page is shown and when the inspected player changes gear
-- (InspectPaperDollFrame.lua:63-73, 81-86, 209-217). A player whose items the game has not announced is not read.
local function OnInspectSlot(button)
	if Usable(button) and not ns.Forbidden(button) and (buttons[button] or (ns.Enabled(KEY) and Opt("ilvlInspect"))) then
		ns.EachPart(KEY, PART, Dress, button, EntryOf(button, "inspect"))
		AverageSoon()
	end
end

-- The game has the items of the player with this GUID. Only those of the unit the Inspect window shows are read.
local function OnInspectReady(guid)
	if ns.IsSecret(guid) or type(guid) ~= "string" then
		return
	end
	local unit = InspectedUnit()
	if unit == nil or GuidOf(unit) ~= guid then
		return
	end
	inspect.ready = guid
	if Opt("ilvlInspect") or inspect.seen then
		DressInspect()
	end
end

-- The addon of the Inspect window has loaded, with the function that fills its slots.
local function OnAddonLoaded(name)
	if name == INSPECT_ADDON and Opt("ilvlInspect") then
		ns.FollowGlobal(INSPECT_UPDATE, OnInspectSlot)
	end
end

-- Called for each slot the windows module styles, and when the game sets its border again.
function Items.Slot(button)
	if ns.Forbidden(button) then
		return
	end
	local entry = buttons[button]
	if entry == nil and not Idle() then
		local kind = KindOf(button)
		entry = kind and EntryOf(button, kind) or nil
	end
	if entry then
		if entry.kind == "bank" then
			ns.FollowGlobal("SetItemButtonQuality", OnQuality)
		end
		Dress(button, entry)
	else
		Count(button, ns.Enabled(KEY))
	end
end

-- Called after a bag window updates its items.
function Items.Bag(root)
	if Idle() or ns.Forbidden(root) or type(root.EnumerateValidItems) ~= "function" then
		return
	end
	for _, button in root:EnumerateValidItems() do
		if Usable(button) and not ns.Forbidden(button) then
			Dress(button, EntryOf(button, "bag"))
		end
	end
end

-- The rows of the Inspect window, applied: a window that shows a player whose items the game has is dressed again, and the average with it.
local function InspectApplied()
	if Opt("ilvlInspect") and ReadyUnit() then
		DressInspect()
	else
		Average()
	end
end

-- Called when the windows module applies its settings.
function Items.Apply()
	ranks = nil
	refused.qualityMin = nil
	if Opt("ilvlCharacter") then
		ns.FollowGlobal("PaperDollItemSlotButton_Update", OnPaperDoll)
		if Opt("ilvlFlyout") then
			ns.FollowGlobal(FLYOUT_BUTTON, OnFlyoutButton)
		end
	end
	if Opt("ilvlInspect") then
		ns.FollowGlobal(INSPECT_UPDATE, OnInspectSlot)
	end
	for button, entry in pairs(buttons) do
		ns.EachPart(KEY, PART, Dress, button, entry)
	end
	ns.EachPart(KEY, PART, InspectApplied)
	if AllDefault() then
		touched = false
	end
end

-- Item information that arrives after the slots were drawn fills in the levels. One refresh covers a run of events.
local function Refill()
	burst = false
	for button, entry in pairs(buttons) do
		ns.EachPart(KEY, PART, Dress, button, entry)
	end
end

local function OnInfo()
	if burst or not (Opt("ilvlBags") or Opt("ilvlCharacter") or (Opt("ilvlInspect") and inspect.seen)) then
		return
	end
	burst = true
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(0, Refill)
	else
		Refill()
	end
end

ns.AddEvent(KEY, "GET_ITEM_INFO_RECEIVED", OnInfo)
ns.AddEvent(KEY, "INSPECT_READY", OnInspectReady)
ns.AddEvent(KEY, "ADDON_LOADED", OnAddonLoaded, function(name)
	return not ns.IsSecret(name) and name == INSPECT_ADDON
end)
