local _, ns = ...

-- Questie's tracker in Flat UI's look. While the Questie addon is loaded, its tracker exists, the Minimap and HUD module is on and Questie's
-- tracker (hud.trackerQuestie, Quests and loot page) is on, the quest tracker Questie draws in place of the objective tracker takes
-- the rows of the objective tracker: Tracker background (a flat background with a thin border round it, Questie's own backdrop faded),
-- Tracker headers (a flat band with a thin border behind the Questie Tracker heading and each zone heading), Heading size (the zone headings),
-- Tracker item buttons (a thin border round each quest item button and its icon cropped by Icon crop), Opacity in combat, and Flat UI's
-- fonts (the Interface font, Text outline and Text shadow of the Fonts page, while that page is on) on the heading and every line. Questie
-- draws no bars: a timed quest's time is a line of text (Modules/Tracker/TrackerQuestTimers.lua:134-135), so Tracker bars and Tracker bar
-- texture have nothing to style here. It is part "questie tracker" of the module, which stops alone after a few failures.
--
-- Questie's team offers it under the GNU GPL 3 (its LICENSE.md). It was read for its frame names, its structure and its redraws only, and
-- none of its code is here. The facts, from Questie 12.10.0, whose Questie_Forever.toc loads the same tracker files as its other flavours
-- (Questie_Forever.toc:254-289); on Forever it takes Era's content paths (Modules/Expansions.lua:21-24), so its tracker shows no
-- achievements, scenarios or timer ticks:
-- - QuestieTracker.Initialize makes the frames once, only while Questie's tracker is on (Modules/Tracker/QuestieTracker.lua:225-266).
--   Questie_BaseFrame is a frame on UIParent with the game's BackdropTemplate, whose backdrop Questie only colours, with SetBackdropColor and
--   SetBackdropBorderColor (TrackerBaseFrame.lua:33-59, 170-193; TrackerFadeTicker.lua:33-37), and keeps clear by default
--   (Modules/Options/QuestieOptionsDefaults.lua:109). Those two calls set the colour of the nine pieces of the backdrop and never their alpha
--   (Blizzard_SharedXML/Backdrop.lua:301-336, 406-440 of the game), so a piece faded here stays faded.
-- - Questie_HeaderFrame holds the heading "Questie Tracker: 12/20", a font string on that frame in the field trackedQuests.label, whose font
--   Questie sets at every redraw before it sizes the heading by its text (TrackerHeaderFrame.lua:40, 131-135, 200-239).
-- - The lines are linePool1 to linePool250, each with a font string, label (TrackerLine.lua:61-71; TrackerLinePool.lua:31, 46-61). A line's
--   SetMode sets the font and the height of its label for its kind, "zone", "quest" or "objective", only when the kind changes
--   (TrackerLine.lua:203-219); a redraw that puts lines away, or a change of Questie's own fonts, clears their kind (TrackerLinePool.lua:88,
--   241), and the line builder reads the label's height and width after SetMode to lay the line out (LinePool/LineBuilder.lua:60-92,
--   123-173, 214-228). So a font or height set right after SetMode is the one Questie lays the line out with.
-- - The item buttons are Questie_ItemButton1 and on, one for each quest the log holds (TrackerLinePool.lua:64-70), buttons of the game's
--   SecureActionButtonTemplate whose normal and pushed textures are the item's icon (TrackerItemButton.lua:24, 56-57), hung on a line while
--   in use and on UIParent while not (TrackerUtils.lua:1208-1250).
-- - QuestieTracker:Update draws it all again. It returns at once in a fight and waits a tenth of a second between two
--   (QuestieTracker.lua:834-860), and Questie calls it after every change of its quests and of its own settings. Questie's loader keeps its
--   modules in QuestieLoader._modules (Modules/Libs/QuestieLoader.lua:11); an older loader without that field hands an existing module out
--   from ImportModule, which makes an empty one for a name it does not know (QuestieLoader.lua:165-177), so only QuestieTracker, which every
--   Questie with a tracker has, is asked that way.
--
-- How: QuestieTracker.Update and UpdateFormatting are followed with ns.FollowTable and each line's SetMode with ns.Follow, never replaced.
-- After every redraw the frames Questie made are looked at again by their names, so a line or button that is new or handed out again is styled
-- as it is used. A line Questie gives another kind has its remembered font and height dropped, and the font Questie just set written back.
-- Flat UI's own outlines (ns.Outline) go on Questie's frames: a backdrop texture under their own art and four edges on a frame of Flat UI's
-- own, round the frame or round an anchor frame of Flat UI's own on a heading. Of Questie's own it writes only what it puts back: the alpha of
-- the nine pieces of its backdrop (ns.SetFaded), the font of its heading and of each line's label (SetFont, SetShadowOffset, through
-- ns.TextStyle, which remembers Questie's font and takes a new one Questie sets as the one to go back to), the height of a zone heading's
-- label (SetHeight, by Heading size), the texture coordinates of the item icons (SetTexCoord) and, in a fight, the alpha of Questie_BaseFrame.
-- The Objective tracker rule of the Fading page fades Questie_BaseFrame too (Fade.lua). Opacity in combat eases it down over a quarter of a second
-- as a fight starts and back up over 0.2 seconds as it ends (ns.TrackerEase, Hud.lua), and in the fight brings it back to full in 0.2 seconds while
-- the mouse is over it, easing down again as the mouse leaves (ns.TrackerHover, Hud.lua). While Opacity in combat holds it, the ease back included,
-- the Fading page leaves it alone (ns.QuestieFades); the opacity read before the first write is the one it had before Fading (ns.FadeGiven), and
-- after the fight it goes back to Fading with that one (ns.FadeTakesBack), which eases on from the opacity it has, so the tracker does not flash to full.
-- Sizes stay Questie's own: its labels have the height of its font size and the Questie Tracker heading is sized by Questie at every redraw,
-- so Heading size goes on the zone headings alone. After a change of the look Questie is asked to lay its lines out again (QuestieTracker:Update,
-- as its own options do), out of combat. Off, the row puts Questie's look back. Questie's saved settings are never written. Nothing is made on
-- a frame the game may protect in a fight (Questie's lines and base frame hold its secure item buttons): that waits for the end of the fight.
-- A Questie whose tracker lacks these frames or functions is not one this file knows: nothing is done there, and /flatui status says so.

local KEY, PART, LABEL = "hud", "questie tracker", "Minimap and HUD"
local LINES, BUTTONS = "linePool", "Questie_ItemButton"
-- More than Questie makes: the walk stops at the first name that is missing.
local MOST_LINES, MOST_BUTTONS = 500, 100
-- The pieces of a backdrop of the game's BackdropTemplate (Blizzard_SharedXML/Backdrop.lua:317-326).
local PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }
local ICONS = { "GetNormalTexture", "GetPushedTexture" }
-- A band reaches this far past the left and right of a zone line, and from this far above its text to this far below it: a zone line is 4
-- taller than its label (LineBuilder.lua:92). The band of the Questie Tracker heading starts this far in from the left of the tracker.
local BAND_X, BAND_TOP, BAND_BOTTOM, HEADING_IN = 3, 2, 2, 2
local UNKNOWN = LABEL .. ": Questie's tracker is not one Flat UI knows (%s), so it keeps Questie's look."
local REFUSED = LABEL .. ": the game refused a font on Questie's tracker, which keeps Questie's font there."
local NO_MODE = LABEL .. ": the lines of Questie's tracker have no SetMode here, so their fonts change after Questie lays them out."

-- lines: per line { label, band, anchor, hGame = the label height Questie set, hSet = the one set here }; buttons: per item button
-- { outline, cropped }; header: { label, band, anchor }; panel: the outline round the base frame; faded: Questie's backdrop is faded; alpha,
-- sent: the opacity of the base frame before a fight and the one set last, and the ease of Opacity in combat (ns.TrackerEase: target, from, t,
-- span, back, driver); followed: QuestieTracker.Update is followed; key: the look the lines were
-- last laid out with; queued, waiting: a pass waits for the next frame, a make for the end of a fight; noMode: a line had no SetMode.
local S = { lines = setmetatable({}, { __mode = "k" }), buttons = setmetatable({}, { __mode = "k" }) }

local function Opt(option)
	return ns.Get(KEY .. "." .. option)
end

local function Wanted()
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and Opt("trackerQuestie") == true
end

local function Read(t, key)
	if t == nil or ns.IsSecret(t) or type(t) ~= "table" then
		return nil
	end
	local ok, value = pcall(function()
		return t[key]
	end)
	if not ok or ns.IsSecret(value) then
		return nil
	end
	return value
end

-- A frame by its global name, or nil when it is missing or forbidden.
local function Named(name)
	local frame = rawget(_G, name)
	if ns.Forbidden(frame) then
		return nil
	end
	return frame
end

local function Loaded()
	local loader = rawget(_G, "QuestieLoader")
	return type(loader) == "table" and not ns.IsSecret(loader) and type(rawget(_G, "Questie")) == "table"
end

-- Questie's tracker module, or nil.
local function Tracker()
	if not Loaded() then
		return nil
	end
	local loader = rawget(_G, "QuestieLoader")
	local modules, tracker = Read(loader, "_modules"), nil
	if type(modules) == "table" then
		tracker = Read(modules, "QuestieTracker")
	elseif type(Read(loader, "ImportModule")) == "function" then
		local ok, found = pcall(loader.ImportModule, loader, "QuestieTracker")
		tracker = ok and found or nil
	end
	if type(tracker) ~= "table" or ns.IsSecret(tracker) then
		return nil
	end
	return tracker
end

local function Styled()
	return next(S.lines) ~= nil or next(S.buttons) ~= nil or S.panel ~= nil or S.header ~= nil or S.alpha ~= nil
end

local function Shown(frame)
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and shown == true
end

local Pass, Queue

-- Runs one piece for one frame. A stopped part is off, so it runs only to give back what it had styled, and the failure that stops it has
-- everything look again for that.
local looking = false
local function Run(fn, ...)
	if ns.PartStopped(KEY, PART) then
		pcall(fn, ...)
	elseif not ns.EachPart(KEY, PART, fn, ...) and ns.PartStopped(KEY, PART) and not looking then
		looking = true
		pcall(Pass, true)
		looking = false
	end
end

-- True in a fight for a frame the game may protect: nothing is made on it now, and everything is looked at again when the fight ends.
local function Later(frame)
	if not InCombatLockdown() or not ns.MaybeProtected(frame) then
		return false
	end
	if not S.waiting then
		S.waiting = true
		ns.OutOfCombat(function()
			S.waiting = false
			Queue()
		end)
	end
	return true
end

-- The font a text of Questie's is to have: Flat UI's Interface font, Text outline and Text shadow while the Fonts page is on (a row at the
-- game's value keeps Questie's), and for a zone heading Heading size. An empty spec gives Questie's font back.
local function Spec(heading)
	local spec = {}
	if ns.Enabled("fonts") then
		if ns.FontsLatin == nil or ns.FontsLatin() then
			spec.face = ns.FontFile(ns.Get("fonts.body"))
		end
		spec.flags = ns.OutlineFlags ~= nil and ns.OutlineFlags(ns.Get("fonts.outline")) or nil
		spec.shadow = ns.Get("fonts.shadow") == false
	end
	if heading then
		spec.percent = Opt("trackerHeaderSize") or 100
	end
	return spec
end

local function Text(label, spec)
	if label ~= nil and ns.TextStyle(label, spec) == false then
		ns.Note(KEY, REFUSED)
	end
end

-- The height of a zone heading's label at Heading size. Questie gives the label the height of its font size and lays the line out by it
-- (TrackerLine.lua:207-209, LineBuilder.lua:88-92). A height other than the one set here is one Questie set again, and the one to go back to.
local function Height(rec, percent)
	local label = rec.label
	local ok, height = pcall(label.GetHeight, label)
	if not ok or not ns.Finite(height) then
		return
	end
	if rec.hSet == nil or math.abs(height - rec.hSet) > 0.01 then
		rec.hGame, rec.hSet = height, nil
	end
	if percent ~= 100 and rec.hGame > 0 then
		local want = rec.hGame * percent / 100
		if rec.hSet ~= want then
			label:SetHeight(want)
			rec.hSet = want
		end
	elseif rec.hSet ~= nil then
		label:SetHeight(rec.hGame)
		rec.hSet = nil
	end
end

-- A flat band with a thin border behind a heading: an anchor frame of Flat UI's own on the heading's frame, placed by place, and an outline
-- round it whose backdrop is drawn on that frame under its text.
local function Band(rec, owner, on, place)
	if not rec.band then
		if not on or ns.Forbidden(owner) or Later(owner) then
			return
		end
		local anchor = CreateFrame("Frame", nil, owner)
		place(anchor, owner)
		local band = ns.Outline(owner, anchor)
		if not band then
			return
		end
		rec.anchor, rec.band = anchor, band
		ns.Count(KEY)
	end
	ns.SetOutline(rec.band, on, true)
end

local function PlaceZone(anchor, line)
	anchor:SetPoint("TOPLEFT", line, "TOPLEFT", -BAND_X, BAND_TOP)
	anchor:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", BAND_X, BAND_BOTTOM)
end

-- The heading frame is as wide as its text (TrackerHeaderFrame.lua:233-234); the band's width is the tracker's, set at each pass.
local function PlaceHeading(anchor, header)
	anchor:SetPoint("TOPLEFT", header, "TOPLEFT", HEADING_IN, BAND_TOP)
	anchor:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", HEADING_IN, BAND_BOTTOM)
	anchor:SetWidth(1)
end

-- Drops what was remembered of a label's font and height, for a line Questie has just given another kind: its SetMode has set the font and
-- height of the new kind (TrackerLine.lua:203-219), and what was set here for the old kind can be near enough to pass for them (a zone heading
-- at 85% of 12 is 10.2, a quest line 10), which would keep the old kind's size as Questie's. ns.TextStyle with nothing asked puts back the font
-- it remembered and forgets what it set, and Questie's new font is then written back as Questie set it.
local function Forget(rec)
	rec.hGame, rec.hSet = nil, nil
	local label = rec.label
	local ok, file, size, flags = pcall(label.GetFont, label)
	if not ok or ns.IsSecret(file) or ns.IsSecret(size) or ns.IsSecret(flags) or type(file) ~= "string" or not ns.Finite(size) or size <= 0 then
		return
	end
	ns.TextStyle(label, {})
	label:SetFont(file, size, type(flags) == "string" and flags or "")
end

local LineHook

-- One line: the band while it is a zone heading, Flat UI's font, and the height of a zone heading's label.
local function Line(line)
	local rec = S.lines[line]
	local on = Wanted()
	if rec == nil then
		if not on then
			return
		end
		local label = Read(line, "label")
		if type(label) ~= "table" or type(Read(label, "GetFont")) ~= "function" or type(Read(label, "SetHeight")) ~= "function" then
			ns.Note(KEY, UNKNOWN:format("a line without a label"))
			return
		end
		rec = { label = label }
		S.lines[line] = rec
		if ns.Follow(line, "SetMode", LineHook) == nil then
			-- No SetMode to follow: the fonts change after Questie lays the line out, until its next redraw.
			S.noMode = true
		end
	end
	-- rec.mode is the kind the label was last styled for. Questie clears a line's kind at each redraw (TrackerLinePool.lua:88, 241) and only
	-- its SetMode sets one, so a kind other than rec.mode means Questie set that kind's font since.
	local mode = Read(line, "mode")
	if type(mode) == "string" then
		if rec.mode ~= nil and rec.mode ~= mode then
			Forget(rec)
		end
		rec.mode = mode
	end
	local zone = on and mode == "zone"
	Band(rec, line, zone and Opt("trackerHeaders") == true, PlaceZone)
	Text(rec.label, on and Spec(zone) or {})
	Height(rec, zone and (Opt("trackerHeaderSize") or 100) or 100)
end

LineHook = function(line)
	if not ns.IsStopped(KEY) and S.lines[line] ~= nil then
		Run(Line, line)
	end
end

-- The Questie Tracker heading: its band across the tracker and Flat UI's font. Its size stays Questie's.
local function Heading(base)
	local header = Named("Questie_HeaderFrame")
	if not header then
		return
	end
	local on = Wanted()
	local rec = S.header
	if rec == nil then
		if not on then
			return
		end
		local label = Read(Read(header, "trackedQuests"), "label")
		rec = { label = type(label) == "table" and type(Read(label, "GetFont")) == "function" and label or nil }
		S.header = rec
	end
	Band(rec, header, on and Opt("trackerHeaders") == true, PlaceHeading)
	if rec.anchor then
		local ok, width = pcall(base.GetWidth, base)
		if ok and ns.Finite(width) and width > HEADING_IN * 2 + 1 then
			rec.anchor:SetWidth(width - HEADING_IN * 2)
		end
	end
	Text(rec.label, on and Spec(false) or {})
end

-- A quest item button: a thin border and a dark background, and its icon cropped. Its icon is its normal and pushed texture.
local function Button(button)
	local on = Wanted() and Opt("trackerItems") == true
	local rec = S.buttons[button]
	if rec == nil then
		if not on or Later(button) then
			return
		end
		local outline = ns.Outline(button, button)
		if not outline then
			return
		end
		rec = { outline = outline }
		S.buttons[button] = rec
		ns.Count(KEY)
	end
	ns.SetOutline(rec.outline, on, true)
	if on or rec.cropped then
		local crop = on and (Opt("crop") or 0) / 100 or 0
		for _, getter in ipairs(ICONS) do
			local ok, icon = pcall(button[getter], button)
			if ok and type(icon) == "table" and not ns.IsSecret(icon) then
				pcall(icon.SetTexCoord, icon, crop, 1 - crop, crop, 1 - crop)
			end
		end
		rec.cropped = on or nil
	end
end

-- Flat UI's background and thin border round the whole tracker, and Questie's own backdrop faded meanwhile.
local function Panel(base)
	local on = Wanted() and Opt("trackerPanel") == true
	if S.panel == nil then
		if not on or Later(base) then
			return
		end
		S.panel = ns.Outline(base, base)
		if not S.panel then
			return
		end
		ns.Count(KEY)
	end
	ns.SetOutline(S.panel, on, true)
	if on or S.faded then
		for _, name in ipairs(PIECES) do
			ns.SetFaded(Read(base, name), on)
		end
		S.faded = on or nil
	end
end

-- The opacity of the tracker in a fight, as the objective tracker's: the opacity it had is read before the first write, and the tracker eases down to
-- the opacity of the fight and back up after (ns.TrackerEase, Hud.lua, with the steps run as this file's part), or is handed to the Fading page while
-- its Objective tracker rule fades the tracker (Hud.lua's TrackerAlpha does the same for the game's). Without Hud.lua's ease it is set at once.
-- fight is nothing when the game's own state is to be asked.
local function Alpha(base, fight)
	if fight == nil then
		fight = InCombatLockdown()
	end
	local percent = Wanted() and Opt("trackerCombat") or 100
	local wanted = fight and percent < 100 and percent / 100 or nil
	local ease = ns.TrackerEase
	if wanted ~= nil then
		if S.alpha == nil then
			local given = ns.FadeGiven and ns.FadeGiven(base)
			local ok, alpha = pcall(base.GetAlpha, base)
			S.alpha = ns.Finite(given) and given or ((ok and ns.Finite(alpha)) and alpha or 1)
		end
		if ease then
			ease(S, base, S.over and S.alpha or wanted, false, Run)
			-- The mouse over the tracker keeps it at full (ns.TrackerHover).
			if ns.TrackerHover then
				ns.TrackerHover(S, base, base, wanted, Run)
			end
		elseif S.sent ~= wanted then
			base:SetAlpha(wanted)
			S.sent = wanted
		end
		return
	end
	if ns.TrackerHover then
		ns.TrackerHover(S)
	end
	if S.alpha ~= nil then
		if ns.FadeTakesBack and ns.FadeTakesBack(base, S.alpha) then
			if ns.TrackerEaseStop then
				ns.TrackerEaseStop(S)
			end
			S.alpha, S.sent = nil, nil
		elseif ease then
			ease(S, base, S.alpha, true, Run)
		else
			base:SetAlpha(S.alpha)
			S.alpha, S.sent = nil, nil
		end
	end
end

-- True for Questie's tracker while Opacity in combat holds its alpha in a fight, for the Fading page, which leaves it to this file then.
function ns.QuestieFades(frame)
	return S.sent ~= nil and frame ~= nil and frame == rawget(_G, "Questie_BaseFrame")
end

-- Looks at every frame of the tracker; full also at lines that are hidden. A line that is put away keeps its look until Questie hands it out
-- again, and its SetMode, followed, gives it the look of its new kind.
Pass = function(full)
	local base = Named("Questie_BaseFrame")
	if base == nil then
		return
	end
	Run(Panel, base)
	Run(Heading, base)
	for index = 1, MOST_LINES do
		local line = rawget(_G, LINES .. index)
		if line == nil then
			break
		end
		if not ns.Forbidden(line) and (full or S.lines[line] == nil or Shown(line)) then
			Run(Line, line)
		end
	end
	for index = 1, MOST_BUTTONS do
		local button = rawget(_G, BUTTONS .. index)
		if button == nil then
			break
		end
		if not ns.Forbidden(button) then
			Run(Button, button)
		end
	end
	Run(Alpha, base)
end

Queue = function()
	if S.queued then
		return
	end
	S.queued = true
	C_Timer.After(0, function()
		S.queued = false
		if not ns.IsStopped(KEY) and (Wanted() or Styled()) then
			Pass(true)
		end
	end)
end

-- What the lines are laid out with: when it changes, Questie lays them out again, out of combat and only once its tracker has started.
local function Look()
	if not Wanted() then
		return "off"
	end
	local spec = Spec(true)
	return ("%s|%s|%s|%s"):format(tostring(spec.face), tostring(spec.flags), tostring(spec.shadow), tostring(spec.percent))
end

local function Relayout()
	local look = Look()
	if S.key == look or InCombatLockdown() then
		return
	end
	if look == "off" and not Styled() then
		-- Nothing of Questie's was changed, so there is nothing to lay out again.
		S.key = look
		return
	end
	local tracker = Tracker()
	if tracker == nil or Read(tracker, "started") ~= true or type(Read(tracker, "Update")) ~= "function" then
		return
	end
	S.key = look
	pcall(tracker.Update, tracker)
end

-- After each redraw of Questie's: the frames are looked at again, and a look that changed since the lines were laid out (a row of the Fonts
-- page) has Questie lay them out again on the next frame.
local relayoutQueued = false
local function AfterUpdate()
	if ns.IsStopped(KEY) or not (Wanted() or Styled()) then
		return
	end
	Pass(false)
	if S.key ~= Look() and not relayoutQueued then
		relayoutQueued = true
		C_Timer.After(0, function()
			relayoutQueued = false
			pcall(Relayout)
		end)
	end
end

-- Questie's options also call UpdateFormatting alone, which sets the heading's font again (QuestieTracker.lua:980-1017;
-- QuestieOptionsTracker.lua:776).
local function AfterFormatting()
	local base = Named("Questie_BaseFrame")
	if base ~= nil and not ns.IsStopped(KEY) and (Wanted() or Styled()) then
		Run(Heading, base)
	end
end

-- Followed whatever the row says, while the module runs: Questie hands the function in QuestieTracker.Update to its heading's click when it
-- makes its tracker (QuestieTracker.lua:249; TrackerHeaderFrame.lua:171-173), so a hook put on later would miss the redraws of that click.
local function Follow()
	if S.followed then
		return
	end
	local tracker = Tracker()
	if tracker == nil or type(Read(tracker, "Update")) ~= "function" then
		return
	end
	S.followed = ns.FollowTable(tracker, "Update", AfterUpdate) == true
	if S.followed and type(Read(tracker, "UpdateFormatting")) == "function" then
		ns.FollowTable(tracker, "UpdateFormatting", AfterFormatting)
	end
end

-- The lines of /flatui status for a Questie whose tracker is not one this file knows.
local function Check()
	if not Wanted() then
		return
	end
	local tracker = Tracker()
	if tracker == nil or type(Read(tracker, "Update")) ~= "function" then
		ns.Note(KEY, UNKNOWN:format("no QuestieTracker.Update"))
	elseif Read(tracker, "started") == true and Named("Questie_BaseFrame") == nil then
		ns.Note(KEY, UNKNOWN:format("no Questie_BaseFrame"))
	end
	if S.noMode then
		ns.Note(KEY, NO_MODE)
	end
end

-- Hud.lua calls this at the end of RefreshTracker: a changed row, the page, the profile, or the part or the module stopping.
function ns.QuestieSkinRefresh()
	if not Loaded() then
		return
	end
	local wanted = Wanted()
	pcall(Follow)
	if wanted or Styled() then
		Pass(true)
	end
	pcall(Check)
	pcall(Relayout)
end

-- Questie loads after Flat UI; its tracker is made at login and drawn by QuestieTracker:Update, which is followed from then on.
ns.AddEvent(KEY, "ADDON_LOADED", ns.QuestieSkinRefresh, function(name)
	return not ns.IsSecret(name) and name == "Questie"
end)
ns.AddEvent(KEY, "PLAYER_ENTERING_WORLD", function()
	if Loaded() then
		pcall(Follow)
		if Wanted() then
			Queue()
		end
	end
end)
-- The game says a fight starts before it locks the interface, so the state is given.
local function Fight(fight)
	local base = Named("Questie_BaseFrame")
	if base ~= nil and (S.alpha ~= nil or (Wanted() and (Opt("trackerCombat") or 100) < 100)) then
		Run(Alpha, base, fight)
	end
end
ns.AddEvent(KEY, "PLAYER_REGEN_DISABLED", function()
	Fight(true)
end)
ns.AddEvent(KEY, "PLAYER_REGEN_ENABLED", function()
	Fight(false)
end)
