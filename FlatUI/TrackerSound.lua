local _, ns = ...

-- The game's own sound for a buff or debuff tracker's aura ending, coming or stacking. A tracker gets one registration with the game for each of
-- its listed spell IDs and each of its sound rows that is on (C_UnitAuras.AddAuraSound, UnitAuraDocumentation.lua:11-27): trigger Removed for Sound
-- when it drops, Added for Sound when it comes and ApplicationsIncreased for Sound when it stacks (Enum.UnitAuraSoundTrigger,
-- UnitAuraConstantsDocumentation.lua:6-17), so the sound plays in a fight where the aura cannot be read: the game plays a registered sound even
-- where it withholds the aura from addons. A tracker whose IDs are all registered for a trigger does not play its own sound for that trigger. A
-- registration the game refuses is not kept, and that tracker keeps its own sound for the changes it can read. AddAuraSound has restrictions
-- (HasRestrictions), so the registrations change only out of combat and, as EnhanceQoL waits, not while the game says aura values are withheld
-- (C_Secrets.ShouldAurasBeSecret, SecretPredicateAPIDocumentation.lua:119-127). A Sync in a fight runs after it; one that waits for aura values
-- is tried again on a frame of this file's own, whether the page is on or off, so a page turned off while they are withheld still takes its
-- registrations back once they are open. This file is no module of its own: Trackers.lua calls ns.TrackerGameSound. The sounds of an aura that
-- comes or stacks, and the wait, follow the Cooldown Panels of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission
-- (EnhanceQoLCooldownPanels/CooldownPanels_AuraContainers.lua:78-94, the three triggers, and 1464-1590, the registrations and their retry).

local KEY = "trackers"
-- The file of each sound kit a tracker can play, by its saved word: kits 8959, 12889 and 37666.
local FILES = { raid = 567397, alarm = 567458, whisper = 876098 }
local THROTTLE = 1
-- The sound rows of a tracker, the trigger of the game's each stands for and its words in the check, in the order of the check's lines.
local TRIGGERS = {
	{ row = "sound", trigger = "Removed", what = "a buff ending" },
	{ row = "comes", trigger = "Added", what = "a buff coming" },
	{ row = "stacks", trigger = "ApplicationsIncreased", what = "a buff stacking" },
}
local REFUSED = "Trackers: the game refused its sound for a buff ending, so the sound plays only when the buff can be read."
local REFUSED_MORE = "Trackers: the game refused its sound for a buff coming or stacking, so that sound plays only when the buff can be read."

-- registered: by key (trigger:unit:spellID), { id, file, trigger }. refused: the triggers the game refused at the last Sync that changed anything.
-- pending: a Sync waits for aura values to be open. waiter: the frame that hears when to try it again (Wait).
local registered = {}
local refused = {}
local queued, pending = false, false
local waiter
local Sync

local function Plain(value)
	return type(value) == "number" and not ns.IsSecret(value)
end

local function Whole(entry)
	return type(entry) == "table" and (entry.kind == nil or entry.kind == "buff" or entry.kind == "debuff") and type(entry.spells) == "table"
end

-- The registrations one tracker wants, as a list of { key, trigger, unit, spellID, file }: none when it is off or its rows are off. only: one
-- trigger alone.
local function Wanted(entry, only)
	local wants = {}
	if not Whole(entry) or entry.on == false then
		return wants
	end
	local unit = entry.kind == "debuff" and "target" or "player"
	-- A kit with no file of its own (Spell alert, Chimes, Bell, Warhorn) is not registered: the tracker plays it itself.
	local file = FILES[ns.TrackerValue(entry, "kit")]
	if not file then
		return wants
	end
	for _, each in ipairs(TRIGGERS) do
		if (only == nil or only == each.trigger) and ns.TrackerValue(entry, each.row) == true then
			for _, spellID in ipairs(entry.spells) do
				wants[#wants + 1] = { key = each.trigger .. ":" .. unit .. ":" .. spellID, trigger = each.trigger, unit = unit, spellID = spellID, file = file }
			end
		end
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

-- When a Sync that waits for aura values to be open is tried again: a restriction that changes (fired after one ends,
-- RestrictedActionsDocumentation.lua:97-107), the end of an encounter or of a fight, and a loading screen, as EnhanceQoL asks again
-- (SoundLifecycle.RequestRetry, CooldownPanels_AuraContainers.lua:1470-1482).
local RETRY = { "ADDON_RESTRICTION_STATE_CHANGED", "ENCOUNTER_END", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }

-- The wait: a frame of this file's own, made the first time a Sync waits, hears those events while one waits and only then, and whether the page
-- is on or off, since Core.lua runs a module's events only while it is on. Its Sync (Later) wants nothing while the page is off, so the
-- registrations are taken back once aura values are open, as EnhanceQoL's Flush does with the removals that waited (1575-1590).
local function Wait(on)
	if on == pending then
		return
	end
	pending = on
	if on and not waiter then
		waiter = CreateFrame("Frame")
		ns.Own[waiter] = true
		waiter:SetScript("OnEvent", function()
			if pending then
				local ok, err = pcall(Later)
				if not ok then
					geterrorhandler()(err)
				end
			end
		end)
	end
	local method = waiter and (on and waiter.RegisterEvent or waiter.UnregisterEvent)
	for _, event in ipairs(method and RETRY or {}) do
		pcall(method, waiter, event)
	end
end

-- True while the game plainly says aura values are withheld: no registration changes then (EnhanceQoL's
-- SoundLifecycle.CanChangeRegistrations, CooldownPanels_AuraContainers.lua:1464-1468).
local function Withheld()
	local call = type(C_Secrets) == "table" and C_Secrets.ShouldAurasBeSecret
	if type(call) ~= "function" then
		return false
	end
	local ok, answer = pcall(call)
	return ok and not ns.IsSecret(answer) and answer == true
end

-- Makes the registrations match the trackers: removes the ones no tracker wants, adds the missing ones. In a fight nothing is changed and
-- one Sync is asked for after it; while aura values are withheld nothing is changed either, and the Sync waits for them to open.
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
	local changes = false
	for key, made in pairs(registered) do
		changes = changes or not wanted[key] or wanted[key].file ~= made.file
	end
	for key in pairs(wanted) do
		changes = changes or not registered[key]
	end
	if not changes then
		Wait(false)
		refused = {}
		return
	end
	if Withheld() then
		Wait(true)
		return
	end
	Wait(false)
	for key, made in pairs(registered) do
		if not wanted[key] or wanted[key].file ~= made.file then
			Drop(key)
		end
	end
	refused = {}
	local call = type(C_UnitAuras) == "table" and C_UnitAuras.AddAuraSound
	local triggers = Enum and Enum.UnitAuraSoundTrigger
	for key, want in pairs(wanted) do
		if not registered[key] then
			local ok, id = pcall(call, triggers and triggers[want.trigger], { unitToken = want.unit, spellID = want.spellID, soundFileID = want.file,
				outputChannel = "Master", throttleSeconds = THROTTLE })
			if ok and Plain(id) then
				registered[key] = { id = id, file = want.file, trigger = want.trigger }
			else
				refused[want.trigger] = true
			end
		end
	end
	if refused.Removed then
		ns.Note(KEY, REFUSED)
	end
	if refused.Added or refused.ApplicationsIncreased then
		ns.Note(KEY, REFUSED_MORE)
	end
end

-- True when the tracker's row of a trigger is on and the game has every one of its listed IDs registered with the tracker's kit for it. trigger:
-- Removed (the drop, when none is given), Added or ApplicationsIncreased.
local function Taken(entry, trigger)
	local wants = Wanted(entry, trigger or "Removed")
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

-- The lines of /flatui tracker check: the spell IDs registered for each trigger, or its refusal. counted: the registrations alone, for /flatui
-- status, where a refusal is a note already.
local function Lines(counted)
	local counts = {}
	for _, made in pairs(registered) do
		counts[made.trigger] = (counts[made.trigger] or 0) + 1
	end
	local lines = {}
	for _, each in ipairs(TRIGGERS) do
		local count = counts[each.trigger] or 0
		if count > 0 then
			lines[#lines + 1] = ("Game's sound for %s: on for %d spell ID%s."):format(each.what, count, count == 1 and "" or "s")
		elseif refused[each.trigger] and not counted then
			lines[#lines + 1] = ("Game's sound for %s: refused by the game."):format(each.what)
		end
	end
	return lines
end

-- /flatui status counts the registrations by trigger under Trackers, also while the page is off and some wait to be taken back.
if type(ns.AddStatus) == "function" then
	ns.AddStatus(KEY, function()
		return Lines(true)
	end)
end

ns.TrackerGameSound = { Sync = Sync, Taken = Taken, Lines = Lines }
