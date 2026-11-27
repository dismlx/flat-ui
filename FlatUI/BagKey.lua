local _, ns = ...

local KEY = "windows"
local FROM, TO = "TOGGLEBACKPACK", "OPENALLBAGS"
local owner = CreateFrame("Frame")
local done, applied, refused = {}, {}, {}
local waiting, busy = false, false

local function Wanted()
	return ns.Enabled(KEY) and ns.Get(KEY .. ".bagKey") == true
end

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
