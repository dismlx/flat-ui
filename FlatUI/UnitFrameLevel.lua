local ADDON_NAME, ns = ...

-- The level on the portrait of the player, target and focus frames, for the level position On the portrait. The other positions, the colour and the
-- size of the level are in UnitFrames.lua, in the functions that lay out and write the name row; a frame that shows no picture of Flat UI's has its
-- level at the end of the row there. On a round picture the number moves in from the corner of the square onto the circle. This file adds its work after
-- the steps of that file through ns.UnitFrameExtra: a part that stops on errors counts as off here, and every function can run twice with the same result.
-- As you level (PLAYER_LEVEL_UP, read 0.2 seconds later, once the row has written the new level from UnitEffectiveLevel), the level of the player frame
-- pops: the number in the name row, and on the portrait with On the portrait, grows to 180% and settles back over 0.45 seconds while it fades up from
-- 40%, from its own end of the row (the right with End of the name row, the left with Before the name) or the portrait's corner, as the experience bar
-- lights in gold (Hud.lua). It is a Scale and an Alpha animation of a font string of the addon's own, made once, so it plays in a fight too; nothing
-- plays on a level that does not show, and no row of its own turns it on or off.

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART = "Level options"
local KIND_PART = "Elite and Rare"
-- Where the number sits on the picture, in units from its bottom right corner. A round picture adds the way in from the corner of its square to the
-- circle (ns.UnitFrameExtra.pictureInset, UnitFrames.lua).
local INSET = 2

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- How far in from the bottom right corner of the picture the number sits, in units.
local function Inset(rec)
	local more = type(X.pictureInset) == "function" and X.pictureInset(rec) or 0
	return INSET + (ns.Finite(more) and more or 0)
end

-- The text on the picture, made once on a frame of the addon's own above the picture, its inner line and its rim. It waits for the end of combat.
local function Make(rec)
	local pic = rec.pic
	if pic.levelText ~= nil then
		return true
	end
	if InCombatLockdown() then
		return false
	end
	local owner = rec.parts.owner
	local ok, level = pcall(owner.GetFrameLevel, owner)
	if pic.top == nil then
		pic.top = X.frame(owner, ok and X.number(level) and level + 2 or nil)
		pic.top:SetAllPoints(pic.frame)
	end
	local text = pic.top:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	ns.Own[text] = true
	pcall(text.SetWordWrap, text, false)
	pcall(text.SetMaxLines, text, 1)
	text:SetJustifyH("RIGHT")
	text:SetPoint("BOTTOMRIGHT", pic.frame, "BOTTOMRIGHT", -INSET, INSET)
	text:Hide()
	pic.levelText = text
	pic.levelInset = INSET
	return true
end

local Update

-- Runs Update once more when the fight is over.
local function Later(rec)
	if not rec.levelQueued then
		rec.levelQueued = true
		ns.OutOfCombat(function()
			rec.levelQueued = nil
			Update(rec)
		end)
	end
end

-- The level as the name row has it, with the mark of a target's kind after it, in the colour and the font of the row's level with an outline.
-- A level the client withholds is passed on unread and gets no mark. Nothing shows unless the level position is On the portrait and the row shows a level.
-- The number is anchored again, out of combat, when the picture turns round or square or changes size.
function Update(rec)
	local pic, row = rec.pic, rec.row
	if pic == nil or row == nil then
		return
	end
	local on = X.rowOn(rec) and X.row.at() == "portrait" and row.levelOn == true and not pic.none and not pic.failed and not pic.noSize and not ns.PartStopped(KEY, PART)
	if not on then
		if pic.levelText ~= nil then
			pic.levelText:Hide()
		end
		return
	end
	if not Make(rec) then
		Later(rec)
		return
	end
	local text = pic.levelText
	local inset = Inset(rec)
	if pic.levelInset == nil or math.abs(pic.levelInset - inset) > 0.01 then
		if InCombatLockdown() then
			Later(rec)
		else
			text:SetPoint("BOTTOMRIGHT", pic.frame, "BOTTOMRIGHT", -inset, inset)
			pic.levelInset = inset
		end
	end
	local ok, value = pcall(row.level.GetText, row.level)
	local withheld = ok and ns.IsSecret(value)
	if not ok or not (withheld or type(value) == "string" or X.number(value)) then
		text:Hide()
		return
	end
	local look = not withheld and not ns.PartStopped(KEY, KIND_PART) and Opt("kindMark") == true and rec.rank and ns.KINDS[rec.rank] or nil
	pcall(text.SetText, text, look and look.mark and (tostring(value) .. " " .. look.mark) or value)
	local fine, file, size, flags = pcall(row.level.GetFont, row.level)
	if fine and not ns.IsSecret(file) and not ns.IsSecret(size) and not ns.IsSecret(flags) and type(file) == "string" and X.number(size) then
		flags = type(flags) == "string" and flags or ""
		if not flags:find("OUTLINE", 1, true) then
			flags = flags == "" and "OUTLINE" or flags .. ",OUTLINE"
		end
		local key = file .. size .. flags
		if pic.levelFont ~= key then
			pic.levelFont = key
			pcall(text.SetFont, text, file, size, flags)
		end
	end
	local answered, r, g, b = pcall(row.level.GetTextColor, row.level)
	if answered and X.number(r) and X.number(g) and X.number(b) then
		text:SetTextColor(r, g, b, 1)
	end
	text:Show()
end

table.insert(X.after.rowText, { part = PART, fn = Update })
table.insert(X.after.colour, { part = PART, fn = Update })
table.insert(X.after.apply, { part = PART, fn = Update })
table.insert(X.after.layout, { part = PART, fn = Update })
table.insert(X.after.picture, { part = PART, fn = Update })

-- The pop as you level --------------------------------------------------------------------------------------------------------------------------

-- The wait after PLAYER_LEVEL_UP, the size the number pops to, the seconds it settles over and the opacity it fades up from.
local POP = { wait = 0.2, scale = 1.8, time = 0.45, alpha = 0.4 }
-- The pop of each font string, made once; false where the client will not make it.
local pops = setmetatable({}, { __mode = "k" })

-- A Scale animation from POP.scale back to whole (a font string scales by its vertices, as PlateQuest.lua pops its kill count) and an Alpha one from
-- POP.alpha to full, together. Its origin is set as it plays.
local function PopOf(text)
	local pop = pops[text]
	if pop ~= nil then
		return pop
	end
	pop = false
	local ok, group, grow = pcall(function()
		local modes = Enum and Enum.FontStringScaleAnimationMode
		pcall(text.SetScaleAnimationMode, text, modes and modes.Vertex or 1)
		local made = text:CreateAnimationGroup()
		ns.Own[made] = true
		local scale = made:CreateAnimation("Scale")
		ns.Own[scale] = true
		scale:SetScaleFrom(POP.scale, POP.scale)
		scale:SetScaleTo(1, 1)
		scale:SetDuration(POP.time)
		pcall(scale.SetSmoothing, scale, "OUT")
		local fade = made:CreateAnimation("Alpha")
		ns.Own[fade] = true
		fade:SetFromAlpha(POP.alpha)
		fade:SetToAlpha(1)
		fade:SetDuration(POP.time)
		return made, scale
	end)
	if ok and type(group) == "table" and type(grow) == "table" then
		pop = { group = group, grow = grow }
	end
	pops[text] = pop
	return pop
end

-- Pops a number that shows, from the point origin of it.
local function Pop(text, origin)
	if text == nil then
		return
	end
	local okShown, shown = pcall(text.IsVisible, text)
	if not okShown or ns.IsSecret(shown) or shown ~= true then
		return
	end
	local pop = PopOf(text)
	if not pop then
		return
	end
	pcall(pop.grow.SetOrigin, pop.grow, origin, 0, 0)
	pcall(pop.group.Stop, pop.group)
	pcall(pop.group.Play, pop.group)
end

-- The level of the player frame as you level: in the name row, from the end the row puts it at, and on the portrait, from its corner.
local function LevelUp()
	local rec = X.known(_G.PlayerFrame)
	if rec == nil then
		return
	end
	local row = rec.row
	if row ~= nil and row.level ~= nil and row.levelOn == true then
		local ok, justify = pcall(row.level.GetJustifyH, row.level)
		Pop(row.level, ok and justify == "LEFT" and "LEFT" or "RIGHT")
	end
	local pic = rec.pic
	if pic ~= nil and pic.levelText ~= nil then
		Pop(pic.levelText, "BOTTOMRIGHT")
	end
end

ns.AddEvent(KEY, "PLAYER_LEVEL_UP", function()
	local function Run()
		X.run(PART, LevelUp)
	end
	if not (type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, POP.wait, Run)) then
		Run()
	end
end)
