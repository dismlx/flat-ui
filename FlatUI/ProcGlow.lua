local _, ns = ...

local KEY = "trackers"
local ATLAS = "UI-HUD-ActionBar-Proc-Loop-Flipbook"
local START_ATLAS = "UI-HUD-ActionBar-Proc-Start-Flipbook"
local START_SIZE, START_SECONDS = 150 / 45, 0.7
local SCALE = 1.4
local GOLD = { 1, 0.82, 0 }
local SOFT = { RING = 2, HALO = 4, HALO_ALPHA = 0.8, LOW = 0.25, HIGH = 0.6, SECONDS = 1.2, EDGE = 0.25,
	FILE = "Interface\\AddOns\\FlatUI\\Media\\Shadow.tga" }
local REFUSED = "Proc glow: the game refused a call on an action button in a fight. The border is drawn without the glow."

local active, seq = {}, 0
local users = setmetatable({}, { __mode = "k" })
local glows = setmetatable({}, { __mode = "k" })
local pending = setmetatable({}, { __mode = "k" })
local gameAlert = setmetatable({}, { __mode = "k" })
local drawn = setmetatable({}, { __mode = "k" })
local hooked = false
local ownGame = setmetatable({}, { __mode = "k" })

local function Plain(value, kind)
	return type(value) == kind and not ns.IsSecret(value)
end

local function Wanted()
	return ns.Enabled(KEY) and ns.Get(KEY .. ".glow") == true
end

local function Style()
	return ns.Get(KEY .. ".glowStyle") == "game" and "game" or "soft"
end

local function LookOf(made)
	if Style() == "game" and made.textured then
		return "game"
	end
	if made.soft then
		return "soft"
	end
	return made.textured and "game" or nil
end

local function Colour(entry)
	if type(ns.ProcColour) == "function" then
		local ok, r, g, b = pcall(ns.ProcColour, entry)
		if ok and Plain(r, "number") and Plain(g, "number") and Plain(b, "number") then
			return r, g, b
		end
	end
	return GOLD[1], GOLD[2], GOLD[3]
end

local function SpellName(id)
	if not (C_Spell and C_Spell.GetSpellName) then
		return nil
	end
	local ok, name = pcall(C_Spell.GetSpellName, id)
	if ok and Plain(name, "string") and name ~= "" then
		return name
	end
	return nil
end

local GAME_BARS = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarLeftButton", "MultiBarRightButton",
	"MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }

local function Unstyled(names, set)
	if type(ns.ButtonAction) ~= "function" or next(names) == nil then
		return
	end
	local list = {}
	if type(ns.OwnOn) == "function" and ns.OwnOn() == true then
		local ok, buttons = pcall(ns.OwnButtons)
		for _, button in ipairs(ok and type(buttons) == "table" and buttons or {}) do
			list[#list + 1] = button
		end
	elseif not ns.HandsOff() then
		for _, bar in ipairs(GAME_BARS) do
			for index = 1, 12 do
				local button = _G[bar .. index]
				if Plain(button, "table") and not ns.Forbidden(button) then
					list[#list + 1] = button
				end
			end
		end
	end
	for _, button in ipairs(list) do
		if not set[button] then
			local ok, kind, _, name = pcall(ns.ButtonAction, button)
			if ok and kind == "spell" and Plain(name, "string") and names[name:lower()] then
				set[button] = true
			end
		end
	end
end

local function Holders(entry, any)
	local set, seen = {}, {}
	if (entry.glow == false and not any) or type(entry.lights) ~= "table" then
		return set
	end
	for index = 1, any and #entry.lights or math.min(#entry.lights, 40) do
		local id = entry.lights[index]
		local name = Plain(id, "number") and SpellName(id)
		if name and not seen[name:lower()] then
			seen[name:lower()] = true
			if type(ns.ButtonsFor) == "function" then
				for _, button in ipairs(ns.ButtonsFor("spell", name:lower())) do
					set[button] = true
				end
			end
		end
	end
	if not ns.Enabled("actionbars") or next(set) == nil then
		Unstyled(seen, set)
	end
	return set
end

local function Refused()
	ns.Note(KEY, REFUSED)
end

local ROWS, COLUMNS, FRAMES, SECONDS = 6, 5, 30, 1

local function ParentOf(button)
	if type(ns.ButtonIsOwn) == "function" and ns.ButtonIsOwn(button) then
		return button
	end
	local ok, parent = pcall(button.GetParent, button)
	if ok and Plain(parent, "table") then
		return parent
	end
	return UIParent
end

local function Cell(texture, box, index)
	local column, row = index % COLUMNS, math.floor(index / COLUMNS)
	local width, height = (box.right - box.left) / COLUMNS, (box.bottom - box.top) / ROWS
	texture:SetTexCoord(box.left + column * width, box.left + (column + 1) * width, box.top + row * height, box.top + (row + 1) * height)
end

local FADE_OUT = 0.2

local function Stopped(made)
	made.fadeLeft = nil
	if made.unmark then
		made.unmark = nil
		if users[made.button] == nil then
			ns.SetButtonMark(made.button, "proc", nil)
			drawn[made.button] = nil
		end
	end
	if made.time then
		made.shown = nil
		made.time:Hide()
	end
	made.mark = nil
	if not pcall(function()
		made.frame:SetScript("OnUpdate", nil)
		made.frame:SetAlpha(0)
		made.alpha = 0
		if made.soft then
			made.soft.pulse:Pause()
		end
	end) then
		Refused()
	end
end

local TIME_SPOTS = { TOPLEFT = { 2, -2, "LEFT" }, TOPRIGHT = { -2, -2, "RIGHT" }, BOTTOMLEFT = { 2, 2, "LEFT" }, BOTTOMRIGHT = { -2, 2, "RIGHT" } }
local TIME_CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local TIME_TAKES = {
	topright = { TOPRIGHT = true }, topleft = { TOPLEFT = true }, top = { TOPLEFT = true, TOPRIGHT = true },
	bottomright = { BOTTOMRIGHT = true }, bottomleft = { BOTTOMLEFT = true }, bottom = { BOTTOMLEFT = true, BOTTOMRIGHT = true },
}
local TIME_LAST, TIME_GROW = 2, 1.15

local function TextOn(made)
	if not ns.Enabled("actionbars") then
		return false
	end
	if type(ns.ButtonIsOn) ~= "function" then
		return true
	end
	local ok, on = pcall(ns.ButtonIsOn, made.button)
	return ok and on == true
end

local function Corner(hot, name, count)
	local takes = { TIME_TAKES[hot] or {}, TIME_TAKES[count] or {}, TIME_TAKES[name] or {} }
	for tier = #takes, 1, -1 do
		for _, corner in ipairs(TIME_CORNERS) do
			local taken = false
			for index = 1, tier do
				taken = taken or takes[index][corner] == true
			end
			if not taken then
				return corner
			end
		end
	end
	return TIME_CORNERS[1]
end

local function Place(made)
	local text = made.time
	local hot, name, count = "topright", "bottom", "bottomright"
	if TextOn(made) then
		hot, name, count = ns.Get("actionbars.hotkeyPoint"), ns.Get("actionbars.namePoint"), ns.Get("actionbars.countPoint")
	end
	local key = ("%s:%s:%s"):format(tostring(hot), tostring(name), tostring(count))
	if made.timeAt == key then
		return
	end
	local corner = Corner(hot, name, count)
	local spot = TIME_SPOTS[corner]
	if pcall(function()
		text:ClearAllPoints()
		text:SetPoint(corner, made.button, corner, spot[1], spot[2])
		text:SetJustifyH(spot[3])
	end) then
		made.timeAt = key
	end
end

local function Look(made, last)
	local on = TextOn(made)
	local size = on and tonumber(ns.Get("actionbars.hotkeySize")) or 100
	local flags = on and type(ns.OutlineFlags) == "function" and ns.OutlineFlags(ns.Get("actionbars.textOutline")) or nil
	ns.TextStyle(made.time, { percent = size * (last and TIME_GROW or 1), flags = flags })
end

local function Count(made, seconds)
	local text = made.time
	if not text then
		return
	end
	made.timeClock = (made.timeClock or 0) - seconds
	if made.timeClock > 0 then
		return
	end
	made.timeClock = 0.1
	if made.fadeLeft and made.shown then
		return
	end
	local mark, left = made.mark, nil
	if type(mark) == "table" and type(mark[5]) == "table" and type(ns.ProcEnds) == "function" and ns.Get(KEY .. ".glowTime") == true then
		local ok, ends = pcall(ns.ProcEnds, mark[5])
		local okNow, now = pcall(GetTime)
		if ok and okNow and Plain(ends, "number") and Plain(now, "number") then
			left = ends - now
		end
	end
	if not (left and left > 0) then
		if made.shown then
			made.shown = nil
			text:Hide()
		end
		return
	end
	local n = math.ceil(left)
	local last = n <= TIME_LAST
	if last then
		text:SetTextColor(1, 1, 1)
	else
		text:SetTextColor(mark[1], mark[2], mark[3])
	end
	if made.shown ~= n then
		if made.shown == nil then
			Place(made)
		end
		Look(made, last)
		made.shown = n
		text:SetText(n)
		text:Show()
	end
end

local function Tick(made, seconds)
	made.clock = made.clock + seconds
	local ok, visible = pcall(made.button.IsVisible, made.button)
	local wanted = ok and visible == true and 1 or 0
	local left = made.fadeLeft
	if left then
		left = left - seconds
		if left <= 0 then
			Stopped(made)
			return
		end
		made.fadeLeft = left
		wanted = wanted * left / FADE_OUT
	end
	if made.alpha ~= wanted then
		made.alpha = wanted
		made.frame:SetAlpha(wanted)
	end
	Count(made, seconds)
	if wanted <= 0 or made.look ~= "game" then
		return
	end
	local start = made.start
	if start and made.clock < START_SECONDS then
		if made.bursting ~= true then
			made.bursting = true
			start:SetAlpha(1)
			made.texture:SetAlpha(0)
		end
		Cell(start, made.startBox, math.min(FRAMES - 1, math.floor(made.clock / START_SECONDS * FRAMES)))
		return
	end
	if made.bursting ~= false then
		made.bursting = false
		if start then
			start:SetAlpha(0)
		end
		made.texture:SetAlpha(1)
	end
	local clock = made.clock - (start and START_SECONDS or 0)
	Cell(made.texture, made, math.floor((clock % SECONDS) / SECONDS * FRAMES))
end

local function AtlasBox(name)
	if not (C_Texture and C_Texture.GetAtlasInfo) then
		return nil
	end
	local asked, info = pcall(C_Texture.GetAtlasInfo, name)
	if not (asked and Plain(info, "table")) then
		return nil
	end
	local box = { left = 0, right = 1, top = 0, bottom = 1 }
	for key, field in pairs({ left = "leftTexCoord", right = "rightTexCoord", top = "topTexCoord", bottom = "bottomTexCoord" }) do
		if Plain(info[field], "number") then
			box[key] = info[field]
		end
	end
	return box
end

local function Halo(frame, spill)
	local e, pieces = SOFT.EDGE, {}
	local function Piece(left, right, top, bottom)
		local texture = frame:CreateTexture(nil, "ARTWORK", nil, 0)
		ns.Own[texture] = true
		texture:SetTexture(SOFT.FILE)
		texture:SetTexCoord(left, right, top, bottom)
		pieces[#pieces + 1] = texture
		return texture
	end
	for _, side in ipairs({
		{ "BOTTOMLEFT", "TOPLEFT", "BOTTOMRIGHT", "TOPRIGHT", e, 1 - e, 0, e, "SetHeight" },
		{ "TOPLEFT", "BOTTOMLEFT", "TOPRIGHT", "BOTTOMRIGHT", e, 1 - e, 1 - e, 1, "SetHeight" },
		{ "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT", 0, e, e, 1 - e, "SetWidth" },
		{ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", 1 - e, 1, e, 1 - e, "SetWidth" },
	}) do
		local piece = Piece(side[5], side[6], side[7], side[8])
		piece:SetPoint(side[1], frame, side[2], 0, 0)
		piece:SetPoint(side[3], frame, side[4], 0, 0)
		piece[side[9]](piece, spill)
	end
	for _, corner in ipairs({
		{ "BOTTOMRIGHT", "TOPLEFT", 0, e, 0, e }, { "BOTTOMLEFT", "TOPRIGHT", 1 - e, 1, 0, e },
		{ "TOPRIGHT", "BOTTOMLEFT", 0, e, 1 - e, 1 }, { "TOPLEFT", "BOTTOMRIGHT", 1 - e, 1, 1 - e, 1 },
	}) do
		local piece = Piece(corner[3], corner[4], corner[5], corner[6])
		piece:SetPoint(corner[1], frame, corner[2], 0, 0)
		piece:SetSize(spill, spill)
	end
	return pieces
end

function ns.ProcGlowTint(look, r, g, b)
	if type(look) ~= "table" or (look.r == r and look.g == g and look.b == b) then
		return
	end
	look.r, look.g, look.b = r, g, b
	if look.ring then
		ns.SetOutlineColour(look.ring, r, g, b)
	end
	for _, piece in ipairs(look.halo) do
		piece:SetVertexColor(r, g, b, SOFT.HALO_ALPHA)
	end
end

function ns.ProcGlowSoft(parent, anchor)
	local frame = CreateFrame("Frame", nil, parent)
	ns.Own[frame] = true
	frame:SetAllPoints(anchor)
	frame:SetAlpha(0)
	local look = { frame = frame, high = SOFT.HIGH }
	look.ring = ns.Outline(frame, frame)
	if look.ring then
		ns.SetOutline(look.ring, true, false)
		ns.SetOutlineThickness(look.ring, SOFT.RING)
	end
	look.halo = Halo(frame, ns.Pixels(frame, SOFT.HALO))
	local pulse = frame:CreateAnimationGroup()
	local breathe = pulse:CreateAnimation("Alpha")
	breathe:SetFromAlpha(SOFT.LOW)
	breathe:SetToAlpha(SOFT.HIGH)
	breathe:SetDuration(SOFT.SECONDS)
	breathe:SetSmoothing("IN_OUT")
	pulse:SetLooping("BOUNCE")
	look.pulse = pulse
	ns.ProcGlowTint(look, GOLD[1], GOLD[2], GOLD[3])
	return look
end

local function Fit(made)
	local ok, w, h = pcall(made.button.GetSize, made.button)
	if not (ok and Plain(w, "number") and Plain(h, "number") and w > 0 and h > 0) or (made.width == w and made.height == h) then
		return
	end
	made.width, made.height = w, h
	made.frame:SetSize(w * SCALE, h * SCALE)
	if made.start then
		made.start:SetSize(w * START_SIZE, h * START_SIZE)
	end
end

local function MakeGlow(button)
	local width, height = 36, 36
	local frame = CreateFrame("Frame", nil, ParentOf(button))
	frame:SetSize(width * SCALE, height * SCALE)
	frame:SetPoint("CENTER", button, "CENTER", 0, 0)
	local okLevel, level = pcall(button.GetFrameLevel, button)
	if okLevel and Plain(level, "number") then
		frame:SetFrameLevel(level + 10)
	end
	local made = { frame = frame, button = button, clock = 0, alpha = 0, plays = 0, stops = 0, left = 0, right = 1, top = 0, bottom = 1 }
	local atlas = false
	if C_Texture and C_Texture.GetAtlasInfo then
		local asked, info = pcall(C_Texture.GetAtlasInfo, ATLAS)
		atlas = asked and info ~= nil
		if atlas and Plain(info, "table") then
			for key, field in pairs({ left = "leftTexCoord", right = "rightTexCoord", top = "topTexCoord", bottom = "bottomTexCoord" }) do
				if Plain(info[field], "number") then
					made[key] = info[field]
				end
			end
		end
	end
	if atlas then
		local texture = frame:CreateTexture(nil, "ARTWORK", nil, 0)
		texture:SetAllPoints(frame)
		if pcall(texture.SetAtlas, texture, ATLAS) then
			made.texture, made.textured = texture, true
			texture:SetAlpha(0)
		else
			texture:Hide()
		end
	end
	local box = made.textured and AtlasBox(START_ATLAS)
	if box then
		local start = frame:CreateTexture(nil, "ARTWORK", nil, 1)
		start:SetPoint("CENTER", frame, "CENTER", 0, 0)
		start:SetSize(width * START_SIZE, height * START_SIZE)
		if pcall(start.SetAtlas, start, START_ATLAS) then
			start:SetAlpha(0)
			made.start, made.startBox = start, box
		else
			start:Hide()
		end
	end
	local fine, soft = pcall(ns.ProcGlowSoft, frame, button)
	if fine and type(soft) == "table" then
		made.soft = soft
	end
	local time = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	ns.Own[time] = true
	time:Hide()
	made.time = time
	Fit(made)
	Place(made)
	made.step = function(_, seconds)
		Tick(made, seconds)
	end
	frame:SetAlpha(0)
	frame:Show()
	return made
end

local function SetLook(made, look, carry)
	made.look, made.bursting = look, nil
	local soft = made.soft
	if look == "soft" then
		if made.texture then
			made.texture:SetAlpha(0)
		end
		if made.start then
			made.start:SetAlpha(0)
		end
		soft.frame:SetAlpha(1)
		if not carry then
			soft.pulse:Stop()
		end
		soft.pulse:Play()
	elseif soft then
		soft.pulse:Stop()
		soft.frame:SetAlpha(0)
	end
end

local function Play(made, carry)
	local look = LookOf(made)
	if made.playing then
		if look and look ~= made.look and not pcall(SetLook, made, look, true) then
			Refused()
		end
		return
	end
	if not look then
		return
	end
	made.unmark = nil
	made.timeClock = 0
	if made.fadeLeft then
		made.fadeLeft = nil
		carry = true
	end
	made.playing = true
	made.plays = made.plays + 1
	made.alpha = 1
	made.clock = carry and math.max(made.clock, START_SECONDS) or 0
	if not pcall(function()
		Fit(made)
		SetLook(made, look, carry)
		made.frame:SetAlpha(1)
		made.frame:SetScript("OnUpdate", made.step)
		Tick(made, 0)
	end) then
		Refused()
	end
end

local function Halt(made, now)
	if not made.playing then
		if now and made.fadeLeft then
			Stopped(made)
		end
		return
	end
	made.playing = false
	made.stops = made.stops + 1
	if now then
		Stopped(made)
	else
		made.fadeLeft = FADE_OUT
	end
end

local Refresh

local function Want(button)
	if glows[button] ~= nil or pending[button] then
		return
	end
	pending[button] = true
	ns.OutOfCombat(function()
		pending[button] = nil
		if glows[button] ~= nil then
			return
		end
		local ok, made = pcall(MakeGlow, button)
		if ok then
			glows[button] = made
		else
			glows[button] = false
			ns.Note(KEY, "Proc glow: a button could not take the glow frame. " .. tostring(made))
		end
		Refresh(button)
	end)
end

Refresh = function(button, carry)
	local list, first = users[button], nil
	for _, mark in pairs(list or {}) do
		if first == nil or mark[4] < first[4] then
			first = mark
		end
	end
	local made = glows[button]
	if made and (first ~= nil or ownGame[button]) then
		made.mark = first
	end
	if first == nil and made and (made.playing or made.fadeLeft) and not ownGame[button] then
		made.unmark = true
		Halt(made)
		return
	end
	if first == nil then
		ns.SetButtonMark(button, "proc", nil)
		drawn[button] = nil
		if not ownGame[button] then
			if made then
				Halt(made)
			end
			return
		end
	else
		drawn[button] = ns.SetButtonMark(button, "proc", first[1], first[2], first[3]) or nil
	end
	if gameAlert[button] then
		if made then
			Halt(made, true)
		end
	elseif made then
		if made.soft then
			local colour = first or GOLD
			ns.ProcGlowTint(made.soft, colour[1], colour[2], colour[3])
		end
		Play(made, carry)
	elseif made == nil then
		Want(button)
	end
end

local function Release(button, id)
	local list = users[button]
	if list then
		list[id] = nil
		if next(list) == nil then
			users[button] = nil
		end
	end
	Refresh(button)
end

local Sync

local function Apply(rec, set, carry)
	local id = rec.entry.id
	for button in pairs(rec.set) do
		if not set[button] then
			Release(button, id)
		end
	end
	local r, g, b = Colour(rec.entry)
	for button in pairs(set) do
		Sync(button)
		local list = users[button]
		if not list then
			list = {}
			users[button] = list
		end
		list[id] = { r, g, b, rec.order, rec.entry }
		Refresh(button, carry)
	end
	rec.set = set
end

function Sync(button)
	if not Plain(button, "table") then
		return
	end
	if type(ns.ButtonIsOwn) == "function" and ns.ButtonIsOwn(button) then
		gameAlert[button] = nil
		return
	end
	local manager = ActionButtonSpellAlertManager
	if type(manager) ~= "table" or type(manager.HasAlert) ~= "function" then
		return
	end
	local ok, has = pcall(manager.HasAlert, manager, button)
	local now = ok and has == true or nil
	if gameAlert[button] ~= now then
		gameAlert[button] = now
		if users[button] then
			Refresh(button)
		end
	end
end

local asked, waiting = {}, false

local function Settle()
	waiting = false
	local list = {}
	for button in pairs(asked) do
		list[#list + 1] = button
		asked[button] = nil
	end
	for _, button in ipairs(list) do
		Sync(button)
	end
end

local function Ask(_, button)
	if not Plain(button, "table") then
		return
	end
	if not (C_Timer and C_Timer.After) then
		Sync(button)
		return
	end
	asked[button] = true
	if not waiting then
		waiting = true
		C_Timer.After(0, Settle)
	end
end

local function Hook()
	if hooked or type(ActionButtonSpellAlertManager) ~= "table" or type(hooksecurefunc) ~= "function" then
		return
	end
	if type(ns.OwnLookOnly) == "function" and ns.OwnLookOnly() then
		return
	end
	if ns.HandsOff() and not ns.Enabled("actionbars") then
		return
	end
	local manager = ActionButtonSpellAlertManager
	if type(manager.ShowAlert) ~= "function" or type(manager.HideAlert) ~= "function" then
		return
	end
	hooked = true
	pcall(hooksecurefunc, manager, "ShowAlert", Ask)
	pcall(hooksecurefunc, manager, "HideAlert", Ask)
end

local prepared = {}

function ns.ProcGlowPrepare(entries)
	if type(entries) == "table" then
		prepared = entries
	end
	if not Wanted() or InCombatLockdown() then
		return
	end
	for _, entry in ipairs(prepared) do
		if type(entry) == "table" and entry.glow ~= false then
			for button in pairs(Holders(entry)) do
				if glows[button] == nil then
					Want(button)
				end
			end
		end
	end
end

function ns.ProcGlowStart(entry, again)
	if type(entry) ~= "table" or entry.id == nil then
		return
	end
	if type(ns.CooldownProcs) == "function" and entry.glow ~= false then
		pcall(ns.CooldownProcs, entry, true)
	end
	Hook()
	local rec = active[entry.id]
	if not rec then
		seq = seq + 1
		rec = { order = seq, set = {} }
		active[entry.id] = rec
	end
	rec.entry = entry
	rec.up = Holders(entry, true)
	local set = Wanted() and entry.glow ~= false and rec.up or {}
	for button in pairs(set) do
		Sync(button)
	end
	Apply(rec, set, again == true)
end

function ns.ProcGlowOwn(button, on)
	if not Plain(button, "table") then
		return
	end
	local now = on == true or nil
	if ownGame[button] == now then
		return
	end
	ownGame[button] = now
	if now or glows[button] ~= nil then
		Refresh(button)
	end
end

function ns.ProcGlowStop(entry)
	if type(ns.CooldownProcs) == "function" then
		pcall(ns.CooldownProcs, entry, false)
	end
	local rec = type(entry) == "table" and active[entry.id]
	if rec then
		active[entry.id] = nil
		Apply(rec, {})
	end
end

function ns.ProcGlowChanged(path)
	for _, rec in pairs(active) do
		rec.up = Holders(rec.entry, true)
		Apply(rec, Wanted() and rec.entry.glow ~= false and rec.up or {})
	end
	for _, made in pairs(glows) do
		if made and made.playing then
			Play(made)
		end
	end
	if path == KEY .. ".glowStyle" then
		for _, name in ipairs({ "ProcArtChanged", "CooldownProcLook" }) do
			if type(ns[name]) == "function" then
				pcall(ns[name])
			end
		end
	end
	if path ~= KEY .. ".glowStyle" and type(ns.ProcPreview) == "function" then
		ns.ProcPreview()
	end
end

local BAR_FRAMES = { ActionButton = "MainActionBar", MultiBarBottomLeftButton = "MultiBarBottomLeft", MultiBarBottomRightButton = "MultiBarBottomRight",
	MultiBarRightButton = "MultiBarRight", MultiBarLeftButton = "MultiBarLeft", MultiBar5Button = "MultiBar5", MultiBar6Button = "MultiBar6",
	MultiBar7Button = "MultiBar7" }
local barOf = setmetatable({}, { __mode = "k" })

local function OnBar(button, name, own)
	local n = type(ns.OwnBar) == "function" and ns.OwnBar(button)
	if n then
		return own ~= nil and type(ns.OwnBarFrame) == "function" and rawequal(ns.OwnBarFrame(n), own)
	end
	local bar = barOf[button]
	if bar == nil then
		local ok, full = pcall(button.GetName, button)
		local prefix = ok and Plain(full, "string") and full:match("^(.-)%d+$")
		bar = prefix and BAR_FRAMES[prefix] or false
		barOf[button] = bar
	end
	return bar == name
end

function ns.ProcUpOn(name)
	if not Plain(name, "string") or next(active) == nil then
		return false
	end
	local own = type(ns.OwnBarOf) == "function" and ns.OwnBarOf(name) or nil
	local mode = ns.TestMode
	local testing = type(mode) == "table" and type(mode.IsOn) == "function" and mode.IsOn() == true
	local held = testing and type(ns.ProcHeld) == "function" and ns.ProcHeld or nil
	for _, rec in pairs(active) do
		if not (held and held(rec.entry) and not (type(ns.ProcReal) == "function" and ns.ProcReal(rec.entry))) then
			if rec.bars == nil or rec.barsOf ~= rec.up then
				rec.barsOf, rec.bars = rec.up, {}
			end
			local on = rec.bars[name]
			if on == nil then
				on = false
				for button in pairs(rec.up or {}) do
					if OnBar(button, name, own) then
						on = true
						break
					end
				end
				rec.bars[name] = on
			end
			if on then
				return true
			end
		end
	end
	return false
end

function ns.ProcGlowLine(entry)
	if ns.Get(KEY .. ".glow") ~= true then
		return "Glow: off"
	end
	if entry.glow == false then
		return "Glow: none, any spell uses this proc"
	end
	local rec = active[entry.id]
	local set = rec and rec.set or Holders(entry)
	local n, border, animation = 0, false, false
	for button in pairs(set) do
		n = n + 1
		local list = users[button]
		border = border or (list ~= nil and list[entry.id] ~= nil and drawn[button] == true)
		local made = glows[button]
		animation = made and LookOf(made) or animation
	end
	if n == 0 then
		local light = Plain(entry.lights and entry.lights[1], "number") and SpellName(entry.lights[1])
		return ("Glow: no button holds %s"):format(light or (Plain(entry.name, "string") and entry.name) or "this proc")
	end
	return ("Glow: %d %s, border %s, animation %s%s"):format(n, n == 1 and "button" or "buttons", border and "yes" or "no",
		animation == "game" and "yes, as the game has it" or animation == "soft" and "yes, soft" or "no",
		ns.Enabled("actionbars") and "" or " (no border while Restyle action bars is off)")
end

if type(ns.OnButtonsChanged) == "function" then
	ns.OnButtonsChanged(function()
		for _, rec in pairs(active) do
			rec.up = Holders(rec.entry, true)
			Apply(rec, Wanted() and rec.entry.glow ~= false and rec.up or {})
		end
	end)
end

if type(ns.OnButtonsChanged) == "function" then
	ns.OnButtonsChanged(function()
		if next(active) ~= nil then
			Hook()
		end
		ns.ProcGlowPrepare()
	end)
end
