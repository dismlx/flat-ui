local _, ns = ...

local KEY = "errands"

local Errands = { parts = {} }
ns.Errands = Errands

function Errands.Opt(key)
	return ns.Get(KEY .. "." .. key)
end

function Errands.On(key)
	return ns.Enabled(KEY) and Errands.Opt(key) == true
end

function Errands.Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok or ns.IsSecret(a) then
		return nil
	end
	if ns.IsSecret(b) then
		b = nil
	end
	if ns.IsSecret(c) then
		c = nil
	end
	if ns.IsSecret(d) then
		d = nil
	end
	return a, b, c, d
end

function Errands.Call(fn, ...)
	if type(fn) ~= "function" then
		return false
	end
	return (pcall(fn, ...))
end

function Errands.InCombat()
	local fight = Errands.Ask(InCombatLockdown)
	return fight == true
end

function Errands.Money(copper)
	copper = math.floor(tonumber(copper) or 0)
	local text = Errands.Ask(GetMoneyString, copper, true) or Errands.Ask(GetCoinTextureString, copper)
		or (type(C_CurrencyInfo) == "table" and Errands.Ask(C_CurrencyInfo.GetCoinTextureString, copper)) or nil
	if type(text) == "string" and text ~= "" then
		return text
	end
	local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	local parts = {}
	if gold > 0 then
		parts[#parts + 1] = gold .. "g"
	end
	if silver > 0 then
		parts[#parts + 1] = silver .. "s"
	end
	if rest > 0 or #parts == 0 then
		parts[#parts + 1] = rest .. "c"
	end
	return table.concat(parts, " ")
end

function Errands.Say(text)
	if Errands.Opt("chat") ~= false then
		print("Flat UI: " .. text)
	end
end

function Errands.TipOwned(button)
	local tip = GameTooltip
	if type(tip) ~= "table" or ns.Forbidden(tip) then
		return false
	end
	local ok, owned = pcall(tip.IsOwned, tip, button)
	if not ok or owned ~= true then
		return false
	end
	local okShown, shown = pcall(tip.IsShown, tip)
	if okShown and shown == false then
		return false
	end
	local okOver, over = pcall(button.IsMouseOver, button)
	return not okOver or ns.IsSecret(over) or over ~= false
end

local function Shade(delta)
	local r, g, b = ns.Colour("general.backdrop")
	return math.min(1, math.max(0, r + delta)), math.min(1, math.max(0, g + delta)), math.min(1, math.max(0, b + delta))
end

local function Over(button)
	local ok, over = pcall(button.IsMouseOver, button)
	return not ok or ns.IsSecret(over) or over ~= false
end

function Errands.Button(parent, text, width, onClick, onEnter)
	local button = CreateFrame("Frame", nil, parent)
	ns.Own[button] = true
	button:SetSize(width, 22)
	local outline = ns.Outline(button, button, true)
	local label = ns.OwnText(button, "OVERLAY", "GameFontHighlightSmall")
	if label then
		label:SetPoint("CENTER", button, "CENTER", 0, 0)
		label:SetWidth(width - 12)
		label:SetWordWrap(false)
		label:SetText(text)
	end
	local down, hover, usable, pressed = false, false, true, false
	local function Paint()
		local r, g, b = Shade(hover and usable and not pressed and 0.17 or 0.09)
		if outline then
			ns.SetOutlineFill(outline, r, g, b, 1)
		end
		if label then
			label:SetAlpha(usable and 1 or 0.45)
		end
	end
	local function Press(on)
		if on == pressed then
			return
		end
		pressed = on
		if label then
			label:SetPoint("CENTER", button, "CENTER", 0, on and -1 or 0)
		end
		Paint()
	end
	Paint()
	button:EnableMouse(true)
	button:SetScript("OnEnter", function()
		hover = true
		Paint()
		if onEnter then
			pcall(onEnter, button)
		end
	end)
	button:SetScript("OnLeave", function()
		hover, down = false, false
		Press(false)
		Paint()
		if GameTooltip and not ns.Forbidden(GameTooltip) and GameTooltip:IsOwned(button) then
			GameTooltip:Hide()
		end
	end)
	button:SetScript("OnHide", function()
		hover, down = false, false
		Press(false)
		if GameTooltip and not ns.Forbidden(GameTooltip) and GameTooltip:IsOwned(button) then
			GameTooltip:Hide()
		end
	end)
	button:SetScript("OnMouseDown", function(_, which)
		down = which == "LeftButton"
		if down and usable then
			Press(true)
		end
	end)
	button:SetScript("OnMouseUp", function(_, which)
		Press(false)
		local wanted = down and which == "LeftButton" and usable and Over(button)
		down = false
		if wanted then
			onClick(button)
		end
	end)
	function button.Keep(wanted)
		button:SetScript("OnUpdate", function()
			local ok, keep = pcall(wanted)
			if not ok or not keep then
				button:Hide()
			end
		end)
	end
	pcall(button.SetClampedToScreen, button, true)
	function button.SetUsable(on)
		usable = on == true
		if not usable then
			Press(false)
		end
		Paint()
	end
	function button.SetLabel(words)
		if label then
			label:SetText(words)
		end
	end
	return button
end

function Errands.Part(part)
	Errands.parts[#Errands.parts + 1] = part
	return part
end

local reported = {}

function Errands.Run(part, fn, ...)
	local ok, err = ns.EachPart(KEY, part.label, function(_, ...)
		return fn(...)
	end, {}, ...)
	if not ok and err ~= nil and not reported[part.label] then
		reported[part.label] = true
		local handler = type(geterrorhandler) == "function" and geterrorhandler()
		if type(handler) == "function" then
			pcall(handler, ("Flat UI Errands, %s: %s"):format(part.label, tostring(err)))
		end
	end
	return ok
end

function Errands.Listen(part, event, fn)
	return ns.AddEvent(KEY, event, function(...)
		Errands.Run(part, fn, ...)
	end)
end

function Errands.Lists()
	if type(FlatUIDB) ~= "table" then
		return nil
	end
	local lists = type(FlatUIDB.errands) == "table" and FlatUIDB.errands or {}
	FlatUIDB.errands = lists
	lists.sell = type(lists.sell) == "table" and lists.sell or {}
	lists.keep = type(lists.keep) == "table" and lists.keep or {}
	return lists
end

function Errands.Kept(id)
	local lists = Errands.Lists()
	return lists ~= nil and lists.keep[id] == true
end

function Errands.Gamepad()
	if type(InputUtil) ~= "table" or ns.IsSecret(InputUtil) or type(InputUtil.IsGamepadUIEnabled) ~= "function" then
		return false
	end
	local ok, on = pcall(InputUtil.IsGamepadUIEnabled)
	return ok and not ns.IsSecret(on) and on == true
end

function Errands.Shown(frame)
	if type(frame) ~= "table" or ns.Forbidden(frame) or type(frame.IsShown) ~= "function" then
		return false
	end
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and not ns.IsSecret(shown) and shown == true
end

local POPUPS = 4

local function PopupField(frame, key)
	local ok, value = pcall(function()
		return frame[key]
	end)
	if not ok or ns.IsSecret(value) then
		return nil
	end
	return value
end

function Errands.PopupField(frame, key)
	return PopupField(frame, key)
end

function Errands.Popups()
	local count = STATICPOPUP_NUMDIALOGS
	if type(count) ~= "number" or ns.IsSecret(count) or count < 1 or count > 10 then
		count = POPUPS
	end
	local list = {}
	for index = 1, count do
		local name = "StaticPopup" .. index
		local frame = _G[name]
		if Errands.Shown(frame) then
			list[#list + 1] = { frame = frame, name = name, which = PopupField(frame, "which") }
		end
	end
	return list
end

function Errands.HideAlone(which)
	if type(StaticPopup_Hide) ~= "function" then
		return false
	end
	local shown = Errands.Popups()
	if #shown ~= 1 or shown[1].which ~= which then
		return false
	end
	return (pcall(StaticPopup_Hide, which))
end

function Errands.Fighting()
	return Errands.InCombat() or Errands.Ask(UnitAffectingCombat, "player") == true
end

local function EachPart(method)
	for _, part in ipairs(Errands.parts) do
		if type(part[method]) == "function" then
			Errands.Run(part, part[method])
		end
	end
end

local function Start()
	EachPart("Start")
end

local function Refresh()
	EachPart("Refresh")
end

local function Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	for _, part in ipairs(Errands.parts) do
		if type(part.Status) == "function" and not ns.PartStopped(KEY, part.label) then
			local ok, more = pcall(part.Status)
			if ok and type(more) == "table" then
				for _, line in ipairs(more) do
					lines[#lines + 1] = line
				end
			end
		end
	end
	return lines
end

Errands.slash, Errands.help = {}, {}

ns.Register(KEY, {
	label = "Errands",
	counted = false,
	Start = Start,
	Refresh = Refresh,
	Status = Status,
	slash = Errands.slash,
	help = Errands.help,
})
