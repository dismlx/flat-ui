local _, ns = ...

-- Ping bar: a bar of Flat UI's own with one button for each ping of the game, drawn as the icons of Group tools are: square, with a thin border
-- on a dark background, the game's own ping icon inside. A module of its own, on by default, whose page is in the Group group. The bar shows in
-- a group, always, or never (then only its keys ping), as Show says, and /flatui move places it (FlatUIPingBar in Movers.lua: the top left
-- corner of the bar is the top left corner of the box). While test mode is on (TestMode.lua, out of combat only) Show reads as Always and the bar
-- shows also while pings are blocked for you, greyed, with the reason in each tooltip, and a cooldown swipe runs once as a sample. The rows
-- under Pings (Ping, Attack, Warning, On My Way, Assist, all on) choose which of those buttons the bar shows (P.Wanted), and it closes up around
-- the rest, laid out again out of combat; every key under Key Bindings still pings. No frame or setting of the game is changed.
--
-- How the game pings. The ping wheel is the game's own (Blizzard_PingUI, for the game type mainline, Blizzard_PingUI.toc:4, which this client's
-- camelot loads too: Blizzard_UnitFrame.toc:20 has to exclude camelot from a mainline line). Its key (TOGGLEPINGLISTENER, Blizzard_PingUI/Bindings.xml:3-5)
-- runs C_Ping.TogglePingListener, and the keys of the four wedges run C_Ping.SendMacroPing with a type and no target (Bindings.xml:7-21,
-- Blizzard_PingUtil.lua:3-8): the game then pings what is under the mouse, a unit frame, a unit or the ground (Blizzard_PingManager.lua:225-239).
-- Both have restrictions (HasRestrictions: PingManagerDocumentation.lua:53-73), so an addon cannot call them; the game's secure slash command
-- /ping can (Blizzard_ChatFrameBase/Mainline/SlashCommandsOverrides.lua:55-75, SlashCommandUtil.CheckAddSecureSlashCommand, loaded as the
-- [Family] file of Blizzard_ChatFrameBase.toc:22). A button of Flat UI's own made from SecureActionButtonTemplate, of the type macro, has the game
-- run its macrotext in the game's secure code (Blizzard_FrameXML/SecureTemplates.lua:450-463), in a fight too; the secure templates have no ping
-- type of their own. Each line carries the number of its ping, which the game reads in every language (SlashCommandsOverrides.lua:41-54: 1 Attack,
-- 2 Warning, 3 On My Way, 4 Assist, 5 Not a threat, 6 Threat); Ping has none, so the game picks the kind for what it pings, as a tap of its ping
-- key does (SendHitTestPing or SendUnitPing with no type, Blizzard_PingManager.lua:248-262).
-- Click a ping, then click where. A /ping reads the cursor at the moment it runs, and during a click on the bar the cursor is on the bar: 0.5.32's
-- "/ping [@target,exists][@cursor]" pinged, with no target, the world behind the bar (often the sky, where the game refuses the ping), so a click
-- seemed to do nothing. The button did run its macro (it heard the press and the release, its type and macrotext were set, it was shown and took
-- the mouse); the line was the fault. Now a click arms the ping and the next click places it:
-- 1. A left click on a bar button runs ARM before the button's own click (SecureHandlerWrapScript, SecureHandlers.lua:272-290, 602-640, with a
--    SecureHandlerBaseTemplate header of Flat UI's own and its frame reference to the place button), in the game's restricted code, so in a fight
--    too: it gives the place button the bar button's "/ping [@cursor] <n>" and kind (SetAttribute of the handle, RestrictedFrames.lua:522-535),
--    shows it (Show, 394-400), makes Escape right-click it (SetBindingClick, an override binding owned by it, 545-562) and stops the bar button's
--    own macro (false). A bar button hears only the release of the left button (useOnKeyDown false, SecureTemplates.lua:792-826), so the place
--    button comes once the arming click is over.
-- 2. The place button, FlatUIPingPlace, is a SecureActionButtonTemplate button of Flat UI's own over the whole screen (UIParent's corners, strata
--    FULLSCREEN_DIALOG), of the type macro, set out of combat. The release of the next left click anywhere runs its line, and @cursor pings the
--    world under the cursor, passing through all frames (Blizzard_PingManager.lua:214-221); PLACED, after the click, hides it. A right click or
--    Escape hides it in PLACE before its macro, which then does not run; CLEAR, on its OnHide, takes Escape back (ClearBindings, 537-539), also
--    when UIParent hides it. The place button covers the bar too, so PLACE first asks whether the release is on the bar (the header's frame
--    references to the bar, protected of its own as SecureFrameTemplate, and to each bar button, set out of combat; IsVisible and IsUnderMouse
--    of the handles, RestrictedFrames.lua:116, 360-369): on another bar button it switches the waiting ping to that one (its line and kind,
--    then Hide and Show, so CLEAR and the line below run again, and Escape is given back), on the armed button it cancels, a Shift-click with a target pings the target at once (the bar
--    button's own line on the place button, then its macro), and between the buttons it does nothing, so a ping never lands behind the bar.
--    While the mouse is over it the cursor is the game's ping cursor, or its error cursor while the ping cooldown runs (SetCursor "PING_CURSOR"
--    and "PING_ERROR_CURSOR" from its OnShow and OnEnter, ResetCursor on OnLeave and OnHide, as Blizzard_PingUI.lua:134-152 does), a line of its
--    own beside the bar, hanging inward from it (P.Hint), says which ping is armed and how to cancel, and the armed button is lit in its ping's
--    colour, border and background, until the ping is placed or cancelled. Those scripts are insecure and change nothing protected: the text is a FontString of the place
--    button, set with SetText, and the light is the outline of the icon under the bar button. A ping that waits gives up after 10 seconds out of
--    combat (P.Shown sets a timer for each arm and switch, P.Cancel hides the place button, whose CLEAR gives Escape back), so a stray click on
--    the bar never eats the next click on the world; one that waited 10 seconds in a fight, where Flat UI's Lua may not hide the place button,
--    is cancelled as the fight ends (P.stale, P.AfterFight).
-- 3. A Shift-click with a target lets the bar button's own "/ping [@target,exists] <n>" run at once (ARM returns nothing: IsShiftKeyDown and
--    UnitExists are in the restricted environment, RestrictedEnvironment.lua:84-88); with no target it arms as a click.
-- 4. The keys ping at once what is under the mouse, as the game's own ping keys do: hover the spot, press the key. Each key clicks a secure button
--    of its own, named FlatUIPing and its kind (FlatUIPingPing, FlatUIPingAttack, FlatUIPingWarning, FlatUIPingOnMyWay, FlatUIPingAssist,
--    FlatUIPingNotThreat, FlatUIPingThreat) for its key binding in Bindings.xml (CLICK ...:LeftButton, category Flat UI), named in the game's Key
--    Bindings by BINDING_NAME_ globals here, as Mount key names its own. It is a child of UIParent with no size and no point, as Mount key's is,
--    so it shows nothing and takes no mouse; its line is "/ping <n>" with no condition, the call of the game's keys. It hears the press and the
--    release (AnyDown, AnyUp), and the game's ActionButtonUseKeyDown decides which acts (SecureTemplates.lua:792-826).
-- The bar buttons lie over icons of Flat UI's own, as Group tools' do, so an icon can be greyed or swiped in a fight while its secure button is
-- not touched. The bar shows Ping and each ping the game's wheel offers (C_Ping.GetDefaultPingOptions, in its orderIndex, as Blizzard_PingManager.lua:
-- 53-69 sorts them), else the four of the game's ping keys; every kind has its button and its key, shown on the bar or not. The secure buttons
-- make the bar protected, and it is made from SecureFrameTemplate (protected="true", SecureTemplatesBase.xml:4) so PLACE may read its handle in a
-- fight whatever the rules for a frame protected only by its children (RestrictedFrames.lua:79-85, GetPossiblyForbiddenHandleFrame); so the
-- bar, its buttons, the key buttons, the header and the place button are made, placed, sized and given attributes
-- only out of combat, and shown or hidden by Flat UI's own Lua only then: a change in a fight waits for its end (ns.OutOfCombat); in a fight only
-- the snippets above show and hide the place button and set its line. With the module off their type and macrotext are taken away and the place
-- button hides, so the keys and the bar do nothing; the bindings are the player's and stay.
-- The icons are the game's wheel icons, the atlas Ping_Wheel_Icon_ and the texture kit of the ping (Blizzard_PingManager.lua:59-63; the kits of
-- Blizzard_PingUI.lua:276-283), else its marker icon (Ping_Marker_Icon_, Blizzard_PingUI.lua:329), each only when the client has the atlas
-- (C_Texture.GetAtlasInfo), else a letter. The border of a button takes a colour near that of its icon (Borders in the ping's colour). With
-- Keys on the buttons, the first key bound to a button's key binding shows short in its top right corner, as action bars write it ("M4",
-- "s-F": GetBindingText(key, 1) as ActionButton.lua:501 asks, through ns.HotkeyText, ButtonText.lua), a FontString of the icon written again
-- on UPDATE_BINDINGS, so in a fight too.
-- Blocked: the bar hides, out of combat, while the game's ping system is off (C_Ping.IsPingSystemEnabled, as Blizzard_CompactRaidFrameManager.lua:
-- 163 asks), while Enable Pings is off in the game's options (the variable enablePings, Blizzard_SettingsDefinitions_Frame/PingSystem.lua:15) or
-- while the group lets only some members ping and you are not one (C_PartyInfo.GetRestrictPings, PartyInfoDocumentation.lua:348-355; Lead,
-- Assist and TankHealer, the radios of Blizzard_CompactRaidFrameManager.lua:179-182). The leader counts for each, an assistant for Assist and
-- TankHealer, and a tank or healer by its assigned role (UnitGroupRolesAssigned) for TankHealer; an answer the game withholds blocks nothing,
-- and the game refuses a ping it does not allow with its own message. While a fight holds the bar shown, its buttons are greyed and each tooltip
-- says why. The cooldown swipe (Cooldown swipe) is a Cooldown frame of Flat UI's own on each icon, set from C_Ping.GetCooldownInfo, whose
-- times in milliseconds are on the clock of GetTime (Blizzard_PingUI.lua:135-141 compares them so): read a moment after a ping of the bar, the
-- place button or a key (a PostClick of Flat UI's own, set out of combat, which runs after the game's secure code and changes no attribute) and
-- when the mouse comes over a button, as the game's listener reads it (Blizzard_PingUI.lua:134-147). The changes are heard on the module's events
-- (GROUP_ROSTER_UPDATE, PARTY_LEADER_CHANGED, PLAYER_ROLES_ASSIGNED, CVAR_UPDATE of enablePings, PLAYER_ENTERING_WORLD, UPDATE_BINDINGS for the
-- keys on the buttons and the tooltip); no OnUpdate, and a ticker only while the icons fade (Fade until you point at it). Pointing at a button writes its name, what a click and a Shift-click do,
-- its key and the game's own key for that ping in GameTooltip (SetOwner on the icon, SetText, AddLine, Show, and Hide when the mouse leaves), as Group tools does.
-- Fade until you point at it (off by default): the icons stay at 30% until the mouse comes over any button, back to full at once, and fade again
-- over a quarter of a second a second after the mouse leaves (ns.IconFader, IconRow.lua), as Group tools has it; they stay full while a ping
-- waits. Test mode holds nothing, so the fade can be tried there. Only the opacity of the icons changes, frames of Flat UI's own and no secure
-- button, so in a fight too, and the faint buttons take their clicks and keys as ever.

local KEY = "pingbar"
local MOVER = "FlatUIPingBar"
-- The name of the place button, which Escape's override binding clicks (SetBindingClick takes a name).
local PLACE = "FlatUIPingPlace"
-- The box of the handle in Movers.lua: Ping and the four pings of the wheel at the default size and spacing in a row. With no spot saved its top is
-- this far below the top of the screen, under the row of Group tools (GroupTools.lua: 24 high at 100 down).
local BOX_W, BOX_H, BOX_Y = 132, 24, -130
local INSET = 2
local FONT = "GameFontHighlightSmall"
-- The line of the place button, this far from the bar.
local HINT_FONT = "GameFontHighlight"
local HINT_GAP = 6
local HINT = "%s: click where to ping · click it again, right-click or Esc to cancel"
-- The text-dim of the windows (PanelLook.lua) for the lines of a tooltip, and the warm colour of the reason a button is greyed, as Group tools has.
local DIM = { 0.66, 0.68, 0.62 }
local WARN = { 0.9, 0.72, 0.36 }
local GREY_ALPHA = 0.4
local LIGHTER = 0.17
-- The opacity of the ping's colour behind the armed button.
local ARMED_ALPHA = 0.35
-- The cooldown is read this long after a press, once the game has sent the ping. A ping that waits this long out of combat gives up.
local AFTER_PRESS, GIVE_UP = 0.1, 10
local SAMPLE = 3
-- The kinds, in the order the bar shows them while the game offers no order: id (the button's name after FlatUIPing), the name of the enum value
-- of Enum.PingSubjectType and its number where the client has no enum (PingConstantsDocumentation), the number /ping reads, the texture kit, the
-- global string of its name (SlashCommandsOverrides.lua:43-53) and its English name, the game's own binding, and the colour of its border.
local KINDS = {
	{ id = "Ping", kit = "NonThreat", name = "Ping", game = "TOGGLEPINGLISTENER", colour = { 1, 0.82, 0.2 }, row = "ping" },
	{ id = "Attack", enum = "Attack", value = 0, word = "1", kit = "Attack", global = "PING_TYPE_ATTACK", name = "Attack", game = "PINGATTACK",
		colour = { 0.93, 0.27, 0.22 }, row = "attack" },
	{ id = "Warning", enum = "Warning", value = 1, word = "2", kit = "Warning", global = "PING_TYPE_WARNING", name = "Warning", game = "PINGWARNING",
		colour = { 1, 0.6, 0.13 }, row = "warning" },
	{ id = "OnMyWay", enum = "OnMyWay", value = 3, word = "3", kit = "OnMyWay", global = "PING_TYPE_ON_MY_WAY", name = "On My Way",
		game = "PINGONMYWAY", colour = { 0.32, 0.64, 1 }, row = "onMyWay" },
	{ id = "Assist", enum = "Assist", value = 2, word = "4", kit = "Assist", global = "PING_TYPE_ASSIST", name = "Assist", game = "PINGASSIST",
		colour = { 0.35, 0.85, 0.38 }, row = "assist" },
	{ id = "NotThreat", enum = "AlertNotThreat", value = 5, word = "5", kit = "NonThreat", global = "PING_TYPE_NOT_THREAT", name = "Not a threat",
		colour = { 1, 0.82, 0.2 } },
	{ id = "Threat", enum = "AlertThreat", value = 4, word = "6", kit = "Threat", global = "PING_TYPE_THREAT", name = "Threat",
		colour = { 0.93, 0.33, 0.2 } },
}
-- The four pings of the game's own keys, shown while the game offers no list.
local KEYS_ONLY = { Attack = 1, Warning = 2, OnMyWay = 3, Assist = 4 }
-- The conditions of the place button's line and of a Shift-click's.
local AT_CURSOR = "[@cursor]"
local AT_TARGET = "[@target,exists]"
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
-- button of the bar), key (the secure button of its key), hover, armed (its ping waits for a spot), equipped }. header: the SecureHandlerBaseTemplate frame the snippets run
-- against. place: the place button, hint its line. order: the places in KINDS of the kinds the bar shows. placed, laid: the spot and the layout
-- the bar was put at. queued: a change waits for the end of a fight. broken: the game made no secure button. why: the reason pings are blocked,
-- as last painted. equipped: the buttons have their type and macrotext. sample: a sample swipe waits for the bar to be made.
local P = { buttons = {}, queued = false, broken = false, equipped = false }
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

-- A timer of the client, false when there is none or it raises.
local function After(seconds, fn)
	return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, seconds, fn)
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

-- The places in KINDS of the buttons that show now: none while the module is off, Show does not allow the bar or the game made no secure button;
-- else those of P.Order whose row under Pings is on (a kind's row; Not a threat and Threat have none and show wherever the wheel offers them).
-- A new list each time, so P.order is never changed. None at all hides the bar, as Show Never does; the keys still ping.
function P.Wanted()
	if not ns.Enabled(KEY) or P.broken or not P.Allowed() then
		return {}
	end
	local list = {}
	for _, index in ipairs(P.Order()) do
		local row = KINDS[index] and KINDS[index].row
		if not row or Opt(row) ~= false then
			list[#list + 1] = index
		end
	end
	return list
end

-- The buttons --------------------------------------------------------------------------------------------------------------------------------

-- The restricted code, run by the game's secure handlers with the header as `control` (SecureHandlers.lua:61-75, 272-290, 331-347).
-- ARM, before a click on a bar button (`self`): a Shift-click with a target lets the button's own /ping [@target,exists] run; any other left
-- click hands the button's /ping [@cursor] line and kind to the place button, shows it, gives Escape to it and stops the bar button's macro.
local ARM = [=[
if button ~= "LeftButton" then
	return false
end
if IsShiftKeyDown() and UnitExists("target") then
	return
end
local line = self:GetAttribute("flatui-place")
local place = control:GetFrameRef("place")
if not line or not place then
	return false
end
place:SetAttribute("macrotext", line)
place:SetAttribute("flatui-kind", self:GetAttribute("flatui-kind"))
place:Show()
place:SetBindingClick(true, "ESCAPE", place, "RightButton")
return false
]=]
-- PLACE, before a click on the place button (`self`): a right click or Escape hides it and stops its macro; the press of the left button waits
-- for the release. A release on the bar, which the place button covers, is a click of the bar: on another bar button it switches the waiting
-- ping to that one, on the armed one it cancels, a Shift-click with a target runs that button's /ping [@target,exists] at once, and between the
-- buttons it does nothing. Any other release runs the macro and then PLACED, which hides it.
local PLACE_PRE = [=[
if button == "RightButton" then
	self:Hide()
	return false
end
if button ~= "LeftButton" or down then
	return false
end
local bar = control:GetFrameRef("bar")
if bar and bar:IsVisible() and bar:IsUnderMouse() then
	for index = 1, ]=] .. #KINDS .. [=[ do
		local cover = control:GetFrameRef("cover" .. index)
		if cover and cover:IsVisible() and cover:IsUnderMouse() then
			if IsShiftKeyDown() and UnitExists("target") and cover:GetAttribute("macrotext") then
				self:SetAttribute("macrotext", cover:GetAttribute("macrotext"))
				return nil, "placed"
			end
			local line, kind = cover:GetAttribute("flatui-place"), cover:GetAttribute("flatui-kind")
			if not line or kind == self:GetAttribute("flatui-kind") then
				self:Hide()
				return false
			end
			self:SetAttribute("macrotext", line)
			self:SetAttribute("flatui-kind", kind)
			self:Hide()
			self:Show()
			self:SetBindingClick(true, "ESCAPE", self, "RightButton")
			return false
		end
	end
	return false
end
return nil, "placed"
]=]
local PLACED = [=[
self:Hide()
]=]
-- CLEAR, on the place button's OnHide: Escape is its own only while it shows.
local CLEAR = [=[
self:ClearBindings()
]=]

-- A /ping line of a kind: with no condition (a key: what is under the mouse, as the game's keys ping), or with one (AT_CURSOR, AT_TARGET).
function P.Macro(kind, units)
	local line = units and ("/ping " .. units) or "/ping"
	if kind.word then
		return ("%s %s"):format(line, kind.word)
	end
	return line
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
-- the first letter of its name in its colour), the text of its key and a swipe for the cooldown.
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
	-- The key of its key binding, short, in the top right corner (P.KeyLabels), under the swipe as on action buttons.
	local keyText = ns.OwnText(frame, "OVERLAY", FONT)
	if keyText then
		keyText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
		keyText:SetJustifyH("RIGHT")
		keyText:SetWordWrap(false)
		pcall(keyText.SetShadowOffset, keyText, 1, -1)
		pcall(keyText.SetShadowColor, keyText, 0, 0, 0, 1)
		entry.keyText = keyText
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

-- The header the snippets run against: a SecureHandlerBaseTemplate frame of Flat UI's own, never shown. Nil when the game made none.
function P.Header()
	if type(SecureHandlerWrapScript) ~= "function" then
		return nil
	end
	local made, header = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerBaseTemplate")
	if not made or type(header) ~= "table" or IsSecret(header) then
		return nil
	end
	Own(header)
	pcall(header.Hide, header)
	return header
end

-- The place button: a secure button over the whole screen, hidden until ARM shows it, with the line that says which ping waits. Its insecure
-- scripts are set before the wraps, which call them after their snippets. Nil when the game made none.
function P.MakePlace(header)
	local made, place = pcall(CreateFrame, "Button", PLACE, UIParent, "SecureActionButtonTemplate")
	if not made or type(place) ~= "table" or IsSecret(place) then
		return nil
	end
	Own(place)
	local done = pcall(function()
		place:Hide()
		place:SetAllPoints(UIParent)
		place:SetFrameStrata("FULLSCREEN_DIALOG")
		place:EnableMouse(true)
		-- The release of the left button places the ping; the right button, by the mouse or by Escape, cancels on its press or its release.
		place:RegisterForClicks("LeftButtonUp", "RightButtonDown", "RightButtonUp")
		place:SetAttribute("useOnKeyDown", false)
		place:SetScript("OnShow", function()
			ns.Try(KEY, P.Shown)
		end)
		place:SetScript("OnHide", function()
			ns.Try(KEY, P.Uncursor)
			ns.Try(KEY, P.Disarm)
		end)
		place:SetScript("OnEnter", function()
			ns.Try(KEY, P.Cursor)
		end)
		place:SetScript("OnLeave", function()
			ns.Try(KEY, P.Uncursor)
		end)
		place:SetScript("PostClick", function(_, button, down)
			if button == "LeftButton" and not down then
				ns.Try(KEY, P.Pressed)
			end
		end)
		SecureHandlerWrapScript(place, "OnClick", header, PLACE_PRE, PLACED)
		SecureHandlerWrapScript(place, "OnHide", header, CLEAR)
		header:SetFrameRef("place", place)
	end)
	if not done then
		pcall(place.Hide, place)
		return nil
	end
	local hint = ns.OwnText(place, "OVERLAY", HINT_FONT)
	if hint then
		pcall(hint.SetShadowOffset, hint, 1, -1)
		pcall(hint.SetShadowColor, hint, 0, 0, 0, 1)
		P.hint = hint
	end
	return place
end

-- The secure button of the bar over an icon, a child of the bar with no picture of its own, above the icon. A left click arms its ping (ARM);
-- a Shift-click with a target runs its own macro. Its type and lines are given by P.Equip. Nil when the game made none.
function P.Cover(panel, entry, header)
	local made, cover = pcall(CreateFrame, "Button", nil, panel, "SecureActionButtonTemplate")
	if not made or type(cover) ~= "table" or IsSecret(cover) then
		return nil
	end
	Own(cover)
	local done = pcall(function()
		cover:SetFrameLevel(entry.frame:GetFrameLevel() + 3)
		cover:SetSize(BOX_H, BOX_H)
		cover:EnableMouse(true)
		-- The release of the left button only, whatever ActionButtonUseKeyDown says, so the place button shows once the arming click is over.
		cover:RegisterForClicks("LeftButtonUp")
		cover:SetAttribute("useOnKeyDown", false)
		cover:SetAttribute("flatui-kind", entry.kind.id)
		cover:SetScript("OnEnter", function()
			ns.Try(KEY, P.Enter, entry)
		end)
		cover:SetScript("OnLeave", function()
			ns.Try(KEY, P.Leave, entry)
		end)
		-- After the game's secure code ran a Shift-click: the cooldown it may have started is read a moment later.
		cover:SetScript("PostClick", function()
			ns.Try(KEY, P.Pressed)
		end)
		SecureHandlerWrapScript(cover, "OnClick", header, ARM)
	end)
	if not done then
		pcall(cover.Hide, cover)
		return nil
	end
	return cover
end

-- The secure button of a kind's key, named for its key binding: a child of UIParent with no size and no point, so it shows nothing and takes
-- no mouse. Nil when the game made none.
function P.Key(kind)
	local made, key = pcall(CreateFrame, "Button", "FlatUIPing" .. kind.id, UIParent, "SecureActionButtonTemplate")
	if not made or type(key) ~= "table" or IsSecret(key) then
		return nil
	end
	Own(key)
	local done = pcall(function()
		-- The press and the release: the game's ActionButtonUseKeyDown decides which acts, as for its own action buttons.
		key:RegisterForClicks("AnyDown", "AnyUp")
		key:SetScript("PostClick", function()
			ns.Try(KEY, P.Pressed)
		end)
	end)
	if not done then
		return nil
	end
	return key
end

-- The bar, its buttons, their keys, the header and the place button, made the first time the module is on, out of combat, with the header's
-- frame references to the bar and to each bar button, which PLACE reads. False when the game made no secure button.
function P.Build()
	if P.panel then
		return true
	elseif P.broken then
		return false
	end
	local header = P.Header()
	local place = header and P.MakePlace(header)
	if not place then
		P.broken = true
		return false
	end
	-- Protected of its own, so PLACE reads its handle in a fight (IsVisible, IsUnderMouse) whatever the game's rules for a frame protected only by
	-- its secure children.
	local madePanel, panel = pcall(CreateFrame, "Frame", nil, UIParent, "SecureFrameTemplate")
	if not madePanel or type(panel) ~= "table" or IsSecret(panel) then
		P.broken = true
		pcall(place.Hide, place)
		return false
	end
	Own(panel)
	panel:SetFrameStrata("LOW")
	panel:SetSize(BOX_W, BOX_H)
	panel:Hide()
	local buttons = {}
	for index, kind in ipairs(KINDS) do
		local entry = P.Icon(panel, kind)
		entry.cover = P.Cover(panel, entry, header)
		entry.key = entry.cover and P.Key(kind)
		if not entry.key or not pcall(header.SetFrameRef, header, "cover" .. index, entry.cover) then
			P.broken = true
			pcall(panel.Hide, panel)
			return false
		end
		buttons[index] = entry
	end
	if not pcall(header.SetFrameRef, header, "bar", panel) then
		P.broken = true
		return false
	end
	P.buttons, P.panel, P.header, P.place = buttons, panel, header, place
	return true
end

-- Gives every button its type and lines while the module is on, or takes them away, so a click or a key does nothing, and hides the place
-- button then. Only out of combat, and only what changed. The bar button: its own macro is the Shift-click at your target, flatui-place the
-- line ARM hands on. The key: what is under the mouse. The place button: the type; ARM gives the line.
function P.Equip(on)
	for _, entry in ipairs(P.buttons) do
		if entry.equipped ~= on then
			local kind, cover, key = entry.kind, entry.cover, entry.key
			if pcall(function()
				cover:SetAttribute("type", on and "macro" or nil)
				cover:SetAttribute("macrotext", on and P.Macro(kind, AT_TARGET) or nil)
				cover:SetAttribute("flatui-place", on and P.Macro(kind, AT_CURSOR) or nil)
				key:SetAttribute("type", on and "macro" or nil)
				key:SetAttribute("macrotext", on and P.Macro(kind) or nil)
			end) then
				entry.equipped = on
			end
		end
	end
	local place = P.place
	if place and P.equipped ~= on then
		pcall(place.SetAttribute, place, "type", on and "macro" or nil)
	end
	if not on then
		P.Cancel()
	end
	P.equipped = on
end

-- Hides the place button, so no ping waits, out of combat: its OnHide takes Escape back.
function P.Cancel()
	if P.place and not Fighting() then
		pcall(P.place.Hide, P.place)
	end
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
			-- A ping that waits on a button its row under Pings just took off gives up, as nothing would show it waits.
			if entry.armed then
				P.Cancel()
			end
		end
	end
	P.panel:SetSize(math.max(1, width), math.max(1, height))
	P.laid = key
end

-- Puts the bar at the spot of its handle: its top left corner at the top left corner of the box. The line of the place button hangs inward from
-- the bar, so it can always be read: under the bar while the bar's centre is in the upper half of the screen, else over it, from the bar's left
-- edge while it is in the left third, its right edge in the right third, else centred; beside a column (Layout Vertical), to its right, or to
-- its left in the right half of the screen.
function P.Place()
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(MOVER, "TOPLEFT")
	end
	local key = (x and ("%.2f:%.2f"):format(x, y) or "start") .. ":" .. tostring(Opt("layout"))
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
	if P.hint then
		P.Hint(panel, P.hint)
	end
end

-- Anchors the line of the place button by where the bar is (P.Place). With no answer about the screen, it goes centred under the bar.
function P.Hint(panel, hint)
	local okWidth, width = pcall(UIParent.GetWidth, UIParent)
	local okHeight, height = pcall(UIParent.GetHeight, UIParent)
	local okCentre, cx, cy = pcall(panel.GetCenter, panel)
	local known = okWidth and okHeight and okCentre and ns.Finite(width) and ns.Finite(height) and ns.Finite(cx) and ns.Finite(cy) and width > 0
	hint:ClearAllPoints()
	if known and Opt("layout") == "column" then
		if cx > width / 2 then
			hint:SetPoint("RIGHT", panel, "LEFT", -HINT_GAP, 0)
		else
			hint:SetPoint("LEFT", panel, "RIGHT", HINT_GAP, 0)
		end
		return
	end
	local side = ""
	if known and cx < width / 3 then
		side = "LEFT"
	elseif known and cx > width * 2 / 3 then
		side = "RIGHT"
	end
	if not known or cy > height / 2 then
		hint:SetPoint("TOP" .. side, panel, "BOTTOM" .. side, 0, -HINT_GAP)
	else
		hint:SetPoint("BOTTOM" .. side, panel, "TOP" .. side, 0, HINT_GAP)
	end
end

-- Makes the buttons, gives them their pings, and lays out, places and shows the bar, or hides it. Only out of combat (P.Apply).
function P.Lay()
	local on = ns.Enabled(KEY)
	if not on then
		if P.panel then
			P.panel:Hide()
			P.Equip(false)
		end
		return
	end
	if not P.Build() then
		return
	end
	P.Equip(true)
	P.KeyLabels()
	local wanted = P.Wanted()
	if #wanted == 0 then
		P.panel:Hide()
		P.Cancel()
		return
	end
	P.Layout(wanted)
	P.Place()
	P.panel:Show()
	P.fader.Settle()
	local mode = ns.TestMode
	if P.sample and mode ~= nil and mode.IsOn() == true then
		P.Sample()
	end
end

-- A change in a fight waits for its end, once however many come. A module that stopped in the fight only hides the bar and the place button.
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
			P.Cancel()
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

-- The background and border of an icon. The armed button, whose ping waits for its spot, is lit: its ping's colour behind it and on its border.
-- Else the background is the Background colour of the Flat UI page, a little lighter under the mouse while pings can be sent, and the border
-- takes its ping's colour while Borders in the ping's colour is on, else the general one.
function P.Shade(entry)
	local colour = entry.kind.colour
	if entry.armed then
		ns.SetOutlineFill(entry.outline, colour[1], colour[2], colour[3], ARMED_ALPHA)
	elseif entry.hover and not P.why then
		local r, g, b = ns.Colour("general.backdrop")
		ns.SetOutlineFill(entry.outline, math.min(1, r + LIGHTER), math.min(1, g + LIGHTER), math.min(1, b + LIGHTER), 1)
	else
		ns.SetOutlineFill(entry.outline, nil, nil, nil, nil)
	end
	if entry.armed or Opt("colours") ~= false then
		ns.SetOutlineColour(entry.outline, colour[1], colour[2], colour[3])
	else
		ns.SetOutlineColour(entry.outline, nil, nil, nil)
	end
end

-- Greys the buttons while pings are blocked, gives each border and background its colour (P.Shade), and writes again the tooltip of the one
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
	local usable = P.why == nil
	for _, entry in ipairs(P.buttons) do
		if entry.art then
			entry.art:SetDesaturated(not usable)
			entry.art:SetAlpha(usable and 1 or GREY_ALPHA)
		end
		if entry.letter then
			entry.letter:SetAlpha(usable and 1 or GREY_ALPHA)
		end
		P.Shade(entry)
		if entry.hover and P.Owned(entry) then
			P.Tip(entry)
		end
	end
	P.fader.Settle()
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

-- The first key bound to a binding, short as action bars write it (GetBindingText(key, 1), then ns.HotkeyText of ButtonText.lua with no button,
-- which always shortens), or nil.
local function ShortKey(binding)
	local key = Ask(GetBindingKey, binding)
	if type(key) ~= "string" or key == "" then
		return nil
	end
	local text = Ask(GetBindingText, key, 1)
	text = type(text) == "string" and text ~= "" and text or key
	if type(ns.HotkeyText) == "function" then
		local ok, short = pcall(ns.HotkeyText, text)
		if ok and not IsSecret(short) and type(short) == "string" and short ~= "" then
			text = short
		end
	end
	return text
end

-- Keys on the buttons: the key of each button's key binding in its top right corner, a third of Button size high, nothing with the row off or no
-- key bound. The height is given on every call, before and apart from the layout, which P.Layout keeps while nothing of it changed: Fonts, which
-- starts after this module at login (MODULE_ORDER in Core.lua), may set the font object of the label again (Fonts.lua), and a string can take
-- its font object's height back, as Group tools notes for its countdown number. P.Lay, P.Refresh and UPDATE_BINDINGS run this. Only FontStrings
-- of the icons change, so this runs in a fight too.
function P.KeyLabels()
	local on = Opt("keys") ~= false
	local high = math.max(7, math.floor(Number("size", BOX_H) / 3 + 0.5))
	for _, entry in ipairs(P.buttons) do
		local text = entry.keyText
		if text then
			text:SetTextHeight(high)
			local label = on and ShortKey("CLICK FlatUIPing" .. entry.kind.id .. ":LeftButton") or nil
			text:SetText(label or "")
			text:SetShown(label ~= nil)
		end
	end
end

-- The lines of a button's tooltip: what a click and a Shift-click ping, its key and the game's own key for that ping.
function P.Lines(entry)
	local kind, lines = entry.kind, {}
	if kind.word then
		lines[#lines + 1] = ("Click, then click where to ping: %s goes to that spot for your group. Right-click or Esc cancels."):format(Name(kind))
	else
		lines[#lines + 1] = "Click, then click where to ping: the game picks the kind of ping for that spot. Right-click or Esc cancels."
	end
	lines[#lines + 1] = "Shift-click pings your target at once; with no target it works as a click."
	lines[#lines + 1] = "While a ping waits, click another button to switch to it, or this one again to cancel."
	lines[#lines + 1] = ("A ping that waits gives up after %d seconds, or as the fight ends if it waited through one."):format(GIVE_UP)
	local key = KeyText("CLICK FlatUIPing" .. kind.id .. ":LeftButton")
	if key then
		lines[#lines + 1] = ("Key: %s pings what is under the mouse at once: hover the spot, press the key."):format(key)
	else
		lines[#lines + 1] = ("No key: bind Ping: %s under Flat UI in the game's Key Bindings to ping what is under the mouse at once."):format(kind.name)
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
	P.Wake()
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
	P.Faint()
	P.Shade(entry)
	if P.Owned(entry) then
		pcall(_G.GameTooltip.Hide, _G.GameTooltip)
	end
end

-- The place button ------------------------------------------------------------------------------------------------------------------------------

-- The game's ping cursor while the mouse is over the place button, its error cursor while the ping cooldown runs.
function P.Cursor()
	if type(SetCursor) == "function" then
		pcall(SetCursor, P.Cooldown() and "PING_ERROR_CURSOR" or "PING_CURSOR")
	end
end

function P.Uncursor()
	if type(ResetCursor) == "function" then
		pcall(ResetCursor)
	end
end

-- The place button shows, from ARM or from a switch in PLACE: its line names the ping that waits, in that ping's colour, its button is lit and
-- the cursor turns. GIVE_UP seconds later, should the same ping still wait, it is cancelled out of combat, or marked to be as the fight ends.
function P.Shown()
	local hint, place = P.hint, P.place
	local token = {}
	P.waiting, P.stale = token, nil
	After(GIVE_UP, function()
		if P.waiting ~= token or not P.place then
			return
		end
		local ok, shown = pcall(P.place.IsShown, P.place)
		if not ok or IsSecret(shown) or shown ~= true then
			return
		end
		if Fighting() then
			P.stale = true
		else
			ns.Try(KEY, P.Cancel)
		end
	end)
	if place then
		local ok, id = pcall(place.GetAttribute, place, "flatui-kind")
		local kind = KINDS[1]
		for _, each in ipairs(KINDS) do
			if ok and not IsSecret(id) and each.id == id then
				kind = each
			end
		end
		if hint then
			local colour = kind.colour
			hint:SetText(HINT:format(Name(kind)))
			hint:SetTextColor(colour[1], colour[2], colour[3], 1)
		end
		for _, entry in ipairs(P.buttons) do
			entry.armed = entry.kind == kind
			P.Shade(entry)
		end
	end
	P.Wake()
	P.Cursor()
end

-- The place button hid: the ping was placed or cancelled, so no button is lit and nothing waits to give up.
function P.Disarm()
	P.waiting, P.stale = nil, nil
	for _, entry in ipairs(P.buttons) do
		if entry.armed then
			entry.armed = false
			P.Shade(entry)
		end
	end
	P.Faint()
end

-- The keys on the buttons and the tooltip under the mouse, written again after a key changed.
function P.Retip()
	P.KeyLabels()
	for _, entry in ipairs(P.buttons) do
		if entry.hover and P.Owned(entry) then
			P.Tip(entry)
		end
	end
end

-- Fade until you point at it -------------------------------------------------------------------------------------------------------------

-- True while the icons stay full: the row off, the mouse over a button or a ping that waits. Test mode holds nothing, so Fade until you point at
-- it can be tried there, where a player in no group sees the bar.
function P.Held()
	if Opt("fade") ~= true then
		return true
	end
	for _, entry in ipairs(P.buttons) do
		if entry.hover or entry.armed then
			return true
		end
	end
	return false
end

P.fader = ns.IconFader(function()
	return P.buttons
end, P.Held)

-- Full at once; faint a second after nothing holds the icons full (ns.IconFader).
function P.Wake()
	P.fader.Wake()
end

function P.Faint()
	P.fader.Faint()
end

-- The module ---------------------------------------------------------------------------------------------------------------------------------

function P.Refresh()
	P.placed, P.laid = nil, nil
	if not ns.Enabled(KEY) and P.panel then
		P.Swipe(nil)
	end
	P.Apply()
	P.KeyLabels()
end

-- The end of a fight: a ping that waited GIVE_UP seconds in it gives up, and a change that still waits is applied, should the game have said it
-- was in a fight when ns.OutOfCombat ran it.
function P.AfterFight()
	if P.stale then
		P.Cancel()
	end
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
	-- writes the keys on the buttons and the tooltip again.
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
