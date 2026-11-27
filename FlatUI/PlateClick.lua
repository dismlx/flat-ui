local _, ns = ...

local KEY = "nameplates"
local PART = "nameplate click area"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

local NONE = 10000

local KINDS = {
	{ type = "Friendly", through = "clickThroughFriendly", friendly = true },
	{ type = "Enemy", through = "clickThroughEnemy" },
}

local done = {}
local queued, forced = false, false
local note
local rows, told

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

local function Inside()
	if type(IsInInstance) ~= "function" then
		return false
	end
	local ok, inside, kind = pcall(IsInInstance)
	return ok and Plain(inside, "boolean") and inside and Plain(kind, "string") and (kind == "party" or kind == "raid") or false
end

local function Apply(force)
	local types = Plain(Enum, "table") and Plain(Enum.NamePlateType, "table") and Enum.NamePlateType
	local manager = C_NamePlateManager
	local live = ns.Enabled(KEY) and not ns.IsStopped(KEY) and not ns.PartStopped(KEY, PART)
	local rows, any = {}, false
	local inside = Inside()
	for i, kind in ipairs(KINDS) do
		local through = live and Opt(kind.through) or false
		if through and kind.friendly and Opt("clickThroughFriendlyWhere") == "instances" and not inside then
			through = false
		end
		local dx, dy = live and Opt("clickExtraX") or 0, live and Opt("clickExtraY") or 0
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
	queued, forced, told = false, false, nil
	local ok = ns.EachPart(KEY, PART, Apply, f)
	if not ok and ns.PartStopped(KEY, PART) then
		pcall(Apply, true)
	end
end

local function Tell()
	local now = ("%s|%s|%s|%s|%s|%s"):format(tostring(ns.Enabled(KEY)), tostring(Opt("clickThroughFriendly")), tostring(Opt("clickThroughEnemy")),
		tostring(Opt("clickThroughFriendlyWhere")), tostring(Opt("clickExtraX")), tostring(Opt("clickExtraY")))
	local changed = rows ~= nil and rows ~= now
	rows = now
	if changed and not told and InCombatLockdown() and type(ns.PanelShown) == "function" and ns.PanelShown() == true then
		told = true
		print("Flat UI: nameplate clicks change when the fight ends.")
	end
end

local function Queue(force)
	forced = forced or force == true
	pcall(Tell)
	if queued then
		return
	end
	queued = true
	ns.OutOfCombat(Run)
end

EXTRA.refresh[#EXTRA.refresh + 1] = Queue

local function Zoned()
	if Opt("clickThroughFriendly") == true and Opt("clickThroughFriendlyWhere") == "instances" then
		Queue()
	end
end
ns.AddEvent(KEY, "PLAYER_ENTERING_WORLD", Zoned)
ns.AddEvent(KEY, "ZONE_CHANGED_NEW_AREA", Zoned)
