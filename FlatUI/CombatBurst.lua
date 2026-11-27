local _, ns = ...

local BURST = { settle = 0.2, rise = 12, life = 1.7, fade = 1.2, cap = 128,
	keys = { { 0, 2.2 }, { 0.09, 0.92 }, { 0.15, 1.08 }, { 0.2, 1 } } }
ns.CombatBurst = BURST

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

function ns.CombatBurstHeight(settle, t)
	if t >= BURST.settle then
		return settle, false
	end
	return math.min(BURST.cap, math.floor(settle * ns.CombatBurstScale(t) + 0.5)), true
end

function ns.CombatMove(movement, burstable)
	if movement == "burst" then
		return burstable and "burst" or "fall"
	end
	return movement
end
