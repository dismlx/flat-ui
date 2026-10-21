local _, ns = ...

-- Window titles and item slots. This is not a module: the windows module calls ns.Items from its window frames, its item slots and its bag
-- and bank hooks, and its Refresh calls ns.Items.Apply. The title of a window is TitleContainer.TitleText (Blizzard_SharedXML/PortraitFrame.lua:4-14);
-- a dialog whose title is in a Header has none and is left alone. A slot's bag is read with button:GetBagID() (Blizzard_UIPanels_Game/
-- Mainline/ContainerFrame.lua:1831-1833) and a bank slot's with GetBankTabID and GetContainerSlotID (Mainline/BankFrameTemplates.lua:494, 521).
-- Every row at its default makes no call the game does not make, and a row put back to its default gives the game's own value back.

local KEY = "windows"
local PART = "item details"

-- The lowest quality each choice of Quality border from draws, and the quality colours that are compared to find where a colour belongs.
local MIN_QUALITY = { all = 0, uncommon = 2, rare = 3, epic = 4 }
local WEAPON, ARMOUR = 2, 4
local LEVEL_FONT = "NumberFontNormal"
local WHITE, GOLD = { 1, 1, 1 }, { 1, 0.82, 0 }

-- The slots this file looks at, by button: { kind = "bag", "bank" or "char", level = the item level text, dim = the dim texture, hidGlow = true
-- while the new item glow is hidden here }.
local buttons = setmetatable({}, { __mode = "k" })
-- What the game answers for the colour of each quality from 0 to 4, read at each refresh: { quality, r, g, b }.
local ranks
-- True once a row away from its default has been applied, so that nothing is read for a slot while every row is at its default.
local touched = false
-- Parts the game refused: the part is off and says so on /flatui status.
local refused = {}
local burst = false

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
-- character window in UpdateTitle, CharacterFrame.lua:254-258, on show, on a tab change and on the name and rank events), so the colour
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

-- The item link and the container item info of a slot, and the bag and slot they came from.
local function Source(button, kind)
	if kind == "char" then
		if type(GetInventoryItemLink) ~= "function" then
			return nil
		end
		local ok, link = pcall(GetInventoryItemLink, "player", button:GetID())
		return ok and not ns.IsSecret(link) and type(link) == "string" and link or nil
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
	if not ns.Finite(bag) or not ns.Finite(slot) then
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
		pcall(text.SetPoint, text, "BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
		local ok, file = pcall(text.GetFont, text)
		entry.levelFile = ok and not ns.IsSecret(file) and type(file) == "string" and file or nil
	end
	local size = Opt("ilvlSize")
	if entry.levelSize ~= size and entry.levelFile then
		if not pcall(text.SetFont, text, entry.levelFile, size, "OUTLINE") then
			Refuse(PART, "Windows: item level stopped, the game refused the font of an item level.")
			pcall(text.Hide, text)
			return
		end
		entry.levelSize = size
	end
	local r, g, b = LevelColour(link, info)
	pcall(text.SetTextColor, text, r, g, b, 1)
	pcall(text.SetText, text, tostring(value))
	pcall(text.Show, text)
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

-- Applies the rows to one slot.
function Dress(button, entry)
	local live = ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and not refused[PART]
	Count(button, ns.Enabled(KEY))
	local bagLike = entry.kind ~= "char"
	local wantLevel = live and Opt(bagLike and "ilvlBags" or "ilvlCharacter") or false
	local wantDim = live and bagLike and Opt("junkDim") or false
	local hideGlow = live and entry.kind == "bag" and not Opt("newGlow")
	if wantLevel or wantDim or hideGlow or Opt("countSize") ~= 100 then
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

local function KindOf(button)
	if type(button.GetBankTabID) == "function" and type(button.GetContainerSlotID) == "function" then
		return "bank"
	elseif type(button.GetBagID) == "function" then
		return "bag"
	end
	local name = NameOf(button)
	if name and name:find("^Character%u%w*Slot$") and not name:find("^CharacterBag") then
		return "char"
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

-- Called when the windows module applies its settings.
function Items.Apply()
	ranks = nil
	refused.qualityMin = nil
	if Opt("ilvlCharacter") then
		ns.FollowGlobal("PaperDollItemSlotButton_Update", OnPaperDoll)
	end
	for button, entry in pairs(buttons) do
		ns.EachPart(KEY, PART, Dress, button, entry)
	end
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
	if burst or not (Opt("ilvlBags") or Opt("ilvlCharacter")) then
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
