local _, ns = ...

-- Ping bar: a bar of Flat UI's own with one button for each ping of the game, drawn as the icons of Group tools are: square, with a thin border
-- on a dark background, the game's own ping icon inside. A module of its own, on by default, whose page is in the Group group. The bar shows in
-- a group, always, or never (then only its keys ping), as Show says, and /flatui move places it (FlatUIPingBar in Movers.lua: the top left
-- corner of the bar is the top left corner of the box). While test mode is on (TestMode.lua, out of combat only) Show reads as Always and the bar
-- shows also while pings are blocked for you, greyed, with the reason in each tooltip, and a cooldown swipe runs once as a sample. No frame or
-- setting of the game is changed.
--
-- How the game pings. The ping wheel is the game's own (Blizzard_PingUI, for the game type mainline, Blizzard_PingUI.toc:4, which this client's
-- camelot loads too: Blizzard_UnitFrame.toc:20 has to exclude camelot from a mainline line). Its key (TOGGLEPINGLISTENER, Blizzard_PingUI/Bindings.xml:3-5)
-- runs C_Ping.TogglePingListener, and the keys of the four wedges run C_Ping.SendMacroPing with a type (Bindings.xml:7-21,
-- Blizzard_PingUtil.lua:3-8). Both have restrictions (HasRestrictions: PingManagerDocumentation.lua:53-73), so an addon cannot call them; the
-- game's secure slash command /ping can (Blizzard_ChatFrameBase/Mainline/SlashCommandsOverrides.lua:35-75, SlashCommandUtil.
-- CheckAddSecureSlashCommand, loaded as the [Family] file of Blizzard_ChatFrameBase.toc:22). A button of Flat UI's own made from
-- SecureActionButtonTemplate, of the type macro, has the game run its macrotext in the game's secure code (Blizzard_FrameXML/SecureTemplates.lua:
-- 450-463), in a fight too; the secure templates have no ping type of their own. Each button's macrotext is one /ping line with the number of its
-- ping, which the game reads in every language (SlashCommandsOverrides.lua:41-54: 1 Attack, 2 Warning, 3 On My Way, 4 Assist, 5 Not a threat,
-- 6 Threat); the Ping button has none, so the game picks the kind for what it pings, as a tap of its ping key does (SendHitTestPing or
-- SendUnitPing with no type, Blizzard_PingManager.lua:248-262).
-- What a click pings: [@target,exists] pings your target (its GUID, Blizzard_PingManager.lua:220-223). With no target, With no target picks a
-- second clause: [@cursor] pings the ground under the cursor (a macro's "cursor" token, Blizzard_PingManager.lua:214-219), [@player] pings you,
-- and none leaves it, since a /ping with a condition that gives no unit does nothing (SlashCommandsOverrides.lua:63-68). That is also why the
-- line is not "[@target,exists] attack; attack": its second clause gives no unit while the line has a condition, so with no target it would
-- send nothing. A key pressed with the mouse over the world pings where it points; a click on the bar pings the ground behind it.
-- The buttons: SecureActionButtonTemplate, each named FlatUIPing and its kind (FlatUIPingPing, FlatUIPingAttack, FlatUIPingWarning,
-- FlatUIPingOnMyWay, FlatUIPingAssist, FlatUIPingNotThreat, FlatUIPingThreat) for its key binding in Bindings.xml (CLICK ...:LeftButton,
-- category Flat UI), named in the game's Key Bindings by BINDING_NAME_ globals here, as Mount key names its own. They hear the press and the
-- release of the left button: a mouse click acts on the release and a key as the game's ActionButtonUseKeyDown says (SecureTemplates.lua:
-- 792-826). They lie over icons of Flat UI's own, as Group tools' do, so an icon can be greyed or swiped in a fight while its secure button is not
-- touched. The bar shows Ping and each ping the game's wheel offers (C_Ping.GetDefaultPingOptions, in its orderIndex, as Blizzard_PingManager.lua:
-- 53-69 sorts them), else the four of the game's ping keys; every kind has its button and its key, shown on the bar or not. The secure buttons
-- make the bar protected, so the bar and its buttons are made, placed, sized, shown, hidden and given attributes only out of combat: a change in a
-- fight waits for its end (ns.OutOfCombat), and in a fight nothing on them changes. With the module off their type and macrotext are taken away,
-- so the keys do nothing; the bindings are the player's and stay.
-- The icons are the game's wheel icons, the atlas Ping_Wheel_Icon_ and the texture kit of the ping (Blizzard_PingManager.lua:59-63; the kits of
-- Blizzard_PingUI.lua:276-283), else its marker icon (Ping_Marker_Icon_, Blizzard_PingUI.lua:329), each only when the client has the atlas
-- (C_Texture.GetAtlasInfo), else a letter. The border of a button takes a colour near that of its icon (Borders in the ping's colour).
-- Blocked: the bar hides, out of combat, while the game's ping system is off (C_Ping.IsPingSystemEnabled, as Blizzard_CompactRaidFrameManager.lua:
-- 163 asks), while Enable Pings is off in the game's options (the variable enablePings, Blizzard_SettingsDefinitions_Frame/PingSystem.lua:15) or
-- while the group lets only some members ping and you are not one (C_PartyInfo.GetRestrictPings, PartyInfoDocumentation.lua:348-355; Lead,
-- Assist and TankHealer, the radios of Blizzard_CompactRaidFrameManager.lua:179-182). The leader counts for each, an assistant for Assist and
-- TankHealer, and a tank or healer by its assigned role (UnitGroupRolesAssigned) for TankHealer; an answer the game withholds blocks nothing,
-- and the game refuses a ping it does not allow with its own message. While a fight holds the bar shown, its buttons are greyed and each tooltip
-- says why. The cooldown swipe (Cooldown swipe) is a Cooldown frame of Flat UI's own on each icon, set from C_Ping.GetCooldownInfo, whose
-- times in milliseconds are on the clock of GetTime (Blizzard_PingUI.lua:135-141 compares them so): read a moment after a press of a button of
-- the bar (a PostClick of Flat UI's own, set out of combat, which runs after the game's secure code and changes no attribute) and when the mouse
-- comes over a button, as the game's listener reads it (Blizzard_PingUI.lua:134-147). The changes are heard on the module's events
-- (GROUP_ROSTER_UPDATE, PARTY_LEADER_CHANGED, PLAYER_ROLES_ASSIGNED, CVAR_UPDATE of enablePings, PLAYER_ENTERING_WORLD, UPDATE_BINDINGS for the
-- tooltip); no ticker and no OnUpdate. Pointing at a button writes its name, what a click pings, its key and the game's own key for that ping in
-- GameTooltip (SetOwner on the icon, SetText, AddLine, Show, and Hide when the mouse leaves), as Group tools does.

local KEY = "pingbar"
local MOVER = "FlatUIPingBar"
-- The box of the handle in Movers.lua: Ping and the four pings of the wheel at the default size and spacing in a row. With no spot saved its top is
-- this far below the top of the screen, under the row of Group tools (GroupTools.lua: 24 high at 100 down).
local BOX_W, BOX_H, BOX_Y = 132, 24, -130
local INSET = 2
local FONT = "GameFontHighlightSmall"
-- The text-dim of the windows (PanelLook.lua) for the lines of a tooltip, and the warm colour of the reason a button is greyed, as Group tools has.
local DIM = { 0.66, 0.68, 0.62 }
local WARN = { 0.9, 0.72, 0.36 }
local GREY_ALPHA = 0.4
local LIGHTER = 0.17
-- The cooldown is read this long after a press, once the game has sent the ping.
local AFTER_PRESS = 0.1
local SAMPLE = 3
-- The kinds, in the order the bar shows them while the game offers no order: id (the button's name after FlatUIPing), the name of the enum value
-- of Enum.PingSubjectType and its number where the client has no enum (PingConstantsDocumentation), the number /ping reads, the texture kit, the
-- global string of its name (SlashCommandsOverrides.lua:43-53) and its English name, the game's own binding, and the colour of its border.
local KINDS = {
	{ id = "Ping", kit = "NonThreat", name = "Ping", game = "TOGGLEPINGLISTENER", colour = { 1, 0.82, 0.2 } },
	{ id = "Attack", enum = "Attack", value = 0, word = "1", kit = "Attack", global = "PING_TYPE_ATTACK", name = "Attack", game = "PINGATTACK",
		colour = { 0.93, 0.27, 0.22 } },
	{ id = "Warning", enum = "Warning", value = 1, word = "2", kit = "Warning", global = "PING_TYPE_WARNING", name = "Warning", game = "PINGWARNING",
		colour = { 1, 0.6, 0.13 } },
	{ id = "OnMyWay", enum = "OnMyWay", value = 3, word = "3", kit = "OnMyWay", global = "PING_TYPE_ON_MY_WAY", name = "On My Way",
		game = "PINGONMYWAY", colour = { 0.32, 0.64, 1 } },
	{ id = "Assist", enum = "Assist", value = 2, word = "4", kit = "Assist", global = "PING_TYPE_ASSIST", name = "Assist", game = "PINGASSIST",
		colour = { 0.35, 0.85, 0.38 } },
	{ id = "NotThreat", enum = "AlertNotThreat", value = 5, word = "5", kit = "NonThreat", global = "PING_TYPE_NOT_THREAT", name = "Not a threat",
		colour = { 1, 0.82, 0.2 } },
	{ id = "Threat", enum = "AlertThreat", value = 4, word = "6", kit = "Threat", global = "PING_TYPE_THREAT", name = "Threat",
		colour = { 0.93, 0.33, 0.2 } },
}
-- The four pings of the game's own keys, shown while the game offers no list.
local KEYS_ONLY = { Attack = 1, Warning = 2, OnMyWay = 3, Assist = 4 }
-- What With no target adds after [@target,exists].
local NO_TARGET = { cursor = "[@cursor]", player = "[@player]", none = "" }
local NO_CLIENT = "This client has no ping system."
local SYSTEM_OFF = "The game's ping system is off here."
local OPTION_OFF = "Pings are off in the game's options: Enable Pings, under Ping System."
local ONLY_LEAD = "Your group lets only its leader ping."
local ONLY_ASSIST = "Your group lets only its leader and assistants ping."
local ONLY_ROLES = "Your group lets only tanks and healers ping."
local LINE_WAITING = "Ping bar: the buttons change when the fight ends."
local LINE_BROKEN = "Ping bar: the game made no secure button, so the bar and its keys do nothing until /reload."
local LINE_HIDDEN = "Ping bar: hidden. %s"
local LINE_NEVER = "Ping bar: Show is Never, so only its keys ping."

local IsSecret = ns.IsSecret
-- panel: the frame of the bar. buttons: one entry for each of KINDS, { kind, frame (the icon), art, letter, outline, sweep, cover (the secure
-- button), hover, macro }. order: the places in KINDS of the kinds the bar shows. placed, laid: the spot and the layout the bar was put at.
-- queued: a change waits for the end of a fight. broken: the game made no secure button. why: the reason pings are blocked, as last painted.
-- armed: the buttons have their type and macrotext. sample: a sample swipe waits for the bar to be made.
local P = { buttons = {}, queued = false, broken = false, armed = false }
ns.PingBar = P

for _, kind in ipairs(KINDS) do
	_G["BINDING_NAME_CLICK FlatUIPing" .. kind.id .. ":LeftButton"] = "Ping: " .. kind.name
end

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Number(key, default)
	local value = Opt(key)
	return ns.Finite(value) and value or default
end

-- The first answer of a call of the client, or nil when the call is missing, raises or the answer is withheld.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

-- True or false from a call of the client, or nil when the call is missing, raises or withholds the answer.
local function Truth(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if not ok or IsSecret(value) then
		return nil
	end
	return value ~= nil and value ~= false
end

-- In a fight, or the game will not say: the secure buttons are left alone then.
local function Fighting()
	local ok, fighting = pcall(InCombatLockdown)
	return ok and (IsSecret(fighting) or fighting == true)
end

local function Api(name)
	local api = _G[name]
	if type(api) == "table" and not IsSecret(api) then
		return api
	end
	return nil
end

-- The value of an enum of the client, else the number given.
local function EnumValue(group, name, fallback)
	local enums = Api("Enum")
	local values = enums and enums[group]
	local value = type(values) == "table" and values[name] or nil
	if ns.Finite(value) then
		return value
	end
	return fallback
end

-- The name of a kind in the client's language, else its English name.
local function Name(kind)
	local text = kind.global and _G[kind.global] or nil
	if type(text) == "string" and not IsSecret(text) and text ~= "" then
		return text
	end
	return kind.name
end

-- Blocked ------------------------------------------------------------------------------------------------------------------------------------

-- Whether the group lets the player ping, nil when it does or the game will not say, else the reason.
function P.Restricted()
	local party = Api("C_PartyInfo")
	if not party or Truth(IsInGroup) ~= true then
		return nil
	end
	local restrict = Ask(party.GetRestrictPings)
	if not ns.Finite(restrict) or restrict == EnumValue("RestrictPingsTo", "None", 0) then
		return nil
	end
	local leader = Truth(UnitIsGroupLeader, "player")
	if leader ~= false then
		return nil
	end
	local assistant = Truth(UnitIsGroupAssistant, "player")
	if assistant ~= true and Truth(IsInRaid) == true and Truth(IsEveryoneAssistant) == true then
		assistant = true
	end
	if restrict == EnumValue("RestrictPingsTo", "Lead", 1) then
		return ONLY_LEAD
	elseif restrict == EnumValue("RestrictPingsTo", "Assist", 2) then
		return assistant == false and ONLY_ASSIST or nil
	elseif restrict == EnumValue("RestrictPingsTo", "TankHealer", 3) then
		if assistant ~= false then
			return nil
		end
		local role = Ask(UnitGroupRolesAssigned, "player")
		if type(role) ~= "string" or role == "TANK" or role == "HEALER" then
			return nil
		end
		return ONLY_ROLES
	end
	return nil
end

-- Why the player cannot ping now, or nil.
function P.Blocked()
	local ping = Api("C_Ping")
	if not ping or type(ping.IsPingSystemEnabled) ~= "function" then
		return NO_CLIENT
	end
	if Truth(ping.IsPingSystemEnabled) == false then
		return SYSTEM_OFF
	end
	local cvars = Api("C_CVar")
	if cvars and Ask(cvars.GetCVar, "enablePings") == "0" then
		return OPTION_OFF
	end
	return P.Restricted()
end

-- Which pings show -----------------------------------------------------------------------------------------------------------------------------

-- The place in KINDS of the kind of a type of the game.
local function KindOf(value)
	for index, kind in ipairs(KINDS) do
		if kind.enum and EnumValue("PingSubjectType", kind.enum, kind.value) == value then
			return index
		end
	end
	return nil
end

-- The places in KINDS of the kinds the bar shows: Ping, then each ping the game's wheel offers in its order, else the four of the game's keys.
function P.Order()
	if P.order then
		return P.order
	end
	local ping, offered = Api("C_Ping"), {}
	local list = ping and Ask(ping.GetDefaultPingOptions) or nil
	if type(list) == "table" then
		for _, info in ipairs(list) do
			if type(info) == "table" and not IsSecret(info.type) then
				local index = KindOf(info.type)
				if index then
					offered[#offered + 1] = { index = index, order = ns.Finite(info.orderIndex) and info.orderIndex or #offered }
				end
			end
		end
	end
	table.sort(offered, function(a, b)
		return a.order < b.order
	end)
	local order, seen = { 1 }, { [1] = true }
	for _, entry in ipairs(offered) do
		if not seen[entry.index] then
			seen[entry.index] = true
			order[#order + 1] = entry.index
		end
	end
	if #order == 1 then
		for index, kind in ipairs(KINDS) do
			if KEYS_ONLY[kind.id] then
				order[#order + 1] = index
			end
		end
	end
	P.order = order
	return order
end

-- Whether Show lets the bar show now. Test mode reads Show as Always and shows a blocked bar, greyed.
function P.Allowed()
	local mode = ns.TestMode
	if mode ~= nil and mode.IsOn() == true then
		return true
	end
	local show = Opt("show")
	if show == "never" or P.Blocked() then
		return false
	end
	return show == "always" or Truth(IsInGroup) == true
end

-- The places in KINDS of the buttons that show now: none while the module is off, Show does not allow the bar or the game made no secure button.
function P.Wanted()
	if not ns.Enabled(KEY) or P.broken or not P.Allowed() then
		return {}
	end
	return P.Order()
end

-- The buttons --------------------------------------------------------------------------------------------------------------------------------

-- The /ping line of a kind, as With no target says.
function P.Macro(kind)
	local units = "[@target,exists]" .. (NO_TARGET[Opt("noTarget")] or NO_TARGET.cursor)
	if kind.word then
		return ("/ping %s %s"):format(units, kind.word)
	end
	return "/ping " .. units
end

-- The atlas of a kit's icon that the client has, or nil.
local function Atlas(kit)
	local textures = Api("C_Texture")
	if not textures or type(textures.GetAtlasInfo) ~= "function" then
		return nil
	end
	for _, form in ipairs({ "Ping_Wheel_Icon_%s", "Ping_Marker_Icon_%s" }) do
		local name = form:format(kit)
		local info = Ask(textures.GetAtlasInfo, name)
		if type(info) == "table" then
			return name
		end
	end
	return nil
end

-- The icon of a button: a frame of the addon's own with the border and dark background of Group tools' icons, the game's ping icon inside (else
-- the first letter of its name in its colour) and a swipe for the cooldown.
function P.Icon(panel, kind)
	local frame = Own(CreateFrame("Frame", nil, panel))
	frame:SetSize(BOX_H, BOX_H)
	local entry = { kind = kind, frame = frame, hover = false }
	entry.outline = ns.Outline(frame, frame)
	local atlas = Atlas(kind.kit)
	if atlas then
		local art = Own(frame:CreateTexture(nil, "ARTWORK", nil, 0))
		art:SetPoint("TOPLEFT", frame, "TOPLEFT", INSET, -INSET)
		art:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -INSET, INSET)
		art:SetAtlas(atlas, false)
		entry.art = art
	else
		local letter = ns.OwnText(frame, "OVERLAY", FONT)
		if letter then
			letter:SetPoint("CENTER", frame, "CENTER", 0, 0)
			letter:SetText(kind.name:sub(1, 1))
			letter:SetTextColor(kind.colour[1], kind.colour[2], kind.colour[3], 1)
			entry.letter = letter
		end
	end
	local made, sweep = pcall(CreateFrame, "Cooldown", nil, frame, "CooldownFrameTemplate")
	if made and type(sweep) == "table" then
		Own(sweep)
		pcall(function()
			sweep:SetAllPoints(frame)
			sweep:SetDrawEdge(false)
			sweep:SetDrawBling(false)
			sweep:SetSwipeColor(0, 0, 0, 0.7)
			sweep:SetHideCountdownNumbers(true)
		end)
		entry.sweep = sweep
	end
	frame:SetScript("OnHide", function()
		ns.Try(KEY, P.Leave, entry)
	end)
	return entry
end

-- The secure button over an icon, named for its key binding, a child of the bar with no picture of its own, above the icon. Its attributes are
-- given by P.Arm. Nil when the game made none.
function P.Cover(panel, entry)
	local made, cover = pcall(CreateFrame, "Button", "FlatUIPing" .. entry.kind.id, panel, "SecureActionButtonTemplate")
	if not made or type(cover) ~= "table" then
		return nil
	end
	Own(cover)
	local done = pcall(function()
		cover:SetFrameLevel(entry.frame:GetFrameLevel() + 3)
		cover:SetSize(BOX_H, BOX_H)
		cover:EnableMouse(true)
		-- The press and the release: a mouse click acts on the release, a key as the game's ActionButtonUseKeyDown says.
		cover:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
		cover:SetScript("OnEnter", function()
			ns.Try(KEY, P.Enter, entry)
		end)
		cover:SetScript("OnLeave", function()
			ns.Try(KEY, P.Leave, entry)
		end)
		-- After the game's secure code ran the press: the cooldown it may have started is read a moment later.
		cover:SetScript("PostClick", function()
			ns.Try(KEY, P.Pressed)
		end)
	end)
	if not done then
		pcall(cover.Hide, cover)
		return nil
	end
	return cover
end

-- The bar and its buttons, made the first time the module is on, out of combat. False when the game made no secure button.
function P.Build()
	if P.panel then
		return true
	elseif P.broken then
		return false
	end
	local panel = Own(CreateFrame("Frame", nil, UIParent))
	panel:SetFrameStrata("LOW")
	panel:SetSize(BOX_W, BOX_H)
	panel:Hide()
	local buttons = {}
	for index, kind in ipairs(KINDS) do
		local entry = P.Icon(panel, kind)
		entry.cover = P.Cover(panel, entry)
		if not entry.cover then
			P.broken = true
			pcall(panel.Hide, panel)
			return false
		end
		buttons[index] = entry
	end
	P.buttons, P.panel = buttons, panel
	return true
end

-- Gives every button its type and macrotext while the module is on, or takes them away, so its key does nothing. Only out of combat, and only
-- what changed.
function P.Arm(on)
	for _, entry in ipairs(P.buttons) do
		local macro = on and P.Macro(entry.kind) or nil
		if entry.macro ~= macro then
			local cover = entry.cover
			if pcall(function()
				cover:SetAttribute("type", macro and "macro" or nil)
				cover:SetAttribute("macrotext", macro)
			end) then
				entry.macro = macro
			end
		end
	end
	P.armed = on
end

-- Laying out ----------------------------------------------------------------------------------------------------------------------------------

-- Puts the buttons of the list in a row or a column, each secure button on the very spot of its icon, hides the others and sizes the bar to
-- them. A layout already in place is left as it is.
function P.Layout(list)
	local size, spacing, layout = Number("size", BOX_H), Number("spacing", 3), Opt("layout")
	local key = ("%s|%s|%s|%s"):format(table.concat(list, ","), size, spacing, tostring(layout))
	if P.laid == key then
		return
	end
	local shown, x, y, width, height = {}, 0, 0, 0, 0
	for place, index in ipairs(list) do
		local entry = P.buttons[index]
		shown[entry] = true
		if place > 1 then
			if layout == "column" then
				y = y + size + spacing
			else
				x = x + size + spacing
			end
		end
		for _, frame in ipairs({ entry.frame, entry.cover }) do
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", P.panel, "TOPLEFT", x, -y)
			frame:SetSize(size, size)
			frame:Show()
		end
		width, height = math.max(width, x + size), math.max(height, y + size)
	end
	for _, entry in ipairs(P.buttons) do
		if not shown[entry] then
			entry.frame:Hide()
			entry.cover:Hide()
		end
	end
	P.panel:SetSize(math.max(1, width), math.max(1, height))
	P.laid = key
end

-- Puts the bar at the spot of its handle: its top left corner at the top left corner of the box.
function P.Place()
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(MOVER, "TOPLEFT")
	end
	local key = x and ("%.2f:%.2f"):format(x, y) or "start"
	if P.placed == key then
		return
	end
	P.placed = key
	local panel = P.panel
	panel:ClearAllPoints()
	if x then
		panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
	else
		panel:SetPoint("TOPLEFT", UIParent, "TOP", -BOX_W / 2, BOX_Y)
	end
end

-- Makes the buttons, gives them their pings, and lays out, places and shows the bar, or hides it. Only out of combat (P.Apply).
function P.Lay()
	local on = ns.Enabled(KEY)
	if not on then
		if P.panel then
			P.panel:Hide()
			P.Arm(false)
		end
		return
	end
	if not P.Build() then
		return
	end
	P.Arm(true)
	local wanted = P.Wanted()
	if #wanted == 0 then
		P.panel:Hide()
		return
	end
	P.Layout(wanted)
	P.Place()
	P.panel:Show()
	local mode = ns.TestMode
	if P.sample and mode ~= nil and mode.IsOn() == true then
		P.Sample()
	end
end

-- A change in a fight waits for its end, once however many come. A module that stopped in the fight only hides the bar.
function P.Queue()
	if P.queued then
		return
	end
	P.queued = true
	ns.OutOfCombat(function()
		if Fighting() then
			return
		end
		P.queued = false
		if ns.IsStopped(KEY) then
			if P.panel then
				pcall(P.panel.Hide, P.panel)
			end
		else
			ns.Try(KEY, P.Apply)
		end
	end)
end

-- What the rows, the group, the game's options and the spot ask for: the bar is laid out out of combat, else when the fight ends, and the
-- greying follows at once.
function P.Apply()
	if Fighting() then
		P.Queue()
	else
		P.Lay()
	end
	P.Paint()
end

-- Drawing ------------------------------------------------------------------------------------------------------------------------------------

-- The background of an icon: the Background colour of the Flat UI page, a little lighter under the mouse while pings can be sent.
function P.Shade(entry)
	if entry.hover and not P.why then
		local r, g, b = ns.Colour("general.backdrop")
		ns.SetOutlineFill(entry.outline, math.min(1, r + LIGHTER), math.min(1, g + LIGHTER), math.min(1, b + LIGHTER), 1)
	else
		ns.SetOutlineFill(entry.outline, nil, nil, nil, nil)
	end
end

-- Greys the buttons while pings are blocked, gives each border its ping's colour or the general one, and writes again the tooltip of the one
-- under the mouse. Only the icons change, which are no secure frames, so this runs in a fight too. A hidden bar is left as it is.
function P.Paint()
	if not P.panel then
		return
	end
	local asked, shown = pcall(P.panel.IsShown, P.panel)
	if asked and not IsSecret(shown) and shown == false then
		return
	end
	P.why = P.Blocked()
	local usable, tinted = P.why == nil, Opt("colours") ~= false
	for _, entry in ipairs(P.buttons) do
		if entry.art then
			entry.art:SetDesaturated(not usable)
			entry.art:SetAlpha(usable and 1 or GREY_ALPHA)
		end
		if entry.letter then
			entry.letter:SetAlpha(usable and 1 or GREY_ALPHA)
		end
		local colour = tinted and entry.kind.colour or nil
		if colour then
			ns.SetOutlineColour(entry.outline, colour[1], colour[2], colour[3])
		else
			ns.SetOutlineColour(entry.outline, nil, nil, nil)
		end
		P.Shade(entry)
		if entry.hover and P.Owned(entry) then
			P.Tip(entry)
		end
	end
end

-- The cooldown -------------------------------------------------------------------------------------------------------------------------------

-- The ping cooldown as the game gives it, start and length in seconds on the clock of GetTime, or nil when there is none now.
function P.Cooldown()
	local ping = Api("C_Ping")
	local info = ping and Ask(ping.GetCooldownInfo) or nil
	if type(info) ~= "table" then
		return nil
	end
	local start, finish, now = info.startTimeMs, info.endTimeMs, Ask(GetTime)
	if IsSecret(start) or IsSecret(finish) or not (ns.Finite(start) and ns.Finite(finish) and ns.Finite(now)) then
		return nil
	end
	if finish <= now * 1000 or finish <= start then
		return nil
	end
	return start / 1000, (finish - start) / 1000
end

-- Puts a swipe on every icon of the bar, or clears them.
function P.Swipe(start, length)
	for _, entry in ipairs(P.buttons) do
		local sweep = entry.sweep
		if sweep then
			if start then
				pcall(sweep.SetCooldown, sweep, start, length)
			else
				pcall(sweep.Clear, sweep)
			end
		end
	end
end

-- Reads the cooldown and swipes the icons with it, while Cooldown swipe is on.
function P.ReadCooldown()
	if not P.panel or Opt("cooldown") == false then
		return
	end
	local start, length = P.Cooldown()
	if start then
		P.Swipe(start, length)
	end
end

-- A press of a button of the bar, by the mouse or its key.
function P.Pressed()
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, AFTER_PRESS, function()
		ns.Try(KEY, P.ReadCooldown)
	end) then
		return
	end
	P.ReadCooldown()
end

-- Test mode: one sample swipe, as soon as the bar is made.
function P.Sample()
	if not P.panel then
		P.sample = true
		return
	end
	P.sample = nil
	local now = Ask(GetTime)
	if Opt("cooldown") ~= false and ns.Finite(now) then
		P.Swipe(now, SAMPLE)
	end
end

-- Tooltips -----------------------------------------------------------------------------------------------------------------------------------

local function Tooltip()
	local tip = _G.GameTooltip
	if tip == nil or ns.Forbidden(tip) then
		return nil
	end
	return tip
end

function P.Owned(entry)
	local tip = Tooltip()
	if not tip then
		return false
	end
	local ok, owned = pcall(tip.IsOwned, tip, entry.frame)
	return ok and not IsSecret(owned) and owned == true
end

-- The text of the first key bound to a binding, or nil.
local function KeyText(binding)
	local key = Ask(GetBindingKey, binding)
	if type(key) ~= "string" or key == "" then
		return nil
	end
	local text = Ask(GetBindingText, key)
	return type(text) == "string" and text ~= "" and text or key
end

-- The lines of a button's tooltip: what a click pings, its key and the game's own key for that ping.
function P.Lines(entry)
	local kind, lines = entry.kind, {}
	if kind.word then
		lines[#lines + 1] = ("Pings your target with %s for your group."):format(Name(kind))
	else
		lines[#lines + 1] = "Pings your target for your group; the game picks the kind of ping for it."
	end
	local mode = Opt("noTarget")
	if mode == "player" then
		lines[#lines + 1] = "With no target, it pings you."
	elseif mode == "none" then
		lines[#lines + 1] = "With no target, it does nothing."
	else
		lines[#lines + 1] = "With no target, it pings the ground under the cursor."
	end
	local key = KeyText("CLICK FlatUIPing" .. kind.id .. ":LeftButton")
	if key then
		lines[#lines + 1] = ("Key: %s"):format(key)
	else
		lines[#lines + 1] = ("No key: bind Ping: %s under Flat UI in the game's Key Bindings."):format(kind.name)
	end
	local game = kind.game and KeyText(kind.game) or nil
	if game then
		lines[#lines + 1] = ("The game's own key for it: %s"):format(game)
	end
	return Name(kind), lines
end

-- Where a tooltip opens: above the bar in the lower half of the screen, below it in the upper half.
function P.Anchor()
	local ok, _, y = pcall(P.panel.GetCenter, P.panel)
	local okHeight, height = pcall(UIParent.GetHeight, UIParent)
	if ok and okHeight and ns.Finite(y) and ns.Finite(height) and y < height / 2 then
		return "ANCHOR_TOP"
	end
	return "ANCHOR_BOTTOM"
end

function P.Tip(entry)
	local tip = Tooltip()
	if not tip then
		return
	end
	local title, lines = P.Lines(entry)
	local colour = entry.kind.colour
	pcall(function()
		tip:SetOwner(entry.frame, P.Anchor())
		tip:SetText(title, colour[1], colour[2], colour[3])
		for _, line in ipairs(lines) do
			tip:AddLine(line, DIM[1], DIM[2], DIM[3], true)
		end
		if P.why then
			tip:AddLine(P.why, WARN[1], WARN[2], WARN[3], true)
		end
		tip:Show()
	end)
end

function P.Enter(entry)
	entry.hover = true
	P.why = P.Blocked()
	P.Shade(entry)
	P.Tip(entry)
	P.ReadCooldown()
end

function P.Leave(entry)
	if not entry.hover then
		return
	end
	entry.hover = false
	P.Shade(entry)
	if P.Owned(entry) then
		pcall(_G.GameTooltip.Hide, _G.GameTooltip)
	end
end

-- The tooltip under the mouse, written again after a key changed.
function P.Retip()
	for _, entry in ipairs(P.buttons) do
		if entry.hover and P.Owned(entry) then
			P.Tip(entry)
		end
	end
end

-- The module ---------------------------------------------------------------------------------------------------------------------------------

function P.Refresh()
	P.placed, P.laid = nil, nil
	if not ns.Enabled(KEY) and P.panel then
		P.Swipe(nil)
	end
	P.Apply()
end

-- The end of a fight: a change that still waits is applied, should the game have said it was in a fight when ns.OutOfCombat ran it.
function P.AfterFight()
	if P.queued and not Fighting() then
		P.queued = false
		P.Apply()
	else
		P.Paint()
	end
end

function P.Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	if P.broken then
		lines[#lines + 1] = LINE_BROKEN
	end
	local why = P.Blocked()
	if why then
		lines[#lines + 1] = LINE_HIDDEN:format(why)
	elseif Opt("show") == "never" then
		lines[#lines + 1] = LINE_NEVER
	end
	if P.queued then
		lines[#lines + 1] = LINE_WAITING
	end
	return lines
end

-- The movers -----------------------------------------------------------------------------------------------------------------------------------

-- True while the bar has a handle in the movers: while the module is on, shown or not.
function ns.PingBarShown()
	return ns.Enabled(KEY)
end

-- The movers set or put back the spot: the bar moves there out of combat.
function ns.PingBarMoved()
	P.placed = nil
	if P.panel and ns.Enabled(KEY) then
		ns.Try(KEY, P.Apply)
	end
end

ns.Register(KEY, {
	label = "Ping bar",
	counted = false,
	Start = P.Refresh,
	Refresh = P.Refresh,
	Resized = P.Refresh,
	Status = P.Status,
	-- The group, its leader, the roles, Enable Pings or a loading screen: the bar shows or hides and the greying follows. A key changed only
	-- writes the tooltip again.
	events = {
		GROUP_ROSTER_UPDATE = P.Apply,
		PARTY_LEADER_CHANGED = P.Apply,
		PLAYER_ROLES_ASSIGNED = P.Apply,
		PLAYER_ENTERING_WORLD = P.Apply,
		CVAR_UPDATE = P.Apply,
		UPDATE_BINDINGS = P.Retip,
		PLAYER_REGEN_ENABLED = P.AfterFight,
	},
	filters = {
		CVAR_UPDATE = function(name)
			return not IsSecret(name) and type(name) == "string" and name:lower() == "enablepings"
		end,
	},
})

-- Test mode: On, Off and a pause refresh the page, which shows the bar or puts it back to its own Show rule (P.Allowed), out of combat or once the
-- fight ends (P.Apply), and On runs a sample swipe.
if ns.TestMode then
	ns.TestMode.Register("pingbar", { module = KEY, label = "Ping bar", refresh = true, Start = P.Sample })
end
