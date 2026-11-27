local _, ns = ...

local KEY = "trackers"
local FILES = { raid = 567397, alarm = 567458, whisper = 876098 }
local THROTTLE = 1
local TRIGGERS = {
	{ row = "sound", trigger = "Removed", what = "a buff ending" },
	{ row = "comes", trigger = "Added", what = "a buff coming" },
	{ row = "stacks", trigger = "ApplicationsIncreased", what = "a buff stacking" },
}
local REFUSED = "Trackers: the game refused its sound for a buff ending, so the sound plays only when the buff can be read."
local REFUSED_MORE = "Trackers: the game refused its sound for a buff coming or stacking, so that sound plays only when the buff can be read."

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

local function Wanted(entry, only)
	local wants = {}
	if not Whole(entry) or entry.on == false then
		return wants
	end
	local unit = entry.kind == "debuff" and "target" or "player"
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

local RETRY = { "ADDON_RESTRICTION_STATE_CHANGED", "ENCOUNTER_END", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }

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

local function Withheld()
	local call = type(C_Secrets) == "table" and C_Secrets.ShouldAurasBeSecret
	if type(call) ~= "function" then
		return false
	end
	local ok, answer = pcall(call)
	return ok and not ns.IsSecret(answer) and answer == true
end

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

local function Silent()
	local names = {}
	for _, entry in ipairs(ns.Enabled(KEY) and type(ns.TrackerEntries) == "function" and ns.TrackerEntries() or {}) do
		if Whole(entry) and entry.on ~= false and not FILES[ns.TrackerValue(entry, "kit")] then
			for _, each in ipairs(TRIGGERS) do
				if ns.TrackerValue(entry, each.row) == true then
					names[#names + 1] = type(ns.TrackerLabel) == "function" and ns.TrackerLabel(entry) or tostring(entry.name)
					break
				end
			end
		end
	end
	return names
end

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
	local silent = Silent()
	if #silent > 0 then
		lines[#lines + 1] = ("Silent in a fight: %s, whose sound the game does not play; Raid warning, Alarm and Whisper warning play in a fight."):format(table.concat(silent, ", "))
	end
	return lines
end

if type(ns.AddStatus) == "function" then
	ns.AddStatus(KEY, function()
		return Lines(true)
	end)
end

ns.TrackerGameSound = { Sync = Sync, Taken = Taken, Lines = Lines }

function ns.TrackerSoundFile(word)
	return FILES[word]
end

function ns.TrackerKitInFights(word)
	return FILES[word] ~= nil
end

function ns.TrackerDropSoundIDs()
	local ids = {}
	for _, entry in ipairs(ns.Enabled(KEY) and type(ns.TrackerEntries) == "function" and ns.TrackerEntries() or {}) do
		for _, want in ipairs(Wanted(entry, "Removed")) do
			if want.unit == "player" and Plain(want.spellID) then
				ids[want.spellID] = true
			end
		end
	end
	return ids
end
