local _, ns = ...

local KEY = "pingbar"
local MOVER = "FlatUIPingBar"
local PLACE = "FlatUIPingPlace"
local BOX_W, BOX_H, BOX_Y = 132, 24, -130
local INSET = 2
local FONT = "GameFontHighlightSmall"
local HINT_FONT = "GameFontHighlight"
local HINT_GAP = 6
local HINT = "%s: click where to ping · click it again, right-click or Esc to cancel"
local DIM = { 0.66, 0.68, 0.62 }
local WARN = { 0.9, 0.72, 0.36 }
local GREY_ALPHA = 0.4
local LIGHTER = 0.17
local ARMED_ALPHA = 0.35
local AFTER_PRESS, GIVE_UP = 0.1, 10
local SAMPLE = 3
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
local KEYS_ONLY = { Attack = 1, Warning = 2, OnMyWay = 3, Assist = 4 }
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

local function After(seconds, fn)
	return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, seconds, fn)
end

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

local function EnumValue(group, name, fallback)
	local enums = Api("Enum")
	local values = enums and enums[group]
	local value = type(values) == "table" and values[name] or nil
	if ns.Finite(value) then
		return value
	end
	return fallback
end

local function Name(kind)
	local text = kind.global and _G[kind.global] or nil
	if type(text) == "string" and not IsSecret(text) and text ~= "" then
		return text
	end
	return kind.name
end

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

local function KindOf(value)
	for index, kind in ipairs(KINDS) do
		if kind.enum and EnumValue("PingSubjectType", kind.enum, kind.value) == value then
			return index
		end
	end
	return nil
end

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
local CLEAR = [=[
self:ClearBindings()
]=]

function P.Macro(kind, units)
	local line = units and ("/ping " .. units) or "/ping"
	if kind.word then
		return ("%s %s"):format(line, kind.word)
	end
	return line
end

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
		cover:RegisterForClicks("LeftButtonUp")
		cover:SetAttribute("useOnKeyDown", false)
		cover:SetAttribute("flatui-kind", entry.kind.id)
		cover:SetScript("OnEnter", function()
			ns.Try(KEY, P.Enter, entry)
		end)
		cover:SetScript("OnLeave", function()
			ns.Try(KEY, P.Leave, entry)
		end)
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

function P.Key(kind)
	local made, key = pcall(CreateFrame, "Button", "FlatUIPing" .. kind.id, UIParent, "SecureActionButtonTemplate")
	if not made or type(key) ~= "table" or IsSecret(key) then
		return nil
	end
	Own(key)
	local done = pcall(function()
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

function P.Cancel()
	if P.place and not Fighting() then
		pcall(P.place.Hide, P.place)
	end
end

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
			if entry.armed then
				P.Cancel()
			end
		end
	end
	P.panel:SetSize(math.max(1, width), math.max(1, height))
	P.laid = key
end

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

function P.Apply()
	if Fighting() then
		P.Queue()
	else
		P.Lay()
	end
	P.Paint()
end

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

function P.ReadCooldown()
	if not P.panel or Opt("cooldown") == false then
		return
	end
	local start, length = P.Cooldown()
	if start then
		P.Swipe(start, length)
	end
end

function P.Pressed()
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, AFTER_PRESS, function()
		ns.Try(KEY, P.ReadCooldown)
	end) then
		return
	end
	P.ReadCooldown()
end

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

local function KeyText(binding)
	local key = Ask(GetBindingKey, binding)
	if type(key) ~= "string" or key == "" then
		return nil
	end
	local text = Ask(GetBindingText, key)
	return type(text) == "string" and text ~= "" and text or key
end

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

function P.Retip()
	P.KeyLabels()
	for _, entry in ipairs(P.buttons) do
		if entry.hover and P.Owned(entry) then
			P.Tip(entry)
		end
	end
end

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

function P.Wake()
	P.fader.Wake()
end

function P.Faint()
	P.fader.Faint()
end

function P.Refresh()
	P.placed, P.laid = nil, nil
	if not ns.Enabled(KEY) and P.panel then
		P.Swipe(nil)
	end
	P.Apply()
	P.KeyLabels()
end

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

function ns.PingBarShown()
	return ns.Enabled(KEY)
end

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

if ns.TestMode then
	ns.TestMode.Register("pingbar", { module = KEY, label = "Ping bar", refresh = true, Start = P.Sample })
end
