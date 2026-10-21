local _, ns = ...

-- Glow on the action button: while a proc is up, the button that casts the spell it is for gets the proc's border colour and the game's own
-- glow animation (ActionButtonSpellAlerts.xml:3-33). Procs.lua calls ns.ProcGlowStart(entry) and ns.ProcGlowStop(entry). The border is
-- drawn by ns.SetButtonMark in ActionBars.lua. The glow is a frame of this addon next to the button (a child of the button's parent,
-- anchored to the button), made out of combat and kept at alpha 0; in a fight only SetAlpha and SetScript run on it. A button the game glows itself is left alone. This file is not a module.

local KEY = "trackers"
local ATLAS = "UI-HUD-ActionBar-Proc-Loop-Flipbook"
local SCALE = 1.4
local GOLD = { 1, 0.82, 0 }
local REFUSED = "Proc glow: the game refused a call on an action button in a fight. The border is drawn without the glow."

-- active[entry.id] = { entry = entry, order = n, set = { [button] = true } }
local active, seq = {}, 0
-- users[button][entry.id] = { r, g, b, order }: the procs that are up on a button
local users = setmetatable({}, { __mode = "k" })
-- glows[button] = { frame, texture, step, playing } once made, or false when it could not be made
local glows = setmetatable({}, { __mode = "k" })
local pending = setmetatable({}, { __mode = "k" })
-- gameAlert[button] = true while the game's own alert is up
local gameAlert = setmetatable({}, { __mode = "k" })
-- drawn[button] = true while the border of a proc is drawn on it
local drawn = setmetatable({}, { __mode = "k" })
local hooked = false
-- ownGame[button] = true while the proc row asks for the game's glow on one of Flat UI's own buttons (ButtonEffects.lua). It shares the glow frame of
-- the tracker glow, so a button with both draws one glow.
local ownGame = setmetatable({}, { __mode = "k" })

local function Plain(value, kind)
	return type(value) == kind and not ns.IsSecret(value)
end

local function Wanted()
	return ns.Enabled(KEY) and ns.Get(KEY .. ".glow") == true
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

-- The restyled buttons that hold a spell the proc is for, as a set. Names are asked, so every rank is found.
local function Holders(entry)
	local set, seen = {}, {}
	if type(ns.ButtonsFor) ~= "function" or type(entry.lights) ~= "table" then
		return set
	end
	for index = 1, math.min(#entry.lights, 40) do
		local id = entry.lights[index]
		local name = Plain(id, "number") and SpellName(id)
		if name and not seen[name] then
			seen[name] = true
			for _, button in ipairs(ns.ButtonsFor("spell", name:lower())) do
				set[button] = true
			end
		end
	end
	return set
end

local function Refused()
	ns.Note(KEY, REFUSED)
end

-- The glow frame of a button: one texture with the game's flipbook, stepped from the frame's own OnUpdate. The frame hangs from the button's
-- parent and is anchored to the button, so nothing is added under a protected button, and no animation group runs on a game frame
-- (EllesmereUI/EllesmereUIActionBars.lua:759-766, EllesmereUI/EUI_ActionBars_Glows.lua:114-120). Out of combat only.
local ROWS, COLUMNS, FRAMES, SECONDS = 6, 5, 30, 1

local function ParentOf(button)
	local ok, parent = pcall(button.GetParent, button)
	if ok and Plain(parent, "table") then
		return parent
	end
	return UIParent
end

-- Shows one cell of the flipbook: the cell's rectangle inside the atlas's own.
local function Cell(made, index)
	local column, row = index % COLUMNS, math.floor(index / COLUMNS)
	local width, height = (made.right - made.left) / COLUMNS, (made.bottom - made.top) / ROWS
	made.texture:SetTexCoord(made.left + column * width, made.left + (column + 1) * width, made.top + row * height, made.top + (row + 1) * height)
end

-- The glow shows while its button does: the container stays shown over an empty slot, so the button is asked each frame.
local function Tick(made, seconds)
	made.clock = made.clock + seconds
	local ok, visible = pcall(made.button.IsVisible, made.button)
	local wanted = ok and visible == true and 1 or 0
	if made.alpha ~= wanted then
		made.alpha = wanted
		made.frame:SetAlpha(wanted)
	end
	if wanted == 1 then
		Cell(made, math.floor((made.clock % SECONDS) / SECONDS * FRAMES))
	end
end

local function MakeGlow(button)
	local width, height = 36, 36
	local ok, w, h = pcall(button.GetSize, button)
	if ok and Plain(w, "number") and Plain(h, "number") and w > 0 and h > 0 then
		width, height = w, h
	end
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
			made.step = function(_, seconds)
				Tick(made, seconds)
			end
		else
			texture:Hide()
		end
	end
	frame:SetAlpha(0)
	frame:Show()
	return made
end

local function Play(made)
	if made.playing then
		return
	end
	made.playing = true
	made.plays = made.plays + 1
	made.clock, made.alpha = 0, 1
	if not pcall(function()
		made.frame:SetAlpha(1)
		made.frame:SetScript("OnUpdate", made.step)
	end) then
		Refused()
	end
end

local function Halt(made)
	if not made.playing then
		return
	end
	made.playing = false
	made.stops = made.stops + 1
	if not pcall(function()
		made.frame:SetScript("OnUpdate", nil)
		made.frame:SetAlpha(0)
		made.alpha = 0
	end) then
		Refused()
	end
end

local Refresh

-- The frame is made once, when the button has none and the fight is over.
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

-- What a button shows now: the border of the proc that came up first, and the glow unless the game glows it.
Refresh = function(button)
	local list, first = users[button], nil
	for _, mark in pairs(list or {}) do
		if first == nil or mark[4] < first[4] then
			first = mark
		end
	end
	local made = glows[button]
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
			Halt(made)
		end
	elseif made then
		if made.step then
			Play(made)
		end
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

-- The buttons of a proc are the set: the ones that held it before and are not in it lose it.
local Sync

local function Apply(rec, set)
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
		list[id] = { r, g, b, rec.order }
		Refresh(button)
	end
	rec.set = set
end

-- The game's own alert on a button: one more thing to leave alone, and the glow of this addon comes back when the game's goes.
function Sync(button)
	if not Plain(button, "table") then
		return
	end
	-- One of Flat UI's own buttons has no alert of the game's.
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

-- The game's call is never answered inside the call: ShowAlert and HideAlert run in the game's own pass for the button, so each one only
-- marks the button, and the next frame asks the manager what it holds (EllesmereUICooldownManager/EUI_CDM_Glows.lua:841-868 follows the
-- same two calls on the same table; ActionButtonSpellAlerts.lua:1 makes it a plain table, not a frame).
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

-- A hook on the manager table, which is a singleton: no frame gets a field, and taintLog does not hold it back.
local function Hook()
	if hooked or type(ActionButtonSpellAlertManager) ~= "table" or type(hooksecurefunc) ~= "function" then
		return
	end
	-- Only Flat UI's own buttons are styled: the game's alert manager has nothing to say about them.
	if type(ns.OwnLookOnly) == "function" and ns.OwnLookOnly() then
		return
	end
	-- Nothing is hooked or registered in the game's action button code while Restyle action bars is off and Flat UI leaves the game's bars alone.
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

function ns.ProcGlowStart(entry)
	if type(entry) ~= "table" or entry.id == nil then
		return
	end
	Hook()
	local rec = active[entry.id]
	if not rec then
		seq = seq + 1
		rec = { order = seq, set = {} }
		active[entry.id] = rec
	end
	rec.entry = entry
	local set = Wanted() and Holders(entry) or {}
	for button in pairs(set) do
		Sync(button)
	end
	Apply(rec, set)
end

-- The glow of the game's proc on one of Flat UI's own buttons, given by the proc row of the Glows and animations page: on is true while the spell of the
-- button's slot glows.
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
	local rec = type(entry) == "table" and active[entry.id]
	if rec then
		active[entry.id] = nil
		Apply(rec, {})
	end
end

-- The row Glow on the action button changed: the procs that are up take the border and the glow, or give them back.
function ns.ProcGlowChanged()
	for _, rec in pairs(active) do
		Apply(rec, Wanted() and Holders(rec.entry) or {})
	end
end

-- A line for /flatui tracker check.
function ns.ProcGlowLine(entry)
	if ns.Get(KEY .. ".glow") ~= true then
		return "Glow: off"
	end
	if not ns.Enabled("actionbars") then
		return "Glow: Restyle action bars is off"
	end
	local rec = active[entry.id]
	local set = rec and rec.set or Holders(entry)
	local n, border, animation = 0, false, false
	for button in pairs(set) do
		n = n + 1
		local list = users[button]
		border = border or (list ~= nil and list[entry.id] ~= nil and drawn[button] == true)
		local made = glows[button]
		animation = animation or (made and made.textured) == true
	end
	if n == 0 then
		local light = Plain(entry.lights and entry.lights[1], "number") and SpellName(entry.lights[1])
		return ("Glow: no button holds %s"):format(light or (Plain(entry.name, "string") and entry.name) or "this proc")
	end
	return ("Glow: %d %s, border %s, animation %s"):format(n, n == 1 and "button" or "buttons", border and "yes" or "no", animation and "yes" or "no")
end

-- The buttons hold something else: the buttons of every proc that is up are found again.
if type(ns.OnButtonsChanged) == "function" then
	ns.OnButtonsChanged(function()
		for _, rec in pairs(active) do
			Apply(rec, Wanted() and Holders(rec.entry) or {})
		end
	end)
end

-- Flat UI's buttons made after login, or the game's styled after them: the alert manager is followed once a game button is among them and a proc is up.
if type(ns.OnButtonsChanged) == "function" then
	ns.OnButtonsChanged(function()
		if next(active) ~= nil then
			Hook()
		end
	end)
end
