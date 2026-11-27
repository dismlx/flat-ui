local _, ns = ...

local KEY = "bags"
local GAME_BAGS = { "ContainerFrameCombinedBags", "ContainerFrame1", "ContainerFrame2", "ContainerFrame3", "ContainerFrame4", "ContainerFrame5",
	"ContainerFrame6", "ContainerFrame7" }
local BANK_FRAME = "BankFrame"
local KEPT = {}
for _, name in ipairs(GAME_BAGS) do
	KEPT[#KEPT + 1] = name
end
KEPT[#KEPT + 1] = BANK_FRAME
local OTHER_BAGS = { "Bagnon", "Baganator", "AdiBags", "BetterBags", "ArkInventory", "Combuctor", "LiteBag", "Inventorian", "Bagshui", "Sorted" }
local OTHER = {}
for _, name in ipairs(OTHER_BAGS) do
	OTHER[name] = true
end
local FOLLOW = {
	{ "ToggleBackpack", "toggled" }, { "ToggleBag", "toggled", "bag" }, { "ToggleAllBags", "toggled" },
	{ "OpenAllBags", "opened" }, { "OpenAllBagsMatchingContext", "opened" }, { "OpenBag", "opened" }, { "OpenBackpack", "opened" },
	{ "CloseAllBags", "closed" }, { "CloseBag", "closed" }, { "CloseBackpack", "closed" },
}
local BAG_BAR = { MainMenuBarBackpackButton = 0, CharacterBag0Slot = 1, CharacterBag1Slot = 2, CharacterBag2Slot = 3, CharacterBag3Slot = 4,
	CharacterReagentBag0Slot = 5, KeyRingButton = -1 }
local WINDOWS = { "bags", "bank" }
local NAMES = { bags = "FlatUIBags", bank = "FlatUIBank" }
local FLAGS = { items = true, layout = true, search = true, footer = true, look = true }
local HOLDS = { bank = true, trade = true, command = true }
local CRITICAL = { follow = true, cache = true, window = true, layout = true, items = true }
local CRITICAL_ORDER = { "follow", "cache", "window", "layout", "items" }
local SWAP_WAIT = 0.5
local SORT_QUIET, SORT_NONE, SORT_CAP = 0.4, 1.5, 6
local SORT_PINS = 11
local MOST_SLOTS = 200
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
local DOWN_CHAT = {
	follow = "Flat UI: Bags stays off: the game's bag functions could not be followed, so the game's bags are used.",
	missing = "Flat UI: Bags stays off: a file of its window did not load, so the game's bags are used.",
	gamepad = "Flat UI: Bags stays off under the gamepad interface, where the game's bags are used.",
	addon = "Flat UI: Bags stays off while %s is loaded.",
}
local ON_PURPOSE = { addon = true, gamepad = true }
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

local function IsSecret(value)
	return ns.IsSecret(value)
end

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
	Order = {},
	Pins = {},
	Slots = {},
	Currency = {},
	Custom = {},
	atMerchant = false,
}
ns.Bags = B

local started, up, followed, down, downAddon = false, false, nil, nil, nil
local enabled = false
local said = {}
local parked = setmetatable({}, { __mode = "k" })
local hidden
local bagsOpen = false
local holds = {}
local burst, swapAt, swapToken
local barHooked = {}
local wants = { bags = { flags = {} }, bank = { flags = {} } }
local passQueued = false
local sorting = {}
local viewing = {}
local windows = {}
local sentinels = setmetatable({}, { __mode = "k" })
local syncQueued, syncAfterFight, releasing = false, false, false
local reported = {}
local handlers

local Release, Tidy, Queue, Sync, SoonSync

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

local function Shown(frame)
	if type(frame) ~= "table" or IsSecret(frame) or type(frame.IsShown) ~= "function" then
		return false
	end
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and not IsSecret(shown) and shown == true
end

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

function B.Opt(key)
	return ns.Get(KEY .. "." .. key)
end

function B.Look(key)
	return ns.Get("windows." .. key)
end

function B.Me()
	return ns.CharacterKey()
end

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

local function Call(part, tbl, name, ...)
	local fn = type(tbl) == "table" and tbl[name]
	if type(fn) ~= "function" then
		return false
	end
	return (B.Part(part, fn, ...))
end

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

function Sync()
	local fight, later = InCombat(), false
	for _, name in ipairs(KEPT) do
		local frame = Game(name)
		if frame then
			if parked[frame] ~= nil and not Under(frame) then
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

function ns.BagsParked(frame)
	if type(frame) ~= "table" or IsSecret(frame) or parked[frame] == nil then
		return false
	end
	return Under(frame)
end

function B.GameBagsOpen()
	for _, name in ipairs(GAME_BAGS) do
		if Shown(Game(name)) then
			return true
		end
	end
	return false
end

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

function B.HideGameBags()
	HideParked()
	ClearNew()
end

function B.ClearNew()
	if B.On() then
		B.Part("follow", ClearNew)
	end
end

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

local function Open(which, quiet)
	if not Shown(Frame(which, quiet)) then
		return false
	end
	return which ~= "bags" or bagsOpen
end

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

function B.LaidOut(which)
	local want = wants[which]
	if want == nil then
		return
	end
	local flags = want.flags
	flags.items, flags.layout, flags.search, flags.footer = nil, nil, nil, nil
	want.changed, want.all = nil, nil
end

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
		wants[which].flags.layout = true
		Queue()
	else
		B.Request("layout", which)
	end
	B.Request("footer", which)
end

local function AnyHold()
	return next(holds) ~= nil
end

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

function B.HideBags()
	local frame = Frame("bags", true)
	if Shown(frame) then
		HideWindow("bags", frame)
	end
	if bagsOpen and not Shown(frame) then
		Tidy()
	end
end

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

local function Recheck()
	if B.On() and bagsOpen and not AnyHold() and not B.GameBagsOpen() then
		B.HideBags()
	end
end

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

local function PanelHidden(frame)
	if type(frame) ~= "table" or IsSecret(frame) or not rawequal(frame, _G[BANK_FRAME]) then
		return
	end
	if B.On() or next(parked) ~= nil then
		SoonSync()
	end
end

local function Reparented()
	if B.On() or next(parked) ~= nil then
		SoonSync()
	end
end

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

local function EndHold(which, hold)
	if sorting[which] == hold then
		sorting[which] = nil
		B.Request("layout", which)
	end
end

local function HandOver(which, hold)
	if which ~= "bags" or hold.handed then
		return false
	end
	hold.handed = true
	local pins = B.Pins
	local after = type(pins) == "table" and pins.AfterSort or nil
	if type(after) ~= "function" then
		return false
	end
	local ok, waits = pcall(after, function()
		EndHold(which, hold)
	end, hold)
	if not (ok and waits == true) then
		return false
	end
	if not After(SORT_PINS, function()
		EndHold(which, hold)
	end) then
		return false
	end
	return true
end

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
	if HandOver(which, hold) then
		return
	end
	EndHold(which, hold)
end

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

function B.Sorting(which)
	return sorting[which] ~= nil
end

function B.SortHold(which)
	return sorting[which]
end

function B.BankOpened()
	if not B.On() then
		return
	end
	Safely(Sync)
	if B.Opt("bank") ~= "game" and B.Opt("openWithBank") ~= false then
		B.Hold("bank", true)
	end
end

function B.BankClosed()
	if B.On() or next(parked) ~= nil then
		SoonSync()
	end
	holds.bank = nil
	if B.On() and bagsOpen and not AnyHold() and not B.GameBagsOpen() then
		B.HideBags()
	end
end

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

local function Missing()
	return type(B.Window.Get) ~= "function" or type(B.Window.Show) ~= "function" or type(B.Window.Hide) ~= "function"
		or type(B.Window.Update) ~= "function" or type(B.Buttons.Prepare) ~= "function"
end

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

local function Judge()
	local was, wasAddon = down, downAddon
	down, downAddon = Reason()
	if down ~= nil and ns.Enabled(KEY) and (not ON_PURPOSE[down] or ns.IsSet(KEY .. ".enabled")) then
		local key = down == "addon" and ("addon:" .. tostring(downAddon)) or down
		if not said[key] then
			said[key] = true
			print(down == "addon" and DOWN_CHAT.addon:format(downAddon) or DOWN_CHAT[down])
		end
	end
	return down ~= was or downAddon ~= wasAddon
end

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

local function BagBarHooks()
	for name, bag in pairs(BAG_BAR) do
		local button = Game(name)
		if button and not barHooked[button] and type(button.HookScript) == "function" then
			local okEnter = pcall(button.HookScript, button, "OnEnter", function()
				if B.On() then
					Call("layout", B.Layout, "Light", "bags", bag)
				end
			end)
			local okLeave = pcall(button.HookScript, button, "OnLeave", function()
				if B.On() then
					Call("layout", B.Layout, "Light", "bags", nil)
				end
			end)
			barHooked[button] = okEnter or okLeave
		end
	end
end

local function Up(fresh)
	up = true
	if fresh then
		B.atMerchant = Shown(Game("MerchantFrame"))
		Safely(Special)
		Safely(BagBarHooks)
	end
	Safely(Sync)
	Call("items", B.Buttons, "Prepare")
	if fresh and type(B.Bank.Settle) == "function" then
		Safely(B.Bank.Settle)
	end
	if fresh and not bagsOpen and B.GameBagsOpen() then
		B.ShowBags("game")
	end
end

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
	Safely(Tidy)
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
	Safely(BagBarHooks)
	Judge()
	if B.On() then
		Up(true)
	else
		Release()
	end
end

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

local function Resized()
	if B.On() then
		B.Request("layout")
	end
end

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

local function ErrandsOn()
	local ok, on = pcall(ns.Enabled, "errands")
	return ok and on == true
end

local function OnBagClosed()
	swapAt = Now()
end

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

local function Status()
	local lines = {}
	if ns.Enabled(KEY) and down ~= nil then
		lines[1] = down == "addon" and DOWN_STATUS.addon:format(tostring(downAddon)) or DOWN_STATUS[down]
	end
	if not B.On() then
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

local function Pick(text)
	local typed = Trim(text):lower()
	local loose = typed:gsub("%s", "")
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

function ns.BagsToggle()
	SlashBags("")
end

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
