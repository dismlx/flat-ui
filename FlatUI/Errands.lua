local _, ns = ...

-- Errands: small chores the game leaves to the player, done when the game asks for them. Selling grey items and repairing at a merchant
-- (ErrandsMerchant.lua), looting every slot at once and making room in full bags (ErrandsLoot.lua), training every spell a trainer offers
-- (ErrandsTrainer.lua), the release guard, summons, resurrections and the DELETE word of the game's popups (ErrandsPopups.lua), and group
-- invites, duels and the last mail recipient (ErrandsSocial.lua). Each file is a part of this module: it adds its events with ns.AddEvent and
-- names itself here with Errands.Part, so /flatui status has a line for it and a refresh reaches it.
--
-- Nothing here restyles anything, so the module counts nothing, and its page is off by default. Every errand is out of combat unless it
-- says otherwise, and every call into the client goes through pcall: a client without the call leaves the errand undone and says so once.
-- Several of these errands follow the ways EnhanceQoL by Philipp Barth does them, adapted with his permission.

local KEY = "errands"

local Errands = { parts = {} }
ns.Errands = Errands

function Errands.Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- True while the module is on and the row is ticked.
function Errands.On(key)
	return ns.Enabled(KEY) and Errands.Opt(key) == true
end

-- Up to four values the client gives, each nil when the client withholds it (a secret); all nil when the call is missing or raises.
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

-- Calls the client and says whether it took the call.
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

-- An amount of copper as the game writes money ("1g 20s 5c" with coin icons), or plain text when the client has no money string.
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

-- A line in the chat frame, when Messages in chat is ticked.
function Errands.Say(text)
	if Errands.Opt("chat") ~= false then
		print("Flat UI: " .. text)
	end
end

-- Whether the game's tooltip is shown for a button and the cursor is still over it: only then is it drawn again, so an update never brings a
-- tooltip back after the cursor left.
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

-- A colour of the Background colour moved toward white by delta, for the plate of an own button.
local function Shade(delta)
	local r, g, b = ns.Colour("general.backdrop")
	return math.min(1, math.max(0, r + delta)), math.min(1, math.max(0, g + delta)), math.min(1, math.max(0, b + delta))
end

-- Whether the cursor is over a button when it is let go: a press let go elsewhere is no click, as with a button of the game's (BagSort.lua does
-- the same). A client that does not say counts as over.
local function Over(button)
	local ok, over = pcall(button.IsMouseOver, button)
	return not ok or ns.IsSecret(over) or over ~= false
end

-- A flat button of the addon's own, as Reload.lua makes them: a frame with an outline and a label, clicked when the left mouse button comes up
-- over it after going down on it, so the click is the player's own (a hardware click). button.SetUsable greys it and turns its click off.
function Errands.Button(parent, text, width, onClick, onEnter)
	local button = CreateFrame("Frame", nil, parent)
	ns.Own[button] = true
	button:SetSize(width, 22)
	local outline = ns.Outline(button, button, true)
	local label = ns.OwnText(button, "OVERLAY", "GameFontHighlightSmall")
	if label then
		label:SetPoint("CENTER", button, "CENTER", 0, 0)
		label:SetText(text)
	end
	local down, hover, usable = false, false, true
	local function Paint()
		local r, g, b = Shade(hover and usable and 0.17 or 0.09)
		if outline then
			ns.SetOutlineFill(outline, r, g, b, 1)
		end
		if label then
			label:SetAlpha(usable and 1 or 0.45)
		end
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
		Paint()
		if GameTooltip and not ns.Forbidden(GameTooltip) and GameTooltip:IsOwned(button) then
			GameTooltip:Hide()
		end
	end)
	-- A button hidden under the cursor takes its tooltip with it.
	button:SetScript("OnHide", function()
		hover, down = false, false
		if GameTooltip and not ns.Forbidden(GameTooltip) and GameTooltip:IsOwned(button) then
			GameTooltip:Hide()
		end
	end)
	button:SetScript("OnMouseDown", function(_, which)
		down = which == "LeftButton"
	end)
	button:SetScript("OnMouseUp", function(_, which)
		local wanted = down and which == "LeftButton" and usable and Over(button)
		down = false
		if wanted then
			onClick(button)
		end
	end)
	-- A button that is no longer wanted hides itself while it shows (wanted() is asked every frame then), so a part that stopped, or an event
	-- missed while the module was off, cannot leave a live button on a game window.
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
		Paint()
	end
	function button.SetLabel(words)
		if label then
			label:SetText(words)
		end
	end
	return button
end

-- part: { label = name for /flatui status, Start = function, Refresh = function, Status = function returning lines }.
function Errands.Part(part)
	Errands.parts[#Errands.parts + 1] = part
	return part
end

-- The parts whose first error went to the game's error handler.
local reported = {}

-- Runs fn as a part of the module. ns.EachPart counts each failure (a fresh key per call, since an event with no values would count once) and
-- stops the part alone after a few, with a line for /flatui status, while the other errands go on. The first error of a part also goes to the
-- game's error handler, so it is seen.
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

-- Runs fn on an event while the module is on.
function Errands.Listen(part, event, fn)
	return ns.AddEvent(KEY, event, function(...)
		Errands.Run(part, fn, ...)
	end)
end

-- The account's lists of items, by item ID: sell (always sold at a merchant) and keep (never sold, never deleted to make room). Kept in
-- FlatUIDB.errands, outside every profile. Nil before the saved variables are loaded.
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

-- Whether the game shows the interface made for a gamepad: an own button on a game window could not be reached then (BagSort.lua leaves
-- its buttons out the same way).
function Errands.Gamepad()
	if type(InputUtil) ~= "table" or ns.IsSecret(InputUtil) or type(InputUtil.IsGamepadUIEnabled) ~= "function" then
		return false
	end
	local ok, on = pcall(InputUtil.IsGamepadUIEnabled)
	return ok and not ns.IsSecret(on) and on == true
end

-- Whether a frame of the game is shown, asked with the widget call IsShown. False when it is missing, forbidden or does not say.
function Errands.Shown(frame)
	if type(frame) ~= "table" or ns.Forbidden(frame) or type(frame.IsShown) ~= "function" then
		return false
	end
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and not ns.IsSecret(shown) and shown == true
end

-- The shown popups of the game (StaticPopup1 to 4): { frame, name, which }. Read with the widget call IsShown and the field which; no popup code
-- is called.
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

-- Hides a popup of the game with StaticPopup_Hide, only when it is the one popup shown: hiding it beside another one would leave values written by
-- Flat UI's code in the game's list of shown popups, which the game renews securely only once that list is empty. True when it was hidden.
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

-- True in a fight: the lockdown, or the player in combat (UnitAffectingCombat), which can come a moment before it.
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
		-- A stopped part has its note from ns.EachPart, and nothing it says about what it does is true any longer.
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

-- The slash words of the parts, gathered when the module registers below.
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
