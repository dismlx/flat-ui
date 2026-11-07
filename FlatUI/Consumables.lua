local _, ns = ...

-- Drink and health macros: two macros of Flat UI's own in the account's macro list, Flat UI Drink and Flat UI Health, kept up to date out of
-- combat. Flat UI Drink drinks the best drink in the bags that the level allows, conjured water first, and in a fight, where nobody can drink,
-- takes the best mana potion the level allows (Mana potion in a fight). Flat UI Health takes the best healthstone, then at the next press the
-- best healing potion (a cast sequence that starts again when the fight ends); out of combat it eats the best food instead, conjured food first
-- (Eat out of combat). The ranks are those of ns.COOLDOWN_ITEMS for the potions and healthstones (CooldownData.lua) and of ns.CONSUMABLE_KINDS
-- for the drinks and foods (ConsumableData.lua). An item counts when the bags hold one (C_Item.GetItemCount, ItemDocumentation.lua:451-468)
-- and the level allows it: the level it needs is the fifth value of C_Item.GetItemInfo (ItemDocumentation.lua:626-657), as Cooldowns.lua:384-391
-- reads it for a potion, else the level of the data; the player's is UnitLevel (UnitDocumentation.lua:2474-2487). A healthstone still cooling
-- (C_Item.GetItemCooldown, ItemDocumentation.lua:434-448) goes after a potion that is ready, since a cast sequence waits on an item that is not
-- ready, and it goes first again when it is ready. A macro uses items by their ID (item:159), so it works in every language, and #showtooltip
-- gives its button the icon, the count and the tooltip of the item it uses. A character without mana (UnitPowerMax, UnitDocumentation.lua:
-- 2801-2817, a value the game may withhold) leaves Flat UI Drink as it is.
--
-- The macros are written again when the bags change (BAG_UPDATE_DELAYED, a unique event after the bag updates, ContainerDocumentation.lua:
-- 675-679), when the level changes (PLAYER_LEVEL_CHANGED, once the game has the new level: UnitDocumentation.lua:3818-3828, as Cooldowns.lua:
-- 1894-1898 reads it), on entering the world, and when a row of the page changes. Never in a fight: a change waits for its end
-- (InCombatLockdown, RestrictedActionsDocumentation.lua:45-53, then ns.OutOfCombat). Never while the game's macro window is open either
-- (MacroFrame, asked with the widget call IsShown): it hears UPDATE_MACROS while shown and loads the text of the macro it has picked again
-- (Blizzard_MacroUI.lua:110-117, 132-136, 285-300), which would throw away what the player is typing there; a step of one second waits for it to
-- close. A macro is made with CreateMacro(name, icon, body, false), an account macro as the game's own New button makes one
-- (Blizzard_MacroIconSelector.lua:109), written with EditMacro(index, nil, nil, body), which keeps its name and icon (Blizzard_MacroUI.lua:364),
-- and deleted with DeleteMacro(index) (Blizzard_MacroUI.lua:317), each found by name (GetMacroIndexByName) and read back with GetMacroInfo
-- (Blizzard_MacroUI.lua:299); a body that is already the one wanted is not written. The icon is the question mark (fileID 134400, the file of
-- QUESTION_MARK_ICON, Blizzard_FrameXMLBase/Constants.lua:588), which #showtooltip replaces. The account list holds 120 macros
-- (Constants.MacroConsts.MAX_ACCOUNT_MACROS, MacroConstantsDocumentation.lua:10; Blizzard_MacroUI.lua:166, 182-196): when it is full, chat says
-- so once a session and /flatui status says so, and UPDATE_MACROS (UIMacrosDocumentation.lua:67-72) tries again once the
-- player has deleted one. Flat UI only touches the macros it made: their names are kept in FlatUIDB.consumables (the account's, as the macros
-- are) from the moment they are made, and a macro of the same name that Flat UI did not make is left alone, said once in chat.
-- Turned off (its row, the page, a profile without it, or a stop after errors) in a session that kept it, a macro Flat UI made is deleted, out
-- of combat, for every character of the account, whose list it is; a character whose profile has it off at login leaves it alone. The game then
-- takes it off any action bar the player put it on, as when a player deletes a macro, and the bar slot is empty until something else goes there.
-- Turned on again, a new macro is made, to be put on the bar again.
--
-- The game's action buttons write action, which the click of an action button reads (TaintScan.lua), when ACTIONBAR_SLOT_CHANGED names their
-- slot (ActionButton.lua:981-984, 1109-1112, 538-545), and the game raises that event inside the call that changes a slot (SynchronousEvent,
-- ActionBarFrameDocumentation.lua:1082-1091; ErrandsRanks.lua says what that does). A macro call changes no slot, but a macro on a bar may be
-- drawn again. So a frame of the addon's own hears ACTIONBAR_SLOT_CHANGED during each macro call of this file, and only then. Should the game
-- raise it inside one, chat and /flatui status say that /reload makes the bars clean again, and Flat UI writes no more macros on that build of
-- the client (FlatUIDB.consumables.slotWrite); turning the page off still deletes them. No secure button, binding or global of Flat UI's is
-- made, and nothing of the game's is hooked or written.
--
-- Built on the drink and health macros of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission (EnhanceQoL/Modules/Food/Food.lua,
-- Init.lua:412-435, EnhanceQoLHealthMacro.lua, Health.lua), with the choice its Forever build makes for the health macro: food out of combat
-- (Core/Cleanup.lua:195-198, the locale healthUseFoodForever). Left out: Recuperate, mage food and Earthen food (none on Forever), the flask and
-- buff food macros, the order of the health macro as a choice, its reset choices, custom spells and the potion priority list. The level an item
-- needs is the client's first and the data's only when the client gives none, and a vanilla catalogue replaces the retail one.

local KEY = "consumables"
local KINDS = { "drink", "health" }
local NAMES = { drink = "Flat UI Drink", health = "Flat UI Health" }
local ICON = 134400
local ACCOUNT_MACROS = 120
-- A burst of events is written once, this long after the first. The step while the game's macro window is open.
local SOON, WAIT = 0.2, 1
-- A cooldown this short is the one every item shares after a use, not the item's own.
local SHORT = 1.5
local LABEL = "Drink and health macros"

-- What each macro uses now ({ drink, potion } or { stone, potion, food, order }), and why one is not kept ("mana", "taken", "full",
-- "blocked"), by kind.
local using, why = {}, {}
-- Lines already said in chat this session.
local said = {}
-- The kinds Flat UI kept this session. Only those are deleted when their row or the page goes off: the macros are the account's, so a character
-- whose profile has a row off at login leaves alone the macro another character keeps.
local kept = {}
-- A run waiting for the end of the fight, for the macro window, or for a burst of events to end.
local fight, window, soon = false, false, false
-- The health macro put a cooling healthstone after the potion: the time to write it again, or true while its cooldown has not started.
local wakeAt, held = nil, false
-- The slot guard: true while a macro call of this file runs, and whether the game raised ACTIONBAR_SLOT_CHANGED inside one this session.
local writing, slotSeen, slotTripped = false, false, false

local guard = CreateFrame("Frame")
ns.Own[guard] = true
guard:SetScript("OnEvent", function()
	if writing then
		slotSeen = true
	end
end)

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- Up to five values the client gives, each nil when the client withholds it (a secret); all nil when the call is missing or raises.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b, c, d, e = pcall(fn, ...)
	if not ok then
		return nil
	end
	local values = { a, b, c, d, e }
	for index = 1, 5 do
		if ns.IsSecret(values[index]) then
			values[index] = nil
		end
	end
	return values[1], values[2], values[3], values[4], values[5]
end

local function After(seconds, fn)
	return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, seconds, fn)
end

local function Say(key, text)
	if not said[key] then
		said[key] = true
		print("Flat UI: " .. text)
	end
end

-- FlatUIDB.consumables: drink and health hold the name of the macro Flat UI made, slotWrite the build on which a macro call made the game
-- write an action slot. Nil before the saved variables are loaded, and while nothing is kept unless make is set.
local function Store(make)
	local db = ns.Account()
	if type(db) ~= "table" then
		return nil
	end
	if type(db.consumables) ~= "table" then
		if not make then
			return nil
		end
		db.consumables = {}
	end
	return db.consumables
end

local function Build()
	local _, build = Ask(GetBuildInfo)
	return type(build) == "string" and build ~= "" and build or "?"
end

local function Blocked()
	local store = Store()
	return slotTripped or (store ~= nil and store.slotWrite == Build())
end

-- The player ------------------------------------------------------------------------------------------------------------------------------

local function Level()
	local level = Ask(UnitLevel, "player")
	return ns.Finite(level) and level or nil
end

-- False only when the game says the player has no mana.
local function HasMana()
	local mana = type(Enum) == "table" and type(Enum.PowerType) == "table" and Enum.PowerType.Mana or 0
	local most = Ask(UnitPowerMax, "player", mana)
	if ns.Finite(most) then
		return most > 0
	end
	return true
end

-- Items ------------------------------------------------------------------------------------------------------------------------------------

local function Count(id)
	local n = Ask(C_Item and C_Item.GetItemCount, id, false, false)
	return ns.Finite(n) and n or 0
end

-- True when the level allows the item: the level it needs is the client's, else fallback; a level nobody knows allows it.
local function Allowed(id, fallback, level)
	local needs = fallback
	local call = C_Item and C_Item.GetItemInfo
	if type(call) == "function" then
		local ok, _, _, _, _, minLevel = pcall(call, id)
		if ok and ns.Finite(minLevel) then
			needs = minLevel
		end
	end
	return level == nil or not ns.Finite(needs) or needs <= level
end

-- The highest rank of a kind of ns.CONSUMABLE_KINDS that the bags hold and the level allows, or nil.
local function BestOf(key, level)
	for _, kind in ipairs(type(ns.CONSUMABLE_KINDS) == "table" and ns.CONSUMABLE_KINDS or {}) do
		if type(kind) == "table" and kind.key == key and type(kind.ranks) == "table" then
			for index = #kind.ranks, 1, -1 do
				local rank = kind.ranks[index]
				local id = type(rank) == "table" and rank[1]
				if ns.Finite(id) and Count(id) > 0 and Allowed(id, rank[2], level) then
					return id
				end
			end
		end
	end
	return nil
end

-- The same for a kind of ns.COOLDOWN_ITEMS (healing, mana, healthstone), whose ranks have no level of their own.
local function BestItem(key, level)
	for _, kind in ipairs(type(ns.COOLDOWN_ITEMS) == "table" and ns.COOLDOWN_ITEMS or {}) do
		if type(kind) == "table" and kind.key == key and type(kind.items) == "table" then
			for index = #kind.items, 1, -1 do
				local id = kind.items[index]
				if ns.Finite(id) and Count(id) > 0 and Allowed(id, nil, level) then
					return id
				end
			end
		end
	end
	return nil
end

-- Seconds until an item is ready again: 0 when it is, math.huge for a cooldown that has not started yet (enableCooldownTimer false, as for a
-- potion drunk in a fight), nil when the client does not say.
local function Left(id)
	local start, duration, enable = Ask(C_Item and C_Item.GetItemCooldown, id)
	if not (ns.Finite(start) and ns.Finite(duration)) then
		return nil
	end
	if duration <= SHORT then
		return 0
	end
	if enable == false or enable == 0 then
		return math.huge
	end
	local now = Ask(GetTime)
	if not ns.Finite(now) then
		return nil
	end
	return math.max(0, start + duration - now)
end

-- The macros --------------------------------------------------------------------------------------------------------------------------------

local function DrinkBody(level)
	local drink = BestOf("water", level) or BestOf("drink", level)
	local potion = Opt("manaPotion") == true and BestItem("mana", level) or nil
	local lines = { "#showtooltip" }
	if potion then
		lines[#lines + 1] = ("/use [combat] item:%d"):format(potion)
	end
	if drink then
		lines[#lines + 1] = ("/use%s item:%d"):format(potion and " [nocombat]" or "", drink)
	end
	return table.concat(lines, "\n"), { drink = drink, potion = potion }
end

-- The body of Flat UI Health, what it uses, and in how many seconds it wants writing again (a cooling healthstone put after the potion).
local function HealthBody(level)
	local stone, potion = BestItem("healthstone", level), BestItem("healing", level)
	local food = Opt("food") == true and (BestOf("bread", level) or BestOf("food", level)) or nil
	local order, wake = {}, nil
	if stone then
		order[#order + 1] = stone
	end
	if potion then
		order[#order + 1] = potion
	end
	if stone and potion then
		local stoneLeft, potionLeft = Left(stone), Left(potion)
		if stoneLeft and stoneLeft > 0 and potionLeft == 0 then
			order, wake = { potion, stone }, stoneLeft
		end
	end
	local lines = { "#showtooltip" }
	if food then
		lines[#lines + 1] = ("/use [nocombat] item:%d"):format(food)
	end
	local when = food and " [combat]" or ""
	if #order == 1 then
		lines[#lines + 1] = ("/use%s item:%d"):format(when, order[1])
	elseif #order == 2 then
		lines[#lines + 1] = ("/castsequence%s reset=combat item:%d, item:%d"):format(when, order[1], order[2])
	end
	return table.concat(lines, "\n"), { stone = stone, potion = potion, food = food, order = order }, wake
end

local function MacroCalls()
	return type(GetMacroIndexByName) == "function" and type(GetMacroInfo) == "function" and type(GetNumMacros) == "function"
		and type(CreateMacro) == "function" and type(EditMacro) == "function" and type(DeleteMacro) == "function"
end

-- The place of the macro of that name in the macro lists, 0 when there is none, nil when the client does not say.
local function Index(name)
	local index = Ask(GetMacroIndexByName, name)
	if ns.Finite(index) and index >= 0 then
		return index
	end
	return nil
end

local function BodyAt(index)
	local _, _, body = Ask(GetMacroInfo, index)
	return type(body) == "string" and body or nil
end

local function AccountFull()
	local count = Ask(GetNumMacros)
	local consts = type(Constants) == "table" and type(Constants.MacroConsts) == "table" and Constants.MacroConsts or nil
	local most = consts and consts.MAX_ACCOUNT_MACROS
	most = ns.Finite(most) and most > 0 and most or ACCOUNT_MACROS
	return ns.Finite(count) and count >= most
end

local function WindowOpen()
	local frame = _G.MacroFrame
	if type(frame) ~= "table" or ns.Forbidden(frame) or type(frame.IsShown) ~= "function" then
		return false
	end
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and not ns.IsSecret(shown) and shown == true
end

-- A macro call, with the slot guard listening while it runs. True when the client took it.
local function Call(deleting, fn, ...)
	local listening = pcall(guard.RegisterEvent, guard, "ACTIONBAR_SLOT_CHANGED")
	slotSeen, writing = false, true
	local ok = pcall(fn, ...)
	writing = false
	if listening then
		pcall(guard.UnregisterEvent, guard, "ACTIONBAR_SLOT_CHANGED")
	end
	if slotSeen then
		slotSeen = false
		if deleting then
			Say("slotDelete", "the game updated an action button while Flat UI deleted its macro. Type /reload before a fight, so that button takes keys and clicks again.")
		else
			slotTripped = true
			local store = Store(true)
			if store then
				store.slotWrite = Build()
			end
			Say("slotWrite", "the game updated an action button while Flat UI wrote a macro, so that button may refuse keys and clicks until you type /reload. Flat UI no longer writes its drink and health macros on this version of the game.")
		end
	end
	return ok
end

-- A run that waited for a timer or the end of a fight (below).
local Again

-- Makes or writes the macro of a kind, as its row wants it.
local function Keep(kind)
	why[kind] = nil
	local store = Store()
	local name = NAMES[kind]
	if kind == "drink" and not HasMana() then
		using[kind], why[kind] = nil, "mana"
		return
	end
	kept[kind] = true
	local level = Level()
	local body, uses, wake
	if kind == "drink" then
		body, uses = DrinkBody(level)
	else
		body, uses, wake = HealthBody(level)
		held = wake == math.huge
		if wake and wake ~= math.huge then
			local now = Ask(GetTime)
			if ns.Finite(now) and (not wakeAt or wakeAt <= now or wakeAt > now + wake + 0.1) then
				local due = now + wake + 0.1
				wakeAt = due
				After(wake + 0.1, function()
					if wakeAt == due then
						wakeAt = nil
						Again()
					end
				end)
			end
		end
	end
	using[kind] = uses
	if Blocked() then
		why[kind] = "blocked"
		return
	end
	local index = Index(name)
	if index == nil then
		return
	end
	if index > 0 and not (store and store[kind] == name) then
		why[kind] = "taken"
		Say(kind .. "Taken", ("your macros already have one called %s that Flat UI did not make, so it is left alone. Rename or delete it, and Flat UI makes its own."):format(name))
		return
	end
	if index == 0 then
		if AccountFull() then
			why[kind] = "full"
			Say("full", ("your account's macro list is full, so %s could not be made. Delete a macro, and Flat UI makes it."):format(name))
			return
		end
		Call(false, CreateMacro, name, ICON, body, false)
		store = (Index(name) or 0) > 0 and Store(true)
		if store then
			store[kind] = name
			print(("Flat UI: %s is in your macro list. Open it with /macro and drag it onto a bar."):format(name))
		end
		return
	end
	if BodyAt(index) ~= body then
		Call(false, EditMacro, index, nil, nil, body)
	end
end

-- Deletes the macro of a kind that Flat UI made and kept this session, and forgets it once it is gone.
local function Remove(kind)
	using[kind], why[kind] = nil, nil
	if kind == "health" then
		held, wakeAt = false, nil
	end
	if not kept[kind] then
		return
	end
	local store = Store()
	local name = store and store[kind]
	if type(name) ~= "string" then
		return
	end
	local index = Index(name)
	if index == nil then
		return
	end
	if index > 0 then
		Call(true, DeleteMacro, index)
		index = Index(name)
	end
	if index == 0 then
		store[kind], kept[kind] = nil, nil
	end
end

local Run

-- A run that waited: through ns.Try, or as it is for a stopped module, which still deletes what it made.
Again = function()
	if ns.IsStopped(KEY) then
		pcall(Run)
	else
		ns.Try(KEY, Run)
	end
end

-- Each macro as its row and the page want it: out of combat, with the game's macro window closed.
Run = function()
	if not MacroCalls() then
		return
	end
	if Ask(InCombatLockdown) == true then
		if not fight then
			fight = true
			ns.OutOfCombat(function()
				fight = false
				Again()
			end)
		end
		return
	end
	if WindowOpen() then
		if not window then
			window = true
			if not After(WAIT, function()
				window = false
				Again()
			end) then
				window = false
			end
		end
		return
	end
	for _, kind in ipairs(KINDS) do
		if ns.Enabled(KEY) and Opt(kind) == true then
			Keep(kind)
		else
			Remove(kind)
		end
	end
end

-- An event: a burst is written once, a moment after the first.
local function Soon()
	if soon then
		return
	end
	soon = true
	if not After(SOON, function()
		soon = false
		Again()
	end) then
		soon = false
		Run()
	end
end

-- /flatui status --------------------------------------------------------------------------------------------------------------------------

local function Named(id)
	local name = Ask(C_Item and C_Item.GetItemNameByID, id)
	return type(name) == "string" and name ~= "" and name or ("item " .. tostring(id))
end

local function Line(kind)
	local name, reason, uses = NAMES[kind], why[kind], using[kind]
	if reason == "mana" then
		return ("%s: %s is left as it is, as this character has no mana."):format(LABEL, name)
	elseif reason == "taken" then
		return ("%s: %s is not made, as a macro of that name that Flat UI did not make is in your macro list."):format(LABEL, name)
	elseif reason == "full" then
		return ("%s: %s is not made, as your account's macro list is full."):format(LABEL, name)
	elseif type(uses) ~= "table" then
		return nil
	end
	local parts = {}
	if kind == "drink" then
		parts[#parts + 1] = uses.drink and ("drinks %s"):format(Named(uses.drink)) or "finds nothing to drink"
		if uses.potion then
			parts[#parts + 1] = ("in a fight takes %s"):format(Named(uses.potion))
		end
	else
		local order = uses.order or {}
		if #order > 0 then
			local names = {}
			for index, id in ipairs(order) do
				names[index] = Named(id)
			end
			parts[#parts + 1] = ("takes %s"):format(table.concat(names, ", then "))
		else
			parts[#parts + 1] = "finds no healthstone or healing potion"
		end
		if uses.food then
			parts[#parts + 1] = ("out of combat eats %s"):format(Named(uses.food))
		end
	end
	return ("%s: %s %s%s."):format(LABEL, name, table.concat(parts, "; "), reason == "blocked" and " (not written)" or "")
end

local function Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	if not MacroCalls() then
		lines[1] = LABEL .. ": this client has no macro calls, so no macro is made."
		return lines
	end
	if Blocked() then
		lines[#lines + 1] = LABEL .. ": the game updated an action button while Flat UI wrote a macro, so the macros are no longer written on this version of the game."
	end
	if fight then
		lines[#lines + 1] = LABEL .. ": the macros wait for the end of the fight."
	elseif window then
		lines[#lines + 1] = LABEL .. ": the macros wait for the game's macro window to close."
	end
	for _, kind in ipairs(KINDS) do
		if Opt(kind) == true then
			lines[#lines + 1] = Line(kind)
		end
	end
	return lines
end

-- A macro call that made the game write an action slot this session leaves the bars to a reload.
ns.ClickPathReporter(function()
	if slotTripped then
		return LABEL .. ": the game updated an action button inside a macro write of Flat UI. /reload makes it clean."
	end
	return nil
end)

ns.Register(KEY, {
	label = LABEL,
	counted = false,
	Start = Run,
	Refresh = Run,
	Status = Status,
	events = {
		BAG_UPDATE_DELAYED = Soon,
		PLAYER_LEVEL_CHANGED = Soon,
		PLAYER_ENTERING_WORLD = Soon,
		-- The cooldown of a healthstone put after the potion has started, so the time it ends is known.
		BAG_UPDATE_COOLDOWN = function()
			if held then
				Soon()
			end
		end,
		-- The player made room in the macro list, or renamed the macro that had Flat UI's name.
		UPDATE_MACROS = function()
			if why.drink == "full" or why.health == "full" or why.drink == "taken" or why.health == "taken" then
				Soon()
			end
		end,
	},
})
