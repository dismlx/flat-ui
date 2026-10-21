local _, ns = ...

-- Windows. The border art of a window and its buttons, tabs, scroll bars, check boxes, text
-- boxes, dropdowns, progress bars and item slots is made transparent and replaced by flat
-- boxes with thin borders, drawn with frames and textures of this addon. Each control is
-- recognised by the fields its template gives it. A region keeps the alpha it had, so a part
-- that is switched off puts Blizzard's art back exactly. Nothing is written on a Blizzard
-- frame except the size of a side tab and of its icon, which Side tab size sets and gives back
-- (out of combat when the tab is protected). The state textures of check boxes, item slots,
-- sidebar tabs and list lines are recoloured and re-anchored instead, and only /reload undoes
-- that. An open menu gets a frame of this addon's inside the menu, since the game refuses
-- textures made on it.

local KEY = "windows"

-- A sweep of one window stops at these.
local MAX_DEPTH = 10
local MAX_FRAMES = 1500

-- Fields of Blizzard's templates that hold art.
local PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }
-- The border pieces a frame keeps in its own fields: the older templates name them differently, a backdrop uses the names
-- above and adds a centre, and a basic frame with an inset has a border for the inset too.
local OWN_PIECES = { "TopBorder", "BotLeftCorner", "BotRightCorner", "BottomBorder", "LeftBorder", "RightBorder", "Center",
	"InsetBorderTopLeft", "InsetBorderTopRight", "InsetBorderBottomLeft", "InsetBorderBottomRight", "InsetBorderTop", "InsetBorderBottom",
	"InsetBorderLeft", "InsetBorderRight" }
local FLAT_BG = { "BottomLeft", "BottomRight", "BottomEdge", "TopSection" }
local STATES = { "Normal", "Pushed", "Disabled", "Highlight" }
local TAB_SQUARES = { "SquareBackground", "SquareBackgroundActive", "SquareBackgroundActiveGlow" }
local SCROLL_PARTS = { "Begin", "Middle", "End" }
local EDIT_CAPS = { "Left", "Middle", "Right" }
local MULTI_LINE_CAPS = { "TopLeftTex", "TopRightTex", "TopTex", "BottomLeftTex", "BottomRightTex", "BottomTex", "LeftTex", "RightTex", "MiddleTex" }
local RACE_ART = { "BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft", "BackgroundBotRight", "BackgroundOverlay" }
local PAGE_BUTTONS = { "MerchantPrevPageButton", "MerchantNextPageButton" }
local MERCHANT_BUTTONS = { "MerchantSellAllJunkButton", "MerchantRepairAllButton", "MerchantRepairItemButton", "MerchantGuildBankRepairButton" }
local STAT_TAB_RING = "UI-Character-Info-StatTab"
local AMMO_SLOT = "CharacterAmmoSlot"
local AMMO_RING = "UI-Character-Info-GearSlotSmall"
local BAR_BACKGROUND = "common-stat-bar-BG"
local CATEGORY_UPDATE = "LFGListingCategorySelection_UpdateCategoryButtons"
local FLYOUT_UPDATE = "EquipmentFlyout_UpdateItems"
-- The animated frames of the eye in the Looking For Group window, children of the eye button (Blizzard_LFGUtil/Mainline/LFGEye.xml:254-361;
-- the button is LFGParentFramePortrait, Blizzard_LFGVanilla_ParentFrame.xml:85).
local EYE_FRAMES = { "EyeInitial", "EyeSearchingLoop", "EyeMouseOver", "EyePokeInitial", "EyePokeLoop", "EyePokeEnd" }
-- The picture each menu style is drawn on, and how far above the bottom of the menu the box ends: the first style leaves a
-- larger gap below its rows than on the other sides.
local MENU_BACKGROUNDS = { { "common-dropdown-bg", 7 }, { "common-dropdown-c-bg", 0 } }
local MENU_EVENT = "MenuProxy.OnShow"
local PUSHED_OUT_EVENT = "UIParentPanelManager.ForcePanelHide"

-- Colours that are not options, and the colour of the edge on a broken item.
local ROLES = {
	white = { 1, 1, 1 },
	black = { 0, 0, 0 },
}
local BROKEN = { 0.9, 0, 0 }
local CHECK_ON = { 1, 0.82, 0, 0.8 }
local CHECK_OFF = { 0.6, 0.6, 0.6, 0.8 }
local HOVER = { 1, 1, 1, 0.3 }
local SLOT_PRESSED = { 0.9, 0.8, 0.1, 0.3 }

-- What this addon made for a Blizzard frame, by kind.
local styled = setmetatable({}, { __mode = "k" })
-- The alpha a faded region had.
local faded = setmetatable({}, { __mode = "k" })
-- The texture coordinates an icon had before it was cropped.
local texcoords = setmetatable({}, { __mode = "k" })
-- The window each root frame belongs to.
local roots = setmetatable({}, { __mode = "k" })
-- The item buttons that are styled, for the hooks on the game's item functions.
local slots = setmetatable({}, { __mode = "k" })
-- The scripts of Blizzard frames that are already hooked, and the global functions.
local hooked = setmetatable({}, { __mode = "k" })
local hookedGlobals = {}
-- Kinds whose art was put back after they stopped.
local released = {}
-- True while a kind is made on a protected frame in combat: its art is faded and nothing is created.
local dry = false

local KINDS = {}

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- Reading Blizzard's frames ------------------------------------------------------------------

-- A frame or region, unless the client withholds it.
local function Usable(value)
	return value ~= nil and not ns.IsSecret(value) and type(value) == "table"
end

-- A field of a frame, unless the client withholds it.
local function Field(frame, key)
	local value = frame[key]
	if ns.IsSecret(value) then
		return nil
	end
	return value
end

-- A frame or region held in a field.
local function Part(frame, key)
	if not Usable(frame) then
		return nil
	end
	local value = frame[key]
	if Usable(value) then
		return value
	end
	return nil
end

-- Only a Texture can be masked. Font strings and mask textures cannot.
local function IsTexture(region)
	return Usable(region) and type(region.AddMaskTexture) == "function"
end

local function NameOf(frame)
	local ok, name = pcall(frame.GetName, frame)
	if ok and not ns.IsSecret(name) and type(name) == "string" then
		return name
	end
	return nil
end

local function ParentOf(frame)
	local ok, parent = pcall(frame.GetParent, frame)
	if ok and Usable(parent) then
		return parent
	end
	return nil
end

local function Shown(region)
	if not Usable(region) then
		return false
	end
	local ok, shown = pcall(region.IsShown, region)
	return ok and not ns.IsSecret(shown) and shown == true
end

local function Protected(frame)
	local ok, protected = pcall(frame.IsProtected, frame)
	return not ok or ns.IsSecret(protected) or protected == true
end

-- Red, green and blue of a region's vertex colour.
local function VertexColour(region)
	if not Usable(region) then
		return nil
	end
	local ok, r, g, b = pcall(region.GetVertexColor, region)
	if ok and not ns.IsSecret(r) and not ns.IsSecret(g) and not ns.IsSecret(b)
		and type(r) == "number" and type(g) == "number" and type(b) == "number" then
		return r, g, b
	end
	return nil
end

local function Children(frame)
	if type(frame.GetChildren) ~= "function" then
		return {}
	end
	local ok, list = pcall(function()
		return { frame:GetChildren() }
	end)
	return ok and list or {}
end

-- The texture in one of a button's states: "Normal", "Pushed", "Disabled", "Highlight", "Checked".
local function State(button, which)
	local getter = button["Get" .. which .. "Texture"]
	if type(getter) ~= "function" then
		return nil
	end
	local ok, texture = pcall(getter, button)
	if ok and Usable(texture) then
		return texture
	end
	return nil
end

-- A frame or region named by a path from the globals, such as "CharacterFrame.LeftPaneHost".
-- A forbidden frame on the way ends the path before any of its fields is read.
local function Path(text)
	local found
	local ok = pcall(function()
		for key in text:gmatch("[^%.]+") do
			if found == nil then
				found = _G[key]
			else
				found = found[key]
			end
			if not Usable(found) or ns.Forbidden(found) then
				found = nil
				return
			end
		end
	end)
	return ok and found or nil
end

-- A frame or region held in a field of a frame that may be forbidden.
local function Held(frame, key)
	if ns.Forbidden(frame) then
		return nil
	end
	return Part(frame, key)
end

-- A list of the frames and regions among the values, left out when the client withholds them.
local function Pieces(...)
	local list = {}
	for index = 1, select("#", ...) do
		local piece = select(index, ...)
		if Usable(piece) then
			list[#list + 1] = piece
		end
	end
	return list
end

-- The frames and regions held in the named fields of a frame that may be forbidden, left out when missing.
local function Keyed(frame, keys)
	local list = {}
	for _, key in ipairs(keys) do
		list[#list + 1] = Held(frame, key)
	end
	return list
end

-- The texture a frame draws in one draw layer and sublevel, for art that has no key.
local function RegionAt(frame, layer, sublevel)
	if ns.Forbidden(frame) or type(frame.GetRegions) ~= "function" then
		return nil
	end
	for _, region in ipairs({ frame:GetRegions() }) do
		if IsTexture(region) and not ns.Own[region] then
			local ok, found, level = pcall(region.GetDrawLayer, region)
			if ok and not ns.IsSecret(found) and not ns.IsSecret(level) and found == layer and level == sublevel then
				return region
			end
		end
	end
	return nil
end

-- An edge texture of a text box: by its key, or by the name its template gives it.
local function EditCap(frame, key)
	local cap = Part(frame, key)
	if cap then
		return cap
	end
	local name = NameOf(frame)
	cap = name and Part(_G, name .. key)
	return IsTexture(cap) and cap or nil
end

-- Art ---------------------------------------------------------------------------------------

-- Makes a texture transparent and keeps the alpha it had. Turning it off gives that alpha back.
-- With frames true the region may be a frame with the alpha methods, which dims what is drawn on it.
local function Fade(region, on, frames)
	if not IsTexture(region) and not (frames and Usable(region) and type(region.GetAlpha) == "function" and type(region.SetAlpha) == "function") then
		return
	end
	local had = faded[region]
	if on then
		if had == nil then
			local ok, alpha = pcall(region.GetAlpha, region)
			if not ok or ns.IsSecret(alpha) or type(alpha) ~= "number" then
				return
			end
			faded[region] = alpha
		end
		pcall(region.SetAlpha, region, 0)
	elseif had ~= nil then
		faded[region] = nil
		pcall(region.SetAlpha, region, had)
	end
end

-- Fades the textures in an array field.
local function FadeArray(frame, key, on)
	local list = Part(frame, key)
	if list then
		for _, region in ipairs(list) do
			Fade(region, on)
		end
	end
end

-- Fades every texture drawn on a frame, and on its children down to `depth`.
-- keep: one texture to leave alone.
local function Strip(frame, depth, on, keep)
	if ns.Forbidden(frame) or type(frame.GetRegions) ~= "function" then
		return
	end
	for _, region in ipairs({ frame:GetRegions() }) do
		if Usable(region) and region ~= keep and not ns.Own[region] then
			Fade(region, on)
		end
	end
	if depth > 0 then
		for _, child in ipairs(Children(frame)) do
			if Usable(child) and not ns.Own[child] then
				Strip(child, depth - 1, on, keep)
			end
		end
	end
end

-- An icon cut to the middle of the rectangle it shows, which is a part of a shared sheet for some
-- icons. The coordinates it had come back when the crop ends.
local function Crop(icon, fraction)
	if not IsTexture(icon) then
		return
	end
	if texcoords[icon] == nil then
		local ok, ulx, uly, llx, lly, urx = pcall(icon.GetTexCoord, icon)
		if ok and not ns.IsSecret(ulx) and not ns.IsSecret(uly) and not ns.IsSecret(lly) and not ns.IsSecret(urx)
			and type(ulx) == "number" and type(uly) == "number" and type(lly) == "number" and type(urx) == "number" then
			texcoords[icon] = { ulx, urx, uly, lly }
		else
			texcoords[icon] = { 0, 1, 0, 1 }
		end
	end
	local had = texcoords[icon]
	local across, down = (had[2] - had[1]) * fraction, (had[4] - had[3]) * fraction
	pcall(icon.SetTexCoord, icon, had[1] + across, had[2] - across, had[3] + down, had[4] - down)
end

local function Uncrop(icon)
	local had = texcoords[icon]
	if had then
		texcoords[icon] = nil
		pcall(icon.SetTexCoord, icon, had[1], had[2], had[3], had[4])
	end
end

-- A state texture of a Blizzard button becomes a flat colour. The game shows it by state, so no
-- script is needed. With an inset it is that far inside the target, without one it fills it.
local function Retint(texture, target, colour, inset)
	if dry or not Usable(texture) then
		return
	end
	texture:SetColorTexture(colour[1], colour[2], colour[3], colour[4])
	texture:ClearAllPoints()
	if inset then
		texture:SetPoint("TOPLEFT", target, "TOPLEFT", inset, -inset)
		texture:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", -inset, inset)
	else
		texture:SetAllPoints(target)
	end
end

-- What this addon draws ---------------------------------------------------------------------

local function Mine(object)
	ns.Own[object] = true
	return object
end

-- An invisible rectangle for a box that is not the rectangle of a frame. Each side is that far
-- inside the target; a negative number reaches outside it. With a height, the box is that high
-- and centred on the target.
local function Box(owner, target, left, right, top, bottom, height)
	if dry then
		return nil
	end
	local box = Mine(owner:CreateTexture(nil, "BACKGROUND", nil, -8))
	box:SetColorTexture(0, 0, 0, 0)
	if height then
		box:SetPoint("LEFT", target, "LEFT", left, 0)
		box:SetPoint("RIGHT", target, "RIGHT", -right, 0)
		box:SetHeight(height)
	else
		box:SetPoint("TOPLEFT", target, "TOPLEFT", left, -top)
		box:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", -right, bottom)
	end
	return box
end

local function RoleColour(role)
	if role == "accent" then
		return ns.Colour(KEY .. ".accent")
	end
	local colour = ROLES[role]
	return colour[1], colour[2], colour[3]
end

-- Sets a colour and visibility only when they changed.
local function Show(paint, shown)
	local r, g, b = RoleColour(paint.role)
	if paint.r ~= r or paint.g ~= g or paint.b ~= b then
		paint.r, paint.g, paint.b = r, g, b
		paint.texture:SetColorTexture(r, g, b, paint.alpha)
	end
	if paint.shown ~= shown then
		paint.shown = shown
		paint.texture:SetShown(shown)
	end
end

-- One flat colour over a target. role: "accent", "white" or "black".
local function Tint(own, owner, target, layer, role, alpha, blend, manual)
	if dry then
		return nil
	end
	local texture = Mine(owner:CreateTexture(nil, layer, nil, 1))
	if blend then
		texture:SetBlendMode(blend)
	end
	texture:SetAllPoints(target)
	local paint = { texture = texture, role = role, alpha = alpha, manual = manual }
	own.paints[#own.paints + 1] = paint
	return paint
end

-- Follows a script of one Blizzard frame with HookScript, which writes nothing on the frame, once for each frame, script and function.
-- (EllesmereUI follows script and event passes the same way: EllesmereUIChat/EllesmereUIChat.lua:4410-4417, 6270-6281.)
local function HookScript(frame, script, fn)
	if type(frame) ~= "table" or ns.IsSecret(frame) or ns.Forbidden(frame) then
		return false
	end
	local done = hooked[frame] or {}
	hooked[frame] = done
	local list = done[script] or {}
	done[script] = list
	if list[fn] == nil then
		list[fn] = type(frame.HookScript) == "function" and pcall(frame.HookScript, frame, script, fn) or false
	end
	return list[fn]
end

-- Work asked for from a game call or event runs one frame later, once for each function and frame, so that nothing of the addon's runs
-- inside the game's own pass (the way EllesmereUI does it: EllesmereUI_Lite.lua:517-558, EllesmereUIBlizzardSkin.lua:1296-1305).
local Soon
do
	local queued, flushing = {}, false

	local function Flush()
		flushing = false
		local work = queued
		queued = {}
		if not ns.Enabled(KEY) then
			return
		end
		for fn, set in pairs(work) do
			for _, item in pairs(set) do
				ns.EachPart(KEY, item.part, fn, item.a, item.b)
			end
		end
	end

	function Soon(part, fn, a, b)
		local set = queued[fn]
		if set == nil then
			set = {}
			queued[fn] = set
		end
		set[a == nil and true or a] = { part = part, a = a, b = b }
		if not flushing then
			flushing = true
			if C_Timer and C_Timer.After then
				C_Timer.After(0, Flush)
			else
				Flush()
			end
		end
	end
end

-- What the calls and events of the game ask to be looked at again: the side tabs, the lists, the bags and the bank.
local Watch = {}

-- A chevron or a cross made of two lines.
local SHAPES = {
	x = { { -1, 1, 1, -1 }, { -1, -1, 1, 1 } },
	up = { { -1, -0.5, 0, 0.5 }, { 0, 0.5, 1, -0.5 } },
	down = { { -1, 0.5, 0, -0.5 }, { 0, -0.5, 1, 0.5 } },
	left = { { 0.5, 1, -0.5, 0 }, { -0.5, 0, 0.5, -1 } },
	right = { { -0.5, 1, 0.5, 0 }, { 0.5, 0, -0.5, -1 } },
}

local function Place(glyph, shape)
	local half = glyph.size / 2
	for index, segment in ipairs(SHAPES[shape]) do
		local line = glyph.lines[index]
		line:SetStartPoint(glyph.point, glyph.target, glyph.x + segment[1] * half, glyph.y + segment[2] * half)
		line:SetEndPoint(glyph.point, glyph.target, glyph.x + segment[3] * half, glyph.y + segment[4] * half)
	end
	glyph.shape = shape
end

-- spec: layer, shape, role, alpha, size, and optionally point, x and y for its place on target.
local function Glyph(own, owner, target, spec)
	if dry then
		return nil
	end
	local glyph = { target = target, size = spec.size, point = spec.point or "CENTER", x = spec.x or 0, y = spec.y or 0, lines = {} }
	for index = 1, 2 do
		local line = Mine(owner:CreateLine(nil, spec.layer, nil, 2))
		line:SetThickness(1.5)
		glyph.lines[index] = line
		own.paints[#own.paints + 1] = { texture = line, role = spec.role, alpha = spec.alpha }
	end
	Place(glyph, spec.shape)
	return glyph
end

-- A thin border and a fill around target, made with the outline Flat UI draws elsewhere.
-- fill: "window" for the window colour and opacity, "panel" for the button and slot colour.
local function Outlined(own, owner, target, fill)
	if dry then
		return nil
	end
	local outline = ns.Outline(owner, target)
	if not outline then
		error("no outline", 0)
	end
	own.outlines[#own.outlines + 1] = { outline = outline, fill = fill }
	return outline
end

local function Fill(outline, fill)
	if fill == "window" then
		local r, g, b = ns.Colour("general.backdrop")
		ns.SetOutlineFill(outline, r, g, b, Opt("opacity") / 100)
	elseif fill == "solid" then
		local r, g, b = ns.Colour("general.backdrop")
		-- Menus and lists lie over other windows, so their fill does not follow the window opacity.
		ns.SetOutlineFill(outline, r, g, b, 0.95)
	else
		local r, g, b = ns.Colour(KEY .. ".panel")
		ns.SetOutlineFill(outline, r, g, b, 1)
	end
end

-- Shows or hides everything a kind drew for one frame, in the current colours.
local function Reveal(own, on)
	for _, entry in ipairs(own.outlines) do
		Fill(entry.outline, entry.fill)
		ns.SetOutline(entry.outline, on, on)
	end
	for _, paint in ipairs(own.paints) do
		-- A paint with its own rule is shown by the kind that made it.
		if not paint.manual then
			Show(paint, on)
		end
	end
end

-- Kinds of styled frame ------------------------------------------------------------------------

-- label: the name of the part in /flatui status. option: the setting that switches it, besides
-- the window's own. make draws what is needed once. apply shows or hides it, and fades Blizzard's art.
-- host: the frame that make creates things on, when that is not the styled frame itself.
local function Kind(name, label, option, make, apply, host)
	KINDS[name] = { label = label, option = option, make = make, apply = apply, host = host }
end

local function IsOn(kind, group)
	local option = KINDS[kind].option
	return ns.Enabled(KEY) and ns.Get(KEY .. "." .. group) == true and (option == nil or Opt(option) == true)
end

-- Runs a kind's make and apply for a frame. Anything made before a failure is hidden again.
local function Build(frame, def, own, flag, on)
	def.make(frame, own, flag)
	def.apply(frame, own, on)
end

-- Puts back the art of every frame a stopped part had styled.
local function Release(kind)
	if released[kind] then
		return
	end
	released[kind] = true
	local def = KINDS[kind]
	for frame, entries in pairs(styled) do
		local own = entries[kind]
		if own and not own.broken then
			own.broken = true
			pcall(def.apply, frame, own, false)
		end
	end
end

-- Applies a kind to a frame it styled. A part that stops on the way gives back the art of every
-- frame it had styled.
local function Apply(kind, frame, own, on)
	local def = KINDS[kind]
	if not ns.EachPart(KEY, def.label, def.apply, frame, own, on) and ns.PartStopped(KEY, def.label) then
		Release(kind)
	end
end

local function Style(kind, frame, group, flag)
	if ns.Forbidden(frame) then
		return
	end
	local def = KINDS[kind]
	if ns.PartStopped(KEY, def.label) then
		return
	end
	local had = styled[frame] and styled[frame][kind]
	if had then
		if not had.broken then
			Apply(kind, frame, had, IsOn(kind, group))
		end
		return
	end
	if not IsOn(kind, group) then
		return
	end
	-- The pass in combat fades Blizzard's art on this record. Make builds on it, or undoes it.
	local own = { kind = kind, group = group, paints = {}, outlines = {} }
	local function Make()
		if styled[frame] and styled[frame][kind] then
			return
		end
		-- Switched off since the pass in combat: Blizzard's art goes back.
		if not IsOn(kind, group) then
			pcall(def.apply, frame, own, false)
			return
		end
		local entries = styled[frame]
		if not entries then
			entries = {}
			styled[frame] = entries
		end
		entries[kind] = own
		if ns.EachPart(KEY, def.label, Build, frame, def, own, flag, true) then
			ns.Count(KEY)
		else
			own.broken = true
			pcall(def.apply, frame, own, false)
			if ns.PartStopped(KEY, def.label) then
				Release(kind)
			end
		end
	end
	-- Nothing is created or anchored on a protected frame in combat, but its art can be faded.
	local host = def.host and def.host(frame, flag) or frame
	if InCombatLockdown() and (Protected(frame) or Protected(host)) then
		dry = true
		ns.EachPart(KEY, def.label, Build, frame, def, own, flag, true)
		dry = false
		ns.OutOfCombat(Make)
	else
		Make()
	end
end

-- Applies a kind again to a frame it styled, after a change Blizzard made.
local function Again(frame, kind)
	local entry = styled[frame] and styled[frame][kind]
	if entry and not entry.broken then
		Apply(kind, frame, entry, IsOn(kind, entry.group))
	end
end

-- The window a map is drawn in, for the border frame that lies over the map: its fill has to be made under the map.
local function MapWindow(frame)
	local parent = ParentOf(frame)
	if parent and Part(parent, "ScrollContainer") then
		return parent
	end
	return nil
end

-- Window frame. A page fills its window and has no box of its own (flag true). With the flag
-- "parchment" the Bg is a parchment the text is coloured for: it stays, and the rock under it goes.
-- With the flag "solid" the fill does not follow the window opacity.
Kind("window", "window frames", nil,
	function(frame, own, flag)
		if flag == "parchment" then
			own.parchment = true
			own.rock = RegionAt(frame, "BACKGROUND", -6)
		end
		if flag ~= true then
			Outlined(own, MapWindow(frame) or frame, frame, flag == "solid" and "solid" or "window")
		end
	end,
	function(frame, own, on)
		local nine = Part(frame, "NineSlice")
		if nine then
			for _, name in ipairs(PIECES) do
				Fade(Part(nine, name), on)
			end
		end
		local background = Part(frame, "Bg")
		if own.parchment then
			Fade(own.rock, on)
		elseif IsTexture(background) then
			Fade(background, on)
		elseif background then
			for _, name in ipairs(FLAT_BG) do
				Fade(Part(background, name), on)
			end
		end
		Fade(Part(nine, "Center"), on)
		for _, name in ipairs(PIECES) do
			Fade(Part(frame, name), on)
		end
		for _, name in ipairs(OWN_PIECES) do
			Fade(Part(frame, name), on)
		end
		Fade(Part(frame, "TopTileStreaks"), on)
		Fade(Part(frame, "TitleBg"), on)
		local portrait = Part(frame, "PortraitContainer")
		Fade(portrait and Part(portrait, "portrait"), on and not Opt("portrait"))
		-- A dialog keeps its border pieces and its background in one frame.
		local border = Part(frame, "Border")
		if border then
			for _, name in ipairs(PIECES) do
				Fade(Part(border, name), on)
			end
			Fade(Part(border, "Bg"), on)
		end
		ns.Items.Title(frame, on)
		Reveal(own, on)
	end,
	function(frame, flag)
		return flag ~= true and MapWindow(frame) or nil
	end)

-- Every texture drawn on a frame, for panels whose art has no field.
Kind("art", "window backgrounds", nil,
	function(frame, own, flag)
		own.depth = flag and flag.depth or 0
		own.keep = flag and flag.keep
	end,
	function(frame, own, on)
		Strip(frame, own.depth, on, own.keep)
	end)

-- A list of textures that are shown when an option is on, and faded otherwise.
Kind("fades", "window pictures", nil,
	function(frame, own, flag)
		own.list = flag.list
		own.unless = flag.unless
	end,
	function(frame, own, on)
		local fade = on and not (own.unless and Opt(own.unless))
		for _, region in ipairs(own.list) do
			Fade(region, fade)
		end
	end)

-- The eye of the Looking For Group window: with Show the eye off, the button, its picture and its six animated frames are transparent and the
-- button takes no mouse, so the eye does not look at the cursor or answer a click. Its mouse comes back with the setting.
Kind("eye", "looking for group eye", nil,
	function(frame, own)
		own.pieces = Pieces(Held(frame, "texture"))
		own.frames = Pieces(frame)
		for _, key in ipairs(EYE_FRAMES) do
			own.frames[#own.frames + 1] = Held(frame, key)
		end
	end,
	function(frame, own, on)
		local fade = on and not Opt("eye")
		for _, region in ipairs(own.pieces) do
			Fade(region, fade)
		end
		for _, part in ipairs(own.frames) do
			Fade(part, fade, true)
		end
		if type(frame.EnableMouse) == "function" and not (InCombatLockdown() and Protected(frame)) then
			if fade and own.mouse == nil and type(frame.IsMouseEnabled) == "function" then
				local ok, taking = pcall(frame.IsMouseEnabled, frame)
				own.mouse = ok and not ns.IsSecret(taking) and taking ~= false
			end
			if fade then
				-- Without a readable state the mouse is left as it is: it could not be given back.
				if own.mouse ~= nil then
					pcall(frame.EnableMouse, frame, false)
				end
			elseif own.mouse ~= nil then
				pcall(frame.EnableMouse, frame, own.mouse)
				own.mouse = nil
			end
		end
	end)

Kind("inset", "insets", nil,
	function() end,
	function(frame, own, on)
		Fade(Part(frame, "Background"), on)
		Fade(Part(frame, "Bg"), on)
		local nine = Part(frame, "NineSlice")
		if nine then
			for _, name in ipairs(PIECES) do
				Fade(Part(nine, name), on)
			end
		end
	end)

-- Close button: a cross with no box. With a pane, the same button is a chevron that shows
-- which way the pane opens.
Kind("close", "close buttons", "buttons",
	function(frame, own, pane)
		own.pane = pane
		local shape = pane and "left" or "x"
		own.glyph = Glyph(own, frame, frame, { layer = "OVERLAY", shape = shape, role = "white", alpha = 0.6, size = 10 })
		own.hover = Glyph(own, frame, frame, { layer = "HIGHLIGHT", shape = shape, role = "accent", alpha = 1, size = 10 })
	end,
	function(frame, own, on)
		for _, which in ipairs(STATES) do
			Fade(State(frame, which), on)
		end
		Fade(Part(frame, "Border"), on)
		if own.glyph and own.pane and not ns.Forbidden(own.pane) then
			local shape = Shown(own.pane) and "left" or "right"
			if own.glyph.shape ~= shape then
				Place(own.glyph, shape)
				Place(own.hover, shape)
			end
		end
		Reveal(own, on)
	end)

-- With the flag "plain" the button has a plate in each state and no parts, as the buttons of pop-ups do.
Kind("button", "buttons", "buttons",
	function(frame, own, flag)
		own.plain = flag == "plain"
		Outlined(own, frame, frame, "panel")
		Tint(own, frame, frame, "HIGHLIGHT", "accent", 0.25)
	end,
	function(frame, own, on)
		for _, key in ipairs({ "Left", "Middle", "Center", "Right" }) do
			Fade(Part(frame, key), on)
		end
		Fade(State(frame, "Highlight"), on)
		if own.plain then
			for _, which in ipairs(STATES) do
				Fade(State(frame, which), on)
			end
		end
		Reveal(own, on)
	end)

-- Bottom tab: the same box whether selected or not. Blizzard's label colour tells them apart.
Kind("tab", "tabs", "tabs",
	function(frame, own)
		-- A tab that hangs from the top of its window has its edge at the bottom.
		local top, bottom = 1, 3
		if Field(frame, "isTabOnTop") == true or Field(frame, "isTopTab") == true then
			top, bottom = bottom, top
		end
		local box = Box(frame, frame, 3, 3, top, bottom)
		Outlined(own, frame, box, "panel")
		Tint(own, frame, box, "HIGHLIGHT", "accent", 0.25)
	end,
	function(frame, own, on)
		FadeArray(frame, "TabTextures", on)
		FadeArray(frame, "RotatedTextures", on)
		for _, key in ipairs(TAB_SQUARES) do
			Fade(Part(frame, key), on)
		end
		Reveal(own, on)
	end)

-- Side tab size. The icon side in units for each choice of Side tab size; Game's size has none. The game's tab is 5 units
-- larger than its icon: it is the common-sidetab atlas of 55 by 60 without its 5 of empty height, set once when the tab loads
-- (AtlasInfo.lua:3761-3765, SharedUIPanelTemplates.lua:309-329), around the 50 by 50 icon that every SetChecked sets again
-- (SharedUIPanelTemplates.lua:381-399). The windows chain their tabs, each from the bottom left of the one above, so a smaller
-- tab closes the column up and no anchor is written here (CharacterFrame.lua:207, BankFrame.lua:122, Blizzard_Collections.lua:128,
-- Blizzard_ProfessionsFrame.xml:29-39, Blizzard_LFGVanilla_ParentFrame.xml:113-123).
local TAB_ICONS = { large = 42, medium = 36, small = 30 }
local TAB_PADDING = 5

-- The width and height of a frame or region, unless the client withholds them or they are not a size yet.
local function SizeOf(region)
	if not Usable(region) then
		return nil
	end
	local ok, width, height = pcall(region.GetSize, region)
	if ok and not ns.IsSecret(width) and not ns.IsSecret(height) and type(width) == "number" and type(height) == "number"
		and width > 0 and height > 0 then
		return width, height
	end
	return nil
end

-- Gives a frame or region a square size, or the size the game gave it. Any size other than the one set here is the
-- game's: the first one read, and the one the game sets again on SetChecked. Nothing is written until the game's is known.
local function FitSquare(own, key, region, side)
	local fit = own[key]
	if not fit then
		fit = {}
		own[key] = fit
	end
	local width, height = SizeOf(region)
	if width and not (fit.set and width == fit.set and height == fit.set) then
		fit.gameWidth, fit.gameHeight = width, height
	end
	if side then
		if fit.gameWidth then
			if width ~= side or height ~= side then
				pcall(region.SetSize, region, side, side)
			end
			fit.set = side
		end
	elseif fit.set and width then
		if width == fit.set and height == fit.set then
			pcall(region.SetSize, region, fit.gameWidth, fit.gameHeight)
		end
		fit.set = nil
	end
end

-- The mask that rounds the corners of the icon (Square side tab icons off) is the atlas of 55 by 60, centred on the tab (Blizzard_SharedXML/
-- Mainline/SharedUIPanelTemplates.xml:1026-1033, AtlasInfo.lua:3770) while the icon sits at the offsets the game gives it, -4 and 0 on Forever
-- (SharedUIPanelTemplates.lua:331-345, Camelot/SharedUIPanelTemplates.lua:8-10), and it is cut for an icon of 50 (SharedUIPanelTemplates.lua:381-387).
-- A smaller icon needs a mask smaller in the same ratio that lies in the same place on the icon, so the mask is scaled about the centre of the icon.
-- SetPoint on the point CENTER moves the anchor the game made, as the game moves the icon's (SharedUIPanelTemplates.lua:352-357), so none is cleared.
-- GetPoint gives withheld values only when the anchoring is withheld (SimpleScriptRegionResizingAPIDocumentation.lua:65-86).
local ICON_EXTENT = 50

local function Holds(fit)
	return fit ~= nil and fit.set ~= nil
end

-- Gives the mask of a side tab the size and place it has for an icon of the side given, or the game's when there is none. Nothing is
-- done when the icon is not at the centre of the tab, or the mask's size or the icon's place cannot be read.
local function FitMask(frame, own, side)
	local mask, icon = own.mask, own.icon
	local fit = own.maskFit
	if not fit then
		if not side then
			return
		end
		local width, height = SizeOf(mask)
		local ok, point, anchor, relative, x, y = pcall(icon.GetPoint, icon, 1)
		if not width or not ok or ns.IsSecret(point) or ns.IsSecret(anchor) or ns.IsSecret(relative) or ns.IsSecret(x) or ns.IsSecret(y) then
			return
		end
		if point ~= "CENTER" or relative ~= "CENTER" or anchor ~= frame or type(x) ~= "number" or type(y) ~= "number" then
			return
		end
		fit = { width = width, height = height, x = x, y = y }
		own.maskFit = fit
	end
	if side and fit.set ~= side then
		local ratio = side / ICON_EXTENT
		pcall(mask.SetSize, mask, fit.width * ratio, fit.height * ratio)
		pcall(mask.SetPoint, mask, "CENTER", frame, "CENTER", fit.x * (1 - ratio), fit.y * (1 - ratio))
		fit.set = side
	elseif not side and fit.set then
		pcall(mask.SetSize, mask, fit.width, fit.height)
		pcall(mask.SetPoint, mask, "CENTER", frame, "CENTER", 0, 0)
		fit.set = nil
	end
end

-- The icon and the tab of a side tab at the chosen size, or at the game's. Only a tab that fills its icon to the interior
-- (fillToInterior, which sets the icon size in UpdateIconInterior) is sized; the others keep the art's own sizes, and nothing waits
-- for them. SetSize and SetPoint are protected functions (SimpleScriptRegionResizingAPIDocumentation.lua:162-173, 135-149), so a protected
-- tab waits for the end of combat, once however often it is asked. A tab whose part stopped in the meantime is given its sizes back there,
-- as Again leaves a stopped entry alone.
local function SizeSideTab(frame, own, on)
	local side = on and Field(frame, "fillToInterior") == true and TAB_ICONS[Opt("sideTabSize")] or nil
	if not side and not (Holds(own.tabFit) or Holds(own.iconFit) or Holds(own.maskFit)) then
		return
	end
	if InCombatLockdown() and Protected(frame) then
		if not own.sizeWaits then
			own.sizeWaits = true
			ns.OutOfCombat(function()
				own.sizeWaits = nil
				if own.broken then
					SizeSideTab(frame, own, false)
				else
					Again(frame, "sideTab")
				end
			end)
		end
		return
	end
	FitSquare(own, "tabFit", frame, side and side + TAB_PADDING)
	FitSquare(own, "iconFit", own.icon, side)
	FitMask(frame, own, side and own.mask and not Opt("squareTabs") and side or nil)
end

-- A side tab is read again after the game chose a tab: its checked state is what the game's SetChecked set. The title colour of the
-- character window is set again by the same calls.
function Watch.ReadSideTab(frame, entry)
	do
		-- LargeSideTabButtonTemplate is a Frame with no GetChecked (SharedUIPanelTemplates.xml:1008); SetChecked is a Lua method that shows or
		-- hides its SelectedTexture (SharedUIPanelTemplates.lua:389-399), so the texture is read. A check button answers GetChecked.
		if type(frame.GetChecked) == "function" then
			local ok, checked = pcall(frame.GetChecked, frame)
			if ok and not ns.IsSecret(checked) and type(checked) == "boolean" then
				entry.checked = checked
			end
		else
			entry.checked = Shown(Part(frame, "SelectedTexture"))
		end
	end
end

function Watch.ResetSideTab(frame)
	local entry = styled[frame] and styled[frame].sideTab
	if entry then
		Watch.ReadSideTab(frame, entry)
		Again(frame, "sideTab")
	end
end

-- Choosing one tab unchecks the others, so every styled side tab is read again, not the one that was clicked or shown alone.
function Watch.RefreshSideTabs()
	for frame, entries in pairs(styled) do
		if entries.sideTab then
			Soon("side tabs", Watch.ResetSideTab, frame)
		end
	end
	ns.Items.Retitle()
end

Watch.SideTabChanged = Watch.RefreshSideTabs

-- Side tab: a square icon with a thin border. flag "sidebar" is a sidebar tab of the character
-- window, a check button whose own checked texture becomes the selected tint.
Kind("sideTab", "side tabs", "sideTabs",
	function(frame, own, flag)
		own.sidebar = flag == "sidebar"
		own.icon = Part(frame, "Icon")
		if not own.icon then
			error("no icon", 0)
		end
		Outlined(own, frame, own.icon, "panel")
		Tint(own, frame, own.icon, "HIGHLIGHT", "white", HOVER[4], "ADD")
		if own.sidebar then
			Retint(State(frame, "Checked"), own.icon, HOVER)
			return
		end
		own.mask = Part(frame, "Mask")
		own.selected = Tint(own, frame, own.icon, "OVERLAY", "white", HOVER[4], "ADD", true)
		own.checked = Shown(Part(frame, "SelectedTexture"))
		-- Blizzard sets the icon's texture coordinates and size again on every SetChecked (SharedUIPanelTemplates.lua:389-399), which its windows
		-- call from their own methods. A tab is looked at again a frame after it is shown or clicked and after the game's functions that
		-- choose a tab (Watch.RefreshSideTabs, Watch.SideTabChanged), and its checked state is read then. The template has no OnClick: it
		-- runs OnMouseUp (SharedUIPanelTemplates.lua:359).
		HookScript(frame, "OnMouseUp", Watch.SideTabChanged)
		HookScript(frame, "OnShow", Watch.SideTabChanged)
	end,
	function(frame, own, on)
		if own.sidebar then
			if own.ring == nil then
				own.ring = ns.RegionWithAtlas(frame, STAT_TAB_RING) or false
				if not own.ring then
					ns.Note(KEY, "Windows: the default border of a sidebar tab was not found and is still shown.")
				end
			end
			Fade(own.ring or nil, on)
		else
			Fade(Part(frame, "Background"), on)
			Fade(Part(frame, "SelectedTexture"), on)
			Fade(Part(frame, "HighlightTexture"), on)
		end
		local square = on and Opt("squareTabs")
		if own.mask and IsTexture(own.icon) then
			if square and not own.unmasked then
				own.unmasked = pcall(own.icon.RemoveMaskTexture, own.icon, own.mask)
			elseif not square and own.unmasked then
				own.unmasked = not pcall(own.icon.AddMaskTexture, own.icon, own.mask)
			end
		end
		if square then
			Crop(own.icon, Opt("crop") / 100)
		else
			Uncrop(own.icon)
		end
		SizeSideTab(frame, own, on)
		Reveal(own, on)
		if own.selected then
			Show(own.selected, on and own.checked == true)
		end
	end)

-- The item button behind a hook argument, if this addon styled it.
local function SlotOf(button)
	if button == nil or ns.IsSecret(button) or type(button) ~= "table" then
		return nil
	end
	local own = slots[button]
	if own and not own.broken then
		return own
	end
	return nil
end

local function ItemIcon(button)
	local icon = Part(button, "Icon") or Part(button, "icon")
	if icon then
		return icon
	end
	local name = NameOf(button)
	return name and Part(_G, name .. "IconTexture") or nil
end

-- Red in the red channel only, which is how the game marks an item that is broken or cannot be used.
-- Grey marks an item that is sold out.
local function IsRed(r, g, b)
	return type(r) == "number" and r > 0 and g == 0 and b == 0
end

-- Item slot: a box with the quality colour as its edge. The ammo slot has no quality border. With the
-- flag "still" the icon is not cropped: the game puts a picture of an empty slot there and takes it away again.
Kind("slot", "item slots", "slots",
	function(frame, own, flag)
		own.icon = ItemIcon(frame)
		own.still = flag == "still"
		own.ammo = NameOf(frame) == AMMO_SLOT
		Outlined(own, frame, frame, "panel")
		-- Where the game stands now: the border it shows and the colour of the slot's frame.
		local border = Part(frame, "IconBorder")
		if Shown(border) then
			local r, g, b = VertexColour(border)
			own.quality = r and { r, g, b } or nil
		end
		local r, g, b = VertexColour(State(frame, "Normal"))
		own.worn = r ~= nil and IsRed(r, g, b)
		slots[frame] = own
	end,
	function(frame, own, on)
		Fade(State(frame, "Normal"), on)
		Fade(Part(frame, "IconBorder"), on)
		local plate = Part(frame, "BorderFrame")
		if plate then
			Strip(plate, 0, on)
		end
		if own.ammo then
			if own.ring == nil then
				own.ring = ns.RegionWithAtlas(frame, AMMO_RING) or false
			end
			Fade(own.ring or nil, on)
		end
		if on and Opt("crop") > 0 and not own.still then
			Crop(own.icon, Opt("crop") / 100)
		else
			Uncrop(own.icon)
		end
		local r, g, b
		if on then
			if own.worn then
				r, g, b = BROKEN[1], BROKEN[2], BROKEN[3]
			elseif own.quality and Opt("quality") and not own.ammo and ns.Items.Passes(own.quality) then
				r, g, b = own.quality[1], own.quality[2], own.quality[3]
			end
		end
		if own.outlines[1] then
			ns.SetOutlineColour(own.outlines[1].outline, r, g, b)
		end
		if on and not dry and Opt("slotTints") and not own.tinted then
			own.tinted = true
			local function Tinted()
				Retint(State(frame, "Highlight"), frame, HOVER)
				Retint(State(frame, "Pushed"), frame, SLOT_PRESSED)
			end
			if InCombatLockdown() and Protected(frame) then
				ns.OutOfCombat(Tinted)
			else
				Tinted()
			end
		end
		ns.Items.Slot(frame)
		Reveal(own, on)
	end)

Kind("scroll", "scroll bars", "scroll",
	function(frame, own)
		local track = Part(frame, "Track")
		local thumb = Part(track, "Thumb")
		Tint(own, track, track, "BACKGROUND", "black", 0.3)
		Tint(own, thumb, thumb, "ARTWORK", "accent", 0.25)
		Tint(own, thumb, thumb, "HIGHLIGHT", "accent", 0.5)
		for key, shape in pairs({ Back = "up", Forward = "down" }) do
			local arrow = Part(frame, key)
			Glyph(own, arrow, arrow, { layer = "OVERLAY", shape = shape, role = "white", alpha = 0.6, size = 6 })
			Glyph(own, arrow, arrow, { layer = "HIGHLIGHT", shape = shape, role = "accent", alpha = 1, size = 6 })
		end
	end,
	function(frame, own, on)
		local track = Part(frame, "Track")
		local thumb = Part(track, "Thumb")
		for _, key in ipairs(SCROLL_PARTS) do
			Fade(Part(track, key), on)
			Fade(Part(thumb, key), on)
		end
		Fade(Part(Part(frame, "Back"), "Texture"), on)
		Fade(Part(Part(frame, "Forward"), "Texture"), on)
		Reveal(own, on)
	end)

Kind("check", "check boxes", "checks",
	function(frame, own)
		local box = Box(frame, frame, 4, 4, 4, 4)
		Outlined(own, frame, box, "panel")
		Retint(State(frame, "Checked"), frame, CHECK_ON, 6)
		Retint(State(frame, "DisabledChecked"), frame, CHECK_OFF, 6)
		Retint(State(frame, "Highlight"), box, HOVER)
	end,
	function(frame, own, on)
		Fade(State(frame, "Normal"), on)
		Fade(State(frame, "Pushed"), on)
		Reveal(own, on)
	end)

-- Text box. A single line has its caps on the box and is outlined by its parent, because nothing
-- is created on an edit box. A box with several lines is a scroll frame and outlines itself.
Kind("edit", "text boxes", "inputs",
	function(frame, own, flag)
		own.multi = flag == "multi"
		if own.multi then
			Outlined(own, frame, frame, "panel")
			return
		end
		local parent = ParentOf(frame)
		if not parent or ns.Forbidden(parent) then
			error("no parent", 0)
		end
		Outlined(own, parent, Box(parent, frame, -5, 0, 0, 0), "panel")
	end,
	function(frame, own, on)
		for _, key in ipairs(own.multi and MULTI_LINE_CAPS or EDIT_CAPS) do
			Fade(EditCap(frame, key), on)
		end
		Reveal(own, on)
	end,
	function(frame, flag)
		return flag ~= "multi" and ParentOf(frame) or nil
	end)

Kind("dropdown", "dropdowns", "inputs",
	function(frame, own)
		Outlined(own, frame, frame, "panel")
		Tint(own, frame, frame, "HIGHLIGHT", "accent", 0.25)
		Glyph(own, frame, frame, { layer = "OVERLAY", shape = "down", role = "white", alpha = 0.8, size = 8, point = "RIGHT", x = -12 })
	end,
	function(frame, own, on)
		Fade(Part(frame, "Background"), on)
		Fade(Part(frame, "Arrow"), on)
		Reveal(own, on)
	end)

Kind("bar", "progress bars", "bars",
	function(frame, own)
		Outlined(own, frame, Box(frame, frame, 0, 0, 0, 0, 15), "window")
		own.fill = Part(frame, "Fill")
		own.mask = Part(frame, "Mask")
		own.back = ns.RegionWithAtlas(frame, BAR_BACKGROUND)
		if not own.back then
			ns.Note(KEY, "Windows: the default background of a progress bar was not found and is still shown.")
		end
	end,
	function(frame, own, on)
		Fade(own.back, on)
		if IsTexture(own.fill) and own.mask then
			if on and not own.unmasked then
				own.unmasked = pcall(own.fill.RemoveMaskTexture, own.fill, own.mask)
			elseif not on and own.unmasked then
				own.unmasked = not pcall(own.fill.AddMaskTexture, own.fill, own.mask)
			end
		end
		Reveal(own, on)
	end)

-- A one pixel line down the left edge of a pane in place of Blizzard's divider. It goes with the other borders.
Kind("divider", "dividers", nil,
	function(frame, own)
		if dry then
			return
		end
		own.line = Mine(frame:CreateTexture(nil, "OVERLAY", nil, 7))
		own.line:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -1)
		own.line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	end,
	function(frame, own, on)
		if not own.line then
			return
		end
		local r, g, b = ns.BorderRGB()
		own.line:SetWidth(ns.Pixels(frame, ns.Get("general.thickness")))
		own.line:SetColorTexture(r, g, b, 1)
		own.line:SetShown(on and not ns.Borderless())
	end)

-- A category of the Looking For Group list: the picture stays, with a box around it.
Kind("category", "category buttons", "buttons",
	function(frame, own)
		local icon = Part(frame, "Icon")
		if not icon then
			error("no icon", 0)
		end
		Outlined(own, frame, icon, "panel")
		Tint(own, frame, icon, "HIGHLIGHT", "white", 0.1, "ADD")
	end,
	function(frame, own, on)
		Fade(Part(frame, "Cover"), on)
		Fade(State(frame, "Pushed"), on)
		Fade(State(frame, "Highlight"), on)
		Reveal(own, on)
	end)

-- A vendor button that shows a picture on a slot: the picture stays, the slot is replaced.
Kind("iconButton", "vendor buttons", "buttons",
	function(frame, own)
		own.icon = Part(frame, "Icon")
		Outlined(own, frame, frame, "panel")
		Tint(own, frame, frame, "HIGHLIGHT", "white", 0.3, "ADD")
	end,
	function(frame, own, on)
		Strip(frame, 0, on, own.icon)
		Reveal(own, on)
	end)

-- A header of the character window's stat list: the rounded plate goes and a flat band takes its place.
Kind("plate", "stat headers", "buttons",
	function(frame, own)
		Outlined(own, frame, Box(frame, frame, 0, 0, 0, 0, 22), "panel")
	end,
	function(frame, own, on)
		Fade(Part(frame, "Background"), on)
		Reveal(own, on)
	end)

-- A header in a list that folds: a plate in the button states, or three slices, and a flat box in their place.
Kind("header", "list headers", "rows",
	function(frame, own)
		Outlined(own, frame, frame, "panel")
		Tint(own, frame, frame, "HIGHLIGHT", "accent", 0.25)
	end,
	function(frame, own, on)
		Fade(State(frame, "Normal"), on)
		Fade(State(frame, "Highlight"), on)
		for _, key in ipairs(EDIT_CAPS) do
			Fade(Part(frame, key), on)
		end
		FadeArray(frame, "HighlightTextureRegions", on)
		Reveal(own, on)
	end)

-- A line in a list that has a stripe, a hover bar and a bar for the selected line: the stripe and the hover bar go, a flat
-- tint takes the hover, and the selected bar, which the game shows and hides, becomes a flat colour.
Kind("line", "list lines", "rows",
	function(frame, own)
		own.selected = Part(frame, "SelectedHighlight") or Part(frame, "SelectedTexture")
		Tint(own, frame, frame, "HIGHLIGHT", "accent", 0.25)
	end,
	function(frame, own, on)
		Fade(Part(frame, "NormalTexture"), on)
		Fade(State(frame, "Normal"), on)
		Fade(Part(frame, "HighlightTexture"), on)
		Fade(State(frame, "Highlight"), on)
		if on and not dry and not own.tinted then
			own.tinted = true
			Retint(own.selected, frame, HOVER)
		end
		Reveal(own, on)
	end)

-- An open menu. The game takes a menu frame from a pool and draws its background on it each time it opens, in a texture that
-- is a row icon the next time. The box lies in a frame of this addon's inside the menu, which stays with the menu.
Kind("menu", "menus", nil,
	function(frame, own)
		if dry then
			return
		end
		own.box = Mine(CreateFrame("Frame", nil, frame))
		own.box:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		own.box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
		own.gap = 0
		Outlined(own, own.box, own.box, "solid")
	end,
	function(frame, own, on)
		-- The game's background goes only where the box is to take its place, and the box moves only when the gap changes,
		-- not at all in combat on a menu that hangs from a protected frame.
		for _, style in ipairs(MENU_BACKGROUNDS) do
			local background = own.box and ns.RegionWithAtlas(frame, style[1])
			if background then
				Fade(background, on)
				if own.gap ~= style[2] and not (InCombatLockdown() and Protected(frame)) then
					own.box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, style[2])
					own.gap = style[2]
				end
			end
		end
		Reveal(own, on)
	end)

-- Sweeping a window --------------------------------------------------------------------------------

local function IsClose(frame)
	if type(frame.GetNormalTexture) ~= "function" then
		return false
	end
	-- The Close button of the options window is a push button that the game keys as CloseButton.
	if Part(frame, "Left") and Part(frame, "Right") then
		return false
	end
	local name = NameOf(frame)
	if name and name:find("CloseButton$") then
		return true
	end
	local parent = ParentOf(frame)
	if parent and Part(parent, "CloseButton") == frame then
		return true
	end
	local normal = State(frame, "Normal")
	if normal then
		local ok, atlas = pcall(normal.GetAtlas, normal)
		return ok and not ns.IsSecret(atlas) and type(atlas) == "string" and atlas:lower():find("^redbutton%-exit") ~= nil
	end
	return false
end

-- A check box is a check button of about the size of one that has no picture of its own.
local function IsCheck(frame)
	if type(frame.GetCheckedTexture) ~= "function" or Part(frame, "Icon") or Part(frame, "icon") or Part(frame, "Name") then
		return false
	end
	local ok, width, height = pcall(frame.GetSize, frame)
	if not ok or ns.IsSecret(width) or ns.IsSecret(height) or type(width) ~= "number" or type(height) ~= "number" then
		return false
	end
	return width >= 20 and width <= 32 and height >= 20 and height <= 32 and math.abs(width - height) <= 2 and State(frame, "Checked") ~= nil
end

local function IsWindow(frame)
	local nine = Part(frame, "NineSlice")
	if not nine then
		return false
	end
	for _, name in ipairs(PIECES) do
		if not Part(nine, name) then
			return false
		end
	end
	return Part(frame, "TitleContainer") ~= nil or Part(frame, "CloseButton") ~= nil or Part(frame, "PortraitContainer") ~= nil
end

-- The kind of a Blizzard frame, from the fields its template gives it, and a flag for that kind.
local function Classify(frame)
	local track = Part(frame, "Track")
	if track and Part(track, "Thumb") and Part(frame, "Back") and Part(frame, "Forward") then
		return "scroll"
	end
	if Part(frame, "Background") and Part(frame, "Icon") and Part(frame, "Mask") and Part(frame, "SelectedTexture") and Part(frame, "TabGlow") then
		return "sideTab"
	end
	if Part(frame, "Left") and Part(frame, "LeftActive") and (Part(frame, "TabTextures") or Part(frame, "RotatedTextures")) then
		return "tab"
	end
	if Part(frame, "IconBorder") and (Part(frame, "icon") or Part(frame, "Icon")) and Part(frame, "NormalTexture") then
		return "slot", type(Field(frame, "emptyBackgroundAtlas")) == "string" and "still" or nil
	end
	if IsClose(frame) then
		return "close"
	end
	if Part(frame, "Background") and Part(frame, "Text") and (Part(frame, "Arrow") or Part(frame, "ResetButton")) and type(frame.SetupMenu) == "function" then
		return "dropdown"
	end
	if IsCheck(frame) then
		return "check"
	end
	if type(frame.HighlightText) == "function" and EditCap(frame, "Left") and EditCap(frame, "Middle") and EditCap(frame, "Right") then
		return "edit"
	end
	if Part(frame, "TopLeftTex") and Part(frame, "MiddleTex") then
		return "edit", "multi"
	end
	if Part(frame, "Left") and Part(frame, "Right") and not Part(frame, "LeftActive") then
		if Part(frame, "Middle") and Part(frame, "Text") and not Part(frame, "Center") then
			return "button"
		elseif Part(frame, "Center") and type(Field(frame, "atlasName")) == "string" then
			return "button"
		end
	end
	if Part(frame, "Flash") and Part(frame, "Text") and type(Field(frame, "baseWidth")) == "number" and State(frame, "Normal") then
		return "button", "plain"
	end
	if Part(frame, "Fill") and Part(frame, "Mask") and Part(frame, "Text") and type(frame.SetFillPercent) == "function" then
		return "bar"
	end
	if Part(frame, "NineSlice") and Part(frame, "Bg") and Field(frame, "layoutType") == "InsetFrameTemplate" then
		return "inset"
	end
	-- The panels of the auction house keep the picture in a Background.
	if Part(frame, "NineSlice") and Part(frame, "Background") and "InsetFrameTemplate" == Field(frame, "layoutType") then
		return "inset"
	end
	if IsWindow(frame) then
		return "window"
	end
	return nil
end

-- The kind of a row of a list that Classify has no kind for: a line with a selected bar, or a header that folds.
local function RowKind(frame)
	if Part(frame, "HighlightTexture") and (Part(frame, "SelectedHighlight") or Part(frame, "SelectedTexture")) then
		return "line"
	end
	local folds = Part(frame, "CollapseButton") ~= nil and State(frame, "Normal") ~= nil
	local sliced = Part(frame, "Left") and Part(frame, "Middle") and Part(frame, "Right") and Part(frame, "HighlightMiddle")
	if folds or sliced then
		return "header"
	end
	return nil
end

-- Kinds that hold other controls, so the sweep goes on inside them.
local HOLDS = { inset = true, window = true }

-- Hooks the scroll list of a window, and looks at the rows it has.
local Rows

-- Looks at one child. The result is left in state.descend.
local function Visit(child, group, state)
	state.descend = false
	if ns.Forbidden(child) or ns.Own[child] or state.skip[child] then
		return
	end
	-- Cooldowns and models draw their own art.
	if type(child.SetCooldown) == "function" or type(child.CreateActor) == "function" or type(child.SetDisplayInfo) == "function" then
		return
	end
	if state.pages[child] then
		state.descend = true
		return
	end
	local kind, flag = Classify(child)
	if not kind and state.rows then
		kind = RowKind(child)
	end
	if kind then
		Style(kind, child, group, flag)
		-- A box with several lines holds its scroll bar.
		state.descend = HOLDS[kind] == true or flag == "multi"
	else
		-- A list makes its rows when it is shown: they are looked at after each update of the list.
		if Part(child, "ScrollTarget") then
			Rows(child, group)
		end
		state.descend = type(child.HighlightText) ~= "function" and Part(child, "ScrollTarget") == nil
	end
end

-- True when a frame holds a frame of Blizzard's that a sweep may look at.
local function HoldsFrames(frame)
	for _, child in ipairs(Children(frame)) do
		if not ns.Forbidden(child) and not ns.Own[child] then
			return true
		end
	end
	return false
end

-- A window the sweep did not search to the end.
local function TooLarge(state)
	ns.Note(KEY, ("Windows: part of the %s window is too large and keeps Blizzard's look."):format(state.title))
end

local function Walk(frame, group, state, depth)
	if depth > MAX_DEPTH then
		if HoldsFrames(frame) then
			TooLarge(state)
		end
		return
	end
	for _, child in ipairs(Children(frame)) do
		if state.count >= MAX_FRAMES then
			TooLarge(state)
			return
		end
		state.count = state.count + 1
		if ns.EachPart(KEY, "search for controls", Visit, child, group, state) and state.descend then
			Walk(child, group, state, depth + 1)
		end
	end
end

-- Looks at the children of a frame that nothing has styled yet. The game makes item slots and tabs
-- when it updates a window and keeps them for the next time.
local function StyleNew(frame, group, skip)
	local state = { count = 0, title = "", pages = {}, skip = skip or {} }
	for _, child in ipairs(Children(frame)) do
		if not styled[child] then
			ns.EachPart(KEY, "search for controls", Visit, child, group, state)
		end
	end
end

-- The rows that were looked at: a row keeps its template as the list gives it other data.
local looked = setmetatable({}, { __mode = "k" })

local function StyleRows(box, group)
	if not IsOn("line", group) then
		return
	end
	local target = Held(box, "ScrollTarget")
	for _, row in ipairs(target and Children(target) or {}) do
		if Usable(row) and not looked[row] then
			looked[row] = true
			local state = { count = 0, title = "list", pages = {}, skip = {}, rows = true }
			Visit(row, group, state)
			if state.descend then
				Walk(row, group, state, MAX_DEPTH - 2)
			end
		end
	end
end

-- A scroll box makes its rows when it is shown and again as it scrolls. It announces the end of each of its updates on its own callback
-- registry (Blizzard_SharedXML/Shared/Scroll/ScrollBox.lua:557-558, 795), so each list is looked at a frame after that and when it is shown.
-- (EllesmereUIFriends/EllesmereUIFriends.lua:1098 registers on a scroll box the same way.)
do
	local watchedBoxes = setmetatable({}, { __mode = "k" })
	local boxOwners = setmetatable({}, { __mode = "k" })

	function Watch.Box(box, part, fn, group)
		local parts = watchedBoxes[box] or {}
		watchedBoxes[box] = parts
		if parts[part] then
			return
		end
		parts[part] = true
		local function Queue()
			Soon(part, fn, box, group)
		end
		HookScript(box, "OnShow", Queue)
		if type(box.RegisterCallback) == "function" then
			local owner = boxOwners[box] or {}
			boxOwners[box] = owner
			pcall(box.RegisterCallback, box, "OnUpdate", Queue, owner)
		end
	end
end

function Rows(box, group)
	Watch.Box(box, "list rows", StyleRows, group)
	ns.EachPart(KEY, "list rows", StyleRows, box, group)
end

-- The pane toggle of the character window follows the pane. Opening or closing the pane runs the game's RefreshDisplay, whose
-- SetChecked gives every mode tab icon 50 again (CharacterFrame.lua:300-301, 265-271, 217-229; the size 50 is set at
-- Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:381-387), so the side tabs are sized again too.
Watch.toggles = setmetatable({}, { __mode = "k" })

function Watch.PaneChanged()
	Watch.RefreshSideTabs()
	for toggle in pairs(Watch.toggles) do
		Soon("close buttons", Again, toggle, "close")
	end
end

-- The tab with the player's portrait draws it again on the game's portrait and talent events and when the window is shown.
Watch.portraitTabs = setmetatable({}, { __mode = "k" })

function Watch.PortraitChanged()
	for tab in pairs(Watch.portraitTabs) do
		Soon("side tabs", Watch.ResetSideTab, tab)
	end
end

-- Windows with their own parts ------------------------------------------------------------------------

-- The stat list is made by a scroll box, so its headers are styled after the box has laid them out.
local function StyleHeaders(box, group)
	local target = Held(box, "ScrollTarget")
	for _, child in ipairs(target and Children(target) or {}) do
		if Usable(child) and not styled[child] and not ns.Forbidden(child) and Part(child, "Background") and Part(child, "Title") then
			Style("plate", child, group)
		end
	end
end

local STAT_LISTS = { "CharacterStatsPaneScrollBox", "CharacterStatsPanePetScrollBox" }

local function CharacterExtras(root, group)
	for index = 1, 4 do
		local tab = _G["PaperDollSidebarTab" .. index]
		if Usable(tab) then
			Style("sideTab", tab, group, "sidebar")
		end
	end
	local pane = Part(root, "RightPaneHost")
	local toggle = Part(root, "RightPaneToggleButton")
	if toggle and pane then
		Style("close", toggle, group, pane)
		-- The game's UpdateRightPaneToggleButton runs when the window is shown and when the pane opens or closes (CharacterFrame.lua:306-320,
		-- 728-732); the shape follows the pane, so the toggle is looked at again a frame after each of those.
		Watch.toggles[toggle] = true
		HookScript(toggle, "OnClick", Watch.PaneChanged)
		HookScript(pane, "OnShow", Watch.PaneChanged)
		HookScript(pane, "OnHide", Watch.PaneChanged)
		HookScript(root, "OnShow", Watch.PaneChanged)
	end
	-- The tab with the player's portrait gets its texture coordinates from the game again.
	local portraitTab = Held(Held(root, "ModeTabs"), "CharacterTab")
	if portraitTab then
		-- The game draws it again when the window is shown and on the portrait and talent events (CharacterFrame.lua:160-164, 380-405).
		Watch.portraitTabs[portraitTab] = true
		HookScript(root, "OnShow", Watch.PortraitChanged)
	end
	local scene = _G.CharacterModelScene
	if Usable(scene) and not ns.Forbidden(scene) then
		local list = {}
		for _, name in ipairs(RACE_ART) do
			list[#list + 1] = Part(scene, name)
		end
		Style("fades", scene, group, { list = list, unless = "raceArt" })
	end
	if pane then
		Style("divider", pane, group)
	end
	-- The pet's experience bar is inside the model scene, which the sweep does not enter.
	local petBar = _G.PetPaperDollFrameExpBar
	if Usable(petBar) then
		Style("bar", petBar, group)
	end
	local ammo = _G[AMMO_SLOT]
	if Usable(ammo) then
		Style("slot", ammo, group)
	end
	for _, name in ipairs(STAT_LISTS) do
		local box = Held(_G[name], "ScrollBox")
		if box then
			StyleHeaders(box, group)
			Watch.Box(box, "window details", StyleHeaders, group)
		end
	end
end

-- The categories are made one by one in Lua, so each is styled after the list is updated.
local function StyleCategories(view)
	if not Usable(view) or ns.Forbidden(view) then
		return
	end
	for _, button in ipairs(Part(view, "CategoryButtons") or {}) do
		Style("category", button, "groupfinder")
	end
end

local function GroupFinderExtras(root, group)
	local listing = _G.LFGListingFrame
	if not Usable(listing) or ns.Forbidden(listing) then
		return
	end
	StyleCategories(Part(listing, "CategoryView"))
	local roles = {}
	local solo = Held(listing, "SoloRoleButtons")
	for _, button in ipairs(Held(solo, "RoleButtons") or {}) do
		roles[#roles + 1] = button
	end
	local icon = Held(Held(listing, "GroupRoleButtons"), "RoleIcon")
	if icon then
		roles[#roles + 1] = icon
	end
	for _, button in ipairs(roles) do
		Style("fades", button, group, { list = Pieces(Held(button, "Background")), unless = "roleArt" })
	end
	local eye = _G.LFGParentFramePortrait
	if Usable(eye) then
		Style("eye", eye, group)
	end
end

-- The round picture at the top left of the Friends window is a texture of its own, and Blizzard sets
-- its file again when the tab changes.
local function FriendsExtras(root, group)
	Style("fades", root, group, { list = Pieces(_G.FriendsFrameIcon), unless = "portrait" })
end

-- The book at the top left of the quest log popup has no key or name.
local function QuestLogExtras(root, group)
	Style("fades", root, group, { list = Pieces(RegionAt(root, "OVERLAY", -1)), unless = "portrait" })
end

-- The seventh item of each side is the slot for the item that is not traded. Its picture stays.
local NOT_TRADED = { "TradePlayerItem7", "TradeRecipientItem7" }

-- The other player's portrait and its ring, the border pieces of the half they sit on, and the
-- art behind the two slots for the item that is not traded.
local function TradeExtras(root, group)
	local overlay = Held(root, "RecipientOverlay")
	Style("fades", overlay, group, { list = Pieces(Held(overlay, "portrait"), Held(overlay, "portraitFrame")), unless = "portrait" })
	Style("fades", root, group, { list = Pieces(_G.TradeRecipientBotLeftCorner, _G.TradeRecipientLeftBorder) })
	for _, name in ipairs(NOT_TRADED) do
		local cell = _G[name]
		Style("art", cell, group, { depth = 0, keep = RegionAt(cell, "ARTWORK", 0) })
	end
end

local function MerchantExtras(root, group)
	-- The bronze strip along the bottom, and the round plates behind the two page buttons.
	local list = Pieces(_G.MerchantFrameBottomLeftBorder)
	for _, name in ipairs(PAGE_BUTTONS) do
		list[#list + 1] = RegionAt(_G[name], "BACKGROUND", 0)
	end
	Style("fades", root, group, { list = list })
	for _, name in ipairs(MERCHANT_BUTTONS) do
		local button = _G[name]
		if Usable(button) then
			Style("iconButton", button, group)
		end
	end
end

-- The vendor's twelve items each sit on slot and name art that has no field.
local MERCHANT = { name = "MerchantFrame", title = "Vendor", group = "npc", special = MerchantExtras, strip = {} }
for index = 1, 12 do
	MERCHANT.strip[index] = "MerchantItem" .. index
end
MERCHANT.strip[13] = "MerchantBuyBackItem"
-- The two plates the money is shown on.
MERCHANT.strip[14] = "MerchantMoneyBg"
MERCHANT.strip[15] = "MerchantExtraCurrencyBg"

-- The trade window's items on each side sit on the same kind of art. TradeExtras does the seventh.
local TRADE = { name = "TradeFrame", title = "Trade", group = "npc", special = TradeExtras, strip = {} }
for index = 1, 6 do
	TRADE.strip[#TRADE.strip + 1] = "TradePlayerItem" .. index
	TRADE.strip[#TRADE.strip + 1] = "TradeRecipientItem" .. index
end
-- The plate the other player's money is shown on.
TRADE.strip[#TRADE.strip + 1] = "TradeRecipientMoneyBg"

-- The guild bank draws its frame, the red marble behind its slots and the seven columns of slots in textures of its own.
local GUILD_BANK = { name = "GuildBankFrame", title = "Guild bank", group = "guild", addon = "Blizzard_GuildBankUI", strip = { "GuildBankFrame" } }
for index = 1, 7 do
	GUILD_BANK.strip[#GUILD_BANK.strip + 1] = "GuildBankFrame.Column" .. index
end

-- The bag windows are shown with a direct Show and make their item slots when they update their items.
-- The game also sets the colour of their flat background each time a bag opens. ContainerFrame_GenerateFrame makes the slots, sets the
-- background and updates the items of a bag it opens (ContainerFrame.lua:1293-1312), and ContainerFrame_UpdateAll updates the items of every
-- open bag (:1267-1271), so a bag is looked at a frame after either, after BAG_UPDATE_DELAYED and BAG_NEW_ITEMS_UPDATED, and when it is shown.
Watch.bags = setmetatable({}, { __mode = "k" })

function Watch.BagChanged(root)
	local group = Watch.bags[root]
	if group then
		Soon("window details", StyleNew, root, group)
		Soon("item details", ns.Items.Bag, root)
		Soon(KINDS.window.label, Again, root, "window")
	end
end

function Watch.BagGenerated(frame)
	if type(frame) == "table" and not ns.IsSecret(frame) then
		Watch.BagChanged(frame)
	end
end

function Watch.BagsUpdated()
	for root in pairs(Watch.bags) do
		Watch.BagChanged(root)
	end
end

local function BagExtras(root, group)
	-- The coin box at the bottom is a frame of three pieces.
	local border = Held(Held(root, "MoneyFrame"), "Border")
	Style("fades", border, group, { list = Keyed(border, EDIT_CAPS) })
	Watch.bags[root] = group
	HookScript(root, "OnShow", Watch.BagChanged)
end

-- The bank takes its page tabs and bag buttons from a pool when it is shown, and its item slots when
-- it lays out a page. The game announces a page it lays out on its registry ("BankPanelMixin.PageInfoChanged", BankFrameTemplates.lua:1080,
-- 1117, 1132) and sends BANK_TABS_CHANGED when the tabs change (Camelot/BankFrame.lua:239-247), so the bank is looked at a frame after
-- either and when it is shown.
Watch.banks = setmetatable({}, { __mode = "k" })

function Watch.BankChanged(root)
	local entry = Watch.banks[root]
	if entry then
		if entry.panel then
			Soon("window details", StyleNew, entry.panel, entry.group)
		end
		Soon("window details", StyleNew, root, entry.group)
		Watch.RefreshSideTabs()
	end
end

function Watch.BanksChanged()
	for root in pairs(Watch.banks) do
		Watch.BankChanged(root)
	end
end

local function BankExtras(root, group)
	local panel = Held(root, "BankPanel")
	if panel then
		Style("inset", panel, group)
		Style("art", Held(panel, "EdgeShadows"), group)
	end
	Watch.banks[root] = { panel = panel, group = group }
	HookScript(root, "OnShow", Watch.BankChanged)
end

-- The plate behind the title of a dialog is a frame of its own.
local function DialogExtras(root, group)
	Style("art", Held(root, "Header"), group)
end

-- The background of a pop-up is two textures in a frame of their own.
local function PopupExtras(root, group)
	Style("art", Held(root, "BG"), group)
end

-- The dialog that confirms a purchase has the border of a dialog.
local function AuctionExtras(root, group)
	Style("window", Held(root, "BuyDialog"), group)
end

-- The guild portrait, and the tabard that takes its place for a guild, are pictures the portrait setting shows.
local COMMUNITIES_PICTURES = { "Portrait", "TabardBackground", "TabardEmblem", "TabardBorder" }

local function CommunitiesExtras(root, group)
	local overlay = Held(root, "PortraitOverlay")
	local list = {}
	for _, key in ipairs(COMMUNITIES_PICTURES) do
		list[#list + 1] = Held(overlay, key)
	end
	Style("fades", overlay, group, { list = list, unless = "portrait" })
end

-- The frame around the inspected player's model is nine textures with names and no keys, and the picture behind the model
-- has the keys of the character window's.
local INSPECT_BORDER = { "TopLeft", "TopRight", "BottomLeft", "BottomRight", "Left", "Right", "Top", "Bottom", "Bottom2" }

local function InspectExtras(root, group)
	local list = {}
	for _, part in ipairs(INSPECT_BORDER) do
		local piece = _G["InspectModelFrameBorder" .. part]
		if Usable(piece) then
			list[#list + 1] = piece
		end
	end
	Style("fades", root, group, { list = list })
	local model = _G.InspectModelFrame
	if Usable(model) and not ns.Forbidden(model) then
		local art = {}
		for _, name in ipairs(RACE_ART) do
			art[#art + 1] = Part(model, name)
		end
		Style("fades", model, group, { unless = "raceArt", list = art })
	end
end

local function DressUpExtras(root, group)
	Style("fades", root, group, { unless = "raceArt", list = Pieces(Held(root, "ModelBackground")) })
end

-- The portrait, the two bars across the window and the plate behind the selected macro have no keys. The portrait follows
-- the portrait setting.
local function MacroExtras(root, group)
	local portrait = _G.MacroFramePortrait
	Style("fades", root, group, { list = Pieces(portrait), unless = "portrait" })
	Style("art", root, group, { depth = 0, keep = Usable(portrait) and portrait or nil })
	Style("window", _G.MacroFrameTextBackground, group, "solid")
end

-- The tip that opens beside a long message is a box with a border of its own.
local function ToastExtras(root, group)
	Style("window", Held(root, "TooltipFrame"), group, "solid")
end

-- The spellbook keeps its pages: the game draws every text in it in a dark colour made for them. The talent tab has a backdrop,
-- a frame and a class picture of its own, which the setting bookArt gives back.
local TALENT_ART = { "Background", "BackgroundBorder", "ClassBackground" }

local function SpellsExtras(root, group)
	local talents = Held(root, "TalentsFrame")
	Style("fades", talents, group, { list = Keyed(talents, TALENT_ART), unless = "bookArt" })
end

-- Each of the three pages of the Legacy window draws a background of its own, which the setting bookArt gives back.
local LEGACY_PAGES = { "RewardTrackPage", "ChallengesPage", "TreePage" }

local function LegacyExtras(root, group)
	local list = {}
	for _, key in ipairs(LEGACY_PAGES) do
		list[#list + 1] = Held(Held(root, key), "Background")
	end
	Style("fades", root, group, { list = list, unless = "bookArt" })
end

-- The strip behind the number is two textures, which the game shows one at a time.
local function StackSplitExtras(root, group)
	Style("fades", root, group, { list = Keyed(root, { "SingleItemSplitBackground", "MultiItemSplitBackground" }) })
end

-- title: what a player calls the window, for /flatui status. group: the setting that switches the
-- window. addon: a load-on-demand addon that has it. pages: frames that fill the window and are
-- stripped of their art. strip: other frames that are, as a path or { path, depth }. skip: frames
-- the sweep leaves alone. bare: the window has no box of its own. solid: the fill ignores the window opacity.
local WINDOWS = {
	{ name = "CharacterFrame", title = "Character", group = "character", special = CharacterExtras,
		strip = { "CharacterFrame.LeftPaneHost", { "CharacterFrame.RightPaneHost", 1 }, "PaperDollLevelInfo", "CharacterStatsPaneScrollBox", "CharacterStatsPanePetScrollBox" } },
	{ name = "LFGParentFrame", title = "Looking For Group", group = "groupfinder", addon = "Blizzard_GroupFinder_VanillaStyle", special = GroupFinderExtras,
		pages = { "LFGListingFrame", "LFGBrowseFrame", "LFGWhoListFrame" },
		strip = { "LFGListingFrame.RolesSection", "LFGListingFrame.Inset", "LFGListingFrame.DividerFrame", "LFGListingFrame.ActivityView", "LFGBrowseFrame.Inset" },
		skip = { "LFGParentFramePortrait" } },
	{ name = "FriendsFrame", title = "Friends", group = "social", special = FriendsExtras },
	{ name = "SocialUIFrame", title = "Social", group = "social" },
	{ name = "ChannelFrame", title = "Channels", group = "social" },
	{ name = "RaidParentFrame", title = "Raid", group = "social" },
	MERCHANT,
	{ name = "MailFrame", title = "Mail", group = "npc", strip = { "SendMailMoneyBg" } },
	{ name = "OpenMailFrame", title = "Open Mail", group = "npc" },
	-- Quest, gossip and book pages keep their parchment: the game sets the colour of each line of their text for the material.
	{ name = "GossipFrame", title = "Gossip", group = "npc" },
	{ name = "QuestFrame", title = "Quest", group = "npc" },
	{ name = "QuestLogPopupDetailFrame", title = "Quest Log", group = "npc", special = QuestLogExtras, parchment = true },
	{ name = "ItemTextFrame", title = "Book", group = "npc" },
	TRADE,
	{ name = "ClassTrainerFrame", title = "Trainer", group = "npc", addon = "Blizzard_TrainerUI" },
	{ name = "ContainerFrameCombinedBags", title = "Bags", group = "bags", special = BagExtras },
	{ name = "BankFrame", title = "Bank", group = "bags", special = BankExtras, strip = { "BankFrame" } },
	{ name = "PlayerSpellsFrame", title = "Spellbook and talents", group = "spells", addon = "Blizzard_PlayerSpells", special = SpellsExtras },
	{ name = "ProfessionsFrame", title = "Professions", group = "spells", addon = "Blizzard_Professions" },
	{ name = "LegacySystemFrame", title = "Legacy", group = "spells", addon = "Blizzard_LegacySystem", special = LegacyExtras },
	{ name = "GameMenuFrame", title = "Game menu", group = "menus", special = DialogExtras },
	{ name = "SettingsPanel", title = "Options", group = "menus", strip = { "SettingsPanel" } },
	{ name = "AddonList", title = "Addons", group = "menus" },
	{ name = "ColorPickerFrame", title = "Colour picker", group = "menus", special = DialogExtras },
	{ name = "AuctionHouseFrame", title = "Auction house", group = "auction", addon = "Blizzard_AuctionHouseUI", special = AuctionExtras,
		strip = { "AuctionHouseFrame.MoneyFrameBorder" } },
	{ name = "CommunitiesFrame", title = "Guild", group = "guild", special = CommunitiesExtras },
	{ name = "GuildRegistrarFrame", title = "Guild registrar", group = "guild" },
	{ name = "PetitionFrame", title = "Petition", group = "guild" },
	{ name = "TabardFrame", title = "Tabard", group = "guild" },
	GUILD_BANK,
	{ name = "InspectFrame", title = "Inspect", group = "inspect", addon = "Blizzard_InspectUI", special = InspectExtras },
	{ name = "DressUpFrame", title = "Dressing room", group = "inspect", special = DressUpExtras },
	{ name = "MacroFrame", title = "Macros", group = "macros", addon = "Blizzard_MacroUI", special = MacroExtras },
	{ name = "MacroPopupFrame", title = "Macro icons", group = "macros", addon = "Blizzard_MacroUI" },
	{ name = "HelpFrame", title = "Help", group = "macros" },
	-- A map fills its window: the border lies over the map, and the map is not searched.
	{ name = "WorldMapFrame", title = "Map & Quest Log", group = "maps", bare = true, skip = { "WorldMapFrame.ScrollContainer" } },
	{ name = "FlightMapFrame", title = "Flight map", group = "maps", addon = "Blizzard_FlightMap", bare = true, skip = { "FlightMapFrame.ScrollContainer" } },
	{ name = "TaxiFrame", title = "Flight paths", group = "maps" },
	{ name = "CollectionsJournal", title = "Collections", group = "more", addon = "Blizzard_Collections" },
	{ name = "PetStableFrame", title = "Stable", group = "more" },
	{ name = "ItemSocketingFrame", title = "Sockets", group = "more", addon = "Blizzard_ItemSocketingUI" },
	{ name = "ClickBindingFrame", title = "Click casting", group = "more", addon = "Blizzard_ClickBindingUI" },
	{ name = "TimeManagerFrame", title = "Clock", group = "more", addon = "Blizzard_TimeManager" },
	{ name = "CooldownViewerSettings", title = "Cooldown manager", group = "more" },
	{ name = "AutoCompleteBox", title = "Name completion", group = "nameList", solid = true },
	{ name = "BNToastFrame", title = "Battle.net toast", group = "toasts", solid = true, special = ToastExtras },
	{ name = "TimeAlertFrame", title = "Time alert", group = "toasts", solid = true },
	{ name = "StackSplitFrame", title = "Stack splitting", group = "bags", solid = true, special = StackSplitExtras },
	{ name = "EquipmentFlyoutFrame", title = "Equipment flyout", group = "character", bare = true,
		strip = { "EquipmentFlyoutFrame.buttonFrame", "EquipmentFlyoutFrame.NavigationFrame" } },
	{ name = "ReadyCheckListenerFrame", title = "Ready check", group = "groupfinder" },
	{ name = "RolePollPopup", title = "Role check", group = "groupfinder" },
	{ name = "LFGInvitePopup", title = "Group invite", group = "groupfinder" },
	{ name = "AchievementFrame", title = "Achievements", group = "more", addon = "Blizzard_AchievementUI", solid = true },
	{ name = "CalendarFrame", title = "Calendar", group = "more", addon = "Blizzard_Calendar", solid = true, strip = { "CalendarFrame" } },
	{ name = "ChatConfigFrame", title = "Chat settings", group = "menus", special = DialogExtras },
	{ name = "PVPMatchScoreboard", title = "Scoreboard", group = "more", solid = true, strip = { "PVPMatchScoreboard.Content" } },
	{ name = "PVPMatchResults", title = "Match results", group = "more", solid = true, strip = { "PVPMatchResults.content" } },
	{ name = "CompactRaidFrameManager", title = "Raid manager", group = "social", solid = true, strip = { "CompactRaidFrameManager" } },
}
for index = 1, 7 do
	WINDOWS[#WINDOWS + 1] = { name = "ContainerFrame" .. index, title = "Bags", group = "bags", special = BagExtras }
end
-- Pop-ups are not shown through the panel manager.
local POPUPS = 4
for index = 1, POPUPS do
	WINDOWS[#WINDOWS + 1] = { name = "StaticPopup" .. index, title = "Pop-up", group = "menus", special = PopupExtras }
end

local BY_NAME = {}
for _, def in ipairs(WINDOWS) do
	BY_NAME[def.name] = def
end

local function PathSet(paths)
	local set = {}
	for _, text in ipairs(paths or {}) do
		local frame = Path(text)
		if frame then
			set[frame] = true
		end
	end
	return set
end

local function SweepWindow(def)
	local root = Path(def.name)
	if not root or ns.Forbidden(root) then
		return
	end
	roots[root] = def
	local group = def.group
	if def.bare or def.solid then
		Style("window", root, group, def.bare or "solid")
	else
		Style("window", root, group, def.parchment and "parchment" or nil)
	end
	for _, text in ipairs(def.pages or {}) do
		local page = Path(text)
		if page then
			Style("window", page, group, true)
			Style("art", page, group)
		end
	end
	for _, entry in ipairs(def.strip or {}) do
		local text, depth = entry, 0
		if type(entry) == "table" then
			text, depth = entry[1], entry[2]
		end
		local frame = Path(text)
		if frame then
			Style("art", frame, group, { depth = depth })
		end
	end
	Walk(root, group, { count = 0, title = def.title, pages = PathSet(def.pages), skip = PathSet(def.skip) }, 1)
	if def.special then
		ns.EachPart(KEY, "window details", def.special, root, group)
	end
end

local function SweepAll()
	for _, def in ipairs(WINDOWS) do
		ns.Each(KEY, SweepWindow, def)
	end
end

-- Hooks ---------------------------------------------------------------------------------------------

-- The windows opened with ShowUIPanel and not closed with HideUIPanel or pushed out by another window since. ShowUIPanel runs
-- the hook again when it finds the window open, and a window is searched in full once each time it opens.
local opened = setmetatable({}, { __mode = "k" })

local function OnShowUIPanel(frame)
	if frame == nil or ns.IsSecret(frame) or type(frame) ~= "table" then
		return
	end
	local def = roots[frame]
	-- A window the sweep after its addon loaded did not find is found by its name when it opens.
	if not def and not ns.Forbidden(frame) then
		def = BY_NAME[NameOf(frame)]
	end
	if not def or not ns.Enabled(KEY) then
		return
	end
	-- Open already: only what the game has added to the window itself is looked at.
	if opened[frame] then
		ns.EachPart(KEY, "window details", StyleNew, frame, def.group, PathSet(def.skip))
		return
	end
	opened[frame] = Shown(frame) or nil
	ns.Each(KEY, SweepWindow, def)
	-- Some children are made while the window opens.
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if ns.Enabled(KEY) then
				ns.Each(KEY, SweepWindow, def)
			end
		end)
	end
end

local function OnHideUIPanel(frame)
	if frame ~= nil and not ns.IsSecret(frame) and type(frame) == "table" then
		opened[frame] = nil
	end
end

-- Pop-ups are shown without the panel manager, so those on screen are looked at as one is shown.
local function OnPopup()
	if ns.Enabled(KEY) then
		for index = 1, POPUPS do
			local popup = _G["StaticPopup" .. index]
			local def = Usable(popup) and roots[popup]
			if def and Shown(popup) then
				ns.Each(KEY, SweepWindow, def)
			end
		end
	end
end

-- The game sets an item button's border and its colour again on every update of the item, for every slot of a bag. A slot
-- is drawn again only when the quality colour it shows changes.
local function OnItemBorder(button, asset)
	local own = SlotOf(button)
	if own and own.quality ~= nil and not ns.IsSecret(asset) and asset == nil then
		own.quality = nil
		Again(button, "slot")
	end
end

local function OnItemBorderColour(button, r, g, b)
	local own = SlotOf(button)
	if not own then
		return
	end
	local quality = own.quality
	if ns.IsSecret(r) or ns.IsSecret(g) or ns.IsSecret(b) or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
		if quality == nil then
			return
		end
		own.quality = nil
	elseif quality == nil then
		own.quality = { r, g, b }
	elseif quality[1] == r and quality[2] == g and quality[3] == b then
		return
	else
		quality[1], quality[2], quality[3] = r, g, b
	end
	Again(button, "slot")
end

local function OnItemNormalColour(button, r, g, b)
	local own = SlotOf(button)
	if own and not ns.IsSecret(r) and not ns.IsSecret(g) and not ns.IsSecret(b) then
		own.worn = IsRed(r, g, b)
		Again(button, "slot")
	end
end

-- The game sets the colour of the slot and name art of a vendor or trade cell on every update.
local function OnCellColour(cell)
	if cell ~= nil and not ns.IsSecret(cell) and type(cell) == "table" then
		Again(cell, "art")
	end
end

local function OnCategories(view)
	if ns.Enabled(KEY) then
		ns.EachPart(KEY, "window details", StyleCategories, view)
	end
end

-- The equipment flyout makes a background texture for each row of items and a button for each item as it fills.
local function OnFlyout()
	local def = BY_NAME.EquipmentFlyoutFrame
	local panel = Held(_G.EquipmentFlyoutFrame, "buttonFrame")
	if def and panel and ns.Enabled(KEY) then
		ns.EachPart(KEY, "window details", Again, panel, "art")
		ns.EachPart(KEY, "window details", StyleNew, panel, def.group)
	end
end

-- Hooks a global function of Blizzard's, if the client has it.
local function HookGlobal(name, fn)
	if hookedGlobals[name] or type(hooksecurefunc) ~= "function" or type(_G[name]) ~= "function" then
		return
	end
	hookedGlobals[name] = true
	hooksecurefunc(_G, name, fn)
end

local function StyleMenu(menu)
	Style("menu", menu, "popupMenus")
end

-- The game announces each menu after it has built and shown it. The call comes through its callback registry, so nothing is
-- hooked on the menu code.
local function OnMenuShown(_, menu)
	if ns.Enabled(KEY) and Usable(menu) then
		ns.EachPart(KEY, "menus", StyleMenu, menu)
	end
end

local menuOwner = {}
local menusWatched = false

local function WatchMenus()
	if menusWatched or type(EventRegistry) ~= "table" or ns.IsSecret(EventRegistry) or type(EventRegistry.RegisterCallback) ~= "function" then
		return
	end
	menusWatched = pcall(EventRegistry.RegisterCallback, EventRegistry, MENU_EVENT, OnMenuShown, menuOwner)
end

-- The panel manager hides a window that another pushes out with Hide, and announces it on its registry without calling
-- HideUIPanel, so the window is marked closed here.
local function OnPushedOut(_, frame)
	OnHideUIPanel(frame)
end

local pushedOwner = {}
local pushedWatched = false

local function WatchPushedOut()
	if pushedWatched or type(EventRegistry) ~= "table" or ns.IsSecret(EventRegistry) or type(EventRegistry.RegisterCallback) ~= "function" then
		return
	end
	pushedWatched = pcall(EventRegistry.RegisterCallback, EventRegistry, PUSHED_OUT_EVENT, OnPushedOut, pushedOwner)
end

Watch.bankOwner = {}

function Watch.Bank()
	if Watch.bankWatched or type(EventRegistry) ~= "table" or ns.IsSecret(EventRegistry) or type(EventRegistry.RegisterCallback) ~= "function" then
		return
	end
	Watch.bankWatched = pcall(EventRegistry.RegisterCallback, EventRegistry, "BankPanelMixin.PageInfoChanged", Watch.BanksChanged, Watch.bankOwner)
end

local function InstallHooks()
	WatchMenus()
	WatchPushedOut()
	Watch.Bank()
	HookGlobal("ShowUIPanel", OnShowUIPanel)
	HookGlobal("HideUIPanel", OnHideUIPanel)
	HookGlobal("StaticPopup_Show", OnPopup)
	HookGlobal("SetItemButtonBorder", OnItemBorder)
	HookGlobal("SetItemButtonBorderVertexColor", OnItemBorderColour)
	HookGlobal("SetItemButtonNormalTextureVertexColor", OnItemNormalColour)
	HookGlobal("SetItemButtonSlotVertexColor", OnCellColour)
	HookGlobal("SetItemButtonNameFrameVertexColor", OnCellColour)
	HookGlobal(CATEGORY_UPDATE, OnCategories)
	HookGlobal(FLYOUT_UPDATE, OnFlyout)
	HookGlobal("ContainerFrame_GenerateFrame", Watch.BagGenerated)
	HookGlobal("ContainerFrame_UpdateAll", Watch.BagsUpdated)
	-- The game chooses the tab of a character, collections or inspect window in these (PaperDollFrame.lua:3379-3395, CharacterFrame.lua:3,
	-- Blizzard_CollectionsOverrides.lua:21-31).
	HookGlobal("PaperDollFrame_UpdateSidebarTabs", Watch.RefreshSideTabs)
	HookGlobal("CollectionsJournal_SetTab_Internal", Watch.RefreshSideTabs)
	HookGlobal("ToggleCharacter", Watch.RefreshSideTabs)
end

-- The module ----------------------------------------------------------------------------------------

-- The settings that bring more of the interface under the module when they go on, and whether each
-- was on the last time they were looked at.
local SWITCHES = { "enabled", "character", "groupfinder", "social", "npc", "bags", "spells", "menus", "buttons", "tabs", "sideTabs", "scroll", "checks", "inputs", "bars", "slots" }
for _, key in ipairs({ "auction", "guild", "inspect", "macros", "maps", "more", "nameList", "toasts", "rows" }) do
	SWITCHES[#SWITCHES + 1] = key
end
local seen = {}

local function SwitchedOn()
	local went = false
	for _, key in ipairs(SWITCHES) do
		local on = Opt(key) == true
		if on and not seen[key] then
			went = true
		end
		seen[key] = on
	end
	return went
end

-- Applies the options to everything styled. The windows are searched for what is not styled yet when
-- a switch has just gone on, which is the case when the module starts.
local function Refresh()
	InstallHooks()
	ns.Items.Apply()
	local switched = SwitchedOn()
	local all = {}
	for frame, entries in pairs(styled) do
		if entries.sideTab and not entries.sideTab.sidebar and not entries.sideTab.broken then
			-- The game chose tabs while the module was off and nothing was watching, so the checked state is read now.
			Watch.ReadSideTab(frame, entries.sideTab)
		end
		for kind, own in pairs(entries) do
			all[#all + 1] = { kind, frame, own }
		end
	end
	for _, item in ipairs(all) do
		if not item[3].broken then
			Style(item[1], item[2], item[3].group)
		end
	end
	-- The clean up button and the sort direction follow their own settings, whatever the switches say.
	ns.BagSort.Apply()
	if ns.Enabled(KEY) and switched then
		SweepAll()
	end
end

-- Lengths worked out in screen pixels.
local function Resized()
	for frame, entries in pairs(styled) do
		local own = entries.divider
		if own and not own.broken then
			Style("divider", frame, own.group)
		end
	end
end

local LOAD_ON_DEMAND = {}
for _, def in ipairs(WINDOWS) do
	if def.addon then
		LOAD_ON_DEMAND[def.addon] = true
	end
end

local function IsLoaded(addon)
	if type(C_AddOns) ~= "table" or type(C_AddOns.IsAddOnLoaded) ~= "function" then
		return false
	end
	local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, addon)
	return ok and not ns.IsSecret(loaded) and loaded == true
end

-- What became of a listed window: styled, not open yet, not found, loads later, off, stopped or forbidden.
local function WindowState(def)
	if ns.IsStopped(KEY) or ns.PartStopped(KEY, KINDS.window.label) then
		return "stopped"
	end
	if not IsOn("window", def.group) then
		return "off"
	end
	local root = _G[def.name]
	if not Usable(root) then
		return def.addon and not IsLoaded(def.addon) and "loads later" or "not found"
	end
	if ns.Forbidden(root) then
		return "forbidden"
	end
	local own = styled[root] and styled[root].window
	if own and not own.broken then
		return "styled"
	end
	return "not open yet"
end

local function PrintWindows()
	for _, def in ipairs(WINDOWS) do
		print(("%s: %s"):format(def.name, WindowState(def)))
	end
end

ns.Register(KEY, {
	label = "Windows",
	Start = Refresh,
	Refresh = Refresh,
	Resized = Resized,
	filters = {
		ADDON_LOADED = function(name)
			return not ns.IsSecret(name) and LOAD_ON_DEMAND[name] == true
		end,
	},
	events = {
		ADDON_LOADED = function(name)
			InstallHooks()
			for _, def in ipairs(WINDOWS) do
				if def.addon == name then
					ns.Each(KEY, SweepWindow, def)
				end
			end
		end,
		PLAYER_LOGOUT = ns.BagSort.Logout,
		UNIT_PORTRAIT_UPDATE = function(unit)
			if unit == "player" then
				Watch.PortraitChanged()
			end
		end,
		PORTRAITS_UPDATED = Watch.PortraitChanged,
		PLAYER_TALENT_UPDATE = Watch.PortraitChanged,
		ACTIVE_TALENT_GROUP_CHANGED = Watch.PortraitChanged,
		BANK_TABS_CHANGED = Watch.BanksChanged,
		-- BAG_UPDATE reaches a bag's Update and BAG_NEW_ITEMS_UPDATED calls it (ContainerFrame.lua:597-612, 1180-1190), neither through
		-- ContainerFrame_UpdateAll; BAG_UPDATE_DELAYED follows the updates of one change.
		BAG_UPDATE_DELAYED = Watch.BagsUpdated,
		BAG_NEW_ITEMS_UPDATED = Watch.BagsUpdated,
		UNIT_NAME_UPDATE = function(unit)
			if unit == "player" then
				ns.Items.Retitle()
			end
		end,
		PLAYER_PVP_RANK_CHANGED = function()
			ns.Items.Retitle()
		end,
	},
	slash = { windows = PrintWindows, sort = ns.BagSort.Command },
	help = { "/flatui windows - each window and whether it is styled", ns.BagSort.help[1], ns.BagSort.help[2] },
})
