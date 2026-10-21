local _, ns = ...

-- Width and height of the player, pet, target and focus cast bars, the text of the player bar, and the
-- size of the spell name on all four. Edit Mode has only a scale for these bars. SetWidth and SetHeight
-- are widget calls it does not replace.
-- The game sets the size of the player and pet bars again whenever Edit Mode locks the player bar to
-- the player frame or unlocks it, in these two functions, so a hook on each puts the size back. The
-- same two functions give the spell name of those bars a font object again, in SetLook. The target and
-- focus bars are created at one size and one font and nothing sets either again. This is not a module:
-- the cast bars module calls ns.CastBarSizes whenever it applies its settings.

local KEY = "castbars"
local PART = "size"

-- What the game sets: width and height unlocked, then locked under the player frame.
-- Source: CastingBarMixin:SetLook and PlayerFrame_AttachCastBar and PlayerFrame_DetachCastBar.
local BARS = {
	{ key = "player", name = "PlayerCastingBarFrame", game = { 208, 11, 150, 10 } },
	{ key = "pet", name = "PetCastingBarFrame", game = { 195, 13, 150, 10 } },
	-- Children of protected unit frames: sized out of combat only.
	{ key = "target", name = "TargetFrameSpellBar", game = { 150, 10, 150, 10 }, child = true },
	{ key = "focus", name = "FocusFrameSpellBar", game = { 150, 10, 150, 10 }, child = true },
}

-- The art of the player bar that has a size of its own: the spark is 20 high on a bar 11 high, and
-- the mask that clips the cast effects is 256 by 13 on a bar 208 by 11.
local SPARK_HEIGHT, SPARK_EXTRA = 20, 9
local MASK_WIDTH, MASK_HEIGHT = 256, 13
local BAR_WIDTH, BAR_HEIGHT = 208, 11

local sized = setmetatable({}, { __mode = "k" })
local queued = {}
local hooked = false
local Apply

local function Attached()
	local bar = PlayerCastingBarFrame
	if ns.Forbidden(bar) then
		return false
	end
	local ok, attached = pcall(function()
		return bar.attachedToPlayerFrame
	end)
	return ok and not ns.IsSecret(attached) and attached == true
end

-- A region of a bar that may not be there.
local function Part(bar, key)
	local ok, part = pcall(function()
		return bar[key]
	end)
	if ok and part ~= nil and not ns.IsSecret(part) then
		return part
	end
	return nil
end

-- The game anchors the text of a bar again, in SetLook, each time it sets the size.
local function PlaceText(bar, attached, custom)
	local text = Part(bar, "Text")
	if not text then
		return
	end
	text:ClearAllPoints()
	if custom == "inside" then
		text:SetPoint("CENTER", bar, "CENTER", 0, 0)
	elseif custom == "below" then
		-- The game's own spot on a bar 11 high is 1 above the bottom edge.
		text:SetPoint("TOP", bar, "BOTTOM", 0, 1)
	elseif attached then
		text:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 3)
		text:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 3)
	else
		text:SetPoint("TOP", bar, "TOP", 0, -10)
	end
end

-- The spark, the mask and the text of the player bar follow a size, or go back to the game's.
local function FitPlayer(bar, width, height, custom)
	local spark, mask = Part(bar, "Spark"), Part(bar, "BorderMask")
	if spark then
		spark:SetHeight(custom and height + SPARK_EXTRA or SPARK_HEIGHT)
	end
	if mask then
		if custom then
			mask:SetSize(width * MASK_WIDTH / BAR_WIDTH, height * MASK_HEIGHT / BAR_HEIGHT)
		else
			mask:SetSize(MASK_WIDTH, MASK_HEIGHT)
		end
	end
	PlaceText(bar, Attached(), custom)
end

-- The size the game gave the bar, for a bar that was sized.
local function Unsize(bar, entry)
	sized[bar] = nil
	local game = entry.game
	local locked = not entry.child and Attached()
	bar:SetWidth(locked and game[3] or game[1])
	bar:SetHeight(locked and game[4] or game[2])
	if entry.key == "player" then
		FitPlayer(bar, BAR_WIDTH, BAR_HEIGHT, nil)
	end
end

local function Size(bar, entry)
	local on = ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and ns.Get(KEY .. "." .. entry.key .. "Size")
	local custom = on and entry.key == "player" and ns.Get("castbars.playerText") or nil
	-- As the game has it: below the bar, and inside it while the bar is locked under the player frame.
	if custom == "game" then
		custom = Attached() and "inside" or "below"
	end
	if on then
		local width, height = ns.Get(KEY .. "." .. entry.key .. "Width"), ns.Get(KEY .. "." .. entry.key .. "Height")
		-- Marked first: a call the game refuses after the width went through must still be undone.
		sized[bar] = true
		bar:SetWidth(width)
		bar:SetHeight(height)
		if entry.key == "player" then
			FitPlayer(bar, width, height, custom)
		end
	elseif sized[bar] then
		Unsize(bar, entry)
	end
end

-- The spell name of a bar, at a percent of the size the game gave it.
local function FitText(bar)
	local percent = ns.Enabled(KEY) and ns.Get(KEY .. ".textSize") or 100
	if ns.TextSize(Part(bar, "Text"), percent) == false then
		ns.Note(KEY, "Cast bars: the font of a spell name could not be changed, so it keeps its size.")
	end
	-- The game gives the string a new font object when it lays the bar out, which brings its own alignment and colour.
	ns.CastText(bar)
end

-- A protected bar is not sized in combat, and nor are the bars that hang from a protected unit frame.
function Apply(entry)
	local bar = _G[entry.name]
	if bar == nil or ns.IsSecret(bar) or ns.Forbidden(bar) then
		return
	end
	if InCombatLockdown() and (entry.child or ns.MaybeProtected(bar)) then
		if not queued[entry.key] then
			queued[entry.key] = true
			ns.OutOfCombat(function()
				queued[entry.key] = nil
				Apply(entry)
			end)
		end
		return
	end
	if ns.IsStopped(KEY) or ns.PartStopped(KEY, PART) then
		-- The module or the part stopped: a bar it had sized gets the game's size back.
		pcall(Size, bar, entry)
	elseif not ns.EachPart(KEY, PART, Size, bar, entry) and not ns.IsStopped(KEY) and not ns.PartStopped(KEY, PART) then
		ns.Note(KEY, ("Cast bars: the game refused a size on the %s cast bar."):format(entry.key))
		pcall(Unsize, bar, entry)
	end
	ns.Each(KEY, FitText, bar)
end

-- The two functions the game calls on every layout, lock change and scale change of the player bar.
local function Resize()
	Apply(BARS[1])
	Apply(BARS[2])
end

local function Hook()
	if hooked or type(hooksecurefunc) ~= "function" or not ns.Enabled(KEY) or not (ns.Get("castbars.playerSize") or ns.Get("castbars.petSize") or ns.Get("castbars.textSize") ~= 100
		or ns.Get("castbars.textAlign") ~= "game" or ns.Get("castbars.textOwn")) then
		return
	end
	hooked = true
	for _, name in ipairs({ "PlayerFrame_AttachCastBar", "PlayerFrame_DetachCastBar" }) do
		if type(_G[name]) == "function" then
			hooksecurefunc(name, Resize)
		end
	end
end

function ns.CastBarSizes()
	for _, entry in ipairs(BARS) do
		Apply(entry)
	end
	if ns.PartStopped(KEY, PART) then
		-- The part stopped on a bar: every bar it had sized gets the game's size back.
		for _, entry in ipairs(BARS) do
			Apply(entry)
		end
	end
	Hook()
end

-- Target and focus frames can be created after the module starts.
local events = CreateFrame("Frame")
pcall(events.RegisterEvent, events, "PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function()
	ns.CastBarSizes()
end)
