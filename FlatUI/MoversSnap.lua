local _, ns = ...

local Z = {}
ns.MoversSnap = Z

local NEAR = 5
Z.near = NEAR

local picked = {}
local ui = {}

local function Kit()
	return ns.MoverKit
end

function Z.On()
	if type(InCombatLockdown) == "function" and InCombatLockdown() then
		return false
	end
	return ns.PanelLook.Get("snapFrames") == "on"
end

function Z.Pull(start, size, spans)
	local best, at
	for _, other in ipairs(spans) do
		for _, mine in ipairs({ start, start + size / 2, start + size }) do
			for _, theirs in ipairs({ other[1], other[1] + other[2] / 2, other[1] + other[2] }) do
				local move = theirs - mine
				if math.abs(move) <= NEAR and (best == nil or math.abs(move) < math.abs(best)) then
					best, at = move, theirs
				end
			end
		end
	end
	return best, at
end

function Z.Spread(spans)
	if #spans < 3 then
		return nil
	end
	local order = {}
	for index in ipairs(spans) do
		order[index] = index
	end
	table.sort(order, function(a, b)
		if spans[a][1] ~= spans[b][1] then
			return spans[a][1] < spans[b][1]
		end
		return a < b
	end)
	local first, last = spans[order[1]], spans[order[#order]]
	local room = last[1] + last[2] - first[1]
	for _, index in ipairs(order) do
		room = room - spans[index][2]
	end
	local gap = room / (#order - 1)
	local starts, at = {}, first[1]
	for _, index in ipairs(order) do
		starts[index] = at
		at = at + spans[index][2] + gap
	end
	return starts
end

local function Guide(key)
	if not ui.frame then
		local frame = CreateFrame("Frame", nil, UIParent)
		ns.Own[frame] = true
		frame:SetFrameStrata("FULLSCREEN_DIALOG")
		frame:SetFrameLevel(2)
		frame:SetAllPoints(UIParent)
		ui.frame = frame
	end
	if not ui[key] then
		local texture = ui.frame:CreateTexture(nil, "OVERLAY", nil, 0)
		ns.Own[texture] = true
		pcall(texture.SetSnapToPixelGrid, texture, false)
		pcall(texture.SetTexelSnappingBias, texture, 0)
		ui[key] = texture
	end
	return ui[key]
end

function Z.Guides(x, y)
	local r, g, b = ns.PanelLook.Colour("accent")
	local thin = 1
	if x then
		local line = Guide("vertical")
		line:SetColorTexture(r, g, b, 1)
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x - thin / 2, 0)
		line:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x - thin / 2, 0)
		line:SetWidth(thin)
		line:Show()
	elseif ui.vertical then
		ui.vertical:Hide()
	end
	if y then
		local line = Guide("horizontal")
		line:SetColorTexture(r, g, b, 1)
		line:ClearAllPoints()
		line:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, y - thin / 2)
		line:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, y - thin / 2)
		line:SetHeight(thin)
		line:Show()
	elseif ui.horizontal then
		ui.horizontal:Hide()
	end
end

function Z.Hide()
	Z.Guides(nil, nil)
end

local function Others(skip)
	local kit = Kit()
	local xs, ys = {}, {}
	for name, handle in pairs(kit.handles) do
		local look = kit.looks[name]
		if name ~= skip and look and look.shown and not look.placedByGame and not ns.MoversMode.Hidden(name) then
			local left, bottom, width, height = kit.Rect(handle)
			if left then
				xs[#xs + 1] = { left, width }
				ys[#ys + 1] = { bottom, height }
			end
		end
	end
	return xs, ys
end

local function Pulled(name, left, bottom, width, height, onMiddle)
	local xs, ys = Others(name)
	local moveX, atX, moveY, atY
	if not onMiddle then
		moveX, atX = Z.Pull(left, width, xs)
	end
	moveY, atY = Z.Pull(bottom, height, ys)
	local wide, high = Kit().ScreenSize()
	left, bottom = left + (moveX or 0), bottom + (moveY or 0)
	if wide then
		left = math.max(0, math.min(left, wide - width))
	end
	if high then
		bottom = math.max(0, math.min(bottom, high - height))
	end
	Z.Guides(atX, atY)
	return left, bottom
end

function Z.Snap(name, left, bottom, width, height, onMiddle)
	if not (name and Z.On()) then
		Z.Hide()
		return left, bottom
	end
	local ok, newLeft, newBottom = pcall(Pulled, name, left, bottom, width, height, onMiddle)
	if ok and newLeft then
		return newLeft, newBottom
	end
	Z.Hide()
	return left, bottom
end

function Z.Picked(name)
	return picked[name] == true
end

function Z.List()
	local kit, names = Kit(), {}
	for name in pairs(picked) do
		local look = kit.looks[name]
		if look and look.shown and not look.placedByGame and kit.handles[name] and kit.Readable(name) then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	return names
end

function Z.Toggle(name, chosen)
	if next(picked) == nil and chosen and chosen ~= name then
		picked[chosen] = true
		ns.MoversMode.Paint(chosen)
	end
	picked[name] = (not picked[name]) or nil
	ns.MoversMode.Paint(name)
end

function Z.Clear()
	local was = picked
	picked = {}
	for name in pairs(was) do
		ns.MoversMode.Paint(name)
	end
end

function Z.Space(axis)
	if type(InCombatLockdown) == "function" and InCombatLockdown() then
		return 0
	end
	local kit = Kit()
	local names = Z.List()
	if #names < 3 then
		return 0
	end
	local boxes, spans = {}, {}
	for index, name in ipairs(names) do
		local left, bottom, width, height = kit.Rect(kit.handles[name])
		if not left then
			return 0
		end
		boxes[index] = { left, bottom, width, height }
		spans[index] = axis == "y" and { bottom, height } or { left, width }
	end
	local starts = Z.Spread(spans)
	if not starts then
		return 0
	end
	local moved = 0
	ns.MoversMode.Group(true)
	for index, name in ipairs(names) do
		local box, info = boxes[index], kit.Describe(name)
		local now = axis == "y" and box[2] or box[1]
		if info and math.abs(starts[index] - now) >= 0.5 then
			local left, bottom = box[1], box[2]
			if axis == "y" then
				bottom = starts[index]
			else
				left = starts[index]
			end
			if kit.Commit(name, info, left, bottom, box[3], box[4]) then
				moved = moved + 1
			end
			kit.ShowHandle(name)
		end
	end
	ns.MoversMode.Group(false)
	ns.MoversMode.Refresh(true)
	return moved
end

function Z.State()
	return picked, ui
end
