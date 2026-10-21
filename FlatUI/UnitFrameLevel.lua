local ADDON_NAME, ns = ...

-- The level on the portrait of the player, target and focus frames, for the level position On the portrait. The other positions, the colour and the
-- size of the level are in UnitFrames.lua, in the functions that lay out and write the name row. This file adds its work after the steps of that file
-- through ns.UnitFrameExtra: a part that stops on errors counts as off here, and every function can run twice with the same result.

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART = "Level options"
local KIND_PART = "Elite and Rare"
-- Where the number sits on the picture, in units from its bottom right corner.
local INSET = 2

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
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
	return true
end

-- The level as the name row has it, with the mark of a target's kind after it, in the colour and the font of the row's level with an outline.
-- A level the client withholds is passed on unread and gets no mark. Nothing shows unless the level position is On the portrait and the row shows a level.
local function Update(rec)
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
		if not rec.levelQueued then
			rec.levelQueued = true
			ns.OutOfCombat(function()
				rec.levelQueued = nil
				Update(rec)
			end)
		end
		return
	end
	local text = pic.levelText
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
