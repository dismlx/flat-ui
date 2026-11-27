local _, ns = ...

local KEY = "healermana"
local MOVER = "FlatUIHealerMana"
local BOX_W, BOX_H, BOX_X, BOX_Y = 158, 76, 420, -130
local PAD, GAP, INSET = 4, 2, 4
local STEP, TICK, TEST_TIME = 0.2, 0.5, 8
local MOST_ROWS = 40
local FONT = "GameFontHighlightSmall"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local TITLE = "Healer mana"
local MANA = 0
local HEALERS = { PRIEST = true, PALADIN = true, SHAMAN = true, DRUID = true }
local DIM = { 0.66, 0.68, 0.62 }
local TRACK = { 0.2, 0.2, 0.2, 0.5 }
local GREY = { 0.6, 0.6, 0.6 }
local LOW = { 0.85, 0.15, 0.1, 0.45 }
local READY = { 0.4, 0.9, 0.4 }
local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
local DRINK_SPELL, DRINK_ICON, CROP = 430, "Interface\\Icons\\INV_Drink_07", 0.08
local LINE_MISSING = "Healer mana: this client has no UnitPowerPercent, so the list stays hidden."
local LINE_LOW = "Healer mana: the game refused the red wash of Low mana at, so a bar may not turn red."
local LINE_RANGE = "Healer mana: the game refused to fade a bar by its answer about range, so healers out of range stay bright."
local FAR = 0.45
local FADE_IN, FADE_OUT = 0.15, 0.35
local HELP = { "/flatui healers - sample bars of the healer mana list for a few seconds" }
local SAMPLE = { { "Priest", "PRIEST", 82, false, false, 96 }, { "Druid", "DRUID", 47, true, false, 100 }, { "Shaman", "SHAMAN", 15, false, true, 93 } }
local SAMPLE_RAID = { SAMPLE[1], SAMPLE[2], SAMPLE[3], { "Paladin", "PALADIN", 91, false, false, 98 }, { "Priest", "PRIEST", 64, false, false, 95 },
	{ "Druid", "DRUID", 38, false, false, 97 }, { "Shaman", "SHAMAN", 73, false, false, 100 }, { "Paladin", "PALADIN", 22, false, false, 94 } }
local SAMPLE_DRINK, READY_TIME = 18, 4
local TITLE_FORMS = { TITLE .. " %d%%", "Healers %d%%", "%d%%" }
local READY_FORMS = { TITLE .. " %d%% · ready", "Healers %d%% · ready", "%d%% · ready" }
local PULSE_LOW, PULSE_STEP = 0.4, 0.2
local TIP_REST, CHAT_MOST = 10, 250
local TIP_TITLE = "Shift-click: put the healers' mana in chat."
local CHAT_FIGHT = "Flat UI: healer mana shows its numbers out of combat."

local IsSecret = ns.IsSecret
local H = { rows = {}, healers = {} }
ns.HealerMana = H

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

local function Number(key, default)
	local value = Opt(key)
	return ns.Finite(value) and value or default
end

local function Count(fn, most)
	local value = Ask(fn)
	if ns.Finite(value) and value > 0 then
		return math.min(math.floor(value), most)
	end
	return 0
end

local function After(seconds, fn)
	return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, seconds, fn)
end

local function LowCurve(at)
	if H.step ~= nil and H.stepAt == at then
		return H.step or nil
	end
	H.stepAt = at
	local ok, curve = pcall(function()
		local made = C_CurveUtil.CreateCurve()
		made:SetType(Enum.LuaCurveType.Step)
		made:AddPoint(0, 1)
		made:AddPoint(at / 100, 0)
		return made
	end)
	H.step = ok and curve or false
	H.lowRefused = not ok or nil
	return H.step or nil
end

local function AurasOpen()
	if Ask(InCombatLockdown) ~= false then
		return false
	end
	local secrets = C_Secrets
	local call = type(secrets) == "table" and not IsSecret(secrets) and secrets.ShouldAurasBeSecret or nil
	if type(call) ~= "function" then
		return true
	end
	return Ask(call) == false
end

local function DrinkName()
	if H.drinkName == nil then
		local spells = C_Spell
		local name = type(spells) == "table" and not IsSecret(spells) and Ask(spells.GetSpellName, DRINK_SPELL) or nil
		H.drinkName = type(name) == "string" and name ~= "" and name or false
	end
	return H.drinkName or nil
end

local function Drinking(unit)
	local name = DrinkName()
	local auras = C_UnitAuras
	if not name or type(auras) ~= "table" or IsSecret(auras) then
		return false
	end
	local aura = Ask(auras.GetAuraDataBySpellName, unit, name, "HELPFUL")
	if type(aura) ~= "table" then
		return false
	end
	local ok, ends = pcall(function()
		return aura.expirationTime
	end)
	if ok and not IsSecret(ends) and ns.Finite(ends) and ends > 0 then
		return true, ends
	end
	return true, nil
end

local function DrinkLeft(ends)
	local now = ends and Ask(GetTime)
	if not ns.Finite(now) or ends <= now then
		return nil
	end
	return math.ceil(ends - now)
end

local function Hundred()
	local constants = CurveConstants
	if type(constants) ~= "table" or IsSecret(constants) then
		return nil
	end
	local ok, curve = pcall(function()
		return constants.ScaleTo100
	end)
	if ok and not IsSecret(curve) and curve ~= nil then
		return curve
	end
	return nil
end

function H.Allowed()
	if Ask(IsInGroup) ~= true then
		return false
	elseif Opt("show") == "group" then
		return true
	end
	local ok, inside, kind = pcall(IsInInstance)
	return ok and not IsSecret(inside) and inside == true and not IsSecret(kind) and (kind == "party" or kind == "raid")
end

local function NoHealer(unit)
	if Ask(UnitIsUnit, unit, "player") == true then
		local ok, role = pcall(ns.PlayerRole)
		if not ok or IsSecret(role) then
			return false
		elseif role == "tank" then
			return true
		elseif role == "damage" and type(ns.PlayerTree) == "function" then
			local fine, tree = pcall(ns.PlayerTree)
			return fine and ns.Finite(tree) and true or false
		end
		return false
	end
	return Ask(UnitHasEffectivelyTankAura, unit) == true
end

function H.Healer(unit)
	local role = Ask(UnitGroupRolesAssigned, unit)
	if role == "HEALER" then
		return true, false
	elseif role == "TANK" or role == "DAMAGER" then
		return false, false
	end
	local class = Ask(UnitClassBase, unit)
	if type(class) ~= "string" or HEALERS[class] ~= true then
		return false, true
	elseif NoHealer(unit) then
		return false, true
	end
	return true, true
end

function H.Read()
	local byRole, byClass, roled = {}, {}, false
	local skip = Opt("mine") == false
	local function Member(unit)
		if Ask(UnitExists, unit) == true then
			local healer, guessed = H.Healer(unit)
			if healer then
				roled = roled or not guessed
				if not (skip and Ask(UnitIsUnit, unit, "player") == true) then
					local list = guessed and byClass or byRole
					list[#list + 1] = unit
				end
			end
		end
	end
	if Ask(IsInRaid) == true then
		for index = 1, Count(GetNumGroupMembers, 40) do
			Member("raid" .. index)
		end
	elseif Ask(IsInGroup) == true then
		Member("player")
		for index = 1, Count(GetNumSubgroupMembers, 4) do
			Member("party" .. index)
		end
	end
	return roled and byRole or byClass
end

local function ClassRGB(class)
	local colours = RAID_CLASS_COLORS
	if type(class) ~= "string" or type(colours) ~= "table" or IsSecret(colours) then
		return nil
	end
	local colour = colours[class]
	if type(colour) ~= "table" or IsSecret(colour) then
		return nil
	end
	local r, g, b = colour.r, colour.g, colour.b
	if ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		return r, g, b
	end
	return nil
end

local function SetName(text, unit)
	local ok, name = pcall(UnitName, unit)
	if ok and (IsSecret(name) or type(name) == "string") then
		text:SetText(name)
	else
		text:SetText("")
	end
end

local function Fades(frame)
	local ok, fadeIn, fadeOut = pcall(function()
		local come = frame:CreateAnimationGroup()
		local rise = come:CreateAnimation("Alpha")
		rise:SetFromAlpha(0)
		rise:SetToAlpha(1)
		rise:SetDuration(FADE_IN)
		local go = frame:CreateAnimationGroup()
		local fall = go:CreateAnimation("Alpha")
		fall:SetFromAlpha(1)
		fall:SetToAlpha(0)
		fall:SetDuration(FADE_OUT)
		pcall(go.SetToFinalAlpha, go, true)
		go:SetScript("OnFinished", function()
			frame:Hide()
			frame:SetAlpha(1)
		end)
		return come, go
	end)
	if ok then
		return fadeIn, fadeOut
	end
	return nil, nil
end

local function Glide(bar, value, now)
	local list = not now and type(Enum) == "table" and Enum.StatusBarInterpolation or nil
	local how = type(list) == "table" and list.ExponentialEaseOut or nil
	if how ~= nil and pcall(bar.SetValue, bar, value, how) then
		return true
	end
	return (pcall(bar.SetValue, bar, value))
end

function H.Showing(on, now)
	local frame, fadeIn, fadeOut = H.frame, H.fadeIn, H.fadeOut
	if not frame then
		return
	end
	if not on then
		for _, row in ipairs(H.rows) do
			row.who = nil
		end
		H.armed = nil
		H.UntipAll()
	end
	local fading = fadeOut ~= nil and fadeOut:IsPlaying()
	if on then
		if fading then
			pcall(fadeOut.Stop, fadeOut)
			frame:SetAlpha(1)
		end
		if not frame:IsShown() then
			frame:SetAlpha(1)
			frame:Show()
			if fadeIn and not now then
				pcall(fadeIn.Play, fadeIn)
			end
		end
		return
	end
	if fadeIn and fadeIn:IsPlaying() then
		pcall(fadeIn.Stop, fadeIn)
	end
	if now or not fadeOut or not frame:IsShown() then
		if fading then
			pcall(fadeOut.Stop, fadeOut)
		end
		frame:Hide()
		frame:SetAlpha(1)
	elseif not fading and not pcall(fadeOut.Play, fadeOut) then
		frame:Hide()
	end
end

function H.Frame()
	if H.frame then
		return H.frame
	end
	local frame = Own(CreateFrame("Frame", nil, UIParent))
	frame:SetFrameStrata("LOW")
	frame:SetSize(BOX_W, BOX_H)
	frame:Hide()
	H.frame = frame
	H.outline = ns.Outline(frame, frame, true)
	local title = ns.OwnText(frame, "OVERLAY", FONT)
	title:SetJustifyH("LEFT")
	title:SetWordWrap(false)
	title:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + INSET, -PAD)
	title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(PAD + INSET), -PAD)
	title:SetText(TITLE)
	H.title = title
	local strip = Own(CreateFrame("Frame", nil, frame))
	strip:SetPoint("TOPLEFT", title, "TOPLEFT", 0, 0)
	strip:SetPoint("TOPRIGHT", title, "TOPRIGHT", 0, 0)
	strip:SetHeight(14)
	strip:EnableMouse(true)
	H.strip = { bar = strip, Tip = H.TitleTip }
	strip:SetScript("OnEnter", function(self)
		ns.Try(KEY, H.TitleTip, H.strip, self)
	end)
	strip:SetScript("OnLeave", function()
		pcall(H.Untip, H.strip)
	end)
	strip:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" and Ask(IsShiftKeyDown) == true then
			ns.Try(KEY, H.Chat)
		end
	end)
	local more = ns.OwnText(frame, "OVERLAY", FONT)
	more:SetJustifyH("LEFT")
	more:SetWordWrap(false)
	more:Hide()
	H.more = more
	local hit = Own(CreateFrame("Frame", nil, frame))
	hit:SetAllPoints(more)
	hit:Hide()
	H.rest = { bar = hit, Tip = H.RestTip }
	H.Hover(hit, function(self)
		ns.Try(KEY, H.RestTip, H.rest, self)
	end, function()
		pcall(H.Untip, H.rest)
	end)
	H.fadeIn, H.fadeOut = Fades(frame)
	H.pulse = H.Pulse(title)
	return frame
end

function H.Pulse(title)
	local ok, group = pcall(function()
		local made = title:CreateAnimationGroup()
		for order = 1, 4 do
			local step = made:CreateAnimation("Alpha")
			local down = order % 2 == 1
			step:SetFromAlpha(down and 1 or PULSE_LOW)
			step:SetToAlpha(down and PULSE_LOW or 1)
			step:SetDuration(PULSE_STEP)
			step:SetOrder(order)
		end
		return made
	end)
	return ok and group or nil
end

function H.Row(index)
	local row = H.rows[index]
	if row then
		return row
	end
	local bar = Own(CreateFrame("StatusBar", nil, H.frame))
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(0)
	local track = Own(bar:CreateTexture(nil, "BACKGROUND", nil, -7))
	track:SetAllPoints(bar)
	track:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
	local share = ns.OwnText(bar, "OVERLAY", FONT)
	share:SetJustifyH("RIGHT")
	share:SetWordWrap(false)
	share:SetPoint("RIGHT", bar, "RIGHT", -INSET, 0)
	local name = ns.OwnText(bar, "OVERLAY", FONT)
	name:SetJustifyH("LEFT")
	name:SetWordWrap(false)
	name:SetPoint("LEFT", bar, "LEFT", INSET, 0)
	name:SetPoint("RIGHT", share, "LEFT", -INSET, 0)
	local low = Own(bar:CreateTexture(nil, "OVERLAY", nil, -8))
	low:SetAllPoints(bar)
	low:SetColorTexture(LOW[1], LOW[2], LOW[3], LOW[4])
	low:SetAlpha(0)
	local drink = Own(bar:CreateTexture(nil, "OVERLAY", nil, 1))
	drink:SetTexture(DRINK_ICON)
	drink:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
	drink:SetPoint("RIGHT", share, "LEFT", -2, 0)
	drink:Hide()
	row = { bar = bar, track = track, name = name, share = share, low = low, drink = drink, drinking = false, Tip = H.Tip }
	H.rows[index] = row
	H.Hover(bar, function(self)
		ns.Try(KEY, H.Tip, row, self)
	end, function()
		pcall(H.Untip, row)
	end)
	return row
end

function H.Hover(region, enter, leave)
	if type(region.SetMouseMotionEnabled) ~= "function" or type(region.SetMouseClickEnabled) ~= "function" then
		return false
	end
	if not (pcall(region.SetMouseMotionEnabled, region, true) and pcall(region.SetMouseClickEnabled, region, false)) then
		pcall(region.EnableMouse, region, false)
		return false
	end
	region:SetScript("OnEnter", enter)
	region:SetScript("OnLeave", leave)
	return true
end

function H.Untip(holder)
	if type(holder) ~= "table" or not holder.tipped then
		return
	end
	holder.tipped = nil
	local tip = GameTooltip
	if not ns.Forbidden(tip) then
		local ok, owned = pcall(tip.IsOwned, tip, holder.bar)
		if ok and owned == true then
			tip:Hide()
		end
	end
end

function H.Retip(holder)
	if type(holder) ~= "table" or not holder.tipped then
		return
	end
	local tip = GameTooltip
	local ok, owned = false, false
	if not ns.Forbidden(tip) then
		ok, owned = pcall(tip.IsOwned, tip, holder.bar)
	end
	if ok and owned == true then
		holder.Tip(holder, holder.bar)
	else
		holder.tipped = nil
	end
end

function H.UntipAll()
	for _, row in ipairs(H.rows) do
		pcall(H.Untip, row)
	end
	pcall(H.Untip, H.rest)
	pcall(H.Untip, H.strip)
end

local function Named(value)
	return IsSecret(value) or (type(value) == "string" and value ~= "")
end

function H.Colour(unit, sample)
	local r, g, b
	if sample then
		r, g, b = ClassRGB(sample[2])
	else
		r, g, b = ns.ClassColourOf(unit)
	end
	if not r then
		r, g, b = GREY[1], GREY[2], GREY[3]
	end
	return r, g, b
end

function H.TipName(tip, unit, sample, r, g, b)
	if sample then
		return pcall(tip.AddLine, tip, sample[1], r, g, b)
	end
	local ok, name = pcall(UnitName, unit)
	return ok and Named(name) and pcall(tip.AddLine, tip, name, r, g, b)
end

function H.Tip(row, owner)
	local tip, sample, unit = GameTooltip, row.sample, row.unit
	if ns.Forbidden(tip) or not (sample or unit) then
		return
	end
	tip:SetOwner(owner, "ANCHOR_LEFT")
	local r, g, b = H.Colour(unit, sample)
	if not H.TipName(tip, unit, sample, r, g, b) then
		tip:AddLine("Healer", r, g, b)
	end
	local read = row.read
	if row.word then
		tip:AddLine(row.word, 1, 1, 1)
	elseif read then
		tip:AddLine(("Mana %d%%"):format(math.floor(read + 0.5)), 1, 1, 1)
	elseif row.secret then
		tip:AddLine("Mana hidden in a fight", DIM[1], DIM[2], DIM[3])
	end
	if row.cup and row.left then
		tip:AddLine(("Drinking: %d %s left"):format(row.left, row.left == 1 and "second" or "seconds"), 1, 1, 1)
	elseif row.cup then
		tip:AddLine("Drinking", 1, 1, 1)
	end
	local low, ready = Number("lowAt", 30), Number("readyAt", 90)
	if read and not row.word and low > 0 and read < low then
		tip:AddLine(("Under Low mana at (%d%%)"):format(low), LOW[1] + (1 - LOW[1]) * 0.35, LOW[2] + (1 - LOW[2]) * 0.35, LOW[3] + (1 - LOW[3]) * 0.35)
	elseif read and not row.word and ready > 0 and read < ready then
		tip:AddLine(("Under Ready at (%d%%)"):format(ready), DIM[1], DIM[2], DIM[3])
	end
	if sample then
		tip:AddLine("Sample", DIM[1], DIM[2], DIM[3])
	end
	tip:Show()
	row.tipped = true
end

function H.State(unit)
	if Ask(UnitIsConnected, unit) == false then
		return nil, "Offline"
	elseif Ask(UnitIsDeadOrGhost, unit) == true then
		return nil, "Dead"
	end
	local ok, value = pcall(UnitPowerPercent, unit, MANA, false, Hundred())
	if ok and not IsSecret(value) and ns.Finite(value) then
		return value, nil
	end
	return nil, nil
end

function H.RestTip(holder, owner)
	local tip, list, from = GameTooltip, H.restList, H.restFrom
	if ns.Forbidden(tip) or type(list) ~= "table" or not from or from > #list then
		return
	end
	tip:SetOwner(owner, "ANCHOR_LEFT")
	local total, phase = #list - from + 1, H.restSampled and H.SamplePhase() or nil
	tip:AddLine(("%d more %s"):format(total, total == 1 and "healer" or "healers"), 1, 1, 1)
	for index = from, math.min(#list, from + TIP_REST - 1) do
		local entry = list[index]
		local unit, sample = not phase and entry or nil, phase and entry or nil
		local r, g, b = H.Colour(unit, sample)
		local right, name, named
		if sample then
			right, name = ("%d%%"):format(H.SampleShare(sample, phase)), sample[1]
			named = type(name) == "string"
		else
			local share, word = H.State(unit)
			right = word or (share and ("%d%%"):format(math.floor(share + 0.5))) or "hidden in a fight"
			local ok, said = pcall(UnitName, unit)
			if ok and Named(said) then
				name, named = said, true
			end
		end
		if not (named and pcall(tip.AddDoubleLine, tip, name, right, r, g, b, 1, 1, 1)) then
			tip:AddDoubleLine("Healer", right, r, g, b, 1, 1, 1)
		end
	end
	if total > TIP_REST then
		tip:AddLine(("and %d more"):format(total - TIP_REST), DIM[1], DIM[2], DIM[3])
	end
	if phase then
		tip:AddLine("Sample", DIM[1], DIM[2], DIM[3])
	end
	tip:Show()
	holder.tipped = true
end

function H.TitleTip(holder, owner)
	local tip = GameTooltip
	if ns.Forbidden(tip) then
		return
	end
	tip:SetOwner(owner, "ANCHOR_LEFT")
	tip:AddLine(TIP_TITLE, 1, 1, 1, true)
	tip:Show()
	holder.tipped = true
end

function H.ChatPart(unit)
	local name = Ask(UnitName, unit)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	local share, word = H.State(unit)
	if word then
		return name .. " " .. word
	elseif not share then
		return nil
	end
	local part = ("%s %d%%"):format(name, math.floor(share + 0.5))
	if Opt("drinking") ~= false and AurasOpen() then
		local cup, ends = Drinking(unit)
		local left = cup and DrinkLeft(ends) or nil
		if left then
			part = part .. (" (drinking %ds)"):format(left)
		elseif cup then
			part = part .. " (drinking)"
		end
	end
	return part
end

function H.Chat()
	local samples = H.Sampling() and H.Samples() or nil
	if not samples and Ask(InCombatLockdown) ~= false then
		print(CHAT_FIGHT)
		return
	end
	local parts = {}
	if samples then
		local phase = H.SamplePhase()
		for _, sample in ipairs(samples) do
			local part = ("%s %d%%"):format(sample[1], H.SampleShare(sample, phase))
			if Opt("drinking") ~= false and sample[4] == true and phase ~= "ready" then
				part = part .. (" (drinking %ds)"):format(phase)
			end
			parts[#parts + 1] = part
		end
	else
		for _, unit in ipairs(H.healers) do
			parts[#parts + 1] = H.ChatPart(unit)
		end
	end
	if #parts == 0 or type(ns.PutInChat) ~= "function" then
		return
	end
	local line = TITLE .. ": " .. parts[1]
	for index = 2, #parts do
		if #line + #parts[index] + 2 > CHAT_MOST then
			break
		end
		line = line .. ", " .. parts[index]
	end
	ns.PutInChat(line)
end

function H.Cup(row, on)
	if row.drinking == on then
		return
	end
	row.drinking = on
	row.drink:SetShown(on)
	row.name:ClearAllPoints()
	row.name:SetPoint("LEFT", row.bar, "LEFT", INSET, 0)
	row.name:SetPoint("RIGHT", on and row.drink or row.share, "LEFT", -INSET, 0)
end

function H.Wash(row, unit, sample, word)
	local at = Number("lowAt", 30)
	if at <= 0 or word then
		row.low:SetAlpha(0)
		return
	end
	if sample then
		row.low:SetAlpha(H.SampleShare(sample, H.SamplePhase()) < at and 1 or 0)
		return
	end
	local curve = LowCurve(at)
	if not curve then
		row.low:SetAlpha(0)
	elseif not pcall(function()
		row.low:SetAlpha(UnitPowerPercent(unit, MANA, false, curve))
	end) then
		row.low:SetAlpha(0)
		H.lowRefused = true
	end
end

function H.Range(row, unit, sample, word)
	local bar = row.bar
	if Opt("range") == false or word then
		bar:SetAlpha(1)
		return
	end
	if sample then
		bar:SetAlpha(sample[5] == true and H.SamplePhase() ~= "ready" and FAR or 1)
		return
	end
	if Ask(UnitIsUnit, unit, "player") ~= false or type(UnitInRange) ~= "function" or type(bar.SetAlphaFromBoolean) ~= "function" then
		bar:SetAlpha(1)
		return
	end
	local ok, inRange = pcall(UnitInRange, unit)
	if not ok or not (IsSecret(inRange) or type(inRange) == "boolean") then
		bar:SetAlpha(1)
	elseif pcall(bar.SetAlphaFromBoolean, bar, inRange, 1, FAR) then
		H.rangeRefused = nil
	else
		bar:SetAlpha(1)
		H.rangeRefused = true
	end
end

local function Paint(row, file, text)
	if row.file ~= file then
		local ok, done = pcall(row.bar.SetStatusBarTexture, row.bar, file)
		if not ok or (not IsSecret(done) and done == false) then
			pcall(row.bar.SetStatusBarTexture, row.bar, WHITE)
		end
		row.file = file
	end
	row.name:SetTextHeight(text)
	row.share:SetTextHeight(text)
	row.drink:SetSize(text, text)
end

function H.Layout(n, extra)
	local width, height = Number("barWidth", 150), Number("barHeight", 16)
	local text = math.max(7, math.min(14, height - 4))
	local file = ns.BarTexture(Opt("barTexture")) or WHITE
	for index = 1, n do
		Paint(H.Row(index), file, text)
	end
	H.title:SetTextHeight(text)
	H.strip.bar:SetHeight(text + 2)
	H.more:SetTextHeight(text)
	local key = ("%s:%s:%s:%s"):format(n, width, height, extra and 1 or 0)
	if H.laid == key then
		return
	end
	H.laid = key
	H.titled = nil
	local top = PAD + text + 2 + GAP
	for index = 1, n do
		local bar = H.rows[index].bar
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", H.frame, "TOPLEFT", PAD, -(top + (index - 1) * (height + GAP)))
		bar:SetSize(width, height)
	end
	local tall = top + n * height + (n - 1) * GAP + PAD
	local more = H.more
	more:ClearAllPoints()
	if extra then
		more:SetPoint("TOPLEFT", H.frame, "TOPLEFT", PAD + INSET, -(top + n * (height + GAP)))
		more:SetPoint("TOPRIGHT", H.frame, "TOPRIGHT", -(PAD + INSET), -(top + n * (height + GAP)))
		tall = tall + GAP + text
	else
		more:Hide()
	end
	H.frame:SetSize(width + 2 * PAD, tall)
end

function H.Rest(list, n, samples)
	H.restList, H.restFrom, H.restSampled = list, n + 1, samples or nil
	local hidden, least = 0, nil
	for index = n + 1, #list do
		hidden = hidden + 1
		local share
		if samples then
			share = H.SampleShare(list[index], H.SamplePhase())
		elseif Ask(UnitIsConnected, list[index]) == false or Ask(UnitIsDeadOrGhost, list[index]) == true then
			H.away = true
		else
			local ok, value = pcall(UnitPowerPercent, list[index], MANA, false, Hundred())
			if ok and not IsSecret(value) and ns.Finite(value) then
				share = value
			else
				H.hidden = true
			end
		end
		if share then
			H.sum, H.count = (H.sum or 0) + share, (H.count or 0) + 1
			H.least = math.min(H.least or share, share)
			least = math.min(least or share, share)
		end
	end
	return hidden, least
end

function H.More(hidden, least)
	local more = H.more
	if not more then
		return
	elseif hidden < 1 then
		more:Hide()
		pcall(H.Untip, H.rest)
		H.rest.bar:Hide()
		return
	end
	local at = Number("lowAt", 30)
	if least then
		local value = math.floor(least + 0.5)
		more:SetText(("+%d more, lowest %d%%"):format(hidden, value))
	else
		more:SetText(("+%d more"):format(hidden))
	end
	if least and at > 0 and least < at then
		more:SetTextColor(LOW[1] + (1 - LOW[1]) * 0.35, LOW[2] + (1 - LOW[2]) * 0.35, LOW[3] + (1 - LOW[3]) * 0.35, 1)
	else
		more:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
	end
	more:Show()
	H.rest.bar:Show()
	H.Retip(H.rest)
end

function H.SamplePhase()
	local now = H.sampleStart and Ask(GetTime)
	if not ns.Finite(now) or now < H.sampleStart then
		return SAMPLE_DRINK
	end
	local into = math.floor(now - H.sampleStart) % (SAMPLE_DRINK + READY_TIME)
	if into >= SAMPLE_DRINK then
		return "ready"
	end
	return SAMPLE_DRINK - into
end

function H.SampleShare(sample, phase)
	if phase == "ready" then
		return math.min(100, math.max(sample[6], Number("readyAt", 90)))
	end
	return sample[3]
end

function H.Samples()
	local mode = ns.TestMode
	local group = mode and mode.IsOn() == true and mode.Group() or nil
	if type(group) == "string" and group:find("^raid") then
		return SAMPLE_RAID
	end
	return SAMPLE
end

function H.Fill(row, unit, sample)
	row.unit, row.sample, row.read, row.word, row.secret, row.cup, row.left = unit, sample, nil, nil, nil, false, nil
	H.FillRow(row, unit, sample)
	H.Retip(row)
end

function H.FillRow(row, unit, sample)
	local r, g, b = H.Colour(unit, sample)
	row.bar:SetStatusBarColor(r, g, b, 1)
	row.bar:Show()
	local drinks = Opt("drinking") ~= false
	if sample then
		local phase = H.SamplePhase()
		local value = H.SampleShare(sample, phase)
		local cup = drinks and sample[4] == true and phase ~= "ready"
		row.read, row.cup, row.left = value, cup, cup and phase or nil
		row.name:SetText(sample[1])
		row.bar:SetValue(value)
		row.who = nil
		H.sum, H.count = (H.sum or 0) + value, (H.count or 0) + 1
		H.least = math.min(H.least or value, value)
		if cup then
			row.share:SetText(("%ds %d%%"):format(phase, value))
		else
			row.share:SetText(("%d%%"):format(value))
		end
		H.Wash(row, nil, sample)
		H.Cup(row, cup)
		H.Range(row, nil, sample)
		return
	end
	SetName(row.name, unit)
	local word = nil
	if Ask(UnitIsConnected, unit) == false then
		word = "Offline"
	elseif Ask(UnitIsDeadOrGhost, unit) == true then
		word = "Dead"
	end
	H.Wash(row, unit, nil, word)
	H.Range(row, unit, nil, word)
	if word then
		row.word = word
		row.bar:SetValue(0)
		row.who = nil
		row.share:SetText(word)
		H.Cup(row, false)
		H.away = true
		return
	end
	local cup, ends = false, nil
	if drinks and AurasOpen() then
		cup, ends = Drinking(unit)
	end
	H.Cup(row, cup)
	local left = cup and DrinkLeft(ends) or nil
	local ok, share = pcall(UnitPowerPercent, unit, MANA, false, Hundred())
	local jump = row.who ~= unit or not H.frame:IsShown()
	row.who = unit
	if not ok or not Glide(row.bar, share, jump) then
		row.bar:SetValue(0)
	end
	row.cup, row.left = cup, left
	if ok and not IsSecret(share) and ns.Finite(share) then
		row.read = share
		H.sum, H.count = (H.sum or 0) + share, (H.count or 0) + 1
		H.least = math.min(H.least or share, share)
	else
		row.secret = ok and IsSecret(share) or nil
		H.hidden = true
	end
	local written
	if left then
		written = ok and pcall(row.share.SetFormattedText, row.share, "%ds %.0f%%", left, share)
	else
		written = ok and pcall(row.share.SetFormattedText, row.share, cup and "Drinking %.0f%%" or "%.0f%%", share)
	end
	if not written then
		row.share:SetText(left and ("%ds"):format(left) or (cup and "Drinking" or ""))
	end
end

function H.Ready(average)
	local at = Number("readyAt", 90)
	if average == nil or at <= 0 or H.away or Ask(InCombatLockdown) ~= false or not ns.Finite(H.least) then
		return false
	end
	if H.Sampling() then
		if H.SamplePhase() ~= "ready" or H.least < at then
			return false
		end
		local sound, mode = ns.SOUNDS[KITS[Opt("readySound")] or 0], ns.TestMode
		if sound and mode and mode.IsOn() == true and mode.Sound("healermana.ready") then
			ns.PlayKit(sound[1], KEY)
		end
		return true
	end
	if H.least < at then
		H.armed = true
		return false
	end
	if H.armed then
		H.armed = nil
		local sound = ns.SOUNDS[KITS[Opt("readySound")] or 0]
		if sound then
			ns.PlayKit(sound[1], KEY)
		end
	end
	return true
end

local function TitleCut(title)
	local room = Number("barWidth", 150) - 2 * INSET
	local ok, width = pcall(title.GetUnboundedStringWidth, title)
	if ok and not IsSecret(width) and ns.Finite(width) and width > 0 then
		return width > room + 0.5
	end
	if type(title.IsTruncated) == "function" then
		local asked, cut = pcall(title.IsTruncated, title)
		return asked and not IsSecret(cut) and cut == true
	end
	return false
end

function H.Title()
	local count, average = H.count or 0, nil
	if count > 0 and not H.hidden then
		average = math.floor((H.sum or 0) / count + 0.5)
	end
	local at = Number("lowAt", 30)
	local low = average ~= nil and at > 0 and average < at
	local ready = H.Ready(average)
	local key = average and ("%d:%s:%s"):format(average, tostring(low), tostring(ready)) or "plain"
	local forms = ready and READY_FORMS or (average and TITLE_FORMS or nil)
	if H.titled == key and not (forms and (H.form or 1) < #forms and TitleCut(H.title)) then
		return
	end
	local form = H.titled == key and (H.form or 1) + 1 or 1
	H.titled = key
	local colour = ready and READY or low and LOW or DIM
	H.title:SetTextColor(colour[1], colour[2], colour[3], 1)
	if forms then
		H.title:SetFormattedText(forms[form], average)
		while form < #forms and TitleCut(H.title) do
			form = form + 1
			H.title:SetFormattedText(forms[form], average)
		end
	else
		H.title:SetText(TITLE)
	end
	H.form = form
	if ready and H.readyShown == false and H.pulse then
		pcall(H.pulse.Stop, H.pulse)
		pcall(H.pulse.Play, H.pulse)
	end
	H.readyShown = ready
end

local function Average()
	H.sum, H.count, H.hidden, H.least, H.away = 0, 0, false, nil, false
end

function H.Sampling()
	local mode = ns.TestMode
	return H.sample ~= nil or (mode ~= nil and mode.IsOn() == true)
end

function H.Place()
	local corner = Opt("grow") == "up" and "BOTTOMLEFT" or "TOPLEFT"
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(MOVER, corner)
	end
	local key = (x and ("%.2f:%.2f"):format(x, y) or "start") .. ":" .. corner
	if H.placed == key then
		return
	end
	H.placed = key
	local frame = H.frame
	frame:ClearAllPoints()
	if x then
		frame:SetPoint(corner, UIParent, "BOTTOMLEFT", x, y)
	elseif corner == "BOTTOMLEFT" then
		frame:SetPoint(corner, UIParent, "CENTER", BOX_X - BOX_W / 2, BOX_Y - BOX_H / 2)
	else
		frame:SetPoint(corner, UIParent, "CENTER", BOX_X - BOX_W / 2, BOX_Y + BOX_H / 2)
	end
end

function H.Draw()
	local samples = H.Sampling() and H.Samples() or nil
	local list = samples or H.healers
	local n = math.min(#list, Number("rows", 5), MOST_ROWS)
	if n < 1 then
		H.Showing(false)
		H.Tick(false)
		H.readyShown = nil
		return
	end
	H.Frame()
	H.Layout(n, #list > n)
	Average()
	for index = 1, n do
		if samples then
			H.Fill(H.rows[index], nil, samples[index])
		else
			H.Fill(H.rows[index], list[index])
		end
	end
	H.More(H.Rest(list, n, samples ~= nil))
	H.Title()
	for index = n + 1, #H.rows do
		pcall(H.Untip, H.rows[index])
		H.rows[index].bar:Hide()
		H.rows[index].who = nil
	end
	H.Place()
	H.Showing(true)
	H.Tick(not samples)
end

function H.Update()
	H.pending = nil
	local on = ns.Enabled(KEY) and type(UnitPowerPercent) == "function"
	local sampling = H.Sampling()
	if on and not sampling and H.Allowed() then
		H.healers = H.Read()
	else
		H.healers = {}
	end
	if on or sampling then
		H.Draw()
	elseif H.frame then
		H.Showing(false)
		H.Tick(false)
	end
end

function H.Soon()
	if H.pending then
		return
	end
	H.pending = true
	if not After(STEP, function()
		ns.Try(KEY, H.Update)
	end) then
		H.Update()
	end
end

local function Step()
	if H.frame and #H.healers > 0 and not H.Sampling() then
		local n = math.min(#H.healers, Number("rows", 5), MOST_ROWS)
		Average()
		for index = 1, math.min(n, #H.rows) do
			H.Fill(H.rows[index], H.healers[index])
		end
		H.More(H.Rest(H.healers, n, false))
		H.Title()
	end
end

function H.Tick(on)
	if on and not H.ticker then
		local token = {}
		H.ticker = token
		if type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
			local ok, ticker = pcall(C_Timer.NewTicker, TICK, function()
				ns.Try(KEY, Step)
			end)
			token.handle = ok and ticker or nil
		end
		if not token.handle then
			local function Again()
				if H.ticker == token then
					ns.Try(KEY, Step)
					if H.ticker == token and not After(TICK, Again) then
						H.ticker = nil
					end
				end
			end
			if not After(TICK, Again) then
				H.ticker = nil
			end
		end
	elseif not on and H.ticker then
		local handle = H.ticker.handle
		H.ticker = nil
		if handle and type(handle.Cancel) == "function" then
			pcall(handle.Cancel, handle)
		end
	end
end

function H.Refresh()
	H.pending, H.placed, H.laid, H.armed, H.readyShown = nil, nil, nil, nil, nil
	if not ns.Enabled(KEY) then
		H.sample, H.healers = nil, {}
		H.Tick(false)
		H.Showing(false, true)
		return
	end
	H.Update()
end

function H.Slash()
	if not ns.Enabled(KEY) then
		print("Healer mana: turn on Show healer mana first.")
		return
	end
	if Ask(InCombatLockdown) ~= false then
		print("Healer mana: the sample shows out of combat.")
		return
	end
	local token = {}
	H.sample = token
	ns.Try(KEY, H.Update)
	local function Done()
		if H.sample == token then
			H.sample = nil
			ns.Try(KEY, H.Update)
		end
	end
	if not After(TEST_TIME, Done) then
		Done()
	end
end

function H.Status()
	local lines = {}
	if ns.Enabled(KEY) and type(UnitPowerPercent) ~= "function" then
		lines[#lines + 1] = LINE_MISSING
	end
	if ns.Enabled(KEY) and H.lowRefused and Number("lowAt", 30) > 0 then
		lines[#lines + 1] = LINE_LOW
	end
	if ns.Enabled(KEY) and H.rangeRefused and Opt("range") ~= false then
		lines[#lines + 1] = LINE_RANGE
	end
	return lines
end

function ns.HealerManaShown()
	return ns.Enabled(KEY)
end

function ns.HealerManaMoved()
	H.placed = nil
	if H.frame and ns.Enabled(KEY) then
		ns.Try(KEY, H.Place)
	end
end

local function Soon()
	H.Soon()
end

ns.Register(KEY, {
	label = "Healer mana",
	counted = false,
	Start = H.Refresh,
	Refresh = H.Refresh,
	Resized = H.Refresh,
	Status = H.Status,
	events = { GROUP_ROSTER_UPDATE = Soon, PLAYER_ROLES_ASSIGNED = Soon, PLAYER_ENTERING_WORLD = Soon, ZONE_CHANGED_NEW_AREA = Soon,
		PLAYER_TALENT_UPDATE = Soon, CHARACTER_POINTS_CHANGED = Soon, PLAYER_REGEN_ENABLED = Soon },
	slash = { healers = H.Slash },
	help = HELP,
})

if ns.TestMode then
	ns.TestMode.Register("healermana", {
		module = KEY,
		label = "Healer mana",
		refresh = true,
		every = 1,
		Start = function()
			H.sampleStart = Ask(GetTime)
		end,
		Stop = function()
			H.sampleStart = nil
		end,
		Tick = function()
			if Ask(InCombatLockdown) == false then
				H.Update()
			end
		end,
	})
end
