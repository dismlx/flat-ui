local _, ns = ...

-- In-game navigation (errands.navigation on the Levelling tab of Errands, under Waypoints, on by default). The game's variable
-- showInGameNavigation turns on its in-game navigation: a marker over the quest or map pin the game tracks (super-tracks), with its distance
-- under it, that waits at the edge of the screen with an arrow while the place is out of view. The marker is the game's own SuperTrackedFrame
-- (Blizzard_QuestNavigation/SuperTrackedFrame.lua and .xml; the .toc has no AllowLoadGameType or LoadOnDemand line), which follows the frame the
-- engine gives with NAVIGATION_FRAME_CREATED (C_Navigation.GetFrame, InGameNavigationDocumentation.lua), writes the distance with
-- IN_GAME_NAVIGATION_RANGE while the place is in view and shows its Arrow in place of the distance while it is clamped to the screen
-- (UpdateArrow, UpdateDistanceText). /way (ErrandsLevelling.lua) tracks the pin it puts on the map (C_SuperTrack.SetSuperTrackedUserWaypoint),
-- so this is what points to that pin on screen.
-- Later expansions have a checkbox for it in the game's options (Blizzard_SettingsDefinitions_Frame/Mainline/InterfaceOverrides.lua:341-344,
-- Settings.SetupCVarCheckbox, called from Interface.lua:20-25), but Forever loads Camelot/InterfaceOverrides.lua over it
-- (Blizzard_SettingsDefinitions_Frame.toc:19, AllowLoadGameType camelot), whose AdjustInGameNavigationSettings is empty (lines 2-3), so only
-- /console showInGameNavigation 1 turns it on there. On Forever the variable is the account's, 0 by default, and not secure, locked or read-only
-- (cvars.yaml of build 70790: 3682); retail's default is 1. Whether Forever's engine makes the marker for a map pin, for a quest or for both is
-- not in the client's Lua, and wants a look in game.
-- While the row and Errands are on, Flat UI writes 1, out of combat: at login, and when the row, the switch of Errands or the profile changes. A
-- value other than 0 already in place is on, as the game reads it: it is left as it is and nothing is kept. The text the variable had before
-- Flat UI's write is kept for the account in FlatUIDB.navigationGame, and the text Flat UI wrote beside it in FlatUIDB.navigationWrote: the value
-- in place is Flat UI's only while it is that text, so a value the game or the player writes since is theirs from then on, also one written while
-- Flat UI did not run (at the character screen, or with Flat UI off). FlatUIDB.navigationOn says the variable was on the last time the row asked
-- for it; a 0 found since that Flat UI did not write (/console showInGameNavigation 0, another addon or the game) is the player's own choice, kept
-- for the account in FlatUIDB.navigationOff, and Flat UI writes no 1 again until the row itself changes: the switch of Errands, a profile or a
-- reload leave that choice standing. A second after the game or the player writes the variable (CVAR_UPDATE) Flat UI reads it again, so such a
-- choice is seen at once, and Flat UI's own write is seen as its own text. When the row no longer asks for it (the row off, Errands off or
-- stopped, or this part stopped), the kept text is written back while the variable still holds what Flat UI wrote, and forgotten. Core.lua asks
-- at every login whatever the switch of Errands, since the variable is the account's: a character whose profile has the row or Errands off is
-- never given a 1, and gets the game's own value back. A write the game does not keep is not tried again until the value asked or the game's
-- value changes. /flatui status says which applies. No frame of the game is touched.

local KEY = "errands"
local CVAR = "showInGameNavigation"
-- The text Flat UI writes.
local ON = "1"
-- The wait after a change of the variable, so that a write of the game's or of another addon's has settled.
local SETTLE = 1
local LABEL = "In-game navigation"

local E = ns.Errands
local part = E.Part({ label = LABEL })

-- A write waits for combat to end.
local pending = false
-- A change of the variable waits SETTLE seconds.
local settling = false
-- How the last write ended: nil when nothing was asked of the game, "ok", or "refused" when the game did not keep it.
local result = nil
-- A write the game did not keep: the value asked and the value the game kept. It is not asked again until one of them changes.
local stuck = nil
-- True once the game's own value was put back in this session.
local restored = false

local function Calls()
	local cvar = _G.C_CVar
	if type(cvar) == "table" and not ns.IsSecret(cvar) then
		return cvar
	end
	return nil
end

-- The text of the variable, or nil when the client has no such variable or withholds it.
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

-- The number in a text, or nil.
local function Number(text)
	local number = type(text) == "string" and tonumber(text) or nil
	return ns.Finite(number) and number or nil
end

-- Writes the text and gives the text the variable holds after it, or nil when the client cannot be asked.
local function Write(text)
	local cvar = Calls()
	if not cvar or type(cvar.SetCVar) ~= "function" then
		return nil
	end
	pcall(cvar.SetCVar, CVAR, text)
	return Text()
end

-- True while the row asks for the navigation: ticked, with Errands on and not stopped, and this part not stopped.
local function Wanted()
	return ns.Enabled(KEY) and ns.Get(KEY .. ".navigation") == true and not ns.PartStopped(KEY, LABEL)
end

local function Account()
	local db = ns.Account()
	return type(db) == "table" and db or nil
end

-- A text kept in FlatUIDB at key, when it is the text of a number, else nil.
local function Kept(db, key)
	local text = db and db[key]
	return type(text) == "string" and Number(text) ~= nil and text or nil
end

-- Whether the value in place is Flat UI's: the text Flat UI wrote, and not the game's own text again.
local function Ours(db, value)
	local game, wrote = Kept(db, "navigationGame"), Kept(db, "navigationWrote")
	return game ~= nil and wrote ~= nil and Number(wrote) == value and Number(game) ~= value
end

local function Forget(db)
	if db then
		db.navigationGame, db.navigationWrote = nil, nil
	end
end

-- True while the player's own 0 stands: the variable was turned off another way after it was on while the row asked for it.
local function Declined(db)
	return db ~= nil and db.navigationOff == true
end

-- Brings the variable to what the row asks: on, with the game's own text kept, or that text written back. Gives the value in place after it, or
-- nil when the client has no such variable or withholds it, and true when Flat UI wrote the game's own text back.
local function Settle(db, wanted)
	local now = Text()
	local value = Number(now)
	if value == nil then
		result = nil
		return nil, false
	end
	local ours = Ours(db, value)
	if not ours then
		-- The game or the player wrote the value in place, also while Flat UI did not run, so it is the game's own, and a text kept before it is
		-- no longer. A 0 there, after the variable was on while the row asked for it, is the player's own choice until the row changes.
		if wanted and value == 0 and db and db.navigationOn == true then
			db.navigationOff = true
		end
		Forget(db)
	end
	local own = ours and Kept(db, "navigationGame") or now
	local ownValue = Number(own)
	-- The row asks for the navigation while the game's own value is 0 and the player has not turned it off since; any other number is on, and
	-- stays.
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
			-- The write took: what is in place is Flat UI's, and the game's own text is kept beside it.
			db.navigationGame, db.navigationWrote = own, after
		end
		result = afterValue == want and "ok" or "refused"
		return afterValue, false
	end
	if afterValue == want then
		-- The game's own text is back.
		Forget(db)
		restored, result = true, nil
		return afterValue, true
	end
	-- The game kept Flat UI's value: the kept text stays, to be written back once the value asked or the game's value changes.
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
		-- Whether the variable is on while the row asks for it: a 0 found there later that Flat UI did not write is the player's own.
		db.navigationOn = value ~= 0 or nil
	elseif back then
		-- Flat UI's own write of the game's text is no one's choice.
		db.navigationOn = nil
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

-- The row changed (changed in Config.lua gives its path), and Core.lua at every login whatever the switch of Errands (no path). Only a change of
-- the row takes back the player's own 0: the row then asks for the navigation afresh.
function ns.ErrandsNavigationChanged(path)
	local db = Account()
	if type(path) == "string" and db then
		db.navigationOff, db.navigationOn = nil, nil
	end
	Queue()
end

-- A change of a variable (CVAR_UPDATE gives its name and its new text). A change of this one is read again a second later.
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

-- Errands' Start and Refresh: the switch of Errands, a change of the profile and the last Refresh of a stopped Errands reach the variable here.
-- They leave the player's own 0 standing.
part.Start = Queue
part.Refresh = Queue

-- The line of /flatui status, whatever the switch of Errands, since the variable is the account's. Nothing when the client has no such variable.
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
