local _, ns = ...

-- The game's own sound for a buff or debuff tracker's aura ending. A tracker with Sound when it drops on gets one registration with the
-- game for each of its listed spell IDs (C_UnitAuras.AddAuraSound, trigger Removed), so the sound plays in a fight where the aura cannot be
-- read. A tracker whose IDs are all registered does not play its own drop sound. A registration the game refuses is not kept, and that
-- tracker keeps its own sound for the drops it can read. This file is no module of its own: Trackers.lua calls ns.TrackerGameSound.

local KEY = "trackers"
-- The file of each sound kit a tracker can play, by its saved word: kits 8959, 12889 and 37666.
local FILES = { raid = 567397, alarm = 567458, whisper = 876098 }
local THROTTLE = 1
local REFUSED = "Trackers: the game refused its sound for a buff ending, so the sound plays only when the buff can be read."

local registered = {}
local refused = false
local queued = false
local Sync

local function Plain(value)
	return type(value) == "number" and not ns.IsSecret(value)
end

local function Whole(entry)
	return type(entry) == "table" and (entry.kind == nil or entry.kind == "buff" or entry.kind == "debuff") and type(entry.spells) == "table"
end

-- The registrations one tracker wants, as a list of { key, unit, spellID, file }; none when its sound is off or it is off.
local function Wanted(entry)
	local wants = {}
	if not Whole(entry) or entry.on == false or ns.TrackerValue(entry, "sound") ~= true then
		return wants
	end
	local unit = entry.kind == "debuff" and "target" or "player"
	local file = FILES[ns.TrackerValue(entry, "kit")] or FILES.raid
	for _, spellID in ipairs(entry.spells) do
		wants[#wants + 1] = { key = unit .. ":" .. spellID, unit = unit, spellID = spellID, file = file }
	end
	return wants
end

local function Drop(key)
	local made = registered[key]
	registered[key] = nil
	if made and type(C_UnitAuras) == "table" and type(C_UnitAuras.RemoveAuraSound) == "function" then
		pcall(C_UnitAuras.RemoveAuraSound, made.id)
	end
end

local function Later()
	if queued then
		return
	end
	queued = true
	ns.OutOfCombat(function()
		queued = false
		Sync(ns.Enabled(KEY) and ns.TrackerEntries and ns.TrackerEntries() or {})
	end)
end

-- Makes the registrations match the trackers: removes the ones no tracker wants, adds the missing ones. In a fight nothing is changed and
-- one Sync is asked for after it.
function Sync(entries)
	if InCombatLockdown() then
		Later()
		return
	end
	local wanted = {}
	for _, entry in ipairs(entries or {}) do
		for _, want in ipairs(Wanted(entry)) do
			wanted[want.key] = wanted[want.key] or want
		end
	end
	for key, made in pairs(registered) do
		if not wanted[key] or wanted[key].file ~= made.file then
			Drop(key)
		end
	end
	refused = false
	local call = type(C_UnitAuras) == "table" and C_UnitAuras.AddAuraSound
	local trigger = Enum and Enum.UnitAuraSoundTrigger and Enum.UnitAuraSoundTrigger.Removed
	for key, want in pairs(wanted) do
		if not registered[key] then
			local ok, id = pcall(call, trigger, { unitToken = want.unit, spellID = want.spellID, soundFileID = want.file,
				outputChannel = "Master", throttleSeconds = THROTTLE })
			if ok and Plain(id) then
				registered[key] = { id = id, file = want.file }
			else
				refused = true
			end
		end
	end
	if refused then
		ns.Note(KEY, REFUSED)
	end
end

-- True when the tracker's sound is on and the game has every one of its listed IDs registered with the tracker's kit.
local function Taken(entry)
	local wants = Wanted(entry)
	if #wants == 0 then
		return false
	end
	for _, want in ipairs(wants) do
		local made = registered[want.key]
		if not made or made.file ~= want.file then
			return false
		end
	end
	return true
end

local function Lines()
	local count = 0
	for _ in pairs(registered) do
		count = count + 1
	end
	if count > 0 then
		return { ("Game's sound for a buff ending: on for %d spell ID%s."):format(count, count == 1 and "" or "s") }
	elseif refused then
		return { "Game's sound for a buff ending: refused by the game." }
	end
	return {}
end

ns.TrackerGameSound = { Sync = Sync, Taken = Taken, Lines = Lines }
