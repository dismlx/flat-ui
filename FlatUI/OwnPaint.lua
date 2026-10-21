local _, ns = ...

-- The paint of Flat UI's own action buttons (design 3.4, 3.6, 3.7, 6.3, research/own-buttons/design.md). OwnBars.lua makes the buttons; this file works out
-- what each one shows from the slot it holds and draws it: icon, count, macro name, hotkey, cooldown, charges, loss of control, usable and range colours,
-- checked, equipped, proc, empty-slot opacity, the pressed look from a key, the tooltip and the repaint after a click. The look modules colour through
-- painters (ns.OwnPainter) and take proc changes through ns.OnOwnProc; nothing here hooks a function of the game.
-- Calls on a button are plain ones (textures, text, alpha, SetChecked, Cooldown calls), so a pass in a fight touches nothing protected. Flat UI writes no
-- field on a button: every table here is keyed by the button. The game's twins and OverrideActionBar are only read.
-- Never called on a button, a twin or a game table: Update, UpdateAction, UpdateFlyout, SetShowGrid, RegisterActionUIButton, ShowAlert and
-- EnableActionRangeCheck (the game's own range and usable frames keep watching the same slots through the twins).
-- The state of a button (ns.OwnState) and its painters:
--   state: slot, has, texture, usable, noMana, inRange (true, false or nil), checksRange, cdActive, cdOnGCD, checked, equipped, proc, empty, grid, hotkey.
--   painter "icon" and "hotkey": fn(button, state) returns r, g, b[, a] or nil for the game's look.
--   painter "empty": fn(button, state) returns the opacity of an empty button (a number, or r, g, b, a with the opacity as a), nil for normal.
-- This file is not a module. It works while ns.OwnOn() is true.

local WEAK = { __mode = "k" }
local ORDER = { "slot", "icon", "text", "hotkey", "cooldown", "usable", "range", "checked", "equipped", "proc", "empty" }
-- The events that start the work, and the events it listens for once it runs (design 3.4).
local FIRST = { "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }
local EVENTS = { "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_UPDATE_STATE", "ACTIONBAR_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES",
	"SPELL_UPDATE_ICON", "ACTION_USABLE_CHANGED", "ACTION_RANGE_CHECK_UPDATE", "PLAYER_TARGET_CHANGED", "UPDATE_BINDINGS", "GAME_PAD_ACTIVE_CHANGED",
	"UPDATE_SHAPESHIFT_FORM", "PLAYER_MOUNT_DISPLAY_CHANGED", "UPDATE_INVENTORY_ALERTS", "LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE",
	"START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW",
	"SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID" }
-- The steps one event repaints. A slot change repaints every step.
local SETS = {
	state = { checked = true },
	cooldown = { cooldown = true },
	charges = { cooldown = true, text = true },
	icon = { icon = true, text = true, usable = true, range = true },
	usable = { usable = true },
	range = { range = true },
	hotkey = { hotkey = true },
	empty = { empty = true },
	items = { checked = true, text = true, usable = true },
}
-- The steps that end in a colour on the icon, and in the colour of the hotkey.
local COLOUR = { icon = true, cooldown = true, usable = true, range = true }
local HOTKEY = { hotkey = true, range = true }
local DOT = "\226\151\143"

-- All of this file's state. A table keyed by a button is weak.
local P = {
	state = setmetatable({}, WEAK),
	hooked = setmetatable({}, WEAK),
	pressed = setmetatable({}, WEAK),
	alpha = setmetatable({}, WEAK),
	queue = {},
	painters = { icon = {}, hotkey = {}, empty = {} },
	procs = {},
	list = {},
	keys = {},
	grid = false,
	started = false,
	subscribed = false,
	pending = false,
	since = 1,
	tries = 0,
	failed = 0,
	last = nil,
}
local H, STEP = {}, {}

local function Bool(value)
	if type(value) == "boolean" and not ns.IsSecret(value) then
		return value
	end
	return nil
end

local function Plain(value, kind)
	return type(value) == kind and not ns.IsSecret(value)
end

local function On()
	return type(ns.OwnOn) == "function" and ns.OwnOn() == true
end

-- A call of the game's, by C_ActionBar first and then the global of the same name. Returns the first three answers, nothing when it fails.
local function Call(name, ...)
	local fn = C_ActionBar and C_ActionBar[name]
	if type(fn) ~= "function" then
		fn = _G[name]
	end
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b, c = pcall(fn, ...)
	if ok then
		return a, b, c
	end
	return nil
end

local function Failed(where, err)
	P.failed = P.failed + 1
	P.last = where .. ": " .. tostring(err)
end

local function Buttons()
	if type(ns.OwnButtons) == "function" then
		local ok, list = pcall(ns.OwnButtons)
		if ok and type(list) == "table" then
			return list
		end
	end
	return {}
end

local function CommandOf(button)
	if type(ns.OwnCommand) ~= "function" then
		return nil
	end
	local ok, command = pcall(ns.OwnCommand, button)
	if ok and Plain(command, "string") then
		return command
	end
	return nil
end

local function SlotOf(button)
	if type(ns.OwnSlot) ~= "function" then
		return nil
	end
	local ok, slot = pcall(ns.OwnSlot, button)
	if ok and Plain(slot, "number") then
		return slot
	end
	return nil
end

-- The first colour a painter gives: r, g, b, a.
local function Painted(part, button, st)
	for _, fn in ipairs(P.painters[part]) do
		local ok, r, g, b, a = pcall(fn, button, st)
		if not ok then
			Failed("painter " .. part, r)
		elseif r ~= nil then
			return r, g, b, a
		end
	end
	return nil
end

local function StateFor(button)
	local st = P.state[button]
	if st == nil then
		st = { proc = false, grid = P.grid, hotkey = "" }
		P.state[button] = st
	end
	return st
end

-- The colour of the icon: a painter's, else the game's three (ActionButton.lua:728-734).
local function Colour(button, st)
	local icon = button.icon
	if icon == nil or not st.has then
		return
	end
	local r, g, b, a = Painted("icon", button, st)
	if r == nil then
		if st.usable == false then
			if st.noMana == true then
				r, g, b = 0.5, 0.5, 1
			else
				r, g, b = 0.4, 0.4, 0.4
			end
		else
			r, g, b = 1, 1, 1
		end
	end
	if a ~= nil then
		icon:SetVertexColor(r, g, b, a)
	else
		icon:SetVertexColor(r, g, b)
	end
end

local function Grey()
	local c = ACTIONBAR_HOTKEY_FONT_COLOR
	if type(c) == "table" and type(c.GetRGB) == "function" then
		return c:GetRGB()
	end
	return 0.6, 0.6, 0.6
end

local function Red()
	local c = RED_FONT_COLOR
	if type(c) == "table" and type(c.GetRGB) == "function" then
		return c:GetRGB()
	end
	return 1, 0.1, 0.1
end

-- The hotkey text and its colour: the game's rule for the range dot and the red out of range (ActionButton.lua:1289-1308), or a painter's colour.
local function DrawHotkey(button, st)
	local hk = button.HotKey
	if hk == nil then
		return
	end
	local dot = st.hotkey == ""
	hk:SetText(dot and (RANGE_INDICATOR or DOT) or st.hotkey)
	hk:SetShown((not dot) or (st.has == true and st.checksRange == true))
	local r, g, b, a = Painted("hotkey", button, st)
	if r == nil then
		if st.checksRange == true and st.inRange == false then
			r, g, b = Red()
		else
			r, g, b = Grey()
		end
	end
	if a ~= nil then
		hk:SetVertexColor(r, g, b, a)
	else
		hk:SetVertexColor(r, g, b)
	end
end

-- Whether the glow of a spell is up on the slot's action, for the spell, the macro's spell and a flyout's spells.
local function Glowing(st)
	local kind, id, sub = Call("GetActionInfo", st.slot)
	if not Plain(id, "number") then
		return false
	end
	local overlay = C_SpellActivationOverlay
	local function lit(spell)
		if type(overlay) ~= "table" or type(overlay.IsSpellOverlayed) ~= "function" then
			return false
		end
		local ok, answer = pcall(overlay.IsSpellOverlayed, spell)
		return ok and Bool(answer) == true
	end
	if kind == "spell" or (kind == "macro" and sub == "spell") then
		return lit(id)
	elseif kind == "flyout" and type(GetFlyoutSlotInfo) == "function" then
		local _, _, count = Call("GetFlyoutInfo", id)
		for index = 1, Plain(count, "number") and count or 0 do
			local ok, spell = pcall(GetFlyoutSlotInfo, id, index)
			if ok and Plain(spell, "number") and lit(spell) then
				return true
			end
		end
	end
	return false
end

local function SetProc(button, st, on)
	if st.proc == on then
		return
	end
	st.proc = on
	for _, fn in ipairs(P.procs) do
		local ok, err = pcall(fn, button, on)
		if not ok then
			Failed("proc handler", err)
		end
	end
end

-- The slot and whether it holds an action.
function STEP.slot(button, st)
	st.slot = SlotOf(button)
	st.has = st.slot ~= nil and Bool(Call("HasAction", st.slot)) == true
	st.empty = not st.has
	st.grid = P.grid
end

function STEP.icon(button, st)
	local icon = button.icon
	if icon == nil then
		return
	end
	if st.has then
		local texture = Call("GetActionTexture", st.slot)
		icon:SetTexture(texture)
		st.texture = (Plain(texture, "number") or Plain(texture, "string")) and texture or nil
		icon:Show()
	else
		st.texture = nil
		icon:Hide()
	end
end

-- The count (a withheld one goes through unread) and the macro name (the rule of ActionButton.lua:625-630).
function STEP.text(button, st)
	if button.Count ~= nil then
		local count = st.has and Call("GetActionDisplayCount", st.slot) or nil
		button.Count:SetText(type(count) == "nil" and "" or count)
	end
	if button.Name ~= nil then
		local text = ""
		if st.has and Bool(Call("UsesActionText", st.slot)) == true then
			text = Call("GetActionText", st.slot)
			if type(text) == "nil" then
				text = ""
			end
		end
		button.Name:SetText(text)
	end
end

-- The key of the twin's command, else the key bound by a click on this button (ActionButton.lua:480-519).
function STEP.hotkey(button, st)
	local key, command = nil, CommandOf(button)
	if command ~= nil then
		key = Call("GetBindingKey", command)
	end
	if type(key) == "nil" then
		local name = button:GetName()
		if Plain(name, "string") then
			key = Call("GetBindingKey", "CLICK " .. name .. ":LeftButton")
		end
	end
	local text = ""
	if Plain(key, "string") then
		local shown = Call("GetBindingText", key, 1)
		if Plain(shown, "string") then
			text = shown
		end
	end
	st.hotkey = text
end

local function Sweep(frame, show, name, slot)
	if frame == nil then
		return
	end
	local object = show and Call(name, slot) or nil
	if type(object) == "nil" then
		frame:Clear()
	else
		frame:SetCooldownFromDurationObject(object)
	end
end

-- Cooldown, charges and loss of control by duration objects. isActive and isOnGCD are never withheld; the other fields are never read.
function STEP.cooldown(button, st)
	if not st.has then
		st.cdActive, st.cdOnGCD = false, false
		for _, key in ipairs({ "cooldown", "chargeCooldown", "lossOfControlCooldown" }) do
			if button[key] ~= nil then
				button[key]:Clear()
			end
		end
		return
	end
	local slot = st.slot
	local cooldown, charges, loss = Call("GetActionCooldown", slot), Call("GetActionCharges", slot), Call("GetActionLossOfControlCooldownInfo", slot)
	local replace = type(loss) == "table" and Bool(loss.shouldReplaceNormalCooldown) == true
	st.cdActive = type(cooldown) == "table" and Bool(cooldown.isActive) == true
	st.cdOnGCD = type(cooldown) == "table" and Bool(cooldown.isOnGCD) == true
	Sweep(button.cooldown, st.cdActive and not replace, "GetActionCooldownDuration", slot)
	Sweep(button.chargeCooldown, type(charges) == "table" and Bool(charges.isActive) == true and not replace, "GetActionChargeDuration", slot)
	if type(loss) == "table" then
		Sweep(button.lossOfControlCooldown, Bool(loss.isActive) == true, "GetActionLossOfControlCooldownDuration", slot)
	elseif button.lossOfControlCooldown ~= nil then
		-- No plain answer to ask: a duration of zero clears the swipe by itself.
		local object = Call("GetActionLossOfControlCooldownDuration", slot)
		if type(object) == "nil" then
			button.lossOfControlCooldown:Clear()
		else
			button.lossOfControlCooldown:SetCooldownFromDurationObject(object)
		end
	end
end

function STEP.usable(_, st)
	if not st.has then
		st.usable, st.noMana = nil, nil
		return
	end
	local usable, noMana = Call("IsUsableAction", st.slot)
	st.usable, st.noMana = Bool(usable), Bool(noMana)
end

function STEP.range(_, st)
	if not st.has then
		st.inRange, st.checksRange = nil, false
		return
	end
	local inRange = Bool(Call("IsActionInRange", st.slot))
	st.inRange, st.checksRange = inRange, inRange ~= nil
end

-- Checked is the game's rule (ActionButton.lua:715-719).
function STEP.checked(button, st)
	local checked = false
	if st.has then
		local current, repeating, pet = Bool(Call("IsCurrentAction", st.slot)), Bool(Call("IsAutoRepeatAction", st.slot)), Bool(Call("IsAutoCastPetAction", st.slot))
		checked = (current == true or repeating == true) and pet ~= true
	end
	st.checked = checked
	button:SetChecked(checked)
end

-- The green border of an equipped item (ActionButton.lua:612-620).
function STEP.equipped(button, st)
	st.equipped = st.has and Bool(Call("IsEquippedAction", st.slot)) == true
	local border = button.Border
	if border == nil then
		return
	end
	if st.equipped then
		border:SetVertexColor(0, 1, 0, 0.5)
		border:Show()
	else
		border:Hide()
	end
end

function STEP.proc(button, st)
	SetProc(button, st, st.has and Glowing(st) or false)
end

-- An empty button is drawn at its painter's opacity, and normal while an action is on the cursor. Alpha is not protected.
function STEP.empty(button, st)
	local want = 1
	if st.empty and not st.grid then
		local r, g, _, a = Painted("empty", button, st)
		if Plain(a, "number") then
			want = a
		elseif g == nil and Plain(r, "number") then
			want = r
		end
	end
	if P.alpha[button] ~= want then
		P.alpha[button] = want
		button:SetAlpha(want)
	end
end

-- Runs the steps of set (all of them for nil) on a button, in order, then the colours they end in.
local function Refresh(button, set)
	local st = StateFor(button)
	local colour, hotkey = false, false
	for _, name in ipairs(ORDER) do
		if name == "slot" or set == nil or set[name] then
			local ok, err = pcall(STEP[name], button, st)
			if not ok then
				Failed(name, err)
			end
			colour = colour or (set == nil or set[name]) and COLOUR[name] == true
			hotkey = hotkey or (set == nil or set[name]) and HOTKEY[name] == true
		end
	end
	if colour then
		local ok, err = pcall(Colour, button, st)
		if not ok then
			Failed("icon colour", err)
		end
	end
	if hotkey or set == nil then
		local ok, err = pcall(DrawHotkey, button, st)
		if not ok then
			Failed("hotkey", err)
		end
	end
end

local function All(set)
	for _, button in ipairs(P.list) do
		Refresh(button, set)
	end
end

local function ForSlot(slot, fn)
	if not Plain(slot, "number") then
		return
	end
	for _, button in ipairs(P.list) do
		local st = P.state[button]
		if st ~= nil and st.slot == slot then
			fn(button, st)
		end
	end
end

-- The point of the tooltip box that GameTooltip_SetDefaultAnchor reads and compares (SharedTooltipTemplates.lua:87-114). Called by the addon, the
-- function runs tainted, so a secret point there would raise. True when the point and the offsets read as plain values.
local function BoxReadable()
	local box = GameTooltipDefaultContainer or SharedTooltipDefaultContainer
	if type(box) ~= "table" or ns.IsSecret(box) or type(box.GetPoint) ~= "function" then
		return false
	end
	local ok, point, _, _, x, y = pcall(box.GetPoint, box, 1)
	return ok and Plain(point, "string") and Plain(x, "number") and Plain(y, "number")
end

-- True when the tooltip's owner is this button. An owner that cannot be read is not.
local function Owns(tip, button)
	local ok, owner = pcall(tip.GetOwner, tip)
	return ok and not ns.IsSecret(owner) and rawequal(owner, button)
end

-- The tooltip of the slot, set as the game's button does (ActionButton.lua:1114-1130), from the attribute slot, else the slot of the last paint.
-- The game's default anchor is used only when the box can be read; otherwise, or when it fails, the tooltip goes to the right of the button.
local function ShowTip(button)
	local tip = GameTooltip
	local st = P.state[button]
	local slot = SlotOf(button) or (st ~= nil and Plain(st.slot, "number") and st.slot or nil)
	if tip == nil or slot == nil then
		return
	end
	local placed = false
	if Call("GetCVar", "UberTooltips") == "1" and type(GameTooltip_SetDefaultAnchor) == "function" and BoxReadable() then
		local ok, err = pcall(GameTooltip_SetDefaultAnchor, tip, button)
		placed = ok
		if not ok then
			Failed("tooltip anchor", err)
		end
	end
	if not placed and not pcall(tip.SetOwner, tip, button, "ANCHOR_RIGHT") then
		return
	end
	local ok, err = pcall(tip.SetAction, tip, slot)
	if not ok then
		Failed("tooltip", err)
	end
end

local function HideTip(button)
	local tip = GameTooltip
	if tip ~= nil and Owns(tip, button) then
		pcall(tip.Hide, tip)
	end
end

-- The three hooks on a button: the tooltip, and a repaint on the next frame after a click. They only paint.
local function Hook(button)
	if P.hooked[button] then
		return
	end
	P.hooked[button] = true
	button:HookScript("OnEnter", function(self) ShowTip(self) end)
	button:HookScript("OnLeave", function(self) HideTip(self) end)
	button:HookScript("PostClick", function(self)
		P.queue[self] = true
		P.pending = true
	end)
end

-- The buttons that have a key on their twin: the pressed look follows the twin's button state, which the game sets on a key (ActionButton.lua:146-174).
local function Keys()
	local keys = {}
	for _, button in ipairs(P.list) do
		local command = CommandOf(button)
		local twin = type(ns.OwnTwin) == "function" and select(2, pcall(ns.OwnTwin, button)) or nil
		if type(twin) == "table" and command ~= nil and Plain(Call("GetBindingKey", command), "string") then
			keys[#keys + 1] = { button, twin }
		end
	end
	P.keys = keys
end

local function Pressed()
	local override = OverrideActionBar ~= nil and OverrideActionBar:IsShown() == true
	for _, entry in ipairs(P.keys) do
		local button, twin = entry[1], entry[2]
		if not override and twin:GetButtonState() == "PUSHED" then
			if not P.pressed[button] and button:GetButtonState() == "NORMAL" then
				P.pressed[button] = true
				button:SetButtonState("PUSHED")
			end
		elseif P.pressed[button] then
			P.pressed[button] = nil
			if button:GetButtonState() == "PUSHED" then
				button:SetButtonState("NORMAL")
			end
		end
	end
end

-- The buttons Flat UI has made: hooks and a full paint for a new one. Returns true when the list changed.
local function Sync()
	local list = Buttons()
	local same = #list == #P.list
	for index = 1, same and #list or 0 do
		if list[index] ~= P.list[index] then
			same = false
			break
		end
	end
	if same then
		return false
	end
	P.list = {}
	for index, button in ipairs(list) do
		P.list[index] = button
	end
	P.grid = Call("GetCursorInfo") ~= nil
	for _, button in ipairs(P.list) do
		local ok, err = pcall(Hook, button)
		if not ok then
			Failed("hook", err)
		end
		if P.state[button] == nil then
			Refresh(button)
		end
	end
	Keys()
	return true
end

-- The slot of a button changed (a page, a bonus bar, a drag): every button whose slot moved is painted again. Fed by OwnBars.lua's slot watch.
local function SlotsChanged()
	if not On() then
		return
	end
	Sync()
	for _, button in ipairs(P.list) do
		local st = P.state[button]
		if st == nil or st.slot ~= SlotOf(button) then
			Refresh(button)
			if GameTooltip ~= nil and Owns(GameTooltip, button) then
				ShowTip(button)
			end
		end
	end
end

function H.ACTIONBAR_SLOT_CHANGED(slot)
	if not Plain(slot, "number") or slot == 0 then
		All()
		return
	end
	-- A button that holds the slot now, or held it until now.
	for _, button in ipairs(P.list) do
		local st = P.state[button]
		if SlotOf(button) == slot or (st ~= nil and st.slot == slot) then
			Refresh(button)
		end
	end
end

function H.ACTIONBAR_UPDATE_STATE() All(SETS.state) end
function H.ACTIONBAR_UPDATE_COOLDOWN() All(SETS.cooldown) end
function H.SPELL_UPDATE_COOLDOWN() All(SETS.cooldown) end
function H.LOSS_OF_CONTROL_ADDED() All(SETS.cooldown) end
function H.LOSS_OF_CONTROL_UPDATE() All(SETS.cooldown) end
function H.SPELL_UPDATE_CHARGES() All(SETS.charges) end
function H.SPELL_UPDATE_ICON() All(SETS.icon) end
function H.PLAYER_TARGET_CHANGED() All(SETS.range) end
function H.START_AUTOREPEAT_SPELL() All(SETS.state) end
function H.STOP_AUTOREPEAT_SPELL() All(SETS.state) end
function H.UPDATE_INVENTORY_ALERTS() All(SETS.items) end
function H.TRADE_SKILL_SHOW() All(SETS.items) end
function H.TRADE_SKILL_CLOSE() All(SETS.items) end
function H.UNIT_INVENTORY_CHANGED(unit)
	if unit == nil or unit == "player" then
		All(SETS.items)
	end
end
function H.UPDATE_SHAPESHIFT_FORM() All() end
function H.PLAYER_MOUNT_DISPLAY_CHANGED() All() end

function H.ACTION_USABLE_CHANGED(changes)
	if type(changes) ~= "table" then
		All(SETS.usable)
		return
	end
	for _, change in ipairs(changes) do
		if type(change) == "table" then
			local usable, noMana = Bool(change.usable), Bool(change.noMana)
			ForSlot(change.slot, function(button, st)
				st.usable, st.noMana = usable, noMana
				Colour(button, st)
			end)
		end
	end
end

function H.ACTION_RANGE_CHECK_UPDATE(slot, inRange, checksRange)
	local plain, checks = Bool(inRange), Bool(checksRange) == true
	ForSlot(slot, function(button, st)
		st.inRange, st.checksRange = plain, checks
		Colour(button, st)
		DrawHotkey(button, st)
	end)
end

function H.UPDATE_BINDINGS()
	Keys()
	All(SETS.hotkey)
end
H.GAME_PAD_ACTIVE_CHANGED = H.UPDATE_BINDINGS

-- A glow shows or hides on a spell: the buttons whose action holds that spell change state (ActionButton.lua:1037-1058).
local function ProcEvent(spell, on)
	if not Plain(spell, "number") then
		return
	end
	for _, button in ipairs(P.list) do
		local st = P.state[button]
		if st ~= nil and st.has then
			local kind, id, sub = Call("GetActionInfo", st.slot)
			local match = (kind == "spell" and id == spell) or (kind == "macro" and sub == "spell" and id == spell)
				or (kind == "flyout" and Plain(id, "number") and Bool(Call("FlyoutHasSpell", id, spell)) == true)
			if match then
				SetProc(button, st, on)
			end
		end
	end
end
function H.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW(spell) ProcEvent(spell, true) end
function H.SPELL_ACTIVATION_OVERLAY_GLOW_HIDE(spell) ProcEvent(spell, false) end

function H.ACTIONBAR_SHOWGRID()
	P.grid = true
	All(SETS.empty)
end
function H.ACTIONBAR_HIDEGRID()
	P.grid = false
	All(SETS.empty)
end

function H.PLAYER_ENTERING_WORLD()
	Sync()
	P.grid = Call("GetCursorInfo") ~= nil
	All()
end

local frame = CreateFrame("Frame")

-- The one OnUpdate pass: a look at the list of buttons four times a second, the repaint a click asked for, and the pressed look.
local function OnUpdate(_, elapsed)
	if not On() then
		return
	end
	P.since = P.since + (Plain(elapsed, "number") and elapsed or 0)
	if P.since >= 0.25 then
		P.since = 0
		Sync()
	end
	if P.pending then
		P.pending = false
		local queue = P.queue
		P.queue = {}
		for button in pairs(queue) do
			Refresh(button)
		end
	end
	Pressed()
end

local function Start()
	if P.started then
		return true
	end
	if not On() then
		return false
	end
	P.started = true
	for _, event in ipairs(EVENTS) do
		pcall(frame.RegisterEvent, frame, event)
	end
	if type(frame.RegisterUnitEvent) == "function" then
		pcall(frame.RegisterUnitEvent, frame, "UNIT_INVENTORY_CHANGED", "player")
	else
		pcall(frame.RegisterEvent, frame, "UNIT_INVENTORY_CHANGED")
	end
	frame:SetScript("OnUpdate", OnUpdate)
	if not P.subscribed and type(ns.OnOwnSlots) == "function" then
		P.subscribed = true
		ns.OnOwnSlots(SlotsChanged)
	end
	Sync()
	All()
	return true
end

-- The buttons may be made after the first events (a login in a fight, a build that runs after this file's handler): look again a few times.
local function Try()
	if Start() then
		return
	end
	if P.tries < 5 and ns.Get("actionbars.own") == "flat" and type(C_Timer) == "table" then
		P.tries = P.tries + 1
		C_Timer.After(1, Try)
	end
end

frame:SetScript("OnEvent", function(_, event, ...)
	if P.started and H[event] ~= nil and On() then
		local ok, err = pcall(H[event], ...)
		if not ok then
			Failed(event, err)
		end
	end
	if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
		if event == "PLAYER_REGEN_ENABLED" then
			P.tries = 0
		end
		Try()
	end
end)
for _, event in ipairs(FIRST) do
	pcall(frame.RegisterEvent, frame, event)
end

-- The state of a Flat UI button, read only; nil for any other frame.
function ns.OwnState(button)
	if button == nil then
		return nil
	end
	local st = P.state[button]
	if st == nil and On() and type(ns.OwnBar) == "function" and ns.OwnBar(button) ~= nil then
		Refresh(button)
		st = P.state[button]
	end
	return st
end

-- part: "icon", "hotkey" or "empty". fn(button, state) returns r, g, b[, a], or nil for the game's look. The first painter that answers wins.
function ns.OwnPainter(part, fn)
	if P.painters[part] == nil or type(fn) ~= "function" then
		return false
	end
	local list = P.painters[part]
	list[#list + 1] = fn
	if P.started and On() then
		All(part == "icon" and SETS.icon or (part == "hotkey" and SETS.hotkey or SETS.empty))
	end
	return true
end

-- One button, or every Flat UI button for nil, painted again now.
function ns.OwnRepaint(button)
	if not On() then
		return
	end
	if button == nil then
		Sync()
		All()
	else
		Refresh(button)
	end
end

-- fn(button, on) when the glow of the slot's spell comes up or goes.
function ns.OnOwnProc(fn)
	if type(fn) == "function" then
		P.procs[#P.procs + 1] = fn
	end
end

-- How many passes failed, and the last failure; for the status line.
function ns.OwnPaintError()
	return P.failed, P.last
end
