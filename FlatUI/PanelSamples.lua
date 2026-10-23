local ADDON_NAME, ns = ...

-- Samples in the choice lists of the options window: a bar texture as a short bar, a font as letters in its own face and a row direction as an
-- arrow, 48 by 12 at the left of a line and of the button of its list. The setting Samples in lists turns them off.

local Samples = {}
ns.PanelSamples = Samples

local kit = ns.PanelKit
local Look = ns.PanelLook

local WIDTH, HEIGHT, GAP = 48, 12, 6
Samples.WIDTH, Samples.GAP = WIDTH, GAP

local FILLED = 34
local FACES = { sans = true, friz = true, arial = true, morpheus = true, skurri = true }
-- Where the arrow of a row direction points: its head at the left end, at the right end, and the tick at its start.
local HEADS = { center = { true, true }, right = { false, true }, left = { true, false } }
-- A vertical direction: its head at the top (up) or at the bottom (down).
local VHEADS = { up = 1, down = 2 }

function Samples.On()
	return Look.Get("samples") == "on"
end

-- The kind of sample a row has: "texture", "font" or "grow", or nil. A row with sample = false has none.
function Samples.Kind(item)
	local choices = item.choices
	if item.sample == false or choices == nil then
		return nil
	end
	if choices == ns.BAR_CHOICES or choices == "BarChoicesDefault" then
		return "texture"
	end
	if choices == ns.FONT_CHOICES or choices == "FontChoices" then
		return "font"
	end
	if type(choices) == "table" then
		if #choices == 2 and VHEADS[choices[1][1]] and VHEADS[choices[2][1]] and choices[1][1] ~= choices[2][1] then
			return "grow"
		end
		for _, line in ipairs(choices) do
			if line[1] == "center" and item.key == "grow" then
				return "grow"
			end
			if FACES[line[1]] then
				return "font"
			end
		end
	end
	return nil
end

-- The file a font id draws in, or nil for the game font.
function Samples.Face(id)
	if id == "sans" then
		return Look.SansFile
	end
	return ns.FontFile(id)
end

-- A sample on parent. Set(kind, id) draws the sample of one line; frame is the frame to place.
function Samples.New(parent)
	local frame = kit.Frame(parent)
	frame:SetSize(WIDTH, HEIGHT)
	local groove = kit.Fill(frame, "BACKGROUND")
	groove:SetAllPoints(frame)
	local bar = kit.Fill(frame, "ARTWORK")
	bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	bar:SetWidth(FILLED)
	local letters = kit.Label(frame, "GameFontHighlightSmall", "LEFT", WIDTH)
	letters:SetPoint("LEFT", frame, "LEFT", 0, 0)
	local line = kit.Fill(frame, "ARTWORK")
	line:SetPoint("LEFT", frame, "LEFT", 2, 0)
	line:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
	line:SetHeight(1)
	local tick = kit.Fill(frame, "ARTWORK")
	tick:SetSize(1, 8)
	local heads = { {}, {} }
	for side = 1, 2 do
		for step = 1, 4 do
			local piece = kit.Fill(frame, "ARTWORK")
			piece:SetSize(1, 2 * step - 1)
			if side == 1 then
				piece:SetPoint("LEFT", frame, "LEFT", 2 + (step - 1), 0)
			else
				piece:SetPoint("RIGHT", frame, "RIGHT", -(2 + (step - 1)), 0)
			end
			heads[side][step] = piece
		end
	end
	local vline = kit.Fill(frame, "ARTWORK")
	vline:SetSize(1, HEIGHT - 2)
	vline:SetPoint("CENTER", frame, "CENTER", 0, 0)
	local vheads = { {}, {} }
	for side = 1, 2 do
		for step = 1, 4 do
			local piece = kit.Fill(frame, "ARTWORK")
			piece:SetSize(2 * step - 1, 1)
			piece:SetPoint(side == 1 and "TOP" or "BOTTOM", frame, side == 1 and "TOP" or "BOTTOM", 0, side == 1 and -(step - 1) or (step - 1))
			vheads[side][step] = piece
		end
	end
	local state = {}
	local object = { frame = frame }
	local function Draw()
		local kind, id = state.kind, state.id
		groove:SetShown(kind == "texture")
		bar:SetShown(kind == "texture")
		letters:SetShown(kind == "font")
		local vertical = kind == "grow" and VHEADS[id] ~= nil
		line:SetShown(kind == "grow" and not vertical)
		tick:SetShown(kind == "grow" and not vertical)
		vline:SetShown(vertical)
		for side = 1, 2 do
			for step = 1, 4 do
				vheads[side][step]:SetShown(vertical and VHEADS[id] == side)
			end
		end
		for side = 1, 2 do
			for step = 1, 4 do
				heads[side][step]:SetShown(kind == "grow" and not vertical and HEADS[id] ~= nil and HEADS[id][side] == true)
			end
		end
		if kind == "texture" then
			Look.Solid(groove, "window")
			local file = ns.BarTexture(id)
			if file then
				bar:SetTexture(file)
				bar:SetVertexColor(kit.Accent())
			else
				bar:SetVertexColor(1, 1, 1)
				bar:SetColorTexture(kit.Accent())
			end
		elseif kind == "font" then
			letters:SetText("Abc 123")
			local face = Samples.Face(id)
			local set = false
			if face then
				local ok, done = pcall(letters.SetFont, letters, face, Look.SampleSize(), "")
				set = ok and done ~= false
			end
			if not set then
				pcall(letters.SetFontObject, letters, "GameFontHighlightSmall")
			end
		elseif kind == "grow" then
			local r, g, b = Look.Colour("text")
			local arrow = HEADS[id]
			vline:SetColorTexture(r, g, b)
			for side = 1, 2 do
				for step = 1, 4 do
					vheads[side][step]:SetColorTexture(r, g, b)
				end
			end
			line:SetColorTexture(r, g, b)
			tick:SetColorTexture(r, g, b)
			tick:ClearAllPoints()
			if arrow and arrow[1] and arrow[2] then
				tick:SetPoint("CENTER", frame, "CENTER", 0, 0)
			elseif arrow and arrow[1] then
				tick:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
			else
				tick:SetPoint("LEFT", frame, "LEFT", 2, 0)
			end
			for side = 1, 2 do
				for step = 1, 4 do
					heads[side][step]:SetColorTexture(r, g, b)
				end
			end
		end
	end
	function object.Set(kind, id)
		state.kind, state.id = kind, id
		Draw()
	end
	kit.Painted(Draw)
	return object
end
