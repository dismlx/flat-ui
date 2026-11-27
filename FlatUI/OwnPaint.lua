local _, ns = ...

local WEAK = { __mode = "k" }
local ORDER = { "slot", "icon", "text", "hotkey", "cooldown", "usable", "range", "checked", "flash", "equipped", "proc", "empty", "spellmark" }
local FIRST = { "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }
local EVENTS = { "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_UPDATE_STATE", "ACTIONBAR_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES",
	"SPELL_UPDATE_ICON", "ACTION_USABLE_CHANGED", "ACTION_RANGE_CHECK_UPDATE", "PLAYER_TARGET_CHANGED", "UPDATE_BINDINGS", "GAME_PAD_ACTIVE_CHANGED",
	"UPDATE_SHAPESHIFT_FORM", "PLAYER_MOUNT_DISPLAY_CHANGED", "UPDATE_INVENTORY_ALERTS", "LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE",
	"START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW",
	"SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID", "MODIFIER_STATE_CHANGED", "PLAYER_ENTER_COMBAT",
	"PLAYER_LEAVE_COMBAT", "CVAR_UPDATE" }
local SETS = {
	state = { checked = true, flash = true },
	cooldown = { cooldown = true },
	charges = { cooldown = true, text = true },
	icon = { icon = true, text = true, usable = true, range = true },
	usable = { usable = true },
	range = { range = true },
	hotkey = { hotkey = true },
	empty = { empty = true },
	items = { checked = true, text = true, usable = true },
	spellmark = { spellmark = true },
}
local COLOUR = { icon = true, cooldown = true, usable = true, range = true }
local HOTKEY = { hotkey = true, range = true, empty = true }
local DOT = "\226\151\143"

local P = {
	state = setmetatable({}, WEAK),
	hooked = setmetatable({}, WEAK),
	numbersHidden = setmetatable({}, WEAK),
	pressed = setmetatable({}, WEAK),
	alpha = setmetatable({}, WEAK),
	easing = setmetatable({}, WEAK),
	easeUp = 0.12, easeDown = 0.2, snap = true,
	marked = setmetatable({}, WEAK),
	flashing = setmetatable({}, WEAK),
	flashClock = 0,
	attacking = nil,
	queue = {},
	painters = { icon = {}, hotkey = {}, empty = {} },
	procs = {},
	ready = {},
	starts = {},
	sweeping = false,
	tip = nil,
	tipClock = 0,
	list = {},
	keys = {},
	grid = false,
	started = false,
	subscribed = false,
	marks = false,
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

local function DrawHotkey(button, st)
	local hk = button.HotKey
	if hk == nil then
		return
	end
	local dot = st.hotkey == ""
	local bare = st.empty == true and not st.grid and type(ns.EmptyKeyHidden) == "function" and ns.EmptyKeyHidden(button) == true
	hk:SetText(dot and (RANGE_INDICATOR or DOT) or st.hotkey)
	hk:SetShown(not bare and ((not dot) or (st.has == true and st.checksRange == true)))
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
			text = type(ns.HotkeyText) == "function" and ns.HotkeyText(shown, button) or shown
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

local function SpellOf(slot)
	local kind, id, sub = Call("GetActionInfo", slot)
	if not Plain(kind, "string") or not Plain(id, "number") then
		return nil
	elseif kind == "spell" or (kind == "macro" and not (Plain(sub, "string") and sub == "item")) then
		return id
	end
	return nil
end

local function BaseOf(spellID)
	if spellID == nil or type(GetSpellBaseCooldown) ~= "function" then
		return nil
	end
	local ok, milliseconds = pcall(GetSpellBaseCooldown, spellID)
	if ok and Plain(milliseconds, "number") and milliseconds > 0 then
		return milliseconds / 1000
	end
	return nil
end

local function Ready(button, st)
	if st.cdFired then
		return
	end
	st.cdFired = true
	local seconds = st.cdSince and GetTime() - st.cdSince or st.cdBase
	for _, fn in ipairs(P.ready) do
		local ok, err = pcall(fn, button, seconds)
		if not ok then
			Failed("ready handler", err)
		end
	end
end

local function WasLong(st)
	return st.cdActive == true and st.cdOnGCD ~= true and st.cdSlot == st.slot and st.cdTexture == st.texture
end

local function ClearSweeps(button)
	for _, key in ipairs({ "cooldown", "chargeCooldown", "lossOfControlCooldown" }) do
		if button[key] ~= nil then
			button[key]:Clear()
		end
	end
end

function STEP.cooldown(button, st)
	local was = WasLong(st)
	local seen = st.cdSlot ~= nil and st.cdSlot == st.slot and st.cdTexture == st.texture
	if not seen then
		st.cdWait = nil
	end
	st.cdSlot, st.cdTexture = st.slot, st.texture
	if not st.has then
		st.cdActive, st.cdOnGCD, st.cdWait = false, false, nil
		P.sweeping = true
		local ok, err = pcall(ClearSweeps, button)
		P.sweeping = false
		if not ok then
			error(err, 0)
		end
		return
	end
	local slot = st.slot
	local cooldown, charges, loss = Call("GetActionCooldown", slot), Call("GetActionCharges", slot), Call("GetActionLossOfControlCooldownInfo", slot)
	local replace = type(loss) == "table" and Bool(loss.shouldReplaceNormalCooldown) == true
	st.cdActive = type(cooldown) == "table" and Bool(cooldown.isActive) == true
	st.cdOnGCD = type(cooldown) == "table" and Bool(cooldown.isOnGCD) == true
	local long = st.cdActive and not st.cdOnGCD
	if was and not long and st.cdActive then
		st.cdWait = true
	elseif was and not long then
		Ready(button, st)
	elseif st.cdWait and not st.cdActive then
		st.cdWait = nil
		Ready(button, st)
	elseif long and not was then
		st.cdFired, st.cdWait = false, nil
		local spell = SpellOf(slot)
		if seen then
			st.cdSince, st.cdBase = GetTime(), nil
			if spell ~= nil then
				P.starts[spell] = st.cdSince
			end
		else
			local base, start = BaseOf(spell), spell ~= nil and P.starts[spell] or nil
			if base ~= nil and start ~= nil and GetTime() - start < base then
				st.cdSince, st.cdBase = start, nil
			else
				st.cdSince, st.cdBase = false, base
			end
		end
	end
	local gcdOff = st.cdOnGCD and not st.cdWait and ns.Enabled("actionbars") and ns.Get("actionbars.sweepGcd") == false
	P.sweeping = true
	local ok, err = pcall(Sweep, button.cooldown, st.cdActive and not replace and not gcdOff, "GetActionCooldownDuration", slot)
	P.sweeping = false
	if not ok then
		error(err, 0)
	end
	Sweep(button.chargeCooldown, type(charges) == "table" and Bool(charges.isActive) == true and not replace, "GetActionChargeDuration", slot)
	if type(loss) == "table" then
		Sweep(button.lossOfControlCooldown, Bool(loss.isActive) == true, "GetActionLossOfControlCooldownDuration", slot)
	elseif button.lossOfControlCooldown ~= nil then
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

function STEP.checked(button, st)
	local checked = false
	if st.has then
		local current, repeating, pet = Bool(Call("IsCurrentAction", st.slot)), Bool(Call("IsAutoRepeatAction", st.slot)), Bool(Call("IsAutoCastPetAction", st.slot))
		checked = (current == true or repeating == true) and pet ~= true
	end
	st.checked = checked
	button:SetChecked(checked)
end

function STEP.flash(button, st)
	local on = false
	if st.has then
		local attack, repeating = Bool(Call("IsAttackAction", st.slot)) == true, Bool(Call("IsAutoRepeatAction", st.slot)) == true
		local swinging = P.attacking
		if swinging == nil and attack then
			swinging = Bool(Call("IsCurrentAction", st.slot)) == true
		end
		on = (attack and swinging == true) or repeating
	end
	if st.flash == on then
		return
	end
	st.flash = on
	if on then
		P.flashing[button] = true
	else
		P.flashing[button] = nil
		if button.Flash ~= nil then
			button.Flash:Hide()
		end
	end
end

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

function STEP.spellmark(button, st)
	local on = false
	if st.has and type(GetOnBarHighlightMark) == "function" then
		local ok, mark = pcall(GetOnBarHighlightMark, st.slot)
		on = ok and not ns.IsSecret(mark) and mark ~= nil and mark ~= false
	end
	if (P.marked[button] == true) == on then
		return
	end
	local texture, anim = button.SpellHighlightTexture, button.SpellHighlightAnim
	if texture == nil or anim == nil then
		return
	end
	P.marked[button] = on or nil
	if on then
		texture:Show()
		anim:Play()
	else
		texture:Hide()
		anim:Stop()
	end
end

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
	local now, ease = P.alpha[button], P.easing[button]
	if now == nil or P.snap then
		P.easing[button] = nil
		if now ~= want then
			P.alpha[button] = want
			button:SetAlpha(want)
		end
	elseif ease and ease[1] == want then
		return
	elseif now == want then
		P.easing[button] = nil
	else
		P.easing[button] = { want, math.abs(want - now) / (want > now and P.easeUp or P.easeDown) }
	end
end

local function Refresh(button, set)
	local st = StateFor(button)
	local colour, hotkey = false, false
	P.snap = set == nil
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

local function BoxReadable()
	local box = GameTooltipDefaultContainer or SharedTooltipDefaultContainer
	if type(box) ~= "table" or ns.IsSecret(box) or type(box.GetPoint) ~= "function" then
		return false
	end
	local ok, point, _, _, x, y = pcall(box.GetPoint, box, 1)
	return ok and Plain(point, "string") and Plain(x, "number") and Plain(y, "number")
end

local function Owns(tip, button)
	local ok, owner = pcall(tip.GetOwner, tip)
	return ok and not ns.IsSecret(owner) and rawequal(owner, button)
end

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
	local ok, answer = pcall(tip.SetAction, tip, slot)
	if not ok then
		Failed("tooltip", answer)
	end
	P.tip, P.tipClock = (ok and Bool(answer) ~= false) and button or nil, 0
end

local function HideTip(button)
	local tip = GameTooltip
	if rawequal(P.tip, button) then
		P.tip = nil
	end
	if tip ~= nil and Owns(tip, button) then
		pcall(tip.Hide, tip)
	end
end

local function TipTick(elapsed)
	if P.tip == nil then
		return
	end
	P.tipClock = P.tipClock + elapsed
	local every = Plain(TOOLTIP_UPDATE_TIME, "number") and TOOLTIP_UPDATE_TIME > 0 and TOOLTIP_UPDATE_TIME or 0.2
	if P.tipClock < every then
		return
	end
	P.tipClock = 0
	local tip, button = GameTooltip, P.tip
	local okShown, shown = false, nil
	if tip ~= nil then
		okShown, shown = pcall(tip.IsShown, tip)
	end
	if okShown and Bool(shown) == true and Owns(tip, button) then
		ShowTip(button)
	else
		P.tip = nil
	end
end

local function CooldownDone(button)
	if P.sweeping then
		return
	end
	local st = P.state[button]
	if st ~= nil and (st.cdWait == true or (st.cdActive == true and st.cdOnGCD ~= true)) then
		st.cdWait = nil
		Ready(button, st)
	end
	P.queue[button] = true
	P.pending = true
end

local function NumbersOff()
	local read = C_CVar and C_CVar.GetCVarBool or GetCVarBool
	if type(read) ~= "function" then
		return nil
	end
	local ok, on = pcall(read, "countdownForCooldowns")
	if not ok or ns.IsSecret(on) then
		return nil
	end
	return on ~= true
end

local function NumbersHidden(button, hide)
	if hide == nil then
		hide = NumbersOff()
	end
	local cooldown = button.cooldown
	if hide == nil or type(cooldown) ~= "table" or type(cooldown.SetHideCountdownNumbers) ~= "function" or P.numbersHidden[button] == hide then
		return
	end
	if pcall(cooldown.SetHideCountdownNumbers, cooldown, hide) then
		P.numbersHidden[button] = hide
	end
end

local function Hook(button)
	if P.hooked[button] then
		return
	end
	P.hooked[button] = true
	NumbersHidden(button)
	button:HookScript("OnEnter", function(self) ShowTip(self) end)
	button:HookScript("OnLeave", function(self) HideTip(self) end)
	button:HookScript("PostClick", function(self)
		P.queue[self] = true
		P.pending = true
	end)
	local cooldown = button.cooldown
	if type(cooldown) == "table" and type(cooldown.HookScript) == "function" then
		pcall(cooldown.HookScript, cooldown, "OnCooldownDone", function()
			local ok, err = pcall(CooldownDone, button)
			if not ok then
				Failed("cooldown done", err)
			end
		end)
	end
end

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
function H.PLAYER_ENTER_COMBAT()
	P.attacking = true
	All(SETS.state)
end
function H.PLAYER_LEAVE_COMBAT()
	P.attacking = false
	All(SETS.state)
end
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

function H.CVAR_UPDATE(name)
	if not Plain(name, "string") or name:lower() ~= "countdownforcooldowns" then
		return
	end
	local hide = NumbersOff()
	for _, button in ipairs(P.list) do
		NumbersHidden(button, hide)
	end
end

function H.MODIFIER_STATE_CHANGED()
	local tip = GameTooltip
	if tip == nil then
		return
	end
	for _, button in ipairs(P.list) do
		if Owns(tip, button) then
			ShowTip(button)
			return
		end
	end
end

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

local function Blink(elapsed)
	if next(P.flashing) == nil then
		P.flashClock = 0
		return
	end
	local every = Plain(ATTACK_BUTTON_FLASH_TIME, "number") and ATTACK_BUTTON_FLASH_TIME > 0 and ATTACK_BUTTON_FLASH_TIME or 0.4
	P.flashClock = P.flashClock + elapsed
	if P.flashClock < every then
		return
	end
	P.flashClock = P.flashClock >= 2 * every and 0 or P.flashClock - every
	for button in pairs(P.flashing) do
		local flash = button.Flash
		if flash ~= nil then
			flash:SetShown(not flash:IsShown())
		end
	end
end

local function Ease(elapsed)
	if next(P.easing) == nil then
		return
	end
	for button, ease in pairs(P.easing) do
		local want = ease[1]
		local now = P.alpha[button] or want
		local step = ease[2] * elapsed
		if ease[2] <= 0 or math.abs(want - now) <= step then
			now = want
			P.easing[button] = nil
		elseif want > now then
			now = now + step
		else
			now = now - step
		end
		P.alpha[button] = now
		button:SetAlpha(now)
	end
end

local function OnUpdate(_, elapsed)
	if not On() then
		return
	end
	elapsed = Plain(elapsed, "number") and elapsed or 0
	P.since = P.since + elapsed
	if P.since >= 0.25 then
		P.since = 0
		Sync()
	end
	Blink(elapsed)
	Ease(elapsed)
	TipTick(elapsed)
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

local function FollowMarks()
	if not P.marks and ns.FollowGlobal("ActionBarController_UpdateAllSpellHighlights", function()
		if On() then
			All(SETS.spellmark)
		end
	end) ~= nil then
		P.marks = true
	end
end

local function Start()
	if P.started then
		FollowMarks()
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
	FollowMarks()
	Sync()
	All()
	return true
end

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

function ns.OwnRepaintEmpty()
	if P.started and On() then
		All(SETS.empty)
	end
end

function ns.OnOwnProc(fn)
	if type(fn) == "function" then
		P.procs[#P.procs + 1] = fn
	end
end

function ns.OnOwnReady(fn)
	if type(fn) == "function" then
		P.ready[#P.ready + 1] = fn
	end
end

function ns.OwnPaintError()
	return P.failed, P.last
end
