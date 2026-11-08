local _, ns = ...

-- Fading: the action bars, the stance and pet bars, the micro menu, the bag bar, the player and pet frames and the minimap buttons, the game's and
-- other addons', go to a low opacity while nothing asks for them, and back to full when something does. The one thing written on a frame is its alpha
-- (SetAlpha, which the documentation leaves open to addons and does not mark protected:
-- Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua:1133-1142). The alpha a frame had is read before the first write and put
-- back when the module, the row or the part goes off. A faded frame still takes clicks and shows tooltips, since alpha does not touch the mouse.
--
-- One frame of the addon's own runs every 0.05 s while the module is on. A row is at full opacity while the mouse is over the row's hover frame,
-- in a fight (with In combat ticked), with a target (With a target ticked; not the Target frame row, see When shown), while the cursor holds something, while
-- the spell flyout is open and in Edit Mode.
-- Otherwise it stays where it is until Wait before fading has passed, then eases to Faded opacity over Fade time. A frame is written only when its value changes.
-- A frame whose alpha something else holds at 0 (the hidden minimap buttons) is left alone, and a frame the action bar block fades is left to that fade.
-- An alpha something else gives a frame after a write is taken as the frame's own, the one put back, and the frame eases again from it.
-- The frames are the game's own: MainActionBar, MultiBarBottomLeft, MultiBarBottomRight, MultiBarRight, MultiBarLeft, MultiBar5, MultiBar6, MultiBar7, StanceBar,
-- PetActionBar, MicroMenuContainer, BagsBar, PlayerFrame.PlayerFrameContainer and PlayerFrame.PlayerFrameContent (parentKeys of PlayerFrame with no global name: Blizzard_UnitFrame/Mainline/PlayerFrame.xml:23 and :68; the pet frame, totems and cast bar stay as they are),
-- PetFrame, and under MinimapCluster the Tracking and IndicatorFrame frames, GameTimeFrame, TimeManagerClockButton and AddonCompartmentFrame
-- (Blizzard_Minimap/Mainline/Minimap.xml:3, 25 and 46, GameTime.xml:3, Camelot/AddonCompartment.xml:3, Blizzard_TimeManager/Mainline/Blizzard_TimeManager.xml:178).
-- Other addons' minimap buttons join the Minimap buttons row: the shown, unprotected LibDBIcon10_ frames on the map that MapButtons.lua finds
-- (ns.MapAddonButtons), whatever Addon buttons says, asked for again at each pass so that a button made later joins, and a button that leaves the
-- list gets its alpha back at once. In the column or row beside the map they lie outside MinimapCluster, so the mouse over any of them counts as
-- over the map. An addon that fades its own buttons (LibDBIcon's own fade) gives them an alpha that is taken as theirs, as above, so the two do not fight.
-- ExtraActionBarFrame, the swing timers and the resource display are left out because the game or Edit Mode sets their alpha.
--
-- When shown: the target and focus frames, the buffs, the objective tracker and the damage meter each have a rule. Always (the default) leaves the
-- frame alone. Only in combat, Only in a group, Only in an instance, Only outside an instance and Only when not mounted give it full opacity while that
-- holds; at other times it fades as the rows above do, under the mouse, the Stay visible rows and Edit Mode included, With a target aside for the target frame: the game shows that frame only
-- while there is a target (Blizzard_UnitFrame/Shared/TargetFrame.lua:1-15, Mainline/TargetFrame.lua:130-136), so With a target would hold it at full
-- whenever it shows and its rule would never fade it. The frames: TargetFrame and FocusFrame, secure unit buttons of
-- TargetFrameTemplate (Blizzard_UnitFrame/Mainline/TargetFrame.xml:52, 549 and 572) whose cast bar and target of target are their children and fade
-- with them (Mainline/TargetFrame.lua:711-718 and 738-740), as do the combo points on Forever (Camelot/ComboFrame.lua:16); BuffFrame, the buffs and
-- weapon enchants (Blizzard_BuffFrame/BuffFrame.xml:6; the debuffs are DebuffFrame and stay); ObjectiveTrackerFrame
-- (Blizzard_ObjectiveTracker/Blizzard_ObjectiveTracker.xml:3); and DamageMeter, the game's damage meter (Blizzard_DamageMeter/DamageMeter.xml:11, loaded
-- at start on the standard and camelot clients: Blizzard_DamageMeter.toc:2). The game sets the alpha of none of the five but the tracker: of the target
-- frame's portrait and icons (Mainline/TargetFrame.lua:156, 160 and 624), of the buff buttons (BuffFrame.lua:1268 and 1357) and of the meter's session
-- windows (Blizzard_DamageMeter/DamageMeter.lua:298 and 556), never of DamageMeter itself. The windows are children of the meter (DamageMeter.lua:285),
-- so they fade with it and keep the game's Transparency, and the meter's Visibility in Edit Mode (Always, In combat, In group, Hidden:
-- DamageMeter.lua:166-193) still shows and hides it. The second and third windows are anchored to UIParent and may be moved anywhere
-- (DamageMeter.lua:312-330; three at most, :4), and a window's breakdown opens beside it (DamageMeterSourceWindow.lua:280-327), so the mouse over any
-- of them that shows, looked up by name at each pass, counts as over the meter, and a window placed apart comes back under the mouse. The tracker is a managed
-- frame of the right column while Edit Mode has it in its default place (Blizzard_ObjectiveTrackerContainer.lua:34-37,
-- Blizzard_ManagedFrameSystem/Shared/ManagedFrameSystem.lua:57-77), and each time the interface is shown again, after Alt+Z or a cinematic, the game
-- gives it full opacity (ManagedFrameSystem.lua:79-87, 130-134 and 160; Blizzard_UIParent/UIParent.lua:5-7); Ease takes that up and fades it again.
-- Edit Mode's Opacity sets the alpha of an aura frame only where the layout has that setting, which on Forever is the external defensives frame alone
-- (Blizzard_EditMode/Shared/EditModeSystemTemplates.lua:2141-2144, 2158-2175; Mainline/EditModePresetLayouts.lua:434-479), and the tracker's Opacity
-- is the alpha of its background (Blizzard_ObjectiveTrackerManager.lua:86-91, Blizzard_ObjectiveTrackerContainer.lua:187-189). As on the pet frame,
-- the alpha is written in a fight too, since SetAlpha is not protected; nothing is shown, hidden or moved. While the tracker's Opacity in combat
-- (Hud.lua) holds the tracker in a fight, Fading forgets the tracker with no write (ns.TrackerFades); that row reads the alpha the tracker had before
-- Fading from ns.FadeGiven, and after the fight gives the tracker back with it (ns.FadeTakesBack): the ease goes on from the alpha of the fight, so
-- the tracker does not show at full for a moment. The rules: in combat as for In combat below; in a group, IsInGroup, as the game's own group headers
-- ask (Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.lua:268); in an instance, IsInInstance (InstanceDocumentation.lua:170-178); outside
-- an instance, unless IsInInstance plainly says the player is in a dungeon, a raid, a battleground or an arena; mounted,
-- IsMounted (PlayerScriptDocumentation.lua:1399-1406) or a druid's travel, aquatic or flight form, by GetShapeshiftFormID as the game asks it
-- (Blizzard_SharedXMLBase/ModelSceneUtil.lua:23) and the form IDs 3, 4 and 27 (Blizzard_FrameXMLBase/Constants.lua:329-333). None of them marks a
-- return secret; a withheld answer counts as the rule holding, so the frame stays shown, and a call that fails as the rule not holding, but for
-- outside an instance, where a failed call holds too, as nothing then says the player is in one. Only outside an instance is meant for the objective
-- tracker: with Faded opacity at 0% the tracker is gone in dungeons and raids, comes back under the mouse over the part it draws and in Edit Mode,
-- and shows again outside, and its Opacity in combat still comes first in a fight. The step asks every rule again, so no event is needed. The
-- skyriding, flying and Mythic+ rules are left out, as EnhanceQoL leaves them out on Forever, and so are its difficulty scopes for the tracker
-- (Mythic+, delves, timewalking: Forever has only normal dungeons and raids) and its Hide and OnShow hooks on the tracker's modules, since Fading
-- writes only the alpha (EnhanceQoLDungeonRaid/ObjectiveTracker.lua:1-145).
-- These rules follow the frame visibility rules of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission, and so do the damage meter's
-- row (EnhanceQoLDamageMeter/DamageMeter.lua:640-727) and the fade of other addons' minimap buttons (EnhanceQoL/EnhanceQoL.lua:5740-5800).

local KEY = "fade"
local PART = "fade"
local EVERY = 0.05
-- An alpha at or under this is a frame something else holds hidden.
local HIDDEN = 0.001

-- row: the setting that switches it. frames: names in the game, a dotted name reaching down from a global. hover: the frame whose rectangle
-- counts as under the mouse (the frames themselves when it is left out). rule: a row of When shown, whose setting is a rule (RULES) and not a switch.
-- targeted: frames the game shows only while there is a target, which With a target does not hold at full. more: the function of ns that gives the
-- frames of other addons the row fades too, asked at each pass, each also under the mouse. beside: frames by name that do not fade with the row
-- but count as under the mouse while they show.
-- The meter's session windows (DamageMeterSessionWindow1 to 3, DamageMeter.lua:285) and the breakdown of each, a parentKey with no global name
-- (DamageMeterSessionWindow.lua:119-128, DamageMeterSessionWindow.xml:84 and 129).
local METER_PARTS = {}
for index = 1, 3 do
	METER_PARTS[#METER_PARTS + 1] = "DamageMeterSessionWindow" .. index
	METER_PARTS[#METER_PARTS + 1] = "DamageMeterSessionWindow" .. index .. ".MinimizeContainer.SourceWindow"
end
local ENTRIES = {
	{ bar = true, row = "main", label = "Main action bar", frames = { "MainActionBar" } },
	{ bar = true, row = "bar2", label = "Action bar 2", frames = { "MultiBarBottomLeft" } },
	{ bar = true, row = "bar3", label = "Action bar 3", frames = { "MultiBarBottomRight" } },
	{ bar = true, row = "bar4", label = "Action bar 4", frames = { "MultiBarRight" } },
	{ bar = true, row = "bar5", label = "Action bar 5", frames = { "MultiBarLeft" } },
	{ bar = true, row = "bar6", label = "Action bar 6", frames = { "MultiBar5" } },
	{ bar = true, row = "bar7", label = "Action bar 7", frames = { "MultiBar6" } },
	{ bar = true, row = "bar8", label = "Action bar 8", frames = { "MultiBar7" } },
	{ bar = true, row = "stance", label = "Stance bar", frames = { "StanceBar" } },
	{ bar = true, row = "pet", label = "Pet bar", frames = { "PetActionBar" } },
	{ bar = true, row = "micro", label = "Micro menu", frames = { "MicroMenuContainer" } },
	{ bar = true, row = "bags", label = "Bag bar", frames = { "BagsBar" } },
	{ row = "playerFrame", label = "Player frame", frames = { "PlayerFrame.PlayerFrameContainer", "PlayerFrame.PlayerFrameContent" }, hover = "PlayerFrame" },
	{ row = "petFrame", label = "Pet frame", frames = { "PetFrame" } },
	{ row = "minimapButtons", label = "Minimap buttons", hover = "MinimapCluster", more = "MapAddonButtons",
		frames = { "MinimapCluster.Tracking", "MinimapCluster.IndicatorFrame", "GameTimeFrame", "TimeManagerClockButton", "AddonCompartmentFrame" } },
	{ rule = true, targeted = true, row = "targetFrame", label = "Target frame", frames = { "TargetFrame" } },
	{ rule = true, row = "focusFrame", label = "Focus frame", frames = { "FocusFrame" } },
	{ rule = true, row = "buffs", label = "Buffs", frames = { "BuffFrame" } },
	-- The tracker's own frame runs down to the foot of the right column whatever it lists (Blizzard_ObjectiveTrackerContainer.lua:207-228,
	-- UIParentPanelManager.lua:822-829); its NineSlice runs from its top to under the last module (Blizzard_ObjectiveTrackerContainer.lua:117-119).
	{ rule = true, row = "objectiveTracker", label = "Objective tracker", frames = { "ObjectiveTrackerFrame" }, hover = "ObjectiveTrackerFrame.NineSlice" },
	{ rule = true, row = "damageMeter", label = "Damage meter", frames = { "DamageMeter" }, beside = METER_PARTS },
}
-- The forms of a druid that count as mounted, by GetShapeshiftFormID: travel, aquatic and flight form (Blizzard_FrameXMLBase/Constants.lua:329-333).
local TRAVEL_FORMS = { [3] = true, [4] = true, [27] = true }

-- bar: a game action bar, or a frame its layout hangs from (micro menu, bag bar). While Leave the game's action bars alone is on the row does nothing, and a bar this module faded is given its alpha back.
-- orig: the alpha a frame had before the first write. sent: the last alpha written. value: where the ease is. idle: seconds a row has had nothing to keep it
-- at full. found: the frames reached by name. clock: seconds since the last step. added: per frame of another addon a row fades (more), that row.
local weak = { __mode = "k" }
local state = { orig = setmetatable({}, weak), sent = setmetatable({}, weak), value = setmetatable({}, weak), idle = {}, found = {}, clock = 0,
	added = setmetatable({}, weak) }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- True for a row of a game action bar that is left alone now.
local function Left(entry)
	return entry.bar == true and ns.HandsOff()
end

-- The frame behind a name, or nil while the game has not made it or it cannot be touched.
local function Resolve(name)
	local frame = state.found[name]
	if frame then
		return frame
	end
	local first, rest = name:match("^([^.]+)%.?(.*)$")
	local at = _G[first]
	for key in rest:gmatch("[^.]+") do
		if type(at) ~= "table" or ns.IsSecret(at) then
			return nil
		end
		local ok, child = pcall(function()
			return at[key]
		end)
		at = ok and child or nil
	end
	if type(at) == "table" and not ns.IsSecret(at) and not ns.Forbidden(at) and type(at.SetAlpha) == "function" then
		state.found[name] = at
		return at
	end
	return nil
end

-- The alpha of a frame, and true when the client gave a real number; 1 and false when it did not.
local function Alpha(frame)
	local ok, alpha = pcall(frame.GetAlpha, frame)
	if ok and ns.Finite(alpha) then
		return alpha, true
	end
	return 1, false
end

-- A withheld answer counts as the frame being under the mouse, so that it stays shown.
local function Over(frame)
	local ok, over = pcall(frame.IsMouseOver, frame)
	return ok and (ns.IsSecret(over) or over == true)
end

local function Holding()
	if type(GetCursorInfo) ~= "function" then
		return false
	end
	local ok, kind = pcall(GetCursorInfo)
	return ok and (ns.IsSecret(kind) or kind ~= nil)
end

local function FlyoutOpen()
	local flyout = _G.SpellFlyout
	if type(flyout) ~= "table" or ns.IsSecret(flyout) or ns.Forbidden(flyout) then
		return false
	end
	local ok, shown = pcall(flyout.IsShown, flyout)
	return ok and (ns.IsSecret(shown) or shown == true)
end

local function Fighting()
	if InCombatLockdown() then
		return true
	end
	if type(UnitAffectingCombat) ~= "function" then
		return false
	end
	local ok, fighting = pcall(UnitAffectingCombat, "player")
	return ok and (ns.IsSecret(fighting) or fighting == true)
end

local function HasTarget()
	if type(UnitExists) ~= "function" then
		return false
	end
	local ok, exists = pcall(UnitExists, "target")
	return ok and (ns.IsSecret(exists) or exists == true)
end

-- What keeps every row at full opacity, whatever the mouse does. With a target is asked apart (Step), as it does not hold a targeted row.
local function Wanted()
	return (Opt("combat") and Fighting()) or Holding() or FlyoutOpen() or ns.EditModeOpen()
end

-- In a party or a raid.
local function Grouped()
	if type(IsInGroup) ~= "function" then
		return false
	end
	local ok, grouped = pcall(IsInGroup)
	return ok and (ns.IsSecret(grouped) or grouped == true)
end

-- In a dungeon, a raid, a battleground or an arena.
local function Inside()
	if type(IsInInstance) ~= "function" then
		return false
	end
	local ok, inside = pcall(IsInInstance)
	return ok and (ns.IsSecret(inside) or inside == true)
end

-- Outside every dungeon, raid, battleground and arena: true unless the game plainly says the player is in one, so that a withheld answer and a
-- call that fails both leave the frame shown.
local function Outside()
	if type(IsInInstance) ~= "function" then
		return true
	end
	local ok, inside = pcall(IsInInstance)
	return not (ok and not ns.IsSecret(inside) and inside == true)
end

-- Neither on a mount nor in a druid's travel form. A withheld answer counts as not mounted.
local function Unmounted()
	if type(IsMounted) == "function" then
		local ok, mounted = pcall(IsMounted)
		if ok and not ns.IsSecret(mounted) and mounted == true then
			return false
		end
	end
	if type(GetShapeshiftFormID) == "function" then
		local ok, form = pcall(GetShapeshiftFormID)
		if ok and ns.Finite(form) and TRAVEL_FORMS[form] then
			return false
		end
	end
	return true
end

-- The rules of When shown, each true while its frame is to be at full opacity. Always is not one: that row leaves its frame alone.
local RULES = { combat = Fighting, group = Grouped, instance = Inside, outside = Outside, unmounted = Unmounted }
-- The answers of one step, so a rule is asked at most once a step.
local asked = {}

local function Holds(rule)
	local answer = asked[rule]
	if answer == nil then
		answer = RULES[rule]() == true
		asked[rule] = answer
	end
	return answer
end

-- True for a row that fades its frames: a switch that is on, or a rule of When shown other than Always.
local function Active(entry)
	local value = Opt(entry.row)
	if entry.rule then
		return RULES[value] ~= nil
	end
	return value == true
end

-- True for a frame another part of Flat UI holds the alpha of now: a bar the action bar block fades, or the objective tracker while its Opacity in
-- combat has it in a fight.
local function Elsewhere(frame, name)
	return (ns.BarBlockFades and ns.BarBlockFades(name)) or (ns.TrackerFades and ns.TrackerFades(frame)) or false
end

-- The write. It raises when the game refuses, which ns.EachPart counts for the part.
local function Put(frame, alpha)
	if state.sent[frame] ~= alpha then
		frame:SetAlpha(alpha)
		state.sent[frame] = alpha
	end
	state.value[frame] = alpha
end

-- A frame goes back to the alpha it had, unless something else has set its own since.
local function Release(frame)
	local alpha = state.orig[frame]
	if alpha == nil then
		return
	end
	local sent = state.sent[frame]
	state.orig[frame], state.sent[frame], state.value[frame] = nil, nil, nil
	if sent ~= nil and math.abs(Alpha(frame) - sent) < 0.01 then
		pcall(frame.SetAlpha, frame, alpha)
	end
end

local function ReleaseAll()
	for frame in pairs(state.orig) do
		Release(frame)
	end
	state.added = setmetatable({}, weak)
end

-- The frames of other addons that a row faded get their alpha back: those the row no longer lists, or with keep left out all of them.
local function Forget(row, keep)
	for frame, owner in pairs(state.added) do
		if owner == row and not (keep and keep[frame]) then
			state.added[frame] = nil
			Release(frame)
		end
	end
end

-- The frames of other addons that a row fades this pass (entry.more), each { frame, name }. A frame the row no longer lists gets its alpha back.
local function Added(entry)
	local list, listed = {}, {}
	local fn = ns[entry.more]
	if type(fn) == "function" then
		local ok, found = pcall(fn)
		if ok and type(found) == "table" then
			for _, each in ipairs(found) do
				local frame = type(each) == "table" and each.frame or nil
				if frame ~= nil and not listed[frame] and not ns.Forbidden(frame) and type(frame.SetAlpha) == "function" then
					listed[frame] = true
					list[#list + 1] = { frame, each.name }
				end
			end
		end
	end
	Forget(entry.row, listed)
	for frame in pairs(listed) do
		state.added[frame] = entry.row
	end
	return list
end

-- True while the mouse is over one of the frames that count as a row's (entry.beside) and that shows. A withheld answer counts as shown.
local function Beside(names)
	for _, name in ipairs(names) do
		local frame = Resolve(name)
		if frame then
			local ok, shown = pcall(frame.IsVisible, frame)
			if ok and (ns.IsSecret(shown) or shown == true) and Over(frame) then
				return true
			end
		end
	end
	return false
end

-- The alpha a frame had before this module wrote on it, for the action bar block, which takes over the bars it holds, and for the minimap buttons
-- and the tracker's Opacity in combat (Hud.lua), which take a frame over for a time.
function ns.FadeGiven(frame)
	return state.orig[frame]
end

-- The tracker's Opacity in combat (Hud.lua) gives the tracker back here when it lets it go (the fight is over, or that row or its page changed), while
-- the tracker's row of When shown fades it. alpha, the one it had before Fading, is kept to be put back, and the ease goes on from the alpha the tracker
-- has now, so it does not go to full and fade again. False when this module does not take the tracker, or alpha is one something else held hidden,
-- which this module leaves alone (Ease): that row then puts alpha back itself.
function ns.FadeTakesBack(frame, alpha)
	if frame == nil or not ns.Finite(alpha) or alpha <= HIDDEN or not ns.Enabled(KEY) or ns.PartStopped(KEY, PART)
		or RULES[Opt("objectiveTracker")] == nil or frame ~= Resolve("ObjectiveTrackerFrame") then
		return false
	end
	local current = Alpha(frame)
	state.orig[frame], state.value[frame], state.sent[frame] = alpha, current, current
	return true
end

-- One frame toward the wanted alpha. A target of nil holds the frame where it is.
local function Ease(frame, target, step, name)
	-- A button the minimap page switches off stays off whatever Fading says, and the objective tracker is left to its Opacity in combat while that
	-- holds it in a fight: that has written its own alpha, so nothing is put back.
	if (ns.MapButtonOff and ns.MapButtonOff(frame)) or (ns.TrackerFades and ns.TrackerFades(frame)) then
		state.orig[frame], state.sent[frame], state.value[frame] = nil, nil, nil
		return
	end
	if ns.BarBlockFades and ns.BarBlockFades(name) then
		Release(frame)
		return
	end
	local current, known = Alpha(frame)
	if state.orig[frame] == nil then
		if current <= HIDDEN then
			return
		end
		state.orig[frame], state.value[frame] = current, current
	elseif current <= HIDDEN and (state.sent[frame] == nil or state.sent[frame] >= 0.01) then
		-- Something else hides it now. The game keeps an alpha in steps of 1/255, so a write of this module's own below 0.01 can read back as 0.
		state.orig[frame], state.sent[frame], state.value[frame] = nil, nil, nil
		return
	elseif known and state.sent[frame] ~= nil and math.abs(current - state.sent[frame]) >= 0.01 then
		-- Something else has given it another alpha since the last write, as the game gives the tracker full opacity when the interface is shown
		-- again: that is its alpha now, the one put back, and the ease starts from it.
		state.orig[frame], state.value[frame], state.sent[frame] = current, current, nil
	end
	local value = state.value[frame]
	if target == nil then
		return
	elseif value < target then
		value = math.min(target, value + step)
	elseif value > target then
		value = math.max(target, value - step)
	end
	if value ~= (state.sent[frame] or state.orig[frame]) then
		ns.EachPart(KEY, PART, Put, frame, value)
	end
end

local function Step(dt)
	if ns.PartStopped(KEY, PART) then
		ReleaseAll()
		return
	end
	local floor, delay, seconds = Opt("alpha") / 100, Opt("delay") / 1000, math.max(Opt("time") / 1000, 0.05)
	local step = dt / seconds
	local always, targeted = Wanted(), Opt("target") and HasTarget()
	for rule in pairs(asked) do
		asked[rule] = nil
	end
	for _, entry in ipairs(ENTRIES) do
		local frames = entry.cache
		if not frames and Left(entry) then
			frames = {}
			for _, name in ipairs(entry.frames) do
				local frame = state.found[name]
				if frame then
					frames[#frames + 1] = { frame, name }
				end
			end
		elseif not frames then
			frames = {}
			for _, name in ipairs(entry.frames) do
				local frame = Resolve(name)
				if frame then
					frames[#frames + 1] = { frame, name }
				end
			end
			if #frames == #entry.frames then
				entry.cache = frames
			end
		end
		if Left(entry) or not Active(entry) then
			for _, held in ipairs(frames) do
				Release(held[1])
			end
			if entry.more then
				Forget(entry.row)
			end
			state.idle[entry.row] = nil
		elseif #frames > 0 or entry.more then
			local added = entry.more and Added(entry) or nil
			local full = always or (targeted and not entry.targeted) or (entry.rule == true and Holds(Opt(entry.row)))
			if not full then
				local hover = entry.hover and Resolve(entry.hover)
				if hover then
					full = Over(hover)
				else
					for _, held in ipairs(frames) do
						if Over(held[1]) then
							full = true
							break
						end
					end
				end
				-- Another addon's button beside the map, or a window of the meter placed apart, counts as the row's own under the mouse.
				for _, held in ipairs(not full and added or {}) do
					if Over(held[1]) then
						full = true
						break
					end
				end
				if not full and entry.beside then
					full = Beside(entry.beside)
				end
			end
			local idle = full and 0 or (state.idle[entry.row] or 0) + dt
			state.idle[entry.row] = idle
			local target = full and 1 or (idle >= delay and floor or nil)
			for _, held in ipairs(frames) do
				Ease(held[1], target, step, held[2])
			end
			for _, held in ipairs(added or {}) do
				Ease(held[1], target, step, held[2])
			end
		end
	end
end

-- The fight starts: every row with In combat ticked, and every row of When shown at Only in combat, is at full opacity now, not after the ease.
-- With In combat off a fight raises nothing else.
local function FightStarts()
	if ns.PartStopped(KEY, PART) then
		return
	end
	local combat = Opt("combat") == true
	for _, entry in ipairs(ENTRIES) do
		if Active(entry) and not Left(entry) and (combat or (entry.rule and Opt(entry.row) == "combat")) then
			state.idle[entry.row] = 0
			for _, name in ipairs(entry.frames) do
				local frame = Resolve(name)
				if frame and state.orig[frame] ~= nil and state.value[frame] < 1 and not Elsewhere(frame, name) then
					ns.EachPart(KEY, PART, Put, frame, 1)
				end
			end
			for frame, owner in pairs(state.added) do
				if owner == entry.row and state.orig[frame] ~= nil and state.value[frame] < 1 then
					ns.EachPart(KEY, PART, Put, frame, 1)
				end
			end
		end
	end
end

local driver

local function Tick(_, elapsed)
	state.clock = state.clock + elapsed
	if state.clock < EVERY then
		return
	end
	local dt = state.clock
	state.clock = 0
	ns.Try(KEY, Step, dt)
end

local function Refresh()
	if ns.Enabled(KEY) then
		if not driver then
			driver = CreateFrame("Frame")
			ns.Own[driver] = true
			driver:SetScript("OnUpdate", Tick)
		end
		driver:Show()
		Step(0)
	else
		if driver then
			driver:Hide()
		end
		ReleaseAll()
		state.idle = {}
	end
end

-- The lines of /flatui status: how many frames the module holds and fades, and the rows the game has no frame for.
local function Status()
	if not ns.Enabled(KEY) or ns.PartStopped(KEY, PART) then
		return {}
	end
	local held, faded = 0, 0
	for frame, original in pairs(state.orig) do
		held = held + 1
		if (state.sent[frame] or original) < original - 0.001 then
			faded = faded + 1
		end
	end
	local lines = { ("Fading: %d %s, %d faded"):format(held, held == 1 and "frame" or "frames", faded) }
	local missing = {}
	for _, entry in ipairs(ENTRIES) do
		if Active(entry) and not Left(entry) then
			local any = false
			for _, name in ipairs(entry.frames) do
				any = any or Resolve(name) ~= nil
			end
			if not any then
				missing[#missing + 1] = entry.label
			end
		end
	end
	if #missing > 0 then
		lines[#lines + 1] = "Fading: no frame found for " .. table.concat(missing, ", ")
	end
	return lines
end

ns.Register(KEY, {
	label = "Fading",
	counted = false,
	Start = Refresh,
	Refresh = Refresh,
	Status = Status,
	events = { PLAYER_REGEN_DISABLED = FightStarts },
})

-- /flatui status names a game action bar this module has faded in this session.
ns.ClickPathReporter(function()
	local names = {}
	for _, entry in ipairs(ENTRIES) do
		if entry.bar then
			for _, name in ipairs(entry.frames) do
				local frame = state.found[name]
				if frame ~= nil and state.orig[frame] ~= nil then
					names[#names + 1] = entry.label
				end
			end
		end
	end
	if #names > 0 then
		return "Click path: Flat UI faded " .. table.concat(names, ", ") .. "."
	end
	return nil
end)
