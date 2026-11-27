local _, ns = ...

local KEY = "consumables"
local KINDS = { "drink", "health" }
local NAMES = { drink = "Flat UI Drink", health = "Flat UI Health" }
local ICON = 134400
local ACCOUNT_MACROS = 120
local SLOTS = 180
local SOON, WAIT = 0.2, 1
local SHORT = 1.5
local LABEL = "Drink and health macros"
local GEMS = { 5514, 5513, 8007, 8008 }

local using, why = {}, {}
local said = {}
local kept = {}
local fight, window, soon = false, false, false
local wakeAt, held = {}, {}
local writing, slotSeen, slotTripped, slotDeleted = false, false, false, false

local guard = CreateFrame("Frame")
ns.Own[guard] = true
guard:SetScript("OnEvent", function()
	if writing then
		slotSeen = true
	end
end)

local watch = CreateFrame("Frame")
ns.Own[watch] = true
local watching = false

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

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

local function Level()
	local level = Ask(UnitLevel, "player")
	return ns.Finite(level) and level or nil
end

local function HasMana()
	local mana = type(Enum) == "table" and type(Enum.PowerType) == "table" and Enum.PowerType.Mana or 0
	local most = Ask(UnitPowerMax, "player", mana)
	if ns.Finite(most) then
		return most > 0
	end
	return true
end

local function Count(id)
	local n = Ask(C_Item and C_Item.GetItemCount, id, false, false)
	return ns.Finite(n) and n or 0
end

local function Allowed(id, fallback, level)
	local needs = fallback
	local call = C_Item and C_Item.GetItemInfo
	if type(call) == "function" then
		local ok, _, _, _, _, minLevel = pcall(call, id)
		if ok and ns.Finite(minLevel) then
			needs = minLevel
		end
	end
	if not ns.Finite(needs) then
		return true, 0
	end
	return level == nil or needs <= level, needs
end

local function BestOf(key, level)
	for _, kind in ipairs(type(ns.CONSUMABLE_KINDS) == "table" and ns.CONSUMABLE_KINDS or {}) do
		if type(kind) == "table" and kind.key == key and type(kind.ranks) == "table" then
			for index = #kind.ranks, 1, -1 do
				local rank = kind.ranks[index]
				local id = type(rank) == "table" and rank[1]
				if ns.Finite(id) and Count(id) > 0 then
					local allowed, needs = Allowed(id, rank[2], level)
					if allowed then
						return id, needs
					end
				end
			end
		end
	end
	return nil
end

local function Supply(conjured, bought, level)
	local total = 0
	for _, kind in ipairs(type(ns.CONSUMABLE_KINDS) == "table" and ns.CONSUMABLE_KINDS or {}) do
		if type(kind) == "table" and (kind.key == conjured or kind.key == bought) and type(kind.ranks) == "table" then
			for _, rank in ipairs(kind.ranks) do
				local id = type(rank) == "table" and rank[1]
				if ns.Finite(id) then
					local n = Count(id)
					if n > 0 and Allowed(id, rank[2], level) then
						total = total + n
					end
				end
			end
		end
	end
	return total
end

local function Prefer(conjured, bought, level)
	local made, madeNeeds = BestOf(conjured, level)
	local other, otherNeeds = BestOf(bought, level)
	if made and not (other and otherNeeds > madeNeeds) then
		return made
	end
	return other
end

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

local function BestGem(level)
	for index = #GEMS, 1, -1 do
		local id = GEMS[index]
		if Count(id) > 0 and Allowed(id, nil, level) then
			return id
		end
	end
	return nil
end

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

local function DrinkBody(level)
	local drink = Prefer("water", "drink", level)
	local potion = Opt("manaPotion") == true and BestItem("mana", level) or nil
	local gem = Opt("manaGem") == true and BestGem(level) or nil
	local order, wake = {}, nil
	if gem then
		order[#order + 1] = gem
	end
	if potion then
		order[#order + 1] = potion
	end
	if gem and potion then
		local gemLeft, potionLeft = Left(gem), Left(potion)
		if gemLeft and potionLeft and gemLeft > 0 and potionLeft < gemLeft then
			order, wake = { potion, gem }, gemLeft
		end
	end
	local lines = { "#showtooltip" }
	if #order == 1 then
		lines[#lines + 1] = ("/use [combat] item:%d"):format(order[1])
	elseif #order == 2 then
		lines[#lines + 1] = ("/castsequence [combat] reset=combat item:%d, item:%d"):format(order[1], order[2])
	end
	if drink then
		lines[#lines + 1] = ("/use%s item:%d"):format(#order > 0 and " [nocombat]" or "", drink)
	end
	return table.concat(lines, "\n"), { drink = drink, potion = potion, gem = gem, order = order }, wake
end

local function HealthBody(level)
	local stone, potion = BestItem("healthstone", level), BestItem("healing", level)
	local food = Opt("food") == true and Prefer("bread", "food", level) or nil
	local order, wake = {}, nil
	if stone then
		order[#order + 1] = stone
	end
	if potion then
		order[#order + 1] = potion
	end
	if stone and potion then
		local stoneLeft, potionLeft = Left(stone), Left(potion)
		if stoneLeft and potionLeft and stoneLeft > 0 and potionLeft < stoneLeft then
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

local OUR_LINES = { "^/use item:%d+$", "^/use %[combat%] item:%d+$", "^/use %[nocombat%] item:%d+$",
	"^/castsequence reset=combat item:%d+, item:%d+$", "^/castsequence %[combat%] reset=combat item:%d+, item:%d+$" }

local function Ours(body)
	if type(body) ~= "string" then
		return false
	end
	local count = 0
	for line in body:gmatch("[^\r\n]+") do
		count = count + 1
		local fits = count == 1 and line == "#showtooltip"
		if count > 1 then
			for _, shape in ipairs(OUR_LINES) do
				fits = fits or line:match(shape) ~= nil
			end
		end
		if not fits then
			return false
		end
	end
	return count > 0
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
			slotDeleted = true
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

local Again

local function Named(id)
	local name = Ask(C_Item and C_Item.GetItemNameByID, id)
	return type(name) == "string" and name ~= "" and name or ("item " .. tostring(id))
end

local function Set(list)
	local ids = {}
	for index, id in ipairs(list or {}) do
		ids[index] = tostring(id)
	end
	table.sort(ids)
	return table.concat(ids, ",")
end

local function Listed(list)
	local names = {}
	for index, id in ipairs(list) do
		names[index] = Named(id)
	end
	return table.concat(names, ", then ")
end

local function Rows(kind)
	if kind == "drink" then
		return tostring(Opt("manaPotion")) .. tostring(Opt("manaGem"))
	end
	return tostring(Opt("food"))
end

local function Change(kind, old, new)
	if type(old) ~= "table" or type(new) ~= "table" then
		return nil
	end
	local name, lines = NAMES[kind], {}
	local item = kind == "drink" and "drink" or "food"
	if old[item] ~= new[item] then
		if new[item] and kind == "drink" then
			lines[#lines + 1] = ("%s now drinks %s."):format(name, Named(new.drink))
		elseif new[item] then
			lines[#lines + 1] = ("%s now eats %s out of combat."):format(name, Named(new.food))
		elseif old[item] then
			lines[#lines + 1] = kind == "drink" and ("%s has nothing left to drink in your bags."):format(name)
				or ("%s has no food left in your bags."):format(name)
		end
	end
	local before, after = old.order or {}, new.order or {}
	if Set(before) ~= Set(after) then
		if #after > 0 then
			lines[#lines + 1] = kind == "drink" and ("%s now takes %s in a fight."):format(name, Listed(after))
				or ("%s now takes %s."):format(name, Listed(after))
		elseif #before > 0 then
			lines[#lines + 1] = kind == "drink" and ("%s has no mana potion or gem left for a fight."):format(name)
				or ("%s has no healthstone or healing potion left in your bags."):format(name)
		end
	end
	return #lines > 0 and lines or nil
end

local primed, rowsAt, lowSaid = {}, {}, {}
local LOW = 5

local function Low(kind, level, uses, speak)
	local drink = kind == "drink"
	if not (drink and uses.drink or not drink and uses.food) then
		return
	end
	local total = drink and Supply("water", "drink", level) or Supply("bread", "food", level)
	if total > LOW then
		lowSaid[kind] = nil
	elseif total > 0 and speak and not lowSaid[kind] then
		lowSaid[kind] = true
		local word = drink and (total == 1 and "drink" or "drinks") or (total == 1 and "food" or "foods")
		print(("Flat UI: %s has %d %s left in your bags."):format(NAMES[kind], total, word))
	end
end

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
		body, uses, wake = DrinkBody(level)
	else
		body, uses, wake = HealthBody(level)
	end
	held[kind] = wake == math.huge
	if wake and wake ~= math.huge then
		local now, at = Ask(GetTime), wakeAt[kind]
		if ns.Finite(now) and (not at or at <= now or at > now + wake + 0.1) then
			local due = now + wake + 0.1
			wakeAt[kind] = due
			After(wake + 0.1, function()
				if wakeAt[kind] == due then
					wakeAt[kind] = nil
					Again()
				end
			end)
		end
	end
	local rows, changes = Rows(kind), nil
	local speak = primed[kind] == true and Opt("say") == true
	if speak and rowsAt[kind] == rows then
		changes = Change(kind, using[kind], uses)
	end
	primed[kind], rowsAt[kind] = true, rows
	using[kind] = uses
	if Blocked() then
		why[kind] = "blocked"
		return
	end
	local index = Index(name)
	if index == nil then
		return
	end
	if index > 0 and not (store and store[kind] == name) and Ours(BodyAt(index)) then
		store = Store(true)
		if store then
			store[kind] = name
		end
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
	if BodyAt(index) ~= body and Call(false, EditMacro, index, nil, nil, body) and changes then
		for _, line in ipairs(changes) do
			print("Flat UI: " .. line)
		end
	end
	Low(kind, level, uses, speak)
end

local function HeldBy(name, index)
	local text = C_ActionBar and C_ActionBar.GetActionText
	for slot = 1, SLOTS do
		if Ask(GetActionInfo, slot) == "macro" then
			local shown = Ask(text, slot)
			if shown == nil or shown == name then
				return "bar"
			end
		end
	end
	local what, place = Ask(GetCursorInfo)
	if what == "macro" and (place == nil or place == index) then
		return "cursor"
	end
	return nil
end

local function Remove(kind)
	using[kind], why[kind] = nil, nil
	held[kind], wakeAt[kind] = false, nil
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
		local holder = HeldBy(name, index)
		if holder then
			why[kind] = holder
			if holder == "bar" then
				Say(kind .. "Bar", ("%s is still on an action bar, so it is not deleted yet. Drag it off the bar, and Flat UI deletes it."):format(name))
			end
			return
		end
		Call(true, DeleteMacro, index)
		index = Index(name)
	end
	if index == 0 then
		store[kind], kept[kind] = nil, nil
	end
end

local function Watch(on)
	if on == watching then
		return
	end
	watching = on
	local method = on and watch.RegisterEvent or watch.UnregisterEvent
	pcall(method, watch, "ACTIONBAR_SLOT_CHANGED")
	pcall(method, watch, "CURSOR_CHANGED")
end

local function Waiting()
	for _, kind in ipairs(KINDS) do
		if why[kind] == "bar" or why[kind] == "cursor" then
			return true
		end
	end
	return false
end

local Run

Again = function()
	if ns.IsStopped(KEY) then
		pcall(Run)
	else
		ns.Try(KEY, Run)
	end
end

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
	Watch(Waiting())
end

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

watch:SetScript("OnEvent", function()
	local ok, err = pcall(Soon)
	if not ok then
		geterrorhandler()(err)
	end
end)

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
		local fighting = {}
		for index, id in ipairs(uses.order or {}) do
			fighting[index] = Named(id)
		end
		if #fighting > 0 then
			parts[#parts + 1] = ("in a fight takes %s"):format(table.concat(fighting, ", then "))
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
	for _, kind in ipairs(KINDS) do
		local off = not (ns.Enabled(KEY) and Opt(kind) == true)
		if off and why[kind] == "bar" then
			lines[#lines + 1] = ("%s: %s is still on an action bar, so it is deleted once you drag it off."):format(LABEL, NAMES[kind])
		elseif off and why[kind] == "cursor" then
			lines[#lines + 1] = ("%s: %s is on the cursor, so it is deleted once the cursor lets it go."):format(LABEL, NAMES[kind])
		end
	end
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

ns.ClickPathReporter(function()
	if slotTripped then
		return LABEL .. ": the game updated an action button inside a macro write of Flat UI. /reload makes it clean."
	elseif slotDeleted then
		return LABEL .. ": the game updated an action button while Flat UI deleted its macro. /reload makes it clean."
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
		BAG_UPDATE_COOLDOWN = function()
			if held.drink or held.health then
				Soon()
			end
		end,
		UPDATE_MACROS = function()
			if why.drink == "full" or why.health == "full" or why.drink == "taken" or why.health == "taken" then
				Soon()
			end
		end,
	},
})
