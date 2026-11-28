local _, ns = ...

local L = ns.ChargesLook
local B = { exists = {}, looks = {} }
ns.ChargesBar = B

B.GAP, B.WIDTH, B.STACK = 3, 160, 6
B.PIECES = { "shadow", "socket", "rim", "back", "gem", "frame", "glow", "deplete" }
B.TINTED = { back = true, gem = true, frame = true, glow = true, deplete = true }
B.SHAPES = { Top = 0.5, Center = 1 }
B.ORB_FILL = { file = L.GLOW, w = 1.6, h = 1.6, y = 0, blend = "ADD", tint = true, a = 1 }
B.ORB_GHOST = { file = L.RING, w = L.GHOST, h = L.GHOST, y = 0, blend = "ADD", tint = true, a = 0.32 }
B.KITS = {
	rogue = { ref = 20, shadow = { "uf-roguecp-bg-shadow", y = -4 }, socket = { "uf-roguecp-bg-dis" }, rim = { "uf-roguecp-bg-anima-dis" },
		gem = { "uf-roguecp-icon-blue" }, frame = { "uf-roguecp-bg-anima" }, glow = { "uf-roguecp-bg-animaglow" }, deplete = { "uf-roguecp-fx-blue" } },
	druid = { ref = 20, shadow = { "UF-DruidCP-BG-Shadow", y = -2 }, socket = { "UF-DruidCP-BG-Dis" }, back = { "UF-DruidCP-BG-Active" },
		gem = { "UF-DruidCP-Icon" }, glow = { "UF-DruidCP-Ring-Glow" }, deplete = { "UF-DruidCP-Deplete" } },
	arcane = { ref = 21, shadow = { "UF-Arcane-BGShadow", y = -2.5 }, socket = { "UF-Arcane-BG" }, gem = { "UF-Arcane-Icon" },
		glow = { "UF-Arcane-FrameGlow" }, deplete = { "UF-Arcane-OuterFX" } },
	chi = { ref = 21, socket = { "uf-chi-bg", y = -2.5 }, back = { "uf-chi-bg-active", y = -2.5 }, gem = { "uf-chi-icon" },
		glow = { "uf-chi-outerglow", y = -0.5 }, deplete = { "uf-chi-fx-deplete" } },
	holy = { ref = 18, socket = { "uf-holypower-rune1" }, gem = { "uf-holypower-rune1-active" }, glow = { "uf-holypower-rune1-glow" },
		deplete = { "uf-holypower-rune1-blur" } },
}
B.MEDIA = {
	shadow = { file = L.GLOW, size = 1.35, y = -1, blend = "BLEND", rgb = { 0, 0, 0 }, a = 0.55 },
	socket = { file = L.RING, size = 1.05, blend = "ADD", tint = true, a = 0.35 },
	back = { file = L.GLOW, size = 1.6, blend = "ADD", tint = true, a = 0.35 },
	gem = { file = L.GLOW, size = 1.35, blend = "ADD", tint = true, a = 1 },
	glow = { file = L.GLOW, size = 2.3, blend = "ADD", tint = true, a = 1 },
	deplete = { file = L.GLOW, size = 1.7, blend = "ADD", rgb = { 1, 1, 1 }, a = 1 },
}
B.SETS = {
	lightning = { "rogue", native = { rogue = true } },
	maelstrom = { "arcane", "rogue", native = {} },
	water = { "chi", "rogue", native = {} },
	earth = { "druid", "rogue", native = {} },
	innerfire = { "druid", "rogue", native = {} },
	shadowguard = { "arcane", "rogue", native = { arcane = true } },
	holyshield = { "holy", "druid", native = { holy = true } },
	added = { "rogue", "druid", native = {} },
}

local IsSecret = ns.IsSecret
local Opt, Own = L.Opt, L.Own

local function Charges()
	return ns.Charges
end

function B.Exists(name)
	local known = B.exists[name]
	if known == nil then
		known = type(ns.AtlasExists) == "function" and ns.AtlasExists(name) == true
		B.exists[name] = known
	end
	return known
end

function B.AtlasSize(name)
	local api = C_Texture
	if type(api) ~= "table" or IsSecret(api) or type(api.GetAtlasInfo) ~= "function" then
		return nil
	end
	local ok, w, h = pcall(function()
		local info = api.GetAtlasInfo(name)
		return info.width, info.height
	end)
	if ok and ns.Finite(w) and ns.Finite(h) and w > 0 and h > 0 then
		return w, h
	end
	return nil
end

function B.Piece(set, name, tinted)
	for _, kitName in ipairs(set) do
		local kit = B.KITS[kitName]
		local spec = kit and kit[name]
		local atlas = spec and spec[1]
		if not spec and kit and B.Exists(kit.gem[1]) then
			return nil
		end
		if atlas and B.Exists(atlas) then
			local w, h = B.AtlasSize(atlas)
			local ref = kit.ref
			local tint = B.TINTED[name] == true and (tinted or not set.native[kitName])
			return { atlas = atlas, w = (w or ref) / ref, h = (h or ref) / ref, y = (spec.y or 0) / ref, blend = "BLEND", tint = tint, a = 1 }
		end
	end
	local media = B.MEDIA[name]
	if not media then
		return nil
	end
	return { file = media.file, w = media.size, h = media.size, y = (media.y or 0) / 20, blend = media.blend, tint = media.tint, rgb = media.rgb, a = media.a }
end

function B.Look(d)
	local key = d.family.key
	local set = B.SETS[key] or B.SETS.added
	local tinted = Opt("colourBy") ~= "spell" or B.SETS[key] == nil
	local cache = (set == B.SETS.added and "added" or key) .. (tinted and ":tint" or "")
	local look = B.looks[cache]
	if not look then
		look = {}
		for _, name in ipairs(B.PIECES) do
			look[name] = B.Piece(set, name, tinted)
		end
		B.looks[cache] = look
	end
	d.look = look
	if d.kind == "art" then
		d.artTint = tinted
	end
	return look
end

function B.ArtFor(family)
	if type(family) ~= "table" then
		return nil
	end
	if family.art ~= nil then
		return family.art or nil
	end
	local wanted, found = {}, false
	for _, id in ipairs(family.ids) do
		wanted[id] = true
	end
	for _, list in pairs(type(ns.ProcData) == "table" and ns.ProcData or {}) do
		for _, entry in ipairs(type(list) == "table" and list or {}) do
			local art = type(entry) == "table" and entry.art or nil
			local ratio = type(art) == "table" and B.SHAPES[art.location] or nil
			if ratio and (type(art.file) == "number" or type(art.file) == "string") then
				for _, id in ipairs(type(entry.buffs) == "table" and entry.buffs or {}) do
					if wanted[id] and not found then
						found = { file = art.file, ratio = ratio, scale = ns.Finite(art.scale) and art.scale > 0 and math.min(art.scale, 1) or 1 }
					end
				end
			end
		end
	end
	family.art = found
	return found or nil
end

function B.Rgb(piece, r, g, b)
	if piece.rgb then
		return piece.rgb[1], piece.rgb[2], piece.rgb[3]
	elseif piece.tint then
		return r, g, b
	end
	return 1, 1, 1
end

function B.Apply(texture, piece, r, g, b)
	local set = false
	if piece.atlas then
		local ok, done = pcall(texture.SetAtlas, texture, piece.atlas, false)
		set = ok and done ~= false
	end
	if not set then
		texture:SetTexture(piece.file or L.GLOW)
		texture:SetTexCoord(0, 1, 0, 1)
	end
	pcall(texture.SetBlendMode, texture, piece.blend or "BLEND")
	pcall(texture.SetDesaturated, texture, set and piece.tint == true)
	local cr, cg, cb = B.Rgb((set or not piece.atlas) and piece or B.MEDIA.gem, r, g, b)
	texture:SetVertexColor(cr, cg, cb, piece.a or 1)
end

function B.FillOf(bar)
	local ok, fill = pcall(bar.GetStatusBarTexture, bar)
	if ok and type(fill) == "table" and not IsSecret(fill) then
		return fill
	end
	return nil
end

function B.AtlasFill(bar, atlas)
	local ok, done = pcall(bar.SetStatusBarTexture, bar, atlas)
	local fill = ok and done ~= false and B.FillOf(bar) or nil
	if not fill then
		return false
	end
	local read, got = pcall(fill.GetAtlas, fill)
	if read and not IsSecret(got) and got == atlas then
		return true
	end
	local put, made = pcall(fill.SetAtlas, fill, atlas, false)
	return put and made ~= false
end

function B.Tint(piece, set, r, g, b)
	local cr, cg, cb = B.Rgb((set or not piece.atlas) and piece or B.MEDIA.gem, r, g, b)
	return { cr, cg, cb, piece.a or 1 }
end

function B.Fill(bar, piece, r, g, b)
	local set = piece.atlas ~= nil and B.AtlasFill(bar, piece.atlas)
	if not set then
		pcall(bar.SetStatusBarTexture, bar, piece.file or L.GLOW)
	end
	local fill = B.FillOf(bar)
	if fill then
		pcall(fill.SetBlendMode, fill, piece.blend or "BLEND")
		pcall(fill.SetDesaturated, fill, set and piece.tint == true)
	end
	local tint = B.Tint(piece, set, r, g, b)
	tint.set = set
	return tint
end

function B.Region(texture, piece, size, stretch, spot, r, g, b, shown)
	if not (piece and shown) then
		texture:Hide()
		return
	end
	B.Apply(texture, piece, r, g, b)
	texture:SetSize(piece.w * size + stretch, piece.h * size)
	texture:ClearAllPoints()
	texture:SetPoint("CENTER", spot, "CENTER", 0, piece.y * size)
	texture:Show()
end

function B.Texture(owner, layer, sub)
	return Own(owner:CreateTexture(nil, layer, nil, sub))
end

function B.Pip(d, index)
	local spot = L.Spot(d, index)
	local orb = { index = index, spot = spot, popFrom = 1.3, popTime = 0.4, swell = 1.25, pulseGrow = 0.08 }
	orb.shadow = B.Texture(d.own, "BACKGROUND", 0)
	orb.ghost = B.Texture(d.own, "BACKGROUND", 1)
	orb.rim = B.Texture(d.own, "BACKGROUND", 2)
	local frame = Own(CreateFrame("Frame", nil, d.own))
	frame:SetPoint("CENTER", spot, "CENTER", 0, 0)
	frame:SetFrameLevel(d.own:GetFrameLevel() + 3)
	orb.frame = frame
	orb.bars = { L.Bar(frame, index, 0), L.Bar(frame, index, 1), L.Bar(frame, index, 2) }
	orb.pop = B.Texture(d.fx, "ARTWORK", 0)
	orb.burst = B.Texture(d.fx, "ARTWORK", 1)
	orb.flash = L.Glow(d.fx, "ARTWORK", 2)
	orb.flash:SetVertexColor(1, 1, 1, 1)
	for _, texture in ipairs({ orb.pop, orb.burst, orb.flash }) do
		texture:SetPoint("CENTER", spot, "CENTER", 0, 0)
		texture:SetAlpha(0)
	end
	orb.regions = { orb.shadow, orb.ghost, orb.rim, orb.pop, orb.burst, orb.flash }
	return orb
end

function B.Layer(d, index)
	local spot = L.Spot(d, index)
	local orb = { index = index, spot = spot, popFrom = 1.06, popTime = 0.35, swell = 1.12, pulseGrow = 0.03, burstAlpha = 0.6 }
	orb.ghost = B.Texture(d.own, "BACKGROUND", 1)
	local frame = Own(CreateFrame("Frame", nil, d.own))
	frame:SetPoint("CENTER", spot, "CENTER", 0, 0)
	frame:SetFrameLevel(d.own:GetFrameLevel() + 3)
	orb.frame = frame
	orb.bars = { L.Bar(frame, index, 0) }
	orb.pop = B.Texture(d.fx, "ARTWORK", 0)
	orb.burst = B.Texture(d.fx, "ARTWORK", 1)
	orb.flash = B.Texture(d.fx, "ARTWORK", 2)
	for _, texture in ipairs({ orb.pop, orb.burst, orb.flash }) do
		texture:SetPoint("CENTER", spot, "CENTER", 0, 0)
		pcall(texture.SetBlendMode, texture, "ADD")
		texture:SetAlpha(0)
	end
	orb.regions = { orb.ghost, orb.pop, orb.burst, orb.flash }
	return orb
end

function B.Sizes(d)
	return d.pip, 0
end

function B.PaintBar(bar, piece, w, h, y, owner, r, g, b, shown)
	if not (piece and shown) then
		bar:Hide()
		return nil
	end
	local tint = B.Fill(bar, piece, r, g, b)
	bar:SetSize(w, h)
	bar:ClearAllPoints()
	bar:SetPoint("CENTER", owner, "CENTER", 0, y)
	bar:Show()
	return tint
end

function B.PaintPip(d, orb)
	local look, on = d.look, orb.index <= d.n
	local s, stretch = B.Sizes(d)
	local r, g, b = d.r, d.g, d.b
	local used = on and Opt("ghosts") ~= false
	B.Region(orb.shadow, look.shadow, s, stretch, orb.spot, r, g, b, used)
	B.Region(orb.ghost, look.socket, s, stretch, orb.spot, r, g, b, used)
	B.Region(orb.rim, look.rim, s, stretch, orb.spot, r, g, b, used)
	orb.frame:SetSize(s, s)
	local back, gem, cap = look.back, look.gem, look.frame
	orb.tints = {
		back and B.PaintBar(orb.bars[1], back, back.w * s + stretch, back.h * s, back.y * s, orb.frame, r, g, b, true) or B.PaintBar(orb.bars[1]),
		B.PaintBar(orb.bars[2], gem, gem.w * s, gem.h * s, gem.y * s, orb.frame, r, g, b, true),
		cap and B.PaintBar(orb.bars[3], cap, cap.w * s, cap.h * s, cap.y * s, orb.frame, r, g, b, true) or B.PaintBar(orb.bars[3]),
	}
	B.Region(orb.pop, look.glow, s, 0, orb.spot, r, g, b, true)
	B.Region(orb.burst, look.deplete, s, 0, orb.spot, r, g, b, true)
	local deplete = look.deplete
	orb.bw, orb.bh = deplete.w * s, deplete.h * s
	orb.flash:SetSize(s * 1.5, s * 1.5)
	orb.flash:Show()
	for _, texture in ipairs({ orb.pop, orb.burst, orb.flash }) do
		texture:SetAlpha(0)
	end
	L.TintOrb(orb, r, g, b)
	orb.frame:SetShown(on)
end

function B.ArtColour(d)
	if d.artTint then
		return d.r, d.g, d.b
	end
	return 1, 1, 1
end

function B.LayerAlpha(n)
	return 1 - 0.05 ^ (1 / math.max(1, n))
end

function B.PaintArt(texture, d, w, h, r, g, b, a)
	texture:SetTexture(d.art.file)
	texture:SetTexCoord(0, 1, 0, 1)
	pcall(texture.SetDesaturated, texture, d.artTint == true)
	texture:SetVertexColor(r, g, b, a)
	texture:SetSize(w, h)
end

function B.ArtFill(bar, d)
	pcall(bar.SetStatusBarTexture, bar, d.art.file)
	local fill = B.FillOf(bar)
	if fill then
		pcall(fill.SetDesaturated, fill, d.artTint == true)
		pcall(fill.SetBlendMode, fill, "BLEND")
	end
end

function B.ArtTint(d)
	local r, g, b = B.ArtColour(d)
	return { r, g, b, B.LayerAlpha(d.n) }
end

function B.ArtBar(bar, d, owner, shown)
	if not shown then
		bar:Hide()
		return nil
	end
	local art = d.art
	B.ArtFill(bar, d)
	bar:SetSize(art.w, art.h)
	bar:ClearAllPoints()
	bar:SetPoint("CENTER", owner, "CENTER", 0, 0)
	bar:Show()
	return B.ArtTint(d)
end

function B.ArtGhost(texture, d, spot, shown)
	if not shown then
		texture:Hide()
		return
	end
	local r, g, b = B.ArtColour(d)
	B.PaintArt(texture, d, d.art.w, d.art.h, r, g, b, 0.18)
	pcall(texture.SetBlendMode, texture, "BLEND")
	texture:ClearAllPoints()
	texture:SetPoint("CENTER", spot, "CENTER", 0, 0)
	texture:Show()
end

function B.PaintLayer(d, orb)
	local art, on = d.art, orb.index <= d.n
	local r, g, b = B.ArtColour(d)
	local w, h = art.w, art.h
	B.ArtGhost(orb.ghost, d, orb.spot, orb.index == 1 and on and Opt("ghosts") ~= false)
	orb.frame:SetSize(w, h)
	orb.tints = { B.ArtBar(orb.bars[1], d, orb.frame, true) }
	for _, texture in ipairs({ orb.pop, orb.burst, orb.flash }) do
		B.PaintArt(texture, d, w, h, r, g, b, 1)
		pcall(texture.SetBlendMode, texture, "ADD")
		texture:SetAlpha(0)
		texture:Show()
	end
	orb.bw, orb.bh = w, h
	L.TintOrb(orb, r, g, b)
	orb.frame:SetShown(on)
end

function B.PaintPiece(d, orb)
	if d.kind == "art" then
		B.PaintLayer(d, orb)
	else
		B.PaintPip(d, orb)
	end
end

function B.Width()
	local C = Charges()
	if Opt("fill") == false or not (C and C.Width) then
		return nil
	end
	return C.Width()
end

function B.Line(d)
	local text = Opt("name") ~= false or Opt("time") ~= false
	return text and math.floor(d.pip * 0.5 + 6) or 0
end

function B.Small(d)
	return math.max(75, math.min(160, d.pip / 20 * 95))
end

function B.TimeWidth(d)
	return math.floor(d.pip * 1.1 + 4)
end

function B.NameWidth(d)
	local name = d.name
	if not name or Opt("name") == false then
		return 0
	end
	L.Style(name, B.Small(d))
	name:SetText(d.title or "")
	local ok, width = pcall(name.GetStringWidth, name)
	return ok and ns.Finite(width) and width or 0
end

function B.Geometry(d)
	local n, pip = math.max(1, d.n), d.pip
	local width = B.Width()
	local room = Opt("count") ~= false and math.floor(pip * 1.2 + 6) or 0
	d.line, d.room, d.narrow = B.Line(d), room, false
	if d.kind == "art" then
		local art = B.ArtFor(d.family)
		local w = math.min(width or B.WIDTH, B.WIDTH * 1.5) * art.scale
		d.art = { file = art.file, w = w, h = w * art.ratio }
		local under = math.max(room, d.line)
		d.cell, d.rowW = w, w
		d.w, d.h = math.max(w, B.WIDTH), d.art.h + under
		d.cx, d.cy = 0, d.h / 2 - d.art.h / 2
		return
	end
	local least = n * pip + (n - 1) * B.GAP
	local wide = width and n > 1 and width - room > least and width - room or least
	if Opt("time") ~= false and B.NameWidth(d) + B.TimeWidth(d) + 6 > wide then
		d.narrow = true
		room = room + B.TimeWidth(d)
		wide = width and n > 1 and width - room > least and width - room or least
	end
	d.room, d.cell, d.rowW = room, pip, wide
	d.step = n > 1 and (wide - pip) / (n - 1) or 0
	if width then
		d.w, d.cx = d.rowW + room, -room / 2
	else
		d.w, d.cx = d.rowW + room * 2, 0
	end
	d.h = pip + d.line
	d.cy = -(d.h - pip) / 2
end

function B.PlaceSpots(d)
	for index = 1, d.n do
		local x = 0
		if d.kind == "pip" then
			x = -d.rowW / 2 + d.cell / 2 + (index - 1) * d.step
		end
		local spot = d.spots[index]
		spot:ClearAllPoints()
		spot:SetPoint("CENTER", d.centre, "CENTER", x, 0)
	end
end

function B.TextLook(d, set)
	local pip = d.pip
	local small = B.Small(d)
	local time, number, name = set.time, set.number, set.name
	L.Style(time, small)
	L.Style(number, math.max(90, math.min(220, pip / 20 * 125)))
	L.Style(name, small)
	local spots = B.TEXT[d.kind == "art" and "art" or "pip"]
	for key, text in pairs({ time = time, number = number, name = name }) do
		local spot = key == "time" and d.narrow and B.TEXT.after or spots[key]
		text:ClearAllPoints()
		text:SetJustifyH(spot[1])
		local x, y = spot[3](d)
		local to = spot[2] == "number" and number or d.centre
		if to == nil then
			text:SetPoint(spot[4], d.centre, "CENTER", x, y)
		else
			text:SetPoint(spot[4], to, spot[5], x, y)
		end
	end
	if name then
		name:SetText(d.title or "")
		name:SetShown(Opt("name") ~= false)
	end
end

B.TEXT = {
	after = { "LEFT", "number", function()
		return 3, 0
	end, "LEFT", "RIGHT" },
	art = {
		number = { "CENTER", "centre", function(d)
			return 0, -d.art.h / 2 - 1
		end, "TOP", "CENTER" },
		time = { "LEFT", "number", function()
			return 5, 0
		end, "LEFT", "RIGHT" },
		name = { "RIGHT", "number", function()
			return -7, 0
		end, "RIGHT", "LEFT" },
	},
	pip = {
		number = { "LEFT", "centre", function(d)
			return d.rowW / 2 + 5, 0
		end, "LEFT", "CENTER" },
		time = { "RIGHT", "centre", function(d)
			return d.rowW / 2, d.pip / 2 + 2
		end, "BOTTOMRIGHT", "CENTER" },
		name = { "LEFT", "centre", function(d)
			return -d.rowW / 2, d.pip / 2 + 2
		end, "BOTTOMLEFT", "CENTER" },
	},
}
