local _, ns = ...

-- Group tools: a row of buttons of Flat UI's own for a group, the eight raid markers and a clear for your target, a ready check, a role poll
-- and a pull countdown, drawn as the icons of IconRow.lua are: square, with a thin border on a dark background. A module of its own, off by
-- default, whose page is in the Combat group. The row shows in a group, or as Show says, and /flatui move places it (FlatUIGroupTools in
-- Movers.lua: the top left corner of the row is the top left corner of the box). No frame or setting of the game is changed.
--
-- What the game allows. SetRaidTarget, RemoveRaidTargets, C_PartyInfo.DoReadyCheck and C_PartyInfo.DoCountdown have restrictions
-- (HasRestrictions: RaidMarkersDocumentation.lua:108-124, PartyInfoDocumentation.lua:156-174), so they run only in the secure click of a button
-- of Flat UI's own made from SecureActionButtonTemplate, where the game's own secure code makes the call. A marker is of the type raidtarget,
-- which toggles the marker on the target, and with the action clear or clear-all takes it off the target or off every unit
-- (Blizzard_FrameXML/SecureTemplates.lua:582-603). The ready check and the countdown are of the type macro, whose macrotext the game runs
-- (SecureTemplates.lua:450-463) with its own /readycheck, which does nothing for a member who is neither the leader nor an assistant, and
-- /countdown (Blizzard_ChatFrameBase/Shared/SlashCommands.lua:1275-1279, 1666-1672); /countdown 0 stops a countdown, as
-- EnhanceQoLDungeonRaid/Init.lua:440 stops one. The right button reads the attributes that end in 2, with any key held (SecureTemplates.lua:
-- 101-133), so a right-click takes the marker off your target, every marker with the clear, and stops the countdown. A secure button listens for
-- the release of the mouse button (useOnKeyDown false, SecureTemplates.lua:792-800), as those of Reload.lua do. InitiateRolePoll has no
-- restriction (UnitRoleDocumentation.lua:29-36) and the game's own buttons call it from a plain click (Mainline/
-- Blizzard_CompactRaidFrameManager.lua:1435-1438, Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_Listing.lua:626-629), so the role poll
-- is a plain button of Flat UI's own, clicked when the left mouse button comes up over it after going down on it, as Errands.Button is.
-- The secure buttons hold no picture and lie over icons of Flat UI's own, as the secure button of Reload.lua lies over its flat button, so an
-- icon can be greyed in a fight while its secure button is not touched. The secure buttons make the frame of the row protected, so the row and
-- its buttons are made, placed, sized, shown, hidden and given attributes only out of combat: a change in a fight (a group joined, a row of the
-- page changed, the row moved) waits for its end (ns.OutOfCombat), and in a fight nothing on them changes. Nothing of the module runs but on
-- its events and the mouse; no ticker and no OnUpdate.
-- A button that cannot work for the player now is greyed, as the game's own group manager decides (Mainline/
-- Blizzard_CompactRaidFrameManager.lua:601-645, 698, 1263): a marker without a target the game lets be marked (CanBeRaidTarget), and every
-- marker and the clear in a raid unless the player is its leader or an assistant or everyone is; the ready check, the role poll and the
-- countdown out of a group or unless the player is the leader or an assistant; the role poll also in a group the dungeon finder made
-- (HasLFGRestrictions) and in a battleground. An answer the game withholds (UnitIsGroupLeader and UnitIsGroupAssistant may be secret,
-- UnitDocumentation.lua:2023-2055) greys nothing and is not read: the click lets the game decide, and the game refuses what it does not allow.
-- The greying follows the group, its leader and the target (GROUP_ROSTER_UPDATE, PARTY_LEADER_CHANGED, PARTY_LFG_RESTRICTED:
-- PartyInfoDocumentation.lua:680, 784, 790; PLAYER_TARGET_CHANGED: UnitDocumentation.lua:3976). Pointing at a button writes its lines in
-- GameTooltip (SetOwner on the icon, SetText, AddLine, Show, and Hide when the mouse leaves), as the data panels do.
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
-- The markers by index, the game's RAID_TARGET_1 to RAID_TARGET_8.
local NAMES = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
local NO_TARGET = "You have no target."
local NO_MARK = "Your target cannot be marked."
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
-- number), outline, cover (the secure button over the icon; none for the role poll), usable, why, hover, seconds }. placed: the spot the row
-- was put at. queued: a change waits for the end of a fight. broken: the game made no secure button.
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
	if show == "always" then
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

-- The attributes of a secure button; those that end in 2 are for the right button (header). The countdown's macrotext is set by G.Countdown.
function G.Attributes(entry)
	if entry.kind == "mark" then
		return { type = "raidtarget", marker = entry.marker, action = "toggle", ["*action2"] = "clear" }
	elseif entry.kind == "clear" then
		return { type = "raidtarget", action = "clear", ["*action2"] = "clear-all" }
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
		else
			art:SetTexture(ROLES)
			art:SetTexCoord(0, ROLES_CUT, 0, ROLES_CUT)
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
-- others and sizes the row to them.
function G.Layout(list)
	local size, spacing, layout = Number("size", BOX_H), Number("spacing", 3), Opt("layout")
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
	local pull = G.Entry("pull")
	if pull and pull.text then
		pull.text:SetTextHeight(math.max(8, math.floor(size / 2 + 0.5)))
	end
end

-- The countdown's button counts down Countdown length, and its number says how long. The attribute is written out of combat only, and only when
-- the length changed.
function G.Countdown()
	local entry = G.Entry("pull")
	if not entry then
		return
	end
	local seconds = Seconds()
	if entry.seconds ~= seconds then
		entry.cover:SetAttribute("macrotext", "/countdown " .. seconds)
		entry.seconds = seconds
	end
	if entry.text then
		entry.text:SetText(tostring(seconds))
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
	G.Place()
	G.panel:Show()
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

-- The background of an icon: the Background colour of the Flat UI page, a little lighter under the mouse while the button can work.
function G.Shade(entry)
	if entry.hover and entry.usable then
		local r, g, b = ns.Colour("general.backdrop")
		ns.SetOutlineFill(entry.outline, math.min(1, r + LIGHTER), math.min(1, g + LIGHTER), math.min(1, b + LIGHTER), 1)
	else
		ns.SetOutlineFill(entry.outline, nil, nil, nil, nil)
	end
end

-- Greys the buttons that cannot work now, and writes again the tooltip of the one under the mouse. Only the icons change, which are no secure
-- frames, so this runs in a fight too.
function G.Paint()
	if not G.panel then
		return
	end
	local grouped, raid, lead = G.State()
	for _, entry in ipairs(G.buttons) do
		local usable, why = G.Usable(entry.kind, grouped, raid, lead)
		entry.usable, entry.why = usable, why
		if entry.art then
			entry.art:SetDesaturated(not usable)
			entry.art:SetAlpha(usable and 1 or GREY_ALPHA)
		end
		if entry.text then
			local shade = usable and 1 or 0.6
			entry.text:SetTextColor(shade, shade, shade, 1)
		end
		G.Shade(entry)
		if entry.hover and G.Owned(entry) then
			G.Tip(entry)
		end
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

-- The title and the lines of a button's tooltip.
function G.Lines(entry)
	if entry.kind == "mark" then
		return NAMES[entry.marker], { "Left-click puts it on your target, or takes it off.", "Right-click takes your target's marker off." }
	elseif entry.kind == "clear" then
		return "Clear markers", { "Left-click takes the marker off your target.", "Right-click takes every marker off." }
	elseif entry.kind == "check" then
		return "Ready check", { "Asks everyone in the group whether they are ready." }
	elseif entry.kind == "roles" then
		return "Role poll", { "Asks everyone in the group to pick a role." }
	end
	return "Pull countdown", { ("Left-click counts down %d seconds for the group."):format(entry.seconds or Seconds()), "Right-click stops the countdown." }
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
	local title, lines = G.Lines(entry)
	pcall(function()
		tip:SetOwner(entry.frame, G.Anchor())
		tip:SetText(title, 1, 1, 1)
		for _, line in ipairs(lines) do
			tip:AddLine(line, DIM[1], DIM[2], DIM[3], true)
		end
		if not entry.usable and entry.why then
			tip:AddLine(entry.why, WARN[1], WARN[2], WARN[3], true)
		end
		tip:Show()
	end)
end

function G.Enter(entry)
	entry.hover = true
	G.Shade(entry)
	G.Tip(entry)
end

function G.Leave(entry)
	if not entry.hover then
		return
	end
	entry.hover = false
	G.Shade(entry)
	if G.Owned(entry) then
		pcall(_G.GameTooltip.Hide, _G.GameTooltip)
	end
end

-- The module ---------------------------------------------------------------------------------------------------------------------------------

function G.Refresh()
	G.placed = nil
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
	-- The group or its leader changed, or a loading screen ended: the row shows or hides and the greying follows. The target changes only that.
	events = {
		GROUP_ROSTER_UPDATE = G.Apply,
		PARTY_LEADER_CHANGED = G.Apply,
		PLAYER_ENTERING_WORLD = G.Apply,
		PLAYER_TARGET_CHANGED = G.Paint,
		PARTY_LFG_RESTRICTED = G.Paint,
		PLAYER_REGEN_ENABLED = G.AfterFight,
	},
})
