local _, ns = ...

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
local SIDE = { pet = true, stance = true, totem = true }

local eligible
local out = setmetatable({}, { __mode = "k" })
local cdInfo = setmetatable({}, { __mode = "k" })
local painted = setmetatable({}, { __mode = "k" })
local tinted = setmetatable({}, { __mode = "k" })
local greyed = setmetatable({}, { __mode = "k" })
local swipeOff = setmetatable({}, { __mode = "k" })
local swipeSet = setmetatable({}, { __mode = "k" })
local edgeSet = setmetatable({}, { __mode = "k" })
local numbers = setmetatable({}, { __mode = "k" })
local WHITE = "ffffffff"
local dirty = setmetatable({}, { __mode = "k" })
local all, queued, hooked, touched = false, false, false, false
local lookDirty = true
local refused = {}
local watcher
local readyFlash = setmetatable({}, { __mode = "k" })
local READY = { PEAK = 0.6, RISE = 0.1, FALL = 0.25, pending = false }
local SAMPLE = { frame = nil, button = nil, ends = nil, busy = false, running = false, grey = nil, TIME = 4 }
local TINT = { button = nil, path = nil, ends = 0, TIME = 2 }
local TINTS = { usableOwn = "manaColour", manaColour = "manaColour", unusableColour = "unusableColour", rangeTint = "rangeColour",
	rangeColour = "rangeColour" }
READY.SOUNDS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
READY.TEST = "actionbars.ready"
local LOOKS = { sweep = true, sweepOwn = true, sweepColour = true, sweepAlpha = true, sweepEdge = true, sweepEdgeColour = true, cdFont = true,
	cdColour = true, cdTenths = true, readyFlash = true, readyColour = true, cdGrey = true }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

local function Say(which)
	ns.Note(KEY, LINES[which])
end

local function Visible(button)
	local ok, shown = pcall(button.IsVisible, button)
	return ok and not ns.IsSecret(shown) and shown == true
end

local function Group(button)
	if type(ns.ActionButtonGroup) ~= "function" then
		return nil
	end
	local ok, group = pcall(ns.ActionButtonGroup, button)
	return ok and group or nil
end

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

local function Tenths()
	local tenths = Opt("cdTenths")
	return Plain(tenths, "number") and tenths > 0 and tenths or 0
end

local function CooldownWork()
	return touched or Opt("sweep") ~= true or Opt("sweepOwn") == true or Opt("sweepEdge") == true or FONTS[Opt("cdFont")] ~= nil
		or Opt("cdGrey") == true or Opt("cdColour") ~= WHITE or Tenths() ~= 0
end

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
	if not IsOwn(button) then
		Grey(button, cooldown)
	end
end

local function SideLook(button)
	local cooldown = button.cooldown
	if cooldown == nil or ns.IsSecret(cooldown) or button.actionButtonCastType ~= nil then
		return
	end
	local group = Group(button)
	SweepLook(cooldown, group == "totem" and GAME.swipe or false)
end

local function IconPainter(button, shown)
	if type(shown) ~= "table" then
		return nil
	end
	local wanted = Wanted() and Eligible()[button] ~= nil
	local icon = button.icon
	if icon ~= nil and not ns.IsSecret(icon) then
		local want = wanted and Opt("cdGrey") == true and shown.cdActive == true and shown.cdOnGCD ~= true
		if SAMPLE.grey == button then
			greyed[button] = want or nil
		elseif want or greyed[button] then
			pcall(icon.SetDesaturated, icon, want)
			greyed[button] = want or nil
		end
	end
	if not wanted then
		return nil
	end
	if TINT.button == button and GetTime() < TINT.ends and Opt(TINT.path == "rangeColour" and "rangeTint" or "usableOwn") == true then
		return ns.Colour(KEY .. "." .. TINT.path)
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
				ownSeen = true
				Sweep(button)
			end
		end
	end
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
	if ns.HandsOff() and not ns.Enabled("actionbars") then
		return
	end
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

local function ReadyColour()
	local r, g, b = ns.Colour(KEY .. ".readyColour")
	for _, made in pairs(readyFlash) do
		if made and made.texture then
			pcall(made.texture.SetColorTexture, made.texture, r, g, b, 1)
		end
	end
end

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

local function ReadySound()
	local sounds = ns.SOUNDS
	local sound = type(sounds) == "table" and sounds[READY.SOUNDS[Opt("readySound")] or 0] or nil
	if type(sound) == "table" and type(ns.PlayKit) == "function" then
		ns.PlayKit(sound[1], KEY)
	end
end

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

local function SampleGrey(button)
	local want = button ~= nil and Opt("cdGrey") == true and Wanted()
	local was = SAMPLE.grey
	if was and (was ~= button or not want) then
		SAMPLE.grey = nil
		local icon = was.icon
		if Plain(icon, "table") then
			pcall(icon.SetDesaturated, icon, greyed[was] == true)
		end
	end
	local icon = want and button.icon
	if Plain(icon, "table") then
		pcall(icon.SetDesaturated, icon, true)
		SAMPLE.grey = button
	end
end

local function SampleDone()
	if SAMPLE.busy then
		return
	end
	SAMPLE.running = false
	SampleGrey(nil)
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
	SampleGrey(button)
	frame:SetCooldown(GetTime(), SAMPLE.TIME)
	frame:Show()
	SAMPLE.running = true
end

function ns.ButtonStatesSample(button, force)
	if InCombatLockdown() or not Wanted() or not Plain(button, "table") then
		return
	end
	local frame = SAMPLE.frame
	if frame and not force and SAMPLE.button == button and (SAMPLE.heldAt or (SAMPLE.ends and GetTime() < SAMPLE.ends)) then
		SampleLook(frame)
		if SAMPLE.running then
			SampleGrey(button)
		end
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

function ns.ButtonStatesSampleOff()
	local frame = SAMPLE.frame
	if frame then
		SAMPLE.busy = true
		pcall(frame.Clear, frame)
		frame:Hide()
		SAMPLE.busy = false
	end
	SAMPLE.running = false
	SampleGrey(nil)
	SAMPLE.button, SAMPLE.ends, SAMPLE.heldAt = nil, nil, nil
end

local function TintSample(button, path)
	local was = TINT.button
	TINT.button, TINT.path, TINT.ends = button, path, GetTime() + TINT.TIME
	if type(ns.OwnRepaint) ~= "function" then
		return
	end
	if was and was ~= button then
		ns.OwnRepaint(was)
	end
	ns.OwnRepaint(button)
	if C_Timer and C_Timer.After then
		C_Timer.After(TINT.TIME + 0.05, function()
			local lit = TINT.button
			if lit and GetTime() >= TINT.ends then
				TINT.button = nil
				ns.OwnRepaint(lit)
			end
		end)
	end
end

function TINT.Check()
	local lit = TINT.button
	if lit == nil or Opt(TINT.path == "rangeColour" and "rangeTint" or "usableOwn") == true then
		return
	end
	TINT.button = nil
	if type(ns.OwnRepaint) == "function" then
		ns.OwnRepaint(lit)
	end
end

local function Preview(path)
	TINT.Check()
	local row = type(path) == "string" and path:match("^" .. KEY .. "%.(.+)$")
	local mode = ns.TestMode
	local tint = row and TINTS[row]
	if tint and Opt(tint == "rangeColour" and "rangeTint" or "usableOwn") ~= true then
		tint = nil
	end
	if not (row and (LOOKS[row] or tint)) or InCombatLockdown() or (mode and mode.IsOn()) or type(ns.PanelShown) ~= "function" or not ns.PanelShown()
		or type(ns.ButtonSamples) ~= "function" then
		return
	end
	local first = ns.ButtonSamples()[1]
	if first and tint then
		TintSample(first, tint)
	elseif first then
		ns.ButtonStatesSample(first)
	end
end

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

local NUMBERS = { pending = nil }
function ns.ButtonNumbersGet()
	local hide = NumbersOff()
	if hide == nil then
		return nil
	end
	if NUMBERS.pending ~= nil then
		return NUMBERS.pending
	end
	return not hide
end

local function WriteNumbers(on)
	local write = C_CVar and C_CVar.SetCVar or SetCVar
	if type(write) ~= "function" then
		return
	end
	pcall(write, "countdownForCooldowns", on and "1" or "0")
	Preview(KEY .. ".cdFont")
end

function ns.ButtonNumbersSet(_, value)
	local on = value == true
	if InCombatLockdown() then
		local queued = NUMBERS.pending ~= nil
		NUMBERS.pending = on
		if not NUMBERS.told and type(ns.PanelShown) == "function" and ns.PanelShown() == true then
			NUMBERS.told = true
			print(on and "Flat UI: cooldown numbers show when the fight ends." or "Flat UI: cooldown numbers go when the fight ends.")
		end
		if not queued then
			ns.OutOfCombat(function()
				local wanted = NUMBERS.pending
				NUMBERS.pending = nil
				NUMBERS.told = nil
				if wanted ~= nil then
					WriteNumbers(wanted)
				end
			end)
		end
		return
	end
	NUMBERS.pending = nil
	WriteNumbers(on)
end

function ns.ButtonStatesTint(button, path)
	local row = type(path) == "string" and path:match("^" .. KEY .. "%.(.+)$")
	local tint = row and TINTS[row]
	if not tint then
		return false
	end
	TINT.Check()
	if Plain(button, "table") and not InCombatLockdown() and Opt(tint == "rangeColour" and "rangeTint" or "usableOwn") == true then
		TintSample(button, tint)
	end
	return true
end

function ns.ButtonStatesPreviewing()
	local mode = ns.TestMode
	if mode and mode.IsOn() then
		return false
	end
	local now = GetTime()
	return (SAMPLE.ends ~= nil and now < SAMPLE.ends) or (TINT.button ~= nil and now < TINT.ends)
end

if type(ns.OnOwnReady) == "function" then
	ns.OnOwnReady(OnReady)
end
if type(ns.OnOwnBuilt) == "function" then
	ns.OnOwnBuilt(PrepareReady)
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
