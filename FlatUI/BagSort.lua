local _, ns = ...

-- Clean up bags. A small flat button of this addon's own lies on each bag window and on the bank, and /flatui sort does the same
-- job from the keyboard. Both call the game's sort: C_Container.SortBags for the bags and C_Container.SortBank for the bank that is
-- shown, which sorts every tab of that bank (BANK_CONFIRM_CLEANUP_PROMPT, GlobalStrings enUS.lua:1512). ContainerDocumentation.lua
-- lists neither call with a restriction, and the game's own buttons sort with no check for combat (ContainerFrame.xml:355-358,
-- BankFrameTemplates.lua:1857-1876), so this part has none either. The game has a clean up button of its own on the backpack, the
-- combined bag and the bank (ContainerFrame.xml:345-368, BankFrameTemplates.xml:617-621); this one lies beside it and leaves it as it
-- is. The game hides its button only under the gamepad interface (ContainerFrame.lua:1132-1141), and no button of this addon is made
-- then. The button is a frame of this addon's, made out of combat on the bag window it belongs to. The bank type is read from the field
-- BankPanel.bankType while the panel is shown, as BankFrame:GetActiveBankType does (BankFrameTemplates.lua:93-95).
-- A click plays the sound of the game's own clean up buttons (ContainerFrame.xml:357, BankFrameTemplates.lua:1858). The bank asks first
-- while the game's setting for that is on, as its own button does (BankFrameTemplates.lua:1871-1875, CVars.lua:101): with a popup of
-- this addon's own, an entry of StaticPopupDialogs shown with StaticPopup_Show (StaticPopup.lua:309-325), whose Accept sorts the bank.
-- No frame of the game's is written: StaticPopupSpecial_Show on the game's own bank popup would set a field on it that the game reads
-- whenever the bank closes (StaticPopup.lua:941-959, BankFrameTemplates.lua:746-753).
-- Items gather: C_Container.SetSortBagsRightToLeft sets the end the game's clean up fills the bags from (ContainerDocumentation.lua:364-371
-- and 512-519, which do not say whether the value is kept for the character or the account). From the other end writes the opposite of
-- the player's own value, remembered in the saved data of the character before the first write, and puts it back when the choice goes,
-- the page goes off, or the player logs out.
-- This is not a module: the windows module calls ns.BagSort.Apply whenever it applies its settings.

local KEY = "windows"
local PART = "clean up bags"
-- The game's question before a bank is cleaned up: the setting that turns it on, and the name of this addon's popup that asks.
local CONFIRM_VAR, POPUP = "bankConfirmTabCleanUp", "FLATUI_BANK_CLEANUP"
-- The words of the question, from the game's global strings (GlobalStrings enUS.lua:112 and 1512), in English when the client has none.
local ASKS = {
	bank = { "BANK_CONFIRM_CLEANUP_PROMPT", "Are you sure you want to automatically sort your items?|nThis will affect all tabs." },
	account = { "ACCOUNT_BANK_CONFIRM_CLEANUP_PROMPT", "Are you sure you want to automatically sort your items?|nThis will affect all Account tabs." },
}

local NAMES = { "ContainerFrameCombinedBags", "ContainerFrame1", "ContainerFrame2", "ContainerFrame3", "ContainerFrame4", "ContainerFrame5",
	"ContainerFrame6", "ContainerFrame7" }
local BANK = "BankFrame"

-- The button is a square. It lies this many levels above its window, over the title bar of the movers, which lies two above.
local SIZE = 16
local ABOVE = 3
-- The glyph: three bars, each shorter than the one above. Width of each, height, space between, and the left edge of the bars.
local BARS = { 10, 7, 4 }
local BAR_HEIGHT, BAR_GAP, BAR_LEFT = 2, 2, 3
-- Where the button lies: its point, the point of the window it hangs from, the offset, and the corner the tooltip opens from. The title
-- bar is 22 high and its close button is 28 from the right edge. A bag has no free room under its slots, so the button hangs just
-- below the window, and only below a bag with no other bag under it (Stacked). The bank has a strip there, so its button lies inside.
local PLACES = {
	title = { "TOPRIGHT", "TOPRIGHT", -30, -3, "ANCHOR_TOP" },
	slots = { "TOP", "BOTTOM", 0, -2, "ANCHOR_BOTTOM" },
}
local BANK_PLACES = {
	title = PLACES.title,
	slots = { "BOTTOMLEFT", "BOTTOMLEFT", 10, 6, "ANCHOR_TOP" },
}
-- Enum.BankType, for a client that has no enumeration (LuaEnum.lua:609-613).
local BANK_TYPES = { Character = 0, Account = 2 }

-- The tooltips are the game's own words for the action, from its global strings (GlobalStrings enUS.lua:1472-1475), in English when the
-- client has none.
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

-- What was made, by the name of the window: { button, bank, place, anchor, outline, hover, bars, down, broken }.
local made = {}
-- True while a pass that waits for the end of combat is queued, while the game's layout of the bags is followed, and while a pass
-- after one of its layouts is waiting for the next frame.
local queued, watching, pending = false, false, false

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Usable(value)
	return value ~= nil and not ns.IsSecret(value) and type(value) == "table"
end

-- A bag window or the bank, unless it is missing or forbidden.
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

-- The place chosen for the button, or nil when there is none: the page is off or the choice is None. A part that has stopped has hidden
-- its buttons and is not asked again.
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

-- Items gather ----------------------------------------------------------------------------------------------------

local function Calls()
	return type(C_Container) == "table" and type(C_Container.GetSortBagsRightToLeft) == "function"
		and type(C_Container.SetSortBagsRightToLeft) == "function"
end

-- The game's direction, or nil when the client has none or does not say.
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

-- Writes the direction and gives back what the game says now.
local function Write(value)
	pcall(C_Container.SetSortBagsRightToLeft, value)
	return Read()
end

local function Wanted()
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and Opt("sortFrom") == "other"
end

-- The record of the player's own value: { game = the value to put back, wrote = the value this addon last wrote }. It is kept for the
-- character, whatever profile it uses: the source does not say whether the game keeps the direction for the character or for the
-- account, and a record for the character is right in both cases.
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

-- Brings the game's direction to what the settings say. From the other end writes the opposite of the player's own value. A value
-- that is not the one last written was set by the player since, and becomes the player's own. Anything else puts the record's
-- value back, once, and forgets the record.
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

-- At logout the value goes back and the record stays: the next login writes the wanted value again.
local function Logout()
	local rec = Record()
	if rec and rec.wrote ~= nil and rec.wrote ~= rec.game and Read() == rec.wrote then
		Write(rec.game)
	end
end

-- Sorting ------------------------------------------------------------------------------------------------------------

local function Say(text)
	print(text)
	return false
end

local function Holding()
	if type(CursorHasItem) ~= "function" then
		return false
	end
	local ok, held = pcall(CursorHasItem)
	return ok and not ns.IsSecret(held) and held == true
end

-- The type of the bank that is shown, and whether it is the account bank. Nil when the bank does not say, and while its panel is not
-- shown, as the game's own BankFrame:GetActiveBankType does.
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

-- The number of tabs (bag slots on the bank of this client) bought for a bank type, or nil when the client does not say.
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

-- A word of the game's global strings, or the English one when the client has none.
local function Word(name, fallback)
	local text = _G[name]
	if type(text) == "string" and not ns.IsSecret(text) and text ~= "" then
		return text
	end
	return fallback
end

-- The popup that asks before a bank is cleaned up, shown when the game's setting for it is on. True when the popup is up. False when the
-- setting is off or unreadable, or the popup cannot be shown: the bank is sorted then. Its data is the type of the bank asked about.
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

-- The sound the game's own clean up buttons make.
local function Sound()
	if type(PlaySound) ~= "function" or type(SOUNDKIT) ~= "table" or ns.IsSecret(SOUNDKIT) then
		return
	end
	local id = SOUNDKIT.UI_BAG_SORTING_01
	if type(id) == "number" and not ns.IsSecret(id) then
		pcall(PlaySound, id)
	end
end

-- Sorts the bags, or the bank that is shown. Says why not in one line, and returns whether the game was asked.
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
		end
	else
		C_Container.SortBags()
	end
	return true
end

-- The button -------------------------------------------------------------------------------------------------------

-- Hides a button and what it drew, so that a button that has gone leaves nothing shown.
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

-- Hides every button, and puts the game's direction back.
local function Release()
	for _, entry in pairs(made) do
		pcall(Away, entry)
	end
	pcall(Direction)
end

-- Runs code of this part. An error stops the part after three windows have failed, and the buttons go.
local function Guard(fn, ...)
	if not ns.EachPart(KEY, PART, fn, ...) and ns.PartStopped(KEY, PART) then
		Release()
	end
end

-- Puts the popup in the game's list of them, once. The accept runs out of the popup's own hand: the bank must still be shown and still be
-- the one that was asked about, or it says so and sorts nothing.
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

-- Whether the cursor is over the button when it is let go: a press let go elsewhere is no click, as with a button of the game's. A client
-- that does not say counts as over.
local function Over(button)
	local ok, over = pcall(button.IsMouseOver, button)
	return not ok or ns.IsSecret(over) or over ~= false
end

-- The tooltip: the game's own words for the action.
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

-- The cursor left the button, or the window closed under it. A tooltip that belongs to something else stays when the window closes.
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

-- The colours follow the Windows page: the box is the button and slot colour, the bars and the lighter patch under the cursor are
-- the highlight colour, as on the buttons of the windows.
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

-- Puts the button over the title bar of the movers, whatever level the window has now.
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

-- Makes the button of a window. A button that fails on the way stays hidden and is not tried again.
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

-- Whether the game shows the interface made for a gamepad. Its own clean up button is hidden then and the action is in the menu of the
-- backpack (ContainerFrame.lua:735-742 and 1132-1136), and a button here could not be clicked.
local function Gamepad()
	if type(InputUtil) ~= "table" or ns.IsSecret(InputUtil) or type(InputUtil.IsGamepadUIEnabled) ~= "function" then
		return false
	end
	local ok, on = pcall(InputUtil.IsGamepadUIEnabled)
	return ok and not ns.IsSecret(on) and on == true
end

-- Whether another bag lies under a bag window. The game puts each bag on the top right corner of the one under it, 8 units above it
-- (UpdateContainerFrameAnchors, ContainerFrame.lua:26 and 1402), so a button hanging under the window would lie over the title bar of
-- the bag below. The lowest bag of a column is anchored to the screen or to the column before it (1391-1398). A window that does not say
-- where it lies counts as stacked.
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

-- Whether a window has room for its button where the settings put it.
local function Fits(frame, bank)
	if Gamepad() then
		return false
	end
	return bank or Chosen() ~= "slots" or not Stacked(frame)
end

-- Shows the button of one window where the settings put it, or hides it.
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

-- Makes, places and shows the buttons as the settings say, and with full also sets the direction. Nothing is made or placed on a window
-- in combat: a button that has to go is hidden, and the rest waits for the end of combat.
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

-- The game lays the bags out again whenever one opens or closes. The buttons under the slots are placed again on the next frame, when
-- the layout of the game and of the movers is done.
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

-- The layout of the bags is followed only while the buttons lie under the slots: that is the only place that depends on it.
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

-- /flatui sort, and /flatui sort bank.
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

ns.BagSort = { Apply = Apply, Logout = Logout, Command = Command, help = HELP }

-- A page that is off is never started, so a record left by a session in which it was on is put back at login.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
-- The interface style changes while the game runs: the buttons go under the gamepad style and come back with the other.
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
