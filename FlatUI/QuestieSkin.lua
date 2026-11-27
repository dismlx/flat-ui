local _, ns = ...

local KEY, PART, LABEL = "hud", "questie tracker", "Minimap and HUD"
local LINES, BUTTONS = "linePool", "Questie_ItemButton"
local MOST_LINES, MOST_BUTTONS = 500, 100
local PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }
local ICONS = { "GetNormalTexture", "GetPushedTexture" }
local BAND_X, BAND_TOP, BAND_BOTTOM, HEADING_IN = 3, 2, 2, 2
local UNKNOWN = LABEL .. ": Questie's tracker is not one Flat UI knows (%s), so it keeps Questie's look."
local REFUSED = LABEL .. ": the game refused a font on Questie's tracker, which keeps Questie's font there."
local NO_MODE = LABEL .. ": the lines of Questie's tracker have no SetMode here, so their fonts change after Questie lays them out."

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

local function PlaceHeading(anchor, header)
	anchor:SetPoint("TOPLEFT", header, "TOPLEFT", HEADING_IN, BAND_TOP)
	anchor:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", HEADING_IN, BAND_BOTTOM)
	anchor:SetWidth(1)
end

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
			S.noMode = true
		end
	end
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

function ns.QuestieFades(frame)
	return S.sent ~= nil and frame ~= nil and frame == rawget(_G, "Questie_BaseFrame")
end

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

local function AfterFormatting()
	local base = Named("Questie_BaseFrame")
	if base ~= nil and not ns.IsStopped(KEY) and (Wanted() or Styled()) then
		Run(Heading, base)
	end
end

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
