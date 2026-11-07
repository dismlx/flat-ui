local _, ns = ...

-- The zone name and the talking head: two of the game's messages on the screen that the player can hide. The rows are Hide the zone name, Hide
-- the subzone name and Hide the talking head on the Tracker, loot and alerts tab (hud.zoneTitle, hud.subzoneTitle and hud.talkingHead, each off
-- by default), part "zone name and talking head" of the module, which stops alone after a few failures and then gives everything back. Not a
-- module: Hud.lua calls ns.ScreenTextRefresh in every refresh of the page.
-- The zone name fades in near the top of the screen as the player enters a zone or a part of one (ZoneText_OnEvent, Blizzard_FrameXML/Mainline/
-- ZoneText.lua:83-121, for ZONE_CHANGED, ZONE_CHANGED_INDOORS and ZONE_CHANGED_NEW_AREA, :76-78). ZoneTextFrame holds the name of the zone and
-- its PvP line (ZoneTextString and PVPInfoTextString, ZoneText.xml:11-22), SubZoneTextFrame the name of the part of the zone and its PvP line
-- (SubZoneTextString and PVPArenaTextString, :38-49). The game shows and hides both frames and sets their opacity on every frame while they
-- fade (FadingFrame_Show and FadingFrame_OnUpdate, Blizzard_FrameXMLUtil/FadingFrame.lua:22-49); of the font strings it sets only the text, the
-- colour and the anchors (ZoneText.lua:7-69, 83-121 and 173-177). So a row that is on makes its two font strings transparent (SetAlpha 0) and
-- leaves the frames to the game, as Unit frames does with the player's hit number (UnitParts.lua) and Minimap and buffs with the minimap's zone
-- name (Hud.lua): the opacity each string had is read before the first write and given back when the row, the page or the part goes off. The
-- frames take no mouse, so a name that is hidden is in nobody's way. A string this client lacks is passed over, and a change of opacity the
-- game refuses gives back the strings of that row, which then shows as usual until /reload, and /flatui status says so.
-- The talking head is the portrait that speaks at the bottom of the screen (TalkingHeadFrame, Blizzard_FrameXML/TalkingHeadUI.xml:3, loaded for
-- the mainline client that Forever is, Blizzard_FrameXML.toc:147-148). It hears TALKINGHEAD_REQUESTED (TalkingHeadUI.lua:3-8), and shows itself
-- and plays the voice in PlayCurrent (:25-28, 128-217). It is a button that takes clicks, so it is not made transparent: while the row is on,
-- Flat UI reads with IsEventRegistered that the frame listens, takes that one event from it with UnregisterEvent and gives it back with
-- RegisterEvent when the row, the page or the part goes off, as Error messages does with UIErrorsFrame (ErrorFilter.lua). No talking head then
-- shows or speaks; the game's close (TALKINGHEAD_CLOSE, :28-29 and 219-239) and its reset at a loading screen (:36-38) stay its own, and one
-- that shows when the row goes on plays to its end. A frame that does not listen when Flat UI looks (another addon took the event) is left so,
-- and one that says it is protected takes no call in a fight: the change waits for the end of it. Every client call is in a pcall, and nothing of
-- the game's is written but the opacity of the four strings and the event of the talking head.
-- This follows EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission (EnhanceQoL.lua:4017-4019 and 4921-4929, the options
-- ignoreTalkingHead and hideZoneText). Its talking head is hidden with Hide after the game's PlayCurrent, through a hook on that method of the
-- frame, and its zone text loses every event of its frame until a reload. Here no method of the game's is hooked, every change is given back at
-- once, the voice is silent too, and the zone name and the name of the part of a zone have a row each.

local KEY, PART = "hud", "zone name and talking head"
local EVENT = "TALKINGHEAD_REQUESTED"
-- The rows that make font strings transparent, and the strings of each by their global names.
local ROWS = { "zoneTitle", "subzoneTitle" }
local STRINGS = { zoneTitle = { "ZoneTextString", "PVPInfoTextString" }, subzoneTitle = { "SubZoneTextString", "PVPArenaTextString" } }
local LABELS = { zoneTitle = "Zone name", subzoneTitle = "Subzone name" }

-- kept: per row, the opacity each string had before Flat UI made it transparent. refused: the rows whose change the game refused. missing: the
-- rows whose strings this client lacks.
local kept = { zoneTitle = {}, subzoneTitle = {} }
local refused, missing = {}, {}
-- The talking head. held: Flat UI took the event and owes it back. aside: the frame did not listen when Flat UI looked. refused: the frame kept
-- the event or would not say. stuck: the frame would not take the event back. absent: the client has no such frame. waiting: a change waits
-- for the end of a fight.
local T = {}
local Talk

-- A table of the game's by its global name, or nil when it is missing or withheld.
local function Global(name)
	local ok, value = pcall(function()
		return _G[name]
	end)
	if ok and type(value) == "table" and not ns.IsSecret(value) then
		return value
	end
	return nil
end

local function Wanted(row)
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and ns.Get(KEY .. "." .. row) == true
end

-- Gives back the opacity of the strings of a row.
local function Release(row)
	local list = kept[row]
	for text, alpha in pairs(list) do
		list[text] = nil
		pcall(text.SetAlpha, text, alpha)
	end
end

-- Makes the strings of a row transparent while it is on, or gives each the opacity it had.
local function Strings(row)
	if not Wanted(row) or refused[row] then
		missing[row] = nil
		Release(row)
		return
	end
	local list, found = kept[row], 0
	for _, name in ipairs(STRINGS[row]) do
		local text = Global(name)
		if text ~= nil and type(text.SetAlpha) == "function" then
			found = found + 1
			if list[text] == nil then
				local ok, alpha = pcall(text.GetAlpha, text)
				list[text] = ok and ns.Finite(alpha) and alpha >= 0 and alpha <= 1 and alpha or 1
			end
			if not pcall(text.SetAlpha, text, 0) then
				refused[row] = true
				Release(row)
				return
			end
		end
	end
	missing[row] = found == 0 or nil
end

-- The talking head, or nil on a client without it.
local function Head()
	local head = Global("TalkingHeadFrame")
	if head == nil or ns.Forbidden(head) then
		return nil
	end
	return head
end

-- True while the frame listens for the event, false while it does not, nil when it does not say.
local function Listens(head)
	local ok, on = pcall(head.IsEventRegistered, head, EVENT)
	if not ok or ns.IsSecret(on) or type(on) ~= "boolean" then
		return nil
	end
	return on
end

-- In a fight a frame that says it is protected, or will not say, takes no call.
local function Blocked(head)
	return InCombatLockdown() and (ns.MaybeProtected == nil or ns.MaybeProtected(head))
end

local function Wait()
	if T.waiting then
		return
	end
	T.waiting = true
	ns.OutOfCombat(function()
		T.waiting = false
		local ok, err = pcall(Talk)
		if not ok then
			geterrorhandler()(err)
		end
	end)
end

-- Takes the event from the talking head or gives it back, as the row and the page ask.
function Talk()
	local head = Head()
	if head == nil then
		T.absent = Wanted("talkingHead") or nil
		T.held, T.stuck = false, nil
		return
	end
	T.absent = nil
	if Wanted("talkingHead") then
		local on = Listens(head)
		if on == true then
			if Blocked(head) then
				Wait()
				return
			end
			-- Read first: the frame listens, so the event goes back to it when the row goes off.
			pcall(head.UnregisterEvent, head, EVENT)
			local now = Listens(head)
			if now ~= false then
				-- The frame kept the event, or will not say whether it did: it is given the event again, to be sure, and nothing is hidden.
				if now == nil then
					pcall(head.RegisterEvent, head, EVENT)
				end
				T.held, T.refused, T.aside = false, true, nil
				return
			end
			T.held = true
		elseif not T.held then
			T.aside, T.refused = on == false or nil, on == nil or nil
			return
		end
		T.aside, T.refused, T.stuck = nil, nil, nil
		return
	end
	if T.held then
		if Listens(head) == false then
			if Blocked(head) then
				Wait()
				return
			end
			pcall(head.RegisterEvent, head, EVENT)
			if Listens(head) == false then
				T.stuck = true
				return
			end
		end
		T.held = false
	end
	T.aside, T.refused, T.stuck = nil, nil, nil
end

local function Apply()
	for _, row in ipairs(ROWS) do
		Strings(row)
	end
	Talk()
end

ns.AddStatus(KEY, function()
	local lines = {}
	for _, row in ipairs(ROWS) do
		if ns.Get(KEY .. "." .. row) == true and refused[row] then
			lines[#lines + 1] = ("%s: the game refused a change of opacity, so it shows until /reload."):format(LABELS[row])
		elseif Wanted(row) and missing[row] then
			lines[#lines + 1] = ("%s: this client has no such text, so nothing is hidden."):format(LABELS[row])
		end
	end
	if T.stuck then
		lines[#lines + 1] = "Talking head: the game did not take its talking head back, so none shows until /reload."
	elseif T.held and not Wanted("talkingHead") then
		lines[#lines + 1] = "Talking head: shown again at the end of the fight."
	elseif not Wanted("talkingHead") then
		return lines
	elseif T.absent then
		lines[#lines + 1] = "Talking head: this client has none, so nothing is hidden."
	elseif T.waiting and not T.held then
		lines[#lines + 1] = "Talking head: hidden at the end of the fight."
	elseif T.refused then
		lines[#lines + 1] = "Talking head: the game kept it, so it shows as usual."
	elseif T.aside then
		lines[#lines + 1] = "Talking head: another addon has taken it off already, so Flat UI leaves it."
	end
	return lines
end)

-- Hud.lua calls this in every refresh of the module: a changed row, the page, the profile, the module stopped. Once the part has stopped on
-- errors, every row counts as off, so the strings and the event are given back.
function ns.ScreenTextRefresh()
	if not ns.PartStopped(KEY, PART) then
		ns.EachPart(KEY, PART, Apply, {})
	end
	if ns.PartStopped(KEY, PART) then
		pcall(Apply)
	end
end
