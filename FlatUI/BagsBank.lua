local _, ns = ...

-- Bags: the live bank (design 2.4 and 6). This file owns the bank's events and keeps the state of a visit to a banker; it ends the visit where the
-- game would end it in BankFrame's OnHide, draws the row of bank bag slots with the Buy button, moves the items that match the search with Deposit
-- and Take out, and makes the button of the Flat UI bank key.
--
-- A visit. The game opens its bank window through the interaction manager: PLAYER_INTERACTION_MANAGER_FRAME_SHOW with Banker (8), CharacterBanker
-- (67) or AccountBanker (68) calls BankFrame_Open (Blizzard_UIPanels_Game/Mainline/BankFrameTemplates.lua:111-138; Shared/
-- PlayerInteractionFrameManager.lua:114-137; enums.yaml:6250-6265), and the game sends BANKFRAME_OPENED as well (BankDocumentation.lua:398;
-- PlayerInteractionManagerDocumentation.lua:113). The first of the two starts the visit and the other belongs to it; BANKFRAME_CLOSED, or
-- PLAYER_INTERACTION_MANAGER_FRAME_HIDE with one of those interactions, ends it once (BankDocumentation.lua:392;
-- PlayerInteractionManagerDocumentation.lua:103). Flat UI's bank window is the live bank of a visit when Bags keeps the game's BankFrame under its
-- hidden frame as the visit starts (ns.BagsParked of Bags.lua, while At the banker is Flat UI's bank window): BankFrame_Open still shows that frame,
-- so the game's own check passes (BankFrameTemplates.lua:120-123), and nothing of it is seen. Otherwise the game's bank window is the live one and
-- Flat UI's shows the records. The state is set first and the other files of Bags are called after it, each step as the part of Bags that does it
-- (B.Part), so a step that fails stops its own part and the steps after it still run. The work of each event, in order (design 2.8):
-- - BANKFRAME_OPENED and the interaction's show: the live state; B.Data.BankScan, the records of the bank; B.BankOpened, the bank hold of Bags.lua;
--   then, for Flat UI's live bank, this character in the bank window (B.SetViewing) and B.Window.Show("bank").
-- - BANKFRAME_CLOSED and the interaction's hide: the live state off, and a pass of Deposit or Take out ends; B.Data.BankClosed; B.BankClosed, which
--   drops the bank hold and closes the bag window when nothing else holds it; B.Request("layout", "bank"): the live window turns into the records.
-- - PLAYERBANKSLOTS_CHANGED, and BANK_TABS_CHANGED of the character bank (BankDocumentation.lua:382 and 414), during a visit: B.Data.BankTabs; the
--   row of bank bag slots and the Buy button; B.Request("layout", "bank") when the bought tabs or the bags in them changed, since the items in the
--   tabs reach the window slot by slot and nothing moves while it is open.
-- These events reach the module only while it is on, so when the page comes up again Bank.Settle ends a visit that ended meanwhile, one whose
-- BankFrame is no longer shown (the game shows it, hidden by Bags or not, for as long as a visit lasts), and starts one that began meanwhile, whose
-- BankFrame shows while the client does not say the player deals with no banker (C_PlayerInteractionManager.IsInteractingWithNpcOfType with
-- Banker, CharacterBanker and AccountBanker). Bags does not hide a BankFrame that shows, so the game's bank window is the live bank of that visit.
--
-- Ending a visit. The game ends the bank in BankFrame's OnHide (BankFrameTemplates.lua:104-109), which a frame under a hidden parent never runs. So
-- Flat UI calls C_Bank.CloseBankFrame (BankDocumentation.lua:121; apis.yaml:3353) once a visit, while its bank window is the live one:
-- - when that window hides: its close button, the bank key, or Escape, which hides the windows of UISpecialFrames through a securecall
--   (Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua:1106-1116 and 1168). Its OnHide is followed with HookScript, on a frame of Flat
--   UI's own; a window hidden with its parent, as under Alt+Z, keeps its shown flag (IsShown) and ends nothing.
-- - when the game hides BankFrame with HideUIPanel, which is followed with ns.FollowGlobal the first time a visit starts live: Escape
--   (UIParentPanelManager.lua:1130-1132 and 1175-1177), walking away (PlayerInteractionFrameManager.lua:139-163), or another panel taking its place.
--   Only the first argument is read, compared with rawequal, and only a BankFrame whose shown flag is false after the call counts: the game refuses a
--   hide asked by an addon in a fight (UIParentPanelManager.lua:853-861 and 905-922).
-- The game then sends BANKFRAME_CLOSED, and the visit ends as above.
--
-- The row of bank bag slots (Bank.Slots, in a frame of Bags' own that the bank window gives it). Tab 1 is the bank's own slots; tabs 2 to 9 are the
-- bags put in the bank bag slots, the item at Enum.BagIndex.Characterbanktab (-2), slot n (Blizzard_UIPanels_Game/Camelot/BankFrame.lua:136-191 and
-- 301-327; enums.yaml:561), and a slot is bought when n is no more than C_Bank.FetchNumPurchasedBankTabs (the game lights slot n when the n-th entry
-- of its list of bought tabs exists, BankFrame.lua:172-183). The row shows slots 2 to C_Bank.FetchMaxNumBankTabs, at most nine
-- (Constants.InventoryConstants.NumCharacterBankSlots), as buttons of Flat UI's own: the bag's icon from C_Container.GetContainerItemInfo(-2, n), the
-- game's lock (the atlas bankslot-icon-lock, Camelot/BankFrame.xml:11) on a slot not bought. A click, a drag or a drop calls
-- C_Container.PickupContainerItem(-2, n), as the game's own bag slot does (BankFrame.lua:378-395), out of combat. The tooltip is the game's for the
-- bag (GameTooltip:SetOwner, SetBagItem, Show) out of combat, as the game's slot shows it (BankFrame.lua:329-342), and plain lines (SetText, AddLine)
-- in a fight or for an empty or unbought slot; it is hidden (Hide) when the cursor leaves the button that owns it (IsOwned).
-- The first slots and the Buy button. The game's bank window buys the first tab itself whenever it selects a tab while that tab costs nothing
-- (BankFrame.lua:197-206 and 232-236), which never runs while BankFrame is hidden. So while no tab is bought the row says "Your bank has no space
-- yet." beside a Buy button, and later the button stays beside the slots while C_Bank.CanPurchaseBankTab says more can be bought (apis.yaml:3321).
-- The button is a frame of Flat UI's own from the game's template for addons, BankPanelPurchaseButtonScriptTemplate, given the attribute
-- overrideBankType (Enum.BankType.Character) out of combat (Mainline/BankFrameTemplates.xml:513-521); its click is the game's own, which shows the
-- game's question CONFIRM_BUY_BANK_TAB (BankFrameTemplates.lua:1324-1340), whose Yes buys (Camelot/BankFrame.lua:1-22). Flat UI sets only its size,
-- place, look and its OnEnter and OnLeave, never its OnClick. Its tooltip gives the price and whether it can be paid, from
-- C_Bank.FetchNextPurchasableBankTabData (BankDocumentation.lua:211 and 454; apis.yaml:3406). Asked in a fight (InCombatLockdown, through
-- Errands.InCombat), it is made at the end of it (ns.OutOfCombat).
--
-- Deposit and Take out (design 6) move every item that matches the search, one at a time: a deposit takes from the bags 0 to 5 (never the keyring)
-- with C_Container.UseContainerItem(bag, slot, nil, Enum.BankType.Character, false), as the game's own right-click at a banker does
-- (Mainline/ContainerFrame.lua:1611), and Take out takes from the bought tabs of the bank with C_Container.UseContainerItem(tab, slot) and no bank
-- type, as the game's bank buttons do (BankFrameTemplates.lua:445-456; ContainerDocumentation.lua:584). A pass reads each slot of those containers
-- (C_Container.GetContainerNumSlots and GetContainerItemInfo, ContainerDocumentation.lua:192, 313 and 766) and takes the unlocked items whose record
-- (B.Data.Item) the search matches (B.Search.Match). The first move is made inside the click, the next ones SPACING seconds apart on the game's timer
-- (C_Timer.After), the spacing of Errands' selling (ErrandsMerchant.lua:55-56). Before each move: the bank still live; no fight (Errands.Fighting,
-- Errands.lua:321-323: InCombatLockdown or UnitAffectingCombat), else the pass waits and looks again each second; the cursor empty (GetCursorInfo,
-- CursorHasItem); none of MerchantFrame, TradeFrame, MailFrame, AuctionHouseFrame or GuildBankFrame shown (Errands.Shown, Errands.lua:265-271, the
-- widget call IsShown), since the same call would sell, trade, mail or post; and the slot still holding the same unlocked item. A slot still
-- unchanged WAIT seconds after its move stops the pass with "the bank has no room" or "your bags have no room"; one the game still holds locked is
-- looked at again. After a fight the pass reads the bags or the bank again, and stops if the search was cleared meanwhile, since every item would
-- match then. A second click on the same button stops a running pass. The end is said through Errands.Say (Errands.lua:86-91): "Deposited 12
-- items." In a fight, or with the cursor full, a window above open or no search typed, a click moves nothing and says why (print). With PER_CLICK
-- true each click moves the next matching item inside the click and Bank.Busy gives how many are left: the fallback for a server that ignores bank
-- moves made from a timer (design 10.2, in-game check 5), the only precedent for a bank type from addon code being inside a click.
--
-- The bank key: Bindings.xml binds a click of FlatUIBankButton (CLICK FlatUIBankButton:LeftButton), a plain button of Flat UI's own made here as
-- the file loads, a child of UIParent with no size and no point, so it shows nothing and takes no mouse, as Mount key's (MountKey.lua:30-31). The game
-- sends the press and the release of a key bound to a click (Blizzard_FrameXML/SecureTemplates.lua:802-811); the button hears the release only, so a
-- key press toggles the bank window once. The name of the binding is the global BINDING_NAME_CLICK FlatUIBankButton:LeftButton, as Mount key names
-- its own (MountKey.lua:86).
--
-- What the other files of Bags use: Bank.Live (Flat UI's bank window is the live bank now), Bank.Visiting (a visit to a banker is under way, in
-- either bank window: nothing becomes new then), Bank.Settle (Bags.lua, when the page comes up, once the bag slots are made, since a visit it starts
-- may open the bag window), Bank.Toggle (the slash word bank and the key),
-- Bank.Deposit, Bank.TakeOut and Bank.Busy (the buttons of the bank window), Bank.Slots (the row in the strip of the bank window, which takes the
-- height Slots returns and hides when it is 0).
--
-- Every game call runs inside pcall (each piece of work runs in B.Part, which is one), every game answer goes through ns.IsSecret or ns.Finite before
-- it is compared, counted, joined or used as a key, and nothing of the game's frames is written: BankFrame is only read (IsShown) and compared.

local B = ns.Bags
if type(B) ~= "table" or type(B.Bank) ~= "table" then
	return
end
local Bank = B.Bank
local E = ns.Errands

local KEY = "bags"
local PART = "bank"
-- Enum.BankType.Character and Enum.BagIndex.Characterbanktab, for a client whose enumerations do not say (enums.yaml:561 and 608-612).
local CHARACTER, BANK_BAGS = 0, -2
-- The interactions the game opens its bank window for (BankFrameTemplates.lua:126-138), and their numbers when the client does not say.
local BANKERS = { Banker = 8, CharacterBanker = 67, AccountBanker = 68 }
-- The bank bag slots after the bank's own, from 2 to at most 9 (Constants.InventoryConstants.NumCharacterBankSlots and MAX_TRANSACTION_BANK_TABS,
-- globals.yaml:204 and 207).
local FIRST_BAG, MOST_BAGS = 2, 9
-- The bags a deposit takes from: the backpack, the four bags and the reagent bag (Enum.BagIndex 0 to 5). The keyring keeps its keys.
local BAGS = { 0, 1, 2, 3, 4, 5 }
-- More slots than a container ever has; a larger answer is no answer.
local MOST_SLOTS = 200
-- Seconds between two moves; seconds after a move before its slot is looked at again, and how many looks a slot the game holds locked gets; seconds
-- between two looks at the end of a fight.
local SPACING = 0.15
local WAIT, LOOKS = 1, 3
local POLL = 1
-- The fallback of design 6: true makes each click of Deposit or Take out move one item inside the click.
local PER_CLICK = false
-- Windows whose open state turns the same call into a sale, a trade, a mail or a post.
local BLOCKERS = {
	{ "MerchantFrame", "merchant window" },
	{ "TradeFrame", "trade window" },
	{ "MailFrame", "mailbox" },
	{ "AuctionHouseFrame", "auction house" },
	{ "GuildBankFrame", "guild bank" },
}
local WORDS = {
	deposit = { label = "Deposit", done = "Deposited", none = "Deposited nothing", room = "the bank has no room for %s",
		empty = "no item in your bags matches the search" },
	takeout = { label = "Take out", done = "Took out", none = "Took nothing out", room = "your bags have no room for %s",
		empty = "no item in your bank matches the search" },
}
-- The row: the size of a bag slot and the space between two, the size of the Buy button, and its template.
local SLOT, GAP = 28, 4
local BUY_WIDTH, BUY_HEIGHT = 56, 22
local TEMPLATE = "BankPanelPurchaseButtonScriptTemplate"
local LOCK = "bankslot-icon-lock"
local NO_SPACE = "Your bank has no space yet."
-- The tint under the cursor, as on the slots of the windows (Windows.lua:59), and the colour of the plain lines of a tooltip.
local HOVER = { 1, 1, 1, 0.3 }
local DIM = { 0.8, 0.8, 0.8 }
local RED = { 1, 0.35, 0.24 }
-- The crop of an icon when the Windows page does not say.
local CROP = 8

local BUTTON = "FlatUIBankButton"
local BINDING = "CLICK " .. BUTTON .. ":LeftButton"

-- The name of the binding in the game's Key Bindings, under Flat UI.
_G["BINDING_NAME_" .. BINDING] = "Flat UI bank"

-- open: a visit to a banker is under way; flat: Flat UI's bank window is its live bank; closing: C_Bank.CloseBankFrame was asked for it.
local open, flat, closing = false, false, false
-- The pass of Deposit or Take out, or nil: { kind, queue, next, moved, checks, paused, draining, left }. queue and next serve a pass of timers,
-- left a pass of clicks; checks counts the moves whose slot has not been looked at again yet.
local pass
-- The row of bank bag slots, made by Bank.Slots: { frame, parent, slots = { [n] = slot }, text, buy, buyBox }.
local row
-- The Buy button waits for the end of a fight; the game did not make it.
local buyQueued, buyBroken = false, false
-- The bank window whose OnHide is followed, and whether HideUIPanel is.
local watched
local following = false

local Finish, Resume, Update

-- Small helpers ------------------------------------------------------------------------------------------------------------------------------

local function Usable(value)
	return value ~= nil and not ns.IsSecret(value) and type(value) == "table"
end

local function Field(info, key)
	local value = info[key]
	if ns.IsSecret(value) then
		return nil
	end
	return value
end

-- A value of the game's enumerations, or the number the client lists when it does not say.
local function EnumValue(group, name, fallback)
	local enum = type(Enum) == "table" and not ns.IsSecret(Enum) and Enum[group] or nil
	local value = Usable(enum) and enum[name] or nil
	return ns.Finite(value) and value or fallback
end

local function Character()
	return EnumValue("BankType", "Character", CHARACTER)
end

-- A function of C_Container, or nil when the client has none.
local function Container(name)
	local api = C_Container
	if not Usable(api) then
		return nil
	end
	local fn = api[name]
	return type(fn) == "function" and fn or nil
end

-- The first answer of a function of C_Bank about the character bank, or nil when the client lacks it, raises or withholds it.
local function BankAsk(name)
	local api = C_Bank
	if not Usable(api) then
		return nil
	end
	return (E.Ask(api[name], Character()))
end

local function After(seconds, fn)
	if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		return false
	end
	return (pcall(C_Timer.After, seconds, fn))
end

-- True while Bags is on, not stopped and not standing down (B.On, Bags.lua).
local function On()
	local on = B.On
	if type(on) ~= "function" then
		return false
	end
	local ok, yes = pcall(on)
	return ok and yes == true
end

-- Runs fn as the bank part of Bags (B.Part, Bags.lua): a failure stops this part alone.
local function Run(fn, ...)
	local part = B.Part
	if type(part) ~= "function" then
		return false
	end
	return part(PART, fn, ...)
end

-- Runs owner[name] of another file of Bags, when it is there, as the part of Bags its work belongs to, so its failure stops that part and the
-- steps after it still run.
local function Call(part, owner, name, ...)
	local fn = Usable(owner) and owner[name] or nil
	local run = B.Part
	if type(fn) ~= "function" or type(run) ~= "function" then
		return false
	end
	return run(part, fn, ...)
end

-- The bank window's footer shows whether a pass runs (Bank.Busy): it is drawn again on the next frame.
local function RequestFooter()
	Call("window", B, "Request", "footer", "bank")
end

local function Items(n)
	return n == 1 and "item" or "items"
end

-- The cursor holds something.
local function CursorBusy()
	return E.Ask(GetCursorInfo) ~= nil or E.Ask(CursorHasItem) == true
end

-- The words of the first window open whose state would turn a move into something else, or nil.
local function Blocker()
	for _, entry in ipairs(BLOCKERS) do
		if E.Shown(_G[entry[1]]) then
			return entry[2]
		end
	end
	return nil
end

-- What a slot holds now, read from the game: { id, link, count, locked, icon, name }, or nil for an empty slot or an answer the client withholds.
-- A lock it does not plainly deny counts as locked.
local function Held(bag, slot)
	local get = Container("GetContainerItemInfo")
	local info = get and E.Ask(get, bag, slot) or nil
	if not Usable(info) then
		return nil
	end
	local id = Field(info, "itemID")
	if not ns.Finite(id) then
		return nil
	end
	local link, count, locked = Field(info, "hyperlink"), Field(info, "stackCount"), Field(info, "isLocked")
	local icon, name = Field(info, "iconFileID"), Field(info, "itemName")
	return {
		id = id,
		link = type(link) == "string" and link or nil,
		count = ns.Finite(count) and count > 0 and count or 1,
		locked = locked ~= false,
		icon = (ns.Finite(icon) or type(icon) == "string") and icon or nil,
		name = type(name) == "string" and name ~= "" and name or nil,
	}
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

-- The live state --------------------------------------------------------------------------------------------------------------------------

-- Whether Bags keeps the game's BankFrame hidden (ns.BagsParked, Bags.lua), which makes Flat UI's bank window the live one. Without that answer the
-- game's bank window stays the live one.
local function Parked()
	local parked, frame = ns.BagsParked, _G.BankFrame
	if type(parked) ~= "function" or not Usable(frame) then
		return false
	end
	local ok, yes = pcall(parked, frame)
	return ok and yes == true
end

-- True while Flat UI's bank window is the live bank: at a banker, with BankFrame kept hidden, the visit not ending and Bags on.
function Bank.Live()
	return open and flat and not closing and On()
end

-- True while a visit to a banker is under way, with Flat UI's bank window or the game's, until the game says it ended: what comes out of the
-- bank then is not loot (New items, BagsCategories.lua).
function Bank.Visiting()
	return open == true
end

-- Asks the game to end the visit, once, as BankFrame's OnHide would. Plain code with no part around it, so a part that stopped cannot leave the
-- game's bank open behind a hidden frame.
local function EndVisit()
	if not open or not flat or closing then
		return
	end
	closing = true
	local api = C_Bank
	if Usable(api) and type(api.CloseBankFrame) == "function" then
		pcall(api.CloseBankFrame)
	end
end

-- The bank window hid. A window hidden with its parent keeps its shown flag and ends nothing.
local function WindowHidden(window)
	if open and flat and not closing and not E.Shown(window) then
		EndVisit()
	end
end

-- Follows the OnHide of the bank window (a frame of Flat UI's own, from B.Window.Get), once for each window.
local function Watch()
	local window = B.Window.Get("bank")
	if window == watched or not Usable(window) or ns.Forbidden(window) or type(window.HookScript) ~= "function" then
		return
	end
	if pcall(window.HookScript, window, "OnHide", WindowHidden) then
		watched = window
	end
end

-- After the game's HideUIPanel: the visit ends when it was BankFrame and the frame is hidden now.
local function PanelHidden(frame)
	if not open or not flat or closing or frame == nil or ns.IsSecret(frame) then
		return
	end
	local bank = _G.BankFrame
	if bank == nil or ns.IsSecret(bank) or not rawequal(frame, bank) or E.Shown(bank) then
		return
	end
	EndVisit()
end

local function Follow()
	if not following then
		following = ns.FollowGlobal("HideUIPanel", PanelHidden) == true
	end
end

-- The row of bank bag slots and the Buy button -------------------------------------------------------------------------------------------

local function Bought()
	local n = BankAsk("FetchNumPurchasedBankTabs")
	return ns.Finite(n) and n >= 0 and math.floor(n) or 0
end

local function MostBags()
	local n = BankAsk("FetchMaxNumBankTabs")
	if ns.Finite(n) and n >= 1 then
		return math.min(math.floor(n), MOST_BAGS)
	end
	return MOST_BAGS
end

-- The crop of the icons, from the Windows page (B.Look, Bags.lua), as a share of each edge.
local function Crop()
	local look = B.Look
	local crop = type(look) == "function" and look("crop") or nil
	crop = ns.Finite(crop) and crop or CROP
	return math.max(0, math.min(crop, 15)) / 100
end

-- A box of the row in the button and slot colour of the Windows page, as the bag slots are.
local function Paint(box)
	if box then
		local r, g, b = ns.Colour("windows.panel")
		ns.SetOutlineFill(box, r, g, b, 1)
	end
end

local function Hover(button)
	local hover = button:CreateTexture(nil, "HIGHLIGHT")
	ns.Own[hover] = true
	hover:SetAllPoints(button)
	hover:SetColorTexture(HOVER[1], HOVER[2], HOVER[3], HOVER[4])
end

-- A click, a drag or a drop on bank bag slot n: the game's pickup, which lifts the bag or puts the one on the cursor there.
local function Pickup(n)
	if not Bank.Live() or n > Bought() then
		return
	end
	if E.Fighting() then
		print("Flat UI: the bank's bag slots take no clicks in a fight.")
		return
	end
	E.Call(Container("PickupContainerItem"), BANK_BAGS, n)
end

-- The game's tooltip of the bag in slot n, out of combat; plain lines in a fight, for an empty slot, for one not bought, or when the game gives none
-- (it hides the tooltip then, Camelot/BankFrame.lua:334-337 and Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua:264-270, so the owner is
-- set again first).
local function SlotTip(button, n)
	local tip = GameTooltip
	if not Usable(tip) or ns.Forbidden(tip) then
		return
	end
	local bought = n <= Bought()
	local held = bought and Held(BANK_BAGS, n) or nil
	tip:SetOwner(button, "ANCHOR_RIGHT")
	if held and not E.Fighting() then
		local ok, shown = pcall(tip.SetBagItem, tip, BANK_BAGS, n)
		if ok and not ns.IsSecret(shown) and shown ~= false then
			tip:Show()
			return
		end
		tip:SetOwner(button, "ANCHOR_RIGHT")
	end
	if not bought then
		tip:SetText("Bank bag slot")
		tip:AddLine("Not bought yet. The Buy button beside these slots shows the price.", DIM[1], DIM[2], DIM[3], true)
	elseif held then
		tip:SetText(held.name or "Bank bag")
		tip:AddLine("In a bank bag slot.", DIM[1], DIM[2], DIM[3], true)
	else
		tip:SetText("Bank bag slot")
		tip:AddLine("Drop a bag here to add its slots to your bank.", DIM[1], DIM[2], DIM[3], true)
	end
	tip:Show()
end

local function MakeSlot(n)
	local button = CreateFrame("Button", nil, row.frame)
	ns.Own[button] = true
	button:SetSize(SLOT, SLOT)
	local slot = { button = button, box = ns.Outline(button, button) }
	slot.icon = button:CreateTexture(nil, "ARTWORK")
	ns.Own[slot.icon] = true
	slot.icon:SetAllPoints(button)
	slot.lock = button:CreateTexture(nil, "OVERLAY")
	ns.Own[slot.lock] = true
	slot.lock:SetAllPoints(button)
	pcall(slot.lock.SetAtlas, slot.lock, LOCK)
	Hover(button)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetScript("OnClick", function()
		Run(Pickup, n)
	end)
	button:SetScript("OnDragStart", function()
		Run(Pickup, n)
	end)
	button:SetScript("OnReceiveDrag", function()
		Run(Pickup, n)
	end)
	button:SetScript("OnEnter", function(self)
		Run(SlotTip, self, n)
	end)
	button:SetScript("OnLeave", function(self)
		Run(TipGone, self)
	end)
	button:SetScript("OnHide", function(self)
		Run(TipGone, self)
	end)
	row.slots[n] = slot
	return slot
end

local function DrawSlot(slot, n, bought, crop)
	local isBought = n <= bought
	local held = isBought and Held(BANK_BAGS, n) or nil
	slot.lock:SetShown(not isBought)
	if held and held.icon then
		slot.icon:SetTexture(held.icon)
		slot.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
		slot.icon:Show()
	else
		slot.icon:Hide()
	end
	slot.button:SetAlpha(isBought and 1 or 0.6)
	Paint(slot.box)
end

local function BuyTip(button)
	local tip = GameTooltip
	if not Usable(tip) or ns.Forbidden(tip) then
		return
	end
	tip:SetOwner(button, "ANCHOR_TOP")
	tip:SetText(Bought() == 0 and "Buy your bank's first slots" or "Buy a bank bag slot")
	local data = BankAsk("FetchNextPurchasableBankTabData")
	if Usable(data) then
		local cost = Field(data, "tabCost")
		if ns.Finite(cost) then
			tip:AddLine(cost > 0 and ("Costs %s"):format(E.Money(cost)) or "Free", 1, 1, 1)
		end
		if Field(data, "canAfford") == false then
			tip:AddLine("You do not have that much gold yet.", RED[1], RED[2], RED[3], true)
		end
	end
	tip:AddLine("The game asks before it buys.", DIM[1], DIM[2], DIM[3], true)
	tip:Show()
end

-- The Buy button, from the game's template for addons, made out of combat only: in a fight it waits for the end of it.
local function MakeBuy()
	if not row or row.buy or buyBroken then
		return
	end
	if E.InCombat() then
		if not buyQueued then
			buyQueued = true
			ns.OutOfCombat(function()
				buyQueued = false
				Run(function()
					MakeBuy()
					Update()
				end)
			end)
		end
		return
	end
	local ok, button = pcall(CreateFrame, "Button", nil, row.frame, TEMPLATE)
	if not ok or not Usable(button) then
		buyBroken = true
		return
	end
	ns.Own[button] = true
	if not pcall(button.SetAttribute, button, "overrideBankType", Character()) then
		buyBroken = true
		button:Hide()
		return
	end
	button:SetSize(BUY_WIDTH, BUY_HEIGHT)
	local box = ns.Outline(button, button, true)
	local label = ns.OwnText(button, "OVERLAY", "GameFontHighlightSmall")
	if label then
		label:SetPoint("CENTER", button, "CENTER", 0, 0)
		label:SetText("Buy")
	end
	Hover(button)
	button:SetScript("OnEnter", function(self)
		Run(BuyTip, self)
	end)
	button:SetScript("OnLeave", function(self)
		Run(TipGone, self)
	end)
	button:SetScript("OnHide", function(self)
		Run(TipGone, self)
	end)
	button:Hide()
	row.buy, row.buyBox = button, box
end

-- Lays the row out for the live bank, or hides it: the slots and the Buy button, or the first slots' prompt and the Buy button. Returns the width
-- and height it takes in its frame.
Update = function()
	if not row then
		return 0, 0
	end
	local frame = row.frame
	if not Bank.Live() then
		frame:Hide()
		return 0, 0
	end
	MakeBuy()
	local bought, x = Bought(), 0
	if bought == 0 then
		for _, slot in pairs(row.slots) do
			slot.button:Hide()
		end
		if row.text then
			row.text:Show()
			local ok, width = pcall(row.text.GetStringWidth, row.text)
			x = (ok and ns.Finite(width) and math.ceil(width) or 160) + GAP
		end
	else
		if row.text then
			row.text:Hide()
		end
		local most, crop = MostBags(), Crop()
		for n = FIRST_BAG, MOST_BAGS do
			local slot = row.slots[n]
			if n <= most then
				slot = slot or MakeSlot(n)
				slot.button:ClearAllPoints()
				slot.button:SetPoint("LEFT", frame, "LEFT", x, 0)
				DrawSlot(slot, n, bought, crop)
				slot.button:Show()
				x = x + SLOT + GAP
			elseif slot then
				slot.button:Hide()
			end
		end
	end
	local buy = row.buy
	if buy then
		if BankAsk("CanPurchaseBankTab") == true then
			buy:ClearAllPoints()
			buy:SetPoint("LEFT", frame, "LEFT", x, 0)
			Paint(row.buyBox)
			buy:Show()
			x = x + BUY_WIDTH + GAP
		else
			buy:Hide()
		end
	end
	local width = math.max(x - GAP, 1)
	frame:SetSize(width, SLOT)
	frame:Show()
	return width, SLOT
end

local function MakeRow(parent)
	local frame = CreateFrame("Frame", nil, parent)
	ns.Own[frame] = true
	frame:SetSize(1, SLOT)
	local text = ns.OwnText(frame, "OVERLAY", "GameFontHighlightSmall")
	if text then
		text:SetPoint("LEFT", frame, "LEFT", 0, 0)
		text:SetText(NO_SPACE)
	end
	row = { frame = frame, parent = parent, slots = {}, text = text }
end

-- The row of bank bag slots in a frame of Bags' own that the bank window gives (its bottom strip), left-aligned and centred on its height, made the
-- first time and moved when another frame is given. Returns the width and height it takes there: 0, 0 away from the live bank.
function Bank.Slots(frame)
	local width, height = 0, 0
	Run(function()
		if not Usable(frame) or ns.Forbidden(frame) then
			return
		end
		if not row then
			MakeRow(frame)
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

-- Deposit and Take out ------------------------------------------------------------------------------------------------------------------------

-- The containers a pass takes from, in the order of the window: the bags for a deposit, the bought tabs of the bank (B.Data.Containers) for Take out.
local function Sources(kind, me)
	if kind == "deposit" then
		return BAGS
	end
	local list = B.Data.Containers("bank", me)
	return type(list) == "table" and list or {}
end

-- The slots whose unlocked item matches the search (B.Search.Match of the record B.Data.Item gives for it), in the order of the window.
local function Queue(kind)
	local queue, me = {}, B.Me()
	local slotsOf = Container("GetContainerNumSlots")
	if type(me) ~= "string" or not slotsOf then
		return queue
	end
	for _, bag in ipairs(Sources(kind, me)) do
		if ns.Finite(bag) and bag >= 0 then
			local slots = E.Ask(slotsOf, bag)
			slots = ns.Finite(slots) and slots > 0 and slots <= MOST_SLOTS and slots or 0
			for slot = 1, slots do
				local held = Held(bag, slot)
				if held and held.link and not held.locked then
					local record = B.Data.Item(me, bag, slot)
					if Usable(record) and record.id == held.id and B.Search.Match(record) == true then
						queue[#queue + 1] = { bag = bag, slot = slot, id = held.id, link = held.link }
					end
				end
			end
		end
	end
	return queue
end

-- Why a click of Deposit or Take out cannot move anything now, or nil.
local function Refusal()
	if not Bank.Live() then
		return "the bank is not open"
	end
	if E.Fighting() then
		return "you are in a fight"
	end
	if CursorBusy() then
		return "the cursor holds something"
	end
	local blocker = Blocker()
	if blocker then
		return ("the %s is open"):format(blocker)
	end
	if B.Search.Active() ~= true then
		return "type a search first, and what matches it moves"
	end
	return nil
end

-- Why a running pass stops before its next move, or nil. A fight pauses it instead.
local function Stopper()
	if not Bank.Live() then
		return "the bank closed"
	end
	if CursorBusy() then
		return "the cursor held something"
	end
	local blocker = Blocker()
	if blocker then
		return ("the %s opened"):format(blocker)
	end
	return nil
end

local function Use(kind, move)
	local use = Container("UseContainerItem")
	if not use then
		return false
	end
	if kind == "deposit" then
		return E.Call(use, move.bag, move.slot, nil, Character(), false)
	end
	return E.Call(use, move.bag, move.slot)
end

-- WAIT seconds after a move: a slot that still holds the same stack did not move. One the game still holds locked has no answer yet and is looked at
-- again, LOOKS times at most.
local function Verify(run, move, count, looks)
	if pass ~= run then
		return
	end
	local held = Held(move.bag, move.slot)
	local same = held ~= nil and held.id == move.id and held.link == move.link and held.count == count
	if same and held.locked and looks < LOOKS then
		if After(WAIT, function()
			Run(Verify, run, move, count, looks + 1)
		end) then
			return
		end
	end
	run.checks = run.checks - 1
	if same then
		run.moved = math.max(0, run.moved - 1)
		Finish(WORDS[run.kind].room:format(move.link))
	elseif run.draining and run.checks <= 0 then
		Finish(nil)
	end
end

-- One move, when its slot still holds the same unlocked item. True when the game took the call.
local function Move(run, move)
	local held = Held(move.bag, move.slot)
	if not held or held.locked or held.id ~= move.id or held.link ~= move.link then
		return false
	end
	if not Use(run.kind, move) then
		return false
	end
	run.moved = run.moved + 1
	run.checks = run.checks + 1
	local count = held.count
	if not After(WAIT, function()
		Run(Verify, run, move, count, 1)
	end) then
		run.checks = run.checks - 1
	end
	return true
end

-- The last move is made: the pass ends once its slot has been looked at again.
local function Drain(run)
	run.draining = true
	if run.checks <= 0 then
		Finish(nil)
	end
end

-- A fight pauses the pass; it looks each POLL seconds for the end of it.
local function Pause(run)
	run.paused = true
	RequestFooter()
	if not After(POLL, function()
		Run(Resume, run)
	end) then
		Finish("a fight started")
	end
end

local function Step(run)
	if pass ~= run or run.paused or run.draining then
		return
	end
	local why = Stopper()
	if why then
		Finish(why)
		return
	end
	if E.Fighting() then
		Pause(run)
		return
	end
	local move = run.queue[run.next]
	if not move then
		Drain(run)
		return
	end
	run.next = run.next + 1
	Move(run, move)
	RequestFooter()
	if not After(SPACING, function()
		Run(Step, run)
	end) then
		Finish("the game gave no timer")
	end
end

-- The fight is over: the bags or the bank are read again, as a new pass would, and the pass goes on.
Resume = function(run)
	if pass ~= run or not run.paused then
		return
	end
	if E.Fighting() then
		if not After(POLL, function()
			Run(Resume, run)
		end) then
			Finish("a fight started")
		end
		return
	end
	-- A pass moves only what matches a search: with the search cleared meanwhile, every item would.
	if B.Search.Active() ~= true then
		Finish("the search was cleared")
		return
	end
	run.paused = false
	run.queue, run.next = Queue(run.kind), 1
	Step(run)
end

-- Ends the pass and says what moved: why it stopped when it did not end by itself (true: the player stopped it).
Finish = function(why)
	local run = pass
	pass = nil
	if not run then
		return
	end
	local words = WORDS[run.kind]
	if run.moved > 0 then
		local tail = ""
		if why == true then
			tail = ", then stopped"
		elseif why then
			tail = ", then stopped: " .. why
		end
		E.Say(("%s %d %s%s."):format(words.done, run.moved, Items(run.moved), tail))
	elseif why and why ~= true then
		E.Say(("%s: %s."):format(words.none, why))
	end
	RequestFooter()
end

-- A click of Deposit or Take out.
local function Start(kind)
	local run = pass
	if run and run.draining then
		Finish(nil)
		run = nil
	end
	if run and run.kind == kind and not PER_CLICK then
		Finish(true)
		return true
	end
	if run and run.kind ~= kind then
		Finish(true)
		run = nil
	end
	local why = Refusal()
	if why then
		print(("Flat UI: %s: %s."):format(WORDS[kind].none, why))
		return false, why
	end
	local queue = Queue(kind)
	if #queue == 0 then
		if run then
			Drain(run)
		else
			print(("Flat UI: %s: %s."):format(WORDS[kind].none, WORDS[kind].empty))
		end
		RequestFooter()
		return false, "nothing matches"
	end
	if PER_CLICK then
		run = run or { kind = kind, moved = 0, checks = 0 }
		pass = run
		run.left = #queue - 1
		Move(run, queue[1])
		if run.left <= 0 then
			Drain(run)
		end
		RequestFooter()
		return true
	end
	run = { kind = kind, queue = queue, next = 1, moved = 0, checks = 0 }
	pass = run
	Step(run)
	RequestFooter()
	return true
end

-- Deposit and Take out start a pass, or stop the one running (true, or false and why). Busy gives the kind of the pass under way ("deposit" or
-- "takeout"), how many matching items it has left, and true when each click moves the next one (PER_CLICK; else a click stops it), or nil.
function Bank.Deposit()
	local ok, why = false, nil
	Run(function()
		ok, why = Start("deposit")
	end)
	return ok, why
end

function Bank.TakeOut()
	local ok, why = false, nil
	Run(function()
		ok, why = Start("takeout")
	end)
	return ok, why
end

function Bank.Busy()
	local run = pass
	if not run or run.draining then
		return nil, 0, PER_CLICK
	end
	if PER_CLICK then
		return run.kind, run.left or 0, true
	end
	return run.kind, math.max(0, #run.queue - run.next + 1), false
end

-- The bank window and its key ----------------------------------------------------------------------------------------------------------------

-- Shows the bank of a character (key, nil for this one): the live bank at a banker, the records anywhere else. Hides the window when it shows that
-- character already. False while Bags is off.
function Bank.Toggle(key)
	if not On() then
		return false
	end
	local me = B.Me()
	if key == me then
		key = nil
	end
	local viewing = B.Viewing("bank")
	if viewing == me then
		viewing = nil
	end
	if E.Shown(B.Window.Get("bank")) and viewing == key then
		B.Window.Hide("bank")
		return true
	end
	B.SetViewing("bank", key)
	B.Window.Show("bank")
	Watch()
	return true
end

local function KeyPressed()
	if Bank.Toggle(nil) then
		return
	end
	if ns.Enabled(KEY) then
		print("Flat UI: Bags is not in use now, so the bank key does nothing. /flatui status says why.")
	else
		print("Flat UI: the bank key opens Flat UI's bank window. Turn on Flat UI bags on the Bags page of /flatui first.")
	end
end

do
	local ok, button = pcall(CreateFrame, "Button", BUTTON, UIParent)
	if ok and Usable(button) then
		ns.Own[button] = true
		pcall(button.RegisterForClicks, button, "LeftButtonUp")
		button:SetScript("OnClick", function()
			Run(KeyPressed)
		end)
	end
end

-- The events ---------------------------------------------------------------------------------------------------------------------------------

local function Banker(kind)
	if not ns.Finite(kind) then
		return false
	end
	for name, number in pairs(BANKERS) do
		if kind == EnumValue("PlayerInteractionType", name, number) then
			return true
		end
	end
	return false
end

-- The row and the Buy button follow the bank: drawn again, or hidden away from it.
local function Refresh()
	if row then
		Run(Update)
	end
end

local Closed

local function Opened()
	if open and not closing then
		return
	end
	if open then
		-- A visit whose close never came.
		Closed()
	end
	open, closing = true, false
	flat = Parked()
	Call("cache", B.Data, "BankScan")
	Call("follow", B, "BankOpened")
	if flat then
		Call("window", B, "SetViewing", "bank", nil)
		Call("window", B.Window, "Show", "bank")
		-- What ends the visit is followed outside the bank part, so a part that stopped cannot leave the game's bank open behind a hidden frame.
		pcall(Watch)
		Follow()
	end
	Refresh()
end

Closed = function()
	if not open then
		return
	end
	open, flat, closing = false, false, false
	if pass then
		Run(Finish, not PER_CLICK and "the bank closed" or nil)
		pass = nil
	end
	Call("cache", B.Data, "BankClosed")
	Call("follow", B, "BankClosed")
	Call("window", B, "Request", "layout", "bank")
	Refresh()
end

-- The tabs or the bank's bag slots changed. The bank window is laid out afresh only when the bought tabs or the bags in them changed
-- (B.Data.BankTabs says so): the items of the tabs come slot by slot at the next BAG_UPDATE_DELAYED (BagsData.lua), and nothing moves while the
-- window is open. When BagsData could not say (its part stopped), the window is laid out afresh as well.
local function Changed()
	if not open then
		return
	end
	local read, ran, moved = Usable(B.Data) and B.Data.BankTabs or nil, false, false
	local run = B.Part
	if type(read) == "function" and type(run) == "function" then
		run("cache", function()
			ran = true
			moved = read() == true
		end)
	end
	Refresh()
	if moved or not ran then
		Call("window", B, "Request", "layout", "bank")
	end
end

-- The player still deals with a banker: false only when the client plainly says no for each of the three kinds
-- (C_PlayerInteractionManager.IsInteractingWithNpcOfType, PlayerInteractionManagerDocumentation.lua:49-62, as BagsData.lua asks it), true on a
-- client without the call.
local function AtBanker()
	local api = C_PlayerInteractionManager
	local ask = Usable(api) and api.IsInteractingWithNpcOfType or nil
	if type(ask) ~= "function" then
		return true
	end
	for name, number in pairs(BANKERS) do
		local ok, yes = pcall(ask, EnumValue("PlayerInteractionType", name, number))
		if not ok or ns.IsSecret(yes) or yes ~= false then
			return true
		end
	end
	return false
end

-- The page comes up again (Bags.lua): the module heard none of the bank's events while the page was off. During a visit BankFrame has its shown
-- flag set, hidden by Bags or not (BankFrame_Open shows it and asks the game to end the visit when it does not show,
-- Mainline/BankFrameTemplates.lua:111-124), and the game hides it when the visit ends (PlayerInteractionFrameManager.lua:139-163). So a visit
-- whose close the module did not hear ends now, and one that began meanwhile starts now, while BankFrame shows and the player still deals with a
-- banker: Bags does not hide a BankFrame that shows (Parked is false), so the game's bank window stays that visit's live bank, B.Data.BankScan
-- reads the bank, nothing that comes out of it becomes new (Bank.Visiting), and BANKFRAME_CLOSED ends the visit as usual.
function Bank.Settle()
	local shown = E.Shown(_G.BankFrame)
	if open and not shown then
		Closed()
	elseif not open and shown and AtBanker() then
		Opened()
	end
end

ns.AddEvent(KEY, "BANKFRAME_OPENED", function()
	Opened()
end)
ns.AddEvent(KEY, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(kind)
	if Banker(kind) then
		Opened()
	end
end)
ns.AddEvent(KEY, "BANKFRAME_CLOSED", function()
	Closed()
end)
ns.AddEvent(KEY, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(kind)
	if Banker(kind) then
		Closed()
	end
end)
ns.AddEvent(KEY, "PLAYERBANKSLOTS_CHANGED", function()
	Changed()
end)
-- Only the character bank: the account bank is never read (design 10.1).
ns.AddEvent(KEY, "BANK_TABS_CHANGED", function(kind)
	if not ns.Finite(kind) or kind == Character() then
		Changed()
	end
end)

ns.AddStatus(KEY, function()
	local lines = {}
	local run = pass
	if run and run.paused then
		lines[#lines + 1] = ("Bags: %s waits for the end of the fight."):format(WORDS[run.kind].label)
	end
	if buyBroken then
		lines[#lines + 1] = "Bags: the game did not make the bank's Buy button. With At the banker set to the game's bank window, its own button buys."
	end
	if PER_CLICK then
		lines[#lines + 1] = "Bags: Deposit and Take out move one item for each click."
	end
	return lines
end)
