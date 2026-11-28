local _, ns = ...

local KEY, PART, ROW = "windows", "guide windows", "windows.guideSkin"
local ADDON = "RXPGuides"
local UNKNOWN = "Windows: the levelling guide's windows are not ones Flat UI knows (%s), so they keep their own look."
local PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }
local DRAWN = { "rxpBackground", "rxpBorder", "rxpShadow" }
local ROOTS = { "RXPFrame", "RXPG_ARROW", "RXPItemFrame", "RXPTargetFrame", "RXPV2GuideWindow", "RXPActivePartyStepsFrame" }
local COMMS = "RXPV2CommsWindow"
local ARROW = "RXPG_ARROW"
local FOLLOWED = { "UpdateTheme", "SetStep", "ReloadGuide", "LoadGuide", "CreateActiveItemFrame", "ShowMenu" }
local NESTED = { { { "v2" }, { "UpdateGuideWindow" } }, { { "ui", "v2" }, { "CreateAuctionHouse" } }, { { "targeting" }, { "CreateTargetFrame", "UpdateTheme" } } }
local NARROW = { { {}, "UpdateItemFrame", "RXPItemFrame" }, { { "targeting" }, "UpdateTargetFrame", "RXPTargetFrame" } }
local MENUS = { "DropDownList", "L_DropDownList" }
local MENU_LIB = "LibUIDropDownMenu-4.0"
local MOST = { DEPTH = 8, FRAMES = 1500, LEVELS = 3, BUTTONS = 40, COMMS = 6 }
local WAIT, SETTLE, LIT = 0.05, 1, 0.25

local S = { frames = setmetatable({}, { __mode = "k" }), menus = setmetatable({}, { __mode = "k" }), texts = setmetatable({}, { __mode = "k" }),
	glows = setmetatable({}, { __mode = "k" }), lists = {}, counts = {}, narrow = {}, hooks = {} }

local function Read(t, key)
	if t == nil or ns.IsSecret(t) or type(t) ~= "table" then
		return nil
	end
	local ok, value = pcall(function()
		return t[key]
	end)
	if not ok or ns.IsSecret(value) then
		return nil
	end
	return value
end

local function IsFrame(value)
	return type(value) == "table" and not ns.IsSecret(value) and type(Read(value, "GetObjectType")) == "function" and not ns.Forbidden(value)
end

local function IsTexture(value)
	return IsFrame(value) and type(Read(value, "SetTexCoord")) == "function"
end

local function Kind(region)
	local ok, kind = pcall(region.GetObjectType, region)
	if ok and not ns.IsSecret(kind) and type(kind) == "string" then
		return kind
	end
	return nil
end

local function Shown(region)
	local ok, shown = pcall(region.IsShown, region)
	return ok and not ns.IsSecret(shown) and shown == true
end

local function NameOf(frame)
	local ok, name = pcall(frame.GetName, frame)
	if ok and not ns.IsSecret(name) and type(name) == "string" then
		return name
	end
	return nil
end

local function Addon()
	local addon = rawget(_G, "RXP")
	if type(addon) == "table" and not ns.IsSecret(addon) then
		return addon
	end
	return nil
end

local function Part(t, path)
	for _, key in ipairs(path) do
		t = Read(t, key)
	end
	return t
end

local function Present()
	local api = rawget(_G, "C_AddOns")
	local check = type(api) == "table" and not ns.IsSecret(api) and api.IsAddOnLoaded or rawget(_G, "IsAddOnLoaded")
	if type(check) ~= "function" then
		return Addon() ~= nil
	end
	local ok, loaded = pcall(check, ADDON)
	return ok and not ns.IsSecret(loaded) and loaded == true
end

local function Known()
	return Addon() ~= nil and IsFrame(rawget(_G, "RXPFrame"))
end

local function Loaded()
	return Present() and Known()
end

local function Wanted()
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and ns.Get(ROW) == true
end

local function Styled()
	return next(S.frames) ~= nil or next(S.menus) ~= nil or next(S.glows) ~= nil
end

local Pass, Queue

local looking = false
local function Run(fn, ...)
	if ns.PartStopped(KEY, PART) then
		pcall(fn, ...)
	elseif not ns.EachPart(KEY, PART, fn, ...) and ns.PartStopped(KEY, PART) and not looking then
		looking = true
		pcall(Pass)
		looking = false
	end
end

local function Later(frame)
	if not InCombatLockdown() or not ns.MaybeProtected(frame) then
		return false
	end
	if not S.waiting then
		S.waiting = true
		ns.OutOfCombat(function()
			S.waiting = false
			Queue()
		end)
	end
	return true
end

local function Spec()
	if not Wanted() or not ns.Enabled("fonts") or (ns.FontsLatin ~= nil and not ns.FontsLatin()) then
		return {}
	end
	local face = ns.FontFile(ns.Get("fonts.body"))
	return face and { face = face } or {}
end

local function Text(region, spec)
	if spec.face or S.texts[region] then
		S.texts[region] = true
		ns.TextStyle(region, spec)
	end
end

local function Texts(frame, spec)
	local ok, regions = pcall(function()
		return { frame:GetRegions() }
	end)
	if not ok then
		return
	end
	for _, region in ipairs(regions) do
		if not ns.IsSecret(region) and Kind(region) == "FontString" then
			Text(region, spec)
		end
	end
end

local function Backed(frame)
	return type(Read(frame, "backdropInfo")) == "table" or IsFrame(Read(frame, "rxpBackground"))
end

local function Drawn(frame)
	local back = Read(frame, "rxpBackground")
	if IsFrame(back) then
		return Shown(back)
	end
	return type(Read(frame, "backdropInfo")) == "table"
end

local function Fade(frame, on)
	for _, name in ipairs(PIECES) do
		local piece = Read(frame, name)
		if IsTexture(piece) then
			ns.SetFaded(piece, on)
		end
	end
	for _, name in ipairs(DRAWN) do
		local drawn = Read(frame, name)
		if IsFrame(drawn) then
			ns.SetFaded(drawn, on)
		end
	end
	local banner = Read(frame, "bg")
	if IsTexture(banner) then
		ns.SetFaded(banner, on)
	end
end

local PanelHook

local function InList(frame)
	local list = Read(rawget(_G, "RXPFrame"), "ScrollChild")
	if not IsFrame(list) then
		return false
	end
	local ok, parent = pcall(frame.GetParent, frame)
	return ok and not ns.IsSecret(parent) and parent == list
end

local function Lit(frame)
	local lit = frame:CreateTexture(nil, "HIGHLIGHT")
	ns.Own[lit] = true
	lit:SetAllPoints(frame)
	return lit
end

local function Panel(frame, nested, root)
	local rec = S.frames[frame]
	local on = Wanted()
	if rec == nil then
		if not on or Later(frame) then
			return
		end
		local outline = ns.Outline(frame, frame)
		if not outline then
			return
		end
		rec = { fn = "panel", outline = ns.ThemeOutline(outline, root == true), nested = nested, lit = InList(frame) and Lit(frame) or nil }
		S.frames[frame] = rec
		if type(Read(frame, "SetBackdrop")) == "function" then
			ns.Follow(frame, "SetBackdrop", PanelHook)
		end
		ns.Count(KEY)
	end
	local drawn = on and Drawn(frame)
	local r, g, b = ns.WindowColour(rec.nested and "windows.panel" or "general.backdrop")
	local opacity = ns.Get("windows.opacity")
	ns.SetOutlineFill(rec.outline, r, g, b, ns.WindowOpacity((ns.Finite(opacity) and opacity or 80) / 100))
	ns.SetOutline(rec.outline, drawn, drawn)
	Fade(frame, on)
	if rec.lit then
		if on then
			local ar, ag, ab = ns.WindowColour("windows.accent")
			rec.lit:SetColorTexture(ar, ag, ab, LIT)
		end
		rec.lit:SetShown(on)
	end
end

local function RootGlow(frame, want)
	local outline = S.glows[frame]
	local on = want and Wanted()
	if outline == nil then
		if not on or Later(frame) then
			return
		end
		local holder = CreateFrame("Frame", nil, frame)
		ns.Own[holder] = true
		holder:SetAllPoints(frame)
		outline = ns.ThemeOutline(ns.Outline(holder, holder, true), true)
		if not outline then
			return
		end
		ns.SetOutlineEdges(outline, false)
		ns.SetOutlineFill(outline, 0, 0, 0, 0)
		S.glows[frame] = outline
	end
	ns.SetOutline(outline, on, on)
end

PanelHook = function(frame)
	local rec = S.frames[frame]
	if rec ~= nil and not ns.IsStopped(KEY) then
		Run(Panel, frame, rec.nested)
	end
end

local function Bar(bar)
	local rec = S.frames[bar]
	local on = Wanted()
	if rec == nil then
		local region = on and ns.FillRegion(bar)
		if not region then
			return
		end
		local ok, file = pcall(region.GetTexture, region)
		rec = { fn = "bar", file = ok and not ns.IsSecret(file) and file or nil }
		S.frames[bar] = rec
	end
	if on then
		local file = ns.BarTexture()
		if file then
			pcall(bar.SetStatusBarTexture, bar, file)
		end
	else
		if rec.file ~= nil then
			pcall(bar.SetStatusBarTexture, bar, rec.file)
		end
		S.frames[bar] = nil
	end
end

local function Region(button, getter)
	local get = Read(button, getter)
	if type(get) ~= "function" then
		return nil
	end
	local ok, region = pcall(get, button)
	return ok and IsTexture(region) and region or nil
end

local function Check(button)
	local rec = S.frames[button]
	local on = Wanted()
	if rec == nil then
		if not on or Later(button) then
			return
		end
		local outline = ns.Outline(button, button)
		if not outline then
			return
		end
		rec = { fn = "check", outline = outline, normal = Region(button, "GetNormalTexture"), mark = Region(button, "GetCheckedTexture") }
		if rec.mark then
			local ok, r, g, b, a = pcall(rec.mark.GetVertexColor, rec.mark)
			rec.colour = ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b) and { r, g, b, ns.Finite(a) and a or 1 } or { 1, 1, 1, 1 }
		end
		S.frames[button] = rec
		ns.Count(KEY)
	end
	local r, g, b = ns.WindowColour("windows.panel")
	ns.SetOutlineFill(rec.outline, r, g, b, 1)
	ns.SetOutline(rec.outline, on, on)
	ns.SetFaded(rec.normal, on)
	if rec.mark then
		local c = rec.colour
		if on then
			local ar, ag, ab = ns.WindowColour("windows.accent")
			pcall(rec.mark.SetVertexColor, rec.mark, ar, ag, ab, 1)
		else
			pcall(rec.mark.SetVertexColor, rec.mark, c[1], c[2], c[3], c[4])
		end
	end
end

local function Icon(button)
	local rec = S.frames[button]
	local on = Wanted()
	if rec == nil then
		if not on or Later(button) then
			return
		end
		local outline = ns.Outline(button, button)
		if not outline then
			return
		end
		rec = { fn = "icon", outline = outline, icon = Read(button, "icon") }
		S.frames[button] = rec
		ns.Count(KEY)
	end
	ns.SetOutline(rec.outline, on, false)
	local crop = ns.Get(KEY .. ".crop")
	crop = on and ns.Finite(crop) and crop / 100 or 0
	if IsTexture(rec.icon) then
		pcall(rec.icon.SetTexCoord, rec.icon, crop, 1 - crop, crop, 1 - crop)
	end
end

local function Arrow(frame)
	local rec = S.frames[frame]
	local on = Wanted()
	if rec == nil then
		local texture = Read(frame, "texture")
		if not on or not IsTexture(texture) then
			return
		end
		local ok, r, g, b, a = pcall(texture.GetVertexColor, texture)
		rec = { fn = "arrow", texture = texture, colour = ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b) and { r, g, b, ns.Finite(a) and a or 1 } or { 1, 1, 1, 1 } }
		S.frames[frame] = rec
	end
	local texture = rec.texture
	if on and ns.ThemeDark() then
		local r, g, b = ns.WindowColour("windows.accent")
		pcall(texture.SetVertexColor, texture, r, g, b, 1)
		rec.tinted = true
	elseif rec.tinted then
		local c = rec.colour
		pcall(texture.SetVertexColor, texture, c[1], c[2], c[3], c[4])
		rec.tinted = nil
	end
	Texts(frame, on and Spec() or {})
end

local ACTIONS = { panel = Panel, bar = Bar, check = Check, icon = Icon, arrow = Arrow }

local function Walk(frame, depth, inside, state)
	if state.count >= MOST.FRAMES or state.seen[frame] or ns.Own[frame] or not IsFrame(frame) then
		return
	end
	state.seen[frame] = true
	state.count = state.count + 1
	local kind = Kind(frame)
	local boxed = false
	if kind == "StatusBar" then
		Run(Bar, frame)
	elseif kind == "CheckButton" then
		Run(Check, frame)
	elseif kind == "Button" and IsTexture(Read(frame, "icon")) then
		Run(Icon, frame)
	elseif Backed(frame) or (S.frames[frame] and S.frames[frame].fn == "panel") then
		Run(Panel, frame, inside, depth == 0)
		boxed = true
	end
	if depth == 0 then
		Run(RootGlow, frame, not boxed)
	end
	Run(Texts, frame, state.spec)
	if depth >= MOST.DEPTH then
		return
	end
	local ok, children = pcall(function()
		return { frame:GetChildren() }
	end)
	if ok then
		for _, child in ipairs(children) do
			Walk(child, depth + 1, inside or boxed, state)
		end
	end
end

local function Widget(value)
	if IsFrame(value) then
		return value
	end
	local frame = Read(value, "frame")
	if IsFrame(frame) then
		return frame
	end
	return nil
end

local function Roots()
	local list, seen = {}, {}
	local function Add(value)
		local frame = Widget(value)
		if frame and not seen[frame] then
			seen[frame] = true
			list[#list + 1] = frame
		end
	end
	for _, name in ipairs(ROOTS) do
		Add(rawget(_G, name))
	end
	for index = 1, MOST.COMMS do
		Add(rawget(_G, COMMS .. index))
	end
	local addon = Addon()
	local enabled = Read(addon, "enabledFrames")
	if type(enabled) == "table" then
		for _, value in pairs(enabled) do
			Add(value)
		end
	end
	Add(Read(Part(addon, { "ui", "v2" }), "auctionHouse"))
	return list
end

local function Owned(list)
	local dropdown = Read(list, "dropdown")
	if not IsFrame(dropdown) then
		return false
	end
	local name = NameOf(dropdown)
	return name ~= nil and name:sub(1, 3) == "RXP"
end

local function Menu(list, name)
	local rec = S.menus[list]
	local on = Wanted() and Shown(list) and Owned(list)
	if rec == nil then
		if not on then
			return
		end
		local outline = ns.Outline(list, list)
		if not outline then
			return
		end
		rec = { outline = ns.ThemeOutline(outline, false) }
		S.menus[list] = rec
		ns.Count(KEY)
	end
	local r, g, b = ns.WindowColour("general.backdrop")
	ns.SetOutlineFill(rec.outline, r, g, b, ns.WindowOpacity(0.95))
	ns.SetOutline(rec.outline, on, on)
	ns.SetFaded(rawget(_G, name .. "Backdrop"), on)
	ns.SetFaded(rawget(_G, name .. "MenuBackdrop"), on)
	for _, key in ipairs(DRAWN) do
		local drawn = Read(list, key)
		if IsFrame(drawn) then
			ns.SetFaded(drawn, on)
		end
	end
	local spec = on and Spec() or {}
	local count = Read(list, "numButtons")
	count = ns.Finite(count) and math.min(count, MOST.BUTTONS) or 0
	for index = 1, count do
		local text = rawget(_G, name .. "Button" .. index .. "NormalText")
		if IsFrame(text) then
			Text(text, spec)
		end
	end
end

local function Menus()
	for _, prefix in ipairs(MENUS) do
		if S.lists[prefix] then
			for level = 1, MOST.LEVELS do
				local name = prefix .. level
				local list = rawget(_G, name)
				if IsFrame(list) then
					Run(Menu, list, name)
				end
			end
		end
	end
end

local function MenuHook()
	if not ns.IsStopped(KEY) and (Wanted() or next(S.menus) ~= nil) then
		Menus()
	end
end

local function FollowMenus()
	if not S.lists[MENUS[1]] and ns.FollowGlobal("ToggleDropDownMenu", MenuHook) then
		S.lists[MENUS[1]] = true
	end
	local stub = rawget(_G, "LibStub")
	if S.lists[MENUS[2]] or type(stub) ~= "table" or ns.IsSecret(stub) or type(Read(stub, "GetLibrary")) ~= "function" then
		return
	end
	local ok, lib = pcall(stub.GetLibrary, stub, MENU_LIB, true)
	if ok and type(lib) == "table" and not ns.IsSecret(lib) and type(Read(lib, "ToggleDropDownMenu")) == "function"
		and ns.FollowTable(lib, "ToggleDropDownMenu", MenuHook) then
		S.lists[MENUS[2]] = true
	end
end

local function Grown(name)
	local frame = rawget(_G, name)
	if not IsFrame(frame) then
		return false
	end
	local ok, count = pcall(frame.GetNumChildren, frame)
	if not ok or not ns.Finite(count) or S.counts[name] == count then
		return false
	end
	S.counts[name] = count
	return true
end

local function Narrow(name)
	if S.narrow[name] or ns.IsStopped(KEY) or not Wanted() or not Grown(name) then
		return
	end
	S.narrow[name] = true
	C_Timer.After(WAIT, function()
		S.narrow[name] = nil
		local frame = rawget(_G, name)
		if not ns.IsStopped(KEY) and Loaded() and Wanted() and IsFrame(frame) then
			Walk(frame, 0, false, { seen = {}, count = 0, spec = Spec() })
		end
	end)
end

local function NarrowHook(name)
	local hook = S.hooks[name]
	if hook == nil then
		hook = function()
			Narrow(name)
		end
		S.hooks[name] = hook
	end
	return hook
end

local function Follow()
	local addon = Addon()
	if addon == nil then
		return
	end
	if not S.followed then
		local any = false
		for _, name in ipairs(FOLLOWED) do
			if type(Read(addon, name)) == "function" and ns.FollowTable(addon, name, Queue) then
				any = true
			end
		end
		for _, entry in ipairs(NESTED) do
			local part = Part(addon, entry[1])
			if type(part) == "table" then
				for _, name in ipairs(entry[2]) do
					if type(Read(part, name)) == "function" then
						ns.FollowTable(part, name, Queue)
					end
				end
			end
		end
		for _, entry in ipairs(NARROW) do
			local part = Part(addon, entry[1])
			if type(part) == "table" and type(Read(part, entry[2])) == "function" then
				ns.FollowTable(part, entry[2], NarrowHook(entry[3]))
			end
		end
		local frame = rawget(_G, "RXPFrame")
		if IsFrame(frame) and type(Read(frame, "UpdateSubTheme")) == "function" then
			ns.Follow(frame, "UpdateSubTheme", Queue)
		end
		S.followed = any
	end
	FollowMenus()
end

Pass = function()
	local state = { seen = {}, count = 0, spec = Spec() }
	local arrow = rawget(_G, ARROW)
	for _, frame in ipairs(Roots()) do
		if frame == arrow then
			state.seen[frame] = true
			Run(Arrow, frame)
		else
			Walk(frame, 0, false, state)
		end
	end
	Menus()
	if not Wanted() then
		for frame, rec in pairs(S.frames) do
			if not state.seen[frame] then
				Run(ACTIONS[rec.fn], frame, rec.nested)
			end
		end
		for frame, outline in pairs(S.glows) do
			if not state.seen[frame] then
				ns.SetOutline(outline, false, false)
			end
		end
	end
	for _, entry in ipairs(NARROW) do
		Grown(entry[3])
	end
end

Queue = function()
	if S.queued then
		return
	end
	S.queued = true
	C_Timer.After(WAIT, function()
		S.queued = false
		if not ns.IsStopped(KEY) and Loaded() and (Wanted() or Styled()) then
			pcall(Follow)
			Pass()
		end
	end)
end

local function Verify()
	if not Wanted() then
		return
	end
	if Addon() == nil then
		ns.Note(KEY, UNKNOWN:format("no RXP"))
	elseif not IsFrame(rawget(_G, "RXPFrame")) then
		ns.Note(KEY, UNKNOWN:format("no RXPFrame"))
	end
end

function ns.GuideSkinRefresh()
	if not Present() then
		return
	end
	pcall(Verify)
	if not Known() then
		return
	end
	pcall(Follow)
	if Wanted() or Styled() then
		Pass()
	end
end

ns.AddEvent(KEY, "ADDON_LOADED", function()
	ns.GuideSkinRefresh()
	C_Timer.After(SETTLE, Queue)
end, function(name)
	return not ns.IsSecret(name) and name == ADDON
end)
ns.AddEvent(KEY, "PLAYER_ENTERING_WORLD", function()
	if Loaded() and (Wanted() or Styled()) then
		pcall(Follow)
		C_Timer.After(SETTLE, Queue)
	end
end)
