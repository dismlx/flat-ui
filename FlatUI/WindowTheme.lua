local _, ns = ...

local KEY = "windows"
local DARK = {
	["general.backdrop"] = { 0.027, 0.027, 0.035 },
	["general.border"] = { 0.478, 0.039, 0.063 },
	["windows.accent"] = { 0.784, 0.063, 0.180 },
	["windows.panel"] = { 0.071, 0.031, 0.039 },
}
local MIN_ALPHA = 0.94
local GLOW = { SIZE = 8, REST = 0.22, OVER = 0.42, STEP = 0.1 }
local SIDES = { "top", "bottom", "left", "right" }
local FADES = { top = { "VERTICAL", true }, bottom = { "VERTICAL", false }, left = { "HORIZONTAL", false }, right = { "HORIZONTAL", true } }
local REFRESH = { "windows", "bags", "chat", "trinkets" }

local glows = setmetatable({}, { __mode = "k" })
local driver
local wait = 0

local function Dark()
	return ns.Get(KEY .. ".theme") == "dark"
end
ns.ThemeDark = Dark

function ns.WindowColour(path)
	local dark = Dark() and DARK[path]
	if dark then
		return dark[1], dark[2], dark[3]
	end
	if path == "general.border" then
		return ns.BorderRGB()
	end
	return ns.Colour(path)
end

function ns.WindowOpacity(alpha)
	if not ns.Finite(alpha) then
		alpha = 0.8
	end
	if Dark() then
		return math.max(alpha, MIN_ALPHA)
	end
	return alpha
end

function ns.WindowTitleRGB()
	if ns.Get(KEY .. ".titleOwn") == true then
		return ns.Colour(KEY .. ".titleColour")
	end
	if Dark() then
		local accent = DARK[KEY .. ".accent"]
		return accent[1], accent[2], accent[3]
	end
	return nil
end

function ns.WindowCheckRGB(r, g, b)
	if Dark() then
		return ns.WindowColour(KEY .. ".accent")
	end
	return r, g, b
end

local function Place(texture, side, target)
	if side == "top" then
		texture:SetPoint("BOTTOMLEFT", target, "TOPLEFT", 0, 0)
		texture:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT", 0, 0)
		texture:SetHeight(GLOW.SIZE)
	elseif side == "bottom" then
		texture:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 0, 0)
		texture:SetPoint("TOPRIGHT", target, "BOTTOMRIGHT", 0, 0)
		texture:SetHeight(GLOW.SIZE)
	elseif side == "left" then
		texture:SetPoint("TOPRIGHT", target, "TOPLEFT", 0, 0)
		texture:SetPoint("BOTTOMRIGHT", target, "BOTTOMLEFT", 0, 0)
		texture:SetWidth(GLOW.SIZE)
	else
		texture:SetPoint("TOPLEFT", target, "TOPRIGHT", 0, 0)
		texture:SetPoint("BOTTOMLEFT", target, "BOTTOMRIGHT", 0, 0)
		texture:SetWidth(GLOW.SIZE)
	end
end

local function Shade(texture, side)
	local accent, fade = DARK[KEY .. ".accent"], FADES[side]
	local r, g, b = accent[1], accent[2], accent[3]
	local ok = pcall(function()
		local strong, none = CreateColor(r, g, b, 1), CreateColor(r, g, b, 0)
		texture:SetColorTexture(1, 1, 1, 1)
		if fade[2] then
			texture:SetGradient(fade[1], strong, none)
		else
			texture:SetGradient(fade[1], none, strong)
		end
	end)
	if not ok then
		texture:SetColorTexture(r, g, b, 0.35)
	end
end

local function Level(record, alpha)
	if record.level ~= alpha then
		record.level = alpha
		for _, texture in ipairs(record.parts) do
			texture:SetAlpha(alpha)
		end
	end
end

local function Over(record)
	local target = record.target
	local ok, visible = pcall(target.IsVisible, target)
	if not ok or ns.IsSecret(visible) or visible ~= true then
		return false
	end
	local read, over = pcall(target.IsMouseOver, target)
	return read and not ns.IsSecret(over) and over == true
end

local function Tick(_, elapsed)
	wait = wait - (ns.Finite(elapsed) and elapsed or 0)
	if wait > 0 then
		return
	end
	wait = GLOW.STEP
	local any = false
	for record in pairs(glows) do
		if record.on then
			any = true
			Level(record, Over(record) and GLOW.OVER or GLOW.REST)
		end
	end
	if not any and driver then
		driver:Hide()
	end
end

local function Drive()
	if driver == nil then
		driver = CreateFrame("Frame")
		ns.Own[driver] = true
		driver:SetScript("OnUpdate", Tick)
	end
	wait = 0
	driver:Show()
end

function ns.ThemeGlowPaint(record, on)
	on = on and true or false
	if record.on == on then
		return
	end
	record.on = on
	for _, texture in ipairs(record.parts) do
		texture:SetShown(on)
	end
	if on then
		Level(record, GLOW.REST)
		Drive()
	end
end

local function Glow(outline)
	local owner, target = outline.owner, outline.target
	if ns.Forbidden(owner) or target == nil then
		return nil
	end
	local record = { target = target, parts = {} }
	for _, side in ipairs(SIDES) do
		local texture = owner:CreateTexture(nil, "BACKGROUND", nil, -8)
		ns.Own[texture] = true
		Place(texture, side, target)
		Shade(texture, side)
		texture:Hide()
		record.parts[#record.parts + 1] = texture
	end
	glows[record] = true
	return record
end

function ns.ThemeOutline(outline, glow)
	if outline == nil then
		return nil
	end
	outline.themed = true
	if glow and outline.glow == nil then
		outline.glow = Glow(outline)
	end
	ns.RepaintOutline(outline)
	return outline
end

function ns.ThemeChanged()
	ns.RepaintOutlines()
	for _, key in ipairs(REFRESH) do
		ns.RefreshModule(key)
	end
	local look = ns.PanelLook
	if type(look) == "table" and type(look.onChange) == "function" then
		pcall(look.onChange, "accent")
	end
end
