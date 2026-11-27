local _, ns = ...

local KEY = "errands"
local CVAR = "showInGameNavigation"
local ON = "1"
local SETTLE = 1
local LABEL = "In-game navigation"

local E = ns.Errands
local part = E.Part({ label = LABEL })

local pending = false
local settling = false
local result = nil
local stuck = nil
local restored = false

local function Calls()
	local cvar = _G.C_CVar
	if type(cvar) == "table" and not ns.IsSecret(cvar) then
		return cvar
	end
	return nil
end

local function Text()
	local cvar = Calls()
	if not cvar or type(cvar.GetCVar) ~= "function" then
		return nil
	end
	local ok, value = pcall(cvar.GetCVar, CVAR)
	if ok and not ns.IsSecret(value) and type(value) == "string" then
		return value
	end
	return nil
end

local function Number(text)
	local number = type(text) == "string" and tonumber(text) or nil
	return ns.Finite(number) and number or nil
end

local function Write(text)
	local cvar = Calls()
	if not cvar or type(cvar.SetCVar) ~= "function" then
		return nil
	end
	pcall(cvar.SetCVar, CVAR, text)
	return Text()
end

local function Wanted()
	return ns.Enabled(KEY) and ns.Get(KEY .. ".navigation") == true and not ns.PartStopped(KEY, LABEL)
end

local function Account()
	local db = ns.Account()
	return type(db) == "table" and db or nil
end

local function Kept(db, key)
	local text = db and db[key]
	return type(text) == "string" and Number(text) ~= nil and text or nil
end

local function Ours(db, value)
	local game, wrote = Kept(db, "navigationGame"), Kept(db, "navigationWrote")
	return game ~= nil and wrote ~= nil and Number(wrote) == value and Number(game) ~= value
end

local function Forget(db)
	if db then
		db.navigationGame, db.navigationWrote = nil, nil
	end
end

local function Declined(db)
	return db ~= nil and db.navigationOff == true
end

local function Settle(db, wanted)
	local now = Text()
	local value = Number(now)
	if value == nil then
		result = nil
		return nil, false
	end
	local ours = Ours(db, value)
	if not ours then
		if wanted and value == 0 and db and db.navigationOn == true then
			db.navigationOff = true
		end
		Forget(db)
	end
	local own = ours and Kept(db, "navigationGame") or now
	local ownValue = Number(own)
	local raise = wanted and ownValue == 0 and (ours or not Declined(db))
	local want = raise and 1 or ownValue
	if want == value then
		stuck, result = nil, wanted and "ok" or nil
		return value, false
	end
	if stuck and stuck.want == want and stuck.value == value then
		result = "refused"
		return value, false
	end
	local after = Write(raise and ON or own)
	local afterValue = Number(after)
	stuck = afterValue ~= want and { want = want, value = afterValue } or nil
	if raise then
		if db and afterValue ~= nil and afterValue ~= value then
			db.navigationGame, db.navigationWrote = own, after
		end
		result = afterValue == want and "ok" or "refused"
		return afterValue, false
	end
	if afterValue == want then
		Forget(db)
		restored, result = true, nil
		return afterValue, true
	end
	result = "refused"
	return afterValue, false
end

local function Apply()
	pending = false
	local db = Account()
	local wanted = Wanted()
	if wanted then
		restored = false
	end
	local value, back = Settle(db, wanted)
	if not db or value == nil then
		return
	end
	if wanted then
		db.navigationOn = value ~= 0 or nil
	elseif back then
		db.navigationOn = nil
	end
end

local function Queue()
	if pending then
		return
	end
	pending = true
	ns.OutOfCombat(Apply)
end

function ns.ErrandsNavigationChanged(path)
	local db = Account()
	if type(path) == "string" and db then
		db.navigationOff, db.navigationOn = nil, nil
	end
	Queue()
end

function ns.ErrandsNavigationCVar(name)
	if type(name) ~= "string" or ns.IsSecret(name) or name:lower() ~= CVAR:lower() or settling then
		return
	end
	settling = true
	local timer = type(C_Timer) == "table" and C_Timer.After or nil
	local ok = type(timer) == "function" and pcall(timer, SETTLE, function()
		settling = false
		Queue()
	end)
	if not ok then
		settling = false
		Queue()
	end
end

part.Start = Queue
part.Refresh = Queue

ns.AddStatus(KEY, function()
	local value = Number(Text())
	if value == nil then
		return {}
	end
	if pending then
		return { LABEL .. ": waiting for combat to end." }
	end
	local wanted = Wanted()
	if value == 0 then
		if wanted and Declined(Account()) then
			return { LABEL .. ": off. It was turned off outside Flat UI, with /console or by another addon, so Flat UI leaves it off until you change the row." }
		elseif wanted and result == "refused" then
			return { LABEL .. ": on, but the game kept it off." }
		end
		return { LABEL .. (restored and not wanted and ": off. Your own setting is back." or ": off.") }
	end
	if not wanted and result == "refused" then
		return { LABEL .. ": on. The game kept it on when Flat UI put your own setting back." }
	end
	if Ours(Account(), value) then
		return { LABEL .. ": on, turned on by Flat UI." }
	end
	return { LABEL .. ": on, as the game has it." }
end)
