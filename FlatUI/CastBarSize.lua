local _, ns = ...

local KEY = "castbars"
local PART = "size"

local BARS = {
	{ key = "player", name = "PlayerCastingBarFrame", game = { 208, 11, 150, 10 } },
	{ key = "pet", name = "PetCastingBarFrame", game = { 195, 13, 150, 10 } },
	{ key = "target", name = "TargetFrameSpellBar", game = { 150, 10, 150, 10 }, child = true },
	{ key = "focus", name = "FocusFrameSpellBar", game = { 150, 10, 150, 10 }, child = true },
}

local SPARK_HEIGHT, SPARK_EXTRA = 20, 9
local MASK_WIDTH, MASK_HEIGHT = 256, 13
local BAR_WIDTH, BAR_HEIGHT = 208, 11

local sized = setmetatable({}, { __mode = "k" })
local queued = {}
local hooked = false
local Apply
local applied, told = {}, {}

local function Rows(entry)
	local key = entry.key
	local player = key == "player"
	return ("%s|%s|%s|%s|%s|%s"):format(tostring(ns.Enabled(KEY)), tostring(ns.Get(KEY .. "." .. key .. "Size")), tostring(ns.Get(KEY .. "." .. key .. "Width")),
		tostring(ns.Get(KEY .. "." .. key .. "Height")), player and tostring(ns.Get(KEY .. ".playerMatch")) or "", player and tostring(ns.Get(KEY .. ".playerText")) or "")
end

local function Tell(entry)
	if told[entry.key] or applied[entry.key] == nil or applied[entry.key] == Rows(entry) or not (type(ns.PanelShown) == "function" and ns.PanelShown() == true) then
		return
	end
	told[entry.key] = true
	print(("Flat UI: the %s cast bar takes its new size when the fight ends."):format(entry.key))
end

local function Attached()
	local bar = PlayerCastingBarFrame
	if ns.Forbidden(bar) then
		return false
	end
	local ok, attached = pcall(function()
		return bar.attachedToPlayerFrame
	end)
	return ok and not ns.IsSecret(attached) and attached == true
end

local function Part(bar, key)
	local ok, part = pcall(function()
		return bar[key]
	end)
	if ok and part ~= nil and not ns.IsSecret(part) then
		return part
	end
	return nil
end

local function PlaceText(bar, attached, custom)
	local text = Part(bar, "Text")
	if not text then
		return
	end
	text:ClearAllPoints()
	if custom == "inside" then
		text:SetPoint("CENTER", bar, "CENTER", 0, 0)
	elseif custom == "below" then
		text:SetPoint("TOP", bar, "BOTTOM", 0, 1)
	elseif attached then
		text:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 3)
		text:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 3)
	else
		text:SetPoint("TOP", bar, "TOP", 0, -10)
	end
end

local function FitPlayer(bar, width, height, custom)
	local spark, mask = Part(bar, "Spark"), Part(bar, "BorderMask")
	if spark then
		spark:SetHeight(custom and height + SPARK_EXTRA or SPARK_HEIGHT)
	end
	if mask then
		if custom then
			mask:SetSize(width * MASK_WIDTH / BAR_WIDTH, height * MASK_HEIGHT / BAR_HEIGHT)
		else
			mask:SetSize(MASK_WIDTH, MASK_HEIGHT)
		end
	end
	PlaceText(bar, Attached(), custom)
end

local function Unsize(bar, entry)
	sized[bar] = nil
	local game = entry.game
	local locked = not entry.child and Attached()
	bar:SetWidth(locked and game[3] or game[1])
	bar:SetHeight(locked and game[4] or game[2])
	if entry.key == "player" then
		FitPlayer(bar, BAR_WIDTH, BAR_HEIGHT, nil)
	end
end

function ns.StackWidth(frame)
	local display = PersonalResourceDisplayFrame
	if ns.Forbidden(display) or ns.Forbidden(frame) then
		return nil
	end
	local ok, width, shown, own = pcall(function()
		return display:GetWidth(), display:GetEffectiveScale(), frame:GetEffectiveScale()
	end)
	if not ok or not (ns.Finite(width) and ns.Finite(shown) and ns.Finite(own)) or width <= 0 or shown <= 0 or own <= 0 then
		return nil
	end
	local units = math.floor(width * shown / own + 0.5)
	return units > 0 and units or nil
end

local function Size(bar, entry)
	local on = ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and ns.Get(KEY .. "." .. entry.key .. "Size")
	local player = entry.key == "player"
	local match = ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and player and ns.Get("castbars.playerMatch") == "resource"
	if match and ns.EditModeOpen() then
		return
	end
	local matched = match and not Attached() and ns.StackWidth(bar) or nil
	local custom = on and entry.key == "player" and ns.Get("castbars.playerText") or nil
	if custom == "game" then
		custom = Attached() and "inside" or "below"
	end
	if on or matched then
		local width, height = matched or ns.Get(KEY .. "." .. entry.key .. "Width"), on and ns.Get(KEY .. "." .. entry.key .. "Height") or BAR_HEIGHT
		sized[bar] = true
		bar:SetWidth(width)
		bar:SetHeight(height)
		if player then
			FitPlayer(bar, width, height, custom)
		end
	elseif sized[bar] then
		Unsize(bar, entry)
	end
end

local function FitText(bar)
	local on = ns.Enabled(KEY)
	local percent = on and ns.Get(KEY .. ".textSize") or 100
	if ns.TextStyle(Part(bar, "Text"), { percent = percent, flags = on and ns.OutlineFlags(ns.Get(KEY .. ".textOutline")) or nil }) == false then
		ns.Note(KEY, "Cast bars: the font of a spell name could not be changed, so it keeps its size.")
	end
	ns.CastText(bar)
end

function Apply(entry)
	local bar = _G[entry.name]
	if bar == nil or ns.IsSecret(bar) or ns.Forbidden(bar) then
		return
	end
	if InCombatLockdown() and (entry.child or ns.MaybeProtected(bar)) then
		if not queued[entry.key] then
			queued[entry.key] = true
			ns.OutOfCombat(function()
				queued[entry.key] = nil
				told[entry.key] = nil
				Apply(entry)
			end)
		end
		Tell(entry)
		return
	end
	applied[entry.key] = Rows(entry)
	if ns.IsStopped(KEY) or ns.PartStopped(KEY, PART) then
		pcall(Size, bar, entry)
	elseif not ns.EachPart(KEY, PART, Size, bar, entry) and not ns.IsStopped(KEY) and not ns.PartStopped(KEY, PART) then
		ns.Note(KEY, ("Cast bars: the game refused a size on the %s cast bar."):format(entry.key))
		pcall(Unsize, bar, entry)
	end
	ns.Each(KEY, FitText, bar)
end

local function Resize()
	Apply(BARS[1])
	Apply(BARS[2])
end

local function Hook()
	if hooked or not ns.Enabled(KEY) or not (ns.Get("castbars.playerSize") or ns.Get("castbars.playerMatch") == "resource" or ns.Get("castbars.petSize") or ns.Get("castbars.textOutline") ~= "game" or ns.Get("castbars.textSize") ~= 100
		or ns.Get("castbars.textAlign") ~= "game" or ns.Get("castbars.textOwn")) then
		return
	end
	hooked = true
	if ns.WatchEditModePass then
		ns.WatchEditModePass()
	end
	for _, name in ipairs({ "PlayerFrame_AttachCastBar", "PlayerFrame_DetachCastBar" }) do
		ns.FollowGlobal(name, Resize)
	end
end

function ns.CastBarSizes()
	for _, entry in ipairs(BARS) do
		Apply(entry)
	end
	if ns.PartStopped(KEY, PART) then
		for _, entry in ipairs(BARS) do
			Apply(entry)
		end
	end
	Hook()
	if type(ns.HitTableMoved) == "function" then
		pcall(ns.HitTableMoved)
	end
end

function ns.StackWidths()
	Hook()
	local entry = BARS[1]
	local bar = _G[entry.name]
	if bar ~= nil and not ns.IsSecret(bar) and not ns.Forbidden(bar) then
		local want = ns.Get("castbars.playerMatch") == "resource" and not Attached() and ns.StackWidth(bar) or nil
		local ok, now = pcall(bar.GetWidth, bar)
		local same = want and ok and ns.Finite(now) and now == want and sized[bar]
		if not same and (want or sized[bar]) then
			Apply(entry)
		end
	end
	if ns.SwingWidths then
		ns.SwingWidths()
	end
end

local events = CreateFrame("Frame")
pcall(events.RegisterEvent, events, "PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function()
	ns.CastBarSizes()
end)
