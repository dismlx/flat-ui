local _, ns = ...

local KEY = "nameplates"
local PART, HOVER_PART = "plate colours", "mouseover border"
local HOOK = "CompactUnitFrame_UpdateHealthColor"
local MISSING = "Plate colours: the game's health colour call was not found, so nameplate health bars keep the game's colours."
local EVERY = 0.1

local recs = setmetatable({}, { __mode = "k" })
local hovered, ticking, missing, noted, applying = nil, false, false, false, nil

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Is(value, expected)
	return not ns.IsSecret(value) and value == expected
end

local function Call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, answer = pcall(fn, ...)
	if ok and not ns.IsSecret(answer) then
		return answer
	end
	return nil
end

local function Bar(frame)
	local bar = frame.healthBar
	if bar == nil then
		local container = frame.HealthBarsContainer
		bar = container ~= nil and not ns.Forbidden(container) and container.healthBar or nil
	end
	if bar ~= nil and not ns.Forbidden(bar) then
		return bar
	end
	return nil
end

local function Asked()
	return Opt("colours") == true or Opt("targetBar") == true or (Opt("threat") == true and Opt("threatBar") == true)
end

local function FromThreat(frame, own)
	local PT = ns.PlateThreat
	if PT == nil then
		return nil
	end
	local was = applying
	if own then
		applying = frame
	end
	local ok, state = pcall(PT.Read, frame)
	applying = was
	if ok and type(state) == "table" and state.tapped ~= true then
		return PT.Colour(state)
	end
	return nil
end

local function ReactionColour(unit)
	if Opt("colourPlayers") ~= "reaction" and Call(UnitIsPlayer, unit) ~= false then
		return nil
	end
	if ns.Get("general.reactionOwn") ~= true and Call(UnitIsTapDenied, unit) == true and Call(UnitPlayerControlled, unit) == false then
		return nil
	end
	if Call(UnitIsConnected, unit) == false then
		return nil
	end
	if Call(UnitIsDead, unit) == true and Call(UnitIsPlayer, unit) == false then
		return nil
	end
	return ns.ReactionColour(unit)
end

local function Styled(frame)
	return Opt("friendly") == true or not Is(frame.isFriend, true)
end

local function Want(frame, own)
	if missing or not ns.Enabled(KEY) or ns.PartStopped(KEY, PART) or not ns.IsPlate(frame) or not Styled(frame) then
		return nil
	end
	local unit = frame.unit
	if type(unit) ~= "string" or ns.IsSecret(unit) then
		return nil
	end
	if Opt("targetBar") == true and ns.PlateUnitFrame("target") == frame then
		return ns.Colour(KEY .. ".targetBarColour")
	end
	if Opt("threat") == true and Opt("threatBar") == true then
		local r, g, b = FromThreat(frame, own)
		if r then
			return r, g, b
		end
	end
	if Opt("colours") == true then
		return ReactionColour(unit)
	end
	return nil
end

local function Apply(frame, fromGame)
	local rec = recs[frame]
	if rec == nil then
		if not Asked() then
			return
		end
		rec = {}
		recs[frame] = rec
	end
	local r, g, b = Want(frame, true)
	local bar = Bar(frame)
	if bar == nil then
		return
	end
	if r ~= nil then
		if fromGame or not rec.painted then
			rec.game = { bar:GetStatusBarColor() }
		end
		rec.painted = true
		bar:SetStatusBarColor(r, g, b)
	elseif rec.painted then
		rec.painted = nil
		local game = rec.game
		if game ~= nil and not fromGame then
			bar:SetStatusBarColor(game[1], game[2], game[3], game[4])
		end
	end
end

function ns.PlateOverride(frame)
	if not Asked() then
		return false
	end
	return Want(frame, false) ~= nil
end

local function Run(frame, fromGame)
	if ns.IsStopped(KEY) or ns.PartStopped(KEY, PART) then
		pcall(Apply, frame, fromGame)
	elseif not ns.EachPart(KEY, PART, Apply, frame, fromGame) and ns.PartStopped(KEY, PART) then
		ns.EachPlate(Apply, false)
	end
end

local function OnColour(frame)
	if ns.IsPlate(frame) then
		Run(frame, true)
	end
end

local function ThreatSeen()
	local PT = ns.PlateThreat
	return PT ~= nil and type(PT.Seen) == "function" and PT.Seen() == true
end

local function Install()
	if not missing and Asked() and not ns.FollowGlobal(HOOK, OnColour) then
		missing = true
	end
	if missing and not noted and (Opt("colours") == true or Opt("targetBar") == true or ThreatSeen()) then
		noted = true
		ns.Note(KEY, MISSING)
	end
end

local function Reapply()
	Install()
	ns.EachPlate(Run, false)
end

local function OnThreat(frame)
	local PT = ns.PlateThreat
	if applying == frame or (PT ~= nil and type(PT.InColourCall) == "function" and PT.InColourCall()) or Opt("threatBar") ~= true then
		return
	end
	if ns.IsPlate(frame) then
		Run(frame, false)
	end
end

local function Unhover()
	local frame = hovered
	hovered = nil
	if frame ~= nil then
		ns.PlateBorder(frame, nil)
	end
end

local Watch

local function Tick()
	ticking = false
	if hovered ~= nil then
		if ns.PlateUnitFrame("mouseover") ~= hovered then
			Unhover()
		else
			Watch()
		end
	end
end

function Watch()
	if ticking or hovered == nil or type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		return
	end
	ticking = true
	C_Timer.After(EVERY, function()
		pcall(Tick)
	end)
end

local function OnMouseover()
	local frame = nil
	if Opt("hover") == true and ns.Enabled(KEY) and not ns.PartStopped(KEY, HOVER_PART) then
		frame = ns.PlateUnitFrame("mouseover")
	end
	if frame ~= hovered then
		Unhover()
		if frame ~= nil and ns.PlateBorder(frame, ns.Colour(KEY .. ".hoverColour")) then
			hovered = frame
		end
	end
	Watch()
end

local function Mouseover()
	if ns.IsStopped(KEY) or ns.PartStopped(KEY, HOVER_PART) then
		pcall(Unhover)
	elseif not ns.EachPart(KEY, HOVER_PART, OnMouseover) and ns.PartStopped(KEY, HOVER_PART) then
		pcall(Unhover)
	end
end

local extra = ns.PlateExtra
extra.show[#extra.show + 1] = function(frame)
	Install()
	Run(frame, false)
end
extra.leave[#extra.leave + 1] = function(frame)
	recs[frame] = nil
	if frame == hovered then
		pcall(Unhover)
	end
end
extra.refresh[#extra.refresh + 1] = function()
	Reapply()
	pcall(Unhover)
	Mouseover()
end

if ns.PlateThreat ~= nil then
	ns.PlateThreat.OnChange(OnThreat)
end
ns.AddEvent(KEY, "PLAYER_TARGET_CHANGED", function()
	if Opt("targetBar") == true then
		ns.EachPlate(Run, false)
	end
end)
ns.AddEvent(KEY, "UPDATE_MOUSEOVER_UNIT", Mouseover)

do
	local LINE_PART, LINE_ALPHA, LINE_LEVEL = "low health line", 0.7, 3
	local lines = setmetatable({}, { __mode = "k" })
	local owns = setmetatable({}, { __mode = "k" })
	local Mark

	local function LineOn()
		return ns.Enabled(KEY) and not ns.IsStopped(KEY) and not ns.PartStopped(KEY, LINE_PART) and Opt("lowHealth") == true and Opt("lowHealthLine") == true
	end

	local function Share()
		local at = Opt("lowHealthAt")
		at = ns.Finite(at) and math.max(0, math.min(100, at)) or 20
		return at / 100
	end

	local function Wants(frame)
		if not LineOn() or not ns.IsPlate(frame) then
			return false
		end
		local own = owns[frame]
		if (type(own) == "table" and own.styleOn == false) or Is(frame.showOnlyName, true) or Is(frame.widgetsOnlyMode, true) then
			return false
		end
		local unit = frame.unit
		if type(unit) ~= "string" or ns.IsSecret(unit) then
			return false
		end
		return Call(UnitCanAttack, "player", unit) == true
	end

	local function Spot(line)
		local holder, texture = line.holder, line.texture
		local ok, width = pcall(holder.GetWidth, holder)
		if not ok or not ns.Finite(width) or width <= 0 then
			return
		end
		local px = ns.Pixels(holder, 1)
		if not ns.Finite(px) or px <= 0 then
			return
		end
		local x = math.floor(width * Share() / px + 0.5) * px
		if line.x == x and line.px == px then
			return
		end
		line.x, line.px = x, px
		texture:ClearAllPoints()
		texture:SetPoint("TOPLEFT", holder, "TOPLEFT", x, 0)
		texture:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", x, 0)
		texture:SetWidth(px)
	end

	local function Locked(frame, bar)
		return InCombatLockdown() and (type(ns.MaybeProtected) ~= "function" or ns.MaybeProtected(frame) or ns.MaybeProtected(bar))
	end

	local function Wait(frame)
		local line = lines[frame]
		if line == nil then
			line = {}
			lines[frame] = line
		end
		if line.waiting then
			return
		end
		line.waiting = true
		ns.OutOfCombat(function()
			line.waiting = nil
			if lines[frame] == line and not ns.Forbidden(frame) then
				ns.EachPart(KEY, LINE_PART, Mark, frame)
			end
		end)
	end

	local function Make(frame)
		local line = lines[frame]
		if line and line.holder then
			return line
		end
		local bar = Bar(frame)
		if bar == nil then
			return nil
		end
		if Locked(frame, bar) then
			Wait(frame)
			return nil
		end
		line = line or {}
		lines[frame] = line
		local holder = CreateFrame("Frame", nil, bar)
		ns.Own[holder] = true
		holder:SetAllPoints(bar)
		local ok, level = pcall(bar.GetFrameLevel, bar)
		if ok and ns.Finite(level) then
			pcall(holder.SetFrameLevel, holder, level + LINE_LEVEL)
		end
		local texture = holder:CreateTexture(nil, "OVERLAY")
		ns.Own[texture] = true
		line.holder, line.texture = holder, texture
		holder:SetScript("OnSizeChanged", function()
			pcall(Spot, line)
		end)
		holder:Hide()
		return line
	end

	local function Still(line)
		if line and line.holder and line.shown then
			line.shown = nil
			line.holder:Hide()
		end
	end

	function Mark(frame)
		if ns.Forbidden(frame) then
			return
		end
		if not Wants(frame) then
			Still(lines[frame])
			return
		end
		local line = Make(frame)
		if not (line and line.holder) then
			return
		end
		local r, g, b = ns.Colour(KEY .. ".lowHealthColour")
		if line.r ~= r or line.g ~= g or line.b ~= b then
			line.r, line.g, line.b = r, g, b
			line.texture:SetColorTexture(r, g, b, LINE_ALPHA)
		end
		line.x = nil
		Spot(line)
		if not line.shown then
			line.shown = true
			line.holder:Show()
		end
	end

	local function StandDown()
		for _, line in pairs(lines) do
			pcall(Still, line)
		end
	end

	extra.show[#extra.show + 1] = function(frame, own)
		if type(own) == "table" then
			owns[frame] = own
		end
		if LineOn() or lines[frame] ~= nil then
			ns.EachPart(KEY, LINE_PART, Mark, frame)
		end
	end
	extra.layout[#extra.layout + 1] = function(frame, own)
		if type(own) == "table" then
			owns[frame] = own
		end
		if lines[frame] ~= nil then
			ns.EachPart(KEY, LINE_PART, Mark, frame)
		end
	end
	extra.leave[#extra.leave + 1] = function(frame)
		pcall(Still, lines[frame])
	end
	extra.refresh[#extra.refresh + 1] = function()
		if ns.IsStopped(KEY) or ns.PartStopped(KEY, LINE_PART) then
			pcall(StandDown)
			return
		end
		local seen = {}
		ns.EachPlate(function(frame)
			seen[frame] = true
			ns.EachPart(KEY, LINE_PART, Mark, frame)
		end)
		for frame, line in pairs(lines) do
			if not seen[frame] then
				pcall(Still, line)
			end
		end
	end
	ns.AddEvent(KEY, "UNIT_FACTION", function(unit)
		local frame = ns.PlateUnitFrame(unit)
		if frame ~= nil and (LineOn() or lines[frame] ~= nil) then
			ns.EachPart(KEY, LINE_PART, Mark, frame)
		end
	end, function(unit)
		return type(unit) == "string" and not ns.IsSecret(unit) and unit:find("^nameplate%d") ~= nil
	end)
end
