local _, ns = ...

local G = { recs = {} }
ns.ChargesGame = G

local SLOT_ICON, SLOT_ORB = "icon", "orb"
local NUMBER_SHOWN, NUMBER_HIDDEN = "%d", " "

local IsSecret = ns.IsSecret
local L = ns.ChargesLook
local Own = L.Own

local function Charges()
	return ns.Charges
end

function G.TimeOptions()
	if G.timeOptions == nil then
		local ok, options = pcall(function()
			local amber = L.AMBER
			local curve = C_CurveUtil.CreateColorCurve()
			curve:SetType(Enum.LuaCurveType.Step)
			curve:AddPoint(0, CreateColor(amber[1], amber[2], amber[3], 1))
			curve:AddPoint(L.LOW, CreateColor(1, 1, 1, 1))
			return { textColor = { curve = curve, property = Enum.DurationTextBindingProperty.RemainingDuration } }
		end)
		G.timeOptions = ok and type(options) == "table" and options or false
	end
	return G.timeOptions or nil
end

function G.Formatter(always)
	local key = always and "always" or "over"
	if G.formatters[key] == nil then
		local call = type(C_StringUtil) == "table" and C_StringUtil.CreateNumericRuleFormatter or nil
		local ok, formatter = pcall(call)
		if ok and formatter ~= nil and not IsSecret(formatter) then
			ok = pcall(formatter.AddBreakpoint, formatter, { threshold = 0, format = NUMBER_HIDDEN })
			ok = ok and pcall(formatter.AddBreakpoint, formatter, { threshold = always and 1 or L.MOST + 1, format = NUMBER_SHOWN })
		end
		G.formatters[key] = ok and formatter or false
	end
	return G.formatters[key] or nil
end
G.formatters = {}

local function Invoke(object, method, ...)
	return object[method](object, ...)
end

local function Call(object, method, ...)
	return pcall(Invoke, object, method, ...)
end

function G.Quiet(button)
	pcall(button.SetAllPoints, button)
	pcall(button.EnableMouse, button, false)
	pcall(button.SetHideTooltipInCombat, button, true)
end

function G.Texts(rec, button, top)
	local d = rec.d
	local time = L.Text(top, "NumberFontNormalSmall")
	if time then
		rec.time = time
		local options = G.TimeOptions()
		local bound = options ~= nil and pcall(button.SetDurationText, button, time, options)
		if not bound then
			pcall(button.SetDurationText, button, time, nil)
		end
	end
	local number = L.Text(top, "NumberFontNormal")
	if number then
		number:SetPoint("CENTER", d.centre, "CENTER", 0, 0)
		rec.number = number
		G.Bind(rec)
	end
	rec.name = L.Text(top, "GameFontHighlightSmall")
end

function G.Bind(rec)
	local number, always = rec.number, L.Opt("count") ~= false
	if not number or rec.always == always or rec.countRefused then
		return
	end
	local formatter = G.Formatter(always)
	if formatter and pcall(rec.button.SetApplicationCount, rec.button, number, { formatter = formatter }) then
		rec.always = always
		pcall(number.Show, number)
	else
		rec.countRefused = true
		number:Hide()
	end
end

function G.InitIcon(rec, button)
	local d = rec.d
	G.Quiet(button)
	rec.button = button
	local face = Own(CreateFrame("Frame", nil, button))
	face:SetAllPoints(d.frame)
	rec.face = L.Face(d, face)
	rec.iconOk = pcall(button.SetIcon, button, rec.face.icon)
	rec.ghosts = {}
	for index = 1, L.MOST do
		local list = {}
		for layer = 0, 2 do
			local ghost = Own(face:CreateTexture(nil, "BORDER", nil, layer))
			ghost:SetPoint("CENTER", L.Spot(d, index), "CENTER", 0, 0)
			ghost:Hide()
			list[#list + 1] = ghost
		end
		rec.ghosts[index] = list
	end
	local top = Own(CreateFrame("Frame", nil, face))
	top:SetAllPoints(face)
	top:SetFrameLevel(face:GetFrameLevel() + 8)
	G.Texts(rec, button, top)
end

function G.InitOrb(rec, index, button)
	G.Quiet(button)
	local bar = L.Bar(button, index, 2)
	bar:SetPoint("CENTER", L.Spot(rec.d, index), "CENTER", 0, 0)
	local ok = pcall(button.SetApplicationBar, button, bar, { minApplications = index - 1, maxApplications = index })
	rec.orbs[index] = { bar = bar, ok = ok }
	if not ok then
		rec.orbRefused = true
	end
end

function G.Slots(rec, container, set)
	local filters = { includeSpellIDs = set }
	container:AddAuraSlot(SLOT_ICON, "HELPFUL", { candidateFilters = filters, initializeFrame = function(button)
		local ok = pcall(G.InitIcon, rec, button)
		rec.iconOk = ok and rec.iconOk
	end })
	for index = 1, L.MOST do
		container:AddAuraSlot(SLOT_ORB .. index, "HELPFUL", { candidateFilters = { includeSpellIDs = set }, initializeFrame = function(button)
			if not pcall(G.InitOrb, rec, index, button) then
				rec.orbRefused = true
			end
		end })
	end
end

function G.Build(d)
	local family = d.family
	local set = {}
	for _, id in ipairs(family.ids) do
		set[id] = true
	end
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, d.frame, "CustomAuraContainerTemplate")
	if not ok or type(container) ~= "table" then
		G.refused = true
		return
	end
	Own(container)
	local rec = { d = d, orbs = {}, container = container, on = true }
	local made = pcall(function()
		container:SetEditModePreviewEnabled(false)
		container:SetUnit("player")
		container:SetAllPoints(d.frame)
		container:SetFrameLevel(d.frame:GetFrameLevel() + 10)
		container:SetAlpha(0)
		G.Slots(rec, container, set)
	end)
	if not (made and rec.iconOk and rec.face) then
		G.refused = true
		G.Enable(rec, false)
		return
	end
	G.recs[family.key] = rec
	d.game = rec
	G.Paint(d)
	G.Show(d, d.mode == "hidden")
end

function G.Enable(rec, on)
	if rec.on == on or InCombatLockdown() then
		return
	end
	local container = rec.container
	pcall(container.SetAuraSlotEnabled, container, SLOT_ICON, on)
	for index = 1, L.MOST do
		pcall(container.SetAuraSlotEnabled, container, SLOT_ORB .. index, on)
	end
	rec.on = on
	if not on then
		pcall(container.SetAlpha, container, 0)
	end
end

function G.Paint(d)
	local rec = d.game
	if not (rec and rec.face) then
		return
	end
	rec.dirty = nil
	local r, g, b = d.r or 1, d.g or 1, d.b or 1
	pcall(L.PaintFace, rec.face, d.size, r, g, b, d.faceShown)
	pcall(G.Bind, rec)
	for index = 1, L.MOST do
		pcall(G.PaintSlot, d, rec, index, r, g, b)
	end
	pcall(L.TextLook, d, rec)
	if rec.time then
		Call(rec.time, "SetShown", L.Opt("time") ~= false)
	end
end

function G.PaintSlot(d, rec, index, r, g, b)
	local B = ns.ChargesBar
	local on = index <= d.n
	local used = on and L.Opt("ghosts") ~= false
	local ghosts, orb, spot = rec.ghosts[index], rec.orbs[index], L.Spot(d, index)
	local bar = orb and orb.bar
	local tint
	if d.kind == "pip" then
		local look = d.look
		local s, stretch = B.Sizes(d)
		B.Region(ghosts[1], look.shadow, s, stretch, spot, r, g, b, used)
		B.Region(ghosts[2], look.socket, s, stretch, spot, r, g, b, used)
		B.Region(ghosts[3], look.rim, s, stretch, spot, r, g, b, used)
		local gem = look.gem
		tint = bar and B.PaintBar(bar, gem, gem.w * s, gem.h * s, gem.y * s, spot, r, g, b, on)
	elseif d.kind == "art" then
		B.ArtGhost(ghosts[1], d, spot, used and index == 1)
		ghosts[2]:Hide()
		ghosts[3]:Hide()
		tint = bar and B.ArtBar(bar, d, spot, on)
	else
		B.Region(ghosts[1], B.ORB_GHOST, d.orb, 0, spot, r, g, b, used)
		ghosts[2]:Hide()
		ghosts[3]:Hide()
		local fill = B.ORB_FILL
		tint = bar and B.PaintBar(bar, fill, d.orb * fill.w, d.orb * fill.h, 0, spot, r, g, b, on)
	end
	if tint then
		bar:SetStatusBarColor(tint[1], tint[2], tint[3], tint[4])
	end
end

function G.Safe()
	return not InCombatLockdown() and ns.Tracking.Open() == true
end

function G.Repaint(d)
	local rec = d.game
	if not rec then
		return
	end
	if G.Safe() then
		G.Paint(d)
	else
		rec.dirty = true
	end
end

function G.Show(d, on)
	local rec = d.game
	if rec and rec.container then
		pcall(rec.container.SetAlpha, rec.container, on and rec.on and 1 or 0)
	end
end

function G.Sync()
	local C = Charges()
	if not C or InCombatLockdown() or not ns.Enabled("charges") then
		return
	end
	local wanted = {}
	for _, family in ipairs(C.Families()) do
		wanted[family.key] = true
		local d = C.Display(family)
		local rec = G.recs[family.key]
		if rec then
			G.Enable(rec, true)
		elseif not G.tried[family.key] then
			G.tried[family.key] = true
			G.Build(d)
		end
	end
	for key, rec in pairs(G.recs) do
		if not wanted[key] then
			G.Enable(rec, false)
		end
		if rec.dirty and G.Safe() then
			G.Paint(rec.d)
		end
	end
end
G.tried = {}

function G.Disable()
	for _, rec in pairs(G.recs) do
		G.Enable(rec, false)
	end
end

function G.Off()
	for _, rec in pairs(G.recs) do
		pcall(rec.container.SetAlpha, rec.container, 0)
	end
	if not InCombatLockdown() then
		G.Disable()
	elseif not G.offQueued then
		G.offQueued = true
		ns.OutOfCombat(function()
			G.offQueued = false
			if not ns.Enabled("charges") then
				G.Disable()
			end
		end)
	end
end
