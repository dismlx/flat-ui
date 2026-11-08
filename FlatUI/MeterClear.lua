local _, ns = ...

-- Clear the damage meter: hud.meterClear on the Tracker, loot and alerts tab (Off, the default; When you enter a dungeon or raid; Ask when you
-- enter one) with At each raid boss (hud.meterClearBoss, off), part "damage meter clear" of Minimap and buffs, which stops alone after a few
-- failures. Not a module: Hud.lua calls ns.MeterClearRefresh in every refresh of the page, and the events come through that module (ns.AddEvent),
-- so nothing is heard while the page is off.
-- The game's meter (Blizzard_DamageMeter, loaded at start on the standard and camelot clients: Blizzard_DamageMeter.toc:2) keeps its numbers until
-- the player clears them from its own menu, which calls C_DamageMeter.ResetAllCombatSessions (DamageMeterSessionWindow.lua:506-507). Flat UI makes
-- the same call, which the documentation lists with no protection or restriction (DamageMeterDocumentation.lua:123-127), and the game's windows
-- draw themselves again on DAMAGE_METER_RESET (DamageMeterSessionWindow.lua:95, 204). On PLAYER_ENTERING_WORLD and ZONE_CHANGED_NEW_AREA, when
-- IsInInstance says the player is in a dungeon or a raid ("party" or "raid": InstanceDocumentation.lua:170-178) and C_DamageMeter.IsDamageMeterAvailable
-- plainly says yes (DamageMeterDocumentation.lua:112-122), it waits 2 seconds and clears, or with Ask shows a popup of Flat UI's own, an entry of
-- StaticPopupDialogs shown with StaticPopup_Show (Blizzard_StaticPopup/StaticPopup.lua:309-325), as Clean up bags does (BagSort.lua), whose Yes
-- clears while the player is still in that instance. As Clean up bags' popup, it has no OnHide, so a No or an Escape runs no code of Flat UI's
-- (StaticPopup_OnHide calls a popup's OnHide directly and then rewrites the game's list of shown popups: StaticPopup.lua:630-664). Once the player
-- has left that instance or the rows no longer ask, Flat UI hides it with StaticPopup_Hide only while it is the one popup shown, as Errands hides
-- the game's (Errands.HideAlone): beside another one it stays up, since the game renews that list securely only once it is empty
-- (StaticPopup.lua:89-104), and its Yes then clears nothing. The instance is known by the 8th answer of GetInstanceInfo, its instance ID
-- (InstanceDocumentation.lua:103-120), kept in FlatUICharDB.meterClear with the time the player left it by the realm's clock (GetServerTime,
-- SystemTimeDocumentation.lua:30-37): a /reload inside, or a run back after a wipe, does not clear again; another instance does, and so does the
-- same one after an hour away. The instance the player is in when the row goes on, or at login, counts as entered already, so turning the row on
-- inside a dungeon clears nothing. A player found outside then, after a logout inside it or with the rows off, has been away since Flat UI last
-- saw them inside it (on entering, at the logout, as the rows went off). With At each raid boss, ENCOUNTER_START in a raid clears without
-- asking, on the next frame, outside the game's synchronous dispatch of that event (EncounterInfoDocumentation.lua:53-64). That clear runs in
-- the fight, which the documentation allows, though no code of the game's on Forever clears there. A withheld or failed answer counts as no
-- instance, so nothing is cleared, and every client call is in a pcall. /flatui status names the last clear and where it happened.
-- This follows the automatic clear of EnhanceQoL's damage meter by Philipp Barth (R41Z0R), adapted with his permission
-- (EnhanceQoLDamageMeter/DamageMeter.lua:42-43, 100, 1700-1712, 7665-7674 and 7696-7803): its Never, Ask and Always, its 2 seconds, its instance
-- key and its clear at a raid boss's pull. Flat UI clears the game's own meter, keeps the instance across a reload and waits for an hour away
-- before the same one clears again.

local KEY, PART = "hud", "damage meter clear"
local ROW, BOSS_ROW = "hud.meterClear", "hud.meterClearBoss"
local POPUP = "FLATUI_METER_CLEAR"
-- Seconds after entering before the clear (EnhanceQoLDamageMeter/DamageMeter.lua:100), and the seconds away after which the same instance clears again.
local DELAY, AWAY = 2, 3600
local ASKS = { party = "Clear the damage meter for this dungeon?", raid = "Clear the damage meter for this raid?" }
local PLACES = { party = "a dungeon", raid = "a raid" }

-- token: counts the clears asked for, so one that a later event or a change of the rows has made stale does nothing. pending: the instance a clear
-- waits for. on: the rows wanted a clear at the last refresh. asked: the popup may still be up (no OnHide tells when it goes). refused: the game
-- refused the last clear.
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

-- The time by the realm's clock, which a reload or a new session keeps; nil when the game does not say.
local function Now()
	if type(GetServerTime) ~= "function" then
		return nil
	end
	local ok, now = pcall(GetServerTime)
	return ok and ns.Finite(now) and now or nil
end

-- What the character keeps: instance, the ID of the dungeon or raid last entered with the row on; left, when the player left it (nil while inside);
-- seen, when Flat UI last knew the player to be inside it; last = { at, where, boss }, the last clear. A damaged value is dropped. Nil before the
-- saved data is read, or with make false when nothing is kept.
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

-- The dungeon or raid the player is in: its kind ("party" or "raid"), its instance ID and its name. Nil anywhere else, and when the game withholds
-- an answer or a call fails.
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

-- Clears the meter and keeps when and where. False when the game refuses, which /flatui status says.
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

-- A global string of the game's, or the English words when the client has none.
local function Word(name, fallback)
	local text = _G[name]
	if type(text) == "string" and not ns.IsSecret(text) and text ~= "" then
		return text
	end
	return fallback
end

-- Yes in the popup: the meter is cleared while the rows still ask and the player is still in the instance asked about. A popup left up beside
-- another one (Unask) can be answered after that.
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

-- Puts the popup in the game's list of them, once. Like Clean up bags' popup, it has an OnAccept only: no OnHide or OnCancel, so a No, an Escape
-- or a hide by the game runs no code of Flat UI's.
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

-- Takes the popup down: the player has left the instance, or the rows no longer ask. Only while it is the one popup shown, with Errands' helper
-- for the game's popups (Errands.HideAlone reads StaticPopup1 to 4 with IsShown and their field which, then calls StaticPopup_Hide): hidden
-- beside another popup, it would leave values written by Flat UI's code in the game's list of shown popups, which the game renews securely only
-- once that list is empty (StaticPopup.lua:89-104). Beside another popup it stays up, and asked stays, so a later pass tries again.
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

-- The popup that asks. Nothing is cleared when the client has no popups or will not show this one. One still up beside another popup is shown
-- again with this instance, as Clean up bags shows its own again (StaticPopup_Show takes the one up: StaticPopup.lua:379-386).
local function Ask(kind, id, where)
	Unask()
	if type(StaticPopup_Show) ~= "function" or not Register() then
		return
	end
	local ok, popup = pcall(StaticPopup_Show, POPUP, ASKS[kind], nil, { id = id, where = where })
	M.asked = M.asked or (ok and popup ~= nil and popup ~= false)
end

-- DELAY seconds after the player entered: still in the same instance, the meter is cleared or the popup asks.
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

-- True after an hour away from the instance kept.
local function Away(saved)
	local now = Now()
	return saved.left ~= nil and now ~= nil and now - saved.left >= AWAY
end

-- PLAYER_ENTERING_WORLD and ZONE_CHANGED_NEW_AREA: in a dungeon or raid not kept, or kept but left an hour ago, a clear waits DELAY seconds.
local function Entered()
	local saved = Saved(true)
	local kind, id, name = Where()
	if kind == nil then
		-- Out of every dungeon and raid: a clear that waits is dropped, the popup goes, and the time away from the last one starts. Now, not seen:
		-- Apply ran as the rows went on and at login (Hud.lua's Start is its Refresh, run at PLAYER_LOGIN, which comes before
		-- PLAYER_ENTERING_WORLD), so a left still empty here was heard as it happened, and seen, the time of entering, would date a long run's
		-- exit from its start.
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

-- ENCOUNTER_START (encounterID, encounterName, difficultyID, groupSize): in a raid, with At each raid boss on, the meter is cleared without asking.
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

-- Notes the time while the player is still in the instance kept: should Flat UI next hear from the player outside it, after a logout inside it or
-- with the rows off, the time away counts from here.
local function Seen(saved)
	if saved == nil or saved.instance == nil or saved.left ~= nil then
		return
	end
	local _, id = Where()
	if id ~= nil and id == saved.instance then
		saved.seen = Now() or saved.seen
	end
end

-- The rows went on, or the player logged in with them on: the instance the player is in counts as entered already, and outside the one kept the
-- time away from it counts from when Flat UI last saw the player inside it (Seen), or from now when it never did. The rows off: the time is noted
-- while the player is inside, a clear that waits is dropped and the popup goes.
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
-- A logout or a /reload inside the instance kept: the time away, if the player is outside it at the next login, counts from here (Apply).
ns.AddEvent(KEY, "PLAYER_LOGOUT", function()
	ns.EachPart(KEY, PART, function()
		Seen(Saved(false))
	end, {})
end, Heard)

-- How long ago a time of the realm's clock was, in words.
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

-- Hud.lua calls this in every refresh of the module: a changed row, the page, the profile, the module stopped. Once the part has stopped on errors,
-- the rows count as off, so nothing waits and the popup goes.
function ns.MeterClearRefresh()
	if not ns.PartStopped(KEY, PART) then
		ns.EachPart(KEY, PART, Apply, {})
	end
	if ns.PartStopped(KEY, PART) then
		pcall(Apply)
	end
end
