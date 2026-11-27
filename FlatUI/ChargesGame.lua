local _, ns = ...

local G = { recs = {} }
ns.ChargesGame = G

local SLOT_ICON, SLOT_ORB = "icon", "orb"
local NUMBER_SHOWN, NUMBER_HIDDEN = "%d", " "
local ORB_SIZE = 1.6

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

function G.Formatter()
	if G.formatter == nil then
		local call = type(C_StringUtil) == "table" and C_StringUtil.CreateNumericRuleFormatter or nil
		local ok, formatter = pcall(call)
		if ok and formatter ~= nil and not IsSecret(formatter) then
			ok = pcall(formatter.AddBreakpoint, formatter, { threshold = 0, format = NUMBER_HIDDEN })
			ok = ok and pcall(formatter.AddBreakpoint, formatter, { threshold = L.MOST + 1, format = NUMBER_SHOWN })
		end
		G.formatter = ok and formatter or false
	end
	return G.formatter or nil
end

function G.Seen(rec, on)
	rec.d.gameUp = on
	local C = Charges()
	if on and C and C.Wake then
		C.Wake()
	end
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
	local formatter = G.Formatter()
	if number and formatter then
		number:SetPoint("CENTER", d.centre, "CENTER", 0, 0)
		if pcall(button.SetApplicationCount, button, number, { formatter = formatter }) then
			rec.number = number
		else
			number:Hide()
		end
	elseif number then
		number:Hide()
	end
end

function G.InitIcon(rec, button)
	local d = rec.d
	G.Quiet(button)
	local face = Own(CreateFrame("Frame", nil, button))
	face:SetAllPoints(d.frame)
	rec.face = L.Face(d, face)
	rec.iconOk = pcall(button.SetIcon, button, rec.face.icon)
	rec.ghosts = {}
	for index = 1, L.MOST do
		local ghost = Own(face:CreateTexture(nil, "BORDER", nil, 0))
		ghost:SetTexture(L.RING)
		pcall(ghost.SetBlendMode, ghost, "ADD")
		ghost:SetPoint("CENTER", L.Spot(d, index), "CENTER", 0, 0)
		rec.ghosts[index] = ghost
	end
	local top = Own(CreateFrame("Frame", nil, face))
	top:SetAllPoints(face)
	top:SetFrameLevel(face:GetFrameLevel() + 8)
	G.Texts(rec, button, top)
	local watch = Own(CreateFrame("Frame", nil, button))
	watch:SetScript("OnShow", function()
		G.Seen(rec, true)
	end)
	watch:SetScript("OnHide", function()
		G.Seen(rec, false)
	end)
	local ok, shown = pcall(button.IsVisible, button)
	d.gameUp = not ok or IsSecret(shown) or shown == true
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
	local rec = { d = d, orbs = {}, container = container, Paint = G.Paint, on = true }
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
	local r, g, b = d.r or 1, d.g or 1, d.b or 1
	L.PaintFace(rec.face, d.size, r, g, b)
	local ghosts = L.Opt("ghosts") ~= false
	for index = 1, L.MOST do
		local ghost = rec.ghosts[index]
		ghost:SetSize(d.orb * L.GHOST, d.orb * L.GHOST)
		ghost:SetVertexColor(r, g, b, 0.32)
		ghost:SetShown(ghosts and index <= d.n)
		local orb = rec.orbs[index]
		if orb then
			orb.bar:SetSize(d.orb * ORB_SIZE, d.orb * ORB_SIZE)
			orb.bar:SetStatusBarColor(r, g, b, 1)
			orb.bar:SetAlpha(index <= d.n and 1 or 0)
		end
	end
	local percent = math.max(80, math.min(150, d.size / 40 * 100))
	if rec.time then
		ns.TextStyle(rec.time, { percent = percent, flags = "OUTLINE" })
		rec.time:ClearAllPoints()
		rec.time:SetPoint("TOP", d.frame, "BOTTOM", 0, d.style == "row" and 2 or d.orb * 0.4)
		rec.time:SetShown(L.Opt("time") ~= false)
	end
	if rec.number then
		ns.TextStyle(rec.number, { percent = percent * 1.2, flags = "OUTLINE" })
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
	end
end
G.tried = {}

function G.Off()
	for _, rec in pairs(G.recs) do
		pcall(rec.container.SetAlpha, rec.container, 0)
		G.Enable(rec, false)
	end
end
