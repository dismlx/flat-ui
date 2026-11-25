local _, ns = ...

-- Test mode: a state of the session, never saved (FlatUIDB and FlatUICharDB hold none of it, so a reload or a logout ends it). While it is on, out
-- of combat, the modules that registered here draw samples on their own frames (TM.Register), and stand-ins (TM.StandIn), frames of Flat UI's own
-- on UIParent that take no mouse, lie at the places of the game's frames that are hidden now, painted by the drawings of setup. Every change of a
-- setting reaches them through Core.lua's ns.Set, which calls TM.Changed after its own Changed, and through Apply after a change of profile.
--
-- It is turned on from the switch in the title bar of the options window (source "panel", Panel.lua), Samples on the toolbar of /flatui move
-- ("movers", MoversMode.lua), /flatui test, test on and test off ("slash", Core.lua) and a key ("key": Bindings.xml binds a click of
-- FlatUITestButton, a plain button of Flat UI's own made here, named in the game's Key Bindings as BagsBank.lua names its own). On refuses while
-- Setup has the options window; in combat it keeps the wish, and a frame after the fight ends test mode comes on while what asked is still open
-- (Wished); asked again in the same fight, the wish goes. It ends with its toggle or the bar's End; when the options window hides while it was
-- turned on there, unless /flatui move holds that window hidden (ns.MoversMode.Holding); when /flatui move closes for good after turning it on,
-- unless the options window is shown then, which takes it over; when Setup takes the window (Panel.lua's SetMode, whatever turned it on, since
-- Setup paints a draft and the samples paint the live profile); and at a reload. A fight pauses it inside PLAYER_REGEN_DISABLED, heard by a frame
-- registered as this file loads; a frame after the fight ends it comes back while what turned it on is still open (the options window shown or held
-- hidden by /flatui move, /flatui move open again), or for "slash" and "key" always, and ends otherwise.
--
-- The bar (BuildBar) picks the group and Moving (a switch that clicks and slides as the options window's do, ns.PanelKit.SwitchClick and Slider),
-- opens Bags, Bank, Gear, Finder, Queue (the Trinket queue window) and Move (/flatui move, with the samples kept on) and has End. It stands above
-- or under the options window (BarSpot); dragged, it stays where it was dropped until a
-- double-click on its title puts it back. The bar is 1044 wide since Queue joined it (the controls end at 956 of a live strip 968 wide, End at
-- 976).
--
-- A stand-in reads of the game frame it stands in for only its place and size (ns.MoverRect), its effective scale against UIParent's, its strata,
-- its level (at most 300 in HIGH, so that it lies under the options window and the welcome screen there) and its shown flag
-- (ns.MoverShown), each through ns.IsSecret or ns.Finite; it writes nothing on it, calls no other method of it and adds
-- no hook; Hide.lua's H.Holds reads its parents. It shows while test mode is on and not paused, its module is on (ns.ModuleOn), its gate passes,
-- the game frame is not shown (or its own real rule says the real one is not), the Hidden frames page does not hide that frame or a frame it
-- hangs from (ns.HideFrames: its row ticked, or H.Holds, as the pet frame and the totems hang from the player frame), and the frame has a place:
-- not one the movers count as Offstage (Movers.lua:1577-1583), which the bar names instead. A poll every 0.25 s (Movers.lua's HANDLES_EVERY)
-- shows, hides and places them again; a change of a setting paints the shown ones again once, on the next frame. Build, Paint, gate, real and
-- Animate run under pcall, and the first error of a stand-in goes to the error handler once and turns that stand-in off for the session, nothing
-- else.
--
-- The contract the other files code against (spec section 5.1):
--   TM.IsOn()            true while on and not paused: the one read every part uses in Refresh, Update or a show rule.
--   TM.On(source)        source "panel", "movers", "slash" or "key"; false (with a line that says why) in combat or while Setup has the window.
--                        In combat it keeps the wish for the fight's end ("comes on when the fight ends"), or takes back the one it kept ("stays off").
--   TM.Off(why)          why "toggle", "panel", "movers" or "setup"; when off, "toggle" only takes back a wish of a fight.
--   TM.Toggle(source)    Off when on (paused included), else On(source).
--   TM.Pass(source)      gives a mode that is on to another source (/flatui move closing for good hands it to the options window that is shown).
--   TM.Source()          the source while on, paused included, else nil.
--   TM.Wanted()          while off: the source that asked for it in a fight, which the fight's end turns on; else nil.
--   TM.Drop(source)      takes back a wish of that source (any, when nil) with no line: the options window drops its own as it hides.
--   TM.Epoch()           a number that goes up at every On, Off, pause and resume: the token of every sample timer.
--   TM.Group()           "solo", "party", "raid10", "raid20" or "raid40" (default "party"), chosen on the bar for the session.
--   TM.SetGroup(group)   what the bar's Group runs: entries get Changed("test.group") and their refresh, and the stand-ins are polled and painted.
--   TM.GroupSize()       0, 4 (the party members), 10, 20 or 40.
--   TM.Moving()          the bar's Moving: false freezes Animate and Tick.
--   TM.SetMoving(on)     what the bar's Moving runs: entries get Changed("test.moving").
--   TM.Sound(id)         true only the first time it is asked for this id since the last On: the gate of every sample sound.
--   TM.Shown(id)         true while the stand-in with that id shows.
--   TM.Changed(path)     Core.lua calls it after every ns.Set and after a change of profile ("*").
--   TM.Repaint()         while on: the shown stand-ins are painted again on the next frame (a game variable they are drawn from changed).
--   TM.Watch(fn)         at load: fn(TM.IsOn()) runs after every On, Off, pause and resume, so a file can run something only while test mode is on.
--   TM.Status()          the line of /flatui status while on, paused included; nil while off.
--   TM.BarRect()         while the bar shows: its left, bottom, width and height in the units of UIParent, and where it stands ("top", "above" or
--                        "below" the options window, or "dragged"); else nil. The reload notice (Reload.lua) keeps clear of it.
--   TM.Register(id, spec)  at load, after the module's ns.Register. spec: module (a module key, required), label, refresh (true: On, Off, pause,
--                        resume and the group run ns.RefreshModule), Start, Stop, Changed(path), Tick(now) with every (seconds, default 1; one shared
--                        ticker, skipped while not TM.Moving()). Each runs through ns.Try(module, ...), and only while ns.ModuleOn(module). Start
--                        runs at On, at resume, after the module's Start while on (ns.AddStart) and when the module comes on while on; Stop at
--                        Off, at pause and when the module goes off while on.
--   TM.StandIn(spec)     at load. spec: id (unique), module, game (the global name of the game frame), label (for the bar, else id), corner
--                        (default TOPLEFT), fit (true: the holder takes the size of the game frame's rectangle and Paint gets w and h), gate(),
--                        real() (default: the game frame is shown), Build(holder) once on the first show, Paint(holder, w, h) under
--                        ns.Viewing(ns.LiveView) that returns its width and height when not fit, Animate(holder, elapsed, now) every frame while
--                        it shows and TM.Moving(), fills, text and alpha only.

local TM = {}
ns.TestMode = TM

-- First thing as the file loads, so this frame hears the start of a fight before the frames registered after it.
local events = CreateFrame("Frame")
ns.Own[events] = true
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")

-- The state of the session: on, the source that turned it on, paused for a fight, the token of timers, the group on the bar and Moving.
-- wanted: the source that asked for it in a fight, for the fight's end (TM.On, Wished).
local S = { on = false, source = nil, paused = false, epoch = 0, group = "party", moving = true, wanted = nil }
-- The entries and the stand-ins, in the order they were given, and by id. heard: the sounds asked for since the last On.
local entries, entryById, standins, standinById, heard = {}, {}, {}, {}, {}
-- What TM.Watch was given, told after every On, Off, pause and resume.
local watchers = {}
-- The bar and what it shows.
local ui = { notes = {} }
local clock = { poll = 0, bar = 0 }

local POLL, BAR_EVERY = 0.25, 0.5
-- The most level a stand-in takes in HIGH, the strata of the options window (level 500, Panel.lua's LEVEL) and the welcome screen (800,
-- SetupWelcome.lua), so it and its drawing stay under both. A game frame there can stand at any level: the player's cast bar is a toplevel frame
-- of HIGH, which the game raises above the others (Blizzard_UIPanels_Game/Mainline/CastingBarFrame.xml:468), and its stand-in drew over the window.
local UNDER_PANEL = 300
local BAR_W, BAR_H, TOP = 1044, 40, -8
-- The most time between the two clicks of a double-click on the bar's title, in seconds.
local DOUBLE = 0.3
local SOURCES = { panel = "options", movers = "/flatui move", slash = "/flatui test", key = "key" }
local GROUPS = { { "solo", "Solo", 0 }, { "party", "Party", 4 }, { "raid10", "Raid 10", 10 }, { "raid20", "Raid 20", 20 }, { "raid40", "Raid 40", 40 } }
local GROUP_SIZE = { solo = 0, party = 4, raid10 = 10, raid20 = 20, raid40 = 40 }
-- The share of the width and height of a rectangle at each point.
local CORNERS = { TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 } }
local STRATA = { BACKGROUND = true, LOW = true, MEDIUM = true, HIGH = true, DIALOG = true, FULLSCREEN = true, FULLSCREEN_DIALOG = true,
	TOOLTIP = true }
local SAY = {
	combat = "Flat UI: test mode comes on when the fight ends.",
	stays = "Flat UI: test mode stays off.",
	setup = "Flat UI: finish or close Setup first.",
	pause = "Flat UI: test mode pauses for combat.",
	line = "Samples fill in for hidden frames; your real frames take over when they show. Esc > Edit Mode shows the game's own previews.",
	windows = "Open a game window (C, P, N...) to see its look change.",
	place = "%s: no place yet (open Edit Mode once)",
}
-- The tooltip of each control of the bar, by the id of a Group choice or the name of the control: its title, then one line.
local TIPS = {
	solo = { "Solo", "No party or raid samples: you alone, with your target, focus and pet." },
	party = { "Party", "Four sample party members, while you are in no group." },
	raid10 = { "Raid 10", "10 sample members in groups, as Edit Mode lays them out, while you are in no raid." },
	raid20 = { "Raid 20", "20 sample members in groups, as Edit Mode lays them out, while you are in no raid." },
	raid40 = { "Raid 40", "40 sample members in groups, as Edit Mode lays them out, while you are in no raid." },
	moving = { "Moving", "Casts fill, health drifts and cooldowns run. Off holds every sample still, so a look can be judged." },
	Bags = { "Bags", "Opens or closes Flat UI's bag window, as /flatui bags." },
	Bank = { "Bank", "Opens or closes your bank window, as /flatui bank: live at the banker, else as you last left it." },
	Gear = { "Gear", "Opens or closes the Gear comparison window, as /flatui gear." },
	Finder = { "Finder", "Opens or closes the item finder, as the Find button of the Gear comparison window." },
	Queue = { "Queue", "Opens or closes the Trinket queue window, as /flatui queue." },
	Move = { "Move", "Opens /flatui move with these samples, so each frame can be placed where it shows. Press it again to close it." },
	Title = { "Test mode bar", "Drag the bar to move it; double-click here to put it back." },
	End = { "End", "Turns test mode off. Nothing was saved." },
}

local function Report(err)
	local handler = type(geterrorhandler) == "function" and geterrorhandler()
	if type(handler) == "function" then
		handler(err)
	end
end

-- Runs fn and hands an error to the game's error handler.
local function Safe(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		Report(err)
	end
	return ok
end

local function Fn(value)
	return type(value) == "function" and value or nil
end

local function Fighting()
	return InCombatLockdown() == true
end

-- Entries ----------------------------------------------------------------------------------------------------------------------------------------

local function Run(entry, name, ...)
	local fn = entry[name]
	if fn then
		return ns.Try(entry.module, fn, ...)
	end
	return true
end

-- Starts an entry whose module is on. True when it started now.
local function StartEntry(entry)
	if entry.running or not ns.ModuleOn(entry.module) then
		return false
	end
	entry.running, entry.acc = true, 0
	Run(entry, "Start")
	return true
end

local function StopEntry(entry)
	if not entry.running then
		return false
	end
	entry.running = false
	Run(entry, "Stop")
	return true
end

-- Refreshes once each module of the entries that ask for it.
local function Refresh(list)
	local done = {}
	for _, entry in ipairs(list) do
		if entry.refresh and not done[entry.module] then
			done[entry.module] = true
			ns.RefreshModule(entry.module)
		end
	end
end

local function StartAll()
	local started = {}
	for _, entry in ipairs(entries) do
		if StartEntry(entry) then
			started[#started + 1] = entry
		end
	end
	Refresh(started)
end

local function StopAll()
	local stopped = {}
	for _, entry in ipairs(entries) do
		if StopEntry(entry) then
			stopped[#stopped + 1] = entry
		end
	end
	Refresh(stopped)
end

-- Tells every running entry of a change of the bar, and refreshes those that ask for it.
local function Tell(path)
	local list = {}
	for _, entry in ipairs(entries) do
		if entry.running then
			if entry.Changed then
				ns.Try(entry.module, entry.Changed, path)
			end
			list[#list + 1] = entry
		end
	end
	Refresh(list)
end

-- Stand-ins --------------------------------------------------------------------------------------------------------------------------------------

-- What a game frame's method answers, or nil when it raises or the answer is secret.
local function Read(frame, method)
	local ok, value = pcall(frame[method], frame)
	if ok and not ns.IsSecret(value) then
		return value
	end
	return nil
end

local function GameFrame(si)
	local frame = _G[si.game]
	if type(frame) ~= "table" or ns.IsSecret(frame) or ns.Forbidden(frame) then
		return nil
	end
	return frame
end

-- The effective scale of a frame against UIParent's, or 1 when either will not say.
local function Scale(frame)
	local mine, base = Read(frame, "GetEffectiveScale"), Read(UIParent, "GetEffectiveScale")
	if ns.Finite(mine) and ns.Finite(base) and mine > 0 and base > 0 then
		return mine / base
	end
	return 1
end

-- True for a frame the movers count as Offstage (Movers.lua:1577-1583): one Edit Mode owns, not shown, with no saved spot, that is a bar of the
-- game's stacks or still at the corner Edit Mode starts every frame at, UIParent's top left (read here from its rectangle: Movers.lua's
-- AtPlaceholder reads its point).
local function Offstage(si, frame, left, bottom, height)
	local kit = ns.MoverKit
	local info = type(kit) == "table" and type(kit.BY_NAME) == "table" and kit.BY_NAME[si.game] or nil
	if type(info) ~= "table" or not info.system or info.keptHidden then
		return false
	end
	if ns.MoverShown(frame) == true or (type(ns.MoverSaved) == "function" and ns.MoverSaved(si.game)) then
		return false
	end
	if info.stack == true then
		return true
	end
	local top = Read(UIParent, "GetHeight")
	return ns.Finite(top) and math.abs(left) < 0.5 and math.abs(bottom + height - top) < 0.5
end

-- True while the Hidden frames page hides the game frame (Hide.lua): its own row is ticked, or it hangs from a frame that is held hidden (H.Holds),
-- as the pet frame, the totems and a cast bar locked to it hang from the player frame.
local function HiddenByPage(si, frame)
	local hide = ns.HideFrames
	if type(hide) ~= "table" then
		return false
	end
	if type(hide.Key) == "function" and type(hide.Hidden) == "function" then
		local key = hide.Key(si.game)
		if key ~= nil and hide.Hidden(key) == true then
			return true
		end
	end
	return type(hide.Holds) == "function" and hide.Holds(frame) == true
end

local function HideStandIn(si)
	si.shown = false
	if si.holder then
		si.holder:SetScript("OnUpdate", nil)
		si.holder:Hide()
	end
end

-- The first error of a stand-in: said once, and the stand-in is off for the session.
local function Broken(si, err)
	if not si.broken then
		si.broken = true
		Report(("Flat UI test mode, stand-in %s: %s"):format(si.id, tostring(err)))
	end
	HideStandIn(si)
end

-- A rule of a stand-in: its answer, or nil after an error (the stand-in is then broken).
local function Rule(si, fn)
	local ok, answer = pcall(fn)
	if not ok then
		Broken(si, answer)
		return nil
	end
	return answer == true
end

-- Whether a stand-in shows now: false, "offstage" for a frame with no place yet, or true with the game frame's left, bottom, width and height in
-- UIParent's units, its scale against UIParent's and the frame.
local function Want(si)
	if si.broken or not TM.IsOn() or not ns.ModuleOn(si.module) or type(ns.MoverRect) ~= "function" or type(ns.MoverShown) ~= "function" then
		return false
	end
	local frame = GameFrame(si)
	if not frame or HiddenByPage(si, frame) then
		return false
	end
	if si.gate and not Rule(si, si.gate) then
		return false
	end
	local real
	if si.real then
		real = Rule(si, si.real)
		if real == nil then
			return false
		end
	else
		real = ns.MoverShown(frame) == true
	end
	if real then
		return false
	end
	local left, bottom, width, height = ns.MoverRect(frame)
	if not (ns.Finite(left) and ns.Finite(bottom) and ns.Finite(width) and ns.Finite(height)) then
		return false
	end
	if Offstage(si, frame, left, bottom, height) then
		return "offstage"
	end
	return true, left, bottom, width, height, Scale(frame), frame
end

-- Puts the holder's corner on the same corner of the game frame's rectangle, at the game frame's scale, strata and level, at most UNDER_PANEL in HIGH.
-- Offsets are in the holder's own units.
local function Place(si, frame)
	local holder, at, k = si.holder, si.at, si.at.k
	local share = CORNERS[si.corner]
	holder:SetScale(k)
	holder:ClearAllPoints()
	holder:SetPoint(si.corner, UIParent, "BOTTOMLEFT", (at.l + at.w * share[1]) / k, (at.b + at.h * share[2]) / k)
	if si.fit then
		holder:SetSize(math.max(1, at.w / k), math.max(1, at.h / k))
	end
	local strata = Read(frame, "GetFrameStrata")
	strata = type(strata) == "string" and STRATA[strata] and strata or "MEDIUM"
	holder:SetFrameStrata(strata)
	local level = Read(frame, "GetFrameLevel")
	if ns.Finite(level) and level >= 0 then
		holder:SetFrameLevel(math.min(level, strata == "HIGH" and UNDER_PANEL or 9000))
	end
end

-- Paints a stand-in from the live profile, and gives the holder the size the painter returns.
local function Paint(si)
	local w, h
	if si.fit then
		w, h = math.max(1, si.at.w / si.at.k), math.max(1, si.at.h / si.at.k)
	end
	local ok, width, height = ns.Viewing(ns.LiveView, si.Paint, si.holder, w, h)
	if not ok then
		Broken(si, width)
		return false
	end
	if not si.fit and ns.Finite(width) and ns.Finite(height) and width > 0 and height > 0 then
		si.holder:SetSize(width, height)
	end
	return true
end

-- Animate runs on the holder while it shows and Moving is on.
local function Animating(si)
	if si.holder then
		si.holder:SetScript("OnUpdate", (si.shown and si.Animate and S.moving) and si.tick or nil)
	end
end

local function ShowStandIn(si, frame)
	if not si.holder then
		local holder = CreateFrame("Frame", nil, UIParent)
		ns.Own[holder] = true
		holder:EnableMouse(false)
		holder:SetSize(1, 1)
		holder:Hide()
		si.holder = holder
		if si.Build then
			local ok, err = pcall(si.Build, holder)
			if not ok then
				Broken(si, err)
				return
			end
		end
	end
	Place(si, frame)
	if not Paint(si) then
		return
	end
	si.holder:Show()
	si.shown = true
	Animating(si)
end

local function Moved(at, l, b, w, h, k)
	return math.abs(at.l - l) > 0.01 or math.abs(at.b - b) > 0.01 or math.abs(at.w - w) > 0.01 or math.abs(at.h - h) > 0.01
		or math.abs(at.k - k) > 0.0001
end

-- Shows, hides and places each stand-in again, and lists those with no place yet for the bar.
local function Poll()
	local notes = {}
	for _, si in ipairs(standins) do
		local want, l, b, w, h, k, frame = Want(si)
		if want == true then
			local at = si.at
			if not si.shown then
				at.l, at.b, at.w, at.h, at.k = l, b, w, h, k
				ShowStandIn(si, frame)
			elseif Moved(at, l, b, w, h, k) then
				at.l, at.b, at.w, at.h, at.k = l, b, w, h, k
				Place(si, frame)
				Paint(si)
			end
		else
			if si.shown then
				HideStandIn(si)
			end
			if want == "offstage" then
				notes[#notes + 1] = SAY.place:format(si.label)
			end
		end
	end
	ui.notes = notes
end

local function PaintShown()
	for _, si in ipairs(standins) do
		if si.shown and not si.broken then
			Paint(si)
		end
	end
end

local function HideStandIns()
	for _, si in ipairs(standins) do
		HideStandIn(si)
	end
	ui.notes = {}
end

-- The bar -----------------------------------------------------------------------------------------------------------------------------------------

-- The words of /flatui bags, bank and gear, as typed.
local function Word(word)
	for _, module in pairs(ns.modules or {}) do
		local command = type(module) == "table" and type(module.slash) == "table" and module.slash[word]
		if type(command) == "function" then
			Safe(command, "")
			return
		end
	end
end

local function Finder()
	if type(ns.GearSearchToggle) == "function" then
		Safe(ns.GearSearchToggle)
	end
end

-- The tooltip of a control of the bar (TIPS), under it, as the other tooltips of Flat UI's own: GameTooltip, unless the game forbids it.
local function Tip(owner, key)
	local tip = TIPS[key]
	if not tip or ns.Forbidden(GameTooltip) then
		return
	end
	ui.tipOwner = owner
	pcall(function()
		GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
		GameTooltip:SetText(tip[1], 1, 1, 1)
		GameTooltip:AddLine(tip[2], 0.66, 0.68, 0.62, true)
		GameTooltip:Show()
	end)
end

-- Hides the tooltip while it is the bar's: owner, or any control of the bar when owner is nil (the bar hid under the cursor).
local function Untip(owner)
	owner = owner or ui.tipOwner
	if not owner or ns.Forbidden(GameTooltip) then
		return
	end
	if ui.tipOwner == owner then
		ui.tipOwner = nil
	end
	local ok, owned = pcall(GameTooltip.IsOwned, GameTooltip, owner)
	if ok and owned == true then
		GameTooltip:Hide()
	end
end

-- A chosen segment is in the accent, one under the cursor takes the hover backing, as the controls of the options window do; Moving lightens under
-- the cursor the same way.
local function PaintBar()
	local look = ns.PanelLook
	for _, segment in ipairs(ui.segments) do
		local chosen = S.group == segment.id
		local hover = segment.hover == true and not chosen
		look.Backing(segment.outline, chosen and "accent" or hover and "hover" or "card", chosen and 0.18 or 1, chosen and "accent" or "line")
		ns.PanelKit.Tint(segment.label, (chosen or hover) and "text" or "text-dim")
	end
	if ui.toggleHover then
		look.Solid(ui.track, S.moving and "accent-hover" or "hover")
	else
		look.Solid(ui.track, S.moving and "accent" or "raised")
	end
	look.Solid(ui.knob, S.moving and "on-accent" or "text-dim")
	-- The knob slides to its end (ns.PanelKit.Slider), as the switches of the options window do.
	if ui.placeKnob then
		ui.placeKnob(S.moving == true)
	else
		ui.knob:ClearAllPoints()
		ui.knob:SetPoint("LEFT", ui.toggle, "LEFT", S.moving and 18 or 2, 0)
	end
end

-- Where the bar goes: under the toolbar of /flatui move while it shows, else at the top of the screen; but while the options window shows and that
-- would cover its title bar (the search field, the Test mode switch and the drag area), just above the window when there is room, else just
-- under it (the bar is clamped to the screen). Returns "top" and the offset, or "above" or "below" and the window.
local function BarSpot()
	local kit = ns.MoverKit
	local movers = type(kit) == "table" and type(kit.IsOpen) == "function" and kit.IsOpen() == true
	local y = movers and TOP - 46 or TOP
	local panel = ns.PanelKit
	local window = type(ns.PanelShown) == "function" and ns.PanelShown() and type(panel) == "table" and panel.Window() or nil
	if not window then
		return "top", y
	end
	local _, bottom, _, height = panel.Rect(window)
	local screen, tall = Read(UIParent, "GetHeight"), Read(ui.bar, "GetHeight")
	if not (ns.Finite(bottom) and ns.Finite(height) and ns.Finite(screen) and ns.Finite(tall)) or height <= 0 then
		return "top", y
	end
	local top = bottom + height
	local title = top - height * panel.TITLE / panel.HEIGHT
	local barTop = screen + y
	if barTop - tall >= top or barTop <= title then
		return "top", y
	end
	if top + tall - TOP <= screen then
		return "above", window
	end
	return "below", window
end

-- Places the bar at BarSpot, unless it was dragged this session: it then stays where it was dropped, until a double-click on its title.
local function PlaceBar()
	if ui.dragged then
		return
	end
	local spot, at = BarSpot()
	if ui.spot == spot and ui.at == at then
		return
	end
	ui.spot, ui.at = spot, at
	ui.bar:ClearAllPoints()
	if spot == "above" then
		ui.bar:SetPoint("BOTTOM", at, "TOP", 0, -TOP)
	elseif spot == "below" then
		ui.bar:SetPoint("TOP", at, "BOTTOM", 0, TOP)
	else
		ui.bar:SetPoint("TOP", UIParent, "TOP", 0, at)
	end
end

local function UpdateBar()
	if not ui.bar then
		return
	end
	ui.title:SetText(S.paused and "Test mode: paused for combat" or "Test mode")
	ui.live:SetShown(not S.paused)
	PaintBar()
	local text = SAY.line
	if not S.paused then
		local look = ns.PanelLook
		if type(ns.PanelShown) == "function" and ns.PanelShown() and not (ns.PanelInMode and ns.PanelInMode()) and look and look.Page() == "windows" then
			text = text .. " " .. SAY.windows
		end
		for _, note in ipairs(ui.notes) do
			text = text .. "\n" .. note
		end
	end
	ui.line:SetText(text)
	local height = ui.line:GetStringHeight()
	ui.bar:SetHeight(BAR_H + (ns.Finite(height) and height or 12) + 10)
	PlaceBar()
end

-- A label and a row of choices, a switch, the windows and End, with a dim line under them. Built with the widgets of the options window
-- (ns.PanelKit), the first time test mode is on. Each control lights up under the cursor and has a one-line tooltip (TIPS).
local function BuildBar()
	local kit, look = ns.PanelKit, ns.PanelLook
	local bar = kit.Frame(UIParent)
	bar:SetFrameStrata("DIALOG")
	bar:SetSize(BAR_W, BAR_H + 22)
	bar:EnableMouse(true)
	-- Dragged by any part that is not a control, for the session (it is no named frame, so the game keeps no spot of it).
	bar:SetMovable(true)
	bar:SetClampedToScreen(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	bar:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		ui.dragged = true
	end)
	local outline = ns.Outline(bar, bar, true)
	kit.Painted(function()
		look.Backing(outline, "card", 1, "line-strong")
	end)
	ui.title = kit.Label(bar, "GameFontNormal", "LEFT", 190)
	ui.title:SetPoint("LEFT", bar, "TOPLEFT", 12, -BAR_H / 2)
	-- Over the title: a drag moves the bar as from any other part, and a double-click puts a dragged bar back at its own place (PlaceBar).
	local grip = kit.Frame(bar)
	grip:SetSize(190, BAR_H)
	grip:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	grip:EnableMouse(true)
	grip:RegisterForDrag("LeftButton")
	grip:SetScript("OnDragStart", function()
		bar:StartMoving()
	end)
	grip:SetScript("OnDragStop", function()
		bar:StopMovingOrSizing()
		ui.dragged = true
	end)
	grip:SetScript("OnMouseDown", function(_, button)
		if button ~= "LeftButton" then
			return
		end
		local now = GetTime()
		if ui.clicked and now - ui.clicked <= DOUBLE then
			ui.clicked = nil
			ui.dragged, ui.spot, ui.at = false, nil, nil
			Safe(PlaceBar)
		else
			ui.clicked = now
		end
	end)
	grip:SetScript("OnEnter", function()
		Tip(grip, "Title")
	end)
	grip:SetScript("OnLeave", function()
		Untip(grip)
	end)
	-- What hides while paused: the group, Moving and the windows.
	local live = kit.Frame(bar)
	live:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	live:SetSize(BAR_W - 76, BAR_H)
	ui.live = live
	local group = kit.Dim(kit.Label(live, "GameFontHighlightSmall", "LEFT"))
	group:SetPoint("LEFT", live, "LEFT", 206, 0)
	group:SetText("Group")
	ui.segments = {}
	for index, choice in ipairs(GROUPS) do
		local segment = kit.Frame(live)
		segment:SetSize(54, 24)
		segment:SetPoint("LEFT", live, "LEFT", 246 + (index - 1) * 54, 0)
		local entry = { id = choice[1], outline = ns.Outline(segment, segment, true) }
		entry.label = kit.Label(segment, "GameFontHighlightSmall", "CENTER")
		entry.label:SetPoint("CENTER", segment, "CENTER", 0, 0)
		entry.label:SetText(choice[2])
		kit.Clickable(segment, function()
			TM.SetGroup(choice[1])
		end)
		segment:SetScript("OnEnter", function()
			entry.hover = true
			PaintBar()
			Tip(segment, choice[1])
		end)
		segment:SetScript("OnLeave", function()
			entry.hover = false
			PaintBar()
			Untip(segment)
		end)
		ui.segments[index] = entry
	end
	local moving = kit.Dim(kit.Label(live, "GameFontHighlightSmall", "LEFT"))
	moving:SetPoint("LEFT", live, "LEFT", 532, 0)
	moving:SetText("Moving")
	local toggle = kit.Frame(live)
	toggle:SetSize(32, 16)
	toggle:SetPoint("LEFT", live, "LEFT", 578, 0)
	ui.toggle = toggle
	ui.track = kit.Fill(toggle, "BACKGROUND")
	ui.track:SetAllPoints(toggle)
	ui.knob = kit.Fill(toggle, "ARTWORK")
	ui.knob:SetSize(12, 12)
	ui.placeKnob = type(kit.Slider) == "function" and kit.Slider(ui.knob, toggle, toggle) or nil
	-- A click plays the game's checkbox sound, higher for on, as the switches of the options window do.
	kit.Clickable(toggle, function()
		TM.SetMoving(not S.moving)
		if type(kit.SwitchClick) == "function" then
			kit.SwitchClick(S.moving == true)
		end
	end)
	toggle:SetScript("OnEnter", function()
		ui.toggleHover = true
		PaintBar()
		Tip(toggle, "moving")
	end)
	toggle:SetScript("OnLeave", function()
		ui.toggleHover = false
		PaintBar()
		Untip(toggle)
	end)
	-- The buttons keep the hover fill of kit.Button (Panel.lua); the tooltip runs after it (HookScript on a frame of Flat UI's own).
	local function Tipped(made, key)
		made:HookScript("OnEnter", function()
			Tip(made, key)
		end)
		made:HookScript("OnLeave", function()
			Untip(made)
		end)
	end
	local x = 622
	-- Move opens /flatui move (Movers' word, as the options window's Move frames runs it); the options window that turned test mode on is held
	-- hidden there (MoversMode's Holding), so test mode stays on.
	for _, button in ipairs({ { "Bags", 50, function() Word("bags") end }, { "Bank", 50, function() Word("bank") end },
		{ "Gear", 50, function() Word("gear") end }, { "Finder", 60, Finder }, { "Queue", 50, function() Word("queue") end },
		{ "Move", 54, function() Word("move") end } }) do
		local made = kit.Button(live, button[1], button[2], button[3])
		made:SetPoint("LEFT", live, "LEFT", x, 0)
		Tipped(made, button[1])
		x = x + button[2] + 4
	end
	local finish = kit.Button(bar, "End", 56, function()
		TM.Off("toggle")
	end, true)
	finish:SetPoint("RIGHT", bar, "TOPRIGHT", -12, -BAR_H / 2)
	Tipped(finish, "End")
	-- A control that hides under the cursor (End, or the controls of a pause for a fight) takes its tooltip with it; a hover it had is gone when
	-- it shows again.
	local function Gone()
		Untip(nil)
		ui.toggleHover = false
		for _, entry in ipairs(ui.segments) do
			entry.hover = false
		end
	end
	bar:SetScript("OnHide", Gone)
	live:SetScript("OnHide", Gone)
	ui.line = kit.Dim(kit.Label(bar, "GameFontHighlightSmall", "LEFT", BAR_W - 24, true))
	ui.line:SetPoint("TOPLEFT", bar, "TOPLEFT", 12, -BAR_H)
	kit.Painted(PaintBar)
	ui.bar = bar
end

-- The bar's rectangle while it shows, and where it stands (TM.BarRect).
local function BarRect()
	local bar = ui.bar
	if not bar or Read(bar, "IsVisible") ~= true or type(ns.PanelKit) ~= "table" then
		return nil
	end
	local left, bottom, width, height = ns.PanelKit.Rect(bar)
	if not (ns.Finite(left) and ns.Finite(bottom) and ns.Finite(width) and ns.Finite(height)) then
		return nil
	end
	return left, bottom, width, height, ui.dragged and "dragged" or ui.spot or "top"
end

-- The bar while on, the switch of the options window and Samples of /flatui move.
local function Controls()
	if S.on then
		if not ui.bar and type(ns.PanelKit) == "table" then
			Safe(BuildBar)
		end
		if ui.bar then
			ui.bar:Show()
			Safe(UpdateBar)
		end
	elseif ui.bar then
		ui.bar:Hide()
	end
	if type(ns.RefreshPanel) == "function" then
		Safe(ns.RefreshPanel)
	end
	local mode = ns.MoversMode
	if type(mode) == "table" and type(mode.TestChanged) == "function" then
		Safe(mode.TestChanged)
	end
	local on = TM.IsOn()
	for _, fn in ipairs(watchers) do
		Safe(fn, on)
	end
end

-- The shared ticker --------------------------------------------------------------------------------------------------------------------------------

local function Frame(_, elapsed)
	if not TM.IsOn() then
		events:SetScript("OnUpdate", nil)
		return
	end
	if S.dirty then
		S.dirty = false
		Safe(PaintShown)
	end
	clock.poll = clock.poll + elapsed
	if clock.poll >= POLL then
		clock.poll = 0
		Safe(Poll)
	end
	clock.bar = clock.bar + elapsed
	if clock.bar >= BAR_EVERY then
		clock.bar = 0
		Safe(UpdateBar)
	end
	if S.moving then
		local now = GetTime()
		for _, entry in ipairs(entries) do
			if entry.running and entry.Tick then
				entry.acc = entry.acc + elapsed
				if entry.acc >= entry.every then
					entry.acc = 0
					ns.Try(entry.module, entry.Tick, now)
				end
			end
		end
	end
end

-- On, Off, pause and resume -------------------------------------------------------------------------------------------------------------------------

-- The entries start, the ticker runs and the stand-ins show.
local function Begin()
	S.dirty = false
	clock.poll, clock.bar = 0, 0
	StartAll()
	events:SetScript("OnUpdate", Frame)
	Safe(Poll)
	Controls()
end

-- The entries stop and refresh, the ticker stops and every stand-in hides; the controls show what is left.
local function Finish()
	StopAll()
	events:SetScript("OnUpdate", nil)
	HideStandIns()
	Controls()
end

local function Pause()
	if not S.on or S.paused then
		return
	end
	S.paused = true
	S.epoch = S.epoch + 1
	Finish()
	print(SAY.pause)
end

-- True while what turned test mode on (or what asked for it in a fight: source) is still open.
local function StillOpen(source)
	source = source or S.source
	if source == "panel" then
		local mode = ns.MoversMode
		return (type(ns.PanelShown) == "function" and ns.PanelShown() == true)
			or (type(mode) == "table" and type(mode.Holding) == "function" and mode.Holding() == true)
	elseif source == "movers" then
		local kit = ns.MoverKit
		return type(kit) == "table" and type(kit.IsOpen) == "function" and kit.IsOpen() == true
	end
	return true
end

local function Resume()
	if not (S.on and S.paused) or Fighting() then
		return
	end
	if not StillOpen() then
		TM.Off(S.source)
		return
	end
	S.paused = false
	S.epoch = S.epoch + 1
	Begin()
end

function TM.IsOn()
	return S.on and not S.paused
end

-- In a fight it keeps the wish (S.wanted) and says so, and the fight's end turns it on (Wished); asked again in the same fight, it takes the wish back.
function TM.On(source)
	if S.on then
		return true
	end
	if Fighting() then
		if S.wanted then
			S.wanted = nil
			print(SAY.stays)
		else
			S.wanted = SOURCES[source] and source or "slash"
			print(SAY.combat)
		end
		return false
	end
	if type(ns.PanelInMode) == "function" and ns.PanelInMode() then
		print(SAY.setup)
		return false
	end
	S.on, S.source, S.paused = true, SOURCES[source] and source or "slash", false
	S.epoch = S.epoch + 1
	heard = {}
	Begin()
	return true
end

-- why ("toggle", "panel", "movers" or "setup") names the rule that ended it, for the reader: every way ends the same.
function TM.Off(why)
	if not S.on then
		-- /flatui test off in a fight takes a wish back.
		if S.wanted and why == "toggle" then
			S.wanted = nil
			print(SAY.stays)
		end
		return
	end
	S.on, S.source, S.paused = false, nil, false
	S.epoch = S.epoch + 1
	Finish()
end

function TM.Toggle(source)
	if S.on then
		TM.Off("toggle")
		return false
	end
	return TM.On(source)
end

function TM.Pass(source)
	if S.on and SOURCES[source] then
		S.source = source
	end
end

function TM.Source()
	return S.on and S.source or nil
end

function TM.Wanted()
	return not S.on and S.wanted or nil
end

function TM.Drop(source)
	if S.wanted and (source == nil or S.wanted == source) then
		S.wanted = nil
		return true
	end
	return false
end

function TM.Epoch()
	return S.epoch
end

function TM.Group()
	return S.group
end

function TM.GroupSize()
	return GROUP_SIZE[S.group]
end

function TM.SetGroup(group)
	if not GROUP_SIZE[group] or group == S.group then
		return false
	end
	S.group = group
	if TM.IsOn() then
		Tell("test.group")
		Safe(Poll)
		S.dirty = true
	end
	Safe(UpdateBar)
	return true
end

function TM.Moving()
	return S.moving
end

function TM.SetMoving(on)
	S.moving = on == true
	for _, si in ipairs(standins) do
		Animating(si)
	end
	if TM.IsOn() then
		Tell("test.moving")
	end
	Safe(UpdateBar)
end

function TM.Sound(id)
	if id == nil or heard[id] then
		return false
	end
	heard[id] = true
	return true
end

function TM.Shown(id)
	local si = standinById[id]
	return si ~= nil and si.shown == true
end

-- After every ns.Set and a change of profile ("*"): an entry whose module went off stops, one whose module came on starts, each running entry
-- hears the path, and the shown stand-ins are painted again on the next frame, once however many changes come in this one.
function TM.Changed(path)
	if not TM.IsOn() then
		return
	end
	local started = {}
	for _, entry in ipairs(entries) do
		local on = ns.ModuleOn(entry.module)
		if entry.running and not on then
			StopEntry(entry)
		elseif not entry.running and on and StartEntry(entry) then
			started[#started + 1] = entry
		end
		if entry.running and entry.Changed then
			ns.Try(entry.module, entry.Changed, path)
		end
	end
	Refresh(started)
	S.dirty = true
end

function TM.Repaint()
	if TM.IsOn() then
		S.dirty = true
	end
end

function TM.Watch(fn)
	if type(fn) ~= "function" then
		return false
	end
	watchers[#watchers + 1] = fn
	return true
end

function TM.Status()
	if not S.on then
		return nil
	end
	local running, shown = 0, 0
	for _, entry in ipairs(entries) do
		running = running + (entry.running and 1 or 0)
	end
	for _, si in ipairs(standins) do
		shown = shown + (si.shown and 1 or 0)
	end
	return ("Test mode: %s (%s), %d samples, %d stand-ins shown"):format(S.paused and "paused for combat" or "on", SOURCES[S.source] or "?",
		running, shown)
end

function TM.BarRect()
	return BarRect()
end

function TM.Register(id, spec)
	if type(id) ~= "string" or entryById[id] or type(spec) ~= "table" or type(spec.module) ~= "string" then
		return false
	end
	local every = spec.every
	local entry = { id = id, module = spec.module, label = type(spec.label) == "string" and spec.label or id, refresh = spec.refresh == true,
		Start = Fn(spec.Start), Stop = Fn(spec.Stop), Changed = Fn(spec.Changed), Tick = Fn(spec.Tick), acc = 0,
		every = ns.Finite(every) and every > 0 and every or 1 }
	entries[#entries + 1] = entry
	entryById[id] = entry
	-- After the module's Start while on: the page was turned on, or the module starts late.
	ns.AddStart(spec.module, function()
		if TM.IsOn() and StartEntry(entry) then
			Refresh({ entry })
		end
	end)
	return true
end

function TM.StandIn(spec)
	if type(spec) ~= "table" or type(spec.id) ~= "string" or standinById[spec.id] or type(spec.module) ~= "string" or type(spec.game) ~= "string"
		or type(spec.Paint) ~= "function" then
		return false
	end
	local si = { id = spec.id, module = spec.module, game = spec.game, label = type(spec.label) == "string" and spec.label or spec.id,
		corner = CORNERS[spec.corner] and spec.corner or "TOPLEFT", fit = spec.fit == true, gate = Fn(spec.gate), real = Fn(spec.real),
		Build = Fn(spec.Build), Paint = spec.Paint, Animate = Fn(spec.Animate), at = {}, shown = false }
	si.tick = function(_, elapsed)
		local ok, err = pcall(si.Animate, si.holder, elapsed, GetTime())
		if not ok then
			Broken(si, err)
		end
	end
	standins[#standins + 1] = si
	standinById[si.id] = si
	return true
end

-- A wish of a fight (TM.On in combat), a frame after the fight ends: it turns test mode on while what asked for it is still open (the options window
-- shown and not in Setup, /flatui move open), or for "slash" and "key" always, and is dropped otherwise. A new fight in that frame keeps it.
local function Wished()
	local source = S.wanted
	if not source or S.on or Fighting() then
		return
	end
	S.wanted = nil
	if not StillOpen(source) or (source == "panel" and type(ns.PanelInMode) == "function" and ns.PanelInMode()) then
		return
	end
	TM.On(source)
end

events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		Safe(Pause)
	elseif event == "PLAYER_REGEN_ENABLED" and S.wanted and not S.on then
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				Safe(Wished)
			end)
		else
			Safe(Wished)
		end
	elseif event == "PLAYER_REGEN_ENABLED" and S.on and S.paused then
		-- A frame later, so the movers have opened again (Movers.lua's PLAYER_REGEN_ENABLED) before what turned it on is looked at.
		local epoch = S.epoch
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				if S.epoch == epoch then
					Safe(Resume)
				end
			end)
		else
			Safe(Resume)
		end
	end
end)

-- The key: Bindings.xml binds a click of this plain button of Flat UI's own, a child of UIParent with no size and no point, as the bank key's
-- (BagsBank.lua). It hears the release only, so a press toggles once; in a fight it keeps the wish for the fight's end, as TM.On does.
local BUTTON = "FlatUITestButton"
local BINDING = "CLICK " .. BUTTON .. ":LeftButton"
_G["BINDING_NAME_" .. BINDING] = "Flat UI test mode"

do
	local ok, button = pcall(CreateFrame, "Button", BUTTON, UIParent)
	if ok and type(button) == "table" then
		ns.Own[button] = true
		pcall(button.RegisterForClicks, button, "LeftButtonUp")
		button:SetScript("OnClick", function()
			Safe(TM.Toggle, "key")
		end)
	end
end
