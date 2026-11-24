local _, ns = ...

-- Channel ticks: thin marks across the player's cast bar where each tick of a channel lands, while Channel ticks on the player bar (on by default,
-- under Look on the Cast bars page) and the page are on, with or without the flat fill. Not a module: Bars.lua calls ns.CastTicksSync at the end of
-- every refresh of the cast bars. While the row is on, a frame of the addon's own hears the player's UNIT_SPELLCAST_CHANNEL_START, _UPDATE and _STOP
-- (RegisterUnitEvent; UnitDocumentation.lua, the events the game's cast bar hears, Shared/CastingBarFrame.lua:240-242). At a start or an update it
-- reads UnitChannelInfo of the player (UnitDocumentation.lua:870-893: the start and end in milliseconds and the spell ID, plain for the player and
-- tested all the same) and asks SpellModel.lua for the rank of that spell (ns.SpellModel.Find): a rank of a channel (ct -1 in SpellData.lua) gives
-- its ticks, the rank's own count of the part that ticks, else the part's (Arcane Missiles 3, 4 and 5, Blizzard 8, Mind Flay 3, Drain Life 5,
-- Hellfire 15). A spell that is no channel there, or has fewer than two ticks, gets no marks.
-- The ticks of a channel come at even steps from its start; the bar drains from its right end to its left (CastingBarFrame.lua:395 and 524-538:
-- the value is the time left, the width the whole channel), so a tick k is at 1 - k * step / length of the width from the left, and a pushback,
-- which ends the channel sooner, moves the marks with the bar's new length (the step is the one the channel started with) and drops those past
-- its end. The width is read at each start and update (bar:GetWidth, plain on the player bar), so the marks follow the size of CastBarSize.lua.
-- The marks are textures of the addon's own on PlayerCastingBarFrame and OverlayPlayerCastingBarFrame (OVERLAY, under the spark), 15 a bar, one
-- screen pixel wide (ns.Pixels) and as tall as the bar, white at 0.6 opacity, made once and, on a bar the game may protect, only out of combat
-- (ns.MaybeProtected, Movers.lua), and placed with SetPoint only where the bar is not protected in a fight. They hide at the channel's stop and
-- when the row, the page or the part goes off. /flatui status names the last channel and its ticks. Nothing of the game is written or called but
-- CreateTexture on the two bars, as Bars.lua makes its own marks there.

local KEY, ROW, PART = "castbars", "castbars.ticks", "channel ticks"
local BARS = { "PlayerCastingBarFrame", "OverlayPlayerCastingBarFrame" }
-- POOL: the marks a bar has (Hellfire's 15 ticks need 14). ALPHA: their opacity. SUBLEVEL: their place in the OVERLAY layer, under the spark (2).
local POOL, ALPHA, SUBLEVEL = 15, 0.6, 1
local EVENTS = { "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP" }

-- marks[bar]: the list of its marks, false when they could not be made. S: frame (the file's own, false when it could not be made), on (the events are
-- heard), spell, ticks and step (the channel that has marks: its spell ID, its ticks and the milliseconds between two, from its start), last (the
-- name and ticks of the last channel with marks, for /flatui status).
local marks = setmetatable({}, { __mode = "k" })
local S = { frame = nil, on = false, spell = nil, ticks = nil, step = nil, last = nil }

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

local function On()
	return ns.Enabled(KEY) and ns.Get(ROW) == true and not ns.PartStopped(KEY, PART)
end

-- The ticks of a channel by its spell ID: the rank's own count of the part that ticks, else the part's; nil for a spell that is no channel there.
local function TicksOf(spellID)
	local model = ns.SpellModel
	if not (Plain(spellID, "number") and type(model) == "table" and type(model.Find) == "function") then
		return nil
	end
	local ok, entry, place = pcall(model.Find, spellID)
	if not ok or type(entry) ~= "table" or type(entry.ranks) ~= "table" or type(entry.parts) ~= "table" then
		return nil
	end
	local rank = entry.ranks[place]
	if type(rank) ~= "table" or rank.ct ~= -1 then
		return nil
	end
	for index, part in ipairs(entry.parts) do
		if type(part) == "table" and type(part.n) == "number" then
			local own = type(rank.n) == "table" and rank.n[index] or nil
			return type(own) == "number" and own or part.n
		end
	end
	return nil
end

local function Bar(name)
	local bar = _G[name]
	if bar == nil or ns.IsSecret(bar) or ns.Forbidden(bar) then
		return nil
	end
	return bar
end

local function Locked(bar)
	return InCombatLockdown() and ns.MaybeProtected(bar)
end

-- The marks of a bar, made once; nil while a protected bar is in a fight, or when the bar would not take them.
local function Marks(bar)
	local list = marks[bar]
	if list ~= nil then
		return list or nil
	end
	if Locked(bar) then
		return nil
	end
	marks[bar] = false
	list = {}
	for index = 1, POOL do
		local mark = bar:CreateTexture(nil, "OVERLAY", nil, SUBLEVEL)
		ns.Own[mark] = true
		mark:SetColorTexture(1, 1, 1, ALPHA)
		mark:Hide()
		list[index] = mark
	end
	marks[bar] = list
	return list
end

local function HideBar(bar)
	local list = marks[bar]
	if list then
		for _, mark in ipairs(list) do
			mark:Hide()
		end
	end
end

local function HideAll()
	S.spell, S.ticks, S.step = nil, nil, nil
	for bar in pairs(marks) do
		pcall(HideBar, bar)
	end
end

-- The marks of one bar for a channel of `length` milliseconds whose ticks come every `step` milliseconds.
local function Place(bar, length, step)
	local list = Marks(bar)
	local ok, width = pcall(bar.GetWidth, bar)
	if not list or Locked(bar) or not ok or not ns.Finite(width) or width <= 0 then
		HideBar(bar)
		return
	end
	local px = ns.Pixels(bar, 1)
	local used = 0
	for k = 1, POOL do
		local at = k * step
		if at >= length - 0.5 then
			break
		end
		local mark = list[k]
		local x = (1 - at / length) * width
		mark:ClearAllPoints()
		mark:SetPoint("TOP", bar, "TOPLEFT", x, 0)
		mark:SetPoint("BOTTOM", bar, "BOTTOMLEFT", x, 0)
		mark:SetWidth(px)
		mark:Show()
		used = k
	end
	for k = used + 1, POOL do
		list[k]:Hide()
	end
end

-- The player's channel now: its marks on both bars. fresh: a start, whose length gives the step between two ticks.
local function Draw(fresh)
	local name, _, _, startMs, endMs, _, _, spellID = UnitChannelInfo("player")
	if not (Plain(name, "string") and Plain(startMs, "number") and Plain(endMs, "number") and Plain(spellID, "number")) or endMs <= startMs then
		HideAll()
		return
	end
	if fresh or S.spell ~= spellID or not S.step then
		local ticks = TicksOf(spellID)
		if not ticks or ticks < 2 then
			HideAll()
			return
		end
		S.spell, S.ticks, S.step = spellID, ticks, (endMs - startMs) / ticks
		S.last = { name = name, ticks = ticks }
	end
	local length = endMs - startMs
	for _, key in ipairs(BARS) do
		local bar = Bar(key)
		if bar then
			Place(bar, length, S.step)
		end
	end
end

local function Heard(event)
	if event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		HideAll()
	else
		Draw(event == "UNIT_SPELLCAST_CHANNEL_START")
	end
end

local function OnEvent(_, event, unit)
	if not (Plain(unit, "string") and unit == "player") then
		return
	end
	if not ns.EachPart(KEY, PART, Heard, event) then
		pcall(HideAll)
	end
end

local function Frame()
	if S.frame == nil then
		local ok, frame = pcall(CreateFrame, "Frame")
		if not ok or type(frame) ~= "table" then
			S.frame = false
			return nil
		end
		ns.Own[frame] = true
		frame:SetScript("OnEvent", OnEvent)
		S.frame = frame
	end
	return S.frame or nil
end

local function Hear(on)
	local frame = Frame()
	if not frame then
		return
	end
	for _, event in ipairs(EVENTS) do
		if not on then
			pcall(frame.UnregisterEvent, frame, event)
		elseif not (frame.RegisterUnitEvent and pcall(frame.RegisterUnitEvent, frame, event, "player")) then
			pcall(frame.RegisterEvent, frame, event)
		end
	end
end

-- Called by Bars.lua at the end of a refresh of the cast bars: the events start or stop with the row, and a channel already running gets its marks.
function ns.CastTicksSync()
	local want = On() and Frame() ~= nil
	if want ~= S.on then
		S.on = want
		pcall(Hear, want)
		if not want then
			pcall(HideAll)
		end
	end
	if want then
		ns.EachPart(KEY, PART, Draw, false)
	end
end

ns.AddStatus(KEY, function()
	if not S.on then
		return {}
	end
	if S.last then
		return { ("Channel ticks: %s, %d ticks."):format(S.last.name, S.last.ticks) }
	end
	return { "Channel ticks: no channel with ticks seen yet." }
end)
