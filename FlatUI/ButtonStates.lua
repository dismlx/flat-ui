local _, ns = ...

-- Button colours and cooldowns on the main and extra action bars: own colours for not enough power and cannot use, a tint on the icon when out of
-- range, and the cooldown sweep, its numbers and a grey icon on cooldown. Pet and stance buttons keep the game's colours. Nothing here hooks a
-- button method. The game's own handlers run first (ActionButton.lua:415-428 for ACTION_USABLE_CHANGED, UpdateUsable at 721-735); this file
-- only marks buttons and paints them one frame later. The two hooks are on global functions, ActionButton_UpdateRangeIndicator (1289-1307)
-- and ActionButton_ApplyCooldown (897-913), and their bodies only record. Every answer is used only when it is plain; a withheld answer leaves
-- the game's colour and gives one line in /flatui status. A row at its default makes no call. This file is not a module.

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
-- The colours the game gives an icon (ActionButton.lua:728-733) and a swipe it has finished a cast animation on (ActionButton.lua:1843).
local GAME = { usable = { 1, 1, 1 }, mana = { 0.5, 0.5, 1 }, unusable = { 0.4, 0.4, 0.4 } }
local LINES = {
	usable = "Own usability colours: the game withholds whether an action can be used, so those buttons keep the game's colours.",
	range = "Tint icon when out of range: the game withholds the range, so those icons keep their colour.",
	grey = "Grey out icon on cooldown: the game hides cooldowns in fights, so icons stay coloured there.",
	font = "Cooldown number size: As the game has it applies after /reload.",
	sweep = "Cooldown sweep: the game refused the change.",
	swipe = "Own sweep opacity: the game refused the change.",
	size = "Cooldown number size: the game refused the change.",
}

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
local dirty = setmetatable({}, { __mode = "k" })
local all, queued, hooked, fontSet, touched = false, false, false, false, false
-- refused.sweep, refused.swipe, refused.size: a call the game refused; the row stops making it.
local refused = {}
local watcher

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

local function Say(which)
	ns.Note(KEY, LINES[which])
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

-- True when a cooldown row is off its default or this file changed a cooldown before, so the game's cooldown call is worth a pass.
local function CooldownWork()
	return touched or Opt("sweep") ~= true or Opt("sweepOwn") == true or FONTS[Opt("cdFont")] ~= nil or Opt("cdGrey") == true
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
			local alpha = own and Opt("sweepAlpha") / 100 or 1
			if pcall(cooldown.SetSwipeColor, cooldown, 0, 0, 0, alpha) then
				swipeSet[cooldown] = own or nil
				touched = touched or own
			else
				refused.swipe = true
				Say("swipe")
			end
		end
	end
	local size = FONTS[Opt("cdFont")]
	if size ~= nil and not refused.size then
		if pcall(cooldown.SetCountdownFont, cooldown, size) then
			fontSet = true
			touched = true
		else
			refused.size = true
			Say("size")
		end
	end
	-- The grey of an own button is given by the icon painter, from the state the cooldown has.
	if not IsOwn(button) then
		Grey(button, cooldown)
	end
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
	all, dirty = false, setmetatable({}, { __mode = "k" })
	local ownSeen = false
	for button in pairs(list) do
		if everything or todo[button] then
			if IsOwn(button) then
				ownSeen = true
			else
				PaintIcon(button)
			end
			Sweep(button)
		end
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
		if not ok or button == nil or ns.IsSecret(button) or Eligible()[button] == nil then
			return
		end
		cdInfo[normalCooldown] = info
		if CooldownWork() or Opt("usableOwn") == true or Opt("rangeTint") == true or painted[button] then
			Ask(button)
		end
	end)
	hooked = range == true or cooldown == true
end

-- The Config rows of the page Colours and cooldowns call this.
function ns.ButtonStatesChanged(path)
	if fontSet and path == KEY .. ".cdFont" and Opt("cdFont") == "game" then
		fontSet = false
		Say("font")
	end
	if refused.sweep and path == KEY .. ".sweep" then
		refused.sweep = nil
	end
	eligible = nil
	Hook()
	Ask(nil)
end

if CreateFrame then
	watcher = CreateFrame("Frame")
	ns.Own[watcher] = true
	watcher:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_ENTERING_WORLD" or event == "ACTIONBAR_PAGE_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" then
			eligible = nil
		end
		if event == "PLAYER_ENTERING_WORLD" then
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
