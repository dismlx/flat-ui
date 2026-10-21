local _, ns = ...

-- The large art beside the character while a proc is up. The game's own overlay (SpellActivationOverlay.lua) is not built in Forever
-- (Blizzard_FrameXML.toc:109-110), so the pieces are drawn here on frames of the addon, laid out as the game lays them out
-- (SpellActivationOverlay.lua:75-127): a holder of 204.8 square at the middle of the screen, a piece 102.4 by 204.8 to the left of it, its
-- mirror to the right, 204.8 by 102.4 above and below, 102.4 square at the corners. A piece fades in over 0.2 s, pulses while the proc
-- is up and fades out over 0.1 s (SpellActivationOverlay.xml:3-24). Procs.lua calls ns.ProcArtShow when a proc comes up and
-- ns.ProcArtHide when it ends. Every call here is a frame, texture or animation call on a frame of the addon that is not protected, so
-- all of it is allowed in combat; the holder is made out of combat like every Flat UI frame.
-- A second way to draw, for a proc whose buff the game hides in a fight: ns.ProcArtParts makes the same pieces as textures that are children of
-- the button of the game's own icon of the buff (TrackerSlots.lua), inside the function the game calls while it builds the slot. The game shows
-- that button exactly while the buff is up, so these pieces show exactly then. While that icon is on show the pieces of the holder stay hidden.

local KEY = "trackers"
local IsSecret = ns.IsSecret

-- LONG, SHORT: the long and short side of a piece, units. FADE_IN, FADE_OUT, PULSE_UP, PULSE_DOWN, PULSE_TIME: the game's animation.
-- MAX: procs drawn at once. POOL: pieces made with the holder. ARC: the plain arc of a proc with no art. FALLBACK: the colour when nothing
-- gives one. SIDES: pieces of a location that stands for two. NAMES: what the check says. BY_NUMBER: Enum.ScreenLocationType by value
-- (ScreenLocationConstantsDocumentation.lua:13-24).
local K = {
	LONG = 204.8, SHORT = 102.4,
	FADE_IN = 0.2, FADE_OUT = 0.1, PULSE_UP = 1.08, PULSE_DOWN = 0.9259, PULSE_TIME = 0.5,
	MAX = 3, POOL = 12,
	ARC = "Interface\\AddOns\\FlatUI\\Media\\ProcArc.tga",
	FALLBACK = { 1, 209 / 255, 0 },
	SIDES = {
		LeftRight = { "Left", "Right" }, TopBottom = { "Top", "Bottom" }, LeftRightOutside = { "LeftOutside", "RightOutside" },
	},
	NAMES = {
		Center = "Center", Left = "Left", Right = "Right", Top = "Top", Bottom = "Bottom", TopLeft = "Top left", TopRight = "Top right",
		LeftOutside = "Left outside", RightOutside = "Right outside", LeftRight = "Left and Right", TopBottom = "Top and Bottom",
		LeftRightOutside = "Left and Right outside",
	},
	BY_NUMBER = { [0] = "Center", "Left", "Right", "Top", "Bottom", "TopLeft", "TopRight", "LeftOutside", "RightOutside", "LeftRight", "TopBottom", "LeftRightOutside" },
	MAX_SCALE = 5,
}

-- GEOMETRY: by piece, its width and height in units, the point of the piece and the point of the holder it hangs on, the offset along x,
-- whether the picture is mirrored across or down, and the way a second proc on the same place moves out (dx, dy: -1, 0 or 1).
local G = {
	Center = { w = K.LONG, h = K.LONG, point = "CENTER", rel = "CENTER", x = 0, dx = 0, dy = 1 },
	Left = { w = K.SHORT, h = K.LONG, point = "RIGHT", rel = "LEFT", x = 0, dx = -1, dy = 0 },
	LeftOutside = { w = K.SHORT, h = K.LONG, point = "RIGHT", rel = "LEFT", x = -K.SHORT, dx = -1, dy = 0 },
	Right = { w = K.SHORT, h = K.LONG, point = "LEFT", rel = "RIGHT", x = 0, dx = 1, dy = 0, flipH = true },
	RightOutside = { w = K.SHORT, h = K.LONG, point = "LEFT", rel = "RIGHT", x = K.SHORT, dx = 1, dy = 0, flipH = true },
	Top = { w = K.LONG, h = K.SHORT, point = "BOTTOM", rel = "TOP", x = 0, dx = 0, dy = 1 },
	Bottom = { w = K.LONG, h = K.SHORT, point = "TOP", rel = "BOTTOM", x = 0, dx = 0, dy = -1, flipV = true },
	TopRight = { w = K.SHORT, h = K.SHORT, point = "BOTTOMLEFT", rel = "TOPRIGHT", x = 0, dx = 1, dy = 0 },
	TopLeft = { w = K.SHORT, h = K.SHORT, point = "BOTTOMRIGHT", rel = "TOPLEFT", x = 0, dx = -1, dy = 0 },
}

-- holder: the frame everything hangs on, made out of combat. pool: pieces not in use. ups: the procs drawn, in the order they came up.
-- fading: pieces that are fading out. last: what each entry was last drawn with, for the check.
local holder
local pool, ups, fading, last = {}, {}, {}, {}

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

local function Setting(name, default)
	local value = ns.Get(KEY .. "." .. name)
	if Plain(value, "number") then
		return value
	end
	return default
end

local function On()
	return ns.Get(KEY .. ".art") == true
end

function ns.ProcArtOn()
	return On()
end

-- The pieces a location stands for.
local function Locations(location)
	return K.SIDES[location] or { location }
end

-- What a proc is drawn with, from what Procs.lua gives: the file, the location, the scale and the colour. A proc with no file is the arc on
-- the left and the right. A location the game does not have is left and right.
local function Normalise(data)
	data = type(data) == "table" and data or {}
	local file, location, scale = data.file, data.location, data.scale
	if Plain(location, "number") then
		location = K.BY_NUMBER[location]
	end
	if not (Plain(location, "string") and (G[location] or K.SIDES[location])) then
		location = "LeftRight"
	end
	local arc = not ((Plain(file, "number") and file > 0) or (Plain(file, "string") and file ~= ""))
	if arc then
		file, location = K.ARC, "LeftRight"
	end
	if not (Plain(scale, "number") and scale > 0) then
		scale = 1
	end
	scale = math.min(scale, K.MAX_SCALE)
	local colour = {}
	for i, name in ipairs({ "r", "g", "b" }) do
		local value = data[name]
		colour[i] = Plain(value, "number") and math.max(0, math.min(1, value)) or nil
	end
	if not (colour[1] and colour[2] and colour[3]) then
		colour = nil
	end
	return { file = file, location = location, scale = scale, colour = colour, arc = arc }
end

-- The colour of a proc's art: the entry's own when Procs.lua says one, else the one that came with the proc, else gold.
local function ColourOf(entry, art)
	if type(ns.ProcColour) == "function" then
		local ok, r, g, b = pcall(ns.ProcColour, entry)
		if ok and Plain(r, "number") and Plain(g, "number") and Plain(b, "number") then
			return r, g, b
		end
	end
	if art.colour then
		return art.colour[1], art.colour[2], art.colour[3]
	end
	return K.FALLBACK[1], K.FALLBACK[2], K.FALLBACK[3]
end

-- The pieces ---------------------------------------------------------------------------------------------------------------------

local function Release(piece)
	piece.live = false
	piece.byGame = false
	piece.animIn:Stop()
	piece.animOut:Stop()
	piece.pulse:Stop()
	piece:Hide()
	fading[piece] = nil
	pool[#pool + 1] = piece
end

local function MakePiece()
	local piece = CreateFrame("Frame", nil, holder)
	ns.Own[piece] = true
	piece:Hide()
	piece.tex = piece:CreateTexture(nil, "ARTWORK", nil, 0)
	ns.Own[piece.tex] = true
	piece.tex:SetAllPoints(piece)
	piece.animIn = piece:CreateAnimationGroup()
	local fadeIn = piece.animIn:CreateAnimation("Alpha")
	fadeIn:SetFromAlpha(0)
	fadeIn:SetToAlpha(1)
	fadeIn:SetDuration(K.FADE_IN)
	piece.animIn:SetScript("OnPlay", function()
		piece:SetAlpha(0)
	end)
	piece.animIn:SetScript("OnFinished", function()
		piece:SetAlpha(1)
		if piece.live then
			piece.pulse:Play()
		end
	end)
	piece.animOut = piece:CreateAnimationGroup()
	local fadeOut = piece.animOut:CreateAnimation("Alpha")
	fadeOut:SetFromAlpha(1)
	fadeOut:SetToAlpha(0)
	fadeOut:SetDuration(K.FADE_OUT)
	piece.animOut:SetScript("OnFinished", function()
		Release(piece)
	end)
	piece.pulse = piece:CreateAnimationGroup()
	piece.pulse:SetLooping("REPEAT")
	for order, scale in ipairs({ K.PULSE_UP, K.PULSE_DOWN }) do
		local step = piece.pulse:CreateAnimation("Scale")
		step:SetScaleFrom(1, 1)
		step:SetScaleTo(scale, scale)
		step:SetDuration(K.PULSE_TIME)
		step:SetSmoothing("IN_OUT")
		step:SetOrder(order)
	end
	return piece
end

local function Acquire()
	local piece = table.remove(pool)
	if not piece then
		local ok, made = pcall(MakePiece)
		if not ok then
			return nil
		end
		piece = made
	end
	return piece
end

-- Where the pieces of a proc go and how large: the game's place for the first proc, moved out by a piece for the second, and above
-- for the third. The offset of an outside piece is the game's, a short side, and is not scaled.
local function Spot(name, art, slot)
	local g = G[name]
	local size = Setting("artSize", 100) / 100 * art.scale
	local w, h = g.w * size, g.h * size
	local x, y = g.x, 0
	if slot == 2 then
		x, y = x + g.dx * w, y + g.dy * h
	elseif slot == 3 then
		if g.dy ~= 0 then
			y = y + g.dy * h * 2
		else
			y = y + h
		end
	end
	return g, w, h, x, y
end

local function Place(piece, name, art, slot)
	local g, w, h, x, y = Spot(name, art, slot)
	piece:ClearAllPoints()
	piece:SetPoint(g.point, holder, g.rel, x, y)
	piece:SetSize(w, h)
	piece.tex:SetTexCoord(g.flipH and 1 or 0, g.flipH and 0 or 1, g.flipV and 1 or 0, g.flipV and 0 or 1)
end

-- True while the game's own icon of the proc is on show with the art made on its button, so the pieces of the holder are not drawn twice.
local function GameIcon(entry)
	local slots = ns.TrackerSlots
	local call = type(slots) == "table" and slots.InUse
	return type(call) == "function" and call(entry) == true
end

-- Draws a proc's pieces with what it has now, for a proc that came up and for a setting that changed.
local function Layout(rec)
	local r, g, b = ColourOf(rec.entry, rec.art)
	local game = GameIcon(rec.entry)
	rec.drew = true
	local wanted = Locations(rec.art.location)
	for name, piece in pairs(rec.pieces) do
		if name ~= wanted[1] and name ~= wanted[2] then
			rec.pieces[name] = nil
			Release(piece)
		end
	end
	for _, name in ipairs(wanted) do
		local piece = rec.pieces[name]
		if not piece then
			piece = Acquire()
			if not piece then
				rec.drew = false
			else
				rec.pieces[name] = piece
				piece.live = true
				piece.animIn:Stop()
				piece.animOut:Stop()
				piece.pulse:Stop()
				piece:SetAlpha(1)
				fading[piece] = nil
				piece.fresh = true
			end
		end
		if piece then
			Place(piece, name, rec.art, rec.slot)
			local ok = pcall(piece.tex.SetTexture, piece.tex, rec.art.file)
			rec.drew = rec.drew and ok
			piece.tex:SetVertexColor(r, g, b)
			if piece.fresh then
				piece.fresh = false
				piece:Show()
				piece.animIn:Play()
			end
			if game and not piece.byGame then
				piece.byGame = true
				piece:Hide()
			elseif not game and piece.byGame then
				piece.byGame = false
				piece:Show()
			end
		end
	end
end

-- The holder: 204.8 square at the middle of the screen, as high as Art height says, and as clear as Art opacity says.
local function PlaceHolder()
	holder:ClearAllPoints()
	holder:SetPoint("CENTER", UIParent, "CENTER", 0, Setting("artY", 0))
	holder:SetAlpha(Setting("artAlpha", 65) / 100)
end

local function Build()
	if holder then
		return true
	end
	if InCombatLockdown() then
		return false
	end
	local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent)
	if not ok then
		return false
	end
	holder = frame
	ns.Own[holder] = true
	holder:SetSize(K.LONG, K.LONG)
	PlaceHolder()
	holder:Show()
	for _ = 1, K.POOL do
		local made, piece = pcall(MakePiece)
		if made then
			pool[#pool + 1] = piece
		end
	end
	return true
end

-- The lowest place 1 to 3 that no other proc up has a piece of the same location in.
local function SlotFor(rec)
	local taken = {}
	for _, other in ipairs(ups) do
		if other ~= rec then
			for _, name in ipairs(Locations(other.art.location)) do
				for _, mine in ipairs(Locations(rec.art.location)) do
					if name == mine then
						taken[other.slot] = true
					end
				end
			end
		end
	end
	for slot = 1, K.MAX do
		if not taken[slot] then
			return slot
		end
	end
	return K.MAX
end

local function Flush()
	if not Build() then
		return
	end
	for _, rec in ipairs(ups) do
		Layout(rec)
	end
end

local function Find(entry)
	for index, rec in ipairs(ups) do
		if rec.entry == entry or (rec.id ~= nil and rec.id == (type(entry) == "table" and entry.id)) then
			return rec, index
		end
	end
end

-- The calls for Procs.lua ---------------------------------------------------------------------------------------------------------

-- A proc came up, or its art changed. data is what Procs.lua gives: file, location, scale, r, g, b, all optional. Nothing is drawn with the
-- art off, and nothing beyond three procs at once.
function ns.ProcArtShow(entry, data)
	if type(entry) ~= "table" or not On() then
		return false
	end
	local art = Normalise(data)
	local rec = Find(entry)
	if rec then
		rec.art = art
		rec.slot = SlotFor(rec)
	else
		if #ups >= K.MAX then
			return false
		end
		rec = { entry = entry, id = entry.id, art = art, pieces = {} }
		ups[#ups + 1] = rec
		rec.slot = SlotFor(rec)
	end
	last[rec.id or entry] = { file = art.file, location = art.location, arc = art.arc }
	if holder then
		Layout(rec)
		last[rec.id or entry].drew = rec.drew
	else
		ns.OutOfCombat(function()
			Flush()
			local seen = last[rec.id or entry]
			if seen then
				seen.drew = rec.drew
			end
		end)
	end
	return true
end

-- A proc ended: its pieces fade out and the others keep their places. now: stop at once, with no fade.
function ns.ProcArtHide(entry, now)
	local rec, index = Find(entry)
	if not rec then
		return false
	end
	table.remove(ups, index)
	for _, piece in pairs(rec.pieces) do
		piece.live = false
		if now or piece.byGame or not piece:IsShown() then
			Release(piece)
		else
			piece.animIn:Stop()
			piece.pulse:Pause()
			fading[piece] = true
			piece.animOut:Play()
		end
	end
	rec.pieces = {}
	return true
end

-- Pieces in the pool and pieces fading, for the test.
function ns.ProcArtCounts()
	return #pool, (function()
		local n = 0
		for _ in pairs(fading) do
			n = n + 1
		end
		return n
	end)()
end

-- Everything back: no proc up, no animation running, every piece hidden.
function ns.ProcArtReset()
	while #ups > 0 do
		ns.ProcArtHide(ups[1].entry, true)
	end
	for piece in pairs(fading) do
		Release(piece)
	end
end

-- A row of Proc alerts changed: the art goes at once when it is off, else the holder and the pieces take the new size, height or opacity.
function ns.ProcArtChanged()
	if holder then
		if not On() then
			ns.ProcArtReset()
		else
			PlaceHolder()
			for _, rec in ipairs(ups) do
				Layout(rec)
			end
		end
	end
	-- The pieces made on the game's buttons take the new row when the game says buffs are open, else at the end of the fight.
	local slots = ns.TrackerSlots
	if type(slots) == "table" and type(slots.Flush) == "function" then
		slots.Flush()
	end
end

-- The pieces on the game's button -------------------------------------------------------------------------------------------------

-- REL: the point of the holder a piece hangs on (G's rel), as a step of half the holder's side along x and y.
local REL = {
	CENTER = { 0, 0 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 }, TOP = { 0, 1 }, BOTTOM = { 0, -1 },
	TOPLEFT = { -1, 1 }, TOPRIGHT = { 1, 1 },
}

-- The lowest place 1 to 3 that none of the placed procs (each { art, slot }) has a piece of the same location in.
local function Lowest(art, placed)
	local taken = {}
	for _, other in ipairs(placed) do
		for _, name in ipairs(Locations(other.art.location)) do
			for _, mine in ipairs(Locations(art.location)) do
				if mine == name then
					taken[other.slot] = other.slot
				end
			end
		end
	end
	for slot = 1, K.MAX do
		if not taken[slot] then
			return slot
		end
	end
	return K.MAX
end

-- The place of a proc whose pieces are on the game's button: fixed by the order of the proc trackers, as the proc trackers before it take places,
-- so two procs never stack and the place does not depend on which is up.
local function FixedSlot(entry, art)
	local list = type(ns.TrackerEntries) == "function" and ns.TrackerEntries() or {}
	local placed = {}
	for _, other in ipairs(type(list) == "table" and list or {}) do
		if type(other) == "table" then
			if other == entry or (other.id ~= nil and other.id == entry.id) then
				break
			elseif other.kind == "proc" then
				local give = type(ns.ProcArtData) == "function" and ns.ProcArtData
				local ok, data = false, nil
				if give then
					ok, data = pcall(give, other)
				end
				local theirs = Normalise(ok and data or nil)
				placed[#placed + 1] = { art = theirs, slot = Lowest(theirs, placed) }
			end
		end
	end
	return Lowest(art, placed)
end

-- The size of the button against the screen's: a piece on the button is drawn in the button's units, so it is divided by this to be the size
-- the holder's piece is.
local function Ratio(button)
	local ok, mine = pcall(button.GetEffectiveScale, button)
	local fine, base = pcall(UIParent.GetEffectiveScale, UIParent)
	if ok and fine and Plain(mine, "number") and Plain(base, "number") and mine > 0 and base > 0 then
		return mine / base
	end
	return 1
end

-- What the pieces on the button are drawn with, as one text: the row's state, size, opacity and height, the colour, the place and the file.
local function Key(entry, art, slot)
	local r, g, b = ColourOf(entry, art)
	return table.concat({ On() and "on" or "off", Setting("artSize", 100), Setting("artAlpha", 65), Setting("artY", 0), r, g, b, slot,
		tostring(art.file), art.location }, "|")
end

-- Makes the pieces of a proc's art as textures of the game's button, the same pieces the holder has (G and K), each anchored to the middle of the
-- screen, and returns what TrackerSlots.lua needs to keep them right: Pending, Apply and Shown. Run by TrackerSlots.lua inside the function the game
-- calls while it builds the slot; it raises when the game refuses a texture, which TrackerSlots.lua takes as "refused by the game". The pieces
-- have no animation: the button is closed to addon code in a fight, and a piece shows when the button does. With the row off they are clear.
function ns.ProcArtParts(rec, button, entry)
	if type(entry) ~= "table" then
		error("no proc to draw", 0)
	end
	local given = type(ns.ProcArtData) == "function" and ns.ProcArtData
	local art = Normalise(given and select(2, pcall(given, entry)) or nil)
	local pieces = {}
	for _, name in ipairs(Locations(art.location)) do
		local ok, texture = pcall(button.CreateTexture, button, nil, "ARTWORK", nil, 0)
		if not ok or type(texture) ~= "table" then
			for _, made in pairs(pieces) do
				pcall(made.SetAlpha, made, 0)
			end
			error("the game refused a piece of art", 0)
		end
		ns.Own[texture] = true
		pieces[name] = texture
	end
	local handle = {}
	local function Put()
		local slot = FixedSlot(entry, art)
		local key = Key(entry, art, slot)
		local r, g, b = ColourOf(entry, art)
		local ratio = Ratio(button)
		local alpha = On() and Setting("artAlpha", 65) / 100 or 0
		local height = Setting("artY", 0)
		for name, texture in pairs(pieces) do
			local geometry, w, h, x, y = Spot(name, art, slot)
			local step = REL[geometry.rel] or REL.CENTER
			texture:ClearAllPoints()
			texture:SetPoint(geometry.point, UIParent, "CENTER", (x + step[1] * K.LONG / 2) / ratio, (y + step[2] * K.LONG / 2 + height) / ratio)
			texture:SetSize(w / ratio, h / ratio)
			texture:SetTexture(art.file)
			texture:SetTexCoord(geometry.flipH and 1 or 0, geometry.flipH and 0 or 1, geometry.flipV and 1 or 0, geometry.flipV and 0 or 1)
			texture:SetVertexColor(r, g, b)
			texture:SetAlpha(alpha)
		end
		handle.key = key
	end
	Put()
	handle.pieces = pieces
	function handle.Pending()
		return handle.key ~= Key(entry, art, FixedSlot(entry, art))
	end
	function handle.Apply()
		Put()
	end
	-- The game's icon started or stopped being on show: the proc's pieces on the holder are drawn again, or hidden.
	function handle.Shown()
		local found = Find(entry)
		if found and holder then
			Layout(found)
		end
	end
	return handle
end

-- The line of /flatui tracker check for a proc entry.
function ns.ProcArtLine(entry)
	if not On() then
		return "Art: off"
	end
	local seen = type(entry) == "table" and (last[entry.id or entry] or last[entry])
	if not seen then
		return "Art: not drawn yet"
	end
	return ("Art: file %s, %s, drew %s. A file that does not draw is a green block: look at /flatui tracker test."):format(
		tostring(seen.arc and "arc" or seen.file), K.NAMES[seen.location] or seen.location, seen.drew and "yes" or "no")
end

-- The holder is made at login, out of combat (or when combat ends after a /reload in combat), so the first proc of a fight draws at once.
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	ns.OutOfCombat(Build)
end)
