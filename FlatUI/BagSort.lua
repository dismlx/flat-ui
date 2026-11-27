local _, ns = ...

local KEY = "windows"
local PART = "clean up bags"
local CONFIRM_VAR, POPUP = "bankConfirmTabCleanUp", "FLATUI_BANK_CLEANUP"
local ASKS = {
	bank = { "BANK_CONFIRM_CLEANUP_PROMPT", "Are you sure you want to automatically sort your items?|nThis will affect all tabs." },
	account = { "ACCOUNT_BANK_CONFIRM_CLEANUP_PROMPT", "Are you sure you want to automatically sort your items?|nThis will affect all Account tabs." },
}

local NAMES = { "ContainerFrameCombinedBags", "ContainerFrame1", "ContainerFrame2", "ContainerFrame3", "ContainerFrame4", "ContainerFrame5",
	"ContainerFrame6", "ContainerFrame7" }
local BANK = "BankFrame"

local SIZE = 16
local ABOVE = 3
local BARS = { 10, 7, 4 }
local BAR_HEIGHT, BAR_GAP, BAR_LEFT = 2, 2, 3
local PLACES = {
	title = { "TOPRIGHT", "TOPRIGHT", -30, -3, "ANCHOR_TOP" },
	slots = { "TOP", "BOTTOM", 0, -2, "ANCHOR_BOTTOM" },
}
local BANK_PLACES = {
	title = PLACES.title,
	slots = { "BOTTOMLEFT", "BOTTOMLEFT", 10, 6, "ANCHOR_TOP" },
}
local BANK_TYPES = { Character = 0, Account = 2 }

local TIPS = {
	bags = { "BAG_CLEANUP_BAGS", "Clean Up Bags" },
	bank = { "BAG_CLEANUP_BANK", "Clean Up Bank" },
	account = { "BAG_CLEANUP_ACCOUNT_BANK", "Clean Up Account Bank" },
}
local SAY = {
	cursor = "Put down the item on your cursor, then try again.",
	closed = "The bank is not open.",
	tabs = "This bank has no bags to clean up.",
	kind = "Open the bank or the account bank to clean it up.",
	missing = "This client cannot clean up bags.",
}
local NOTE = "Windows: Items gather has no effect. The game has no sort direction here."
local HELP = {
	"/flatui sort - clean up your bags",
	"/flatui sort bank - clean up the bank that is open",
}

local made = {}
local queued, watching, pending = false, false, false

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Usable(value)
	return value ~= nil and not ns.IsSecret(value) and type(value) == "table"
end

local function Game(name)
	local frame = _G[name]
	if Usable(frame) and not ns.Forbidden(frame) then
		return frame
	end
	return nil
end

local function Shown(frame)
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and not ns.IsSecret(shown) and shown == true
end

local function Chosen()
	if not ns.Enabled(KEY) then
		return nil
	end
	local place = Opt("sortButton")
	return PLACES[place] and place or nil
end

local function Wants(bank)
	return Chosen() ~= nil and (not bank or Opt("sortBank") == true)
end

local function Calls()
	return type(C_Container) == "table" and type(C_Container.GetSortBagsRightToLeft) == "function"
		and type(C_Container.SetSortBagsRightToLeft) == "function"
end

local function Read()
	if not Calls() then
		return nil
	end
	local ok, value = pcall(C_Container.GetSortBagsRightToLeft)
	if ok and not ns.IsSecret(value) and type(value) == "boolean" then
		return value
	end
	return nil
end

local function Write(value)
	pcall(C_Container.SetSortBagsRightToLeft, value)
	return Read()
end

local function Wanted()
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and Opt("sortFrom") == "other"
end

local function Record()
	local saved = ns.Character()
	if saved == nil then
		return nil
	end
	local rec = saved.sortDirection
	if rec ~= nil and (type(rec) ~= "table" or type(rec.game) ~= "boolean" or (rec.wrote ~= nil and type(rec.wrote) ~= "boolean")) then
		saved.sortDirection = nil
		rec = nil
	end
	return rec
end

local function Direction()
	if Wanted() and not Calls() then
		ns.Note(KEY, NOTE)
	else
		ns.ClearNote(KEY, NOTE)
	end
	local saved = ns.Character()
	local current = Read()
	if saved == nil or current == nil then
		return
	end
	local rec = Record()
	if Wanted() then
		if rec == nil then
			rec = { game = current }
			saved.sortDirection = rec
		elseif current ~= rec.wrote then
			rec.game = current
		end
		local want = not rec.game
		if current ~= want then
			current = Write(want)
		end
		if current == want then
			rec.wrote = want
		else
			rec.wrote = nil
		end
	elseif rec then
		if rec.wrote ~= nil and current == rec.wrote and current ~= rec.game then
			Write(rec.game)
		end
		saved.sortDirection = nil
	end
end

local function Logout()
	local rec = Record()
	if rec and rec.wrote ~= nil and rec.wrote ~= rec.game and Read() == rec.wrote then
		Write(rec.game)
	end
end

local function Say(text)
	print(text)
	return false
end

local sortWatchers = {}

local function Sorted(which)
	for _, fn in ipairs(sortWatchers) do
		pcall(fn, which)
	end
end

local function AddWatcher(fn)
	if type(fn) ~= "function" then
		return false
	end
	for _, known in ipairs(sortWatchers) do
		if known == fn then
			return true
		end
	end
	sortWatchers[#sortWatchers + 1] = fn
	return true
end

local function Holding()
	if type(CursorHasItem) ~= "function" then
		return false
	end
	local ok, held = pcall(CursorHasItem)
	return ok and not ns.IsSecret(held) and held == true
end

local function BankKind()
	local bank = Game(BANK)
	local panel = bank and bank.BankPanel
	local kind = Usable(panel) and not ns.Forbidden(panel) and Shown(panel) and panel.bankType
	if ns.IsSecret(kind) or type(kind) ~= "number" then
		return nil
	end
	local types = type(Enum) == "table" and not ns.IsSecret(Enum) and type(Enum.BankType) == "table" and Enum.BankType or BANK_TYPES
	if kind == types.Character or kind == types.Account then
		return kind, kind == types.Account
	end
	return nil
end

local function Tabs(kind)
	if type(C_Bank) ~= "table" or type(C_Bank.FetchNumPurchasedBankTabs) ~= "function" then
		return nil
	end
	local ok, count = pcall(C_Bank.FetchNumPurchasedBankTabs, kind)
	if ok and not ns.IsSecret(count) and type(count) == "number" then
		return count
	end
	return nil
end

local function Word(name, fallback)
	local text = _G[name]
	if type(text) == "string" and not ns.IsSecret(text) and text ~= "" then
		return text
	end
	return fallback
end

local Register
local function Ask(kind, account)
	if type(C_CVar) ~= "table" or type(C_CVar.GetCVarBool) ~= "function" or type(StaticPopupDialogs) ~= "table"
		or ns.IsSecret(StaticPopupDialogs) or type(StaticPopup_Show) ~= "function" then
		return false
	end
	local ok, on = pcall(C_CVar.GetCVarBool, CONFIRM_VAR)
	if not ok or ns.IsSecret(on) or not on then
		return false
	end
	if not Register() then
		return false
	end
	local ask = account and ASKS.account or ASKS.bank
	local shown, popup = pcall(StaticPopup_Show, POPUP, Word(ask[1], ask[2]), nil, kind)
	return shown and popup ~= nil and popup ~= false
end

local function Sound()
	if type(PlaySound) ~= "function" or type(SOUNDKIT) ~= "table" or ns.IsSecret(SOUNDKIT) then
		return
	end
	local id = SOUNDKIT.UI_BAG_SORTING_01
	if type(id) == "number" and not ns.IsSecret(id) then
		pcall(PlaySound, id)
	end
end

local function Run(which)
	if Holding() then
		return Say(SAY.cursor)
	end
	local call = which == "bank" and "SortBank" or "SortBags"
	if type(C_Container) ~= "table" or type(C_Container[call]) ~= "function" then
		return Say(SAY.missing)
	end
	local kind, account
	if which == "bank" then
		kind, account = BankKind()
		if not kind then
			return Say(SAY.kind)
		end
		local count = Tabs(kind)
		if count ~= nil and count < 1 then
			return Say(SAY.tabs)
		end
	end
	if Wanted() then
		Direction()
	end
	if which == "bank" then
		if not Ask(kind, account) then
			C_Container.SortBank(kind)
			Sorted("bank")
		end
	else
		C_Container.SortBags()
		Sorted("bags")
	end
	return true
end

local function Away(entry)
	entry.button:Hide()
	if not entry.broken then
		ns.SetOutline(entry.outline, false, false)
		entry.hover:Hide()
		for _, bar in ipairs(entry.bars) do
			bar:Hide()
		end
	end
end

local function Release()
	for _, entry in pairs(made) do
		pcall(Away, entry)
	end
	pcall(Direction)
end

local function Guard(fn, ...)
	if not ns.EachPart(KEY, PART, fn, ...) and ns.PartStopped(KEY, PART) then
		Release()
	end
end

function Register()
	local list = StaticPopupDialogs
	if type(list) ~= "table" or ns.IsSecret(list) then
		return false
	end
	if list[POPUP] == nil then
		list[POPUP] = {
			text = "%s",
			button1 = Word("ACCEPT", "Accept"),
			button2 = Word("CANCEL", "Cancel"),
			timeout = 0,
			whileDead = false,
			hideOnEscape = true,
			OnAccept = function(_, kind)
				Guard(function()
					if not Shown(Game(BANK) or {}) or BankKind() ~= kind then
						Say(SAY.closed)
						return
					end
					C_Container.SortBank(kind)
					Sorted("bank")
				end)
			end,
		}
	end
	return true
end

local function Click(entry)
	if Run(entry.bank and "bank" or "bags") then
		Sound()
	end
end

local function Over(button)
	local ok, over = pcall(button.IsMouseOver, button)
	return not ok or ns.IsSecret(over) or over ~= false
end

local function Tip(which)
	return Word(TIPS[which][1], TIPS[which][2])
end

local function Entering(entry)
	entry.hover:Show()
	if ns.Forbidden(GameTooltip) then
		return
	end
	local account = false
	if entry.bank then
		local _, isAccount = BankKind()
		account = isAccount == true
	end
	GameTooltip:SetOwner(entry.button, entry.anchor)
	GameTooltip:SetText(Tip(entry.bank and (account and "account" or "bank") or "bags"))
	GameTooltip:Show()
end

local function Leaving(entry, closed)
	entry.hover:Hide()
	if ns.Forbidden(GameTooltip) then
		return
	end
	if closed then
		local ok, owned = pcall(GameTooltip.IsOwned, GameTooltip, entry.button)
		if not (ok and owned == true) then
			return
		end
	end
	GameTooltip:Hide()
end

local function Paint(entry)
	local r, g, b = ns.Colour(KEY .. ".panel")
	ns.SetOutlineFill(entry.outline, r, g, b, 1)
	ns.SetOutline(entry.outline, true, true)
	r, g, b = ns.Colour(KEY .. ".accent")
	for _, bar in ipairs(entry.bars) do
		bar:SetColorTexture(r, g, b, 0.9)
		bar:Show()
	end
	entry.hover:SetColorTexture(r, g, b, 0.25)
end

local function Level(entry, frame)
	local ok, level = pcall(frame.GetFrameLevel, frame)
	if ok and not ns.IsSecret(level) and type(level) == "number" then
		level = math.min(level + ABOVE, 10000)
		entry.button:SetFrameLevel(level)
		if entry.outline and entry.outline.holder then
			entry.outline.holder:SetFrameLevel(math.min(level + 1, 10000))
		end
	end
end

local function Build(entry, frame)
	local button = entry.button
	button:SetSize(SIZE, SIZE)
	button:EnableMouse(true)
	Level(entry, frame)
	entry.outline = ns.Outline(button, button)
	if not entry.outline then
		error("no outline", 0)
	end
	entry.hover = button:CreateTexture(nil, "OVERLAY", nil, 1)
	ns.Own[entry.hover] = true
	entry.hover:SetAllPoints(button)
	entry.hover:Hide()
	local top = math.floor((SIZE - (#BARS * BAR_HEIGHT + (#BARS - 1) * BAR_GAP)) / 2)
	for index, width in ipairs(BARS) do
		local bar = button:CreateTexture(nil, "OVERLAY", nil, 2)
		ns.Own[bar] = true
		bar:SetSize(width, BAR_HEIGHT)
		bar:SetPoint("TOPLEFT", button, "TOPLEFT", BAR_LEFT, -(top + (index - 1) * (BAR_HEIGHT + BAR_GAP)))
		entry.bars[index] = bar
	end
	button:SetScript("OnMouseDown", function(_, mouse)
		entry.down = mouse == "LeftButton"
	end)
	button:SetScript("OnMouseUp", function(_, mouse)
		local wanted = entry.down and mouse == "LeftButton"
		entry.down = false
		if wanted and Over(button) then
			Guard(Click, entry)
		end
	end)
	button:SetScript("OnEnter", function()
		Guard(Entering, entry)
	end)
	button:SetScript("OnLeave", function()
		Guard(Leaving, entry, false)
	end)
	button:SetScript("OnHide", function()
		Guard(Leaving, entry, true)
	end)
end

local function Make(name, frame, bank)
	local button = CreateFrame("Frame", nil, frame)
	ns.Own[button] = true
	local entry = { button = button, bank = bank, bars = {}, down = false }
	made[name] = entry
	local ok, err = pcall(Build, entry, frame)
	if not ok then
		entry.broken = true
		pcall(button.Hide, button)
		error(err, 0)
	end
	return entry
end

local function Gamepad()
	if type(InputUtil) ~= "table" or ns.IsSecret(InputUtil) or type(InputUtil.IsGamepadUIEnabled) ~= "function" then
		return false
	end
	local ok, on = pcall(InputUtil.IsGamepadUIEnabled)
	return ok and not ns.IsSecret(on) and on == true
end

local function Stacked(frame)
	local ok, point, other, relative = pcall(frame.GetPoint, frame, 1)
	if not ok or ns.IsSecret(point) or ns.IsSecret(other) or ns.IsSecret(relative) then
		return true
	end
	if point == nil or other == nil or type(relative) ~= "string" or not relative:find("^TOP") then
		return false
	end
	for _, name in ipairs(NAMES) do
		if rawequal(other, _G[name]) then
			return true
		end
	end
	return false
end

local function Fits(frame, bank)
	if Gamepad() then
		return false
	end
	return bank or Chosen() ~= "slots" or not Stacked(frame)
end

local function Arrange(name, bank)
	local frame = Game(name)
	if not frame then
		return
	end
	local entry = made[name]
	if not Wants(bank) or not Fits(frame, bank) then
		if entry and not entry.broken then
			Away(entry)
		end
		return
	end
	if entry and entry.broken then
		return
	end
	entry = entry or Make(name, frame, bank)
	local place = Chosen()
	if entry.place ~= place then
		local spec = (bank and BANK_PLACES or PLACES)[place]
		entry.button:ClearAllPoints()
		entry.button:SetPoint(spec[1], frame, spec[2], spec[3], spec[4])
		entry.anchor, entry.place = spec[5], place
	end
	Level(entry, frame)
	Paint(entry)
	entry.button:Show()
end

local function Place()
	for _, name in ipairs(NAMES) do
		Guard(Arrange, name, false)
	end
	Guard(Arrange, BANK, true)
end

local function Pass()
	Place()
	Guard(Direction)
end

local function Lay(full)
	if not InCombatLockdown() then
		if full then
			Pass()
		else
			Place()
		end
		return
	end
	for name, entry in pairs(made) do
		local frame = Game(name)
		if not entry.broken and (not Wants(entry.bank) or (frame ~= nil and not Fits(frame, entry.bank))) then
			pcall(Away, entry)
		end
	end
	if not queued then
		queued = true
		ns.OutOfCombat(function()
			queued = false
			Pass()
		end)
	end
end

local function Later()
	if pending then
		return
	end
	pending = true
	local function run()
		pending = false
		if Chosen() == "slots" then
			pcall(Lay, false)
		end
	end
	if not (type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, 0, run)) then
		run()
	end
end

local function Watch()
	if watching or Chosen() ~= "slots" or type(hooksecurefunc) ~= "function" or type(UpdateContainerFrameAnchors) ~= "function" then
		return
	end
	watching = pcall(hooksecurefunc, "UpdateContainerFrameAnchors", Later)
end

local function Apply()
	Watch()
	Lay(true)
end

local function Command(rest)
	local word = (rest or ""):lower()
	if word == "" then
		Run("bags")
	elseif word == "bank" then
		local bank = Game(BANK)
		if bank and Shown(bank) then
			Run("bank")
		else
			Say(SAY.closed)
		end
	else
		for _, line in ipairs(HELP) do
			print(line)
		end
	end
end

ns.BagSort = { Apply = Apply, Logout = Logout, Command = Command, help = HELP, Run = Run, Sound = Sound, Watch = AddWatcher }

do
	local name = "FlatUIBagSortButton"
	_G["BINDING_NAME_CLICK " .. name .. ":LeftButton"] = "Flat UI bags: clean up"
	local function BagsOn()
		local bags = ns.Bags
		local on = type(bags) == "table" and bags.On or nil
		if type(on) ~= "function" then
			return false
		end
		local okOn, yes = pcall(on)
		return okOn and yes == true
	end
	local function Busy()
		local bags = ns.Bags
		if type(bags) ~= "table" then
			return false
		end
		local window = bags.Window
		for _, fn in ipairs({ type(window) == "table" and window.Sorting or false, bags.Sorting or false }) do
			if type(fn) == "function" then
				local okBusy, busy = pcall(fn, "bags")
				if okBusy and busy == true then
					return true
				end
			end
		end
		return false
	end
	local ok, button = pcall(CreateFrame, "Button", name, UIParent)
	if ok and type(button) == "table" then
		ns.Own[button] = true
		pcall(button.RegisterForClicks, button, "LeftButtonUp")
		button:SetScript("OnClick", function()
			local okRun, err = pcall(function()
				if not ns.Enabled(KEY) and not BagsOn() then
					print("Flat UI: the clean up key works while the Windows page (Restyle windows) or Flat UI bags is on.")
				elseif Busy() then
					print("Flat UI: your bags are still being cleaned up.")
				elseif Run("bags") then
					Sound()
				end
			end)
			if not okRun then
				geterrorhandler()(err)
			end
		end)
	end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
pcall(watcher.RegisterEvent, watcher, "INPUT_DEVICE_INTERFACE_TRANSITION")
watcher:SetScript("OnEvent", function(_, event)
	if event == "INPUT_DEVICE_INTERFACE_TRANSITION" then
		if ns.Character() then
			pcall(Lay, false)
		end
	elseif ns.Character() and not ns.Enabled(KEY) then
		pcall(Direction)
	end
end)
pcall(Register)
