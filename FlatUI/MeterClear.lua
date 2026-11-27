local _, ns = ...

local KEY, PART = "hud", "damage meter clear"
local ROW, BOSS_ROW = "hud.meterClear", "hud.meterClearBoss"
local POPUP = "FLATUI_METER_CLEAR"
local DELAY, AWAY = 2, 3600
local ASKS = { party = "Clear the damage meter for this dungeon?", raid = "Clear the damage meter for this raid?" }
local PLACES = { party = "a dungeon", raid = "a raid" }

local M = { token = 0, pending = nil, on = false, asked = false, refused = false }

local function Choice()
	local choice = ns.Get(ROW)
	return (choice == "enter" or choice == "ask") and choice or nil
end

local function Wanted()
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and Choice() ~= nil
end

local function Whole(value)
	return ns.Finite(value) and value >= 0 and value == math.floor(value)
end

local function Now()
	if type(GetServerTime) ~= "function" then
		return nil
	end
	local ok, now = pcall(GetServerTime)
	return ok and ns.Finite(now) and now or nil
end

local function Saved(make)
	local char = ns.Character()
	if type(char) ~= "table" then
		return nil
	end
	local saved = char.meterClear
	if type(saved) ~= "table" then
		if not make then
			return nil
		end
		saved = {}
		char.meterClear = saved
	end
	if not Whole(saved.instance) then
		saved.instance = nil
	end
	if not ns.Finite(saved.left) then
		saved.left = nil
	end
	if not ns.Finite(saved.seen) then
		saved.seen = nil
	end
	local last = saved.last
	if type(last) ~= "table" or not ns.Finite(last.at) or type(last.where) ~= "string" or (last.boss ~= nil and type(last.boss) ~= "string") then
		saved.last = nil
	end
	return saved
end

local function Where()
	if type(IsInInstance) ~= "function" or type(GetInstanceInfo) ~= "function" then
		return nil
	end
	local ok, inside, kind = pcall(IsInInstance)
	if not ok or ns.IsSecret(inside) or ns.IsSecret(kind) or inside ~= true or (kind ~= "party" and kind ~= "raid") then
		return nil
	end
	local got, name, _, _, _, _, _, _, id = pcall(GetInstanceInfo)
	if not got or not Whole(id) then
		return nil
	end
	if ns.IsSecret(name) or type(name) ~= "string" or name == "" then
		name = nil
	end
	return kind, id, name
end

local function Meter()
	local meter = C_DamageMeter
	if type(meter) ~= "table" or ns.IsSecret(meter) or type(meter.ResetAllCombatSessions) ~= "function" then
		return nil
	end
	return meter
end

local function Available()
	local meter = Meter()
	if meter == nil or type(meter.IsDamageMeterAvailable) ~= "function" then
		return false
	end
	local ok, yes = pcall(meter.IsDamageMeterAvailable)
	return ok and not ns.IsSecret(yes) and yes == true
end

local function Clear(where, boss)
	local meter = Meter()
	if meter == nil or not pcall(meter.ResetAllCombatSessions) then
		M.refused = true
		return false
	end
	M.refused = false
	local saved, now = Saved(true), Now()
	if saved and now then
		saved.last = { at = now, where = where, boss = boss }
	end
	return true
end

local function Word(name, fallback)
	local text = _G[name]
	if type(text) == "string" and not ns.IsSecret(text) and text ~= "" then
		return text
	end
	return fallback
end

local function Accepted(_, data)
	M.asked = false
	if not Wanted() then
		print("Flat UI: Clear the damage meter is off, so the damage meter keeps its numbers.")
		return
	end
	if type(data) ~= "table" then
		return
	end
	local _, id = Where()
	if id == nil or id ~= data.id then
		print("Flat UI: you are no longer in that instance, so the damage meter keeps its numbers.")
		return
	end
	Clear(data.where)
end

local function Register()
	local list = StaticPopupDialogs
	if type(list) ~= "table" or ns.IsSecret(list) then
		return false
	end
	if list[POPUP] == nil then
		list[POPUP] = {
			text = "%s",
			button1 = Word("YES", "Yes"),
			button2 = Word("NO", "No"),
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			OnAccept = function(_, data)
				ns.EachPart(KEY, PART, Accepted, {}, data)
			end,
		}
	end
	return true
end

local function Unask()
	if not M.asked then
		return
	end
	local errands = ns.Errands
	if type(errands) ~= "table" or type(errands.Popups) ~= "function" or type(errands.HideAlone) ~= "function" then
		M.asked = false
		return
	end
	local up = false
	for _, popup in ipairs(errands.Popups()) do
		up = up or popup.which == POPUP
	end
	M.asked = up and not errands.HideAlone(POPUP)
end

local function Ask(kind, id, where)
	Unask()
	if type(StaticPopup_Show) ~= "function" or not Register() then
		return
	end
	local ok, popup = pcall(StaticPopup_Show, POPUP, ASKS[kind], nil, { id = id, where = where })
	M.asked = M.asked or (ok and popup ~= nil and popup ~= false)
end

local function Due(_, token, kind, id, where)
	if token ~= M.token then
		return
	end
	M.pending = nil
	if not Wanted() then
		return
	end
	local _, here = Where()
	if here ~= id or not Available() then
		return
	end
	local saved = Saved(true)
	if saved then
		saved.instance, saved.left, saved.seen = id, nil, Now()
	end
	if Choice() == "ask" then
		Ask(kind, id, where)
	else
		Clear(where)
	end
end

local function Away(saved)
	local now = Now()
	return saved.left ~= nil and now ~= nil and now - saved.left >= AWAY
end

local function Entered()
	local saved = Saved(true)
	local kind, id, name = Where()
	if kind == nil then
		M.token, M.pending = M.token + 1, nil
		Unask()
		if saved and saved.instance ~= nil and saved.left == nil then
			saved.left = Now()
		end
		return
	end
	if M.pending == id then
		return
	end
	if saved and saved.instance == id and not Away(saved) then
		saved.left, saved.seen = nil, Now()
		return
	end
	if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		return
	end
	M.token = M.token + 1
	M.pending = id
	local token, where = M.token, name or PLACES[kind]
	if not pcall(C_Timer.After, DELAY, function()
		ns.EachPart(KEY, PART, Due, {}, token, kind, id, where)
	end) then
		M.pending = nil
	end
end

local function Pulled(_, _, encounterName)
	if ns.Get(BOSS_ROW) ~= true or type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		return
	end
	local kind, _, name = Where()
	if kind ~= "raid" or not Available() then
		return
	end
	local boss = not ns.IsSecret(encounterName) and type(encounterName) == "string" and encounterName ~= "" and encounterName or nil
	local where = name or PLACES.raid
	pcall(C_Timer.After, 0, function()
		ns.EachPart(KEY, PART, function()
			if Wanted() and ns.Get(BOSS_ROW) == true then
				Clear(where, boss)
			end
		end, {})
	end)
end

local function Seen(saved)
	if saved == nil or saved.instance == nil or saved.left ~= nil then
		return
	end
	local _, id = Where()
	if id ~= nil and id == saved.instance then
		saved.seen = Now() or saved.seen
	end
end

local function Apply()
	local on = Wanted()
	if on and not M.on then
		local saved = Saved(true)
		local kind, id = Where()
		if saved and kind ~= nil then
			saved.instance, saved.left, saved.seen = id, nil, Now()
		elseif saved and saved.instance ~= nil and saved.left == nil then
			saved.left = saved.seen or Now()
		end
	elseif not on then
		if M.on then
			Seen(Saved(false))
		end
		M.token, M.pending = M.token + 1, nil
		Unask()
	end
	M.on = on
end

local function Heard()
	return Wanted()
end
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
	ns.AddEvent(KEY, event, function()
		ns.EachPart(KEY, PART, Entered, {})
	end, Heard)
end
ns.AddEvent(KEY, "ENCOUNTER_START", function(...)
	ns.EachPart(KEY, PART, Pulled, {}, ...)
end, Heard)
ns.AddEvent(KEY, "PLAYER_LOGOUT", function()
	ns.EachPart(KEY, PART, function()
		Seen(Saved(false))
	end, {})
end, Heard)

local function Ago(at)
	local now = Now()
	local seconds = now and math.max(0, now - at) or 0
	if seconds < 60 then
		return "less than a minute ago"
	elseif seconds < 3600 then
		local minutes = math.floor(seconds / 60)
		return minutes == 1 and "a minute ago" or minutes .. " minutes ago"
	elseif seconds < 86400 then
		local hours = math.floor(seconds / 3600)
		return hours == 1 and "an hour ago" or hours .. " hours ago"
	end
	local days = math.floor(seconds / 86400)
	return days == 1 and "a day ago" or days .. " days ago"
end

ns.AddStatus(KEY, function()
	local lines = {}
	if not Wanted() then
		return lines
	end
	if Meter() == nil then
		lines[1] = "Damage meter: this client has no damage meter to clear."
		return lines
	end
	if M.refused then
		lines[#lines + 1] = "Damage meter: the game refused the last clear, so it keeps its numbers."
	end
	local saved = Saved(false)
	local last = saved and saved.last
	if last then
		lines[#lines + 1] = ("Damage meter: last cleared %s in %s%s."):format(Ago(last.at), last.where, last.boss and (" at the pull of " .. last.boss) or "")
	else
		lines[#lines + 1] = "Damage meter: Flat UI has not cleared it yet."
	end
	return lines
end)

function ns.MeterClearRefresh()
	if not ns.PartStopped(KEY, PART) then
		ns.EachPart(KEY, PART, Apply, {})
	end
	if ns.PartStopped(KEY, PART) then
		pcall(Apply)
	end
end
