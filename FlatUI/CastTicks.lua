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
-- the value is the time left, the width the whole channel), so a tick k is at 1 - k * step / length of the width from the left (at k * step / length
-- on a bar that says it fills from the right, GetReverseFill, which the game never sets on a cast bar today), and a pushback, which ends the
-- channel sooner, moves the marks with the bar's new length (the step is the one the channel started with) and drops those past its end. The
-- width is read at each start and update (bar:GetWidth, plain on the player bar), so the marks follow the size of CastBarSize.lua.
-- The marks are textures of the addon's own on PlayerCastingBarFrame and OverlayPlayerCastingBarFrame (OVERLAY, under the spark), 15 a bar, one
-- screen pixel wide (ns.Pixels) and as tall as the bar, white at 0.6 opacity. Each hangs from a spacer of its own, an invisible texture whose left
-- edge is the bar's: the mark's middle is the spacer's right edge. Marks and spacers are made and anchored once, out of a fight (on a bar the
-- game may protect, ns.MaybeProtected of Movers.lua, never in one): as the row comes on, at every refresh of the cast bars and at the end of
-- each fight while some are still missing. While a channel runs only their widths change (SetWidth, the call Bars.lua makes on its latency zone
-- there in a fight), with Show, Hide and SetAlpha, so the marks show and follow a pushback in a fight too, on a bar the game protects then, such
-- as the one Edit Mode's Lock to player frame hangs on the player frame. A mark dims to a faint line (alpha 0.25 of the region, the colour keeps
-- its 0.6) once its tick has landed, the time since the channel's start (UnitChannelInfo, in the milliseconds of GetTime) read twenty times a
-- second by an OnUpdate of the file's own frame that runs only while a channel has marks; the next tick stays bright. They hide at the
-- channel's stop and when the row, the page or the part goes off. /flatui status names the last channel and its ticks, and counts the channels
-- whose marks could not be shown (none made yet, as after a reload in a fight). Nothing of the game is written or called but CreateTexture on
-- the two bars, as Bars.lua makes its own marks there.

local KEY, ROW, PART = "castbars", "castbars.ticks", "channel ticks"
local BARS = { "PlayerCastingBarFrame", "OverlayPlayerCastingBarFrame" }
-- POOL: the marks a bar has (Hellfire's 15 ticks need 14). ALPHA: their opacity. SUBLEVEL: their place in the OVERLAY layer, under the spark (2).
-- PASSED: the alpha of a mark whose tick has landed. EVERY: the seconds between two looks at the ticks that have landed.
local POOL, ALPHA, SUBLEVEL, PASSED, EVERY = 15, 0.6, 1, 0.25, 0.05
-- The channel events, and the end of a fight, when marks still missing are made.
local EVENTS = { "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP" }

-- sets[bar]: { marks, spacers (one each, the same index), used (the marks of the channel now), alpha (the alpha each was given) }, false when they
-- could not be made. S: frame (the file's own, false when it could not be made), on (the events are heard), spell, ticks, step and startMs (the
-- channel that has marks: its spell ID, its ticks, the milliseconds between two and its start), since (the seconds since the last look at the
-- ticks that landed), last (the name and ticks of the last channel with marks, for /flatui status), missed (the channels whose marks could not
-- be shown) and counted (the start of the channel last counted so).
local sets = setmetatable({}, { __mode = "k" })
local S = { frame = nil, on = false, spell = nil, ticks = nil, step = nil, startMs = nil, since = 0, last = nil, missed = 0, counted = nil }

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

-- The marks of a bar and their spacers, made and anchored once; nil while a protected bar is in a fight, or when the bar would not take them.
local function Marks(bar)
	local set = sets[bar]
	if set ~= nil then
		return set or nil
	end
	if InCombatLockdown() and ns.MaybeProtected(bar) then
		return nil
	end
	sets[bar] = false
	set = { marks = {}, spacers = {}, alpha = {}, used = 0 }
	for index = 1, POOL do
		local spacer = bar:CreateTexture(nil, "OVERLAY", nil, SUBLEVEL)
		ns.Own[spacer] = true
		spacer:SetColorTexture(0, 0, 0, 0)
		spacer:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
		spacer:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
		spacer:SetWidth(0.01)
		local mark = bar:CreateTexture(nil, "OVERLAY", nil, SUBLEVEL)
		ns.Own[mark] = true
		mark:SetColorTexture(1, 1, 1, ALPHA)
		mark:SetPoint("TOP", spacer, "TOPRIGHT", 0, 0)
		mark:SetPoint("BOTTOM", spacer, "BOTTOMRIGHT", 0, 0)
		mark:Hide()
		set.marks[index], set.spacers[index], set.alpha[index] = mark, spacer, 1
	end
	sets[bar] = set
	return set
end

-- The marks of both bars, where they are still missing and can be made now (out of a fight on a bar the game may protect).
local function MakeAll()
	for _, key in ipairs(BARS) do
		local bar = Bar(key)
		if bar and sets[bar] == nil then
			Marks(bar)
		end
	end
end

local function HideBar(bar)
	local set = sets[bar]
	if set then
		for _, mark in ipairs(set.marks) do
			mark:Hide()
		end
		set.used = 0
	end
end

local function Watching(on)
	local frame = S.frame
	if frame then
		S.since = 0
		frame:SetScript("OnUpdate", on or nil)
	end
end

local function HideAll()
	S.spell, S.ticks, S.step, S.startMs = nil, nil, nil, nil
	Watching(nil)
	for bar in pairs(sets) do
		pcall(HideBar, bar)
	end
end

-- Dims the marks whose tick has landed: the time since the channel's start against each tick's.
local function Dim()
	local now = GetTime()
	if not (ns.Finite(now) and S.startMs and S.step) then
		return
	end
	local elapsed = now * 1000 - S.startMs
	for _, set in pairs(sets) do
		if set and set.used > 0 then
			for k = 1, set.used do
				local alpha = elapsed >= k * S.step and PASSED or 1
				if set.alpha[k] ~= alpha then
					set.marks[k]:SetAlpha(alpha)
					set.alpha[k] = alpha
				end
			end
		end
	end
end

local function OnUpdate(_, elapsed)
	S.since = S.since + (ns.Finite(elapsed) and elapsed or EVERY)
	if S.since < EVERY then
		return
	end
	S.since = 0
	if not ns.EachPart(KEY, PART, Dim) then
		pcall(HideAll)
	end
end

-- The marks of one bar for a channel of `length` milliseconds whose ticks come every `step` milliseconds: only widths change, with no anchor.
-- True when placed, false when the bar has no marks yet, nil when it has no width.
local function Place(bar, length, step)
	local set = Marks(bar)
	if not set then
		return false
	end
	local ok, width = pcall(bar.GetWidth, bar)
	if not ok or not ns.Finite(width) or width <= 0 then
		HideBar(bar)
		return nil
	end
	local reverse = false
	if type(bar.GetReverseFill) == "function" then
		local read, value = pcall(bar.GetReverseFill, bar)
		reverse = read and Plain(value, "boolean") and value
	end
	local px = ns.Pixels(bar, 1)
	local used = 0
	for k = 1, POOL do
		local at = k * step
		if at >= length - 0.5 then
			break
		end
		local share = at / length
		local x = (reverse and share or 1 - share) * width
		set.spacers[k]:SetWidth(math.max(x, 0.01))
		local mark = set.marks[k]
		mark:SetWidth(px)
		mark:Show()
		used = k
	end
	for k = used + 1, POOL do
		set.marks[k]:Hide()
	end
	set.used = used
	return true
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
	S.startMs = startMs
	local length = endMs - startMs
	local placed, missing = false, false
	for _, key in ipairs(BARS) do
		local bar = Bar(key)
		if bar then
			local done = Place(bar, length, S.step)
			if done then
				placed = true
			elseif done == false then
				missing = true
			end
		end
	end
	-- A channel counts once, by its start, when a bar of the player had no marks for it.
	if missing and S.counted ~= startMs then
		S.counted, S.missed = startMs, S.missed + 1
	end
	if placed then
		-- Marks placed again, as after a pushback, take their alpha from the time now.
		Dim()
		Watching(OnUpdate)
	else
		Watching(nil)
	end
end

local function Heard(event)
	if event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		HideAll()
	elseif event == "PLAYER_REGEN_ENABLED" then
		MakeAll()
	else
		Draw(event == "UNIT_SPELLCAST_CHANNEL_START")
	end
end

local function OnEvent(_, event, unit)
	if event ~= "PLAYER_REGEN_ENABLED" and not (Plain(unit, "string") and unit == "player") then
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
	pcall(on and frame.RegisterEvent or frame.UnregisterEvent, frame, "PLAYER_REGEN_ENABLED")
end

-- Called by Bars.lua at the end of a refresh of the cast bars: the events start or stop with the row, the marks of both bars are made while
-- they can be (out of a fight), and a channel already running gets its marks.
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
		if not InCombatLockdown() then
			ns.EachPart(KEY, PART, MakeAll, "make")
		end
		ns.EachPart(KEY, PART, Draw, false)
	end
end

ns.AddStatus(KEY, function()
	if not S.on then
		return {}
	end
	local lines = {}
	if S.last then
		lines[1] = ("Channel ticks: %s, %d ticks."):format(S.last.name, S.last.ticks)
	else
		lines[1] = "Channel ticks: no channel with ticks seen yet."
	end
	if S.missed > 0 then
		lines[#lines + 1] = ("Channel ticks: channels with no marks, as the cast bar had none made yet (they are made out of a fight): %d."):format(S.missed)
	end
	return lines
end)
