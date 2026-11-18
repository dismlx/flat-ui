local _, ns = ...

-- Bags (off by default) puts every bag in one window of Flat UI's own, with sections and a search, and the bank in a second window, live at the
-- banker for a visit that starts while At the banker is Flat UI's bank window and the last snapshot otherwise; the game's bag windows stay hidden
-- while it is on, and its bank window too for such a visit. This file is the module, and the other Bags files are its parts. It makes ns.Bags and
-- every table the parts fill, for the files that load after it in this order: BagsData.lua (Data, the account cache), BagsCategories.lua
-- (Categories and Categories.New), BagsSearch.lua (Search), BagsItems.lua (Buttons), BagsLayout.lua (Layout), BagsWindow.lua (Window),
-- BagsBank.lua (Bank) and BagsTooltip.lua (Tips). A part adds fields to its own table only, adds the events it owns with ns.AddEvent while the
-- files load (Core.lua:2093-2141; so the module is registered here, first), and looks up the functions of the other parts when it calls them,
-- never at load. This file holds what they share (Opt, Look, On, Part, Request, Me, Viewing), decides when the bag window opens and closes, keeps
-- the game's windows hidden, stands down, and runs the redraw pass and the sort hold. Every part runs its work through Bags.Part (ns.EachPart,
-- Core.lua:2000-2035, with a fresh key per call as Errands.Run does, Errands.lua:215-227), so a part that keeps failing stops alone; when follow,
-- cache, window, layout or items stops, both windows hide and the game's windows go back, so the player always has bags (cache is BagsData's, the
-- only part that tells the windows the bags changed).
--
-- The game keeps deciding when bags are open, and the bag window follows it. Every way the game opens or closes bags goes through ten
-- functions: the key bindings (Bindings_Camelot.xml:1172-1192), the bag bar (Shared/MainMenuBarBagButtons.lua:69-87, 171-175), the merchant
-- (Mainline/MerchantFrame.lua:147-167), the game's bank window (Mainline/BankFrameTemplates.lua:97-109), mail, the auction house, loot toasts
-- (Mainline/AlertFrameSystems.lua:575, 623, 716) and Escape (UIParentPanelManager.lua:1175-1183) call ToggleBackpack, ToggleBag,
-- ToggleAllBags, OpenAllBags, OpenAllBagsMatchingContext, OpenBag, OpenBackpack, CloseAllBags, CloseBag or CloseBackpack
-- (Mainline/ContainerFrame.lua:189-199, 237-251, 2173-2217, 2153-2171, 2255-2280, 313-323, 378-391, 2282-2306, 360-366, 341-347). Each is
-- followed with hooksecurefunc (ns.FollowGlobal, Core.lua:1408-1416) once, at Start; a hook cannot be taken back, so each asks first whether
-- the page is on, and Bags stays off when one of them cannot be followed. None of the game's bag code is called here, not even a reader:
-- IsBagOpen, IsAnyBagOpen and CloseBag reach ContainerFrameUtil_EnumerateContainerFrames, which fills the game's list of bag windows the first
-- time it is asked (:349-376, 2219-2238, 2335-2373, 2416-2422) and is left empty after login with individual bags (:2443-2449, 2502-2513). A
-- list filled by Flat UI's code would be read by Escape's CloseAllBags in a fight (UIParentPanelManager.lua:1175-1177), and the panels Escape
-- hides next would refuse the tainted caller (:854-860, 920-922). Whether the game has a bag open is read from the shown flag of each of its
-- eight bag windows, ContainerFrameCombinedBags and ContainerFrame1 to ContainerFrame7 (Mainline/ContainerFrame.xml:298-304, 313), with the
-- widget call IsShown (Bags.GameBagsOpen), as Errands reads a game window (Errands.lua:264-271). ContainerFrame_AllowedToOpenBags is not asked
-- either: its CanOpenPanels writes a panel's layout attributes the first time (UIParentPanelManager.lua:85-90, 1059-1077). Its one rule about
-- bags is read with C_GameRules.IsGameRuleActive (Enum.GameRule.BagsUIDisabled) before a hold opens the window
-- (Mainline/ContainerFrame.lua:163-170).
--
-- The calls of one burst are settled once, on the next frame (C_Timer.After). The hooks run after the game's call, inner calls first, so the
-- burst keeps the kinds it heard, the kind heard last (the outermost call) and whether the bag window was open when it began. OpenBackpack
-- calls ToggleBackpack when no backpack is shown (Mainline/ContainerFrame.lua:378-391), and ToggleBackpack calls OpenBackpack with combined
-- bags (:172-177), so the kind heard last is the one the caller asked for. A toggle (a bag key or the bag bar) closes the window that was
-- open, and else opens it when a game bag is open. A ToggleBag that the game lets pass with nothing toggled is not heard, so it leaves the window
-- as it is: the keyring while the setting showKeyring is off, and with individual bags a bag slot that holds no bag, such as an empty slot of
-- the bag bar or the key of a bag the character does not have (:201-251; read with C_CVar.GetCVarBool and C_Container.GetContainerNumSlots;
-- with combined bags the bags up to NUM_BAG_SLOTS toggle the combined window whatever their size, :83-86, 2460-2468). Any other burst opens the
-- window when a game bag is open after an opening, and closes it
-- when none is and nothing holds it after a closing. A bag taken out of its slot closes its game window, and with combined bags the whole
-- combined window, which the game opens again at BAG_CONTAINER_UPDATE (:588-596, 2502-2547): for half a second after BAG_CLOSED a closing
-- waits, looks again, and closes the window only when no game bag is open then.
--
-- A hold keeps the window open while the game has no bag open. bank: at the banker, with Flat UI's bank window and Open the bags at the
-- banker (the hidden BankFrame never runs the OnShow that opens the game's bags, Mainline/BankFrameTemplates.lua:97-102), until BagsBank ends
-- the visit itself (it drops the hold then, as BankFrame's OnHide closes the bags it opened, :104-109) or the visit ends (Bags.BankClosed).
-- trade: between TRADE_SHOW and TRADE_CLOSED with Open the bags for a trade (the game opens bags for a trade only under the gamepad interface,
-- Mainline/TradeFrame.lua:29-32, 243-245). command: /flatui bags. A toggle while the window is open closes it, and every close drops them all.
--
-- Escape closes both windows: when the page comes up their names, FlatUIBags and FlatUIBank, go once into UISpecialFrames, which the game
-- walks with securecall (UIParentPanelManager.lua:21-27, 1106-1116, 1168), as the options window's does (Panel.lua:2700-2708). Whatever
-- closes the bag window (its close button, a toggle, Escape, or the page going off), the same steps follow once, from the hiding of a frame
-- of this file's own inside the window: the game's bag windows still open under the hidden frame are hidden (Hide, which runs no script
-- there); the game's new flag comes off every item of the bags (C_NewItems.IsNewItem and C_NewItems.RemoveNewItem over
-- C_Container.GetContainerNumSlots, for the backpack, the bags up to NUM_TOTAL_EQUIPPED_BAG_SLOTS and the keyring while
-- C_ActionBar.ShouldShowKeyring says it shows), as the game's own close does (UpdateNewItemList, Mainline/ContainerFrame.lua:349-358, 393-397,
-- 806), which a hidden window never runs; every hold goes; New items lets go (Categories.New.Close); the layout forgets its places
-- (Layout.Closed); the search clears unless the bank window is open; and the window goes back to this character. The sound is BagsWindow's. A
-- window closed while the player could not see it hears no hiding, so Bags.HideBags and Release take the same steps after it (Tidy), and
-- BagsWindow asks Bags.HideBags when the interface shows again and finds the window closed meanwhile with no hiding heard (its Missed). A window
-- hidden with its parent (the interface hidden) keeps its own shown flag and is not closed then: the game closes every window as the interface
-- comes back (UIParent's OnShow runs CloseAllWindows, Blizzard_UIParent/UIParent.lua:5-7, Blizzard_Game/Shared/Game.lua:91-93), and Escape
-- while the interface is hidden only brings it back (Game.lua:29-37). The warm-up of new item buttons (BagsWindow) shows and hides the window
-- without opening it, so nothing follows then either. The step that takes the new flags off is also Bags.ClearNew, for the other two
-- ways New items is put away while New items at the top is on: a sort of the bags (Bags.Sorted, below) and a click on the title of the top shelf
-- in the bag window (BagsLayout.lua), since a flag left on one of its items would bring it back at the next change of its slot. This file hides a
-- window through Window.Hide, which first has a slot of the bag window that owns the game's split box leave it to the game (B.Buttons.Unsplit)
-- and closes a window the player cannot see itself; one still shown after it (the window part stopped) is hidden here, after the same Unsplit,
-- and a bank window hidden here while the player could not see it heard no OnHide, so the visit it was the live bank of ends here
-- (B.Bank.Hidden of BagsBank.lua).
--
-- The game's windows are kept from drawing by moving each under a hidden frame of this file's own (SetParent, a widget call, after GetParent is
-- read and kept), out of combat (ns.OutOfCombat with a flag of its own, as BagSort.lua:597-619) and only while the game has it closed: moving a
-- shown window would run its OnShow or OnHide in Flat UI's taint (Mainline/ContainerFrame.lua:785-836, Mainline/BankFrameTemplates.lua:97-109).
-- They are the eight bag windows, and BankFrame (Camelot/BankFrame.xml:59) while At the banker is Flat UI's bank window. Under the hidden
-- frame they open and close as the game has them, but never draw and run no OnShow or OnHide, so they hear no BAG_UPDATE either. Each goes
-- back to the parent it was read from when the page goes off, the module or one of the parts above stops, another bag addon loads, the gamepad
-- interface comes, or (BankFrame alone) the game's bank window is chosen: at once, also in a fight, since none of them is protected
-- (Mainline/ContainerFrame.xml:229, 298-304, 313; Mainline/BankFrameTemplates.xml:667), when the game has it closed, and else once the game
-- closes it, which is seen through the ten functions and, for BankFrame, through HideUIPanel (PlayerInteractionFrameManager.lua:139-163),
-- also followed with hooksecurefunc, and BagsBank's end of the bank (Bags.BankClosed). BagsBank hides a BankFrame still shown under the hidden
-- frame (Hide, which runs no script there) just before it ends the bank itself: the game hides BankFrame inside that call
-- (PLAYER_INTERACTION_MANAGER_FRAME_HIDE is a synchronous event, PlayerInteractionManagerDocumentation.lua:103-104) with a HideUIPanel run under
-- Flat UI's code, which the game refuses in a fight; hidden first, the frame stops that HideUIPanel at its shown check.
-- ContainerFrame_SetFullScreenFrame and ContainerFrame_ClearFullScreenFrame give the bag windows another parent themselves
-- (Mainline/ContainerFrame.lua:138-161), so after either one they are moved under the hidden frame again. ns.BagsParked tells Movers and
-- Windows which of the game's windows nobody sees.
--
-- Bags stays off, hiding nothing and showing nothing, while another bag addon is loaded (C_AddOns.IsAddOnLoaded at Start and at ADDON_LOADED,
-- as Movers stands down for other movers, Movers.lua:87) and under the gamepad interface (InputUtil.IsGamepadUIEnabled, as BagSort.lua:516-524,
-- again at INPUT_DEVICE_INTERFACE_TRANSITION), where the game's bags and their gamepad cursor stay; also when one of the ten functions could
-- not be followed, or a file the window needs did not load. /flatui status and one line in chat say so.
--
-- Bags.Request gathers what the windows must draw again (items, layout, search, footer or look, and the slots BagsData found changed at
-- BAG_UPDATE_DELAYED, merged), per window; an ask for items that names no slots means every slot, whatever else the frame asked. One pass on
-- the next frame calls Window.Update for each open window; a closed window keeps what it was asked and drops the slots, since it lays out
-- afresh when it opens, and its opening lets that go (Bags.LaidOut, from BagsWindow's Showing), all but a change of look, which the fresh layout
-- does not paint. The sort hold: the game's clean up only asks the server, and the items then move over many BAG_UPDATE_DELAYED
-- (BagSort.lua:294-325), so after BagSort says it asked (Bags.Sorted) the window keeps every place: its slots are drawn where they are, nothing
-- moves to the arrivals (Bags.Sorting tells BagsWindow), and the fresh layout waits for 0.4 seconds with no change after one came, 1.5 seconds
-- when none comes, or 6 seconds at most; another character chosen meanwhile is laid out at once. A sort of the bags puts New items away, and
-- while New items at the top is on it first takes the game's new flags off the bags (Bags.ClearNew), before anything moves.
--
-- The events this file owns, each heard only here, in this order: BAG_CLOSED (the swap wait above; ContainerDocumentation.lua:613);
-- PLAYER_REGEN_ENABLED (with Errands off, ns.ErrandsSellJunk goes on with a Sell junk pass that a fight paused, which Errands does itself while
-- it is on; work queued with ns.OutOfCombat runs from Core.lua:3492-3500; UnitDocumentation.lua:3893); MERCHANT_SHOW and MERCHANT_CLOSED
-- (Bags.atMerchant, ns.ErrandsMerchantClosed at the close, then the footer of the bag window; MerchantFrameDocumentation.lua:112, 96);
-- TRADE_SHOW and TRADE_CLOSED (the trade hold; TradeInfoDocumentation.lua:143, 78); ADDON_LOADED and INPUT_DEVICE_INTERFACE_TRANSITION
-- (standing down; AddOnsDocumentation.lua:391, InputDocumentation.lua:343). Every other event of the page belongs to its part: BagsData hears
-- the bags, the money and the item data, BagsItems the locks, cooldowns and the start of a fight, BagsBank the bank. ItemMarks adds its own
-- handlers to the module (ItemMarks.Hear), and its watcher and BagSort's call Bags.Request and Bags.Sorted, as Errands' does when its sell or
-- keep list changes (ns.ErrandsListsWatch). The module hears no event while the page is off, so when it comes up again whether a merchant is
-- open is read anew, and a visit to a banker that ended meanwhile is ended and one under way begins (Bank.Settle of BagsBank.lua, once the bag
-- slots are made); and when the page comes on again after Start, which runs Refresh and not Start, BagsData reads again what its Start reads
-- (Data.Resume), whether Bags stands down or not.
--
-- /flatui bags opens or closes the bag window with the command hold, and /flatui bags Name shows the bags of a character Flat UI keeps;
-- /flatui bank and /flatui bank Name ask BagsBank for the bank window. They run whatever the switch of the page, and say so while it is off.
--
-- Besides the calls above it reads GetTime, InCombatLockdown, ns.Enabled (to tell that the page came on again) and, when the page comes up,
-- whether MerchantFrame is shown (IsShown); and it makes frames of its own with CreateFrame (the hidden frame, and in each window a frame that
-- only hears the window's OnShow and OnHide). Its lines of /flatui status are the windows it hides and why it stands down; BagsData and
-- BagsBank add theirs (ns.AddStatus).

local KEY = "bags"
-- The game's eight bag windows, every window its list of bag windows can hold (Mainline/ContainerFrame.lua:2346-2360), and its bank window.
local GAME_BAGS = { "ContainerFrameCombinedBags", "ContainerFrame1", "ContainerFrame2", "ContainerFrame3", "ContainerFrame4", "ContainerFrame5",
	"ContainerFrame6", "ContainerFrame7" }
local BANK_FRAME = "BankFrame"
local KEPT = {}
for _, name in ipairs(GAME_BAGS) do
	KEPT[#KEPT + 1] = name
end
KEPT[#KEPT + 1] = BANK_FRAME
-- Bag addons that hide the same windows: two of them on one frame fight over it.
local OTHER_BAGS = { "Bagnon", "Baganator", "AdiBags", "BetterBags", "ArkInventory", "Combuctor", "LiteBag", "Inventorian", "Bagshui", "Sorted" }
local OTHER = {}
for _, name in ipairs(OTHER_BAGS) do
	OTHER[name] = true
end
-- The game's functions that open and close bags, the kind of call each is, and for ToggleBag a handler of its own, which reads the bag it names.
local FOLLOW = {
	{ "ToggleBackpack", "toggled" }, { "ToggleBag", "toggled", "bag" }, { "ToggleAllBags", "toggled" },
	{ "OpenAllBags", "opened" }, { "OpenAllBagsMatchingContext", "opened" }, { "OpenBag", "opened" }, { "OpenBackpack", "opened" },
	{ "CloseAllBags", "closed" }, { "CloseBag", "closed" }, { "CloseBackpack", "closed" },
}
-- The two windows, by the word the parts use, and the global names BagsWindow gives them.
local WINDOWS = { "bags", "bank" }
local NAMES = { bags = "FlatUIBags", bank = "FlatUIBank" }
-- What Request takes, and the reasons that hold the bag window open.
local FLAGS = { items = true, layout = true, search = true, footer = true, look = true }
local HOLDS = { bank = true, trade = true, command = true }
-- The parts without which the window cannot stand in for the game's bags: when one stops, the game's windows go back. cache (BagsData.lua) is
-- the only part that hears the bags change and asks the windows to draw again, so without it they would show what the bags held before.
local CRITICAL = { follow = true, cache = true, window = true, layout = true, items = true }
local CRITICAL_ORDER = { "follow", "cache", "window", "layout", "items" }
-- Seconds: how long a closing waits after BAG_CLOSED, and the sort hold (quiet after a change, no change at all, at most).
local SWAP_WAIT = 0.5
local SORT_QUIET, SORT_NONE, SORT_CAP = 0.4, 1.5, 6
-- No container has more slots than this.
local MOST_SLOTS = 200
-- The last bag and the keyring, and the last bag that combined bags show in the combined window (NUM_BAG_SLOTS; Mainline/ContainerFrame.lua:83-86),
-- for a client whose constants do not say (Blizzard_FrameXMLBase/Constants.lua:165-170).
local LAST_BAG, KEYRING, LAST_COMBINED = 5, -1, 4
local SAY = {
	off = "Bags is off. Turn on Flat UI bags on the Bags page.",
	stopped = "Bags has stopped. /flatui status shows why.",
	part = "Bags stopped in %s. /flatui status shows why.",
	starting = "Bags has not started yet.",
	shut = "the game keeps the bags shut here.",
	none = "Bags keeps no other character yet. Each is kept when it logs in with Flat UI bags on.",
	unknown = "Bags keeps no character called %s.",
	known = "Kept: %s.",
	several = "More than one character is called %s: %s. Type the realm too.",
	noBank = "the Flat UI bank window is not there.",
}
-- Why Bags stays off: in chat once a session, and in /flatui status.
local DOWN_CHAT = {
	follow = "Flat UI: Bags stays off: the game's bag functions could not be followed, so the game's bags are used.",
	missing = "Flat UI: Bags stays off: a file of its window did not load, so the game's bags are used.",
	gamepad = "Flat UI: Bags stays off under the gamepad interface, where the game's bags are used.",
	addon = "Flat UI: Bags stays off while %s is loaded.",
}
local DOWN_STATUS = {
	follow = "Bags: the game's bag functions could not be followed, so the game's bags are used.",
	missing = "Bags: a file of its window did not load, so the game's bags are used.",
	gamepad = "Bags: under the gamepad interface the game's bags are used.",
	addon = "Bags: stays off while %s is loaded.",
}
local HELP = {
	"/flatui bags - open or close the Flat UI bag window",
	"/flatui bags Name - the bags of another of your characters, as Flat UI last saw them",
	"/flatui bank - your bank: live at the banker with Flat UI's bank window, else as you last left it",
	"/flatui bank Name - the bank of another of your characters",
}

-- ns.IsSecret of Core.lua, looked up when called.
local function IsSecret(value)
	return ns.IsSecret(value)
end

-- The table every Bags file shares. The parts add fields to their own tables and never replace one.
local B = {
	KEY = KEY,
	Data = {},
	Categories = { New = {} },
	Search = {},
	Buttons = {},
	Layout = {},
	Window = {},
	Bank = {},
	Tips = {},
	-- True between MERCHANT_SHOW and MERCHANT_CLOSED.
	atMerchant = false,
}
ns.Bags = B

-- started: Start ran. up: the page stands in for the game's bags now. followed: the ten functions are followed (nil before the first try).
-- down: why Bags stays off ("follow", "missing", "gamepad", or "addon" with downAddon), else nil. said: the reasons already said in chat this
-- session. enabled: whether the module was on (ns.Enabled) when Start or Refresh last ran, so Refresh can tell that it came on again.
local started, up, followed, down, downAddon = false, false, nil, nil, nil
local enabled = false
local said = {}
-- The game's windows under the hidden frame, each with the parent it goes back to; the hidden frame.
local parked = setmetatable({}, { __mode = "k" })
local hidden
-- bagsOpen: the bag window was opened (ShowBags) and has not closed since. holds: the reasons that keep it open.
local bagsOpen = false
local holds = {}
-- The calls of the game heard since the last settle; the time of the last BAG_CLOSED; the token of a closing that waits.
local burst, swapAt, swapToken
-- What each window must draw again: { flags, changed (the slots to look at), all (every slot) }; a pass waits for the next frame; the sort hold
-- of each window.
local wants = { bags = { flags = {} }, bank = { flags = {} } }
local passQueued = false
local sorting = {}
-- The character each window shows, nil for this one.
local viewing = {}
-- The windows of BagsWindow by word, and the frame of this file's own inside each.
local windows = {}
local sentinels = setmetatable({}, { __mode = "k" })
-- A parking pass waits for the next frame, or for the end of the fight. A release runs.
local syncQueued, syncAfterFight, releasing = false, false, false
-- The parts whose first error went to the game's error handler.
local reported = {}
-- The functions that follow the ten game calls, made once so that following again adds nothing.
local handlers

local Release, Tidy, Queue, Sync, SoonSync

-- Small helpers ------------------------------------------------------------------------------------------------------------------------------

-- The first answer of a call of the client, or nil when the call is missing, raises or the answer is withheld.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

-- Runs fn and sends an error to the game's error handler; true when it ran through.
local function Safely(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		local handler = type(geterrorhandler) == "function" and geterrorhandler()
		if type(handler) == "function" then
			pcall(handler, err)
		end
	end
	return ok
end

-- A timer of the client, false when there is none or it raises.
local function After(seconds, fn)
	return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, seconds, fn) or false
end

local function Now()
	local now = Ask(GetTime)
	return ns.Finite(now) and now or 0
end

local function InCombat()
	return Ask(InCombatLockdown) == true
end

-- Whether a frame has its own shown flag set, read with the widget call IsShown. False when it is missing, forbidden or does not say.
local function Shown(frame)
	if type(frame) ~= "table" or IsSecret(frame) or type(frame.IsShown) ~= "function" then
		return false
	end
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and not IsSecret(shown) and shown == true
end

-- A window of the game by its global name, unless it is missing or forbidden.
local function Game(name)
	local frame = _G[name]
	if type(frame) == "table" and not IsSecret(frame) and not ns.Forbidden(frame) then
		return frame
	end
	return nil
end

local function Trim(text)
	if type(text) ~= "string" or IsSecret(text) then
		return ""
	end
	return text:match("^%s*(.-)%s*$") or ""
end

-- The shared helpers ---------------------------------------------------------------------------------------------------------------------------

function B.Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- The look of the windows is the Windows page's: opacity, panel, accent and crop.
function B.Look(key)
	return ns.Get("windows." .. key)
end

-- "Name - Realm" of this character, or nil while the client does not say (Core.lua:2704-2707).
function B.Me()
	return ns.CharacterKey()
end

-- True while the page stands in for the game's bags: on, started, not stopped, not standing down, and none of its critical parts stopped.
function B.On()
	if not started or down ~= nil or not ns.Enabled(KEY) then
		return false
	end
	for _, part in ipairs(CRITICAL_ORDER) do
		if ns.PartStopped(KEY, part) then
			return false
		end
	end
	return true
end

-- Runs fn as a part of the module. ns.EachPart counts each failure (a fresh key per call, since a call with no values would count once) and
-- stops the part alone after a few, with a line for /flatui status; its first error also goes to the game's error handler, so it is seen. A
-- critical part that stops gives the game's windows back at once.
function B.Part(name, fn, ...)
	local ok, err = ns.EachPart(KEY, name, function(_, ...)
		return fn(...)
	end, {}, ...)
	if not ok and err ~= nil then
		if not reported[name] then
			reported[name] = true
			local handler = type(geterrorhandler) == "function" and geterrorhandler()
			if type(handler) == "function" then
				pcall(handler, ("Flat UI Bags, %s: %s"):format(tostring(name), tostring(err)))
			end
		end
		if CRITICAL[name] and ns.PartStopped(KEY, name) and not releasing then
			Release()
		end
	end
	return ok, err
end

-- Calls a function of a part, looked up now, as that part (B.Part). False when the part has no such function.
local function Call(part, tbl, name, ...)
	local fn = type(tbl) == "table" and tbl[name]
	if type(fn) ~= "function" then
		return false
	end
	return (B.Part(part, fn, ...))
end

-- Keeping the game's windows hidden ------------------------------------------------------------------------------------------------------------

local function Hidden()
	if not hidden then
		hidden = CreateFrame("Frame")
		ns.Own[hidden] = true
		hidden:Hide()
	end
	return hidden
end

local function Parent(frame)
	local ok, parent = pcall(frame.GetParent, frame)
	if ok and type(parent) == "table" and not IsSecret(parent) then
		return parent
	end
	return nil
end

-- Whether a window of the game is under the hidden frame now.
local function Under(frame)
	return hidden ~= nil and rawequal(Parent(frame), hidden)
end

local function Park(frame)
	local parent = Parent(frame)
	if parent == nil or rawequal(parent, Hidden()) then
		return false
	end
	if not pcall(frame.SetParent, frame, Hidden()) then
		return false
	end
	parked[frame] = parent
	return true
end

local function PutBack(frame)
	local parent = parked[frame]
	if parent == nil then
		return true
	end
	if Under(frame) and not pcall(frame.SetParent, frame, parent) then
		return false
	end
	parked[frame] = nil
	return true
end

-- Whether a window of the game is to be kept hidden now: the bag windows while the page is on, BankFrame also only with Flat UI's bank window.
local function Wanted(name)
	if not B.On() then
		return false
	end
	if name == BANK_FRAME then
		return B.Opt("bank") ~= "game"
	end
	return true
end

local function SyncAfterFight()
	if syncAfterFight then
		return
	end
	syncAfterFight = true
	ns.OutOfCombat(function()
		syncAfterFight = false
		Safely(Sync)
	end)
end

-- Brings each window of the game where it is wanted: under the hidden frame out of combat, or back to its parent at once, each only while the
-- game has it closed. A shown one waits for the next pass, which the game's next call or BankFrame's hiding brings.
function Sync()
	local fight, later = InCombat(), false
	for _, name in ipairs(KEPT) do
		local frame = Game(name)
		if frame then
			if parked[frame] ~= nil and not Under(frame) then
				-- The game gave it another parent (Mainline/ContainerFrame.lua:138-161); that is the one to go back to now.
				parked[frame] = nil
			end
			local want = Wanted(name)
			if want and parked[frame] == nil and not Shown(frame) then
				if fight then
					later = true
				else
					Park(frame)
				end
			elseif not want and parked[frame] ~= nil and not Shown(frame) then
				if not PutBack(frame) and fight then
					later = true
				end
			end
		end
	end
	if later then
		SyncAfterFight()
	end
end

-- A parking pass on the next frame, once for a run of calls, so nothing of this file runs inside the game's own call.
function SoonSync()
	if syncQueued then
		return
	end
	syncQueued = true
	if not After(0, function()
		syncQueued = false
		Safely(Sync)
	end) then
		syncQueued = false
		Safely(Sync)
	end
end

-- True for a window of the game that Bags keeps hidden (Movers and Windows leave it alone).
function ns.BagsParked(frame)
	if type(frame) ~= "table" or IsSecret(frame) or parked[frame] == nil then
		return false
	end
	return Under(frame)
end

-- The game's bag windows ---------------------------------------------------------------------------------------------------------------------

-- True when one of the game's eight bag windows has its shown flag set. It stands in for IsAnyBagOpen, which answers from the same flags
-- (Mainline/ContainerFrame.lua:368-376, 2235-2238) but fills the game's list of bag windows on the way.
function B.GameBagsOpen()
	for _, name in ipairs(GAME_BAGS) do
		if Shown(Game(name)) then
			return true
		end
	end
	return false
end

-- The containers of the bags: the backpack, the bags up to the reagent bag, and the keyring while the game shows one
-- (Mainline/ContainerFrame.lua:10-12, 2226-2230).
local function HeldBags()
	local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS
	if not ns.Finite(last) or last < 0 or last > 20 then
		last = LAST_BAG
	end
	local list = {}
	for bag = 0, math.floor(last) do
		list[#list + 1] = bag
	end
	local keyring = type(C_ActionBar) == "table" and Ask(C_ActionBar.ShouldShowKeyring)
	if keyring == true then
		list[#list + 1] = ns.Finite(KEYRING_CONTAINER) and KEYRING_CONTAINER or KEYRING
	end
	return list
end

-- Takes the game's new flag off every item of the bags, as the game's close does for each window it closes.
local function ClearNew()
	if type(C_NewItems) ~= "table" or type(C_NewItems.IsNewItem) ~= "function" or type(C_NewItems.RemoveNewItem) ~= "function"
		or type(C_Container) ~= "table" or type(C_Container.GetContainerNumSlots) ~= "function" then
		return
	end
	for _, bag in ipairs(HeldBags()) do
		local slots = Ask(C_Container.GetContainerNumSlots, bag)
		if ns.Finite(slots) and slots > 0 then
			for slot = 1, math.min(math.floor(slots), MOST_SLOTS) do
				if Ask(C_NewItems.IsNewItem, bag, slot) == true then
					pcall(C_NewItems.RemoveNewItem, bag, slot)
				end
			end
		end
	end
end

-- Hides each game bag window still open under the hidden frame, where Hide runs no script, and gives how many. A window that is open and not
-- hidden away yet is left to the player: hiding it would run its OnHide in Flat UI's taint.
local function HideParked()
	local count = 0
	for _, name in ipairs(GAME_BAGS) do
		local frame = Game(name)
		if frame and parked[frame] ~= nil and Under(frame) and Shown(frame) and pcall(frame.Hide, frame) then
			count = count + 1
		end
	end
	return count
end

-- The game's open bag windows that are hidden away close, then the game's new flags come off, as the game's close would take them.
function B.HideGameBags()
	HideParked()
	ClearNew()
end

-- The close's step that takes the game's new flags off (ClearNew), for a sort of the bags (Bags.Sorted) and a click on the title of the top shelf
-- in the bag window (BagsLayout.lua), each while New items at the top is on, which put New items away as the close does: a flag left on one of
-- its items would bring it back at the next change of its slot (Categories.New.Seen, BagsData.lua), and a sort changes nearly every slot. Nothing
-- while the page is not in use; it runs as the follow part, as the close's own step does.
function B.ClearNew()
	if B.On() then
		B.Part("follow", ClearNew)
	end
end

-- The windows of BagsWindow -----------------------------------------------------------------------------------------------------------------

local function Showed(which)
	if next(wants[which].flags) ~= nil then
		Queue()
	end
end

local function Hid(which)
	if which == "bags" then
		Tidy()
	end
end

-- A frame of this file's own inside a window: its OnShow and OnHide follow the window's, whatever scripts the window has.
local function Watch(frame, which)
	if sentinels[frame] ~= nil then
		return
	end
	sentinels[frame] = false
	local ok, sentinel = pcall(CreateFrame, "Frame", nil, frame)
	if not ok or type(sentinel) ~= "table" then
		return
	end
	ns.Own[sentinel] = true
	sentinel:SetSize(1, 1)
	sentinel:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	sentinel:SetScript("OnShow", function()
		Safely(Showed, which)
	end)
	sentinel:SetScript("OnHide", function()
		Safely(Hid, which)
	end)
	sentinels[frame] = sentinel
end

-- A window by its word, from BagsWindow (Window.Get, which may make it), else by the global name it gives the window. quiet: only a window
-- already made, by its name; nothing is made.
local function Frame(which, quiet)
	local frame = windows[which]
	if frame then
		return frame
	end
	local get = B.Window.Get
	if not quiet and type(get) == "function" then
		local ok, made = pcall(get, which)
		if ok then
			frame = made
		end
	end
	if type(frame) ~= "table" or IsSecret(frame) then
		frame = _G[NAMES[which]]
	end
	if type(frame) ~= "table" or IsSecret(frame) then
		return nil
	end
	windows[which] = frame
	Watch(frame, which)
	return frame
end

-- Whether a window is open: the bank window while shown, the bag window while shown after ShowBags opened it. quiet as for Frame.
local function Open(which, quiet)
	if not Shown(Frame(which, quiet)) then
		return false
	end
	return which ~= "bags" or bagsOpen
end

-- The redraw pass ------------------------------------------------------------------------------------------------------------------------------

local function Merge(into, changed)
	for bag, slots in pairs(changed) do
		if ns.Finite(bag) and type(slots) == "table" then
			local set = into[bag] or {}
			into[bag] = set
			for slot, on in pairs(slots) do
				if on and ns.Finite(slot) then
					set[slot] = true
				end
			end
		end
	end
end

local function Pass()
	passQueued = false
	if not B.On() then
		for _, which in ipairs(WINDOWS) do
			wants[which] = { flags = {} }
		end
		return
	end
	for _, which in ipairs(WINDOWS) do
		local want = wants[which]
		if next(want.flags) ~= nil then
			if Open(which) then
				wants[which] = { flags = {} }
				-- No slots named (nil) is every slot.
				Call("window", B.Window, "Update", which, want.flags, (not want.all) and want.changed or nil)
			else
				want.changed, want.all = nil, nil
			end
		end
	end
end

function Queue()
	if passQueued then
		return
	end
	passQueued = true
	if not After(0, function()
		Safely(Pass)
	end) then
		Safely(Pass)
	end
end

-- flag: "items", "layout", "search", "footer" or "look"; which: "bags", "bank" or nil for both; changed: { [bag] = { [slot] = true } } from
-- BagsData at BAG_UPDATE_DELAYED, for that window. An ask for items with no changed means every slot (marks or names that went old, a junk list
-- or a bag's flag that changed), and wins over the slots asked for in the same frame. During a sort hold the window keeps every place: a layout
-- waits for the end of the hold, and the changed slots are drawn where they are, not moved to the arrivals; each call with changed is the time
-- of the last bag change.
function B.Request(flag, which, changed)
	if not FLAGS[flag] or (which ~= nil and wants[which] == nil) or not B.On() then
		return
	end
	for _, w in ipairs(WINDOWS) do
		if which == nil or which == w then
			local want, hold = wants[w], sorting[w]
			if hold and changed ~= nil then
				hold.last = Now()
			end
			if not (hold and flag == "layout") then
				want.flags[flag] = true
				if flag == "items" and type(changed) ~= "table" then
					want.all, want.changed = true, nil
				elseif not hold and not want.all and type(changed) == "table" then
					want.changed = want.changed or {}
					Merge(want.changed, changed)
				end
			end
		end
	end
	Queue()
end

-- A window opened (BagsWindow's Showing, before its fresh layout): what was asked for it while it was closed is drawn by that layout, so it goes
-- here, and the pass after the opening does not draw every slot again. A change of look stays, since the opening paints neither the search boxes
-- nor the buttons the layout does not show; what is asked from here on keeps its pass. Nothing is queued.
function B.LaidOut(which)
	local want = wants[which]
	if want == nil then
		return
	end
	local flags = want.flags
	flags.items, flags.layout, flags.search, flags.footer = nil, nil, nil, nil
	want.changed, want.all = nil, nil
end

-- The character each window shows: nil is this one.
function B.Viewing(which)
	return viewing[which]
end

function B.SetViewing(which, key)
	if wants[which] == nil then
		return
	end
	if IsSecret(key) or type(key) ~= "string" or key == "" or key == B.Me() then
		key = nil
	end
	if viewing[which] == key then
		return
	end
	viewing[which] = key
	if sorting[which] and B.On() and Open(which, true) then
		-- Another character keeps none of the places a sort hold keeps: the open window's layout does not wait for the end of the hold.
		wants[which].flags.layout = true
		Queue()
	else
		B.Request("layout", which)
	end
	B.Request("footer", which)
end

-- Opening and closing the bag window -------------------------------------------------------------------------------------------------------

local function AnyHold()
	return next(holds) ~= nil
end

-- False while the game's rules shut the bags (Enum.GameRule.BagsUIDisabled, the test of ContainerFrame_AllowedToOpenBags that concerns bags).
local function BagsAllowed()
	local rules = C_GameRules
	if type(rules) ~= "table" or IsSecret(rules) or type(rules.IsGameRuleActive) ~= "function" then
		return true
	end
	local enum = type(Enum) == "table" and not IsSecret(Enum) and Enum.GameRule
	local rule = type(enum) == "table" and enum.BagsUIDisabled or nil
	if rule == nil or IsSecret(rule) then
		return true
	end
	return Ask(rules.IsGameRuleActive, rule) ~= true
end

-- Opens the bag window for a reason: "game" (the game opened a bag), or the hold "bank", "trade" or "command", which is kept.
function B.ShowBags(reason)
	if not B.On() then
		return false
	end
	local hold = HOLDS[reason] == true
	if hold then
		if not BagsAllowed() then
			return false
		end
		holds[reason] = true
	end
	if bagsOpen then
		return true
	end
	-- Window.Show is asked even when the window shows already: the warm-up may be showing it for a frame. The frame of this file's own
	-- inside it is shown first, in case something hid it, since a hidden one hears no hiding of the window.
	local sentinel = sentinels[Frame("bags") or false]
	if sentinel and not Shown(sentinel) then
		pcall(sentinel.Show, sentinel)
	end
	Call("window", B.Window, "Show", "bags")
	local frame = Frame("bags")
	if B.On() and Shown(frame) then
		bagsOpen = true
		if next(wants.bags.flags) ~= nil then
			Queue()
		end
		return true
	end
	if hold then
		holds[reason] = nil
	end
	return false
end

-- Hides a window of BagsWindow that shows: through Window.Hide, which first has a slot that owns the game's split box (StackSplitFrame) leave it
-- to the game (B.Buttons.Unsplit, BagsItems.lua), and runs the steps of the window's close itself when the player cannot see it, since it hears no
-- OnHide then. When that did not hide it (the window part stopped, or the warm-up of BagsWindow shows the window for that frame), it is hidden
-- here, and the bag window's slots first leave the split box to the game here too, outside the parts, so a stopped items part does not stop
-- that: a hiding made by Flat UI's code would otherwise run the template's OnHide, which hides the box in Flat UI's taint
-- (ContainerFrame.lua:1816-1822; Mainline/StackSplitFrame.lua:284-299). A bank window hidden here ends the visit it was the live bank of
-- (B.Bank.Hidden, BagsBank.lua), also outside the parts: one the player saw heard its OnHide, which ended the visit already, and one the player
-- could not see heard none.
local function HideWindow(which, frame)
	Call("window", B.Window, "Hide", which)
	if Shown(frame) then
		local unsplit = which == "bags" and B.Buttons.Unsplit or nil
		if type(unsplit) == "function" then
			pcall(unsplit)
		end
		pcall(frame.Hide, frame)
		local ended = which == "bank" and not Shown(frame) and B.Bank.Hidden or nil
		if type(ended) == "function" then
			pcall(ended)
		end
	end
end

-- Closes the bag window. Its hiding runs the steps of a close (Tidy).
function B.HideBags()
	local frame = Frame("bags", true)
	if Shown(frame) then
		HideWindow("bags", frame)
	end
	if bagsOpen and not Shown(frame) then
		Tidy()
	end
end

-- Sets or drops a hold. Dropping the last one closes the window when no game bag is open.
function B.Hold(reason, on)
	if not HOLDS[reason] then
		return false
	end
	if on then
		return B.ShowBags(reason)
	end
	if holds[reason] then
		holds[reason] = nil
		if B.On() and bagsOpen and not AnyHold() and not B.GameBagsOpen() then
			B.HideBags()
		end
	end
	return true
end

-- The steps of a close, once for each opening. A window hidden with its parent keeps its own shown flag and is not closed then; the game closes it
-- when the interface comes back.
function Tidy()
	if not bagsOpen or Shown(windows.bags) then
		return
	end
	bagsOpen = false
	swapToken = nil
	if releasing then
		pcall(B.HideGameBags)
	else
		B.Part("follow", B.HideGameBags)
	end
	for reason in pairs(holds) do
		holds[reason] = nil
	end
	Call("layout", B.Categories.New, "Close")
	Call("layout", B.Layout, "Closed", "bags")
	if not Open("bank", true) then
		Call("search", B.Search, "SetText", "")
	end
	B.SetViewing("bags", nil)
end

-- Following the game ---------------------------------------------------------------------------------------------------------------------------

-- A closing within the swap wait looks again once the wait is over.
local function Recheck()
	if B.On() and bagsOpen and not AnyHold() and not B.GameBagsOpen() then
		B.HideBags()
	end
end

-- What a burst of the game's calls does to the window. last: the kind heard last, the caller's own.
local function Apply(marks, last, wasShown)
	local open = B.GameBagsOpen()
	if last == "toggled" then
		if wasShown then
			B.HideBags()
		elseif open then
			B.ShowBags("game")
		end
	elseif open then
		if marks.opened then
			B.ShowBags("game")
		end
	elseif marks.closed and bagsOpen and not AnyHold() then
		local left = swapAt and (swapAt + SWAP_WAIT - Now()) or 0
		if left > 0 then
			local token = {}
			swapToken = token
			if After(left, function()
				if swapToken == token then
					swapToken = nil
					B.Part("follow", Recheck)
				end
			end) then
				return
			end
		end
		B.HideBags()
	end
end

local function Settle()
	local heard = burst
	burst = nil
	if heard == nil or not B.On() then
		return
	end
	B.Part("follow", Apply, heard.marks, heard.last, heard.wasShown)
end

-- Runs after each of the ten calls of the game: notes the kind for the settle of the next frame, and has a parking pass look at the windows.
local function Heard(kind)
	local on = B.On()
	if on or next(parked) ~= nil then
		SoonSync()
	end
	if not on then
		return
	end
	if burst == nil then
		burst = { marks = {}, wasShown = bagsOpen }
		if not After(0, function()
			Safely(Settle)
		end) then
			burst.marks[kind], burst.last = true, kind
			Settle()
			return
		end
	end
	burst.marks[kind] = true
	burst.last = kind
end

-- The game hid a panel: BankFrame closed, so a parking pass may move it now.
local function PanelHidden(frame)
	if type(frame) ~= "table" or IsSecret(frame) or not rawequal(frame, _G[BANK_FRAME]) then
		return
	end
	if B.On() or next(parked) ~= nil then
		SoonSync()
	end
end

-- The game gave its bag windows another parent.
local function Reparented()
	if B.On() or next(parked) ~= nil then
		SoonSync()
	end
end

-- True for a ToggleBag that the game lets pass with nothing toggled: the keyring while its showKeyring setting is off, and with individual bags a
-- bag slot that holds no bag, a size of 0 (Mainline/ContainerFrame.lua:201-251), such as a click on an empty slot of the bag bar or the key of the
-- reagent bag on a character without one. With combined bags the backpack and the bags up to NUM_BAG_SLOTS toggle the combined window whatever
-- their size (:83-86, 232-235, 2460-2468). The settings are read with C_CVar.GetCVarBool and the size with C_Container.GetContainerNumSlots; an id
-- or an answer the client withholds counts as a toggle.
local function Ignored(id)
	if IsSecret(id) or not ns.Finite(id) then
		return false
	end
	local cvars = C_CVar
	local setting = type(cvars) == "table" and not IsSecret(cvars) and cvars.GetCVarBool or nil
	if id == (ns.Finite(KEYRING_CONTAINER) and KEYRING_CONTAINER or KEYRING) then
		return Ask(setting, "showKeyring") == false
	end
	local combined = ns.Finite(NUM_BAG_SLOTS) and NUM_BAG_SLOTS or LAST_COMBINED
	if id >= 0 and id <= combined and Ask(setting, "combinedBags") == true then
		return false
	end
	local container = C_Container
	local size = type(container) == "table" and not IsSecret(container) and Ask(container.GetContainerNumSlots, id) or nil
	return ns.Finite(size) and size == 0
end

local function Follow()
	if followed then
		return
	end
	handlers = handlers or {
		toggled = function()
			Heard("toggled")
		end,
		-- ToggleBag(id): a call the game lets pass is not heard while the page is in use, so it leaves the window as it is.
		bag = function(id)
			if B.On() and Ignored(id) then
				return
			end
			Heard("toggled")
		end,
		opened = function()
			Heard("opened")
		end,
		closed = function()
			Heard("closed")
		end,
	}
	local all = true
	for _, entry in ipairs(FOLLOW) do
		if ns.FollowGlobal(entry[1], handlers[entry[3] or entry[2]]) ~= true then
			all = false
		end
	end
	ns.FollowGlobal("HideUIPanel", PanelHidden)
	ns.FollowGlobal("ContainerFrame_SetFullScreenFrame", Reparented)
	ns.FollowGlobal("ContainerFrame_ClearFullScreenFrame", Reparented)
	followed = all
end

-- The sort hold ------------------------------------------------------------------------------------------------------------------------------

-- Ends the hold of a window when it is due, or looks again when it will be: a fresh layout then.
local function HoldEnd(which, hold)
	if sorting[which] ~= hold then
		return
	end
	local due = hold.start + SORT_CAP
	if hold.last then
		due = math.min(due, hold.last + SORT_QUIET)
	else
		due = math.min(due, hold.start + SORT_NONE)
	end
	local left = due - Now()
	if left > 0 and After(left, function()
		Safely(HoldEnd, which, hold)
	end) then
		return
	end
	sorting[which] = nil
	B.Request("layout", which)
end

-- BagSort's watcher: the game was asked to sort the bags or the bank. A layout or slots that waited for the next pass give way to the hold,
-- whose end lays the window out afresh. A sort of the bags also puts New items away, and while New items at the top is on it first takes the
-- game's new flags off (Bags.ClearNew): BagSort tells its watchers right after it asks the game (BagSort.lua:344-352), before anything moves, and
-- the moves would file every flagged item in New items again. With the row off nothing is kept as new, and the game's flags stay.
function B.Sorted(which)
	if wants[which] == nil or not B.On() then
		return
	end
	local hold = { start = Now() }
	sorting[which] = hold
	wants[which].flags.layout, wants[which].changed = nil, nil
	if which == "bags" then
		if B.Opt("newItems") ~= false then
			B.ClearNew()
		end
		Call("layout", B.Categories.New, "Clear")
	end
	HoldEnd(which, hold)
end

-- True while the sort hold of a window lasts: BagsWindow keeps its sort button busy and lets nothing arrive at the top shelf until then, also
-- when the window closed and opened again during the hold.
function B.Sorting(which)
	return sorting[which] ~= nil
end

-- The bank -----------------------------------------------------------------------------------------------------------------------------------

-- BagsBank made the bank live: BankFrame is kept hidden with Flat UI's bank window, and the bags open with it while the row says so.
function B.BankOpened()
	if not B.On() then
		return
	end
	Safely(Sync)
	if B.Opt("bank") ~= "game" and B.Opt("openWithBank") ~= false then
		B.Hold("bank", true)
	end
end

-- BagsBank ended the live bank: the bank hold goes (BagsBank drops it already when it ends the visit itself), and the bag window
-- closes when no game bag is open and nothing else holds it. BankFrame goes back, or under the hidden frame, once it is hidden: by the game, or
-- by BagsBank just before it ended the bank.
function B.BankClosed()
	if B.On() or next(parked) ~= nil then
		SoonSync()
	end
	holds.bank = nil
	if B.On() and bagsOpen and not AnyHold() and not B.GameBagsOpen() then
		B.HideBags()
	end
end

-- Standing down ------------------------------------------------------------------------------------------------------------------------------

local function OtherBags()
	if type(C_AddOns) ~= "table" or type(C_AddOns.IsAddOnLoaded) ~= "function" then
		return nil
	end
	for _, addon in ipairs(OTHER_BAGS) do
		if Ask(C_AddOns.IsAddOnLoaded, addon) == true then
			return addon
		end
	end
	return nil
end

local function Gamepad()
	local util = InputUtil
	if type(util) ~= "table" or IsSecret(util) or type(util.IsGamepadUIEnabled) ~= "function" then
		return false
	end
	return Ask(util.IsGamepadUIEnabled) == true
end

-- Whether a part the window cannot stand in for the game's bags without is missing: a file that did not load would leave no bags at all.
local function Missing()
	return type(B.Window.Get) ~= "function" or type(B.Window.Show) ~= "function" or type(B.Window.Hide) ~= "function"
		or type(B.Window.Update) ~= "function" or type(B.Buttons.Prepare) ~= "function"
end

-- Why Bags stays off now, and the addon when it is one.
local function Reason()
	if followed == false then
		return "follow"
	end
	if Missing() then
		return "missing"
	end
	local addon = OtherBags()
	if addon then
		return "addon", addon
	end
	if Gamepad() then
		return "gamepad"
	end
	return nil
end

-- Reads the reason again and says a new one in chat, once a session. True when it changed.
local function Judge()
	local was, wasAddon = down, downAddon
	down, downAddon = Reason()
	if down ~= nil and ns.Enabled(KEY) then
		local key = down == "addon" and ("addon:" .. tostring(downAddon)) or down
		if not said[key] then
			said[key] = true
			print(down == "addon" and DOWN_CHAT.addon:format(downAddon) or DOWN_CHAT[down])
		end
	end
	return down ~= was or downAddon ~= wasAddon
end

-- Bringing the page up and down ---------------------------------------------------------------------------------------------------------------

-- Escape hides both windows: their names go once into UISpecialFrames, as the options window's does (Panel.lua:2700-2708). The game walks
-- that list with securecall (UIParentPanelManager.lua:1106-1116, 1168), and a window that is not shown is passed over.
local function Special()
	local list = UISpecialFrames
	if type(list) ~= "table" or IsSecret(list) then
		return
	end
	for _, which in ipairs(WINDOWS) do
		local name, listed = NAMES[which], false
		for _, entry in ipairs(list) do
			listed = listed or entry == name
		end
		if not listed then
			table.insert(list, name)
		end
	end
end

-- The page stands in for the game's bags: the game's windows go under the hidden frame, the bag slots are made, and with fresh (the page has
-- just come up) a game bag that is open already opens the bag window beside it.
local function Up(fresh)
	up = true
	if fresh then
		-- MERCHANT_SHOW reached no handler while the page was off.
		B.atMerchant = Shown(Game("MerchantFrame"))
		Safely(Special)
	end
	Safely(Sync)
	Call("items", B.Buttons, "Prepare")
	if fresh and type(B.Bank.Settle) == "function" then
		-- Nor did the bank's opening and close: a visit that ended meanwhile ends now, and one under way begins. That comes after the bag slots
		-- are made, since a visit may open the bag window (BankOpened), and as BagsBank's own handlers do, it runs outside the bank part, whose
		-- steps each run as their own part.
		Safely(B.Bank.Settle)
	end
	if fresh and not bagsOpen and B.GameBagsOpen() then
		B.ShowBags("game")
	end
end

-- Off, stopped or standing down: both windows hide (HideWindow), the game's bag windows still open under the hidden frame hide, and every window
-- of the game that the game has closed goes back to its parent at once, also in a fight. A shown one goes back once the game closes it.
function Release()
	if releasing then
		return
	end
	releasing = true
	up = false
	burst, swapToken = nil, nil
	for which in pairs(sorting) do
		sorting[which] = nil
	end
	for _, which in ipairs(WINDOWS) do
		wants[which] = { flags = {} }
	end
	for reason in pairs(holds) do
		holds[reason] = nil
	end
	for _, which in ipairs(WINDOWS) do
		local frame = Frame(which, true)
		if Shown(frame) then
			HideWindow(which, frame)
		end
	end
	-- A window hidden with its parent ran no OnHide, so the steps of the close run here (and BagsWindow's own in Window.Hide).
	Safely(Tidy)
	-- A game bag window the game opened while the bag window was not open closes too, and its new flags go as its close would take them.
	-- With nothing closed the flags stay: another bag addon may show them.
	local ok, closed = pcall(HideParked)
	if ok and closed > 0 then
		pcall(ClearNew)
	end
	Safely(Sync)
	releasing = false
end

local function Start()
	started = true
	enabled = ns.Enabled(KEY) == true
	Safely(Follow)
	Judge()
	if B.On() then
		Up(true)
	else
		Release()
	end
end

-- Applies the rows: the page off, the module stopped (Core.lua:1932-1945) or standing down puts everything back; else the windows are laid out
-- again, for a change of Width in slots, Slot size, Show items, the look of the Windows page or a general setting. A page turned on again after
-- Start, also by a profile or after a stop, runs this and not Start (Core.lua:2278-2287, 2719-2733), and the module heard no event while it was
-- off: BagsData then does the work of its Start again (Data.Resume: the keyring test, the kinds of the bags, the bags in the bag slots, the worn
-- items and who the character is, then a full scan, and after it the quest marks and the set of every slot), also while Bags stands down, since
-- the record is kept then too.
local function Refresh()
	if not started then
		return
	end
	local on = ns.Enabled(KEY) == true
	local cameOn = on and not enabled
	enabled = on
	if not followed then
		Safely(Follow)
	end
	Judge()
	if cameOn then
		Call("cache", B.Data, "Resume")
	end
	if not B.On() then
		Release()
		return
	end
	Up(not up)
	B.Request("layout")
	B.Request("look")
	B.Request("footer")
end

-- The screen or the UI scale changed: the windows' height is capped by the screen's.
local function Resized()
	if B.On() then
		B.Request("layout")
	end
end

-- Another bag addon loaded, or the interface style changed.
local function Reconsider()
	if not Judge() then
		return
	end
	if B.On() then
		Up(true)
	else
		Release()
	end
end

-- Events -----------------------------------------------------------------------------------------------------------------------------------

local function ErrandsOn()
	local ok, on = pcall(ns.Enabled, "errands")
	return ok and on == true
end

local function OnBagClosed()
	swapAt = Now()
end

-- With Errands off, nothing else goes on with a Sell junk pass a fight paused (Errands does it itself while it is on).
local function OnRegenEnabled()
	if ErrandsOn() or not B.atMerchant then
		return
	end
	local selling, sell = ns.ErrandsSelling, ns.ErrandsSellJunk
	if type(selling) == "function" and type(sell) == "function" and Ask(selling) == true then
		pcall(sell)
	end
end

local function OnMerchantShow()
	B.atMerchant = true
	B.Request("footer", "bags")
end

-- The merchant closed: a Sell junk pass ends there, also with Errands off, whose own handler does the same and does no harm in either order.
local function OnMerchantClosed()
	B.atMerchant = false
	if type(ns.ErrandsMerchantClosed) == "function" then
		pcall(ns.ErrandsMerchantClosed)
	end
	B.Request("footer", "bags")
end

local function OnTradeShow()
	if B.On() and B.Opt("openWithTrade") ~= false then
		B.Hold("trade", true)
	end
end

local function OnTradeClosed()
	B.Hold("trade", false)
end

-- /flatui status ------------------------------------------------------------------------------------------------------------------------------

-- The characters BagsData keeps, each with a key, or an empty list.
local function Characters()
	local fn = B.Data.Characters
	if type(fn) ~= "function" then
		return {}
	end
	local ok, list = pcall(fn)
	if not ok or type(list) ~= "table" then
		return {}
	end
	local out = {}
	for _, entry in ipairs(list) do
		if type(entry) == "table" and type(entry.key) == "string" and not IsSecret(entry.key) then
			out[#out + 1] = entry
		end
	end
	return out
end

-- The lines of the page's own state. BagsData adds what it keeps ("Bags: 7 characters kept, 1,834 items; your bank as of 2 days ago." and the
-- warning above 40 characters) and BagsBank a Deposit or Take out that waits for the end of a fight, each with ns.AddStatus.
local function Status()
	local lines = {}
	if ns.Enabled(KEY) and down ~= nil then
		lines[1] = down == "addon" and DOWN_STATUS.addon:format(tostring(downAddon)) or DOWN_STATUS[down]
	end
	if not B.On() then
		-- Off, stopped or standing down: what the game still has open waits to go back.
		local left = 0
		for _ in pairs(parked) do
			left = left + 1
		end
		if left > 0 then
			lines[#lines + 1] = left == 1 and "Bags: 1 of the game's windows goes back once the game closes it."
				or ("Bags: %d of the game's windows go back once the game closes them."):format(left)
		end
		return lines
	end
	local kept, waiting = 0, 0
	for _, name in ipairs(GAME_BAGS) do
		local frame = Game(name)
		if frame and parked[frame] ~= nil and Under(frame) then
			kept = kept + 1
		elseif frame and Shown(frame) then
			waiting = waiting + 1
		end
	end
	local bank = Game(BANK_FRAME)
	local line = ("Bags: the game's bag windows are hidden (%d of %d)"):format(kept, #GAME_BAGS)
	if bank and parked[bank] ~= nil and Under(bank) then
		line = line .. ", and its bank window"
	end
	lines[#lines + 1] = line .. "."
	if waiting > 0 then
		lines[#lines + 1] = waiting == 1 and "Bags: 1 game bag window waits to be closed."
			or ("Bags: %d game bag windows wait to be closed."):format(waiting)
	end
	if bank and Wanted(BANK_FRAME) and parked[bank] == nil and Shown(bank) then
		lines[#lines + 1] = "Bags: the game's bank window waits to be closed."
	end
	if InCombat() and B.atMerchant and not ErrandsOn() and type(ns.ErrandsSelling) == "function" and Ask(ns.ErrandsSelling) == true then
		lines[#lines + 1] = "Bags: Sell junk waits for the end of the fight."
	end
	return lines
end

-- /flatui bags and /flatui bank ------------------------------------------------------------------------------------------------------------------

-- Why the words cannot act now, or nil.
local function Refusal()
	if not ns.Enabled(KEY) then
		return ns.IsStopped(KEY) and SAY.stopped or SAY.off
	end
	if down ~= nil then
		return nil, down == "addon" and DOWN_CHAT.addon:format(tostring(downAddon)) or DOWN_CHAT[down]
	end
	if not started then
		return SAY.starting
	end
	for _, part in ipairs(CRITICAL_ORDER) do
		if ns.PartStopped(KEY, part) then
			return SAY.part:format(part)
		end
	end
	return nil
end

-- Says why the words cannot act; true when they can.
local function Ready()
	local why, line = Refusal()
	if line then
		print(line)
		return false
	elseif why then
		print("Flat UI: " .. why)
		return false
	end
	return true
end

-- The key of a character Flat UI keeps, from what the player typed: "Name - Realm", "Name-Realm", or a name alone when one character has it,
-- or one of those of this realm and its connected realms. Says why not and gives nil otherwise.
local function Pick(text)
	local typed = Trim(text):lower()
	local loose = typed:gsub("%s", "")
	-- This character, also before BagsData has kept it.
	local me = B.Me()
	if type(me) == "string" and not IsSecret(me) then
		local mine = me:lower()
		if mine == typed or mine:gsub("%s", "") == loose or (mine:match("^(.-) %- ") or mine) == typed then
			return me
		end
	end
	local list = Characters()
	if #list == 0 then
		print("Flat UI: " .. SAY.none)
		return nil
	end
	for _, entry in ipairs(list) do
		local key = entry.key:lower()
		if key == typed or key:gsub("%s", "") == loose then
			return entry.key
		end
	end
	local named, near = {}, {}
	for _, entry in ipairs(list) do
		local name = type(entry.name) == "string" and not IsSecret(entry.name) and entry.name or entry.key:match("^(.-) %- ")
		if name and name:lower() == typed then
			named[#named + 1] = entry
			if entry.near == true or entry.me == true then
				near[#near + 1] = entry
			end
		end
	end
	if #named == 1 then
		return named[1].key
	elseif #near == 1 then
		return near[1].key
	elseif #named > 1 then
		local keys = {}
		for _, entry in ipairs(named) do
			keys[#keys + 1] = entry.key
		end
		print("Flat UI: " .. SAY.several:format(Trim(text), table.concat(keys, ", ")))
		return nil
	end
	local keys = {}
	for index, entry in ipairs(list) do
		if index > 12 then
			keys[#keys + 1] = "..."
			break
		end
		keys[#keys + 1] = entry.key
	end
	print("Flat UI: " .. SAY.unknown:format(Trim(text)) .. " " .. SAY.known:format(table.concat(keys, ", ")))
	return nil
end

-- /flatui bags: open or close the bag window with the command hold. /flatui bags Name: that character's bags in it.
local function SlashBags(rest)
	if not Ready() then
		return
	end
	local text = Trim(rest)
	local key
	if text ~= "" then
		key = Pick(text)
		if not key then
			return
		end
	elseif bagsOpen then
		B.HideBags()
		return
	end
	if not bagsOpen and not BagsAllowed() then
		print("Flat UI: " .. SAY.shut)
		return
	end
	if key then
		B.SetViewing("bags", key)
	end
	if not bagsOpen then
		B.Hold("command", true)
	end
end

-- /flatui bank: the bank window, live at the banker while At the banker is Flat UI's bank window, else the snapshot (also at the banker with the
-- game's bank window, which is the live one then). /flatui bank Name: that character's bank.
local function SlashBank(rest)
	if not Ready() then
		return
	end
	local text = Trim(rest)
	local key
	if text ~= "" then
		key = Pick(text)
		if not key then
			return
		end
		if key == B.Me() then
			key = nil
		end
	end
	if type(B.Bank.Toggle) ~= "function" then
		print("Flat UI: " .. SAY.noBank)
		return
	end
	Call("bank", B.Bank, "Toggle", key)
end

-- The module ---------------------------------------------------------------------------------------------------------------------------------

ns.Register(KEY, {
	label = "Bags",
	counted = false,
	Start = Start,
	Refresh = Refresh,
	Resized = Resized,
	Status = Status,
	slash = { bags = SlashBags, bank = SlashBank },
	help = HELP,
})

-- The events of this file, in the order of the table of owners. Those that open or close the window run as the follow part, so one that
-- keeps failing stops alone and gives the game's windows back. Those of the merchant and the end of a fight run whatever the parts, since
-- a Sell junk pass has to end at the merchant's close and go on after a fight even then.
local function Hear(event, fn, filter)
	ns.AddEvent(KEY, event, function(...)
		B.Part("follow", fn, ...)
	end, filter)
end

local function HearAlways(event, fn)
	ns.AddEvent(KEY, event, function(...)
		Safely(fn, ...)
	end)
end

Hear("BAG_CLOSED", OnBagClosed)
HearAlways("PLAYER_REGEN_ENABLED", OnRegenEnabled)
HearAlways("MERCHANT_SHOW", OnMerchantShow)
HearAlways("MERCHANT_CLOSED", OnMerchantClosed)
Hear("TRADE_SHOW", OnTradeShow)
Hear("TRADE_CLOSED", OnTradeClosed)
Hear("ADDON_LOADED", Reconsider, function(name)
	return not IsSecret(name) and type(name) == "string" and OTHER[name] == true
end)
Hear("INPUT_DEVICE_INTERFACE_TRANSITION", Reconsider)

-- ItemMarks' handlers clear its answers while the page is on, whatever the switch of Windows; its watcher and BagSort's tell the windows, and so
-- does Errands' when its sell or keep list changes (/flatui sell, /flatui keep, its list rows), since the junk coin and Sell junk read them.
local marks, sorter = ns.ItemMarks, ns.BagSort
if type(marks) == "table" and type(marks.Hear) == "function" then
	Safely(marks.Hear, KEY)
end
if type(marks) == "table" and type(marks.Watch) == "function" then
	Safely(marks.Watch, function()
		B.Request("items")
	end)
end
if type(sorter) == "table" and type(sorter.Watch) == "function" then
	Safely(sorter.Watch, function(which)
		B.Sorted(which)
	end)
end
if type(ns.ErrandsListsWatch) == "function" then
	Safely(ns.ErrandsListsWatch, function()
		B.Request("items")
		B.Request("footer", "bags")
	end)
end
