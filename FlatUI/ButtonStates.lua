local _, ns = ...

-- Button colours and cooldowns on the main and extra action bars: own colours for not enough power and cannot use, a tint on the icon when out of
-- range, and the cooldown sweep (on or off, its colour and opacity, an edge line in its own colour), its numbers (size, colour and tenths below a
-- number of seconds, each put back at once when set to the game's again) and a grey icon on cooldown. The restyled pet, stance and totem buttons
-- keep the game's colours and grey, but their cooldowns take the sweep, its colour and opacity and the numbers too (SweepLook); not the edge line,
-- which the game's CooldownFrame_Set turns off at each cooldown (Cooldown.lua:2-9). Nothing here hooks a
-- button method. The game's own handlers run first (ActionButton.lua:415-428 for ACTION_USABLE_CHANGED, UpdateUsable at 721-735); this file
-- only marks buttons and paints them one frame later. The two hooks are on global functions, ActionButton_UpdateRangeIndicator (1289-1307)
-- and ActionButton_ApplyCooldown (897-913), and their bodies only record. Every answer is used only when it is plain; a withheld answer leaves
-- the game's colour and gives one line in /flatui status. A row at its default makes no call. This file is not a module.
-- Flat UI's own buttons and the pet, stance and totem buttons are looked at only on a pass that follows a change of a row, their build, a change of
-- the buttons or a new world (lookDirty): their cooldown frames keep the sweep, the edge and the numbers between passes, and OwnPaint.lua paints Flat
-- UI's buttons itself per slot as their usability, range and cooldowns change, so a power tick costs nothing on them.
-- Flash when ready (off by default) is for Flat UI's own buttons: when a cooldown longer than the global cooldown ends on one that shows (ns.OnOwnReady,
-- OwnPaint.lua), a flash in Flash colour (white by default) goes over its icon, from clear to 60% and back in 0.35 s. Each button has one frame of this
-- file's own for it, a child of the button's bar over the icon, made out of combat once the buttons are built and the row is on; in a fight only its
-- animation plays, and a change of Flash colour colours the frames made. Shortest cooldown that flashes (actionbars.readyMinimum, 0 s by default)
-- lets a cooldown shorter than it end without a flash: OwnPaint.lua measures each cooldown from its start on its own clock (a plain number). One
-- already running when a button first holds it (after a stance, form, Stealth or page change, a drag or a reload) takes the start seen for its spell
-- on another slot, or else its spell's base cooldown, so short ones end quietly in every stance; only an item's of unknown length still flashes.
-- Sound when ready (actionbars.readySound, None by default) plays as such a flash plays, through ns.PlayKit, so at most once a second; the sweep
-- sample plays it once each time test mode is turned on, and the page plays a sound as it is picked.
-- The sweep sample (ns.ButtonStatesSample, out of combat): one Cooldown frame of this file's own (CooldownFrameTemplate) over a Flat UI button, a
-- child of its bar one level above it, runs a 4 s sweep in the looks of the rows above (sweep, Sweep colour and opacity, Edge line, the numbers
-- as the game's Show numbers on cooldowns says) and ends with the button's Flash when ready while that row is on. Test mode plays it every 5 s on
-- the fourth shown button of the main bar (ActionBars.lua); with test mode off, a change of one of those rows with the options window open plays it
-- once on the first, and a change while it still runs gives it the new look without starting it again, so a dragged slider plays it once.
-- Moving off on the bar of test mode holds it at 2 s of its 4 (ns.ButtonStatesSampleHold, Cooldown:Pause), with its edge and numbers, until Moving
-- on resumes it and its end moves on by the time held.

local KEY = "actionbars"
local BARS = {
	{ "ActionButton", 12, "main" },
	{ "MultiBarBottomLeftButton", 12, "extra" },
	{ "MultiBarBottomRightButton", 12, "extra" },
	{ "MultiBarLeftButton", 12, "extra" },
	{ "MultiBarRightButton", 12, "extra" },
	{ "MultiBar5Button", 12, "extra" },
	{ "MultiBar6Button", 12, "extra" },
	{ "MultiBar7Button", 12, "extra" },
}
local FONTS = { small = "NumberFontNormalSmall", normal = "NumberFontNormal", large = "NumberFontNormalLarge", huge = "NumberFontNormalHuge" }
local EVENTS = { "ACTION_USABLE_CHANGED", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "SPELL_UPDATE_USABLE", "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_ENTERING_WORLD" }
-- The colours the game gives an icon (ActionButton.lua:728-733), and the opacity of the swipe: the button template's black at 0.64
-- (ActionButtonTemplate.xml:116-118), which the game also puts back when a cast animation ends (ActionButton.lua:1843-1844 with
-- Camelot/ActionButtonOverrides.lua:1-3).
local GAME = { usable = { 1, 1, 1 }, mana = { 0.5, 0.5, 1 }, unusable = { 0.4, 0.4, 0.4 }, swipe = 0.64 }
local LINES = {
	usable = "Own usability colours: the game withholds whether an action can be used, so those buttons keep the game's colours.",
	range = "Tint icon when out of range: the game withholds the range, so those icons keep their colour.",
	grey = "Grey out icon on cooldown: the game hides cooldowns in fights, so icons stay coloured there.",
	font = "Cooldown number size: As the game has it applies after /reload.",
	look = "Cooldown number colour and Tenths below: the game refused the change.",
	sweep = "Cooldown sweep: the game refused the change.",
	swipe = "Own sweep opacity: the game refused the change.",
	size = "Cooldown number size: the game refused the change.",
	edge = "Edge line: the game refused the change.",
}
-- The groups of the restyled buttons the game keeps whose cooldowns take the sweep and number rows (ActionBars.lua).
local SIDE = { pet = true, stance = true, totem = true }

-- name[button]: "main" or "extra", for the buttons this file may paint. The list is made again when the bars change.
local eligible
-- out[button]: true out of range, false in range, from a plain answer of the game's range call.
local out = setmetatable({}, { __mode = "k" })
-- cdInfo[cooldown]: the cooldown info the game last gave that cooldown.
local cdInfo = setmetatable({}, { __mode = "k" })
-- What this file changed, so that a row put back to its default puts the button back.
local painted = setmetatable({}, { __mode = "k" })
local tinted = setmetatable({}, { __mode = "k" })
local greyed = setmetatable({}, { __mode = "k" })
local swipeOff = setmetatable({}, { __mode = "k" })
local swipeSet = setmetatable({}, { __mode = "k" })
-- edgeSet[cooldown]: the Edge colour last written while Edge line is on.
local edgeSet = setmetatable({}, { __mode = "k" })
-- numbers[cooldown]: the look this file gave the countdown of a cooldown, { font = the game's font { file, size, flags } read before the first size
-- change (false when it could not be read), sized = true while a size is set, colour = the colour set, tenths = the tenths set }.
local numbers = setmetatable({}, { __mode = "k" })
local WHITE = "ffffffff"
local dirty = setmetatable({}, { __mode = "k" })
local all, queued, hooked, touched = false, false, false, false
-- True until the next pass of every button has given Flat UI's buttons and the pet, stance and totem buttons their looks.
local lookDirty = true
-- refused.sweep, refused.swipe, refused.size: a call the game refused; the row stops making it.
local refused = {}
local watcher
-- The flash of Flash when ready: by button, { frame, group, texture } once made, or false when it could not be made. RISE and FALL are its two
-- halves in seconds, PEAK its opacity at the top.
local readyFlash = setmetatable({}, { __mode = "k" })
local READY = { PEAK = 0.6, RISE = 0.1, FALL = 0.25, pending = false }
-- The sweep sample: its Cooldown frame once made, the button it lies over, when it and its flash are over (ends), busy while this file sets or clears
-- it (its OnCooldownDone then does not count) and TIME, the sample cooldown in seconds. LOOKS: the rows a change of which plays it.
local SAMPLE = { frame = nil, button = nil, ends = nil, busy = false, TIME = 4 }
-- The places of the Sound when ready choices in ns.SOUNDS (IconRow.lua), as Party cooldowns has them; TEST: the sound test mode plays once.
READY.SOUNDS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
READY.TEST = "actionbars.ready"
local LOOKS = { sweep = true, sweepOwn = true, sweepColour = true, sweepAlpha = true, sweepEdge = true, sweepEdgeColour = true, cdFont = true,
	cdColour = true, cdTenths = true, readyFlash = true, readyColour = true }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

local function Say(which)
	ns.Note(KEY, LINES[which])
end

-- True while the button is drawn: a button the layout hid (fewer icons on its bar in Edit Mode) keeps its place, and its effects are not shown.
local function Visible(button)
	local ok, shown = pcall(button.IsVisible, button)
	return ok and not ns.IsSecret(shown) and shown == true
end

-- The group ActionBars.lua gives a restyled button ("pet", "stance", "totem" and the rest), or nil.
local function Group(button)
	if type(ns.ActionButtonGroup) ~= "function" then
		return nil
	end
	local ok, group = pcall(ns.ActionButtonGroup, button)
	return ok and group or nil
end

-- One of Flat UI's own buttons (OwnBars.lua) is painted through the icon painter of OwnPaint.lua, which gets the state of the slot, and the hooks on
-- the game's range and cooldown functions are not made for it.
local function IsOwn(button)
	return type(ns.ButtonIsOwn) == "function" and ns.ButtonIsOwn(button) == true
end

local function Eligible()
	if eligible == nil then
		eligible = setmetatable({}, { __mode = "k" })
		local byName = setmetatable({}, { __mode = "k" })
		for _, entry in ipairs(BARS) do
			for index = 1, entry[2] do
				local button = _G[entry[1] .. index]
				if button ~= nil and not ns.IsSecret(button) then
					byName[button] = entry[3]
				end
			end
		end
		local list = type(ns.ActionButtons) == "function" and ns.ActionButtons() or {}
		for _, button in ipairs(list) do
			local group = byName[button]
			if type(ns.ActionButtonGroup) == "function" then
				local ok, answer = pcall(ns.ActionButtonGroup, button)
				if ok and (answer == "main" or answer == "extra") then
					group = answer
				elseif ok and answer ~= nil then
					group = nil
				end
			end
			if group ~= nil then
				eligible[button] = group
			end
		end
	end
	return eligible
end

local function Wanted()
	return ns.Enabled(KEY)
end

-- The colour for a button: out of range wins over usability. Nil leaves the game's colour.
local function IconColour(button)
	local own, tint = Opt("usableOwn") == true, Opt("rangeTint") == true
	if not (own or tint or painted[button]) then
		return nil
	end
	if tint and out[button] == true then
		tinted[button] = true
		return ns.Colour(KEY .. ".rangeColour")
	end
	local action = button.action
	local usable, noMana
	local known = false
	if Plain(action, "number") and C_ActionBar and C_ActionBar.IsUsableAction then
		local ok, a, b = pcall(C_ActionBar.IsUsableAction, action)
		if ok and Plain(a, "boolean") and (b == nil or Plain(b, "boolean")) then
			usable, noMana, known = a, b, true
		end
	end
	if not known then
		if own then
			Say("usable")
		end
		if tinted[button] then
			tinted[button] = nil
			return GAME.usable[1], GAME.usable[2], GAME.usable[3]
		end
		return nil
	end
	tinted[button] = nil
	if usable then
		return GAME.usable[1], GAME.usable[2], GAME.usable[3]
	elseif noMana == true then
		if own then
			return ns.Colour(KEY .. ".manaColour")
		end
		return GAME.mana[1], GAME.mana[2], GAME.mana[3]
	end
	if own then
		return ns.Colour(KEY .. ".unusableColour")
	end
	return GAME.unusable[1], GAME.unusable[2], GAME.unusable[3]
end

local function PaintIcon(button)
	local icon = button.icon
	if icon == nil or ns.IsSecret(icon) then
		return
	end
	local r, g, b = IconColour(button)
	if r == nil then
		return
	end
	pcall(icon.SetVertexColor, icon, r, g, b)
	painted[button] = Opt("usableOwn") == true or Opt("rangeTint") == true or nil
end

local function Grey(button, cooldown)
	local icon = button.icon
	if icon == nil or ns.IsSecret(icon) then
		return
	end
	if Opt("cdGrey") ~= true then
		if greyed[button] then
			greyed[button] = nil
			pcall(icon.SetDesaturated, icon, false)
		end
		return
	end
	local info = cdInfo[cooldown]
	local plainInfo = type(info) == "table" and not ns.IsSecret(info)
	local active, gcd
	if plainInfo then
		active, gcd = info.isActive, info.isOnGCD
	end
	if not plainInfo or not Plain(active, "boolean") or not (gcd == nil or Plain(gcd, "boolean")) then
		if greyed[button] then
			greyed[button] = nil
			pcall(icon.SetDesaturated, icon, false)
		end
		if info ~= nil then
			Say("grey")
		end
		return
	end
	local want = active and not gcd
	if want or greyed[button] then
		pcall(icon.SetDesaturated, icon, want)
	end
	greyed[button] = want or nil
	if want then
		touched = true
	end
end

-- Tenths below, a whole number of seconds from 0 (never).
local function Tenths()
	local tenths = Opt("cdTenths")
	return Plain(tenths, "number") and tenths > 0 and tenths or 0
end

-- True when a cooldown row is off its default or this file changed a cooldown before, so the game's cooldown call is worth a pass.
local function CooldownWork()
	return touched or Opt("sweep") ~= true or Opt("sweepOwn") == true or Opt("sweepEdge") == true or FONTS[Opt("cdFont")] ~= nil
		or Opt("cdGrey") == true or Opt("cdColour") ~= WHITE or Tenths() ~= 0
end

-- The countdown's font string of a cooldown (Cooldown:GetCountdownFontString, FrameAPICooldownDocumentation.lua:78-89), or nil.
local function Countdown(cooldown)
	if type(cooldown.GetCountdownFontString) ~= "function" then
		return nil
	end
	local ok, fs = pcall(cooldown.GetCountdownFontString, cooldown)
	if ok and Plain(fs, "table") then
		return fs
	end
	return nil
end

-- The game's font of the countdown, read before the first size change (SimpleFont GetFont), as Cooldowns.lua reads it for the cooldown icons.
local function GameFont(cooldown)
	local fs = Countdown(cooldown)
	if fs == nil then
		return false
	end
	local ok, file, size, flags = pcall(fs.GetFont, fs)
	if ok and Plain(file, "string") and Plain(size, "number") and (flags == nil or Plain(flags, "string")) then
		return { file, size, flags or "" }
	end
	return false
end

-- Cooldown number size, colour and Tenths below on the countdown of a button's cooldown. The size is set at each pass, as before; As the game has it
-- puts back the font read before the first change, at once. The colour is written when it changes and again after each font change (a font object
-- brings its own colour), the tenths when they change (SetCountdownMillisecondsThreshold, FrameAPICooldownDocumentation.lua:379-386); at the
-- defaults (white, 0) nothing is written on a countdown this file never changed, as Cooldowns.lua does for the cooldown icons (Looks.Numbers).
local function Numbers(cooldown)
	local record = numbers[cooldown]
	local size, fresh = FONTS[Opt("cdFont")], false
	if size ~= nil and not refused.size then
		if record == nil then
			record = {}
			numbers[cooldown] = record
		end
		if record.font == nil then
			record.font = GameFont(cooldown)
		end
		if pcall(cooldown.SetCountdownFont, cooldown, size) then
			touched, fresh, record.sized = true, true, true
		else
			refused.size = true
			Say("size")
		end
	elseif record ~= nil and record.sized then
		record.sized = nil
		local saved, fs = record.font, Countdown(cooldown)
		record.font = nil
		if saved and fs and pcall(fs.SetFont, fs, saved[1], saved[2], saved[3]) then
			fresh = true
		else
			Say("font")
		end
	end
	if refused.look then
		return
	end
	local colour, tenths = Opt("cdColour"), Tenths()
	colour = Plain(colour, "string") and colour or WHITE
	local had = record ~= nil and record.colour or nil
	if (colour ~= WHITE or had ~= nil) and (had ~= colour or fresh) then
		local fs = Countdown(cooldown)
		local r, g, b = ns.Colour(KEY .. ".cdColour")
		if fs and pcall(fs.SetTextColor, fs, r, g, b, 1) then
			if record == nil then
				record = {}
				numbers[cooldown] = record
			end
			record.colour, touched = colour ~= WHITE and colour or nil, true
		else
			refused.look = true
			Say("look")
		end
	end
	local before = record ~= nil and record.tenths or nil
	if not refused.look and (tenths ~= 0 or before ~= nil) and before ~= tenths then
		if type(cooldown.SetCountdownMillisecondsThreshold) == "function" and pcall(cooldown.SetCountdownMillisecondsThreshold, cooldown, tenths) then
			if record == nil then
				record = {}
				numbers[cooldown] = record
			end
			record.tenths, touched = tenths ~= 0 and tenths or nil, true
		else
			refused.look = true
			Say("look")
		end
	end
end

-- The look of a cooldown, for every restyled button: the sweep on or off and, with Own sweep opacity, its Sweep colour at Sweep opacity, then the
-- numbers. back is the opacity the game's swipe goes back to, or false for the game's own SetSwipeColor(0, 0, 0) of the pet and stance buttons
-- (PetActionBar.lua:208, StanceBar.lua:115).
local function SweepLook(cooldown, back)
	if not refused.sweep then
		local off = Opt("sweep") ~= true
		if off or swipeOff[cooldown] then
			if pcall(cooldown.SetDrawSwipe, cooldown, not off) then
				swipeOff[cooldown] = off or nil
				touched = touched or off
			else
				refused.sweep = true
				Say("sweep")
			end
		end
	end
	if not refused.swipe then
		local own = Opt("sweepOwn") == true
		if own or swipeSet[cooldown] then
			local ok
			if own then
				local r, g, b = ns.Colour(KEY .. ".sweepColour")
				ok = pcall(cooldown.SetSwipeColor, cooldown, r, g, b, Opt("sweepAlpha") / 100)
			elseif back then
				ok = pcall(cooldown.SetSwipeColor, cooldown, 0, 0, 0, back)
			else
				ok = pcall(cooldown.SetSwipeColor, cooldown, 0, 0, 0)
			end
			if ok then
				swipeSet[cooldown] = own or nil
				touched = touched or own
			else
				refused.swipe = true
				Say("swipe")
			end
		end
	end
	Numbers(cooldown)
end

-- Edge line: the bright line along the edge of the sweep in Edge colour (Cooldown:SetDrawEdge and SetEdgeColor, FrameAPICooldownDocumentation.lua),
-- each written when it changes; off again, the template's drawEdge false comes back (ActionButtonTemplate.xml:111).
local function Edge(cooldown)
	if refused.edge then
		return
	end
	local on = Opt("sweepEdge") == true
	if not on then
		if edgeSet[cooldown] then
			edgeSet[cooldown] = nil
			pcall(cooldown.SetDrawEdge, cooldown, false)
		end
		return
	end
	local colour = Opt("sweepEdgeColour")
	if edgeSet[cooldown] == colour then
		return
	end
	local r, g, b = ns.Colour(KEY .. ".sweepEdgeColour")
	if pcall(cooldown.SetDrawEdge, cooldown, true) and (type(cooldown.SetEdgeColor) ~= "function" or pcall(cooldown.SetEdgeColor, cooldown, r, g, b, 1)) then
		edgeSet[cooldown], touched = colour, true
	else
		refused.edge = true
		Say("edge")
	end
end

local function Sweep(button)
	local cooldown = button.cooldown
	if cooldown == nil or ns.IsSecret(cooldown) then
		return
	end
	if button.actionButtonCastType ~= nil then
		Grey(button, cooldown)
		return
	end
	SweepLook(cooldown, GAME.swipe)
	Edge(cooldown)
	-- The grey of an own button is given by the icon painter, from the state the cooldown has.
	if not IsOwn(button) then
		Grey(button, cooldown)
	end
end

-- A restyled pet, stance or totem button: the look of its cooldown, without colours or grey. A totem button is an action button of the game's, whose
-- cast animation puts its swipe back to black at 0.64 (ActionButton.lua:1840-1845), so it is left alone while one plays and goes back as for the
-- main bars.
local function SideLook(button)
	local cooldown = button.cooldown
	if cooldown == nil or ns.IsSecret(cooldown) or button.actionButtonCastType ~= nil then
		return
	end
	local group = Group(button)
	SweepLook(cooldown, group == "totem" and GAME.swipe or false)
end

-- The icon painter: the colour of the icon of one of Flat UI's buttons, or nil for the game's own (OwnPaint.lua gives white, blue or grey by usability).
-- The grey of a cooldown is set on the icon here; the answers are the state's, which is plain or nil.
local function IconPainter(button, shown)
	if type(shown) ~= "table" then
		return nil
	end
	local wanted = Wanted() and Eligible()[button] ~= nil
	local icon = button.icon
	if icon ~= nil and not ns.IsSecret(icon) then
		local want = wanted and Opt("cdGrey") == true and shown.cdActive == true and shown.cdOnGCD ~= true
		if want or greyed[button] then
			pcall(icon.SetDesaturated, icon, want)
			greyed[button] = want or nil
		end
	end
	if not wanted then
		return nil
	end
	local own, tint = Opt("usableOwn") == true, Opt("rangeTint") == true
	if tint and shown.checksRange == true then
		if shown.inRange == false then
			return ns.Colour(KEY .. ".rangeColour")
		elseif shown.inRange == nil then
			Say("range")
		end
	end
	if own and shown.has == true then
		if shown.usable == false then
			if shown.noMana == true then
				return ns.Colour(KEY .. ".manaColour")
			end
			return ns.Colour(KEY .. ".unusableColour")
		elseif shown.usable == nil then
			Say("usable")
		end
	end
	return nil
end

local painterOn = false

local function Attach()
	if not painterOn and type(ns.OwnPainter) == "function" then
		painterOn = pcall(ns.OwnPainter, "icon", IconPainter)
	end
end

local function Pass()
	queued = false
	Attach()
	if not Wanted() then
		all, dirty = false, setmetatable({}, { __mode = "k" })
		return
	end
	local list = Eligible()
	local todo = dirty
	local everything = all
	local looks = everything and lookDirty
	all, dirty = false, setmetatable({}, { __mode = "k" })
	local ownSeen = false
	for button in pairs(list) do
		if everything or todo[button] then
			if not IsOwn(button) then
				PaintIcon(button)
				Sweep(button)
			elseif looks then
				-- Flat UI's buttons only after a change (lookDirty): a pass of a power tick or a slot event leaves them to OwnPaint.lua.
				ownSeen = true
				Sweep(button)
			end
		end
	end
	-- The pet, stance and totem buttons: all of them after a change, else a totem button whose cooldown the game just set.
	if looks then
		for _, button in ipairs(type(ns.ActionButtons) == "function" and ns.ActionButtons() or {}) do
			if list[button] == nil and SIDE[Group(button)] then
				SideLook(button)
			end
		end
	else
		for button in pairs(todo) do
			if list[button] == nil and SIDE[Group(button)] then
				SideLook(button)
			end
		end
	end
	if looks then
		lookDirty = false
	end
	-- Flat UI's buttons are painted again, so the icon painter reads the rows as they are.
	if ownSeen and type(ns.OwnRepaint) == "function" then
		pcall(ns.OwnRepaint)
	end
end

local function Ask(button)
	if button == nil then
		all = true
	else
		dirty[button] = true
	end
	if queued then
		return
	end
	queued = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			local ok, err = pcall(Pass)
			if not ok then
				queued = false
				geterrorhandler()(err)
			end
		end)
	else
		Pass()
	end
end

local function Hook()
	if hooked then
		return
	end
	-- Nothing is hooked or registered in the game's action button code while Restyle action bars is off and Flat UI leaves the game's bars alone.
	if ns.HandsOff() and not ns.Enabled("actionbars") then
		return
	end
	-- Only Flat UI's own buttons are styled: the game's range and cooldown functions have nothing to say about them.
	if type(ns.OwnLookOnly) == "function" and ns.OwnLookOnly() then
		return
	end
	local range = ns.FollowGlobal("ActionButton_UpdateRangeIndicator", function(button, checksRange, inRange)
		if not ns.Enabled(KEY) or button == nil or ns.IsSecret(button) or Eligible()[button] == nil then
			return
		end
		if Plain(checksRange, "boolean") and (inRange == nil or Plain(inRange, "boolean")) then
			out[button] = checksRange and not inRange or false
			if Opt("rangeTint") == true or painted[button] then
				Ask(button)
			end
		else
			out[button] = nil
			if Opt("rangeTint") == true then
				Say("range")
			end
		end
	end)
	local cooldown = ns.FollowGlobal("ActionButton_ApplyCooldown", function(normalCooldown, info)
		if not ns.Enabled(KEY) or normalCooldown == nil or ns.IsSecret(normalCooldown) then
			return
		end
		local ok, button = pcall(normalCooldown.GetParent, normalCooldown)
		if not ok or button == nil or ns.IsSecret(button) then
			return
		end
		if Eligible()[button] == nil then
			-- A restyled totem button is an action button of the game's: its cooldown takes the look again after the game set it.
			if SIDE[Group(button)] and CooldownWork() then
				Ask(button)
			end
			return
		end
		cdInfo[normalCooldown] = info
		if CooldownWork() or Opt("usableOwn") == true or Opt("rangeTint") == true or painted[button] then
			Ask(button)
		end
	end)
	hooked = range == true or cooldown == true
end

-- One flash frame: a child of the button's bar, over its icon and above its cooldown, clear until its animation plays. Out of combat only.
local function MakeReady(button)
	local icon = button.icon
	if icon == nil or ns.IsSecret(icon) then
		return false
	end
	local ok, parent = pcall(button.GetParent, button)
	if not ok or not Plain(parent, "table") then
		parent = UIParent
	end
	local frame = CreateFrame("Frame", nil, parent)
	ns.Own[frame] = true
	frame:SetAllPoints(icon)
	local okLevel, level = pcall(button.GetFrameLevel, button)
	if okLevel and Plain(level, "number") then
		frame:SetFrameLevel(level + 2)
	end
	frame:SetAlpha(0)
	local texture = frame:CreateTexture(nil, "OVERLAY")
	texture:SetAllPoints(frame)
	local r, g, b = ns.Colour(KEY .. ".readyColour")
	texture:SetColorTexture(r, g, b, 1)
	local group = frame:CreateAnimationGroup()
	local rise = group:CreateAnimation("Alpha")
	rise:SetFromAlpha(0)
	rise:SetToAlpha(READY.PEAK)
	rise:SetDuration(READY.RISE)
	rise:SetOrder(1)
	local fall = group:CreateAnimation("Alpha")
	fall:SetFromAlpha(READY.PEAK)
	fall:SetToAlpha(0)
	fall:SetDuration(READY.FALL)
	fall:SetOrder(2)
	return { frame = frame, group = group, texture = texture }
end

-- Flash colour on the flash frames made: a colour of Flat UI's own textures, allowed in a fight.
local function ReadyColour()
	local r, g, b = ns.Colour(KEY .. ".readyColour")
	for _, made in pairs(readyFlash) do
		if made and made.texture then
			pcall(made.texture.SetColorTexture, made.texture, r, g, b, 1)
		end
	end
end

-- The flash frames of Flat UI's buttons that have none yet, made once the fight is over; nothing while the row is off.
local function PrepareReady()
	if READY.pending or Opt("readyFlash") ~= true or type(ns.OwnOn) ~= "function" or not ns.OwnOn() then
		return
	end
	READY.pending = true
	ns.OutOfCombat(function()
		READY.pending = false
		for _, button in ipairs(type(ns.OwnButtons) == "function" and ns.OwnButtons() or {}) do
			if readyFlash[button] == nil then
				local ok, made = pcall(MakeReady, button)
				readyFlash[button] = ok and made or false
			end
		end
	end)
end

-- Sound when ready, through ns.PlayKit, so at most once a second however many buttons flash at once; nothing at None.
local function ReadySound()
	local sounds = ns.SOUNDS
	local sound = type(sounds) == "table" and sounds[READY.SOUNDS[Opt("readySound")] or 0] or nil
	if type(sound) == "table" and type(ns.PlayKit) == "function" then
		ns.PlayKit(sound[1], KEY)
	end
end

-- A cooldown longer than the global one ended on one of Flat UI's buttons: its flash plays, from the start, with Sound when ready. A button the
-- layout hid has no flash, nor a cooldown shorter than Shortest cooldown that flashes; seconds, the length OwnPaint.lua measured, is nil when it
-- does not know it.
local function OnReady(button, seconds)
	if Opt("readyFlash") ~= true or not Wanted() or Eligible()[button] == nil or not Visible(button) then
		return
	end
	local least = Opt("readyMinimum")
	if Plain(least, "number") and least > 0 and ns.Finite(seconds) and seconds < least then
		return
	end
	ReadySound()
	local made = readyFlash[button]
	if made == nil then
		PrepareReady()
	elseif made then
		made.group:Stop()
		made.group:Play()
	end
end

-- The game's Show numbers on cooldowns as a plain answer: true to hide the numbers, nil when it cannot be read.
local function NumbersOff()
	local read = C_CVar and C_CVar.GetCVarBool or GetCVarBool
	if type(read) ~= "function" then
		return nil
	end
	local ok, on = pcall(read, "countdownForCooldowns")
	if not ok or ns.IsSecret(on) then
		return nil
	end
	return on ~= true
end

-- The looks of the rows on the sample's cooldown; what it changes does not count as a change of a button's (touched).
local function SampleLook(frame)
	local was = touched
	SweepLook(frame, GAME.swipe)
	Edge(frame)
	touched = was
	local hide = NumbersOff()
	if hide ~= nil then
		pcall(frame.SetHideCountdownNumbers, frame, hide)
	end
end

-- The sample's sweep ended: the button's Flash when ready plays while the row is on, its frame made first when it has none. Sound when ready plays
-- with it only in test mode, once each time test mode is turned on (TM.Sound), not on each loop of 5 s.
local function SampleDone()
	if SAMPLE.busy then
		return
	end
	local button = SAMPLE.button
	if not button or Opt("readyFlash") ~= true or not Wanted() or not Visible(button) then
		return
	end
	local mode = ns.TestMode
	if mode and mode.IsOn() and type(mode.Sound) == "function" and mode.Sound(READY.TEST) then
		ReadySound()
	end
	local made = readyFlash[button]
	if made == nil and not InCombatLockdown() then
		local ok, built = pcall(MakeReady, button)
		made = ok and built or false
		readyFlash[button] = made
	end
	if made then
		made.group:Stop()
		made.group:Play()
	end
end

-- The sample's frame over the button: a child of the button's bar, one level above the button, on the button's own cooldown frame.
local function SampleStart(frame, button)
	local okParent, parent = pcall(button.GetParent, button)
	frame:SetParent(okParent and Plain(parent, "table") and parent or UIParent)
	frame:ClearAllPoints()
	local under = button.cooldown
	if not Plain(under, "table") then
		under = button.icon
	end
	frame:SetAllPoints(Plain(under, "table") and under or button)
	local okLevel, level = pcall(button.GetFrameLevel, button)
	if okLevel and Plain(level, "number") then
		frame:SetFrameLevel(level + 1)
	end
	SAMPLE.button = button
	SampleLook(frame)
	frame:SetCooldown(GetTime(), SAMPLE.TIME)
	frame:Show()
end

-- The sweep sample on a Flat UI button, out of combat. Without force, a sample that still runs on that button takes the looks of now and goes on.
function ns.ButtonStatesSample(button, force)
	if InCombatLockdown() or not Wanted() or not Plain(button, "table") then
		return
	end
	local frame = SAMPLE.frame
	if frame and not force and SAMPLE.button == button and (SAMPLE.heldAt or (SAMPLE.ends and GetTime() < SAMPLE.ends)) then
		SampleLook(frame)
		return
	end
	if not frame then
		frame = CreateFrame("Cooldown", nil, UIParent, "CooldownFrameTemplate")
		ns.Own[frame] = true
		pcall(frame.SetDrawBling, frame, false)
		pcall(frame.SetDrawEdge, frame, false)
		frame:SetScript("OnCooldownDone", function()
			local ok, err = pcall(SampleDone)
			if not ok then
				geterrorhandler()(err)
			end
		end)
		SAMPLE.frame = frame
	end
	SAMPLE.busy = true
	local ok, err = pcall(SampleStart, frame, button)
	SAMPLE.busy = false
	if not ok then
		error(err, 0)
	end
	if SAMPLE.heldAt then
		ns.ButtonStatesSampleHold(true)
	end
	SAMPLE.ends = GetTime() + SAMPLE.TIME + READY.RISE + READY.FALL
end

-- Moving on the bar of test mode (ActionBars.lua): held true holds the sweep still at half its time, its edge and numbers with it (Cooldown:Pause),
-- and a sample started meanwhile the same way; false carries on from there (Resume), its end moved on by the time it was held.
function ns.ButtonStatesSampleHold(held)
	local frame, now = SAMPLE.frame, GetTime()
	if not held then
		local since = SAMPLE.heldAt
		SAMPLE.heldAt = nil
		if since and frame then
			if SAMPLE.ends then
				SAMPLE.ends = SAMPLE.ends + (now - since)
			end
			pcall(frame.Resume, frame)
		end
		return
	end
	SAMPLE.heldAt = now
	if not (frame and SAMPLE.button) then
		return
	end
	SAMPLE.busy = true
	local ok = pcall(frame.SetCooldown, frame, now - SAMPLE.TIME / 2, SAMPLE.TIME)
	if ok then
		frame:Show()
		pcall(frame.Pause, frame)
		SAMPLE.ends = now + SAMPLE.TIME / 2 + READY.RISE + READY.FALL
	end
	SAMPLE.busy = false
end

-- Test mode ends or pauses: the sample goes.
function ns.ButtonStatesSampleOff()
	local frame = SAMPLE.frame
	if frame then
		SAMPLE.busy = true
		pcall(frame.Clear, frame)
		frame:Hide()
		SAMPLE.busy = false
	end
	SAMPLE.button, SAMPLE.ends, SAMPLE.heldAt = nil, nil, nil
end

-- A look row changed with the options window open, out of combat and out of test mode (which plays the sample itself): the sample plays once on the
-- first shown button of Flat UI's main bar, or the one that runs takes the new look.
local function Preview(path)
	local row = type(path) == "string" and path:match("^" .. KEY .. "%.(.+)$")
	local mode = ns.TestMode
	if not (row and LOOKS[row]) or InCombatLockdown() or (mode and mode.IsOn()) or type(ns.PanelShown) ~= "function" or not ns.PanelShown()
		or type(ns.ButtonSamples) ~= "function" then
		return
	end
	local first = ns.ButtonSamples()[1]
	if first then
		ns.ButtonStatesSample(first)
	end
end

-- The Config rows of the page Colours and cooldowns call this.
function ns.ButtonStatesChanged(path)
	if refused.look and (path == KEY .. ".cdColour" or path == KEY .. ".cdTenths") then
		refused.look = nil
	end
	if refused.sweep and path == KEY .. ".sweep" then
		refused.sweep = nil
	end
	if refused.edge and (path == KEY .. ".sweepEdge" or path == KEY .. ".sweepEdgeColour") then
		refused.edge = nil
	end
	if path == KEY .. ".readyColour" then
		ReadyColour()
	end
	eligible, lookDirty = nil, true
	Hook()
	Ask(nil)
	PrepareReady()
	Preview(path)
end

if type(ns.OnOwnReady) == "function" then
	ns.OnOwnReady(OnReady)
end
if type(ns.OnOwnBuilt) == "function" then
	ns.OnOwnBuilt(PrepareReady)
	-- Flat UI's buttons are built: they take the looks on the next pass.
	ns.OnOwnBuilt(function()
		lookDirty = true
		Ask(nil)
	end)
end

if CreateFrame then
	watcher = CreateFrame("Frame")
	ns.Own[watcher] = true
	watcher:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_ENTERING_WORLD" or event == "ACTIONBAR_PAGE_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" then
			eligible = nil
		end
		if event == "PLAYER_ENTERING_WORLD" then
			lookDirty = true
			Hook()
		end
		Ask(nil)
	end)
	for _, event in ipairs(EVENTS) do
		pcall(watcher.RegisterEvent, watcher, event)
	end
end

-- The buttons hold something else: Flat UI's buttons made after login, or the game's styled after them, are looked at again.
if type(ns.OnButtonsChanged) == "function" then
	ns.OnButtonsChanged(function()
		lookDirty = true
		if type(ns.OwnOn) == "function" and ns.OwnOn() then
			eligible = nil
			Hook()
			Ask(nil)
		elseif type(ns.OwnWanted) ~= "function" or not ns.OwnWanted() then
			eligible = nil
			Hook()
		end
	end)
end
