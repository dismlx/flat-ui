local _, ns = ...

-- Quest item sparkle and Sparkle strength (general.questSparkle and general.sparkleStrength on the Flat UI page, under World). On WoW: Forever a
-- quest item in the world, and as players see a gathering node, gets the game's loot effect, a sparkle, while the game's variable
-- outlineModeShowLootEffectWhenDisabled is 1. The game's options have no row for it on Forever: Blizzard_SettingsDefinitions_Frame/Camelot/
-- InterfaceOverrides.lua:5-6 leaves RegisterOutlineSettings empty, so only /console sets it. The variable and its behaviour are from players of
-- Forever (Quality-of-Life-Forever pull request 167, ForeverLootSparkles), not from the client's source.
-- Sparkle strength thickens that sparkle with the game's own graphics variables that its Graphics options show as Particle Density
-- (graphicsParticleDensity, "the number of particles used in effects": Disabled 0 to Ultra 5, or Low 0 to Ultra 4 where
-- C_VideoOptions.IsSecondaryLightingSupported says so, Blizzard_SettingsDefinitions_Shared/Graphics.lua:179-200) and Spell Density
-- (graphicsSpellDensity: Essential 0, Reduced 1, Everything 2, Graphics.lua:246-256, offered only where
-- C_VideoOptions.IsSpellVisualDensitySystemSupported says so, Graphics.lua:121-124 and 474-478), with their raid twins
-- raidGraphicsParticleDensity and raidGraphicsSpellDensity, which the game uses with its raid settings (Blizzard_Settings_Shared/Mainline/
-- GraphicsOverrides.lua:3-62, which Forever loads: Blizzard_Settings_Shared.toc:33). None of the five is secure, locked or read-only (cvars.yaml of
-- build 70790: 2283, 2293, 3100, 3378, 3388). Strong raises each to the level under the top (High, and Reduced), Strongest to the top (Ultra, and
-- Everything), at most to the highest level the client offers for that variable, as the options grey out a level the computer cannot take
-- (IsGraphicsSettingValueSupported gives the number of the reason, 0 for none: Graphics.lua:101-106). A variable is only ever raised: a value at
-- or above that level stays as it is. As the game has it writes none of them. Only the tooltip of Particle Density ("the number of particles used
-- in effects caused by spells, fires, etc.") ties a variable to an effect like the sparkle: neither the client's source nor a player says how much
-- a lower level thins the sparkle, so how much a higher one gives back wants a look in game. No variable in the client's list sizes or brightens
-- the sparkle itself, and the outline variables show an outline in its place rather than a stronger sparkle (ForeverLootSparkles' notes), so they
-- are left alone.
-- Every write is made out of combat: at login, when a row or the profile changes, and a second after the game writes its graphics quality
-- (graphicsQuality, raidGraphicsQuality) or one of these variables, as a graphics preset puts its own values back; a write the game does not keep
-- is not tried again until the value asked or the game's value changes, and /flatui status says so. The text a variable had before
-- Flat UI's write is kept for the account in FlatUIDB (sparkleGame, sparkleParticleGame, sparkleRaidParticleGame, sparkleSpellGame,
-- sparkleRaidSpellGame), and the text Flat UI wrote beside it (FlatUIDB.sparkleWrote, by variable): the value in place is Flat UI's only while it
-- is that text, so a value the game or the player writes since is the game's own from then on, also one written while Flat UI did not run (at
-- the character screen, with Flat UI off, or by another account on this computer, whose graphics settings are the computer's). 0.5.13 kept the
-- loot variable's text alone, and wrote 1 there. When the rows no longer need a variable (Quest item sparkle off, or Sparkle strength at As the
-- game has it), the kept text is written back while the variable still holds what Flat UI wrote, and forgotten; a value changed by hand meanwhile
-- stays. The client applies the loot variable at its next start, and an object already in view keeps its look until it appears again. Every
-- change of the rows also reaches Glow on the nearest object (SparkleGlow.lua).

local LOOT = "outlineModeShowLootEffectWhenDisabled"
-- The variables, in the order they are written. key: the field of FlatUIDB that keeps the game's own text. kind: what sets the level the rows ask.
-- raid: the raid twin, checked as a raid setting. label: the name the game's options give it, for /flatui status.
local VARS = {
	{ name = LOOT, key = "sparkleGame", kind = "loot" },
	{ name = "graphicsParticleDensity", key = "sparkleParticleGame", kind = "particle", label = "Particle Density" },
	{ name = "raidGraphicsParticleDensity", key = "sparkleRaidParticleGame", kind = "particle", raid = true, label = "raid Particle Density" },
	{ name = "graphicsSpellDensity", key = "sparkleSpellGame", kind = "spell", label = "Spell Density" },
	{ name = "raidGraphicsSpellDensity", key = "sparkleRaidSpellGame", kind = "spell", raid = true, label = "raid Spell Density" },
}
-- The words of the choices of Sparkle strength.
local STRENGTHS = { game = "As the game has it", strong = "Strong", strongest = "Strongest" }
-- The variables whose change is followed by a write: the graphics quality presets, and the variables themselves.
local WATCHED = { graphicsquality = true, raidgraphicsquality = true }
for _, var in ipairs(VARS) do
	WATCHED[var.name:lower()] = true
end
-- The wait after a watched change, so that a preset has written all of its values first.
local SETTLE = 1

-- A write waits for combat to end.
local pending = false
-- A write waits for SETTLE seconds.
local settling = false
-- How the last write of each variable ended while a row asked for it, by name: nil when nothing was asked, "ok" or "refused".
local results = {}
-- A write the game did not keep, by name: the value asked and the value the game kept. It is not asked again until one of them changes, so a
-- variable the game holds at another value is not written again at each change it announces.
local stuck = {}
-- True once the game's own loot value was put back in this session, and once a graphics value was.
local restored, graphicsBack = false, false

local function Calls()
	local cvar = _G.C_CVar
	if type(cvar) == "table" and not ns.IsSecret(cvar) then
		return cvar
	end
	return nil
end

-- The text of a variable, or nil when the client has no such variable or withholds it.
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

-- The number in a text, or nil.
local function Number(text)
	local number = type(text) == "string" and tonumber(text) or nil
	return ns.Finite(number) and number or nil
end

-- The text Flat UI wrote in a variable and kept for the account (FlatUIDB.sparkleWrote, by name), or nil.
local function Wrote(var, db)
	local store = db and db.sparkleWrote
	local text = type(store) == "table" and store[var.name] or nil
	return type(text) == "string" and text or nil
end

-- Keeps the text Flat UI wrote in a variable, or forgets it with nil; the table goes once it is empty.
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

-- Writes the text and gives the text the variable holds after it, or nil when the client cannot be asked.
local function Write(name, text)
	local cvar = Calls()
	if not cvar or type(cvar.SetCVar) ~= "function" then
		return nil
	end
	pcall(cvar.SetCVar, name, text)
	return Text(name)
end

-- The answer of a function of C_VideoOptions, or nil when the client lacks it, raises or withholds the answer.
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

-- "strong" or "strongest", or nil for As the game has it.
local function Strength()
	local choice = ns.Get("general.sparkleStrength")
	return (choice == "strong" or choice == "strongest") and choice or nil
end

-- The highest level at or under level that the client offers for the variable, or nil when it offers none.
local function Offered(var, level)
	local check = _G.IsGraphicsSettingValueSupported
	if type(check) ~= "function" then
		return level
	end
	for value = level, 0, -1 do
		local ok, reason = pcall(check, var.name, value, var.raid == true)
		-- A call that fails, or an answer that is no number above 0, says nothing against the level.
		if not ok or ns.IsSecret(reason) or type(reason) ~= "number" or reason <= 0 then
			return value
		end
	end
	return nil
end

-- The value the rows ask of a variable at least, or nil when they do not need it.
local function Target(var)
	if not Wanted() then
		return nil
	end
	if var.kind == "loot" then
		return 1
	end
	local strength = Strength()
	-- The strength only thickens the loot sparkle, so a client without that variable gets none of these writes.
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
		-- Ultra is 5 without secondary lighting and 4 with it; a client that does not say gets the lower of the two.
		top = Video("IsSecondaryLightingSupported") == false and 5 or 4
	end
	return Offered(var, strength == "strongest" and top or top - 1)
end

-- Brings one variable to what the rows ask: raised to their level with the game's own text kept, or that text written back.
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
	-- What Flat UI wrote; 0.5.13 kept the loot variable's text without it, and wrote 1.
	local mine = Wrote(var, db) or (kept ~= nil and var.kind == "loot" and "1" or nil)
	-- The value in place is Flat UI's while it is the text Flat UI wrote, and not the game's own text again.
	local ours = kept ~= nil and Number(mine) == value and Number(kept) ~= value
	if not ours then
		-- The game or the player wrote the value in place, also while Flat UI did not run, so it is the game's own, and a text kept before it
		-- is no longer.
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
			-- The write took, whole or in part: what is in place is Flat UI's, and the game's own text is kept beside it.
			if db then
				db[var.key] = own
			end
			KeepWrote(var, db, after)
		end
		results[var.name] = afterValue == target and "ok" or "refused"
		return
	end
	-- The game's own text is back.
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

-- Nothing is written in combat.
local function Queue()
	if pending then
		return
	end
	pending = true
	ns.OutOfCombat(Apply)
end

-- A row, a profile switch and the login. Glow on the nearest object follows the same rows.
function ns.SparkleChanged()
	Queue()
	if ns.SparkleGlowChanged then
		ns.SparkleGlowChanged()
	end
end

-- A change of a variable (CVAR_UPDATE gives its name and its new text). A watched one is written again a second later.
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

-- What /flatui status says of the strength, or nil when the client has none of its variables.
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

-- The line of /flatui status, or nil when there is nothing to say: the client has no such variable, or the row is off and nothing was put back.
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
