local _, ns = ...

local KEY = "grouptools"
local MOVER = "FlatUIGroupTools"
local BOX_W, BOX_H, BOX_Y = 327, 24, -100
local GAP, INSET = 6, 2
local FONT = "GameFontHighlightSmall"
local DIM = { 0.66, 0.68, 0.62 }
local WARN = { 0.9, 0.72, 0.36 }
local ALL_READY = { 0.4, 0.9, 0.4 }
local KEEP_TALLY, COUNT_STEP, GO_TIME = 8, 1, 1.5
local LAST_RED, LAST_FROM = { 1, 0.3, 0.3 }, 3
local PULL_LEAST, PULL_MOST = 3, 60
local PLAYER_COUNTDOWN = 2
local GREY_ALPHA = 0.4
local LIGHTER = 0.17
local MARKERS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local CLEAR = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local READY = "Interface\\RaidFrame\\ReadyCheck-Ready"
local ROLES = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES"
local ROLES_CUT = 134 / 256
local NAMES = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
local COLOURS = {
	{ 1, 0.92, 0 }, { 0.98, 0.57, 0 }, { 0.83, 0.22, 0.9 }, { 0.04, 0.95, 0 },
	{ 0.7, 0.82, 0.875 }, { 0, 0.71, 1 }, { 1, 0.24, 0.168 }, { 0.98, 0.98, 0.98 },
}
local SAMPLE_READY, SAMPLE_TOTAL, SAMPLE_NAME, SAMPLE_CLASS = 4, 5, "Eli", "PRIEST"
local SAMPLE_WAIT, SAMPLE_ALL = 6, 4
local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
local LIT_ALPHA, SAMPLE_MARK = 0.35, 8
local LIT = "On your target now: a left-click takes it off."
local LIT_SAMPLE = "Sample: lit as it is when your target wears it."
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

local SPECS = {}
for marker = 8, 1, -1 do
	SPECS[#SPECS + 1] = { kind = "mark", row = "marks", group = 1, marker = marker }
end
SPECS[#SPECS + 1] = { kind = "clear", row = "marks", group = 1 }
SPECS[#SPECS + 1] = { kind = "check", row = "readyCheck", group = 2 }
SPECS[#SPECS + 1] = { kind = "roles", row = "rolePoll", group = 2 }
SPECS[#SPECS + 1] = { kind = "pull", row = "pull", group = 2 }

local IsSecret = ns.IsSecret
local G = { buttons = {}, queued = false, broken = false }
ns.GroupTools = G

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

local function Seconds()
	return math.floor(Number("pullTime", 10))
end

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

local function After(seconds, fn)
	return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, seconds, fn)
end

local function Either(a, b)
	if a == true or b == true then
		return true
	elseif a == false and b == false then
		return false
	end
	return nil
end

local function Fighting()
	local ok, fighting = pcall(InCombatLockdown)
	return ok and (IsSecret(fighting) or fighting == true)
end

local function Over(frame)
	local ok, over = pcall(frame.IsMouseOver, frame)
	return not ok or IsSecret(over) or over ~= false
end

local function Testing()
	local mode = ns.TestMode
	return mode ~= nil and mode.IsOn() == true
end

local function Hex(r, g, b)
	local function Byte(value)
		return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5)
	end
	return ("|cff%02x%02x%02x"):format(Byte(r), Byte(g), Byte(b))
end

local function Coloured(unit, name)
	local r, g, b = ns.ClassColourOf(unit)
	return r and (Hex(r, g, b) .. name .. "|r") or name
end

local function ClassName(name, class)
	local colours = RAID_CLASS_COLORS
	local colour = type(colours) == "table" and not IsSecret(colours) and colours[class] or nil
	if type(colour) == "table" and not IsSecret(colour) and ns.Finite(colour.r) and ns.Finite(colour.g) and ns.Finite(colour.b) then
		return Hex(colour.r, colour.g, colour.b) .. name .. "|r"
	end
	return name
end

function G.State()
	local grouped, raid = Truth(IsInGroup), Truth(IsInRaid)
	local lead = Either(Truth(UnitIsGroupLeader, "player"), Truth(UnitIsGroupAssistant, "player"))
	if raid == true and lead ~= true then
		lead = Either(lead, Truth(IsEveryoneAssistant))
	end
	return grouped, raid, lead
end

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

function G.Allowed(grouped, lead)
	local show = Opt("show")
	local mode = ns.TestMode
	if show == "always" or (mode ~= nil and mode.IsOn() == true) then
		return true
	end
	return grouped == true and (show ~= "lead" or lead ~= false)
end

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

function G.Attributes(entry)
	if entry.kind == "mark" then
		return { type = "raidtarget", marker = entry.marker, action = "toggle", ["*action2"] = "clear", ["shift-unit*"] = "player", ["ctrl-unit*"] = "focus" }
	elseif entry.kind == "clear" then
		return { type = "raidtarget", action = "clear", ["*action2"] = "clear-all", ["shift-action2"] = "clear", ["ctrl-action2"] = "clear",
			["shift-unit*"] = "player", ["ctrl-unit*"] = "focus" }
	elseif entry.kind == "check" then
		return { type = "macro", macrotext = "/readycheck" }
	end
	return { type = "macro", ["*macrotext2"] = "/countdown 0" }
end

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
	frame:SetScript("OnHide", function()
		ns.Try(KEY, G.Leave, entry)
	end)
	if spec.kind == "roles" then
		G.Plain(entry)
	end
	return entry
end

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

function G.Poll(entry)
	if not Over(entry.frame) then
		return
	end
	local grouped, raid, lead = G.State()
	if G.Usable("roles", grouped, raid, lead) then
		pcall(InitiateRolePoll)
	end
end

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

function G.Entry(kind)
	for _, entry in ipairs(G.buttons) do
		if entry.kind == kind then
			return entry
		end
	end
	return nil
end

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

function G.PullText(entry)
	local text = entry and entry.text
	if not text then
		return
	end
	if G.goUntil then
		local now = Ask(GetTime)
		if ns.Finite(now) and now < G.goUntil then
			text:SetText("Go")
			text:SetTextColor(ALL_READY[1], ALL_READY[2], ALL_READY[3], 1)
			return
		end
		G.goUntil = nil
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

function G.Apply()
	if Fighting() then
		G.Queue()
	else
		G.Lay()
	end
	G.Paint()
end

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

function G.Marked()
	local mark = Ask(GetRaidTargetIndex, "target")
	mark = ns.Finite(mark) and COLOURS[mark] and mark or nil
	G.markSample = mark == nil and Testing()
	G.mark = mark or (G.markSample and SAMPLE_MARK or nil)
end

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

function G.Owned(entry)
	local tip = Tooltip()
	if not tip then
		return false
	end
	local ok, owned = pcall(tip.IsOwned, tip, entry.frame)
	return ok and not IsSecret(owned) and owned == true
end

local function KeyText(binding)
	local key = Ask(GetBindingKey, binding)
	if type(key) ~= "string" or key == "" then
		return nil
	end
	local text = Ask(GetBindingText, key)
	return type(text) == "string" and text ~= "" and text or key
end

function G.Lines(entry)
	if entry.kind == "mark" or entry.kind == "clear" then
		local title, lines, key
		if entry.kind == "mark" then
			title, lines = NAMES[entry.marker], { "Left-click puts it on your target, or takes it off.", "Right-click takes your target's marker off.",
				"Shift-click: on yourself · Ctrl-click: on your focus." }
			key = KeyText("RAIDTARGET" .. entry.marker)
		else
			title, lines = "Clear markers", { "Left-click takes the marker off your target.", "Right-click takes every marker off.",
				"Shift-click takes yours off, Ctrl-click your focus's, with either button." }
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

function G.Anchor()
	local ok, _, y = pcall(G.panel.GetCenter, G.panel)
	local okHeight, height = pcall(UIParent.GetHeight, UIParent)
	if ok and okHeight and ns.Finite(y) and ns.Finite(height) and y < height / 2 then
		return "ANCHOR_TOP"
	end
	return "ANCHOR_BOTTOM"
end

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

local NOBODY = "Nobody has picked a role yet."

function G.Roles(lines)
	local names, any, held = { TANK = {}, HEALER = {}, DAMAGER = {}, NONE = {} }, false, false
	local grouped = Truth(IsInGroup) == true
	if grouped then
		for _, unit in ipairs(Units()) do
			local role, name = Ask(UnitGroupRolesAssigned, unit), Ask(UnitName, unit)
			if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
				held = true
			end
			local list = type(role) == "string" and names[role] or nil
			if list and type(name) == "string" and name ~= "" then
				list[#list + 1] = Coloured(unit, name)
				any = true
			end
		end
	end
	if not held or not any then
		if not Testing() then
			if grouped and not held and #names.NONE > 0 then
				lines[#lines + 1] = NOBODY
			end
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

function G.AllReady(entry, sample)
	ns.IconFlash(entry)
	local sound = ns.SOUNDS[KITS[Opt("readySound")] or 0]
	local mode = ns.TestMode
	if sound and (not sample or (mode ~= nil and mode.Sound("grouptools.ready"))) then
		ns.PlayKit(sound[1], KEY)
	end
end

function G.Checking()
	local was = G.check
	local check = G.Tally()
	G.check = check
	G.Wake()
	G.ShowTally()
	local before = was ~= nil and not was.over and not was.sample and was.total > 0 and was.ready == was.total
	local entry = G.Entry("check")
	if entry and check.total > 0 and check.ready == check.total and not before then
		G.AllReady(entry, false)
	end
end

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

local function PlayerCountdown(kind)
	if IsSecret(kind) or not ns.Finite(kind) then
		return false
	end
	local enums = type(Enum) == "table" and not IsSecret(Enum) and Enum.StartTimerType or nil
	local value = type(enums) == "table" and enums.PlayerCountdown or nil
	return kind == (ns.Finite(value) and value or PLAYER_COUNTDOWN)
end

function G.CountdownOver()
	G.ends, G.sampleCount, G.goUntil = nil, nil, nil
	local ticker = G.ticker
	G.ticker = nil
	if ticker and type(ticker.Cancel) == "function" then
		pcall(ticker.Cancel, ticker)
	end
	G.PullText(G.Entry("pull"))
	G.Faint()
end

local function Frozen()
	local mode = ns.TestMode
	return mode ~= nil and type(mode.Moving) == "function" and mode.Moving() == false
end

function G.CountStep()
	local now = Ask(GetTime)
	if G.sampleCount and G.ends and Frozen() then
		G.ends = G.ends + COUNT_STEP
		return
	end
	if not G.ends or not now or G.ends - now < 0.5 then
		local entry = G.ends and now and G.Entry("pull")
		if entry then
			ns.IconFlash(entry)
		end
		if G.sampleCount and now and Testing() then
			G.ends, G.goUntil = now + Seconds() + COUNT_STEP, now + 0.9 * COUNT_STEP
			G.PullText(G.Entry("pull"))
			return
		end
		G.CountdownOver()
		if entry then
			local mark = now + GO_TIME
			G.goUntil = mark
			G.PullText(entry)
			After(GO_TIME, function()
				if G.goUntil == mark then
					G.goUntil = nil
					ns.Try(KEY, G.PullText, G.Entry("pull"))
				end
			end)
		end
		return
	end
	G.PullText(G.Entry("pull"))
end

function G.StartTicker()
	if not G.ticker and type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
		local ok, ticker = pcall(C_Timer.NewTicker, COUNT_STEP, function()
			ns.Try(KEY, G.CountStep)
		end)
		G.ticker = ok and ticker or nil
	end
end

function G.TimerStarted(kind, remaining)
	if not PlayerCountdown(kind) then
		return
	end
	local now = Ask(GetTime)
	if IsSecret(remaining) or not ns.Finite(remaining) or remaining <= 0 or not now then
		G.CountdownOver()
		return
	end
	G.ends, G.sampleCount, G.goUntil = now + remaining, nil, nil
	G.Wake()
	G.StartTicker()
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

function G.TimerStopped(kind)
	if PlayerCountdown(kind) and not (G.goUntil and not G.ends) then
		G.CountdownOver()
	end
end

function G.SampleOn()
	if not G.check then
		G.check = { ready = SAMPLE_READY, total = SAMPLE_TOTAL, notReady = { ClassName(SAMPLE_NAME, SAMPLE_CLASS) }, waiting = {}, over = false, sample = true }
		G.sampleFrom = Ask(GetTime)
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

function G.SampleTick()
	local check, now = G.check, Ask(GetTime)
	if not (check and check.sample) or not ns.Finite(now) or not ns.Finite(G.sampleFrom) or now < G.sampleFrom then
		return
	end
	local all = math.floor(now - G.sampleFrom) % (SAMPLE_WAIT + SAMPLE_ALL) >= SAMPLE_WAIT
	if all == (check.ready == check.total) then
		return
	end
	check.ready = all and SAMPLE_TOTAL or SAMPLE_READY
	check.notReady = all and {} or { ClassName(SAMPLE_NAME, SAMPLE_CLASS) }
	G.ShowTally()
	local entry = G.Entry("check")
	if all and entry then
		G.AllReady(entry, true)
	end
end

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

function G.Wake()
	G.fader.Wake()
end

function G.Faint()
	G.fader.Faint()
end

function G.Refresh()
	G.placed, G.laid = nil, nil
	G.Apply()
end

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

function ns.GroupToolsShown()
	return ns.Enabled(KEY)
end

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
	events = {
		GROUP_ROSTER_UPDATE = G.Apply,
		PARTY_LEADER_CHANGED = G.Apply,
		PLAYER_ENTERING_WORLD = G.Apply,
		PLAYER_TARGET_CHANGED = G.Paint,
		RAID_TARGET_UPDATE = G.Paint,
		PARTY_LFG_RESTRICTED = G.Paint,
		PLAYER_ROLES_ASSIGNED = G.Paint,
		PLAYER_REGEN_ENABLED = G.AfterFight,
		READY_CHECK = G.Checking,
		READY_CHECK_CONFIRM = G.Checking,
		READY_CHECK_FINISHED = G.Checked,
		START_TIMER = G.TimerStarted,
		STOP_TIMER_OF_TYPE = G.TimerStopped,
		UPDATE_BINDINGS = G.Paint,
	},
})

if ns.TestMode then
	ns.TestMode.Register("grouptools", { module = KEY, label = "Group tools", refresh = true, Start = G.SampleOn, Stop = G.SampleOff, every = 1,
		Tick = G.SampleTick })
end
