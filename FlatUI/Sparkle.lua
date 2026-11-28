local _, ns = ...

local LOOT = "outlineModeShowLootEffectWhenDisabled"
local VARS = {
	{ name = LOOT, key = "sparkleGame", kind = "loot" },
	{ name = "graphicsParticleDensity", key = "sparkleParticleGame", kind = "particle", label = "Particle Density" },
	{ name = "raidGraphicsParticleDensity", key = "sparkleRaidParticleGame", kind = "particle", raid = true, label = "raid Particle Density" },
	{ name = "graphicsSpellDensity", key = "sparkleSpellGame", kind = "spell", label = "Spell Density" },
	{ name = "raidGraphicsSpellDensity", key = "sparkleRaidSpellGame", kind = "spell", raid = true, label = "raid Spell Density" },
}
local STRENGTHS = { game = "As the game has it", strong = "Strong", strongest = "Strongest" }
local WATCHED = { graphicsquality = true, raidgraphicsquality = true }
for _, var in ipairs(VARS) do
	WATCHED[var.name:lower()] = true
end
local SETTLE = 1

local pending = false
local settling = false
local results = {}
local stuck = {}
local restored, graphicsBack = false, false

local function Calls()
	local cvar = _G.C_CVar
	if type(cvar) == "table" and not ns.IsSecret(cvar) then
		return cvar
	end
	return nil
end

local function Text(name)
	local cvar = Calls()
	if not cvar or type(cvar.GetCVar) ~= "function" then
		return nil
	end
	local ok, value = pcall(cvar.GetCVar, name)
	if ok and not ns.IsSecret(value) and type(value) == "string" then
		return value
	end
	return nil
end

local function Number(text)
	local number = type(text) == "string" and tonumber(text) or nil
	return ns.Finite(number) and number or nil
end

local function Wrote(var, db)
	local store = db and db.sparkleWrote
	local text = type(store) == "table" and store[var.name] or nil
	return type(text) == "string" and text or nil
end

local function KeepWrote(var, db, text)
	if not db then
		return
	end
	local store = type(db.sparkleWrote) == "table" and db.sparkleWrote or nil
	if store == nil and text ~= nil then
		store = {}
		db.sparkleWrote = store
	end
	if store then
		store[var.name] = text
		if next(store) == nil then
			db.sparkleWrote = nil
		end
	end
end

local function Write(name, text)
	local cvar = Calls()
	if not cvar or type(cvar.SetCVar) ~= "function" then
		return nil
	end
	pcall(cvar.SetCVar, name, text)
	return Text(name)
end

local function Video(name)
	local video = _G.C_VideoOptions
	local call = type(video) == "table" and not ns.IsSecret(video) and video[name] or nil
	if type(call) ~= "function" then
		return nil
	end
	local ok, answer = pcall(call)
	if ok and not ns.IsSecret(answer) then
		return answer
	end
	return nil
end

local function Wanted()
	return ns.Get("general.questSparkle") == true
end

local function Strength()
	local choice = ns.Get("general.sparkleStrength")
	return (choice == "strong" or choice == "strongest") and choice or nil
end

local function Offered(var, level)
	local check = _G.IsGraphicsSettingValueSupported
	if type(check) ~= "function" then
		return level
	end
	for value = level, 0, -1 do
		local ok, reason = pcall(check, var.name, value, var.raid == true)
		if not ok or ns.IsSecret(reason) or type(reason) ~= "number" or reason <= 0 then
			return value
		end
	end
	return nil
end

local function Target(var)
	if not Wanted() then
		return nil
	end
	if var.kind == "loot" then
		return 1
	end
	local strength = Strength()
	if strength == nil or Text(LOOT) == nil then
		return nil
	end
	local top
	if var.kind == "spell" then
		if Video("IsSpellVisualDensitySystemSupported") ~= true then
			return nil
		end
		top = 2
	else
		top = Video("IsSecondaryLightingSupported") == false and 5 or 4
	end
	return Offered(var, strength == "strongest" and top or top - 1)
end

local function Settle(var, db)
	local now = Text(var.name)
	local value = Number(now)
	if value == nil then
		results[var.name] = nil
		return
	end
	local kept = db and db[var.key]
	if type(kept) ~= "string" or Number(kept) == nil then
		kept = nil
	end
	local mine = Wrote(var, db) or (kept ~= nil and var.kind == "loot" and "1" or nil)
	local ours = kept ~= nil and Number(mine) == value and Number(kept) ~= value
	if not ours then
		kept = nil
		if db then
			db[var.key] = nil
		end
		KeepWrote(var, db, nil)
	end
	local own = ours and kept or now
	local ownValue = Number(own)
	local target = Target(var)
	if target ~= nil and var.kind ~= "loot" then
		graphicsBack = false
	end
	local raise = target ~= nil and ownValue < target
	local want = raise and target or ownValue
	if want == value then
		stuck[var.name] = nil
		results[var.name] = target ~= nil and "ok" or nil
		return
	end
	local block = stuck[var.name]
	if block and block.want == want and block.value == value then
		results[var.name] = target ~= nil and "refused" or nil
		return
	end
	local after = Write(var.name, raise and tostring(target) or own)
	local afterValue = Number(after)
	stuck[var.name] = afterValue ~= want and { want = want, value = afterValue } or nil
	if raise then
		if afterValue ~= nil and afterValue ~= value then
			if db then
				db[var.key] = own
			end
			KeepWrote(var, db, after)
		end
		results[var.name] = afterValue == target and "ok" or "refused"
		return
	end
	if afterValue == ownValue then
		if db then
			db[var.key] = nil
		end
		KeepWrote(var, db, nil)
		if var.kind == "loot" then
			restored = true
		else
			graphicsBack = true
		end
	end
	results[var.name] = target ~= nil and (afterValue == want and "ok" or "refused") or nil
end

local function Apply()
	pending = false
	if Text(LOOT) == nil then
		return
	end
	local db = type(FlatUIDB) == "table" and FlatUIDB or nil
	if Wanted() then
		restored = false
	end
	for _, var in ipairs(VARS) do
		Settle(var, db)
	end
end

local function Queue()
	if pending then
		return
	end
	pending = true
	ns.OutOfCombat(Apply)
end

function ns.SparkleChanged(path)
	Queue()
	if ns.SparkleGlowChanged then
		ns.SparkleGlowChanged(path)
	end
end

function ns.SparkleCVar(name)
	if type(name) ~= "string" or ns.IsSecret(name) or not WATCHED[name:lower()] then
		return
	end
	if settling then
		return
	end
	if C_Timer and C_Timer.After then
		settling = true
		C_Timer.After(SETTLE, function()
			settling = false
			Queue()
		end)
	else
		Queue()
	end
end

local function StrengthStatus()
	local any, refused = false, {}
	for _, var in ipairs(VARS) do
		if var.kind ~= "loot" and Text(var.name) ~= nil then
			any = true
			if results[var.name] == "refused" then
				refused[#refused + 1] = var.label
			end
		end
	end
	if not any then
		return nil
	end
	local strength = Strength()
	local line = "Sparkle strength: " .. STRENGTHS[strength or "game"] .. "."
	if #refused > 0 then
		local last = table.remove(refused)
		local names = #refused > 0 and (table.concat(refused, ", ") .. " and " .. last) or last
		line = line .. " The game kept its own " .. names .. "."
	end
	if strength == nil and graphicsBack then
		line = line .. " Your own graphics values are back."
	end
	return line
end

function ns.SparkleStatus()
	if Text(LOOT) == nil then
		return nil
	end
	if not Wanted() then
		local line = restored and "Quest item sparkle: off. The game's own value applies from its next start." or nil
		if graphicsBack then
			line = (line or "Quest item sparkle: off.") .. " Your own graphics values are back."
		end
		return line
	end
	local line
	if pending then
		line = "Quest item sparkle: on. Waiting for combat to end."
	elseif results[LOOT] == "refused" then
		line = "Quest item sparkle: on, but the game kept it off."
	else
		line = "Quest item sparkle: on."
	end
	local strength = StrengthStatus()
	return strength and (line .. " " .. strength) or line
end
