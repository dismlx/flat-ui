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
-- Flat UI's shows the records. Either stays so for the whole visit (Bank.Live, the one test of the live bank): At the banker changed meanwhile
-- counts from the next visit, since Bags never moves a BankFrame that shows. The state is set first and the other files of Bags are called after
-- it, each step as the part of Bags that does it (B.Part), so a step that fails stops its own part and the steps after it still run. The work of
-- each event, in order (design 2.8):
-- - BANKFRAME_OPENED and the interaction's show: the live state; B.Data.BankScan, the records of the bank; B.BankOpened, the bank hold of Bags.lua;
--   then, for Flat UI's live bank, this character in the bank window (B.SetViewing) and B.Window.Show("bank").
-- - BANKFRAME_CLOSED and the interaction's hide: the live state off, and a pass of Deposit or Take out ends; after a visit with Flat UI's bank
--   window, the game's question of the Buy button (CONFIRM_BUY_BANK_TAB) is hidden while it is the one popup shown (Errands.HideAlone,
--   Errands.lua:307-318), as the game's bank panel hides it when it hides (BankFrameTemplates.lua:709-717 and 745-752), which a hidden BankFrame
--   never does; B.Data.BankClosed; B.BankClosed, which drops the bank hold and closes the bag window when nothing else holds it;
--   B.Request("layout", "bank"): the live window turns into the records.
-- - PLAYERBANKSLOTS_CHANGED, and BANK_TABS_CHANGED of the character bank (BankDocumentation.lua:382 and 414), during a visit: B.Data.BankTabs; the
--   row of bank bag slots and the Buy button; B.Request("layout", "bank") when the bought tabs or the bags in them changed, since the items in the
--   tabs reach the window slot by slot and nothing moves while it is open. A tab whose slots the client gives only after that layout, as it may
--   for a tab just bought, has BagsData.lua lay the window out again at BAG_UPDATE_DELAYED.
-- These events reach the module only while it is on, so when the page comes up again Bank.Settle ends a visit that ended meanwhile, one whose
-- BankFrame is no longer shown (the game shows it, hidden by Bags or not, for as long as a visit lasts), with B.Data.BankClosed told that the close
-- was not heard, so the snapshot keeps the date of its last write; and it starts one that began meanwhile, whose BankFrame shows while the client
-- does not say the player deals with no banker (C_PlayerInteractionManager.IsInteractingWithNpcOfType with Banker, CharacterBanker and
-- AccountBanker). Bags does not hide a BankFrame that shows, so the game's bank window is the live bank of that visit.
--
-- Ending a visit. The game ends the bank in BankFrame's OnHide (BankFrameTemplates.lua:104-109), which a frame under a hidden parent never runs. So
-- Flat UI calls C_Bank.CloseBankFrame (BankDocumentation.lua:121; apis.yaml:3353) once a visit, while its bank window is the live one:
-- - when that window hides: its close button, the bank key, or Escape, which hides the windows of UISpecialFrames through a securecall
--   (Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua:1106-1116 and 1168). Its OnHide is followed with HookScript, on a frame of Flat
--   UI's own; a window hidden with its parent, as when a movie or another addon hides the interface, keeps its shown flag (IsShown) and ends
--   nothing then. A window hidden while the player could not see it hears no OnHide, so BagsWindow's Window.Hide and Bags.lua, which hid it, call
--   Bank.Hidden, which ends the visit the same way, and so does BagsWindow's Missed when the interface shows again and finds the window closed
--   meanwhile with no OnHide heard. The game closes every window when the interface comes back (UIParent's OnShow runs CloseAllWindows,
--   Blizzard_UIParent/UIParent.lua:5-7 and Blizzard_Game/Shared/Game.lua:91-93), and at death, at a loss of control and on entering the world
--   also while it stays hidden; Escape while the interface is hidden only brings it back (Game.lua:29-37).
-- - when the game hides BankFrame with HideUIPanel, which is followed with ns.FollowGlobal the first time a visit starts live: Escape and the
--   game's other closes of every window (UIParentPanelManager.lua:1130-1132 and 1175-1177), walking away (PlayerInteractionFrameManager.lua:139-163),
--   or another panel taking its place. Only the first argument is read, compared with rawequal, and only a BankFrame whose shown flag is false
--   after the call counts: the game refuses a hide asked by an addon in a fight (UIParentPanelManager.lua:853-861 and 905-922).
-- The visit stops being live at once, and the bank hold of Bags.lua goes with it (B.Hold), as the game's OnHide closes the bags its bank window
-- opened (CloseAllBags(self)). The call comes at once, unless a move of Deposit or Take out sent less than WAIT seconds before has no answer yet:
-- its slot still holds that item locked, a lock of the server's, since a pass moves only unlocked items with the cursor empty and a locked item
-- cannot be picked up. Then the slots are looked at again once a frame (C_Timer.After), WAIT seconds after the move at most, and the call comes on
-- the frame after the answer, so BagsData.lua reads it while it still reads the bank's tabs; the game's bank stays open meanwhile, and a
-- right-click in a bag window would still deposit. Just before the call the game's BankFrame, still shown under Bags' hidden frame, is hidden
-- (Hide, which runs no script there): the call ends the interaction, whose hide the game handles inside the call (a synchronous event,
-- PlayerInteractionManagerDocumentation.lua:103-104) with HideUIPanel(BankFrame) under Flat UI's code, which the game refuses in a fight; hidden
-- first, the frame stops it at its shown check (UIParentPanelManager.lua:916-918). The game then sends BANKFRAME_CLOSED, and the visit ends as above.
--
-- The row of bank bag slots (Bank.Slots, in a frame of Bags' own that the bank window gives it). Tab 1 is the bank's own slots; tabs 2 to 9 are the
-- bags put in the bank bag slots, the item at Enum.BagIndex.Characterbanktab (-2), slot n (Blizzard_UIPanels_Game/Camelot/BankFrame.lua:136-191 and
-- 301-327; enums.yaml:561), and a slot is bought when n is no more than C_Bank.FetchNumPurchasedBankTabs (the game lights slot n when the n-th entry
-- of its list of bought tabs exists, BankFrame.lua:172-183). The row shows slots 2 to C_Bank.FetchMaxNumBankTabs, at most nine
-- (Constants.InventoryConstants.NumCharacterBankSlots), as buttons of Flat UI's own: the bag's icon from C_Container.GetContainerItemInfo(-2, n), the
-- game's lock (the atlas bankslot-icon-lock, Camelot/BankFrame.xml:11) on a slot not bought, and on a bought slot with no bag the game's art of an
-- empty bag slot, faded, as the bag window's row draws one (BagsSlots.lua). A bag shows its free slots in its corner, in the game's font of item
-- counts with an outline, white, gold at LOW (4) or fewer and red when it is full, the colours of the footer's free slots. A drag or a drop, or a
-- click with an item on the cursor (CursorHasItem), calls C_Container.PickupContainerItem(-2, n), as the game's own bag slot does
-- (BankFrame.lua:378-395), out of combat. A plain click on a bought slot that holds a bag keeps that bag lit in the bank window (B.Layout.Stick with
-- its container, as the bag window's row does with its bags; B.Layout.Closed lets it go when the window closes), its edge in the Highlight colour
-- (SetOutlineColour), and a click on it again gives every bag back; that touches frames of Flat UI's own only, so it works in a fight too. The
-- tooltip is the game's for the bag (GameTooltip:SetOwner, SetBagItem, Show) out of combat, as the game's slot shows it (BankFrame.lua:329-342), and
-- plain lines (SetText, AddLine) in a fight or for an empty or unbought slot, with the bag's free and total slots
-- (C_Container.GetContainerNumFreeSlots and GetContainerNumSlots of its container, tab TAB_OF_SLOT + n) and what the clicks do, drawn again after a
-- click while the slot owns it. It
-- opens beside the bank window (B.Window.Get; SetOwner with ANCHOR_NONE, ClearAllPoints and SetPoint), right of it while the window's middle is left
-- of the screen's and left of it otherwise, its bottom at the window's, so it never covers the items the slot lights; it is hidden (Hide) when the
-- cursor leaves the button that owns it (IsOwned). While the mouse points at a bought slot that holds a bag, the bank window dims every slot that is
-- not in that bag (B.Layout.Light, BagsLayout.lua), as the bag slots of the bag window do with its bags, and leaving the slot gives the window back.
-- The first slots and the Buy button. The game's bank window buys the first tab itself whenever it selects a tab while that tab costs nothing
-- (BankFrame.lua:197-206 and 232-236), which never runs while BankFrame is hidden. So while no tab is bought the row says "Your bank has no space
-- yet." beside a Buy button, and later the button stays beside the slots while C_Bank.CanPurchaseBankTab says more can be bought (apis.yaml:3321).
-- The button is a frame of Flat UI's own from the game's template for addons, BankPanelPurchaseButtonScriptTemplate, given the attribute
-- overrideBankType (Enum.BankType.Character) out of combat (Mainline/BankFrameTemplates.xml:513-521); its click is the game's own, which shows the
-- game's question CONFIRM_BUY_BANK_TAB (BankFrameTemplates.lua:1324-1340), whose Yes buys (Camelot/BankFrame.lua:1-22). Flat UI sets only its size,
-- place, look and its OnEnter and OnLeave, never its OnClick. Its tooltip gives the price and whether it can be paid, from
-- C_Bank.FetchNextPurchasableBankTabData (BankDocumentation.lua:211 and 454; apis.yaml:3406). Asked in a fight (InCombatLockdown, through
-- Errands.InCombat), it is made at the end of it (ns.OutOfCombat), and the bank window is then asked to measure its strip again with its footer
-- (B.Request("footer", "bank")), since the row grew by the button. The question has no timeout, so the end of the visit takes it down (above).
--
-- Deposit and Take out (design 6) move every item that matches the search, one at a time: a deposit takes from the bags 0 to 5 (never the keyring)
-- with C_Container.UseContainerItem(bag, slot, nil, Enum.BankType.Character, false), as the game's own right-click at a banker does
-- (Mainline/ContainerFrame.lua:1611), and Take out takes from the bought tabs of the bank with C_Container.UseContainerItem(tab, slot) and no bank
-- type, as the game's bank buttons do (BankFrameTemplates.lua:445-456; ContainerDocumentation.lua:584). A pass reads each slot of those containers
-- (C_Container.GetContainerNumSlots and GetContainerItemInfo, ContainerDocumentation.lua:192, 313 and 766) and takes the unlocked items whose record
-- (B.Data.Item) the search matches (B.Search.Match). The first move is made inside the click, the next ones SPACING seconds apart on the game's timer
-- (C_Timer.After), the spacing of Errands' selling (ErrandsMerchant.lua:56-57). Before each move: the bank still live; no fight (Errands.Fighting,
-- Errands.lua:321-323: InCombatLockdown or UnitAffectingCombat), else the pass waits and looks again each second; the cursor empty (GetCursorInfo,
-- CursorHasItem); no spell waiting for its target (SpellIsTargeting, SpellCanTargetItem and SpellCanTargetItemID, in the client's apis.yaml), since
-- the same call would hand the spell the item, as the game's own bag slot does (Mainline/ContainerFrame.lua:1508-1510 and 3378-3382); none of
-- MerchantFrame, TradeFrame, MailFrame, AuctionHouseFrame or GuildBankFrame shown (Errands.Shown, Errands.lua:265-271, the widget call IsShown),
-- since the same call would sell, trade, mail or post; and the slot still holding the same unlocked item. A slot still unchanged WAIT seconds after
-- its move stops the pass with "the bank has no room" or "your bags have no room"; one the game still holds locked is looked at again. After a fight
-- the pass reads the bags or the bank again, and stops if the search was cleared meanwhile, since every item would match then. A second click on
-- the same button stops a running pass. A section's right-click menu (BagsOrder.lua), at the live bank, starts the same pass with a filter in
-- place of the search, the section's items (B.Categories.Of): Put Trade goods in the bank in the bag window, Take Trade goods out in the bank
-- window; it needs no search, keeps its filter after a fight, and ends a pass that runs before it starts. The end is said through Errands.Say
-- (Errands.lua:86-91): "Deposited 12 items." In a fight, or with the
-- cursor full, a spell waiting for its target, a window above open or no search typed, a click moves nothing and says why (print). With PER_CLICK
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
-- either bank window: nothing becomes new then, and the tip of the bag window's bank button says which window is live), Bank.Settle (Bags.lua, when
-- the page comes up, once the bag slots are made, since a visit it starts may open the bag window), Bank.Hidden (BagsWindow's Window.Hide and
-- Missed, and Bags.lua, for the bank window hidden while the player could not see it),
-- Bank.Toggle (the slash word bank and the key), Bank.Deposit, Bank.TakeOut and Bank.Busy (the buttons of the bank window, and with a filter the
-- menu of a section's title, BagsOrder.lua), Bank.Slots (the row in
-- the strip of the bank window, which takes the height Slots returns and hides when it is 0).
--
-- Every game call runs inside pcall (each piece of work runs in B.Part, which is one), every game answer goes through ns.IsSecret or ns.Finite before
-- it is compared, counted, joined or used as a key, and no field of the game's frames is written nor any of their Lua methods called: BankFrame is
-- read (IsShown), compared, and hidden with the widget call Hide only while it is still shown under Bags' hidden frame, just before the call that
-- ends the bank (CloseBank), and the buy question is taken down by the game's own StaticPopup_Hide (through Errands.HideAlone).

local B = ns.Bags
if type(B) ~= "table" or type(B.Bank) ~= "table" then
	return
end
local Bank = B.Bank
local E = ns.Errands

local KEY = "bags"
local PART = "bank"
-- Enum.BankType.Character and Enum.BagIndex.Characterbanktab, for a client whose enumerations do not say (enums.yaml:561 and 608-612), and what
-- bank bag slot n adds to make the container of its bag (tab TAB_OF_SLOT + n, BagsData.lua).
local CHARACTER, BANK_BAGS, TAB_OF_SLOT = 0, -2, 5
-- The interactions the game opens its bank window for (BankFrameTemplates.lua:126-138), and their numbers when the client does not say.
local BANKERS = { Banker = 8, CharacterBanker = 67, AccountBanker = 68 }
-- The bank bag slots after the bank's own, from 2 to at most 9 (Constants.InventoryConstants.NumCharacterBankSlots and MAX_TRANSACTION_BANK_TABS,
-- globals.yaml:204 and 207).
local FIRST_BAG, MOST_BAGS = 2, 9
-- The bags a deposit takes from: the backpack, the four bags and the reagent bag (Enum.BagIndex 0 to 5). The keyring keeps its keys.
local BAGS = { 0, 1, 2, 3, 4, 5 }
-- More slots than a container ever has; a larger answer is no answer.
local MOST_SLOTS = 200
-- Seconds between two moves; seconds after a move before its slot is looked at again (and the longest the end of a visit waits for its answer),
-- and how many looks a slot the game holds locked gets; seconds between two looks at the end of a fight.
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
		empty = "no item in your bags matches the search", emptyOf = "no item of that section is in your bags" },
	takeout = { label = "Take out", done = "Took out", none = "Took nothing out", room = "your bags have no room for %s",
		empty = "no item in your bank matches the search", emptyOf = "no item of that section is in your bank" },
}
-- The row: the size of a bag slot and the space between two, the size of the Buy button, and its template.
local SLOT, GAP = 28, 4
local BUY_WIDTH, BUY_HEIGHT = 56, 22
local TEMPLATE = "BankPanelPurchaseButtonScriptTemplate"
-- The game's question its click shows (Camelot/BankFrame.lua:1).
local BUY_POPUP = "CONFIRM_BUY_BANK_TAB"
local LOCK = "bankslot-icon-lock"
-- The game's art of an empty bag slot, faded on a bought bank bag slot that holds no bag, as on the bag window's row (BagsSlots.lua).
local EMPTY_ART = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
local NO_SPACE = "Your bank has no space yet."
-- The tint under the cursor, as on the slots of the windows (Windows.lua:59), and the colour of the plain lines of a tooltip.
local HOVER = { 1, 1, 1, 0.3 }
local DIM = { 0.8, 0.8, 0.8 }
local RED = { 1, 0.35, 0.24 }
-- The free count in a bank bag's corner, as on the bag window's row (BagsSlots.lua): the game's font of item counts at a size of its own with an
-- outline, white, gold at LOW free slots or fewer and red when the bag is full, the colours of the footer's free slots (BagsWindow.lua).
local COUNT_FONT, COUNT_SIZE = "NumberFontNormal", 11
local ROOM, SHORT, LOW = { 1, 1, 1 }, { 1, 0.82, 0 }, 4
-- The crop of an icon when the Windows page does not say; how far beside the bank window a slot's tooltip opens.
local CROP, TIP_GAP = 8, 4

local BUTTON = "FlatUIBankButton"
local BINDING = "CLICK " .. BUTTON .. ":LeftButton"

-- The name of the binding in the game's Key Bindings, under Flat UI.
_G["BINDING_NAME_" .. BINDING] = "Flat UI bank"

-- open: a visit to a banker is under way; flat: Flat UI's bank window is its live bank; closing: Flat UI asked to end it (C_Bank.CloseBankFrame,
-- maybe after a wait). closeWait: the token of the close that waits; sent: the moves of Deposit and Take out of the last WAIT seconds, oldest
-- first, { bag, slot, id, link, at } with at from GetTime, whose answers that close waits for.
local open, flat, closing = false, false, false
local closeWait
local sent = {}
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

-- The client's clock (GetTime), or nil when it does not say.
local function Clock()
	local now = E.Ask(GetTime)
	return ns.Finite(now) and now or nil
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

-- A spell waits for its target, which the cursor does not say: the same call that moves an item would hand it to the spell, as the game's own bag
-- slot does (Mainline/ContainerFrame.lua:1508-1510 and 3378-3382). Only a plain true counts.
local function Targeting()
	return E.Ask(SpellIsTargeting) == true or E.Ask(SpellCanTargetItem) == true or E.Ask(SpellCanTargetItemID) == true
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

-- True while Flat UI's bank window is the live bank: at a banker, with BankFrame kept hidden as the visit started, the visit not ending and Bags on.
-- The one test of the live bank: At the banker changed during a visit counts from the next one.
function Bank.Live()
	return open and flat and not closing and On()
end

-- True while a visit to a banker is under way, with Flat UI's bank window or the game's, until the game says it ended: what comes out of the
-- bank then is not loot (New items, BagsCategories.lua).
function Bank.Visiting()
	return open == true
end

-- Keeps a move of Deposit or Take out that the game took, for the close that waits (EndVisit), and forgets the moves sent WAIT seconds or more
-- before it. Without the client's clock nothing is kept, and the close never waits.
local function Sent(move)
	local now = Clock()
	local kept = {}
	if now then
		for _, entry in ipairs(sent) do
			if now - entry.at < WAIT then
				kept[#kept + 1] = entry
			end
		end
		kept[#kept + 1] = { bag = move.bag, slot = move.slot, id = move.id, link = move.link, at = now }
	end
	sent = kept
end

-- True while a move sent less than WAIT seconds ago has no answer yet: its slot still holds that item, locked. That lock is the server's: a pass
-- moves only an unlocked item with the cursor empty, and a locked item cannot be picked up. A move that failed unlocks its slot, and an item the
-- player picks up after that looks locked again, so the wait never runs past WAIT seconds after the move.
local function Unanswered()
	local now = Clock()
	if not now then
		return false
	end
	for _, entry in ipairs(sent) do
		if now - entry.at < WAIT then
			local held = Held(entry.bag, entry.slot)
			if held and held.locked and held.id == entry.id and held.link == entry.link then
				return true
			end
		end
	end
	return false
end

-- C_Bank.CloseBankFrame for the close that waits, while it is still the one that waits and the visit it was asked for goes on. The game's
-- BankFrame, still shown under Bags' hidden frame, is hidden first (Hide, which runs no script there). The call ends the bank's interaction, and
-- the game hides BankFrame for that inside the call (PLAYER_INTERACTION_MANAGER_FRAME_HIDE is a synchronous event,
-- PlayerInteractionManagerDocumentation.lua:103-104), with HideUIPanel (PlayerInteractionFrameManager.lua:139-163) run under Flat UI's code,
-- which the game refuses in a fight (UIParentPanelManager.lua:853-861 and 905-922): the frame would stay shown, holding its place among the
-- game's panels. Hidden first, it stops that HideUIPanel at its shown check (:916-918), before the test of a fight, and the game frees the place
-- itself at its next ShowUIPanel or Escape (:156-183 and 191-195, 1130-1132). A BankFrame that is not under the hidden frame is never hidden
-- here: its OnHide would run in Flat UI's taint.
local function CloseBank(token)
	if closeWait ~= token or not open or not closing then
		return
	end
	closeWait = nil
	local api = C_Bank
	if Usable(api) and type(api.CloseBankFrame) == "function" then
		local bank = _G.BankFrame
		if Parked() and E.Shown(bank) then
			pcall(bank.Hide, bank)
		end
		pcall(api.CloseBankFrame)
	end
end

-- The close that waits looks at the slots of the moves just sent once a frame (C_Timer.After), and asks for the close on the frame after the last
-- answer came, so the BAG_UPDATE_DELAYED that carried it has been read while BagsData.lua still reads the bank's tabs. Plain code, checked
-- against its token as CloseBank is.
local function Await(token)
	if closeWait ~= token or not open or not closing then
		return
	end
	if Unanswered() and After(0, function()
		Await(token)
	end) then
		return
	end
	if not After(0, function()
		CloseBank(token)
	end) then
		CloseBank(token)
	end
end

-- Asks the game to end the visit, once, as BankFrame's OnHide would. Plain code with no part around it, so a part that stopped cannot leave the
-- game's bank open behind a hidden frame. The visit stops being live at once (closing), and the bank hold of Bags.lua goes (B.Hold, outside the parts
-- too), as the game's OnHide closes the bags its bank window opened (CloseAllBags(self), BankFrameTemplates.lua:104-109): the bag window closes then
-- when nothing else keeps it open. The call comes at once, unless a move of Deposit or Take out sent less than WAIT seconds before has no answer yet
-- (Unanswered); then it waits for that answer (Await), so the move is read while BagsData.lua still reads the bank's tabs. While it waits the game's
-- bank is still open, and a right-click in a bag window still deposits, so it waits no longer than the answer takes. A move answered after the close
-- is left to the grace of BagsData.lua.
local function EndVisit()
	if not open or not flat or closing then
		return
	end
	closing = true
	local token = {}
	closeWait = token
	local hold = B.Hold
	if type(hold) == "function" then
		pcall(hold, "bank", false)
	end
	if Unanswered() and After(0, function()
		Await(token)
	end) then
		return
	end
	CloseBank(token)
end

-- The bank window hid. A window hidden with its parent keeps its shown flag and ends nothing then: the game closes it when the interface comes back.
local function WindowHidden(window)
	if open and flat and not closing and not E.Shown(window) then
		EndVisit()
	end
end

-- The bank window hid while the player could not see it (the interface hidden), so it heard no OnHide: BagsWindow's Window.Hide, and Bags.lua when
-- it hides the window itself, call this then, and BagsWindow's Missed when the interface shows again and finds the window closed meanwhile with no
-- OnHide heard. It ends the visit as WindowHidden does, without asking the window's shown flag, and as plain code with no part around it.
function Bank.Hidden()
	if open and flat and not closing then
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

-- A drag or a drop on bank bag slot n, or a click with an item on the cursor: the game's pickup, which lifts the bag or puts the one on the cursor
-- there.
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

-- The free and total slots of the bag in bank bag slot n, or nil when the client does not say.
local function Room(n)
	local free = E.Ask(Container("GetContainerNumFreeSlots"), n + TAB_OF_SLOT)
	local total = E.Ask(Container("GetContainerNumSlots"), n + TAB_OF_SLOT)
	if ns.Finite(free) and ns.Finite(total) and total > 0 then
		return math.max(0, math.floor(free)), math.floor(total)
	end
	return nil, nil
end

-- The free and total slots of the bag in bank bag slot n, as a line of its tooltip, or nil when the client does not say.
local function RoomLine(n)
	local free, total = Room(n)
	if free then
		return ("%d of %d slots free"):format(free, total)
	end
	return nil
end

-- The bank bag slot whose bag a click keeps lit in the bank window (B.Layout.Stuck, its container less TAB_OF_SLOT), or nil.
local function Stuck()
	local layout = B.Layout
	local stuck = Usable(layout) and layout.Stuck or nil
	if type(stuck) ~= "function" then
		return nil
	end
	local ok, c = pcall(stuck, "bank")
	return ok and ns.Finite(c) and (c - TAB_OF_SLOT) or nil
end

-- The edge of a slot: in the Highlight colour while a click keeps its bag lit, else the outline's own.
local function Edge(slot, n)
	if Stuck() == n then
		local r, g, b = ns.Colour("windows.accent")
		ns.SetOutlineColour(slot.box, r, g, b)
	else
		ns.SetOutlineColour(slot.box, nil, nil, nil)
	end
end

-- A click on bank bag slot n: with an item on the cursor the game's pickup puts it there; else, on a bought slot that holds a bag, that bag stays
-- lit in the bank window (B.Layout.Stick with its container), or, on the one lit already, every bag comes back, as the bag window's row does with
-- its bags (BagsSlots.lua). That touches frames of Flat UI's own only, so it works in a fight too.
local function Click(n)
	if E.Ask(CursorHasItem) == true then
		Pickup(n)
		return
	end
	local layout = B.Layout
	if not (Bank.Live() and n <= Bought() and Held(BANK_BAGS, n)) or not Usable(layout) or type(layout.Stick) ~= "function" then
		return
	end
	B.Part("layout", layout.Stick, "bank", Stuck() ~= n and (n + TAB_OF_SLOT) or nil)
	for other, slot in pairs(row and row.slots or {}) do
		Edge(slot, other)
	end
end

-- The centre of a frame across the screen, in screen units, or nil.
local function Middle(frame)
	local ok, left, right, scale = pcall(function()
		return frame:GetLeft(), frame:GetRight(), frame:GetEffectiveScale()
	end)
	if ok and ns.Finite(left) and ns.Finite(right) and ns.Finite(scale) and scale > 0 then
		return (left + right) / 2 * scale
	end
	return nil
end

-- The tooltip of a slot opens beside the bank window (B.Window.Get, a frame of Flat UI's own), on the side of the screen with room: right of a
-- window left of the screen's middle, else left of it, its bottom at the window's, so the window and the bag the slot lights stay in view. Right of
-- the slot when the window does not say where it is.
local function Anchor(tip, button)
	local window
	local get = Usable(B.Window) and B.Window.Get or nil
	if type(get) == "function" then
		local ok, frame = pcall(get, "bank")
		window = ok and Usable(frame) and frame or nil
	end
	local at, screen = window and Middle(window), Middle(UIParent)
	if not (at and screen) then
		tip:SetOwner(button, "ANCHOR_RIGHT")
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

-- What the clicks on a bought slot that holds a bag do, after its tooltip's lines.
local function ClickLines(tip, n)
	local click = Stuck() == n and "Click again to show every bag" or "Click to show only this bag"
	tip:AddLine(click .. "; drag it to pick it up, or drop another bag on it to swap.", DIM[1], DIM[2], DIM[3], true)
end

-- The game's tooltip of the bag in slot n, out of combat; plain lines in a fight, for an empty slot, for one not bought, or when the game gives none
-- (it hides the tooltip then, Camelot/BankFrame.lua:334-337 and Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua:264-270, so the owner is
-- set again first). A bag adds its free and total slots and what the clicks do, as the bag slots of the bag window say them (BagsSlots.lua). It
-- opens beside the bank window (Anchor).
local function SlotTip(button, n)
	local tip = GameTooltip
	if not Usable(tip) or ns.Forbidden(tip) then
		return
	end
	local bought = n <= Bought()
	local held = bought and Held(BANK_BAGS, n) or nil
	local room = held and RoomLine(n) or nil
	Anchor(tip, button)
	if held and not E.Fighting() then
		local ok, shown = pcall(tip.SetBagItem, tip, BANK_BAGS, n)
		if ok and not ns.IsSecret(shown) and shown ~= false then
			if room then
				tip:AddLine(room, 1, 1, 1)
			end
			ClickLines(tip, n)
			tip:Show()
			return
		end
		Anchor(tip, button)
	end
	if not bought then
		tip:SetText("Bank bag slot")
		tip:AddLine("Not bought yet. The Buy button beside these slots shows the price.", DIM[1], DIM[2], DIM[3], true)
	elseif held then
		tip:SetText(held.name or "Bank bag")
		if room then
			tip:AddLine(room, 1, 1, 1)
		end
		tip:AddLine("In a bank bag slot.", DIM[1], DIM[2], DIM[3], true)
		ClickLines(tip, n)
	else
		tip:SetText("Bank bag slot")
		tip:AddLine("Drop a bag here, or click with one on your cursor, to add its slots to your bank.", DIM[1], DIM[2], DIM[3], true)
	end
	tip:Show()
end

-- The tooltip again after a click, which may have changed what it says, while this slot still owns it.
local function Retip(button, n)
	local tip = GameTooltip
	if not Usable(tip) or ns.Forbidden(tip) then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, button)
	if ok and not ns.IsSecret(owned) and owned == true then
		SlotTip(button, n)
	end
end

-- The bank window lights the items of the bag in bank bag slot n (B.Layout.Light, BagsLayout.lua), or gives itself back with nil; a slot with no
-- bag lights nothing there.
local function Light(n)
	local layout = B.Layout
	if Usable(layout) and type(layout.Light) == "function" then
		B.Part("layout", layout.Light, "bank", n and (n + TAB_OF_SLOT) or nil)
	end
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
	button:SetScript("OnClick", function(self)
		Run(Click, n)
		Run(Retip, self, n)
	end)
	button:SetScript("OnDragStart", function()
		Run(Pickup, n)
	end)
	button:SetScript("OnReceiveDrag", function()
		Run(Pickup, n)
	end)
	button:SetScript("OnEnter", function(self)
		Run(SlotTip, self, n)
		if n <= Bought() then
			Light(n)
		end
	end)
	button:SetScript("OnLeave", function(self)
		Run(TipGone, self)
		Light(nil)
	end)
	button:SetScript("OnHide", function(self)
		Run(TipGone, self)
		Light(nil)
	end)
	row.slots[n] = slot
	return slot
end

-- Draws bank bag slot n: the bag's icon, cropped, with its free slots in the corner (white, gold at LOW or fewer, red when full); a bought slot
-- with no bag the game's art of an empty bag slot, faded; one not bought the game's lock. Its edge is in the Highlight colour while a click keeps
-- its bag lit.
local function DrawSlot(slot, n, bought, crop)
	local isBought = n <= bought
	local held = isBought and Held(BANK_BAGS, n) or nil
	slot.lock:SetShown(not isBought)
	if held and held.icon then
		slot.icon:SetTexture(held.icon)
		slot.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
		slot.icon:SetAlpha(1)
		slot.icon:Show()
	elseif isBought and not held then
		slot.icon:SetTexture(EMPTY_ART)
		slot.icon:SetTexCoord(0, 1, 0, 1)
		slot.icon:SetAlpha(0.5)
		slot.icon:Show()
	else
		slot.icon:Hide()
	end
	local free = held and Room(n) or nil
	if slot.count and free then
		local colour = free == 0 and RED or free <= LOW and SHORT or ROOM
		slot.count:SetTextColor(colour[1], colour[2], colour[3], 1)
		slot.count:SetText(tostring(free))
		slot.count:Show()
	elseif slot.count then
		slot.count:Hide()
	end
	slot.button:SetAlpha(isBought and 1 or 0.6)
	Paint(slot.box)
	Edge(slot, n)
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

-- The Buy button, from the game's template for addons, made out of combat only: in a fight it waits for the end of it. Made then, it widens the row
-- after the bank window measured it, so the window is asked for its footer, with which it measures its strip again (BagsWindow.lua); a new layout
-- would move the items that came into the bank in the fight while the window is open.
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
					if row and row.buy then
						RequestFooter()
					end
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

-- Whether a pass takes the item of a record: filter's answer (a section's menu, BagsOrder.lua) when the pass has one, else the search's
-- (B.Search.Match). Only a plain true counts, and a filter that raises takes nothing.
local function Takes(record, filter)
	if filter then
		local ok, yes = pcall(filter, record)
		return ok and yes == true
	end
	return B.Search.Match(record) == true
end

-- The slots whose unlocked item matches the search, or filter, of the record B.Data.Item gives for it, in the order of the window.
local function Queue(kind, filter)
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
					if Usable(record) and record.id == held.id and Takes(record, filter) then
						queue[#queue + 1] = { bag = bag, slot = slot, id = held.id, link = held.link }
					end
				end
			end
		end
	end
	return queue
end

-- Why a click of Deposit or Take out cannot move anything now, or nil. A pass with a filter needs no search.
local function Refusal(filter)
	if not Bank.Live() then
		return "the bank is not open"
	end
	if E.Fighting() then
		return "you are in a fight"
	end
	if CursorBusy() then
		return "the cursor holds something"
	end
	if Targeting() then
		return "a spell waits for its target"
	end
	local blocker = Blocker()
	if blocker then
		return ("the %s is open"):format(blocker)
	end
	if not filter and B.Search.Active() ~= true then
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
	if Targeting() then
		return "a spell waited for its target"
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
	Sent(move)
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
	-- A pass of the search moves only what matches it: with the search cleared meanwhile, every item would. A pass of a section keeps its filter.
	if not run.filter and B.Search.Active() ~= true then
		Finish("the search was cleared")
		return
	end
	run.paused = false
	run.queue, run.next = Queue(run.kind, run.filter), 1
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

-- A click of Deposit or Take out, or with filter a line of a section's menu (BagsOrder.lua), which moves that section's items whatever the search
-- says. A second click of the same button stops its pass; a line of a menu ends a pass that runs and starts its own.
local function Start(kind, filter)
	local run = pass
	if run and run.draining then
		Finish(nil)
		run = nil
	end
	if run and run.kind == kind and not PER_CLICK and not filter then
		Finish(true)
		return true
	end
	if run and (run.kind ~= kind or filter or run.filter) then
		Finish(true)
		run = nil
	end
	local why = Refusal(filter)
	if why then
		print(("Flat UI: %s: %s."):format(WORDS[kind].none, why))
		return false, why
	end
	local queue = Queue(kind, filter)
	if #queue == 0 then
		if run then
			Drain(run)
		else
			print(("Flat UI: %s: %s."):format(WORDS[kind].none, filter and WORDS[kind].emptyOf or WORDS[kind].empty))
		end
		RequestFooter()
		return false, "nothing matches"
	end
	if PER_CLICK then
		run = run or { kind = kind, moved = 0, checks = 0, filter = filter }
		pass = run
		run.left = #queue - 1
		Move(run, queue[1])
		if run.left <= 0 then
			Drain(run)
		end
		RequestFooter()
		return true
	end
	run = { kind = kind, queue = queue, next = 1, moved = 0, checks = 0, filter = filter }
	pass = run
	Step(run)
	RequestFooter()
	return true
end

-- Deposit and Take out start a pass, or stop the one running (true, or false and why). filter: a function of a record, true for an item the pass
-- takes in place of the search (a section's menu, BagsOrder.lua). Busy gives the kind of the pass under way ("deposit" or "takeout"), how many
-- matching items it has left, and true when each click moves the next one (PER_CLICK; else a click stops it), or nil.
function Bank.Deposit(filter)
	local ok, why = false, nil
	Run(function()
		ok, why = Start("deposit", type(filter) == "function" and filter or nil)
	end)
	return ok, why
end

function Bank.TakeOut(filter)
	local ok, why = false, nil
	Run(function()
		ok, why = Start("takeout", type(filter) == "function" and filter or nil)
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

-- Shows the bank of a character (key, nil for this one): live at the banker with Flat UI's bank window (Bank.Live), else the bank as last left. Hides
-- the window when it shows that character already. False while Bags is off.
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

-- The visit ended. late: the module did not hear it end (Bank.Settle), so B.Data.BankClosed reads nothing more and leaves the snapshot's date as it
-- was. After a visit with Flat UI's bank window the game's buy question goes too, while it is the one popup shown (Errands.HideAlone): the game takes
-- it down only when its bank panel hides (BankFrameTemplates.lua:709-717 and 745-752), which a hidden BankFrame never does, and its Yes would ask to
-- buy away from the banker. Plain code, as the end of a visit is.
Closed = function(late)
	if not open then
		return
	end
	local wasFlat = flat
	open, flat, closing, closeWait = false, false, false, nil
	sent = {}
	if pass then
		Run(Finish, not PER_CLICK and "the bank closed" or nil)
		pass = nil
	end
	if wasFlat and type(E.HideAlone) == "function" then
		pcall(E.HideAlone, BUY_POPUP)
	end
	Call("cache", B.Data, "BankClosed", late == true)
	Call("follow", B, "BankClosed")
	Call("window", B, "Request", "layout", "bank")
	Refresh()
end

-- The tabs or the bank's bag slots changed. The bank window is laid out afresh only when the bought tabs or the bags in them changed
-- (B.Data.BankTabs says so): the items of the tabs come slot by slot at the next BAG_UPDATE_DELAYED (BagsData.lua), and nothing moves while the
-- window is open; a tab whose size the client gives only after this layout read it has BagsData lay the window out again then. When BagsData
-- could not say (BankTabs missing or failing), the window is laid out afresh as well; a stopped part of BagsData stands Bags down, and the window
-- with it.
local function Changed()
	if not open then
		return
	end
	local read, ran, moved = Usable(B.Data) and B.Data.BankTabs or nil, false, false
	local run = B.Part
	if type(read) == "function" and type(run) == "function" then
		run("cache", function()
			moved = read() == true
			ran = true
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
-- whose close the module did not hear ends now, as a late close (Closed(true): the snapshot keeps the date of its last write, which is no later
-- than what it holds), and one that began meanwhile starts now, while BankFrame shows and the player still deals with a banker: Bags does not hide
-- a BankFrame that shows (Parked is false), so the game's bank window stays that visit's live bank, B.Data.BankScan reads the bank, nothing that
-- comes out of it becomes new (Bank.Visiting), and BANKFRAME_CLOSED ends the visit as usual.
function Bank.Settle()
	local shown = E.Shown(_G.BankFrame)
	if open and not shown then
		Closed(true)
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
