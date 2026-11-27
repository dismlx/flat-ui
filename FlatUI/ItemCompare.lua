local _, ns = ...

local KEY = "chat"
local CVAR = "alwaysCompareItems"
local OFF = "0"

local queued = false
local result = nil

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

local function Write(text)
	local cvar = Calls()
	if not cvar or type(cvar.SetCVar) ~= "function" then
		return false
	end
	pcall(cvar.SetCVar, CVAR, text)
	return Text() == text
end

local function Wanted()
	return ns.Enabled(KEY) and ns.Get(KEY .. ".compareShift") == true
end

local function Apply()
	queued = false
	local now, db = Text(), ns.Account()
	if now == nil or type(db) ~= "table" then
		return
	end
	if Wanted() then
		if now == OFF then
			result = "ok"
			return
		end
		if db.compareGame == nil then
			db.compareGame = now
		end
		if Write(OFF) then
			result = "ok"
			return
		end
		db.compareGame = nil
		result = "refused"
		return
	end
	result = nil
	local game = db.compareGame
	if type(game) ~= "string" then
		return
	end
	db.compareGame = nil
	if now == OFF and game ~= OFF then
		Write(game)
	end
end

function ns.ItemCompareHeld()
	return Wanted() and Text() == OFF
end

function ns.ItemCompareSync()
	if queued then
		return
	end
	queued = true
	ns.OutOfCombat(Apply)
end

ns.AddStatus(KEY, function()
	if not Wanted() or Text() == nil then
		return {}
	end
	if queued then
		return { "Compare items: only while holding Shift. Waiting for combat to end." }
	elseif result == "refused" then
		return { "Compare items: the game kept comparing without Shift." }
	end
	return { "Compare items: only while holding Shift." }
end)
