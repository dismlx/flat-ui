local _, ns = ...

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART = "Lost health trail"
local KINDS = { player = true, target = true, focus = true, pet = true, tot = true, party = true, partypet = true, boss = true }
local POLLED = { tot = true }
local TRAIL = { alpha = 0.45, every = 0.2, low = -8, high = 7 }
local WHITE = "Interface\\Buttons\\WHITE8X8"
local NOTE = "Unit frames: Lost health trail: the game refused the band on one frame, which shows no trail."

local IsSecret = ns.IsSecret
local trails = setmetatable({}, { __mode = "k" })
local poll = { frame = nil, on = false, wait = 0 }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Wanted(rec)
	return ns.Enabled(KEY) and not ns.IsStopped(KEY) and not ns.PartStopped(KEY, PART) and KINDS[rec.kind] == true and Opt("lostTrail") == true
		and Opt("flat") == true and not (Opt("lookLostColour") == true and Opt("backdrop") == true)
end

local function Guid(unit)
	if unit == nil or type(UnitGUID) ~= "function" then
		return nil
	end
	local ok, guid = pcall(UnitGUID, unit)
	if ok and not IsSecret(guid) and type(guid) == "string" then
		return guid
	end
	return nil
end

local function Glide(bar, value)
	local list = type(Enum) == "table" and not IsSecret(Enum) and Enum.StatusBarInterpolation or nil
	local how = type(list) == "table" and list.ExponentialEaseOut or nil
	if how ~= nil and pcall(bar.SetValue, bar, value, how) then
		return true
	end
	return pcall(bar.SetValue, bar, value)
end

local function Feed(t, jump)
	local unit = X.unitOf(t.rec)
	if unit == nil then
		return
	end
	local guid = Guid(unit)
	if guid ~= t.guid then
		jump = true
	end
	t.guid = guid
	local okMost, most = pcall(UnitHealthMax, unit)
	local ok, value = pcall(UnitHealth, unit)
	if not (okMost and ok) then
		return
	end
	pcall(t.ghost.SetMinMaxValues, t.ghost, 0, most)
	if jump then
		pcall(t.ghost.SetValue, t.ghost, value)
	else
		Glide(t.ghost, value)
	end
end

local function Layer(entry)
	local fill = entry.fill or ns.FillRegion(entry.bar)
	if fill == nil then
		return nil
	end
	local ok, layer, sub = pcall(fill.GetDrawLayer, fill)
	if not ok or IsSecret(layer) or type(layer) ~= "string" then
		return nil
	end
	sub = ns.Finite(sub) and sub or 0
	if sub <= TRAIL.low then
		return nil
	end
	return layer, math.min(TRAIL.high, sub - 1)
end

local function Make(rec, entry)
	local bar = entry.bar
	if bar == nil or ns.Forbidden(bar) or Layer(entry) == nil then
		return nil
	end
	local made, ghost = pcall(CreateFrame, "StatusBar", nil, bar)
	if not made or ghost == nil then
		return nil
	end
	ns.Own[ghost] = true
	ghost:SetAllPoints(bar)
	local ok, done = pcall(ghost.SetStatusBarTexture, ghost, WHITE)
	if not ok or (not IsSecret(done) and done == false) then
		return nil
	end
	pcall(ghost.SetStatusBarColor, ghost, 1, 1, 1, 0)
	ghost:SetMinMaxValues(0, 1)
	ghost:SetValue(0)
	local fill = ns.FillRegion(ghost)
	if fill == nil then
		return nil
	end
	local band = bar:CreateTexture()
	ns.Own[band] = true
	band:SetAllPoints(fill)
	band:Hide()
	return { rec = rec, entry = entry, bar = bar, ghost = ghost, band = band, on = false, poll = POLLED[rec.kind] == true }
end

local function Paint(t)
	local layer, sub = Layer(t.entry)
	if layer == nil then
		return false
	end
	if layer ~= t.layer or sub ~= t.sub then
		pcall(t.band.SetDrawLayer, t.band, layer, sub)
		t.layer, t.sub = layer, sub
	end
	local file = X.fillFile("health")
	if file == nil then
		file = ns.BarTexture()
	end
	file = file or false
	if t.file ~= file then
		if file and pcall(t.band.SetTexture, t.band, file) then
			t.band:SetVertexColor(1, 1, 1, TRAIL.alpha)
		else
			t.band:SetColorTexture(1, 1, 1, TRAIL.alpha)
			t.band:SetVertexColor(1, 1, 1, 1)
		end
		t.file = file
	end
	local orientation = X.ask(t.bar, "GetOrientation")
	if type(orientation) == "string" and orientation ~= t.orientation then
		pcall(t.ghost.SetOrientation, t.ghost, orientation)
		t.orientation = orientation
	end
	local reverse = X.ask(t.bar, "GetReverseFill")
	if type(reverse) == "boolean" and reverse ~= t.reverse then
		pcall(t.ghost.SetReverseFill, t.ghost, reverse)
		t.reverse = reverse
	end
	local cut = t.entry.cut
	local mask = cut ~= nil and cut.on and cut.mask or nil
	if t.mask ~= mask then
		if t.mask ~= nil then
			pcall(t.band.RemoveMaskTexture, t.band, t.mask)
		end
		t.mask = mask ~= nil and pcall(t.band.AddMaskTexture, t.band, mask) and mask or nil
	end
	return true
end

local function OnPoll(_, elapsed)
	poll.wait = poll.wait - (tonumber(elapsed) or 0)
	if poll.wait > 0 then
		return
	end
	poll.wait = TRAIL.every
	for _, t in pairs(trails) do
		if t.on and t.poll then
			X.run(PART, Feed, t)
		end
	end
end

local function Poll()
	local want = false
	for _, t in pairs(trails) do
		want = want or (t.on and t.poll)
	end
	if want == poll.on then
		return
	end
	if poll.frame == nil then
		if not want then
			return
		end
		poll.frame = CreateFrame("Frame")
		ns.Own[poll.frame] = true
	end
	poll.on = want
	poll.frame:SetScript("OnUpdate", want and OnPoll or nil)
end

local function Hide(t)
	if t.on then
		t.on = false
		t.band:Hide()
	end
end

local function Sync(rec, on)
	local t = trails[rec]
	local entry = rec.byRole and rec.byRole.health
	if not (on and rec.made and entry ~= nil and Wanted(rec)) then
		if t ~= nil then
			Hide(t)
			Poll()
		end
		return
	end
	if t == nil then
		if rec.trailRefused then
			return
		end
		if InCombatLockdown() then
			if not rec.trailQueued then
				rec.trailQueued = true
				ns.OutOfCombat(function()
					rec.trailQueued = nil
					X.run(PART, Sync, rec, X.active(rec))
				end)
			end
			return
		end
		t = Make(rec, entry)
		if t == nil then
			rec.trailRefused = true
			ns.Note(KEY, NOTE)
			return
		end
		trails[rec] = t
	end
	if not Paint(t) then
		Hide(t)
		Poll()
		return
	end
	if not t.on then
		t.on = true
		Feed(t, true)
		t.band:Show()
	end
	Poll()
end

local function Changed(rec)
	local t = trails[rec]
	if t == nil or not t.on then
		return
	end
	local guid = Guid(X.unitOf(rec))
	if guid == nil or guid ~= t.guid then
		Feed(t, true)
	end
end

local function Heard(unit)
	for _, t in pairs(trails) do
		if t.on and not t.poll and (IsSecret(unit) or X.unitOf(t.rec) == unit) then
			return true
		end
	end
	return false
end

local function OnHealth(unit)
	for _, t in pairs(trails) do
		if t.on and not t.poll and (IsSecret(unit) or X.unitOf(t.rec) == unit) then
			X.run(PART, Feed, t)
		end
	end
end

local function OnChanged(kinds)
	for rec in pairs(trails) do
		if kinds[rec.kind] then
			X.run(PART, Changed, rec)
		end
	end
end

local wasUnit = X.unitChanged
function X.unitChanged(rec)
	if wasUnit ~= nil then
		wasUnit(rec)
	end
	X.run(PART, Changed, rec)
end

ns.AddEvent(KEY, "UNIT_HEALTH", OnHealth, Heard)
ns.AddEvent(KEY, "UNIT_MAXHEALTH", OnHealth, Heard)
ns.AddEvent(KEY, "PLAYER_TARGET_CHANGED", function()
	OnChanged({ target = true, tot = true })
end)
ns.AddEvent(KEY, "PLAYER_FOCUS_CHANGED", function()
	OnChanged({ focus = true, tot = true })
end)

ns.AddStatus(KEY, function()
	if not ns.Enabled(KEY) or ns.IsStopped(KEY) or Opt("lostTrail") ~= true then
		return {}
	end
	local count = 0
	for _, t in pairs(trails) do
		if t.on then
			count = count + 1
		end
	end
	return { ("Lost health trail: on %d %s"):format(count, count == 1 and "frame" or "frames") }
end)

table.insert(X.after.apply, { part = PART, fn = Sync })
