local _, ns = ...

-- Hidden frames: each tick of the Hidden frames page (Config.lua, "hide") takes a frame of the game off the screen, and the untick gives it back as
-- it was. A frame is hidden by putting it under a frame of Flat UI's own that is never shown, the holder (a SecureHandlerBaseTemplate frame, so
-- explicitly protected, its corners on UIParent's, so a frame under it keeps its size and scale). A frame under a hidden parent is not drawn and
-- takes no mouse whatever its own shown flag says, so the game's Show of it (Edit Mode, the managed frame system, a zone change, a target) shows
-- nothing, and its alpha and its points are never touched. A reload puts every frame back under its own parent, and the module hides the ticked
-- ones again as it starts.
-- What is written is the parent, and on the way back the shown flag for a moment and the strata and level where the move changed them, only out of
-- combat: a change in a fight waits for its end (PLAYER_REGEN_ENABLED), and chat says so once a fight.
-- The move under the holder runs in a snippet of the holder (Execute, SecureHandlers.lua:680-699), whose frame handle SetParent takes an explicitly
-- protected parent (RestrictedFrames.lua:614-629), so the OnHide of the frame and of what it holds runs in the game's secure code and taints
-- nothing: a protected frame (the unit frames, the action bars) keeps working, its keys included (ActionButtonDown and ActionButtonUp use the
-- button whether it shows or not: Blizzard_ActionBar/Shared/ActionButton.lua:146-174). The way back depends on the frame. A protected frame
-- (IsProtected: the unit frames, the action bars, the extra abilities, a tracker with quest item buttons) is never placed by a call of Flat UI's
-- own, as Movers.lua says why (a placing call from an addon taints the frame's executions): the whole way back runs in one snippet, which hides
-- it while it is still not drawn (no OnHide), puts it under the parent it had when that one is explicitly protected, else under the returner,
-- and gives it its frame strata and level again where the move changed them, then shows it if its own flag was shown, so its OnShow runs
-- securely. The returner is a second frame of Flat UI's own, explicitly protected and shown, with its corners on UIParent's (set in its own
-- snippet), so the frame keeps its place, size, scale and opacity; a handle cannot be given UIParent, which is not protected. The frame stays
-- under the returner until a reload, or until the game gives it a parent: a managed frame goes back into its container as it shows
-- (ManagedFrameSystem.lua:17-19, 46-49). Any other frame is first hidden by the snippet while it is still not drawn, then put back under the
-- parent it had with the engine's own SetParent (GetFrameMetatable's methods, never a Lua method of the frame), which runs no script while it is
-- hidden, then given its strata and level again, and then shown by the snippet, so its OnShow runs securely too; nothing of Flat UI's own shows
-- it. A frame the game had hidden meanwhile stays hidden, as the game left it. A frame that cannot go back stays hidden until a reload, and chat
-- says so once.
-- The game moves some frames to another parent itself: the managed frame containers (Blizzard_ManagedFrameSystem/Shared/ManagedFrameSystem.lua:46-49),
-- Edit Mode as a frame leaves them (EditModeSystemTemplates.lua:335-344), the main bar when it attaches (MainActionBar.lua:68-87). Four times a
-- second, out of combat, while a frame is ticked, a frame of Flat UI's own looks at the parent of each ticked frame, takes a parent the game gave
-- as the one to give back, and puts the frame under the holder again; one that the client had not made yet when the module started is found the
-- same way. A managed frame that hides leaves its container's layout (ManagedFrameSystem.lua:21-23, 93-115), so the frames beside it close up, and it
-- goes back in as it shows. While Leave the game's action bars alone is on (Flat UI page), the rows of the action bars, the stance, pet, possess
-- and totem bars, the leave vehicle button, the micro menu and the game's status bars hide nothing, as for the other modules. The bag bar row
-- hides BagsBar either way, as Fading's Bag bar row fades it either way (Fade.lua): the snippet writes only its parent, which places, sizes and
-- lays out nothing (its points stay, and the holder's corners and scale are UIParent's), and the bag buttons' clicks run none of the game's
-- secure code. Movers still offers no box for it while that row is on; the list's Hidden group shows it again.
-- The Alerts row: the toasts are not under AlertFrame. The game makes them under UIParent and gives each its fullscreen frame as it shows it
-- (Blizzard_FrameXML/Mainline/AlertFrames.lua:92, 461-467), and only anchors them to AlertFrame. So each toast AlertFrame:AddAlertFrame shows
-- (ns.Follow) also goes under the holder by the snippet, out of combat, and its OnHide, run securely, lets it go at once (AlertFrames.lua:111-116,
-- 179), and the next one in the queue comes and goes the same way. A toast shown in a fight goes once the fight ends, if it is still up. A toast is
-- not given back: the game gives it its parent each time it shows it.
-- Fading (Fade.lua) writes no alpha on a frame this module holds, nor on one under it (H.Holds): just before a frame goes under the holder, Fading
-- gives it, and every frame under it that it fades, back the alpha it had (ns.FadeLetGo), and forgets them, so a frame comes back at its own alpha
-- and Fading takes it up from there. Hidden wins over faded.
-- The frames are the game's HUD frames that /flatui move moves (Movers.lua's list), but for the chat, the loot window and the tooltip's container,
-- and the parts of the minimap that Minimap and buffs knows: MinimapCluster.ZoneTextButton, .Tracking and .IndicatorFrame, GameTimeFrame,
-- TimeManagerClockButton, AddonCompartmentFrame, and the zoom buttons Minimap.ZoomIn and .ZoomOut (Blizzard_Minimap/Mainline/Minimap.xml:24-46,
-- 71-100). Windows such as the Character window open only when asked and are left out, and so are Flat UI's own frames, which have their own
-- switches. A frame that hangs from a held one goes with it: the pet frame, the totems and the class resource bars hang from the player frame
-- while Edit Mode keeps them there (Blizzard_UnitFrame/Mainline/PetFrame.xml:11, TotemFrame.xml:56, Shared/PlayerFrameTemplates.xml:12), and
-- /flatui move says so on their boxes (H.HeldBy). In /flatui move a box hides its frame with Shift and a right-click, the inspector has Hide frame,
-- and the list has a group Hidden whose eye shows a frame again (ns.HideFrames below).

local KEY = "hide"
local PART = "hidden frames"
local EVERY = 0.25
local WAITS = "Flat UI: hidden frames change when the fight ends."

-- key: the row. frames: names in the game, a dotted name reaching down from a global. bar: a row that hides nothing while Leave the game's
-- action bars alone is on. toasts: the row also hides the toasts AlertFrame shows (above).
local ENTRIES = {
	-- Action bars
	{ key = "main", bar = true, frames = { "MainActionBar" } },
	{ key = "bar2", bar = true, frames = { "MultiBarBottomLeft" } },
	{ key = "bar3", bar = true, frames = { "MultiBarBottomRight" } },
	{ key = "bar4", bar = true, frames = { "MultiBarRight" } },
	{ key = "bar5", bar = true, frames = { "MultiBarLeft" } },
	{ key = "bar6", bar = true, frames = { "MultiBar5" } },
	{ key = "bar7", bar = true, frames = { "MultiBar6" } },
	{ key = "bar8", bar = true, frames = { "MultiBar7" } },
	{ key = "stance", bar = true, frames = { "StanceBar" } },
	{ key = "pet", bar = true, frames = { "PetActionBar" } },
	{ key = "possess", bar = true, frames = { "PossessActionBar" } },
	{ key = "totem", bar = true, frames = { "MultiCastActionBarFrame" } },
	{ key = "vehicleLeave", bar = true, frames = { "MainMenuBarVehicleLeaveButton" } },
	{ key = "micro", bar = true, frames = { "MicroMenuContainer" } },
	-- Not a bar row: hidden also while Leave the game's action bars alone is on (above).
	{ key = "bagBar", frames = { "BagsBar" } },
	{ key = "xpBar", bar = true, frames = { "MainStatusTrackingBarContainer" } },
	{ key = "statusBar", bar = true, frames = { "SecondaryStatusTrackingBarContainer" } },
	-- Unit frames
	{ key = "playerFrame", frames = { "PlayerFrame" } },
	{ key = "targetFrame", frames = { "TargetFrame" } },
	{ key = "focusFrame", frames = { "FocusFrame" } },
	{ key = "petFrame", frames = { "PetFrame" } },
	{ key = "partyFrames", frames = { "PartyFrame" } },
	{ key = "raidFrames", frames = { "CompactRaidFrameContainer" } },
	{ key = "bossFrames", frames = { "BossTargetFrameContainer" } },
	-- Minimap
	{ key = "minimap", frames = { "MinimapCluster" } },
	{ key = "mapZone", frames = { "MinimapCluster.ZoneTextButton" } },
	{ key = "mapTracking", frames = { "MinimapCluster.Tracking" } },
	{ key = "mapMail", frames = { "MinimapCluster.IndicatorFrame" } },
	{ key = "mapCalendar", frames = { "GameTimeFrame" } },
	{ key = "mapClock", frames = { "TimeManagerClockButton" } },
	{ key = "mapAddons", frames = { "AddonCompartmentFrame" } },
	{ key = "mapZoom", frames = { "Minimap.ZoomIn", "Minimap.ZoomOut" } },
	-- Buffs and debuffs
	{ key = "buffs", frames = { "BuffFrame" } },
	{ key = "debuffs", frames = { "DebuffFrame" } },
	{ key = "externals", frames = { "ExternalDefensivesFrame" } },
	-- Bars and timers
	{ key = "castBar", frames = { "PlayerCastingBarFrame" } },
	{ key = "resource", frames = { "PersonalResourceDisplayFrame" } },
	{ key = "swingMain", frames = { "SwingTimerMainHandFrame" } },
	{ key = "swingOff", frames = { "SwingTimerOffHandFrame" } },
	{ key = "swingRanged", frames = { "SwingTimerRangedFrame" } },
	{ key = "mirrorTimers", frames = { "MirrorTimerContainer" } },
	{ key = "encounterBar", frames = { "EncounterBar" } },
	{ key = "durability", frames = { "DurabilityFrame" } },
	{ key = "archaeology", frames = { "ArcheologyDigsiteProgressBar" } },
	-- Messages and alerts
	{ key = "alerts", toasts = true, frames = { "AlertFrame" } },
	{ key = "errors", frames = { "UIErrorsFrame" } },
	{ key = "zoneText", frames = { "ZoneTextFrame", "SubZoneTextFrame" } },
	{ key = "raidWarning", frames = { "RaidWarningFrame" } },
	{ key = "lossOfControl", frames = { "LossOfControlFrame" } },
	{ key = "talkingHead", frames = { "TalkingHeadFrame" } },
	{ key = "topWidgets", frames = { "UIWidgetTopCenterContainerFrame" } },
	-- Trackers and meters
	{ key = "tracker", frames = { "ObjectiveTrackerFrame" } },
	{ key = "damageMeter", frames = { "DamageMeter" } },
	{ key = "queue", frames = { "QueueStatusButton" } },
	{ key = "extraAbilities", frames = { "ExtraAbilityContainer" } },
	{ key = "vehicleSeats", frames = { "VehicleSeatIndicator" } },
	{ key = "essential", frames = { "EssentialCooldownViewer" } },
	{ key = "utility", frames = { "UtilityCooldownViewer" } },
	{ key = "trackedBuffs", frames = { "BuffIconCooldownViewer" } },
	{ key = "trackedBars", frames = { "BuffBarCooldownViewer" } },
}

-- The row of each name of a frame /flatui move has a box for, a name without a dot: the first row that has it.
local BY_NAME = {}
for _, entry in ipairs(ENTRIES) do
	for _, name in ipairs(entry.frames) do
		if not name:find(".", 1, true) and BY_NAME[name] == nil then
			BY_NAME[name] = entry
		end
	end
end
local BY_KEY = {}
for _, entry in ipairs(ENTRIES) do
	BY_KEY[entry.key] = entry
end

-- held: per frame under the holder, what it goes back to: { parent, strata, level, key, stuck }, stuck once it could not go back. found: the
-- frames reached by name. told: chat has said this fight that a change waits. waiting: a change waits for the end of the fight. toasts: the
-- toasts AlertFrame has shown; toastsOn while the Alerts row hides them. inside: a snippet runs now.
local state = { held = {}, found = {}, told = false, waiting = false, clock = 0, toasts = setmetatable({}, { __mode = "k" }) }
local SNIPPET_HOLD = [[
	local f = self:GetFrameRef("f")
	if f then f:SetParent(self) end
]]
local SNIPPET_SHOWN = [[
	local f = self:GetFrameRef("f")
	if not f then return end
	if self:GetAttribute("show") then f:Show(true) else f:Hide(true) end
]]
-- The way back of a protected frame: hidden while it is not drawn, under p, its strata and level as they were, and shown again if it was.
local SNIPPET_BACK = [[
	local f, p = self:GetFrameRef("f"), self:GetFrameRef("p")
	if not (f and p) then return end
	local shown = self:GetAttribute("show")
	if shown then f:Hide(true) end
	f:SetParent(p)
	local strata, level = self:GetAttribute("strata"), self:GetAttribute("level")
	if strata and f:GetFrameStrata() ~= strata then f:SetFrameStrata(strata) end
	if level and f:GetFrameLevel() ~= level then f:SetFrameLevel(level) end
	if shown then f:Show(true) end
]]
-- The returner's corners on its parent's, UIParent's.
local SNIPPET_FILL = [[
	self:ClearAllPoints()
	self:SetAllPoints("$parent")
]]

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- The engine's methods of a frame, which no Lua of a frame replaces.
local function Methods()
	if state.methods == nil then
		local ok, meta = pcall(GetFrameMetatable)
		state.methods = ok and type(meta) == "table" and type(meta.__index) == "table" and meta.__index or false
	end
	return state.methods or nil
end

-- What an engine method of a frame gives, or nil when it fails or the answer is secret.
local function Read(method, frame)
	local methods = Methods()
	if not (methods and type(methods[method]) == "function") then
		return nil
	end
	local ok, value = pcall(methods[method], frame)
	if not ok or ns.IsSecret(value) then
		return nil
	end
	return value
end

local function Call(method, frame, ...)
	local methods = Methods()
	return methods ~= nil and type(methods[method]) == "function" and (pcall(methods[method], frame, ...))
end

-- The holder, made out of combat the first time it is needed, or nil.
local function Holder()
	if state.holder ~= nil then
		return state.holder or nil
	end
	if InCombatLockdown() then
		return nil
	end
	local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerBaseTemplate")
	if ok and type(frame) == "table" and not ns.IsSecret(frame) then
		ns.Own[frame] = true
		frame:Hide()
		frame:SetAllPoints(UIParent)
		state.holder = frame
	else
		state.holder = false
	end
	return state.holder or nil
end

-- True when the client says the frame is protected (IsProtected's first answer).
local function Protected(frame)
	return Read("IsProtected", frame) == true
end

-- True when the client says the frame is explicitly protected (IsProtected's second answer): a snippet's SetParent takes only such a parent
-- (RestrictedFrames.lua:614-629).
local function Explicit(frame)
	local methods = Methods()
	if type(frame) ~= "table" or not (methods and type(methods.IsProtected) == "function") then
		return false
	end
	local ok, _, explicit = pcall(methods.IsProtected, frame)
	return ok and not ns.IsSecret(explicit) and explicit == true
end

-- The returner, made out of combat the first time a protected frame goes back to a parent a snippet cannot give, or nil.
local function Returner()
	if state.returner ~= nil then
		return state.returner or nil
	end
	if InCombatLockdown() then
		return nil
	end
	local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerBaseTemplate")
	if ok and type(frame) == "table" and not ns.IsSecret(frame) and pcall(frame.Execute, frame, SNIPPET_FILL) then
		ns.Own[frame] = true
		state.returner = frame
	else
		state.returner = false
	end
	return state.returner or nil
end

-- Runs a snippet of the holder on a frame, out of combat and not inside another one. back: for SNIPPET_BACK, { parent, strata, level }. False
-- when it could not run.
local function Snippet(frame, body, show, back)
	local holder = not InCombatLockdown() and not state.inside and Holder()
	if not holder then
		return false
	end
	state.inside = true
	local ok = pcall(function()
		holder:SetFrameRef("f", frame)
		holder:SetAttribute("show", show == true or nil)
		if back then
			holder:SetFrameRef("p", back.parent)
			holder:SetAttribute("strata", back.strata)
			holder:SetAttribute("level", back.level)
		end
		holder:Execute(body)
	end)
	state.inside = false
	return ok
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
	if type(at) == "table" and not ns.IsSecret(at) and not ns.Forbidden(at) and at ~= UIParent then
		state.found[name] = at
		return at
	end
	return nil
end

-- A change that cannot be made in a fight waits for its end, and chat says so once a fight.
local function Wait()
	state.waiting = true
	if not state.told then
		state.told = true
		print(WAITS)
	end
end

-- Puts a frame under the holder, or leaves it there. A parent the game gave it since is the one it goes back to.
local function Hold(frame, key)
	local holder = Holder()
	local parent = Read("GetParent", frame)
	if holder and parent == holder then
		-- Ticked again: a frame that could not go back may try again at the next untick.
		if state.held[frame] then
			state.held[frame].stuck = nil
		end
		return
	elseif InCombatLockdown() then
		Wait()
		return
	elseif not (holder and parent) then
		-- A frame whose parent the client will not name could not be given back.
		return
	end
	local record = { parent = parent, strata = Read("GetFrameStrata", frame), level = Read("GetFrameLevel", frame), key = key }
	-- Fading gives the frame, and what it fades under it, its own alpha while it still shows, and writes none on it while it is held (Fade.lua).
	if type(ns.FadeLetGo) == "function" then
		pcall(ns.FadeLetGo, frame)
	end
	if Snippet(frame, SNIPPET_HOLD) and Read("GetParent", frame) == holder then
		state.held[frame] = record
	end
end

-- Puts an unprotected frame back under the parent it had with the engine's SetParent while the snippet holds it hidden, with its strata and
-- level, and has the snippet show it again if it was shown. False when it is not under that parent after.
local function PutBack(frame, record, shown)
	if shown then
		Snippet(frame, SNIPPET_SHOWN, false)
	end
	if not (Call("SetParent", frame, record.parent) and Read("GetParent", frame) == record.parent) then
		return false
	end
	if record.strata and Read("GetFrameStrata", frame) ~= record.strata then
		Call("SetFrameStrata", frame, record.strata)
	end
	if ns.Finite(record.level) and Read("GetFrameLevel", frame) ~= record.level then
		Call("SetFrameLevel", frame, record.level)
	end
	if shown then
		Snippet(frame, SNIPPET_SHOWN, true)
	end
	return true
end

-- Gives a frame back to the parent it had, with its strata, level and shown state: a protected frame all in one snippet, to that parent when it
-- is explicitly protected or else to the returner (header above). A frame that cannot go back stays held, and chat says once that a reload
-- shows it.
local function Release(frame)
	local record = state.held[frame]
	if not record or record.stuck then
		return
	elseif InCombatLockdown() then
		Wait()
		return
	end
	local holder = Holder()
	if not (holder and Read("GetParent", frame) == holder) then
		state.held[frame] = nil
		return
	end
	local shown = Read("IsShown", frame) == true
	local done
	if Protected(frame) then
		local parent = Explicit(record.parent) and record.parent or Returner()
		local back = { parent = parent, strata = record.strata, level = ns.Finite(record.level) and record.level or nil }
		done = parent ~= nil and Snippet(frame, SNIPPET_BACK, shown, back) and Read("GetParent", frame) == parent
	else
		done = PutBack(frame, record, shown)
	end
	if done then
		state.held[frame] = nil
	else
		record.stuck = true
		print(("Flat UI: %s could not be shown again. It comes back after a reload (/reload)."):format(ns.HideFrames.Label(record.key)))
	end
end

-- Puts every toast that AlertFrame shows and that is not under the holder there (header above), while the Alerts row hides them, out of combat.
-- A toast that lets go of its OnHide brings the next one in the queue, which is put there too, in the next round of the same call.
local function HoldToasts()
	if not state.toastsOn or state.inside or InCombatLockdown() or not Holder() then
		return
	end
	for _ = 1, 8 do
		local due = {}
		for toast in pairs(state.toasts) do
			if Read("IsShown", toast) == true and Read("GetParent", toast) ~= state.holder then
				due[#due + 1] = toast
			end
		end
		if #due == 0 then
			return
		end
		for _, toast in ipairs(due) do
			Snippet(toast, SNIPPET_HOLD)
		end
	end
end

-- After each AlertFrame:AddAlertFrame (ns.Follow): the toast it showed, kept for the row, and put under the holder at once out of combat.
local function AfterAlert(_, toast)
	if type(toast) == "table" and not ns.IsSecret(toast) and not ns.Forbidden(toast) then
		state.toasts[toast] = true
		HoldToasts()
	end
end

-- True while a row hides its frames: the module is on, the row is ticked, and for a bar the game's bars are not left alone.
local function Wanted(entry)
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and Opt(entry.key) == true and not (entry.bar and ns.HandsOff())
end

-- Hides what is ticked and gives back what is not. True while a row hides something, or a change waits.
local function Apply()
	local any = false
	local wanted = {}
	for _, entry in ipairs(ENTRIES) do
		local on = Wanted(entry)
		any = any or on
		for _, name in ipairs(entry.frames) do
			local frame = Resolve(name)
			if frame and on then
				wanted[frame] = true
				ns.EachPart(KEY, PART, Hold, frame, entry.key)
			end
		end
	end
	-- The toasts of the Alerts row, which are not under AlertFrame (header above).
	state.toastsOn = Wanted(BY_KEY.alerts)
	if state.toastsOn then
		if not state.followed and type(AlertFrame) == "table" then
			state.followed = ns.Follow(AlertFrame, "AddAlertFrame", AfterAlert) == true
		end
		HoldToasts()
	end
	-- A frame goes back also once the part or the module has stopped, and one that cannot is forgotten.
	for frame in pairs(state.held) do
		if not wanted[frame] and not pcall(Release, frame) then
			state.held[frame] = nil
		end
	end
	return any or next(state.held) ~= nil
end

local driver = CreateFrame("Frame")
ns.Own[driver] = true
driver:Hide()

local function Run()
	state.waiting = false
	local busy = Apply()
	driver:SetShown(busy or state.waiting)
end

-- A module that has stopped still gives its frames back, out of combat.
local function Step()
	if ns.IsStopped(KEY) then
		pcall(Run)
	else
		ns.Try(KEY, Run)
	end
end

driver:SetScript("OnUpdate", function(_, elapsed)
	state.clock = state.clock + elapsed
	if state.clock < EVERY then
		return
	end
	state.clock = 0
	if not InCombatLockdown() then
		Step()
	end
end)
-- Also with the module off: what it held goes back once the fight is over.
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:RegisterEvent("PLAYER_REGEN_DISABLED")
driver:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		state.told = false
	elseif state.waiting or next(state.held) ~= nil then
		Step()
	end
end)

local function Refresh()
	Run()
end

-- The lines of /flatui status: how many frames are hidden, a change that waits, the unticked ones that come back after a reload, and the ticked
-- rows the game has no frame for.
local function Status()
	local count = 0
	for _ in pairs(state.held) do
		count = count + 1
	end
	local lines = {}
	if count > 0 or ns.Enabled(KEY) then
		lines[1] = ("Hidden frames: %d %s hidden"):format(count, count == 1 and "frame" or "frames")
	end
	if state.waiting then
		lines[#lines + 1] = "Hidden frames: a change waits for the end of the fight"
	end
	local stuck = 0
	for _, record in pairs(state.held) do
		stuck = stuck + (record.stuck and 1 or 0)
	end
	if stuck > 0 then
		lines[#lines + 1] = ("Hidden frames: %d unticked %s come back after a reload"):format(stuck, stuck == 1 and "frame" or "frames")
	end
	local missing = {}
	for _, entry in ipairs(ENTRIES) do
		if Wanted(entry) then
			local any = false
			for _, name in ipairs(entry.frames) do
				any = any or Resolve(name) ~= nil
			end
			if not any then
				missing[#missing + 1] = ns.HideFrames.Label(entry.key)
			end
		end
	end
	if #missing > 0 then
		lines[#lines + 1] = "Hidden frames: no frame found for " .. table.concat(missing, ", ")
	end
	return lines
end

-- For /flatui move (Movers.lua, MoversMode.lua) and /flatui hide. ---------------------------------------------

local H = {}
ns.HideFrames = H

-- The label of a row, from the Hidden frames page.
function H.Label(key)
	if not state.labels then
		state.labels = {}
		for _, page in ipairs(ns.PAGES) do
			if page.key == KEY then
				for _, item in ipairs(page) do
					if item.key then
						state.labels[item.key] = item.label
					end
				end
			end
		end
	end
	return state.labels[key] or key
end

-- The row that hides the frame of a box of /flatui move, or nil.
function H.Key(name)
	local entry = type(name) == "string" and BY_NAME[name] or nil
	return entry and entry.key or nil
end

-- True for a row of the game's bars while Leave the game's action bars alone is on: its tick hides nothing.
function H.Left(key)
	local entry = BY_KEY[key]
	return entry ~= nil and entry.bar == true and ns.HandsOff()
end

-- True while the row is ticked and the module on: the frame is hidden, or will be once a fight ends. Not for a row whose tick hides nothing now.
function H.Hidden(key)
	return BY_KEY[key] ~= nil and ns.Enabled(KEY) and Opt(key) == true and not H.Left(key)
end

-- True while a frame is off the screen by this module: it, or a frame it hangs from, is under the holder. Fading (Fade.lua) writes no alpha on
-- such a frame. A held frame the game gave another parent in a fight is not, until the fight ends and it is held again.
function H.Holds(frame)
	local holder = state.holder
	if not holder or next(state.held) == nil or type(frame) ~= "table" then
		return false
	end
	local at = frame
	for _ = 1, 20 do
		if at == holder then
			return true
		elseif at == nil or at == UIParent then
			return false
		end
		at = Read("GetParent", at)
	end
	return false
end

-- Ticks or unticks a row, the same setting as the page. Hiding a frame turns the module on.
function H.Set(key, on)
	if not BY_KEY[key] then
		return
	end
	if on and ns.Get(KEY .. ".enabled") ~= true then
		ns.Set(KEY .. ".enabled", true)
	end
	ns.Set(KEY .. "." .. key, on == true)
	if on and H.Left(key) then
		print("Flat UI: Leave the game's action bars alone is on (Flat UI page), so " .. H.Label(key) .. " stays shown.")
	end
end

-- True while the row is ticked and the module on, also for a row whose tick hides nothing now (H.Left).
function H.Ticked(key)
	return BY_KEY[key] ~= nil and ns.Enabled(KEY) and Opt(key) == true
end

-- Hides the frame of a row, or shows it again: an untick for a row that is ticked, also one whose tick hides nothing now.
function H.Toggle(key)
	H.Set(key, not H.Ticked(key))
end

-- The row whose frame takes this one off the screen, the frame itself or one it hangs from, as the pet frame, the totems and the class bars
-- hang from the player frame while Edit Mode keeps them there. Nil when none does.
function H.HeldBy(frame)
	local holder = state.holder
	if not holder or next(state.held) == nil or type(frame) ~= "table" then
		return nil
	end
	local at = frame
	for _ = 1, 20 do
		if at == nil or at == UIParent or at == holder then
			return nil
		end
		local parent = Read("GetParent", at)
		if parent == holder then
			local record = state.held[at]
			return record and record.key or nil
		end
		at = parent
	end
	return nil
end

-- The hidden rows in the order of the page: { key, label, name }, name the box of /flatui move that row has, or nil.
function H.List()
	local list = {}
	for _, entry in ipairs(ENTRIES) do
		if H.Hidden(entry.key) then
			local name = entry.frames[1]
			list[#list + 1] = { key = entry.key, label = H.Label(entry.key), name = BY_NAME[name] == entry and name or nil }
		end
	end
	return list
end

ns.Register(KEY, {
	label = "Hidden frames",
	counted = false,
	Start = Refresh,
	Refresh = Refresh,
	Status = Status,
	slash = {
		hide = function()
			if type(ns.OpenPanelPage) == "function" then
				ns.OpenPanelPage(KEY)
			end
		end,
	},
	help = { "/flatui hide - the Hidden frames page of the options" },
})
