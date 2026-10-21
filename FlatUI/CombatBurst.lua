local _, ns = ...

-- Burst, a Movement of the numbers over enemies (design.md 2.2 and 2.3 of research/reports/2026-10-20-scrolling-text, the enemy.burst keys of
-- preview-spec.json). A critical hit starts at SLAM times its settled height, settles in 0.2 seconds while it rises 12 units, then goes on
-- as Rise and fall. Normal hits keep Rise and fall. The numbers are the module's own (CombatText.lua): the same stepped SetTextHeight the
-- pop uses, no animation group and no table for each hit. The path itself is in ns.CombatOffsets, so the number over the plate and the
-- setup drawing move the same way. The values are choices of this file, not the game's.
-- slam: the height at the start, as a share of the settled one. keys: { seconds, share of the settled height } where the share is reached,
-- the first segment easing in (p * p). settle: seconds to the settled height and the end of the rise. rise: units gained in that time.
-- life, fade: seconds a number lives and the second it starts to fade. cap: the most a height reaches, the largest raster of the module, as the pop's limit is.
local BURST = { settle = 0.2, rise = 12, life = 1.7, fade = 1.2, cap = 128,
	keys = { { 0, 2.2 }, { 0.09, 0.92 }, { 0.15, 1.08 }, { 0.2, 1 } } }
ns.CombatBurst = BURST

-- The share of the settled height a burst has t seconds in.
function ns.CombatBurstScale(t)
	local keys = BURST.keys
	if t >= BURST.settle then
		return 1
	end
	for i = 2, #keys do
		local a, b = keys[i - 1], keys[i]
		if t <= b[1] then
			local p = (t - a[1]) / (b[1] - a[1])
			if i == 2 then
				p = p * p
			end
			return a[2] + (b[2] - a[2]) * p
		end
	end
	return 1
end

-- The height a burst of this settled height has t seconds in, in whole numbers and never past the cap, and whether it is still settling.
function ns.CombatBurstHeight(settle, t)
	if t >= BURST.settle then
		return settle, false
	end
	return math.min(BURST.cap, math.floor(settle * ns.CombatBurstScale(t) + 0.5)), true
end

-- How a number over a plate moves: Burst is for a critical hit over an enemy alone, every other number with Burst chosen rises and falls.
function ns.CombatMove(movement, burstable)
	if movement == "burst" then
		return burstable and "burst" or "fall"
	end
	return movement
end
