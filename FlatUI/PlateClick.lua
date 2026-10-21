local _, ns = ...

-- The clickable area of a nameplate (added to the plates as a part of Nameplates.lua, ns.PlateExtra): click through, and extra width and height.
-- The area is set for a kind of plate (friendly, enemy) with C_NamePlateManager.SetNamePlateHitTestInsets, out of combat
-- (Blizzard_APIDocumentationGenerated/NamePlateManagerDocumentation.lua:46-62). The plate itself is never resized: the unit frame is anchored to
-- the plate's whole size and the bars hang on it (Blizzard_NamePlateBase.lua:20, Blizzard_NamePlateUnitFrame.lua:699-715), so a bigger plate
-- stretches the game's bars; EllesmereUI shrinks the hit rectangle and leaves the plate alone for that reason
-- (EllesmereUINameplates/EllesmereUINameplatesFriendly.lua:1813-1818). Hit testing is clamped to the plate (NamePlateManagerDocumentation.lua:51),
-- so extra width and height reach only as far as the plate. Nothing is hooked on a plate: the game's own per-plate area (UpdateHitTestArea)
-- stays as it is, and the insets widen, narrow or remove it. A row at its default makes no call the game did not make.

local KEY = "nameplates"
local PART = "nameplate click area"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

-- An inset larger than a plate leaves nothing to click: hit testing is clamped to the plate (NamePlateManagerDocumentation.lua:51).
local NONE = 10000

-- The kinds of plate, with the row that clicks through them.
local KINDS = {
	{ type = "Friendly", through = "clickThroughFriendly", friendly = true },
	{ type = "Enemy", through = "clickThroughEnemy" },
}

-- What is set for each kind (a key of its four insets), so the next pass skips a kind that already has them.
local done = {}
local queued, forced = false, false
local note

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

local function Say(text)
	if note == text then
		return
	end
	if note then
		ns.ClearNote(KEY, note)
	end
	note = text
	if text then
		ns.Note(KEY, text)
	end
end

-- Sets the area of both kinds. Out of combat only.
local function Apply(force)
	local types = Plain(Enum, "table") and Plain(Enum.NamePlateType, "table") and Enum.NamePlateType
	local manager = C_NamePlateManager
	local live = ns.Enabled(KEY) and not ns.IsStopped(KEY) and not ns.PartStopped(KEY, PART)
	local rows, any = {}, false
	for i, kind in ipairs(KINDS) do
		local on = live and (not kind.friendly or Opt("friendly"))
		local through = on and Opt(kind.through) or false
		local dx, dy = on and Opt("clickExtraX") or 0, on and Opt("clickExtraY") or 0
		rows[i] = { through = through, dx = dx, dy = dy }
		if through or dx ~= 0 or dy ~= 0 then
			any = true
		end
	end
	if not types or not Plain(manager, "table") or type(manager.SetNamePlateHitTestInsets) ~= "function" then
		Say(any and "Nameplate click area: the game has no call to set it, so the game's area stays." or nil)
		return
	end
	local refused = false
	for i, kind in ipairs(KINDS) do
		local row, left, top = rows[i], 0, 0
		if row.through then
			left, top = NONE, NONE
		else
			-- 0 - n and not -n: minus zero would be written as -0 on a client that keeps it.
			left, top = 0 - row.dx, 0 - row.dy
		end
		local key = left .. "|" .. top
		if (force or done[kind.type] ~= key) and (done[kind.type] ~= nil or left ~= 0 or top ~= 0) then
			local value = types[kind.type]
			if Plain(value, "number") and pcall(manager.SetNamePlateHitTestInsets, value, left, left, top, top) then
				done[kind.type] = key
			elseif any then
				refused = true
			end
		end
	end
	Say(refused and "Nameplate click area: the game refused the change, so the game's area stays." or nil)
end

local function Run()
	local f = forced
	queued, forced = false, false
	local ok = ns.EachPart(KEY, PART, Apply, f)
	if not ok and ns.PartStopped(KEY, PART) then
		-- The part stopped: the game's area goes back.
		pcall(Apply, true)
	end
end

-- Sets the area now, or when combat ends. force sets what is already set again.
local function Queue(force)
	forced = forced or force == true
	if queued then
		return
	end
	queued = true
	ns.OutOfCombat(Run)
end

EXTRA.refresh[#EXTRA.refresh + 1] = Queue
