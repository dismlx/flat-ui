local _, ns = ...

-- Bags: the item buttons of the bag window and the bank window (design §2.5). This file makes them, gives them the Flat UI look, draws a record
-- of BagsData.lua on them, dims them for the search, follows their locks and cooldowns, and holds the click and tooltip code of the buttons that
-- are Flat UI's own. Bags.lua makes ns.Bags and every sub-table of it; this file only adds the fields of B.Buttons, and looks each function of
-- another file up when it calls it. It writes no field on a frame of the game's and calls none of the game's bag functions: the helpers of the
-- game it calls (SetItemButtonCount, CooldownFrame_Set) and the template's methods write fields of this addon's own buttons only. Besides the
-- calls named below it makes widget calls on frames and regions of its own only (CreateFrame, CreateTexture, SetParent, GetParent, SetID,
-- SetPoint, SetAllPoints, ClearAllPoints, GetFrameLevel, SetFrameLevel, Show, Hide, SetShown, IsShown, IsVisible, SetScript, RegisterForClicks,
-- RegisterForDrag, and the texture, text and animation calls of its look), and asks InCombatLockdown, GetTime and C_Timer.After. A hidden frame
-- of its own on UIParent holds the holders until the bag window exists.
--
-- Live bag slots are the game's own template, ContainerFrameItemButtonTemplate (Blizzard_UIPanels_Game/Mainline/ContainerFrame.xml:77-169), made
-- with CreateFrame("ItemButton", "FlatUIBag<bag + 10>Slot<slot>", holder, template), as the game makes item buttons elsewhere
-- (Blizzard_FrameXML/EquipmentFlyout.lua:64). Each has a global name, so the $parent names of the template's parts never overwrite one another.
-- The template reads its bag from its field bagID, else from its parent's ID, and its slot from its own ID (ContainerFrame.lua:1845-1851), so
-- each bag has a holder, a plain frame of this file whose ID is the bag (SetID), and each button takes its slot as its own ID (SetID) for the
-- whole session. The field bagID, SetBagID and Initialize are never used: they would set the bag in this addon's taint, and the click reads it
-- (ContainerFrame.lua:1824-1864). A button that something takes out of its holder is put back in it, with the holder moved to that frame, so its
-- bag stays its holder's ID. The bags are 0 to 5, and the keyring (-1) while C_ActionBar.ShouldShowKeyring says the game shows one
-- (ContainerFrame.lua:10-12), read at each Prepare; their sizes come from C_Container.GetContainerNumSlots, which counts no locked slot
-- (ContainerFrame.lua:120-135). A bag that gets smaller hides its extra buttons, and a larger one gets more.
-- A click on a live slot is the game's own secure OnClick (ContainerFrame.lua:1503-1622, 1683-1698, 1777-1814): use and equip, also in a fight,
-- sell, deposit at the banker, mail, trade, post at the auction house, split a stack, link, dress up and drag, and its OnEnter is the game's
-- tooltip with the compare, which also takes the game's new flag off (ContainerFrame.lua:1735-1775). No script is set on these buttons.
-- They are made out of combat only, STEP to a frame, by B.Buttons.Prepare (Bags.lua at Start, BagsData.lua at BAG_CONTAINER_UPDATE); a call made
-- in a fight waits for its end with a flag of its own, since ns.OutOfCombat keeps every call it is given (Core.lua:1837-1843). The layout may ask
-- for a missing one (B.Buttons.Live), which is then made at once, out of combat only. Bag addons of this client found slots made by addon code
-- failing when they were first shown in a fight, so as a precaution each Prepare run that made buttons hands them to B.Window.Warm, which shows
-- them once at alpha 0 (design §2.5.1), and PLAYER_REGEN_DISABLED, which comes before the lockdown (Cooldowns.lua:1738-1739), makes every missing
-- button at once and warms those the same way. B.Buttons.ShowAll(true) shows every live button for the warm-up, and ShowAll(false) puts each back
-- as it was. The game's source shows no mechanism that needs it (the first OnShow only registers a callback, Shared/ItemButtonTemplate.lua:22-29).
--
-- Bank slots (FlatUIBankTab<tab>Slot<slot>, tabs 6 to 14), the bank's bag slots (FlatUIBankBag<n>, container -2, Camelot/BankFrame.lua:136-191,
-- 301-327) and the slots of other characters and of the bank away from the banker (FlatUIBagsCached<n>, pooled per owner) are ItemButtons of this
-- addon's own from the intrinsic alone (Blizzard_ItemButton/Shared/ItemButtonTemplate.xml:4-81), made when asked, also in a fight, since nothing
-- on them is protected. Their clicks and tooltips are this file's:
-- - A bank slot picks its item up with C_Container.PickupContainerItem on a left click, a drag and a drop, and takes it out with
--   C_Container.UseContainerItem and no bank type on a right click, as the game's bank buttons do (Mainline/BankFrameTemplates.lua:436-478). A
--   bank bag slot picks up with C_Container.PickupContainerItem(-2, n) on any click, drag or drop (Camelot/BankFrame.lua:378-395); one the
--   character has not bought, by C_Bank.FetchNumPurchasedBankTabs (BankDocumentation.lua:226-239), shows the game's lock (bankslot-icon-lock,
--   Camelot/BankFrame.xml:11) and takes no click. Both act only while the bank is live (B.Bank.Live) and never in a fight, when a line says so.
-- - A modified click links the item: out of a fight with HandleModifiedItemClick (Mainline/ItemButtonTemplate.lua:372-404), for chat links and
--   the dressing room, and in a fight only the chat link, with ChatFrameUtil.InsertLink while IsModifiedClick("CHATLINK"), which is the call that
--   function makes for it (:376-387). The dressing room writes the game's DressUpFrame and opens it as a panel (Mainline/DressUpFrames.lua:346-366),
--   which a fight refuses to this addon (Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua:853-861, 886-888). The link of a live bank
--   slot is read with C_Container.GetContainerItemLink, and a cached link is made whole with C_Item.GetItemInfo first. Any other click on a cached
--   slot does nothing, so a cached slot never reaches the game's click.
-- - The tooltip is GameTooltip: SetOwner, then SetBagItem for a live bank slot or bank bag slot, or SetHyperlink and a line "Last seen ..." from
--   B.Data.Characters (the days counted with date and time) for a cached one, then Show, out of a fight. The sell price stays: on this build it is
--   plain text (Blizzard_GameTooltip/Mainline/GameTooltip.lua:325-333). In a fight it is the name (C_Item.GetItemNameByID while the record has
--   none), the count and that line in plain lines (SetText, AddLine), the rule Chat keeps for link tooltips (Core.lua:149-153), and so is the
--   tooltip of an item the game builds none for. When the mouse leaves, it is hidden while the button owns it (IsOwned, Hide).
--
-- The look is set once on each button, as Windows restyles the game's slots (Windows.lua:1123-1189): the NormalTexture at alpha 0, the rounded
-- Mask taken off the icon and off the pushed texture (RemoveMaskTexture; it is put on in Shared/ItemButtonTemplate.lua:16-20), the highlight and
-- pushed textures the flat tints of Windows (SetColorTexture), a box of ns.Outline filled with Button and slot colour, the icon cropped by Icon
-- crop (SetTexCoord), and the template's store highlight hidden, which only the template's new item code hides (ContainerFrame.xml:121-125,
-- ContainerFrame.lua:1894, 1902). SetItemButtonQuality is never called, so IconBorder stays hidden and Items.lua's bank hook never sees these
-- buttons (Items.lua:680-699). The edge of the box is red for a broken item (C_Container.GetContainerItemDurability at 0), else the quality colour
-- of ColorManager.GetColorDataForBagItemQuality (Blizzard_Colors/Mainline/ColorManager.lua:92-112; poor items have none) when Quality border lets
-- that quality through, else the border colour. The buttons keep the template's 37 units: the window scales its content.
-- Drawing a record (B.Buttons.Draw, design §2.5.3): the icon (SetTexture; desaturated while the slot is locked, and at 0.4 grey while its
-- cooldown waits, as ContainerFrame.lua:1990-2004 does), the count with the game's SetItemButtonCount (Mainline/ItemButtonTemplate.lua:9-34),
-- which also writes the field count that the refund question reads (ContainerFrame.lua:1435), and on a live slot the cooldown with
-- CooldownFrame_Set (Blizzard_FrameXMLUtil/Cooldown.lua:2-8) from C_Container.GetContainerItemCooldown, and of the template UpdateQuestItem,
-- UpdateNewItem while New item glow is on (hovering takes the glow off), and SetHasItem and SetReadable for the hover cursor
-- (ContainerFrame.lua:1866-1909, 1970-1988), with isLocked and isReadable read live from C_Container.GetContainerItemInfo. The other buttons draw
-- the quest border and the junk coin with textures of their own in the same art (TEXTURE_ITEM_QUEST_BANG and TEXTURE_ITEM_QUEST_BORDER,
-- Blizzard_FrameXMLBase/Constants.lua:274-275; the atlas bags-junkcoin, ContainerFrame.xml:139-143). The item level is a text of this file
-- (NumberFontNormal at 12 with an outline, as Items.lua:491-531 sets its own) from ns.Items.LevelOf, in the quality colour. The marks are
-- ItemMarks' answers drawn as ItemMarks.lua:366-460 draws them (BoE, the red tint, the Feed Pet icon of C_Spell.GetSpellTexture): all three on
-- this character's items, with Unusable asked by bag and slot for a live slot and by link for the bank away from the banker, and the BoE mark
-- alone on another character's, since the other two describe the character playing. The junk coin shows B.Categories.IsJunk, Errands' own test
-- of the slot for a live slot of the bags. The search dims through the item button's SetMatchesSearch (Shared/ItemButtonTemplate.lua:49-56,
-- 96-116), and the level and marks fade to 0.4. A name the client has not loaded is asked for once through B.Data.Want (Core.lua:139-140). An
-- empty slot of a special bag takes a fill of its kind, and the free slot of a kind its count.
--
-- Events this file owns (design §2.8), each run as the part "items" while Bags is on, with the work in its order:
-- ITEM_LOCK_CHANGED(bag, slot) (ContainerDocumentation.lua:718-728): B.Buttons.Lock(bag, slot), the lock of that one button read live; no pass.
-- BAG_UPDATE_COOLDOWN (ContainerDocumentation.lua:668-673): the cooldowns of the live buttons on screen, only while a window shows them.
-- PLAYER_REGEN_DISABLED (UnitDocumentation.lua:3887): Prepare's top-up, every missing template button at once (normally none), then B.Window.Warm
-- for what it made.

local KEY = "bags"
-- The part of the module this file's work runs in (design §2.10): a failure counts toward stopping it alone.
local PART = "items"

local B = ns.Bags
local Buttons = B.Buttons
local Data = B.Data
local Categories = B.Categories
local Search = B.Search
local Window = B.Window
local Bank = B.Bank
local ItemMarks = ns.ItemMarks

-- The game's template of a bag slot and the global names of the buttons of this file.
local TEMPLATE = "ContainerFrameItemButtonTemplate"
local LIVE_NAME = "FlatUIBag%dSlot%d"
local BANK_NAME = "FlatUIBankTab%dSlot%d"
local BAG_SLOT_NAME = "FlatUIBankBag%d"
local OFFLINE_NAME = "FlatUIBagsCached%d"
-- Template buttons made in one frame of a Prepare run.
local STEP = 40
-- The containers (Enum.BagIndex): the backpack, the four bags and the reagent bag, the keyring, the bank's bag slots (Characterbanktab) and the
-- bank's tabs (CharacterBankTab_1 to _9).
local BAGS = { 0, 1, 2, 3, 4, 5 }
local REAGENT_BAG = 5
local KEYRING = -1
local BANK_BAGS = -2
local FIRST_TAB, LAST_TAB = 6, 14
-- Enum.BankType.Character, for a client whose Enum does not say.
local CHARACTER_BANK = 0

-- The look of Windows' slots (Windows.lua:56-60) and of its text: the hover and pressed tints, the edge of a broken item, the dim text colour
-- (Threat.lua:46) and how far the level and marks fade while the search dims a slot.
local HOVER = { 1, 1, 1, 0.3 }
local SLOT_PRESSED = { 0.9, 0.8, 0.1, 0.3 }
local BROKEN = { 0.9, 0, 0 }
local WHITE = { 1, 1, 1 }
local DIM_TEXT = { 0.66, 0.68, 0.62 }
local FADED = 0.4
-- The grey of an icon whose cooldown waits (ContainerFrame.lua:1997).
local GREY = 0.4
-- Button and slot colour and Icon crop, when the profile gives none (Config.lua:1276, 1278).
local PANEL = { 0.118, 0.118, 0.118 }
local CROP, CROP_MOST = 8, 15
local LEVEL_FONT, LEVEL_SIZE = "NumberFontNormal", 12
local FREE_FONT, FREE_COLOUR = "NumberFontNormalLarge", { 0.85, 0.85, 0.85 }
-- The lowest quality each choice of Quality border lets through; Off is none.
local MIN_QUALITY = { all = 0, uncommon = 2, rare = 3, epic = 4 }
-- The marks as ItemMarks draws them (ItemMarks.lua:46-57): the BoE word, the red of an item the character cannot use, and the Feed Pet icon
-- (spell 6991), or a flat square when the client gives no icon.
local BIND_WORD, BIND_FONT, BIND_COLOUR = "BoE", "NumberFontNormalSmall", { 0.38, 0.82, 1 }
local TINT = { 1, 0.18, 0.18 }
local FEED_PET, FOOD_SIZE, FOOD_COLOUR = 6991, 14, { 0.45, 0.85, 0.3 }
-- The art of the template that the other buttons draw with textures of their own, and the lock of a bank bag slot not bought.
local JUNK_ATLAS = "bags-junkcoin"
local LOCK_ATLAS = "bankslot-icon-lock"
local QUEST_BANG = { "TEXTURE_ITEM_QUEST_BANG", "Interface\\ContainerFrame\\UI-Icon-QuestBang" }
local QUEST_BORDER = { "TEXTURE_ITEM_QUEST_BORDER", "Interface\\ContainerFrame\\UI-Icon-QuestBorder" }
local QUEST_WIDTH, QUEST_HEIGHT = 37, 38
-- The question mark the game shows for an item it has no icon for.
local UNKNOWN_ICON = 134400
-- The fill of an empty slot of a special bag, by kind (design §4.9), drawn half way from Button and slot colour to it, so it stays faint.
local KIND_FILLS = {
	soul = { 0.45, 0.25, 0.55 },
	quiver = { 0.5, 0.38, 0.2 },
	herb = { 0.25, 0.45, 0.25 },
	enchanting = { 0.3, 0.3, 0.6 },
	engineering = { 0.5, 0.45, 0.3 },
	mining = { 0.42, 0.42, 0.42 },
	leather = { 0.45, 0.32, 0.22 },
	gem = { 0.28, 0.5, 0.55 },
	keyring = { 0.55, 0.5, 0.22 },
	reagent = { 0.28, 0.42, 0.52 },
}
local FILL_SHARE = 0.5
-- Enum.ItemClass Container and Quiver, and the kinds of Enum.ItemContainerSubclass that have a fill (WL enums.yaml:4712-4725).
local CONTAINER, QUIVER = 1, 11
local SUBCLASS_FILLS = { [1] = "soul", [2] = "herb", [3] = "enchanting", [4] = "engineering", [5] = "gem", [6] = "mining", [7] = "leather",
	[11] = "reagent" }
-- Each row of the Bags page this file reads, at its default for a profile that has none yet (design §7.2).
local DEFAULTS = { itemLevel = true, quality = "all", marks = true, junkCoin = true, newGlow = true }
-- The game's words for a bank bag slot (Camelot/BankFrame.lua:176, 181), in English when the client has none.
local WORDS = {
	bankBag = { "BANK_BAG", "Bank bag slot" },
	purchase = { "BANK_BAG_PURCHASE", "Purchasable bag slot" },
}
local SAY = {
	fight = "Bags: the bank's slots wait for the end of the fight.",
	closed = "Bags: the bank is not open.",
	refused = "Bags: the game refused its bag slot template, so the bag window cannot use your items. /reload tries again.",
}
-- Seconds in which the same line is not said twice: a drag fires a drag and a click.
local SAY_GAP = 2
local COUNT_LINE = "%d in this slot"
local SEEN = { today = "Last seen today", yesterday = "Last seen yesterday", days = "Last seen %d days ago" }
local DAY = 86400
-- The regions that fade while the search dims a slot.
local FADES = { "level", "bind", "tint", "food" }
local NONE = {}

-- Per button: { kind = "live", "bank", "bagslot" or "offline", bag, slot (live, bank and bagslot), holder (live), owner (offline), icon, outline,
-- cooldown, record and opts of the last Draw, broken, fill (the kind's colour of an empty slot), unbought (bagslot), and the regions of this file
-- made on it when first needed, false when the game refused one: level, bind, tint, food, quest, junk, lock, freeText }.
local states = setmetatable({}, { __mode = "k" })
-- Per bag: its holder, and its template buttons by slot. The number of slots each bag had at the last Prepare.
local holders = {}
local live = {}
local sizes = {}
-- Per bank tab (and -2 for the bag slots): the buttons by slot.
local banks = {}
-- Offline buttons: those free, those each owner holds, and how many were made.
local pool = {}
local used = {}
local offlineMade = 0
-- Template buttons made by a Prepare run and not warmed yet.
local unwarmed = {}
-- While ShowAll(true) holds: per live button, whether it was shown before.
local warming = nil
-- The paced run of Prepare: the slots it still makes, the next of them, and whether a frame of it is due.
local pending, nextIndex, running = nil, 1, false
-- True while a Prepare waits for the end of the fight, and once the game refused the template.
local queued, refused = false, false
-- Whether the game shows a keyring, as read at the last Prepare (nil before the first).
local keyringShown = nil
-- A hidden frame of this file that holds the buttons while their window does not exist yet.
local shelf = nil
-- Per item link: its item level, once the game gave one. The Feed Pet icon, false when the client gives none. Per line: when it was said.
local levels = {}
local foodIcon = nil
local said = {}

-- Small helpers -----------------------------------------------------------------------------------------------------------------------

local function Usable(value)
	return value ~= nil and not ns.IsSecret(value) and type(value) == "table"
end

-- A frame or region: a table with the widget call GetObjectType.
local function IsFrame(value)
	return Usable(value) and type(value.GetObjectType) == "function"
end

-- A plain answer, or nil for one the client withholds.
local function Plain(value)
	if ns.IsSecret(value) then
		return nil
	end
	return value
end

-- A string that is not empty, or nil.
local function Text(value)
	if ns.IsSecret(value) or type(value) ~= "string" or value == "" then
		return nil
	end
	return value
end

local function Whole(value)
	return ns.Finite(value) and value % 1 == 0
end

-- True for a container of the bags this file makes template buttons for.
local function IsBag(bag)
	return Whole(bag) and (bag == KEYRING or (bag >= 0 and bag <= REAGENT_BAG))
end

local function IsTab(bag)
	return Whole(bag) and bag >= FIRST_TAB and bag <= LAST_TAB
end

-- A frame or region held in a field of a button of this file.
local function Field(frame, key)
	local value = frame[key]
	if Usable(value) then
		return value
	end
	return nil
end

-- What a function of another part answers, or nil when it is missing or fails: a part that fails leaves its piece of the drawing out, and the
-- rest of the button is still drawn.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b = pcall(fn, ...)
	if not ok then
		return nil
	end
	return a, b
end

-- Runs fn as the part of this file (B.Part, ns.EachPart): a failure is counted, never raised.
local function Part(fn, ...)
	local part = B.Part
	if type(part) == "function" then
		return part(PART, fn, ...)
	end
	return pcall(fn, ...)
end

-- Bags is on, not stopped and not standing down (design §2.3.6).
local function On()
	return Ask(B.On) == true
end

local function Me()
	return (Ask(B.Me))
end

-- A row of the Bags page, at its default while the profile has none.
local function Opt(key)
	local value = Ask(B.Opt, key)
	if value == nil then
		value = DEFAULTS[key]
	end
	return value
end

local function Fighting()
	if type(InCombatLockdown) ~= "function" then
		return false
	end
	local ok, fighting = pcall(InCombatLockdown)
	return ok and (ns.IsSecret(fighting) or fighting == true)
end

-- A word of the game's, or the English one when the client has none.
local function Word(key)
	local entry = WORDS[key]
	return Text(_G[entry[1]]) or entry[2]
end

local function Say(text)
	local now = 0
	if type(GetTime) == "function" then
		local ok, stamp = pcall(GetTime)
		if ok and ns.Finite(stamp) then
			now = stamp
		end
	end
	local last = said[text]
	if last ~= nil and now - last < SAY_GAP and now >= last then
		return
	end
	said[text] = now
	print(text)
end

-- Runs fn on the next frame.
local function Soon(fn)
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, 0, fn) then
		return
	end
	fn()
end

local function BankLive()
	return Ask(Bank.Live) == true
end

local function Searching()
	return Ask(Search.Active) == true
end

-- Reading the game ---------------------------------------------------------------------------------------------------------------------

local function Container(name)
	local api = C_Container
	if type(api) ~= "table" or ns.IsSecret(api) or type(api[name]) ~= "function" then
		return nil
	end
	return api[name]
end

-- The number of slots of a container, 0 for none or a withheld answer.
local function SizeOf(bag)
	local call = Container("GetContainerNumSlots")
	if call == nil then
		return 0
	end
	local ok, count = pcall(call, bag)
	if ok and ns.Finite(count) and count > 0 then
		return math.floor(count)
	end
	return 0
end

-- The game's ContainerItemInfo of a slot (ContainerDocumentation.lua:765-783), or nil.
local function Info(bag, slot)
	local call = Container("GetContainerItemInfo")
	if call == nil then
		return nil
	end
	local ok, info = pcall(call, bag, slot)
	if ok and Usable(info) then
		return info
	end
	return nil
end

-- True for an item whose durability is 0, as the game's red slot marks it.
local function Broken(bag, slot)
	local call = Container("GetContainerItemDurability")
	if call == nil then
		return false
	end
	local ok, current, most = pcall(call, bag, slot)
	return ok and ns.Finite(current) and ns.Finite(most) and most > 0 and current <= 0
end

-- True while the game shows a keyring (C_ActionBar.ShouldShowKeyring, the game's own test, ContainerFrame.lua:10-12).
local function KeyringShows()
	local api = C_ActionBar
	if type(api) ~= "table" or ns.IsSecret(api) or type(api.ShouldShowKeyring) ~= "function" then
		return false
	end
	local ok, shows = pcall(api.ShouldShowKeyring)
	return ok and not ns.IsSecret(shows) and shows == true
end

local function BankType()
	local enum = _G.Enum
	local types = Usable(enum) and enum.BankType or nil
	local value = Usable(types) and types.Character or nil
	if ns.Finite(value) then
		return value
	end
	return CHARACTER_BANK
end

-- Whether bank bag slot n is bought: the first tab is the bank's own slots, and bag slot n holds tab n (Camelot/BankFrame.lua:154-183). An
-- answer the game withholds counts as bought, so the slot is not locked by mistake.
local function Bought(n)
	local api = C_Bank
	if type(api) ~= "table" or ns.IsSecret(api) or type(api.FetchNumPurchasedBankTabs) ~= "function" then
		return true
	end
	local ok, count = pcall(api.FetchNumPurchasedBankTabs, BankType())
	if not ok or not ns.Finite(count) then
		return true
	end
	return n <= count
end

-- The colour the game gives a quality in the bags, or nil (none for poor items, ColorConstants.lua:21-30).
local function QualityColour(quality)
	if not ns.Finite(quality) then
		return nil
	end
	local manager = _G.ColorManager
	if not Usable(manager) or type(manager.GetColorDataForBagItemQuality) ~= "function" then
		return nil
	end
	local ok, colour = pcall(manager.GetColorDataForBagItemQuality, quality)
	if ok and Usable(colour) and ns.Finite(colour.r) and ns.Finite(colour.g) and ns.Finite(colour.b) then
		return colour.r, colour.g, colour.b
	end
	return nil
end

-- The item level of a link, from Items.lua (weapons and armour only), kept once the game gave one.
local function LevelOf(link)
	local known = levels[link]
	if known ~= nil then
		return known
	end
	local items = ns.Items
	local value = Usable(items) and Ask(items.LevelOf, link) or nil
	if ns.Finite(value) and value > 0 then
		levels[link] = value
		return value
	end
	return nil
end

-- The icon of Feed Pet, read once.
local function FoodIcon()
	if foodIcon == nil then
		foodIcon = false
		local api = C_Spell
		if type(api) == "table" and not ns.IsSecret(api) and type(api.GetSpellTexture) == "function" then
			local ok, file = pcall(api.GetSpellTexture, FEED_PET)
			if ok and (ns.Finite(file) or Text(file)) then
				foodIcon = file
			end
		end
	end
	return foodIcon or nil
end

-- Records ------------------------------------------------------------------------------------------------------------------------------

-- A record of BagsData.lua (design §2.2), or nil for anything that is not one with an item ID.
local function RecordOf(value)
	if Usable(value) and ns.Finite(value.id) then
		return value
	end
	return nil
end

local function IconOf(record)
	local icon = record.icon
	if ns.Finite(icon) or Text(icon) then
		return icon
	end
	return UNKNOWN_ICON
end

local function CountOf(record)
	local count = record.count
	if ns.Finite(count) and count >= 1 then
		return math.floor(count)
	end
	return 1
end

local function NameOf(record)
	local name = Text(record.name)
	if name then
		return name
	end
	local api = C_Item
	if type(api) == "table" and not ns.IsSecret(api) and type(api.GetItemNameByID) == "function" then
		local ok, found = pcall(api.GetItemNameByID, record.id)
		if ok and Text(found) then
			return found
		end
	end
	return "Item " .. tostring(math.floor(record.id))
end

-- The bag in bank bag slot n, read live at the banker, for a bag slot drawn with no record: a record of this file in the shape of BagsData's.
local function BagSlotRecord(state)
	if not BankLive() then
		return nil
	end
	local info = Info(BANK_BAGS, state.slot)
	local id = info and Plain(info.itemID)
	if not ns.Finite(id) then
		return nil
	end
	local quality = Plain(info.quality)
	local icon = Plain(info.iconFileID)
	return {
		key = Me(), bag = BANK_BAGS, slot = state.slot, live = true, id = id, count = 1,
		quality = ns.Finite(quality) and quality or nil,
		link = Text(info.hyperlink), icon = (ns.Finite(icon) or Text(icon)) and icon or nil, name = Text(info.itemName),
		bound = Plain(info.isBound) == true, locked = Plain(info.isLocked) == true,
	}
end

-- The fill of an empty slot of a bag of this kind, or nil for a normal bag. kind is BagsData's { id, label, family, class, subclass, key, name }:
-- id is the bag's item ID, and key names the kind ("keyring", "reagent", "bag" and one for each kind of special bag), so the keyring and the
-- reagent bag are known by it on a button of another character, which has no container; a live button knows them by its container too.
local function KindFill(kind, bag)
	if bag == KEYRING then
		return KIND_FILLS.keyring
	elseif bag == REAGENT_BAG then
		return KIND_FILLS.reagent
	end
	if not Usable(kind) then
		return nil
	end
	local key = Plain(kind.key)
	if key == "keyring" or key == "reagent" then
		return KIND_FILLS[key]
	end
	local class, subclass = Plain(kind.class), Plain(kind.subclass)
	if class == QUIVER then
		return KIND_FILLS.quiver
	elseif class == CONTAINER and ns.Finite(subclass) then
		local name = SUBCLASS_FILLS[subclass]
		return name and KIND_FILLS[name] or nil
	end
	return nil
end

-- Where the buttons live ---------------------------------------------------------------------------------------------------------------

local function Shelf()
	if shelf == nil then
		local ok, made = pcall(CreateFrame, "Frame", nil, UIParent)
		if not ok or not IsFrame(made) then
			return nil
		end
		ns.Own[made] = true
		pcall(made.Hide, made)
		shelf = made
	end
	return shelf
end

-- The frame that holds the buttons of a window: the window's content frame when it keeps one in its field content (the frame the window scales
-- and scrolls, design §4.8), else the window, else the shelf until the window exists.
local function Home(which)
	local frame = Ask(Window.Get, which)
	if Usable(frame) then
		local content = rawget(frame, "content")
		if IsFrame(content) then
			return content
		elseif IsFrame(frame) then
			return frame
		end
	end
	return Shelf()
end

local function LevelOfFrame(frame)
	local ok, level = pcall(frame.GetFrameLevel, frame)
	if ok and ns.Finite(level) then
		return level
	end
	return nil
end

-- Puts a frame of this file just above another when it is not above it already.
local function Above(frame, under)
	local mine, base = LevelOfFrame(frame), LevelOfFrame(under)
	if mine ~= nil and base ~= nil and mine <= base then
		pcall(frame.SetFrameLevel, frame, math.min(base + 1, 10000))
	end
end

-- The template gives its buttons frame level 10 (ContainerFrame.xml:77), which a window of a higher level would draw over, so a template button is
-- kept above its holder, and its cooldown and the edges of its box (ns.Outline's holder, as BagSort.lua:448-457 keeps its own) above it.
local function Lift(button, state)
	if state.holder then
		Above(button, state.holder)
	end
	if state.cooldown then
		Above(state.cooldown, button)
	end
	local outline = state.outline
	if Usable(outline) and IsFrame(outline.holder) then
		Above(outline.holder, button)
	end
end

local function LiftBag(bag)
	for _, button in pairs(live[bag] or NONE) do
		local state = states[button]
		if state then
			Lift(button, state)
		end
	end
end

-- Moves a frame of this file off the shelf once its window exists; a frame somewhere else stays where something put it. fill: the holder of a
-- bag, which covers the frame it is in. True when it moved the frame.
local function Rehome(frame, which, fill)
	if shelf == nil then
		return false
	end
	local ok, parent = pcall(frame.GetParent, frame)
	if not ok or ns.IsSecret(parent) or not rawequal(parent, shelf) then
		return false
	end
	local home = Home(which)
	if home == nil or rawequal(home, shelf) then
		return false
	end
	pcall(frame.SetParent, frame, home)
	if fill then
		pcall(frame.ClearAllPoints, frame)
		pcall(frame.SetAllPoints, frame, home)
	end
	return true
end

local function RehomeAll()
	if shelf == nil then
		return
	end
	for bag, holder in pairs(holders) do
		if Rehome(holder, "bags", true) then
			LiftBag(bag)
		end
	end
	for _, list in pairs(banks) do
		for _, button in pairs(list) do
			Rehome(button, "bank", false)
		end
	end
end

-- Puts a template button back in its holder when something took it out: the template reads its bag from its parent's ID
-- (ContainerFrame.lua:1845-1847), and any other parent would make its click use another bag. The holder goes to the frame the button was put
-- in, so the button stays where it was placed.
local function Keep(button, state)
	local holder = state.holder
	local ok, parent = pcall(button.GetParent, button)
	if not ok or ns.IsSecret(parent) or rawequal(parent, holder) then
		return
	end
	if IsFrame(parent) then
		pcall(holder.SetParent, holder, parent)
		pcall(holder.ClearAllPoints, holder)
		pcall(holder.SetAllPoints, holder, parent)
	end
	pcall(button.SetParent, button, holder)
	LiftBag(state.bag)
end

-- The look ------------------------------------------------------------------------------------------------------------------------------

local function CropShare()
	local crop = Ask(B.Look, "crop")
	if not ns.Finite(crop) then
		crop = ns.Get("windows.crop")
	end
	if not ns.Finite(crop) then
		crop = CROP
	end
	return math.max(0, math.min(CROP_MOST, crop)) / 100
end

local function PanelColour()
	local ok, r, g, b = pcall(ns.Colour, "windows.panel")
	if ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		return r, g, b
	end
	return PANEL[1], PANEL[2], PANEL[3]
end

-- The fill of a slot: Button and slot colour, moved half way to the colour of its kind for an empty slot of a special bag.
local function FillColour(state)
	local r, g, b = PanelColour()
	local kind = state.fill
	if kind then
		r = r + (kind[1] - r) * FILL_SHARE
		g = g + (kind[2] - g) * FILL_SHARE
		b = b + (kind[3] - b) * FILL_SHARE
	end
	return r, g, b
end

-- The edge of a slot: red while broken, the quality colour when Quality border lets the quality through, else none (the border colour).
local function EdgeColour(state)
	if state.broken then
		return BROKEN[1], BROKEN[2], BROKEN[3]
	end
	local record = state.record
	local least = MIN_QUALITY[Opt("quality")]
	if record == nil or least == nil or not ns.Finite(record.quality) or record.quality < least then
		return nil
	end
	return QualityColour(record.quality)
end

local function Crop(state)
	local icon = state.icon
	if icon then
		local share = CropShare()
		pcall(icon.SetTexCoord, icon, share, 1 - share, share, 1 - share)
	end
end

-- Paints what the look rows decide on one button: the crop, the fill and the edge.
local function PaintOne(state)
	Crop(state)
	local outline = state.outline
	if outline then
		local r, g, b = FillColour(state)
		ns.SetOutlineFill(outline, r, g, b, 1)
		ns.SetOutlineColour(outline, EdgeColour(state))
	end
end

-- A state texture of the button as a flat colour over the whole slot, as Windows' Retint does (Windows.lua:356-369).
local function Retint(texture, button, colour)
	if not Usable(texture) then
		return
	end
	pcall(texture.SetColorTexture, texture, colour[1], colour[2], colour[3], colour[4])
	pcall(texture.ClearAllPoints, texture)
	pcall(texture.SetAllPoints, texture, button)
end

-- The look, given once to each button of this file when it is made (see the top of this file).
local function Style(button, state)
	local icon = Field(button, "icon") or Field(button, "Icon")
	local mask = Field(button, "Mask")
	state.icon = icon
	state.cooldown = Field(button, "Cooldown")
	local okNormal, normal = pcall(button.GetNormalTexture, button)
	if okNormal and Usable(normal) then
		pcall(normal.SetAlpha, normal, 0)
	end
	if icon and mask then
		pcall(icon.RemoveMaskTexture, icon, mask)
	end
	local okHighlight, highlight = pcall(button.GetHighlightTexture, button)
	if okHighlight then
		Retint(highlight, button, HOVER)
	end
	local okPushed, pushed = pcall(button.GetPushedTexture, button)
	if okPushed and Usable(pushed) then
		if mask then
			pcall(pushed.RemoveMaskTexture, pushed, mask)
		end
		Retint(pushed, button, SLOT_PRESSED)
	end
	local battlepay = Field(button, "BattlepayItemTexture")
	if battlepay then
		pcall(battlepay.Hide, battlepay)
	end
	local ok, outline = pcall(ns.Outline, button, button)
	state.outline = ok and outline or nil
	PaintOne(state)
end

-- A texture of this file on a button, or nil when the game refuses it.
local function Made(button, layer, sublevel)
	local ok, texture = pcall(button.CreateTexture, button, nil, layer, nil, sublevel)
	if not ok or not Usable(texture) then
		return nil
	end
	ns.Own[texture] = true
	return texture
end

-- Each of these makes one region of this file on a button, the first time it is needed, or answers nil.
local function LevelText(button)
	local text = ns.OwnText(button, "OVERLAY", LEVEL_FONT)
	if text == nil then
		return nil
	end
	local ok, file = pcall(text.GetFont, text)
	if ok and Text(file) then
		pcall(text.SetFont, text, file, LEVEL_SIZE, "OUTLINE")
	end
	pcall(text.SetPoint, text, "BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
	return text
end

local function BindText(button)
	local text = ns.OwnText(button, "OVERLAY", BIND_FONT)
	if text == nil then
		return nil
	end
	pcall(text.SetPoint, text, "TOPLEFT", button, "TOPLEFT", 2, -2)
	pcall(text.SetTextColor, text, BIND_COLOUR[1], BIND_COLOUR[2], BIND_COLOUR[3], 1)
	pcall(text.SetText, text, BIND_WORD)
	return text
end

-- The red with the MOD blend just above the icon, which is in the BORDER layer (Shared/ItemButtonTemplate.xml:17-21), as ItemMarks' tint.
local function TintTexture(button, state)
	local texture = Made(button, "BORDER", 7)
	if texture == nil then
		return nil
	end
	pcall(texture.SetColorTexture, texture, TINT[1], TINT[2], TINT[3], 1)
	pcall(texture.SetBlendMode, texture, "MOD")
	pcall(texture.SetAllPoints, texture, state.icon or button)
	return texture
end

local function FoodTexture(button)
	local texture = Made(button, "OVERLAY", 2)
	if texture == nil then
		return nil
	end
	local icon = FoodIcon()
	if not (icon and pcall(texture.SetTexture, texture, icon) and pcall(texture.SetTexCoord, texture, 0.08, 0.92, 0.08, 0.92)) then
		pcall(texture.SetColorTexture, texture, FOOD_COLOUR[1], FOOD_COLOUR[2], FOOD_COLOUR[3], 1)
	end
	pcall(texture.SetSize, texture, FOOD_SIZE, FOOD_SIZE)
	pcall(texture.SetPoint, texture, "BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
	return texture
end

-- The template's junk coin and quest border, for a button made from the intrinsic alone (ContainerFrame.xml:96-101, 139-143).
local function JunkTexture(button)
	local texture = Made(button, "OVERLAY", 5)
	if texture == nil then
		return nil
	end
	pcall(texture.SetAtlas, texture, JUNK_ATLAS, true)
	pcall(texture.SetPoint, texture, "TOPLEFT", button, "TOPLEFT", 1, 0)
	return texture
end

local function QuestTexture(button)
	local texture = Made(button, "OVERLAY", 2)
	if texture == nil then
		return nil
	end
	pcall(texture.SetSize, texture, QUEST_WIDTH, QUEST_HEIGHT)
	pcall(texture.SetPoint, texture, "TOP", button, "TOP", 0, 0)
	return texture
end

-- The game's lock over a bank bag slot not bought (Camelot/BankFrame.xml:11).
local function LockTexture(button)
	local texture = Made(button, "ARTWORK", 1)
	if texture == nil then
		return nil
	end
	pcall(texture.SetAtlas, texture, LOCK_ATLAS)
	pcall(texture.SetAllPoints, texture, button)
	return texture
end

local function FreeText(button)
	local text = ns.OwnText(button, "OVERLAY", FREE_FONT)
	if text == nil then
		return nil
	end
	pcall(text.SetPoint, text, "CENTER", button, "CENTER", 0, 0)
	pcall(text.SetTextColor, text, FREE_COLOUR[1], FREE_COLOUR[2], FREE_COLOUR[3], 1)
	return text
end

-- The region of key on a button, made by make the first time it is wanted; false keeps a refused one from being asked for again.
local function Region(button, state, key, want, make)
	local region = state[key]
	if want and region == nil then
		region = make(button, state) or false
		state[key] = region
	end
	return region or nil
end

-- Shows or hides the region of key, making it when it is wanted.
local function Mark(button, state, key, want, make)
	local region = Region(button, state, key, want, make)
	if region then
		pcall(region.SetShown, region, want)
	end
	return region
end

-- Drawing ---------------------------------------------------------------------------------------------------------------------------------

local function SetIcon(state, icon)
	local texture = state.icon
	if texture == nil then
		return
	end
	if icon ~= nil then
		pcall(texture.SetTexture, texture, icon)
		Crop(state)
		pcall(texture.Show, texture)
	else
		pcall(texture.SetTexture, texture, nil)
		pcall(texture.Hide, texture)
	end
end

local function SetLocked(state, locked)
	local icon = state.icon
	if icon then
		pcall(icon.SetDesaturated, icon, locked == true)
	end
end

-- The cooldown of a live slot, as the game's UpdateCooldown draws it (ContainerFrame.lua:1990-2004): no item hides it, and the icon is grey while
-- a cooldown waits to start.
local function Cooldown(state)
	local frame = state.cooldown
	if frame == nil then
		return
	end
	local grey = false
	local record = state.record
	if record ~= nil and record.live == true then
		local call = Container("GetContainerItemCooldown")
		local ok, start, duration, enable = false, nil, nil, nil
		if call then
			ok, start, duration, enable = pcall(call, state.bag, state.slot)
		end
		if not (ok and ns.Finite(start) and ns.Finite(duration) and ns.Finite(enable)) then
			start, duration, enable = 0, 0, 0
		end
		if type(CooldownFrame_Set) == "function" then
			pcall(CooldownFrame_Set, frame, start, duration, enable)
		end
		grey = duration > 0 and enable == 0
	else
		pcall(frame.Hide, frame)
	end
	local icon = state.icon
	if icon then
		local shade = grey and GREY or 1
		pcall(icon.SetVertexColor, icon, shade, shade, shade)
	end
end

-- The template's new item glow while New item glow is on; off, its glow, store highlight and their animations are hidden, which only its own
-- new item code does otherwise (ContainerFrame.lua:1878-1909).
local function Glow(button, record)
	if record ~= nil and Opt("newGlow") ~= false then
		pcall(button.UpdateNewItem, button, ns.Finite(record.quality) and record.quality or nil)
		return
	end
	for _, key in ipairs({ "NewItemTexture", "BattlepayItemTexture" }) do
		local texture = Field(button, key)
		if texture then
			pcall(texture.Hide, texture)
		end
	end
	for _, key in ipairs({ "flashAnim", "newitemglowAnim" }) do
		local anim = Field(button, key)
		if anim then
			pcall(anim.Stop, anim)
		end
	end
end

-- The quest border or bang of a button made from the intrinsic, as the template's UpdateQuestItem draws it (ContainerFrame.lua:1866-1876).
local function OwnQuest(button, state, record)
	local bang = record ~= nil and record.questStart == true
	local border = record ~= nil and record.quest == true
	local texture = Mark(button, state, "quest", bang or border, QuestTexture)
	if texture and (bang or border) then
		local art = bang and QUEST_BANG or QUEST_BORDER
		pcall(texture.SetTexture, texture, Text(_G[art[1]]) or art[2])
	end
end

local function Level(button, state, record, link)
	local value = nil
	if record ~= nil and link ~= nil and Opt("itemLevel") ~= false then
		value = LevelOf(link)
		-- The record's level is filled by the first part that works it out (design §2.2).
		if value ~= nil and record.level == nil then
			record.level = value
		end
	end
	local text = Mark(button, state, "level", value ~= nil, LevelText)
	if text and value ~= nil then
		local r, g, b = QualityColour(record.quality)
		if r == nil then
			r, g, b = WHITE[1], WHITE[2], WHITE[3]
		end
		pcall(text.SetTextColor, text, r, g, b, 1)
		pcall(text.SetText, text, tostring(math.floor(value + 0.5)))
	end
end

-- Whose marks a record gets (design §2.5.3): the character playing gets all three, and Unusable reads its tooltip by bag and slot while the slot
-- is live, by link otherwise (the bank away from the banker); another character only the BoE mark, which depends on the item and its bound flag.
local function Marks(button, state, record, link)
	local bind, tint, food = false, false, false
	if record ~= nil and state.kind ~= "bagslot" and Opt("marks") ~= false and Usable(ItemMarks) then
		bind = Ask(ItemMarks.BoE, record.id, link, record.bound == true) == true
		if record.key == Me() then
			if record.live == true then
				tint = Ask(ItemMarks.Unusable, record.id, link, record.bag, record.slot) == true
			else
				tint = Ask(ItemMarks.Unusable, record.id, link, nil, nil) == true
			end
			food = Ask(ItemMarks.Eats, record.id) == true
		end
	end
	Mark(button, state, "bind", bind, BindText)
	Mark(button, state, "tint", tint, TintTexture)
	Mark(button, state, "food", food, FoodTexture)
end

-- The junk coin on what B.Categories.IsJunk says Sell junk would sell (design §4.4): the template's own JunkIcon on a live slot.
local function Junk(button, state, record)
	local show = record ~= nil and state.kind ~= "bagslot" and Opt("junkCoin") ~= false and Ask(Categories.IsJunk, record) == true
	if state.kind == "live" then
		local coin = Field(button, "JunkIcon")
		if coin then
			pcall(coin.SetShown, coin, show)
		end
	else
		Mark(button, state, "junk", show, JunkTexture)
	end
end

-- The count of the free slots of a kind, over its first free slot (design §4.5).
local function FreeCount(button, state, count)
	local want = ns.Finite(count) and count >= 0
	local text = Mark(button, state, "freeText", want, FreeText)
	if text and want then
		pcall(text.SetText, text, tostring(math.floor(count)))
	end
end

-- B.Buttons.Dim(button, matched): the search's answer for the record the button shows. Only a search that is typed dims, and an empty slot never.
-- matched is true, false, or nil while the item's data has not loaded; nil dims until it has (design §5.2).
function Buttons.Dim(button, matched)
	local state = states[button]
	if state == nil then
		return
	end
	local dim = state.record ~= nil and state.kind ~= "bagslot" and matched ~= true and Searching()
	pcall(button.SetMatchesSearch, button, not dim)
	local alpha = dim and FADED or 1
	for _, key in ipairs(FADES) do
		local region = state[key]
		if region then
			pcall(region.SetAlpha, region, alpha)
		end
	end
end

-- B.Buttons.Draw(button, record or nil, opts): draws a record on a button of this file (design §2.5.3). opts: free = the count of a free slot of a
-- kind, kind = the kind of its bag, so an empty slot of a special bag takes its fill, hold = an empty slot that keeps its place while the window
-- is open (design §4.8), drawn blank. A template button always shows its own slot: a record of another slot is replaced by the record BagsData
-- gives for the slot.
function Buttons.Draw(button, record, opts)
	local state = states[button]
	if state == nil then
		return
	end
	if not Usable(opts) then
		opts = NONE
	end
	record = RecordOf(record)
	if state.kind == "live" then
		Keep(button, state)
	end
	if record ~= nil and (state.kind == "live" or state.kind == "bank") and not (record.bag == state.bag and record.slot == state.slot) then
		record = RecordOf(Ask(Data.Item, Me(), state.bag, state.slot))
	end
	if record == nil and state.kind == "bagslot" then
		record = BagSlotRecord(state)
	end
	state.record, state.opts = record, opts
	local empty = record == nil and opts.hold ~= true
	local link = record and Text(record.link) or nil
	local icon = record and IconOf(record) or nil
	-- Only a slot the game holds now is read: a live record on a button of the bags or of the bank at the banker.
	local reading = record ~= nil and record.live == true and state.kind ~= "offline"
	local info = reading and Info(state.bag, state.slot) or nil
	SetIcon(state, icon)
	if type(SetItemButtonCount) == "function" then
		pcall(SetItemButtonCount, button, record and CountOf(record) or 0)
	end
	if info ~= nil then
		SetLocked(state, Plain(info.isLocked) == true)
	else
		SetLocked(state, record ~= nil and record.locked == true)
	end
	if state.kind == "live" then
		pcall(button.SetHasItem, button, icon)
		pcall(button.SetReadable, button, info ~= nil and Plain(info.isReadable) == true or nil)
		Cooldown(state)
		pcall(button.UpdateQuestItem, button, record ~= nil and record.quest == true, record ~= nil and record.questStart == true or nil, false)
		Glow(button, record)
	elseif state.kind ~= "bagslot" then
		OwnQuest(button, state, record)
	end
	state.broken = reading and Broken(state.bag, state.slot) or false
	state.fill = empty and opts.kind ~= nil and KindFill(opts.kind, state.bag) or nil
	PaintOne(state)
	Level(button, state, record, link)
	Marks(button, state, record, link)
	Junk(button, state, record)
	FreeCount(button, state, empty and opts.free or nil)
	if state.kind == "bagslot" then
		state.unbought = not Bought(state.slot)
		Mark(button, state, "lock", state.unbought, LockTexture)
	end
	if record ~= nil and record.name == nil then
		Ask(Data.Want, record.id)
	end
	local matched = true
	if record ~= nil and Searching() then
		matched = Ask(Search.Match, record)
	end
	Buttons.Dim(button, matched)
end

-- Tooltips and clicks of the buttons of this file --------------------------------------------------------------------------------------

local function Tooltip()
	local tip = _G.GameTooltip
	if Usable(tip) and not ns.Forbidden(tip) then
		return tip
	end
	return nil
end

local function HideTip(button)
	local tip = Tooltip()
	if tip == nil then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, button)
	if ok and not ns.IsSecret(owned) and owned == true then
		pcall(tip.Hide, tip)
	end
end

-- True when a tooltip call of the game's built a tooltip (TooltipDataHandler.lua:245-307).
local function Built(ok, answer)
	return ok and not ns.IsSecret(answer) and answer == true
end

-- How old a time of BagsData's records is, in days of the calendar: today, yesterday, or so many days ago.
local function DayOf(stamp)
	local ok, parts = pcall(date, "*t", stamp)
	if not ok or not Usable(parts) then
		return nil
	end
	local okNoon, noon = pcall(time, { year = parts.year, month = parts.month, day = parts.day, hour = 12 })
	if not okNoon or not ns.Finite(noon) then
		return nil
	end
	return math.floor(noon / DAY)
end

local function SeenPhrase(stamp)
	if not ns.Finite(stamp) then
		return nil
	end
	local okNow, now = pcall(time)
	if not okNow or not ns.Finite(now) then
		return nil
	end
	local today, seen = DayOf(now), DayOf(stamp)
	if today == nil or seen == nil then
		return nil
	end
	local days = today - seen
	if days <= 0 then
		return SEEN.today
	elseif days == 1 then
		return SEEN.yesterday
	end
	return SEEN.days:format(days)
end

-- The line "Last seen ..." of a cached record: the time of the character's bags, or of its bank for a slot of a bank tab (design §3.1).
local function SeenLine(record)
	if record.live == true then
		return nil
	end
	local list = Ask(Data.Characters)
	if not Usable(list) then
		return nil
	end
	for _, entry in ipairs(list) do
		if Usable(entry) and entry.key == record.key then
			return SeenPhrase(IsTab(record.bag) and entry.bankSeen or entry.seen)
		end
	end
	return nil
end

-- The plain tooltip of a fight, and of an item the game builds no tooltip for: the name in its quality colour and the count.
local function PlainTip(tip, state)
	local record = state.record
	if record == nil then
		if state.kind == "bagslot" then
			return (pcall(tip.SetText, tip, Word(state.unbought and "purchase" or "bankBag")))
		end
		return false
	end
	local r, g, b = QualityColour(record.quality)
	if r == nil then
		r, g, b = WHITE[1], WHITE[2], WHITE[3]
	end
	if not pcall(tip.SetText, tip, NameOf(record), r, g, b) then
		return false
	end
	local count = CountOf(record)
	if count > 1 then
		pcall(tip.AddLine, tip, COUNT_LINE:format(count), WHITE[1], WHITE[2], WHITE[3])
	end
	return true
end

local function Entered(button)
	local state = states[button]
	local tip = Tooltip()
	if state == nil or tip == nil then
		return
	end
	local record = state.record
	if record == nil and state.kind ~= "bagslot" then
		HideTip(button)
		return
	end
	if state.kind == "bagslot" then
		state.unbought = not Bought(state.slot)
	end
	if not pcall(tip.SetOwner, tip, button, "ANCHOR_RIGHT") then
		return
	end
	local shown = false
	if not Fighting() then
		if state.kind == "bagslot" then
			if not state.unbought and record ~= nil and BankLive() then
				shown = Built(pcall(tip.SetBagItem, tip, BANK_BAGS, state.slot))
			end
		elseif state.kind == "bank" and record.live == true and BankLive() then
			shown = Built(pcall(tip.SetBagItem, tip, state.bag, state.slot))
		else
			local link = Text(record.link)
			if link ~= nil then
				shown = Built(pcall(tip.SetHyperlink, tip, link))
			end
		end
	end
	if not shown then
		-- A tooltip the game could not build hid itself and let go of its owner (TooltipDataHandler.lua:264-269).
		pcall(tip.SetOwner, tip, button, "ANCHOR_RIGHT")
		shown = PlainTip(tip, state)
	end
	local seen = record ~= nil and state.kind == "offline" and SeenLine(record) or nil
	if shown and seen ~= nil then
		pcall(tip.AddLine, tip, seen, DIM_TEXT[1], DIM_TEXT[2], DIM_TEXT[3])
	end
	if shown then
		pcall(tip.Show, tip)
	else
		HideTip(button)
	end
end

local function Modified(kind)
	if type(IsModifiedClick) ~= "function" then
		return false
	end
	local ok, held
	if kind then
		ok, held = pcall(IsModifiedClick, kind)
	else
		ok, held = pcall(IsModifiedClick)
	end
	return ok and not ns.IsSecret(held) and held == true
end

-- The whole link of the item a button shows, for chat: read live for the bank at the banker, else the record's, which for a cached item is an item
-- string that C_Item.GetItemInfo makes whole once the client has the item.
local function WholeLink(state)
	local link = nil
	if (state.kind == "bank" or state.kind == "bagslot") and BankLive() then
		local call = Container("GetContainerItemLink")
		if call then
			local ok, found = pcall(call, state.bag, state.slot)
			link = ok and Text(found) or nil
		end
	end
	if link == nil and state.record ~= nil then
		link = Text(state.record.link)
	end
	if link == nil then
		return nil
	end
	if link:find("|H", 1, true) then
		return link
	end
	local api = C_Item
	if type(api) == "table" and not ns.IsSecret(api) and type(api.GetItemInfo) == "function" then
		local ok, _, whole = pcall(api.GetItemInfo, link)
		if ok and Text(whole) and whole:find("|H", 1, true) then
			return whole
		end
	end
	return nil
end

-- A modified click (design §2.5.4): out of a fight the game's HandleModifiedItemClick, in a fight the chat link only.
local function Linked(state)
	local link = WholeLink(state)
	if link == nil then
		return
	end
	if Fighting() then
		local util = _G.ChatFrameUtil
		if Modified("CHATLINK") and Usable(util) and type(util.InsertLink) == "function" then
			pcall(util.InsertLink, link)
		end
		return
	end
	if type(HandleModifiedItemClick) == "function" then
		pcall(HandleModifiedItemClick, link)
	end
end

-- A click, drag or drop on a bank slot or bank bag slot (design §2.4).
local function Use(state, mouse)
	if Fighting() then
		Say(SAY.fight)
		return
	end
	if not BankLive() then
		Say(SAY.closed)
		return
	end
	if state.kind == "bagslot" then
		state.unbought = not Bought(state.slot)
		local pickup = Container("PickupContainerItem")
		if pickup and not state.unbought then
			pcall(pickup, BANK_BAGS, state.slot)
		end
	elseif mouse == "RightButton" then
		local use = Container("UseContainerItem")
		if use then
			pcall(use, state.bag, state.slot)
		end
	else
		local pickup = Container("PickupContainerItem")
		if pickup then
			pcall(pickup, state.bag, state.slot)
		end
	end
end

local function Clicked(button, mouse)
	local state = states[button]
	if state == nil then
		return
	end
	if Modified(nil) then
		Linked(state)
	elseif state.kind ~= "offline" then
		Use(state, mouse)
	end
end

local function Dragged(button)
	local state = states[button]
	if state ~= nil and state.kind ~= "offline" then
		Use(state, "LeftButton")
	end
end

local function OnClick(button, mouse)
	Part(Clicked, button, mouse)
end

local function OnDrag(button)
	Part(Dragged, button)
end

local function OnEnter(button)
	Part(Entered, button)
end

local function OnLeave(button)
	pcall(HideTip, button)
end

local function Scripts(button, state)
	pcall(button.RegisterForClicks, button, "LeftButtonUp", "RightButtonUp")
	pcall(button.SetScript, button, "OnClick", OnClick)
	pcall(button.SetScript, button, "OnEnter", OnEnter)
	pcall(button.SetScript, button, "OnLeave", OnLeave)
	if state.kind ~= "offline" then
		pcall(button.RegisterForDrag, button, "LeftButton")
		pcall(button.SetScript, button, "OnDragStart", OnDrag)
		pcall(button.SetScript, button, "OnReceiveDrag", OnDrag)
	end
end

-- Making the buttons ----------------------------------------------------------------------------------------------------------------------

local function Holder(bag)
	local holder = holders[bag]
	if holder ~= nil then
		return holder
	end
	local home = Home("bags")
	local ok, made = pcall(CreateFrame, "Frame", nil, home)
	if not ok or not IsFrame(made) then
		return nil
	end
	ns.Own[made] = true
	pcall(made.SetID, made, bag)
	if home then
		pcall(made.SetAllPoints, made, home)
	end
	if bag == KEYRING then
		pcall(made.SetShown, made, keyringShown == true)
	end
	holders[bag] = made
	return made
end

-- Makes the template button of a slot, out of combat only. warm: it goes to the next warm-up.
local function Make(bag, slot, warm)
	local list = live[bag]
	if list == nil then
		list = {}
		live[bag] = list
	end
	if list[slot] ~= nil then
		return list[slot]
	end
	if refused or Fighting() then
		return nil
	end
	local holder = Holder(bag)
	if holder == nil then
		return nil
	end
	local ok, button = pcall(CreateFrame, "ItemButton", LIVE_NAME:format(bag + 10, slot), holder, TEMPLATE)
	if not ok or not IsFrame(button) then
		refused = true
		ns.Note(KEY, SAY.refused)
		return nil
	end
	ns.Own[button] = true
	pcall(button.SetID, button, slot)
	local state = { kind = "live", bag = bag, slot = slot, holder = holder }
	states[button] = state
	Style(button, state)
	Lift(button, state)
	list[slot] = button
	if warm then
		unwarmed[#unwarmed + 1] = button
	end
	return button
end

-- Makes a button of this file's own from the intrinsic: a bank slot, a bank bag slot or an offline slot. It starts hidden, as the template does.
local function MakeOwn(name, parent, kind, bag, slot)
	local ok, button = pcall(CreateFrame, "ItemButton", name, parent)
	if not ok or not IsFrame(button) then
		return nil
	end
	ns.Own[button] = true
	pcall(button.Hide, button)
	local state = { kind = kind, bag = bag, slot = slot }
	states[button] = state
	Style(button, state)
	Scripts(button, state)
	return button
end

-- B.Buttons.Live(bag, slot): the template button of a slot of the bags, or nil while it has none. Out of combat a missing one is made at once:
-- the layout asks for it as it shows the window, so its first show is out of combat. A slot past the bag's size, and the keyring while the game
-- shows none, have no button.
function Buttons.Live(bag, slot)
	if not IsBag(bag) or not Whole(slot) or slot < 1 then
		return nil
	end
	if bag == KEYRING then
		if keyringShown == nil then
			keyringShown = KeyringShows()
		end
		if not keyringShown then
			return nil
		end
	end
	if sizes[bag] == nil or slot > sizes[bag] then
		sizes[bag] = SizeOf(bag)
	end
	if slot > sizes[bag] then
		return nil
	end
	local list = live[bag]
	local button = list and list[slot] or nil
	if button == nil then
		button = Make(bag, slot, false)
		if button == nil then
			return nil
		end
	end
	local state = states[button]
	Keep(button, state)
	if Rehome(state.holder, "bags", true) then
		LiftBag(bag)
	end
	return button
end

-- B.Buttons.Bank(tab, slot): the button of a slot of a bank tab (6 to 14) while the bank is live, or with tab -2 the button of bank bag slot n.
function Buttons.Bank(tab, slot)
	if not Whole(slot) or slot < 1 or not (tab == BANK_BAGS or IsTab(tab)) then
		return nil
	end
	local list = banks[tab]
	if list == nil then
		list = {}
		banks[tab] = list
	end
	local button = list[slot]
	if button ~= nil then
		Rehome(button, "bank", false)
		return button
	end
	local bagSlot = tab == BANK_BAGS
	local name = bagSlot and BAG_SLOT_NAME:format(slot) or BANK_NAME:format(tab, slot)
	button = MakeOwn(name, Home("bank"), bagSlot and "bagslot" or "bank", tab, slot)
	list[slot] = button
	return button
end

-- The frame an owner's offline buttons go in: the owner when it is a frame, else the window it names.
local function ParentFor(owner)
	if IsFrame(owner) then
		return owner
	elseif owner == "bank" then
		return Home("bank")
	end
	return Home("bags")
end

-- B.Buttons.Offline(owner): a free offline button for the slots of another character or of the bank away from the banker, held by owner (a
-- window's key, "bags" or "bank", or a frame, which it is put in) until B.Buttons.Release(owner). It comes hidden.
function Buttons.Offline(owner)
	local key = owner
	if key == nil then
		key = "bags"
	end
	local parent = ParentFor(owner)
	local button = table.remove(pool)
	if button == nil then
		offlineMade = offlineMade + 1
		button = MakeOwn(OFFLINE_NAME:format(offlineMade), parent, "offline")
		if button == nil then
			return nil
		end
	else
		local ok, current = pcall(button.GetParent, button)
		if parent ~= nil and not (ok and not ns.IsSecret(current) and rawequal(current, parent)) then
			pcall(button.SetParent, button, parent)
		end
	end
	states[button].owner = key
	local list = used[key]
	if list == nil then
		list = {}
		used[key] = list
	end
	list[#list + 1] = button
	return button
end

local function Return(button)
	pcall(button.Hide, button)
	HideTip(button)
	local state = states[button]
	if state then
		state.record, state.opts, state.owner = nil, nil, nil
	end
	pool[#pool + 1] = button
end

-- B.Buttons.Release(owner): every offline button the owner holds goes back to the pool, hidden; with no owner, every one.
function Buttons.Release(owner)
	if owner == nil then
		for key, list in pairs(used) do
			used[key] = nil
			for _, button in ipairs(list) do
				Return(button)
			end
		end
		return
	end
	local list = used[owner]
	if list == nil then
		return
	end
	used[owner] = nil
	for _, button in ipairs(list) do
		Return(button)
	end
end

-- B.Buttons.ShowAll(on): with true, every live button the bags have now is shown, for the warm-up of B.Window.Warm, which shows the window at alpha
-- 0 for one frame (design §2.5.1); with false, each goes back to the shown flag it had.
function Buttons.ShowAll(on)
	if not on then
		local was = warming
		warming = nil
		if was == nil then
			return
		end
		for button, shown in pairs(was) do
			if not shown then
				pcall(button.Hide, button)
			end
		end
		return
	end
	RehomeAll()
	warming = warming or {}
	for bag, list in pairs(live) do
		local holder = holders[bag]
		local okShown, shows = false, false
		if holder then
			okShown, shows = pcall(holder.IsShown, holder)
		end
		if okShown and not ns.IsSecret(shows) and shows == true then
			local size = sizes[bag] or 0
			for slot, button in pairs(list) do
				if slot <= size then
					Keep(button, states[button])
					if warming[button] == nil then
						local ok, shown = pcall(button.IsShown, button)
						warming[button] = ok and not ns.IsSecret(shown) and shown == true
					end
					pcall(button.Show, button)
				end
			end
		end
	end
end

-- Prepare and the top-up ----------------------------------------------------------------------------------------------------------------

-- The bags to make buttons for, the given ones first, then the rest: 0 to 5, and the keyring while the game shows one. Their sizes are read again,
-- the buttons past a bag's size are hidden, and the keyring's holder shows only with the keyring.
local function Wanted(containers)
	keyringShown = KeyringShows()
	local keyring = holders[KEYRING]
	if keyring then
		pcall(keyring.SetShown, keyring, keyringShown)
	end
	local list, taken = {}, {}
	local function Take(bag)
		if IsBag(bag) and not taken[bag] and (bag ~= KEYRING or keyringShown) then
			taken[bag] = true
			list[#list + 1] = bag
		end
	end
	if Usable(containers) then
		for _, bag in ipairs(containers) do
			Take(bag)
		end
	end
	for _, bag in ipairs(BAGS) do
		Take(bag)
	end
	Take(KEYRING)
	if not keyringShown then
		sizes[KEYRING] = 0
	end
	for _, bag in ipairs(list) do
		local size = SizeOf(bag)
		sizes[bag] = size
		for slot, button in pairs(live[bag] or NONE) do
			if slot > size then
				pcall(button.Hide, button)
			end
		end
	end
	return list
end

-- The slots of these bags that have no button yet, in order.
local function Missing(list)
	local missing = {}
	for _, bag in ipairs(list) do
		local made = live[bag]
		for slot = 1, sizes[bag] or 0 do
			if not (made and made[slot]) then
				missing[#missing + 1] = { bag, slot }
			end
		end
	end
	return missing
end

-- Hands the buttons made since the last warm-up to B.Window.Warm, once their holders are in the window. While Bags is off, stopped or stood down
-- nothing shows, and they wait for the next Prepare or the top-up at the start of a fight.
local function Finish()
	if #unwarmed == 0 or not On() then
		return
	end
	local list = unwarmed
	unwarmed = {}
	RehomeAll()
	Ask(Window.Warm, "bags", list)
end

local Queue

-- One frame of a Prepare run: STEP buttons, then the next frame, until every slot has one. A fight stops the run, and the rest waits for its end.
local function Step()
	if pending == nil then
		running = false
		return
	end
	if Fighting() then
		pending, running = nil, false
		Queue()
		return
	end
	local count = 0
	while pending ~= nil and nextIndex <= #pending and count < STEP do
		local entry = pending[nextIndex]
		nextIndex = nextIndex + 1
		count = count + 1
		Make(entry[1], entry[2], true)
		if refused then
			pending = nil
		end
	end
	if pending ~= nil and nextIndex <= #pending then
		Soon(function()
			Part(Step)
		end)
		return
	end
	pending, running = nil, false
	Finish()
end

-- The work of B.Buttons.Prepare(containers). Its callers (Bags.lua's Start, BagsData.lua's BAG_CONTAINER_UPDATE) call it only while Bags is on.
local function Prepare(containers)
	local list = Wanted(containers)
	if Fighting() then
		Queue()
		return
	end
	local missing = Missing(list)
	if #missing == 0 then
		if not running then
			pending = nil
			Finish()
		end
		return
	end
	pending, nextIndex = missing, 1
	if not running then
		running = true
		Step()
	end
end

-- A Prepare asked for in a fight waits for its end, once, whatever the number of asks, and runs then only while Bags is still on.
function Queue()
	if queued then
		return
	end
	queued = true
	ns.OutOfCombat(function()
		queued = false
		if On() then
			Buttons.Prepare(nil)
		end
	end)
end

-- B.Buttons.Prepare(containers): out of combat, a template button for every slot of the bags, the containers given first, STEP to a frame, then
-- the warm-up of what it made. In a fight it waits for the end of the fight.
function Buttons.Prepare(containers)
	Part(Prepare, containers)
end

-- PLAYER_REGEN_DISABLED, before the lockdown: every missing template button at once, normally none, and the warm-up of those and of any a run left
-- unwarmed (design §2.5.1).
local function TopUp()
	if not On() then
		return
	end
	local list = Wanted(nil)
	for _, entry in ipairs(Missing(list)) do
		Make(entry[1], entry[2], true)
	end
	pending, running = nil, false
	Finish()
end

-- Locks, cooldowns and the look --------------------------------------------------------------------------------------------------------

-- B.Buttons.Lock(bag, slot): ITEM_LOCK_CHANGED for one slot of the bags, or of the bank while it is live: its icon is desaturated while the game
-- holds it locked, read live; nothing else of the button is drawn again.
function Buttons.Lock(bag, slot)
	if not Whole(bag) or not Whole(slot) then
		return
	end
	local list
	if IsBag(bag) then
		list = live[bag]
	elseif IsTab(bag) or bag == BANK_BAGS then
		list = banks[bag]
	end
	local button = list and list[slot] or nil
	local state = button and states[button] or nil
	if state == nil or state.record == nil or state.record.live ~= true then
		return
	end
	local info = Info(bag, slot)
	SetLocked(state, info ~= nil and Plain(info.isLocked) == true)
end

-- B.Buttons.Cooldowns(): the cooldowns of the live buttons on screen, only while a window shows a bag.
function Buttons.Cooldowns()
	local shown = false
	for _, holder in pairs(holders) do
		local ok, visible = pcall(holder.IsVisible, holder)
		if ok and not ns.IsSecret(visible) and visible == true then
			shown = true
			break
		end
	end
	if not shown then
		return
	end
	for _, list in pairs(live) do
		for _, button in pairs(list) do
			local state = states[button]
			if state and state.record ~= nil then
				local ok, visible = pcall(button.IsVisible, button)
				if ok and not ns.IsSecret(visible) and visible == true then
					Cooldown(state)
				end
			end
		end
	end
end

-- B.Buttons.Paint(): the look rows again on every button (Icon crop, Button and slot colour, Quality border), from what each shows.
function Buttons.Paint()
	for _, state in pairs(states) do
		PaintOne(state)
	end
end

-- Events (design §2.8) ----------------------------------------------------------------------------------------------------------------------

ns.AddEvent(KEY, "ITEM_LOCK_CHANGED", function(bag, slot)
	if On() then
		Part(Buttons.Lock, bag, slot)
	end
end, function(bag, slot)
	return ns.Finite(bag) and ns.Finite(slot)
end)

ns.AddEvent(KEY, "BAG_UPDATE_COOLDOWN", function()
	if On() then
		Part(Buttons.Cooldowns)
	end
end)

ns.AddEvent(KEY, "PLAYER_REGEN_DISABLED", function()
	Part(TopUp)
end)
