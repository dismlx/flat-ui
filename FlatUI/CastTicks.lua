local _, ns = ...

local KEY, ROW, PART, COLOUR_ROW = "castbars", "castbars.ticks", "channel ticks", "castbars.ticksColour"
local BARS = { "PlayerCastingBarFrame", "OverlayPlayerCastingBarFrame" }
local POOL, ALPHA, SUBLEVEL, PASSED, EVERY = 15, 0.6, 1, 0.25, 0.05
local EVENTS = { "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP" }

local sets = setmetatable({}, { __mode = "k" })
local S = { frame = nil, on = false, spell = nil, ticks = nil, step = nil, startMs = nil, since = 0, last = nil, missed = 0, counted = nil }

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

local function On()
	return ns.Enabled(KEY) and ns.Get(ROW) == true and not ns.PartStopped(KEY, PART)
end

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

local function Tint(set)
	local hex = ns.Get(COLOUR_ROW)
	if set.hex == hex then
		return
	end
	local ok, r, g, b = pcall(ns.Colour, COLOUR_ROW)
	if not (ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b)) then
		r, g, b = 1, 1, 1
	end
	for _, mark in ipairs(set.marks) do
		mark:SetColorTexture(r, g, b, ALPHA)
	end
	set.hex = hex
end

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
	Tint(set)
	sets[bar] = set
	return set
end

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
	Tint(set)
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
	if missing and S.counted ~= startMs then
		S.counted, S.missed = startMs, S.missed + 1
	end
	if placed then
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
		Draw(false)
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
		for _, set in pairs(sets) do
			if set then
				pcall(Tint, set)
			end
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
