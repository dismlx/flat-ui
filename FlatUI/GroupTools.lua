local _, ns = ...

-- Group tools: a row of buttons of Flat UI's own for a group, the eight raid markers and a clear for your target, a ready check, a role poll
-- and a pull countdown, drawn as the icons of IconRow.lua are: square, with a thin border on a dark background. With Borders in the marker's
-- colour each marker's border takes the colour the game's own menu gives it (UnitPopupSharedButtonMixins.lua:2653-2752, GetColor of
-- RaidTarget1 to 8). A module of its own, on by default, whose page is in the Group group. The row shows in a group, or as Show says, and /flatui move places it (FlatUIGroupTools in
-- Movers.lua: the top left corner of the row is the top left corner of the box). While test mode is on (TestMode.lua, out of combat only) Show
-- reads as Always, the tick shows a sample tally of 4/5 with a sample Eli not ready, the pull button counts down from Countdown length in
-- the warm colour, again and again, with its red last seconds and its flash at each 0, the Skull is lit as your target's marker while the target
-- wears none, and the role poll's tooltip lists a sample party's roles, names in their class colours, while its count reads 1 for the sample Kai
-- (G.SampleOn); a real ready check, countdown, marker or roles take their place. No frame or setting of the game is changed.
--
-- What the game allows. SetRaidTarget, RemoveRaidTargets, C_PartyInfo.DoReadyCheck and C_PartyInfo.DoCountdown have restrictions
-- (HasRestrictions: RaidMarkersDocumentation.lua:108-124, PartyInfoDocumentation.lua:156-174), so they run only in the secure click of a button
-- of Flat UI's own made from SecureActionButtonTemplate, where the game's own secure code makes the call. A marker is of the type raidtarget,
-- which toggles the marker on the target, and with the action clear or clear-all takes it off the target or off every unit
-- (Blizzard_FrameXML/SecureTemplates.lua:582-603). The ready check and the countdown are of the type macro, whose macrotext the game runs
-- (SecureTemplates.lua:450-463) with its own /readycheck, which does nothing for a member who is neither the leader nor an assistant, and
-- /countdown (Blizzard_ChatFrameBase/Shared/SlashCommands.lua:1275-1279, 1666-1672); /countdown 0 stops a countdown, as
-- EnhanceQoLDungeonRaid/Init.lua:440 stops one. The right button reads the attributes that end in 2, with any key held (SecureTemplates.lua:
-- 101-133), so a right-click takes the marker off your target, every marker with the clear, and stops the countdown. Shift and Ctrl turn a
-- marker and the clear on the player and on the focus (shift-unit* and ctrl-unit*, which SecureButton_GetModifiedUnit reads: SecureTemplates.lua:
-- 118-143), with either button, so Shift-right-click takes the player's marker off; a focus that does not exist makes the click do nothing
-- (717-718), and a marker greyed for no target still marks the player with Shift. A secure button listens for
-- the release of the mouse button (useOnKeyDown false, SecureTemplates.lua:792-800), as those of Reload.lua do. InitiateRolePoll has no
-- restriction (UnitRoleDocumentation.lua:29-36) and the game's own buttons call it from a plain click (Mainline/
-- Blizzard_CompactRaidFrameManager.lua:1435-1438, Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_Listing.lua:626-629), so the role poll
-- is a plain button of Flat UI's own, clicked when the left mouse button comes up over it after going down on it, as Errands.Button is.
-- The secure buttons hold no picture and lie over icons of Flat UI's own, as the secure button of Reload.lua lies over its flat button, so an
-- icon can be greyed in a fight while its secure button is not touched. The secure buttons make the frame of the row protected, so the row and
-- its buttons are made, placed, sized, shown, hidden and given attributes only out of combat: a change in a fight (a group joined, a row of the
-- page changed, the row moved) waits for its end (ns.OutOfCombat), and in a fight nothing on them changes. Nothing of the module runs but on
-- its events, the mouse and, only while a countdown runs, a ticker of one second, and with Fade until you point at it a wait of a second
-- and a short ticker as the icons fade; no OnUpdate.
-- The tally of a ready check: from READY_CHECK to READY_CHECK_FINISHED (and on each READY_CHECK_CONFIRM: PartyInfoDocumentation.lua:839-870)
-- the tick's icon shows how many are ready of those asked, as 3/5, read with GetReadyCheckStatus for the player and party1 to party4, or raid1
-- to the size of the raid (the call the game's own frames make, CompactUnitFrame.lua:1371; plain answers only): green when all are ready, in
-- the warm colour once someone is not ready or, after the check, did not answer; the tick gives the white flash of cooldown icons (IconRow.lua)
-- the moment the last member answers ready. Its tooltip names who is not ready and who has not answered, by plain names only, each in his class
-- colour (ns.ClassColourOf, plain answers only), and the result stays 8 seconds after the check ends. The pull countdown: from START_TIMER of the
-- player countdown type (Enum.StartTimerType.PlayerCountdown, TimerConstantsDocumentation.lua:13-16; timeRemaining,
-- WorldStateInfoDocumentation.lua:43-62) its number counts the seconds left in the warm colour, the last three in red, once a second
-- (C_Timer.NewTicker), and goes back to Countdown length at 0, with the white flash, or on STOP_TIMER_OF_TYPE. Both change only FontStrings and
-- textures of the icons of Flat UI's own, never a secure button, so in a fight too. Out of combat the mouse wheel over the pull button makes
-- Countdown length a second longer or shorter (3 to 60 seconds, G.Wheel): an OnMouseWheel script of the addon's own on its own secure button, set
-- as the button is made, out of combat; in a fight it does nothing.
-- A button that cannot work for the player now is greyed, as the game's own group manager decides (Mainline/
-- Blizzard_CompactRaidFrameManager.lua:601-645, 698, 1263): a marker without a target the game lets be marked (CanBeRaidTarget), and every
-- marker and the clear in a raid unless the player is its leader or an assistant or everyone is; the ready check, the role poll and the
-- countdown out of a group or unless the player is the leader or an assistant; the role poll also in a group the dungeon finder made
-- (HasLFGRestrictions) and in a battleground. An answer the game withholds (UnitIsGroupLeader and UnitIsGroupAssistant may be secret,
-- UnitDocumentation.lua:2023-2055) greys nothing and is not read: the click lets the game decide, and the game refuses what it does not allow.
-- The greying follows the group, its leader and the target while the row shows (GROUP_ROSTER_UPDATE, PARTY_LEADER_CHANGED, PARTY_LFG_RESTRICTED:
-- PartyInfoDocumentation.lua:680, 784, 790; PLAYER_TARGET_CHANGED: UnitDocumentation.lua:3976). Pointing at a button writes its lines in
-- GameTooltip (SetOwner on the icon, SetText, AddLine, Show, and Hide when the mouse leaves), as the data panels do; a marker's and the clear's
-- name the game's own key for them where one is bound (RAIDTARGET1 to 8 and RAIDTARGETNONE, Blizzard_FrameXML/Bindings_Standard.xml:1573-1597),
-- written again on UPDATE_BINDINGS.
-- The marker your target wears (GetRaidTargetIndex, whose answer may be secret, RaidMarkersDocumentation.lua:55-69: plain answers only, so a
-- withheld index lights nothing) is lit, its colour at 35% behind it and on its border, as the Ping bar lights a waiting ping, and its tooltip
-- says a left-click takes it off. It follows PLAYER_TARGET_CHANGED and RAID_TARGET_UPDATE (EncounterInfoDocumentation.lua:86), in a fight too,
-- as only the outline of an icon of Flat UI's own changes. The role poll's tooltip lists who has which role (UnitGroupRolesAssigned and UnitName,
-- plain answers only), each name in its class colour: a line for each role in a party, and there "No tank" or "No healer" in the warm colour
-- when nobody holds that role while someone holds one, the counts in a raid, and in the warm colour who has none, written again on
-- PLAYER_ROLES_ASSIGNED (PartyInfoDocumentation.lua:829) while the mouse is over it. The corner of its icon counts in the warm colour how many
-- members have no role (a plain NONE), as the tick shows its tally, only once someone in the group holds a tank, healer or damage role (most
-- groups on Forever pick none, and the whole group would read as missing), grey while the role poll is greyed, hidden at 0 and out of a group
-- (G.RoleCount), on each paint.
-- Fade until you point at it (off by default): the icons stay at 30% until the mouse comes over any button, back to full at once, and fade again
-- over a quarter of a second a second after the mouse leaves (ns.IconFader, IconRow.lua). They stay full during a real ready check and its tally
-- and a real countdown; the samples of test mode hold nothing, so the fade can be tried there. Only the opacity of the icons changes, frames of
-- Flat UI's own and no secure button, so in a fight too, and the faint buttons take their clicks and keys as ever.
-- Adapted from the Mark Bar of the data panels and the Group Tools panel of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission
-- (EnhanceQoL/Core/Streams/Stream_MarkBarCommon.lua:4-16, Stream_MarkBarTarget.lua:20-40, Stream_MarkBarUtility.lua:51-75,
-- EnhanceQoLDungeonRaid/GroupTools.lua:29-31, 272-289, 472): its secure buttons for the markers, the ready check and the countdown and the
-- countdown of 0 that stops one, the plain role poll and who may use it, and the skull first. Its markers are the game's secure marker action
-- in place of /tm, the same toggle; its world markers, pings, convert, disband and leave buttons, its folding panel and its designs are left out.

local KEY = "grouptools"
local MOVER = "FlatUIGroupTools"
-- The box of the handle in Movers.lua: the buttons at the default size and spacing in a row. With no spot saved its top is this far below the top
-- of the screen, under the game's top widgets (Blizzard_UIWidgets/Blizzard_UIWidgetTopCenterFrame.xml:6) and above its zone text and countdown
-- bars (Blizzard_FrameXML/Mainline/ZoneText.xml:6, Timer.lua:131).
local BOX_W, BOX_H, BOX_Y = 327, 24, -100
-- The room between the markers and the rest beyond the spacing, and between the edge of an icon and its picture.
local GAP, INSET = 6, 2
local FONT = "GameFontHighlightSmall"
-- The text-dim of the windows (PanelLook.lua) for the lines of a tooltip, and the warm colour of the reason a button is greyed.
local DIM = { 0.66, 0.68, 0.62 }
local WARN = { 0.9, 0.72, 0.36 }
-- The green of a ready check that all answered ready, how long its tally stays after it ends, and the step of the countdown's number.
local ALL_READY = { 0.4, 0.9, 0.4 }
local KEEP_TALLY, COUNT_STEP = 8, 1
-- The red of the last seconds of a countdown, from how many seconds left, and the shortest and longest Countdown length the mouse wheel sets (the
-- row's own limits, Config.lua).
local LAST_RED, LAST_FROM = { 1, 0.3, 0.3 }, 3
local PULL_LEAST, PULL_MOST = 3, 60
-- The player countdown among the types of START_TIMER, where the client has no enum.
local PLAYER_COUNTDOWN = 2
local GREY_ALPHA = 0.4
-- How much lighter the background of an icon is under the mouse, as Errands.Button has it.
local LIGHTER = 0.17
-- The pictures, each a file the game's own frames use: the raid markers in a sheet of four by four (Blizzard_UnitFrame/Mainline/TargetFrame.xml:282,
-- cut as SetupDrawPlates.lua cuts it), the pass of a loot roll for the clear (Blizzard_UIPanels_Game/Mainline/GroupLootFrame.xml:243), the green
-- tick (Blizzard_Calendar/Mainline/Blizzard_CalendarTemplates.xml:325) and the sheet of the roles of the group finder
-- (Blizzard_GroupFinder_VanillaStyle/Mainline/Blizzard_LFGVanilla_Listing.xml:37), whose four cells of 67 pixels in its top left corner show
-- together (Blizzard_SharedXML/Shared/SharedUtils.lua:17-32).
local MARKERS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local CLEAR = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local READY = "Interface\\RaidFrame\\ReadyCheck-Ready"
local ROLES = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES"
local ROLES_CUT = 134 / 256
-- The markers by index, the game's RAID_TARGET_1 to RAID_TARGET_8, and the colour of each as the game's menu gives it
-- (UnitPopupSharedButtonMixins.lua:2653-2752).
local NAMES = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
local COLOURS = {
	{ 1, 0.92, 0 }, { 0.98, 0.57, 0 }, { 0.83, 0.22, 0.9 }, { 0.04, 0.95, 0 },
	{ 0.7, 0.82, 0.875 }, { 0, 0.71, 1 }, { 1, 0.24, 0.168 }, { 0.98, 0.98, 0.98 },
}
-- The sample ready check of test mode, its member not ready with his class (PartyCooldowns.lua's sample priest).
local SAMPLE_READY, SAMPLE_TOTAL, SAMPLE_NAME, SAMPLE_CLASS = 4, 5, "Eli", "PRIEST"
-- The marker your target wears is lit: its colour behind it at this opacity, as the Ping bar lights a waiting ping (PingBar.lua ARMED_ALPHA). The
-- sample of test mode is the Skull.
local LIT_ALPHA, SAMPLE_MARK = 0.35, 8
local LIT = "On your target now: a left-click takes it off."
local LIT_SAMPLE = "Sample: lit as it is when your target wears it."
-- The roles of the role poll's tooltip in their order, the word of a party's line and of a raid's count and the line of a party where nobody holds
-- it, the most names of those with no role in a raid, and the sample party of test mode by line, each name with its class (the names and classes of
-- PartyCooldowns.lua's sample party, and a Kai who picked no role).
local ROLE_WORDS = { { "TANK", "Tank", "Tanks", "No tank" }, { "HEALER", "Healer", "Healers", "No healer" }, { "DAMAGER", "Damage", "Damage" } }
local ROLE_NAMES = 8
local SAMPLE_ROLES = {
	{ "Tank", { "Mara", "PALADIN" } }, { "Healer", { "Eli", "PRIEST" } }, { "Damage", { "Ivo", "WARLOCK" }, { "Fay", "ROGUE" } },
	{ "No role", { "Kai", "MAGE" } },
}
local NO_TARGET = "You have no target (Shift-click still marks you)."
local NO_MARK = "Your target cannot be marked (Shift-click still marks you)."
local RAID_MARK = "In a raid only the leader and assistants can mark."
local NO_GROUP = "You are not in a group."
local NOT_LEAD = "Only the leader or an assistant can do this."
local LFG = "Not in a group the dungeon finder made."
local BATTLEGROUND = "Not in a battleground."
local NO_POLL = "This client has no role poll."
local LINE_WAITING = "Group tools: the buttons change when the fight ends."
local LINE_BROKEN = "Group tools: the game made no secure button, so the buttons stay hidden."

-- The buttons in their order, as the game's menu and group manager list the markers, from the skull down (UnitPopupSharedButtonMixins.lua:
-- 2568-2580): the kind, the row of the page that shows it, its group (the markers and the clear, then the rest) and the marker of a marker.
local SPECS = {}
for marker = 8, 1, -1 do
	SPECS[#SPECS + 1] = { kind = "mark", row = "marks", group = 1, marker = marker }
end
SPECS[#SPECS + 1] = { kind = "clear", row = "marks", group = 1 }
SPECS[#SPECS + 1] = { kind = "check", row = "readyCheck", group = 2 }
SPECS[#SPECS + 1] = { kind = "roles", row = "rolePoll", group = 2 }
SPECS[#SPECS + 1] = { kind = "pull", row = "pull", group = 2 }

local IsSecret = ns.IsSecret
-- panel: the frame of the row. buttons: one entry for each of SPECS, { kind, row, group, marker, frame (the icon), art, text (the countdown's
-- number), tally (the ready check's count), outline, cover (the secure button over the icon; none for the role poll), usable, why, hover,
-- seconds }. placed: the spot the row was put at. laid: the buttons, size, spacing and layout the row was laid out for. queued: a change waits
-- for the end of a fight. broken: the game made no secure button. check: the tally of the last ready check, { ready, total, notReady, waiting,
-- over, sample (test mode's) }. ends: when the running countdown ends, on the clock of GetTime; ticker its step; sampleCount: it is test mode's.
local G = { buttons = {}, queued = false, broken = false }
ns.GroupTools = G

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

-- A number row, else its default.
local function Number(key, default)
	local value = Opt(key)
	return ns.Finite(value) and value or default
end

-- The length of the countdown, in whole seconds.
local function Seconds()
	return math.floor(Number("pullTime", 10))
end

-- True or false from a call of the client, or nil when the call is missing, raises or withholds the answer. Nothing back counts as false.
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

-- A timer of the client, false when there is none or it raises.
local function After(seconds, fn)
	return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, seconds, fn)
end

-- True when either is true, false when both are false, nil while one of them is not known.
local function Either(a, b)
	if a == true or b == true then
		return true
	elseif a == false and b == false then
		return false
	end
	return nil
end

-- In a fight, or the game will not say: the secure buttons are left alone then (ChatLinks.lua counts a withheld answer the same).
local function Fighting()
	local ok, fighting = pcall(InCombatLockdown)
	return ok and (IsSecret(fighting) or fighting == true)
end

-- Whether the mouse is over a frame when its button comes up: a press let go elsewhere is no click. A client that does not say counts as over.
local function Over(frame)
	local ok, over = pcall(frame.IsMouseOver, frame)
	return not ok or IsSecret(over) or over ~= false
end

-- True while test mode is on (TestMode.lua).
local function Testing()
	local mode = ns.TestMode
	return mode ~= nil and mode.IsOn() == true
end

-- The colour code of red, green and blue from 0 to 1.
local function Hex(r, g, b)
	local function Byte(value)
		return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5)
	end
	return ("|cff%02x%02x%02x"):format(Byte(r), Byte(g), Byte(b))
end

-- A plain name in the class colour of its unit (ns.ClassColourOf, plain answers only), as Targeted by writes the group (ChatTips.lua), or as it is.
-- The line's own colour comes back after it, so a label keeps its dim or warm colour.
local function Coloured(unit, name)
	local r, g, b = ns.ClassColourOf(unit)
	return r and (Hex(r, g, b) .. name .. "|r") or name
end

-- A sample name in the colour of a class by its file name (RAID_CLASS_COLORS), or as it is.
local function ClassName(name, class)
	local colours = RAID_CLASS_COLORS
	local colour = type(colours) == "table" and not IsSecret(colours) and colours[class] or nil
	if type(colour) == "table" and not IsSecret(colour) and ns.Finite(colour.r) and ns.Finite(colour.g) and ns.Finite(colour.b) then
		return Hex(colour.r, colour.g, colour.b) .. name .. "|r"
	end
	return name
end

-- What may be done ----------------------------------------------------------------------------------------------------------------------------

-- What the game says of the player's group now: in a group, in a raid, and leading (the leader or an assistant, or in a raid where everyone is an
-- assistant). Each is nil where the game will not say.
function G.State()
	local grouped, raid = Truth(IsInGroup), Truth(IsInRaid)
	local lead = Either(Truth(UnitIsGroupLeader, "player"), Truth(UnitIsGroupAssistant, "player"))
	if raid == true and lead ~= true then
		lead = Either(lead, Truth(IsEveryoneAssistant))
	end
	return grouped, raid, lead
end

-- Whether a kind of button can work now, and the reason when it cannot. What the game will not say counts as usable.
function G.Usable(kind, grouped, raid, lead)
	if kind == "mark" or kind == "clear" then
		if raid == true and lead == false then
			return false, RAID_MARK
		end
		if kind == "mark" then
			if Truth(UnitExists, "target") == false then
				return false, NO_TARGET
			elseif Truth(CanBeRaidTarget, "target") == false then
				return false, NO_MARK
			end
		end
		return true
	end
	if grouped == false then
		return false, NO_GROUP
	elseif lead == false then
		return false, NOT_LEAD
	end
	if kind == "roles" then
		if type(InitiateRolePoll) ~= "function" then
			return false, NO_POLL
		elseif Truth(HasLFGRestrictions) == true then
			return false, LFG
		elseif Truth(UnitInBattleground, "player") == true then
			return false, BATTLEGROUND
		end
	end
	return true
end

-- Whether Show lets the row show now: in a group, in a group where the player is the leader or an assistant, or anywhere.
function G.Allowed(grouped, lead)
	local show = Opt("show")
	local mode = ns.TestMode
	-- Test mode (TestMode.lua) reads Show as Always while it is on, which is out of combat only: a fight pauses it, and G.Apply lays the secure
	-- buttons out out of combat.
	if show == "always" or (mode ~= nil and mode.IsOn() == true) then
		return true
	end
	return grouped == true and (show ~= "lead" or lead ~= false)
end

-- The places in SPECS of the buttons that show now: none while the module is off, Show does not allow the row or the game made no secure button.
function G.Wanted()
	local list = {}
	if not ns.Enabled(KEY) or G.broken then
		return list
	end
	local grouped, _, lead = G.State()
	if not G.Allowed(grouped, lead) then
		return list
	end
	for index, spec in ipairs(SPECS) do
		if Opt(spec.row) == true then
			list[#list + 1] = index
		end
	end
	return list
end

-- The buttons -------------------------------------------------------------------------------------------------------------------------------

-- The attributes of a secure button; those that end in 2 are for the right button (header). The countdown's macrotext is set by G.Countdown. A
-- marker and the clear act on the player with Shift held and on the focus with Ctrl, either button: the secure marker action reads its unit
-- through SecureButton_GetModifiedUnit (SecureTemplates.lua:118-143, 582-603), which finds shift-unit* and ctrl-unit*, and does nothing for a
-- focus that does not exist (717-718); no modifier leaves the unit to the action, the target.
function G.Attributes(entry)
	if entry.kind == "mark" then
		return { type = "raidtarget", marker = entry.marker, action = "toggle", ["*action2"] = "clear", ["shift-unit*"] = "player", ["ctrl-unit*"] = "focus" }
	elseif entry.kind == "clear" then
		return { type = "raidtarget", action = "clear", ["*action2"] = "clear-all", ["shift-unit*"] = "player", ["ctrl-unit*"] = "focus" }
	elseif entry.kind == "check" then
		return { type = "macro", macrotext = "/readycheck" }
	end
	return { type = "macro", ["*macrotext2"] = "/countdown 0" }
end

-- The icon of a button: a frame of the addon's own with the border and dark background of the icons of IconRow.lua, and its picture inside, or for
-- the countdown its number. Only the icon of the role poll takes the mouse.
function G.Icon(panel, spec)
	local frame = Own(CreateFrame("Frame", nil, panel))
	frame:SetSize(BOX_H, BOX_H)
	local entry = { kind = spec.kind, row = spec.row, group = spec.group, marker = spec.marker, frame = frame, usable = true, hover = false }
	entry.outline = ns.Outline(frame, frame)
	if spec.kind == "pull" then
		local text = ns.OwnText(frame, "OVERLAY", FONT)
		if text then
			text:SetPoint("CENTER", frame, "CENTER", 0, 0)
			text:SetWordWrap(false)
			entry.text = text
		end
	else
		local art = Own(frame:CreateTexture(nil, "ARTWORK", nil, 0))
		art:SetPoint("TOPLEFT", frame, "TOPLEFT", INSET, -INSET)
		art:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -INSET, INSET)
		if spec.kind == "mark" then
			local cell = spec.marker - 1
			local column, line = cell % 4, math.floor(cell / 4)
			art:SetTexture(MARKERS)
			art:SetTexCoord(column * 0.25, column * 0.25 + 0.25, line * 0.25, line * 0.25 + 0.25)
		elseif spec.kind == "clear" then
			art:SetTexture(CLEAR)
		elseif spec.kind == "check" then
			art:SetTexture(READY)
			local tally = ns.OwnText(frame, "OVERLAY", FONT)
			if tally then
				tally:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
				tally:SetWordWrap(false)
				pcall(tally.SetShadowOffset, tally, 1, -1)
				pcall(tally.SetShadowColor, tally, 0, 0, 0, 1)
				entry.tally = tally
			end
		else
			art:SetTexture(ROLES)
			art:SetTexCoord(0, ROLES_CUT, 0, ROLES_CUT)
			-- How many members have no role, in the corner as the ready check's tally (G.RoleCount).
			local count = ns.OwnText(frame, "OVERLAY", FONT)
			if count then
				count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
				count:SetWordWrap(false)
				pcall(count.SetShadowOffset, count, 1, -1)
				pcall(count.SetShadowColor, count, 0, 0, 0, 1)
				count:Hide()
				entry.count = count
			end
		end
		entry.art = art
	end
	-- An icon hidden under the mouse takes its tooltip with it.
	frame:SetScript("OnHide", function()
		ns.Try(KEY, G.Leave, entry)
	end)
	if spec.kind == "roles" then
		G.Plain(entry)
	end
	return entry
end

-- The role poll takes its own click: the left mouse button let go over it after it went down on it, so the click is the player's own.
function G.Plain(entry)
	local frame, down = entry.frame, false
	frame:EnableMouse(true)
	frame:SetScript("OnEnter", function()
		ns.Try(KEY, G.Enter, entry)
	end)
	frame:SetScript("OnLeave", function()
		down = false
		ns.Try(KEY, G.Leave, entry)
	end)
	frame:SetScript("OnMouseDown", function(_, which)
		down = which == "LeftButton"
	end)
	frame:SetScript("OnMouseUp", function(_, which)
		local wanted = down and which == "LeftButton"
		down = false
		if wanted then
			ns.Try(KEY, G.Poll, entry)
		end
	end)
end

-- A click on the role poll asks for one while the player may.
function G.Poll(entry)
	if not Over(entry.frame) then
		return
	end
	local grouped, raid, lead = G.State()
	if G.Usable("roles", grouped, raid, lead) then
		pcall(InitiateRolePoll)
	end
end

-- The secure button over an icon, a child of the row with no picture of its own, above the icon, with the attributes of its action and the hover
-- of the icon under it (as the secure buttons of Reload.lua pass theirs on). Nil when the game made none.
function G.Cover(panel, entry)
	local made, cover = pcall(CreateFrame, "Button", nil, panel, "SecureActionButtonTemplate")
	if not made or type(cover) ~= "table" then
		return nil
	end
	Own(cover)
	local done = pcall(function()
		cover:SetFrameLevel(entry.frame:GetFrameLevel() + 3)
		cover:SetSize(BOX_H, BOX_H)
		cover:EnableMouse(true)
		cover:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		-- The game runs a click on the key press by default (ActionButtonUseKeyDown); the button listens for the release.
		cover:SetAttribute("useOnKeyDown", false)
		for name, value in pairs(G.Attributes(entry)) do
			cover:SetAttribute(name, value)
		end
		cover:SetScript("OnEnter", function()
			ns.Try(KEY, G.Enter, entry)
		end)
		cover:SetScript("OnLeave", function()
			ns.Try(KEY, G.Leave, entry)
		end)
		-- The mouse wheel over the pull button sets Countdown length, out of combat (G.Wheel): an insecure script of the addon's own on its own
		-- button, set once as it is made, out of combat.
		if entry.kind == "pull" then
			cover:EnableMouseWheel(true)
			cover:SetScript("OnMouseWheel", function(_, delta)
				ns.Try(KEY, G.Wheel, entry, delta)
			end)
		end
	end)
	if not done then
		pcall(cover.Hide, cover)
		return nil
	end
	return cover
end

-- The row and its buttons, made the first time the row shows, out of combat. False when the game made no secure button: then nothing shows.
function G.Build()
	if G.panel then
		return true
	elseif G.broken then
		return false
	end
	local panel = Own(CreateFrame("Frame", nil, UIParent))
	panel:SetFrameStrata("LOW")
	panel:SetSize(BOX_W, BOX_H)
	panel:Hide()
	local buttons = {}
	for index, spec in ipairs(SPECS) do
		local entry = G.Icon(panel, spec)
		if spec.kind ~= "roles" then
			entry.cover = G.Cover(panel, entry)
			if not entry.cover then
				G.broken = true
				return false
			end
		end
		buttons[index] = entry
	end
	G.buttons, G.panel = buttons, panel
	return true
end

-- The entry of a kind of button.
function G.Entry(kind)
	for _, entry in ipairs(G.buttons) do
		if entry.kind == kind then
			return entry
		end
	end
	return nil
end

-- Laying out ----------------------------------------------------------------------------------------------------------------------------------

-- Puts the buttons of the list in a row, in a column, or the markers above the rest, each secure button on the very spot of its icon, hides the
-- others and sizes the row to them. A layout already in place is left as it is, as Threat.lua leaves its own: GROUP_ROSTER_UPDATE says nothing
-- of what changed (it has no payload, PartyInfoDocumentation.lua:678-682), and most changes of a group leave the same buttons at the same size.
-- Only the countdown's number is given its height each time, one call: Fonts, which starts after this module at login (MODULE_ORDER in
-- Core.lua), may set the font object of the number again (Fonts.lua:159-194), and a string can take its font object's height back, as it does
-- from a new font object (CombatText.lua:630-631).
function G.Layout(list)
	local size, spacing, layout = Number("size", BOX_H), Number("spacing", 3), Opt("layout")
	local pull = G.Entry("pull")
	if pull and pull.text then
		pull.text:SetTextHeight(math.max(8, math.floor(size / 2 + 0.5)))
	end
	local check = G.Entry("check")
	if check and check.tally then
		check.tally:SetTextHeight(math.max(7, math.floor(size / 3 + 0.5)))
	end
	local roles = G.Entry("roles")
	if roles and roles.count then
		roles.count:SetTextHeight(math.max(7, math.floor(size / 3 + 0.5)))
	end
	local key = ("%s|%s|%s|%s"):format(table.concat(list, ","), size, spacing, tostring(layout))
	if G.laid == key then
		return
	end
	local shown = {}
	local x, y, width, height, last = 0, 0, 0, 0, nil
	for _, index in ipairs(list) do
		local entry = G.buttons[index]
		shown[entry] = true
		if last then
			local apart = last.group ~= entry.group
			if layout == "column" then
				y = y + size + spacing + (apart and GAP or 0)
			elseif layout == "rows" and apart then
				x, y = 0, y + size + spacing
			else
				x = x + size + spacing + (apart and GAP or 0)
			end
		end
		for _, frame in ipairs({ entry.frame, entry.cover }) do
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", G.panel, "TOPLEFT", x, -y)
			frame:SetSize(size, size)
			frame:Show()
		end
		width, height = math.max(width, x + size), math.max(height, y + size)
		last = entry
	end
	for _, entry in ipairs(G.buttons) do
		if not shown[entry] then
			entry.frame:Hide()
			if entry.cover then
				entry.cover:Hide()
			end
		end
	end
	G.panel:SetSize(math.max(1, width), math.max(1, height))
	G.laid = key
end

-- The countdown's button counts down Countdown length, and its number says how long. The attribute and the number are written out of combat
-- only, and only when the length changed.
function G.Countdown()
	local entry = G.Entry("pull")
	if not entry then
		return
	end
	local seconds = Seconds()
	if entry.seconds ~= seconds then
		entry.cover:SetAttribute("macrotext", "/countdown " .. seconds)
		entry.seconds = seconds
		G.PullText(entry)
	end
end

-- The countdown's number: the seconds left in the warm colour while a countdown runs, red for the last LAST_FROM of them, else Countdown length,
-- dim while the button is greyed.
function G.PullText(entry)
	local text = entry and entry.text
	if not text then
		return
	end
	local now = G.ends and Ask(GetTime)
	if now then
		local left = math.max(0, math.floor(G.ends - now + 0.5))
		local colour = left <= LAST_FROM and LAST_RED or WARN
		text:SetText(tostring(left))
		text:SetTextColor(colour[1], colour[2], colour[3], 1)
		return
	end
	text:SetText(tostring(entry.seconds or Seconds()))
	local shade = entry.usable and 1 or 0.6
	text:SetTextColor(shade, shade, shade, 1)
end

-- The mouse wheel over the pull button: Countdown length one second longer (up) or shorter (down), from PULL_LEAST to PULL_MOST, out of combat
-- only (a withheld answer counts as a fight). ns.Set refreshes the module, which writes the macrotext, the number and the tooltip under the
-- mouse again (G.Countdown, G.Paint).
function G.Wheel(entry, delta)
	if Fighting() or IsSecret(delta) or not ns.Finite(delta) or delta == 0 then
		return
	end
	local now = Seconds()
	local seconds = math.max(PULL_LEAST, math.min(PULL_MOST, now + (delta > 0 and 1 or -1)))
	if seconds ~= now then
		ns.Set(KEY .. ".pullTime", seconds)
	end
end

-- Puts the row at the spot of its handle: its top left corner at the top left corner of the box.
function G.Place()
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(MOVER, "TOPLEFT")
	end
	local key = x and ("%.2f:%.2f"):format(x, y) or "start"
	if G.placed == key then
		return
	end
	G.placed = key
	local panel = G.panel
	panel:ClearAllPoints()
	if x then
		panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
	else
		panel:SetPoint("TOPLEFT", UIParent, "TOP", -BOX_W / 2, BOX_Y)
	end
end

-- Lays the row out, places it, sets its countdown and shows it, or hides it. Only out of combat (G.Apply).
function G.Lay()
	local wanted = G.Wanted()
	if #wanted == 0 then
		if G.panel then
			G.panel:Hide()
		end
		return
	end
	if not G.Build() then
		return
	end
	G.Layout(wanted)
	G.Countdown()
	G.ShowTally()
	G.Place()
	G.panel:Show()
	G.fader.Settle()
end

-- A change in a fight waits for its end, once however many come. Should the game still say it is in a fight then, PLAYER_REGEN_ENABLED of the
-- module applies it. A module that stopped in the fight only hides the row.
function G.Queue()
	if G.queued then
		return
	end
	G.queued = true
	ns.OutOfCombat(function()
		if Fighting() then
			return
		end
		G.queued = false
		if ns.IsStopped(KEY) then
			if G.panel then
				pcall(G.panel.Hide, G.panel)
			end
		else
			ns.Try(KEY, G.Apply)
		end
	end)
end

-- What the rows, the group and the spot ask for: the row is laid out out of combat, else when the fight ends, and the greying follows at once.
function G.Apply()
	if Fighting() then
		G.Queue()
	else
		G.Lay()
	end
	G.Paint()
end

-- Drawing ------------------------------------------------------------------------------------------------------------------------------------

-- The background of an icon: the Background colour of the Flat UI page, a little lighter under the mouse while the button can work. The border
-- of a marker takes its colour while Borders in the marker's colour is on, greyed or not, else the general one, as the Ping bar does for its
-- pings (PingBar.lua). The marker your target wears (G.mark) is lit as the Ping bar lights a waiting ping: its colour behind it at LIT_ALPHA
-- and on its border, under the mouse too and whatever Borders in the marker's colour says.
function G.Shade(entry)
	local colour = entry.kind == "mark" and COLOURS[entry.marker] or nil
	local lit = colour ~= nil and entry.marker == G.mark
	if lit then
		ns.SetOutlineFill(entry.outline, colour[1], colour[2], colour[3], LIT_ALPHA)
	elseif entry.hover and entry.usable then
		local r, g, b = ns.Colour("general.backdrop")
		ns.SetOutlineFill(entry.outline, math.min(1, r + LIGHTER), math.min(1, g + LIGHTER), math.min(1, b + LIGHTER), 1)
	else
		ns.SetOutlineFill(entry.outline, nil, nil, nil, nil)
	end
	if colour and (lit or Opt("markColours") ~= false) then
		ns.SetOutlineColour(entry.outline, colour[1], colour[2], colour[3])
	else
		ns.SetOutlineColour(entry.outline, nil, nil, nil)
	end
end

-- Greys the buttons that cannot work now, and writes again the tooltip of the one under the mouse. Only the icons change, which are no secure
-- frames, so this runs in a fight too. A hidden row is left as it is: it shows only in G.Lay, which G.Apply follows with this, so a target
-- changed or a fight ended while it is hidden asks the game only IsShown. IsShown has no restriction, in a fight too, and its answer is secret
-- only for a frame shown with a secret value (SimpleFrameAPIDocumentation.lua:914-926, 1484-1488); a withheld answer paints.
function G.Paint()
	if not G.panel then
		return
	end
	local asked, shown = pcall(G.panel.IsShown, G.panel)
	if asked and not IsSecret(shown) and shown == false then
		return
	end
	local grouped, raid, lead = G.State()
	G.Marked()
	for _, entry in ipairs(G.buttons) do
		local usable, why = G.Usable(entry.kind, grouped, raid, lead)
		entry.usable, entry.why = usable, why
		if entry.art then
			entry.art:SetDesaturated(not usable)
			entry.art:SetAlpha(usable and 1 or GREY_ALPHA)
		end
		if entry.text then
			G.PullText(entry)
		end
		G.Shade(entry)
		if entry.hover and G.Owned(entry) then
			G.Tip(entry)
		end
	end
	G.RoleCount(G.Entry("roles"))
	G.fader.Settle()
end

-- The marker your target wears, from a plain answer of GetRaidTargetIndex only (Ask): a withheld index or none lights nothing. While test mode is on
-- and the target wears none the Skull is lit as a sample (G.markSample), as the Threat list's sample title shows a Skull.
function G.Marked()
	local mark = Ask(GetRaidTargetIndex, "target")
	mark = ns.Finite(mark) and COLOURS[mark] and mark or nil
	G.markSample = mark == nil and Testing()
	G.mark = mark or (G.markSample and SAMPLE_MARK or nil)
end

-- The role poll's count: how many members of the group have no role (a plain NONE of UnitGroupRolesAssigned; a withheld role counts for
-- nothing), in the icon's corner, but only once someone holds a plain tank, healer or damage role, the rule of G.Roles for its "No tank" lines:
-- on Forever most groups pick no role at all, and a number of the whole group would say nothing. It is in the warm colour while the role poll
-- can work, grey (0.6, as G.PullText greys the pull number) while it is greyed, hidden at 0 and out of a group. While test mode is on and
-- nobody holds a role it reads 1, for the sample Kai. G.Paint calls it after the greying, so entry.usable is fresh. Only a FontString of the
-- icon changes, so in a fight too.
function G.RoleCount(entry)
	local count = entry and entry.count
	if not count then
		return
	end
	local none, held = 0, false
	if Truth(IsInGroup) == true then
		for _, unit in ipairs(G.Units()) do
			local role = Ask(UnitGroupRolesAssigned, unit)
			if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
				held = true
			elseif role == "NONE" then
				none = none + 1
			end
		end
	end
	if not held then
		none = Testing() and 1 or 0
	end
	if none > 0 then
		local shade = entry.usable == false and 0.6 or nil
		count:SetText(tostring(none))
		if shade then
			count:SetTextColor(shade, shade, shade, 1)
		else
			count:SetTextColor(WARN[1], WARN[2], WARN[3], 1)
		end
		count:Show()
	else
		count:SetText("")
		count:Hide()
	end
end

local function Tooltip()
	local tip = _G.GameTooltip
	if tip == nil or ns.Forbidden(tip) then
		return nil
	end
	return tip
end

-- Whether GameTooltip is the icon's.
function G.Owned(entry)
	local tip = Tooltip()
	if not tip then
		return false
	end
	local ok, owned = pcall(tip.IsOwned, tip, entry.frame)
	return ok and not IsSecret(owned) and owned == true
end

-- The text of the first key bound to a binding of the game, or nil.
local function KeyText(binding)
	local key = Ask(GetBindingKey, binding)
	if type(key) ~= "string" or key == "" then
		return nil
	end
	local text = Ask(GetBindingText, key)
	return type(text) == "string" and text ~= "" and text or key
end

-- The title and the lines of a button's tooltip. A marker and the clear add the game's own key for them, where one is bound.
function G.Lines(entry)
	if entry.kind == "mark" or entry.kind == "clear" then
		local title, lines, key
		if entry.kind == "mark" then
			title, lines = NAMES[entry.marker], { "Left-click puts it on your target, or takes it off.", "Right-click takes your target's marker off.",
				"Shift-click: on yourself · Ctrl-click: on your focus." }
			key = KeyText("RAIDTARGET" .. entry.marker)
		else
			title, lines = "Clear markers", { "Left-click takes the marker off your target.", "Right-click takes every marker off.",
				"Shift-click takes yours off, Ctrl-click your focus's." }
			key = KeyText("RAIDTARGETNONE")
		end
		if key then
			lines[#lines + 1] = "Key: " .. key
		end
		if entry.kind == "mark" and entry.marker == G.mark then
			lines[#lines + 1] = G.markSample and LIT_SAMPLE or LIT
		end
		return title, lines
	elseif entry.kind == "check" then
		local lines, check = { "Asks everyone in the group whether they are ready." }, G.check
		if check then
			local when = check.sample and "Sample" or (check.over and "Last check" or "Now")
			lines[#lines + 1] = ("%s: %d of %d ready."):format(when, check.ready, check.total)
			if #check.notReady > 0 then
				lines[#lines + 1] = "Not ready: " .. table.concat(check.notReady, ", ")
			end
			if #check.waiting > 0 then
				lines[#lines + 1] = "No answer: " .. table.concat(check.waiting, ", ")
			end
		end
		return "Ready check", lines
	elseif entry.kind == "roles" then
		local lines, warm = G.Roles({ "Asks everyone in the group to pick a role." })
		return "Role poll", lines, warm
	end
	return "Pull countdown", { ("Left-click counts down %d seconds for the group."):format(entry.seconds or Seconds()), "Right-click stops the countdown.",
		"Mouse wheel: longer or shorter, out of combat." }
end

-- Where a tooltip opens: above the row in the lower half of the screen, below it in the upper half (as the data panels have it).
function G.Anchor()
	local ok, _, y = pcall(G.panel.GetCenter, G.panel)
	local okHeight, height = pcall(UIParent.GetHeight, UIParent)
	if ok and okHeight and ns.Finite(y) and ns.Finite(height) and y < height / 2 then
		return "ANCHOR_TOP"
	end
	return "ANCHOR_BOTTOM"
end

-- Writes the tooltip of a button, owned by its icon: what it does, and why it is greyed.
function G.Tip(entry)
	local tip = Tooltip()
	if not tip then
		return
	end
	local title, lines, warm = G.Lines(entry)
	pcall(function()
		tip:SetOwner(entry.frame, G.Anchor())
		tip:SetText(title, 1, 1, 1)
		for index, line in ipairs(lines) do
			local colour = warm and warm[index] and WARN or DIM
			tip:AddLine(line, colour[1], colour[2], colour[3], true)
		end
		if not entry.usable and entry.why then
			tip:AddLine(entry.why, WARN[1], WARN[2], WARN[3], true)
		end
		tip:Show()
	end)
end

function G.Enter(entry)
	entry.hover = true
	G.Wake()
	G.Shade(entry)
	G.Tip(entry)
end

function G.Leave(entry)
	if not entry.hover then
		return
	end
	entry.hover = false
	G.Faint()
	G.Shade(entry)
	if G.Owned(entry) then
		pcall(_G.GameTooltip.Hide, _G.GameTooltip)
	end
end

-- The ready check and the countdown ---------------------------------------------------------------------------------------------------------

-- The units of the group: raid1 to the size of the raid, else the player and party1 to party4. G.Units for the role poll's count, written above.
local function Units()
	local units = {}
	if Truth(IsInRaid) == true then
		local count = Ask(GetNumGroupMembers)
		for index = 1, ns.Finite(count) and math.min(math.floor(count), 40) or 0 do
			units[#units + 1] = "raid" .. index
		end
	else
		units[1] = "player"
		local count = Ask(GetNumSubgroupMembers)
		for index = 1, ns.Finite(count) and math.min(math.floor(count), 4) or 0 do
			units[#units + 1] = "party" .. index
		end
	end
	return units
end
G.Units = Units

-- The roles of the group for the role poll's tooltip, added to lines: who has which role, from plain answers of UnitGroupRolesAssigned and UnitName
-- only (UnitDocumentation.lua:1318-1332; a withheld role or name is left out). In a party a line for each role that has names; in a raid one line
-- of counts, then the names of those with no role, ROLE_NAMES at most. The second answer marks the line of those with no role, written in the
-- warm colour. Out of a group nothing is added, but while test mode is on and the group gives no plain role a sample party's roles are, one of
-- them with no role.
function G.Roles(lines)
	local names, any = { TANK = {}, HEALER = {}, DAMAGER = {}, NONE = {} }, false
	if Truth(IsInGroup) == true then
		for _, unit in ipairs(Units()) do
			local role, name = Ask(UnitGroupRolesAssigned, unit), Ask(UnitName, unit)
			local list = type(role) == "string" and names[role] or nil
			if list and type(name) == "string" and name ~= "" then
				list[#list + 1] = Coloured(unit, name)
				any = true
			end
		end
	end
	if not any then
		if not Testing() then
			return lines, nil
		end
		lines[#lines + 1] = "Sample roles:"
		for _, sample in ipairs(SAMPLE_ROLES) do
			local shown = {}
			for index = 2, #sample do
				shown[#shown + 1] = ClassName(sample[index][1], sample[index][2])
			end
			lines[#lines + 1] = sample[1] .. ": " .. table.concat(shown, ", ")
		end
		return lines, { [#lines] = true }
	end
	local warm = {}
	if Truth(IsInRaid) == true then
		local counts = {}
		for _, role in ipairs(ROLE_WORDS) do
			counts[#counts + 1] = ("%s %d"):format(role[3], #names[role[1]])
		end
		lines[#lines + 1] = table.concat(counts, " · ")
	else
		local held = false
		for _, role in ipairs(ROLE_WORDS) do
			if #names[role[1]] > 0 then
				lines[#lines + 1] = role[2] .. ": " .. table.concat(names[role[1]], ", ")
				held = true
			end
		end
		-- A party where someone holds a role but nobody the tank's or the healer's: that is named, in the warm colour.
		for _, role in ipairs(held and ROLE_WORDS or {}) do
			if role[4] and #names[role[1]] == 0 then
				lines[#lines + 1] = role[4]
				warm[#lines] = true
			end
		end
	end
	local none = names.NONE
	if #none == 0 then
		return lines, next(warm) and warm or nil
	end
	local shown = {}
	for index = 1, math.min(#none, ROLE_NAMES) do
		shown[index] = none[index]
	end
	local line = "No role: " .. table.concat(shown, ", ")
	if #none > ROLE_NAMES then
		line = ("%s and %d more"):format(line, #none - ROLE_NAMES)
	end
	lines[#lines + 1] = line
	warm[#lines] = true
	return lines, warm
end

-- Reads the answers of the ready check that runs: how many are ready of those asked, and the plain names of who is not ready and who has not
-- answered. A unit the game gives no answer for was not asked.
function G.Tally()
	local check = { ready = 0, total = 0, notReady = {}, waiting = {} }
	for _, unit in ipairs(Units()) do
		local status = Ask(GetReadyCheckStatus, unit)
		if status == "ready" or status == "notready" or status == "waiting" then
			check.total = check.total + 1
			local name = Ask(UnitName, unit)
			name = type(name) == "string" and name ~= "" and Coloured(unit, name) or nil
			if status == "ready" then
				check.ready = check.ready + 1
			elseif name then
				local list = status == "notready" and check.notReady or check.waiting
				list[#list + 1] = name
			end
		end
	end
	return check
end

-- Writes the tally on the tick's icon, or clears it, and writes the tooltip again when it is the tick's.
function G.ShowTally()
	local entry = G.Entry("check")
	if not entry then
		return
	end
	local check, tally = G.check, entry.tally
	if tally then
		if check and check.total > 0 then
			local colour = (check.ready == check.total and ALL_READY) or ((#check.notReady > 0 or (check.over and #check.waiting > 0)) and WARN) or nil
			tally:SetText(("%d/%d"):format(check.ready, check.total))
			if colour then
				tally:SetTextColor(colour[1], colour[2], colour[3], 1)
			else
				tally:SetTextColor(1, 1, 1, 1)
			end
			tally:Show()
		else
			tally:SetText("")
			tally:Hide()
		end
	end
	if entry.hover and G.Owned(entry) then
		G.Tip(entry)
	end
end

-- READY_CHECK and READY_CHECK_CONFIRM: the answers so far. The tick flashes as cooldown icons do (IconRow.lua) the moment the last member answers
-- ready: all ready now, not so at the answer before in the same check (an ended check or the sample counts as not).
function G.Checking()
	local was = G.check
	local check = G.Tally()
	G.check = check
	G.Wake()
	G.ShowTally()
	local before = was ~= nil and not was.over and not was.sample and was.total > 0 and was.ready == was.total
	local entry = G.Entry("check")
	if entry and check.total > 0 and check.ready == check.total and not before then
		ns.IconFlash(entry)
	end
end

-- READY_CHECK_FINISHED: the last tally stays, those still waiting now did not answer, and it goes KEEP_TALLY seconds later.
function G.Checked()
	local check = G.check
	if not check then
		return
	end
	check.over = true
	G.ShowTally()
	if not After(KEEP_TALLY, function()
		if G.check == check then
			G.check = nil
			ns.Try(KEY, G.ShowTally)
			ns.Try(KEY, G.Faint)
		end
	end) then
		G.check = nil
		G.ShowTally()
		G.Faint()
	end
end

-- True for a plain timer type of the player countdown.
local function PlayerCountdown(kind)
	if IsSecret(kind) or not ns.Finite(kind) then
		return false
	end
	local enums = type(Enum) == "table" and not IsSecret(Enum) and Enum.StartTimerType or nil
	local value = type(enums) == "table" and enums.PlayerCountdown or nil
	return kind == (ns.Finite(value) and value or PLAYER_COUNTDOWN)
end

-- Stops the countdown's step and gives the number back its length.
function G.CountdownOver()
	G.ends, G.sampleCount = nil, nil
	local ticker = G.ticker
	G.ticker = nil
	if ticker and type(ticker.Cancel) == "function" then
		pcall(ticker.Cancel, ticker)
	end
	G.PullText(G.Entry("pull"))
	G.Faint()
end

-- One step of the countdown: the number, and the end at 0, where the pull button gives the white flash of cooldown icons (IconRow.lua). The sample
-- of test mode flashes too, and starts again from Countdown length while test mode is on.
function G.CountStep()
	local now = Ask(GetTime)
	if not G.ends or not now or G.ends - now < 0.5 then
		local entry = G.ends and now and G.Entry("pull")
		if entry then
			ns.IconFlash(entry)
		end
		if G.sampleCount and now and Testing() then
			G.ends = now + Seconds()
			G.PullText(G.Entry("pull"))
			return
		end
		G.CountdownOver()
		return
	end
	G.PullText(G.Entry("pull"))
end

-- The step of one second of the countdown, where the client has NewTicker.
function G.StartTicker()
	if not G.ticker and type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
		local ok, ticker = pcall(C_Timer.NewTicker, COUNT_STEP, function()
			ns.Try(KEY, G.CountStep)
		end)
		G.ticker = ok and ticker or nil
	end
end

-- START_TIMER: a player countdown counts on the pull button, once a second until it ends.
function G.TimerStarted(kind, remaining)
	if not PlayerCountdown(kind) then
		return
	end
	local now = Ask(GetTime)
	if IsSecret(remaining) or not ns.Finite(remaining) or remaining <= 0 or not now then
		G.CountdownOver()
		return
	end
	G.ends, G.sampleCount = now + remaining, nil
	G.Wake()
	G.StartTicker()
	-- With no ticker the number shows the length the countdown started with, until it ends.
	if not G.ticker then
		local ends = G.ends
		After(remaining, function()
			if G.ends == ends then
				ns.Try(KEY, G.CountdownOver)
			end
		end)
	end
	G.PullText(G.Entry("pull"))
end

-- STOP_TIMER_OF_TYPE: a stopped player countdown.
function G.TimerStopped(kind)
	if PlayerCountdown(kind) then
		G.CountdownOver()
	end
end

-- Test mode on: a sample tally on the tick (4/5, a sample member not ready, in the warm colour) and a sample countdown on the pull button,
-- shown only, no /countdown sent, from Countdown length again and again. A real ready check or countdown replaces them, as it sets G.check and
-- G.ends. Only FontStrings of the icons change.
function G.SampleOn()
	if not G.check then
		G.check = { ready = SAMPLE_READY, total = SAMPLE_TOTAL, notReady = { ClassName(SAMPLE_NAME, SAMPLE_CLASS) }, waiting = {}, over = false, sample = true }
	end
	G.ShowTally()
	local now = Ask(GetTime)
	if not G.ends and now then
		G.ends, G.sampleCount = now + Seconds(), true
		G.StartTicker()
		if not G.ticker then
			G.ends, G.sampleCount = nil, nil
		end
		G.PullText(G.Entry("pull"))
	end
	G.Paint()
end

-- Test mode off or paused: the samples go, a real check or countdown stays.
function G.SampleOff()
	if G.check and G.check.sample then
		G.check = nil
	end
	if G.sampleCount then
		G.CountdownOver()
	end
	G.ShowTally()
	G.Paint()
end

-- Fade until you point at it -------------------------------------------------------------------------------------------------------------

-- True while the icons stay full: the row off, the mouse over a button, a real ready check or its tally, or a real countdown. The samples of test
-- mode hold nothing, so Fade until you point at it can be tried there, where a player in no group sees the row.
function G.Held()
	if Opt("fade") ~= true then
		return true
	end
	for _, entry in ipairs(G.buttons) do
		if entry.hover then
			return true
		end
	end
	local check = G.check
	return (check ~= nil and not check.sample and ns.Finite(check.total) and check.total > 0) or (G.ends ~= nil and not G.sampleCount)
end

G.fader = ns.IconFader(function()
	return G.buttons
end, G.Held)

-- Full at once; faint a second after nothing holds the icons full; or at once as G.Held says, after a layout or a paint.
function G.Wake()
	G.fader.Wake()
end

function G.Faint()
	G.fader.Faint()
end

-- The module ---------------------------------------------------------------------------------------------------------------------------------

function G.Refresh()
	G.placed, G.laid = nil, nil
	G.Apply()
end

-- The end of a fight: a change that still waits is applied, should the game have said it was in a fight when ns.OutOfCombat ran it.
function G.AfterFight()
	if G.queued and not Fighting() then
		G.queued = false
		G.Apply()
	else
		G.Paint()
	end
end

function G.Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	if G.broken then
		lines[#lines + 1] = LINE_BROKEN
	end
	if G.queued then
		lines[#lines + 1] = LINE_WAITING
	end
	return lines
end

-- The movers -----------------------------------------------------------------------------------------------------------------------------------

-- True while the row has a handle in the movers: while the module is on, shown or not.
function ns.GroupToolsShown()
	return ns.Enabled(KEY)
end

-- The movers set or put back the spot: the row moves there out of combat.
function ns.GroupToolsMoved()
	G.placed = nil
	if G.panel and ns.Enabled(KEY) then
		ns.Try(KEY, G.Apply)
	end
end

ns.Register(KEY, {
	label = "Group tools",
	counted = false,
	Start = G.Refresh,
	Refresh = G.Refresh,
	Resized = G.Refresh,
	Status = G.Status,
	-- The group or its leader changed, or a loading screen ended: the row shows or hides and the greying follows. The target and its marker
	-- change only that and the lit marker.
	events = {
		GROUP_ROSTER_UPDATE = G.Apply,
		PARTY_LEADER_CHANGED = G.Apply,
		PLAYER_ENTERING_WORLD = G.Apply,
		PLAYER_TARGET_CHANGED = G.Paint,
		RAID_TARGET_UPDATE = G.Paint,
		PARTY_LFG_RESTRICTED = G.Paint,
		-- A role changed: the role poll's tooltip under the mouse lists the new roles.
		PLAYER_ROLES_ASSIGNED = G.Paint,
		PLAYER_REGEN_ENABLED = G.AfterFight,
		-- A ready check and its answers, and a countdown started or stopped: only the FontStrings of the icons change.
		READY_CHECK = G.Checking,
		READY_CHECK_CONFIRM = G.Checking,
		READY_CHECK_FINISHED = G.Checked,
		START_TIMER = G.TimerStarted,
		STOP_TIMER_OF_TYPE = G.TimerStopped,
		-- A key changed: the tooltip under the mouse names the new one.
		UPDATE_BINDINGS = G.Paint,
	},
})

-- Test mode: On, Off and a pause refresh the page, which shows the row or puts it back to its own Show rule (G.Allowed), out of combat or once the
-- fight ends (G.Apply); On shows the sample tally and countdown (G.SampleOn), Off and a pause take them away.
if ns.TestMode then
	ns.TestMode.Register("grouptools", { module = KEY, label = "Group tools", refresh = true, Start = G.SampleOn, Stop = G.SampleOff })
end
