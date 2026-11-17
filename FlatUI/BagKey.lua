local _, ns = ...

-- Backpack key opens every bag. WoW: Forever binds B to Toggle Backpack (TOGGLEBACKPACK, Bindings_Camelot.xml:1172-1174) and Shift+B to Open
-- All Bags (OPENALLBAGS, :1190-1192). With Combine bags on, Toggle Backpack shows the combined bag alone (ToggleBackpack_Combined,
-- Mainline/ContainerFrame.lua:171-177): the reagent bag is never part of it (ContainerFrame_IsGenericHeldBag and IsUsingCombinedBags, :83-86 and
-- 2460-2464) and has a window and a key of its own (TOGGLEREAGENTBAG1, Bindings_Camelot.xml:1175-1177). Open All Bags opens the backpack and then
-- every bag up to the reagent bag, and closes them all when all are open (ToggleAllBags, ContainerFrame.lua:2141-2148 and 2173-2213).
-- So while the row is on, each key the player has for Toggle Backpack gets an override binding to Open All Bags, owned by a frame of this addon's
-- own (SetOverrideBinding). The key then runs the game's own binding, and nothing of this addon runs when it is pressed. The player's bindings are
-- not written: GetBindingKey without its override flag reads them, so this addon's own overrides are not counted; ClearOverrideBindings takes the
-- overrides away when the row goes off, and they end with the session (the page goes off with a reload). Neither call may be made in combat, so a
-- change then waits for the end of the fight. UPDATE_BINDINGS follows a key the player binds again; this addon's own calls fire it as well, and a
-- pass for the keys already done does nothing.
-- This is not a module: the windows module calls ns.BagKey.Apply whenever it applies its settings, and the row calls ns.BagKeyChanged.

local KEY = "windows"
local FROM, TO = "TOGGLEBACKPACK", "OPENALLBAGS"
local owner = CreateFrame("Frame")
-- done: the keys the last pass was for. applied: those the game took. refused: those it did not. waiting: a pass waits for the end of combat.
local done, applied, refused = {}, {}, {}
local waiting, busy = false, false

local function Wanted()
	return ns.Enabled(KEY) and ns.Get(KEY .. ".bagKey") == true
end

-- The keys the player has bound to Toggle Backpack, in the order the game gives them.
local function Keys()
	local keys = {}
	if type(GetBindingKey) ~= "function" then
		return keys
	end
	local ok, first, second = pcall(GetBindingKey, FROM)
	if not ok then
		return keys
	end
	for _, key in ipairs({ { first }, { second } }) do
		local value = key[1]
		if value ~= nil and not ns.IsSecret(value) and type(value) == "string" and value ~= "" then
			keys[#keys + 1] = value
		end
	end
	return keys
end

local function Same(a, b)
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

local function Pass()
	if busy then
		return
	end
	local keys = Wanted() and Keys() or {}
	if Same(keys, done) then
		return
	end
	if InCombatLockdown() then
		if not waiting then
			waiting = true
			ns.OutOfCombat(function()
				waiting = false
				Pass()
			end)
		end
		return
	end
	busy = true
	done, applied, refused = keys, {}, {}
	if type(ClearOverrideBindings) == "function" then
		pcall(ClearOverrideBindings, owner)
	end
	for _, key in ipairs(keys) do
		if type(SetOverrideBinding) == "function" and pcall(SetOverrideBinding, owner, false, key, TO) then
			applied[#applied + 1] = key
		else
			refused[#refused + 1] = key
		end
	end
	busy = false
end

local function Status()
	if not Wanted() then
		return {}
	end
	if waiting then
		return { "Backpack key: waits for the end of combat." }
	end
	local lines = {}
	if #applied > 0 then
		lines[#lines + 1] = ("Backpack key: %s opens every bag, the reagent bag too."):format(table.concat(applied, ", "))
	elseif #refused == 0 then
		lines[#lines + 1] = "Backpack key: no key is bound to Toggle Backpack."
	end
	if #refused > 0 then
		lines[#lines + 1] = ("Backpack key: the game would not bind %s to Open All Bags."):format(table.concat(refused, ", "))
	end
	return lines
end

ns.BagKey = { Apply = Pass, Status = Status }

function ns.BagKeyChanged()
	Pass()
end

pcall(owner.RegisterEvent, owner, "UPDATE_BINDINGS")
owner:SetScript("OnEvent", function()
	Pass()
end)
