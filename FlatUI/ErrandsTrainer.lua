local _, ns = ...

-- Train all: a button beside the Train button of the trainer window (ClassTrainerFrame and ClassTrainerTrainButton, from the game's
-- Blizzard_TrainerUI, which loads when a trainer is first opened) that learns every service the trainer marks available and you can pay for.
-- The plan takes the rows in the order of the list, each while the money left pays for it, and the calls (BuyTrainerService) go last first,
-- each row read again just before its call, so a list rebuilt after a purchase cannot move a call onto another row.
-- A profession is left to the game's Train button, which asks before it uses one of your two places; so is a row whose price or flags cannot
-- be read. Both shapes of the client's answers are read: GetTrainerServiceInfo gives name, type, ... (the mainline trainer) or name, rank,
-- type, ... (the classic one), and GetTrainerServiceCost gives cost, isProfession or cost, talent points, profession points.
-- The tooltip says what a click learns and why anything is left. After a click the button waits SETTLE seconds, so a double click asks once.
-- It follows the game's ClassTrainerFrame_Update and TRAINER_UPDATE to stay right. Not in combat: the button is made only out of the lockdown
-- and does nothing in a fight. Never under the gamepad interface, whose navigation could not reach it; /flatui train does the same there.
-- While EnhanceQoL's own Train All button (EQOLTrainAllButton) is shown in the same place, this one stands aside.
-- It follows EnhanceQoL's Train All button, adapted with the permission of its author.

local E = ns.Errands
local part = E.Part({ label = "Trainer" })

local LABEL = "Train all"
local KINDS = { available = true, unavailable = true, used = true, header = true }
local SETTLE = 1
local MAX_ROWS = 500
local GAP = 2
local WIDTH = 80

local button
local followed = false
-- A make of the button failed: it is not tried again.
local broken = false
-- A make waits for the end of the fight.
local queued = false
local settling = false
-- What /flatui status says: the last click that the game took, and a click the game refused.
local last
local refusedLast = false

local Update, Explain

local function Skills(n)
	return n == 1 and "skill" or "skills"
end

-- " for 4s", or nothing for skills that cost nothing.
local function For(cost)
	return cost > 0 and (" for " .. E.Money(cost)) or ""
end

-- EnhanceQoL's own Train All button, shown where this one would be.
local function TheirsShown()
	return E.Shown(_G.EQOLTrainAllButton)
end

-- One row of the trainer's list: { kind, name, price, profession, other }, or nil when it cannot be read.
local function Service(index)
	local ok, name, a, b = pcall(GetTrainerServiceInfo, index)
	if not ok then
		return nil
	end
	local kind
	if not ns.IsSecret(a) and KINDS[a] then
		kind = a
	elseif not ns.IsSecret(b) and KINDS[b] then
		kind = b
	end
	if kind == nil then
		return nil
	end
	local row = { kind = kind, name = (not ns.IsSecret(name) and type(name) == "string") and name or nil }
	if kind ~= "available" then
		return row
	end
	local okCost, price, second, third = pcall(GetTrainerServiceCost, index)
	if not okCost or not ns.Finite(price) or price < 0 or ns.IsSecret(second) or ns.IsSecret(third) then
		row.other = true
		return row
	end
	row.price = price
	if second == true or (ns.Finite(third) and third > 0) then
		row.profession = true
	elseif ns.Finite(second) and second > 0 then
		-- Older clients: the row also costs talent or training points, which this button does not check.
		row.other = true
	end
	return row
end

-- What a click learns: the available rows in the order of the list, each while the money left pays for it. The rest is counted for the
-- tooltip: rows the money does not reach (short), professions, and rows left to the Train button (other).
local function Plan()
	local plan = { buy = {}, cost = 0, short = 0, shortCost = 0, professions = {}, other = 0, rows = 0, read = 0 }
	if type(GetTrainerServiceInfo) ~= "function" or type(GetTrainerServiceCost) ~= "function" then
		return plan
	end
	local count = E.Ask(GetNumTrainerServices)
	if not ns.Finite(count) or count < 1 then
		return plan
	end
	local left = E.Ask(GetMoney)
	if not ns.Finite(left) or left < 0 then
		plan.noMoney, left = true, 0
	end
	plan.rows = math.min(math.floor(count), MAX_ROWS)
	for index = 1, plan.rows do
		local row = Service(index)
		if row then
			plan.read = plan.read + 1
			if row.kind == "available" then
				if row.profession then
					plan.professions[#plan.professions + 1] = row.name or false
				elseif row.other then
					plan.other = plan.other + 1
				elseif row.price <= left then
					plan.buy[#plan.buy + 1] = { index = index, name = row.name, price = row.price }
					plan.cost, left = plan.cost + row.price, left - row.price
				else
					plan.short, plan.shortCost = plan.short + 1, plan.shortCost + row.price
				end
			end
		end
	end
	return plan
end

-- Learns the plan. Returns how many calls the game took, what they cost, and the plan.
local function Learn()
	if not E.On("trainAll") or settling or E.Fighting() then
		return 0, 0, nil
	end
	local plan = Plan()
	local calls, asked, cost = 0, 0, 0
	for i = #plan.buy, 1, -1 do
		local want = plan.buy[i]
		local now = Service(want.index)
		if now and now.kind == "available" and now.name == want.name and not now.profession and not now.other then
			calls = calls + 1
			if E.Call(BuyTrainerService, want.index) then
				asked, cost = asked + 1, cost + want.price
			end
		end
	end
	refusedLast = calls > 0 and asked == 0
	if asked > 0 then
		last = { count = asked, cost = cost }
		-- A second click before the game answers would ask again for the same rows.
		settling = true
		C_Timer.After(SETTLE, function()
			settling = false
			E.Run(part, Update)
		end)
	end
	return asked, cost, plan
end

-- What a click says: what it learns, and what the money did not reach.
local function Said(asked, cost, plan)
	local text = ("Learning %d %s%s."):format(asked, Skills(asked), For(cost))
	if plan and plan.short > 0 then
		text = text .. (" Not enough money for %d more (%s)."):format(plan.short, E.Money(plan.shortCost))
	end
	return text
end

local function TrainAll()
	local asked, cost, plan = Learn()
	if asked > 0 then
		E.Say(Said(asked, cost, plan))
	end
	Update()
	return asked, cost, plan
end

-- True when the trainer's filter hides the rows you can learn.
local function Filtered()
	if type(GetTrainerServiceTypeFilter) ~= "function" then
		return false
	end
	local ok, on = pcall(GetTrainerServiceTypeFilter, "available")
	return ok and not ns.IsSecret(on) and (on == false or on == nil or on == 0)
end

Explain = function(owner, plan)
	if not GameTooltip or ns.Forbidden(GameTooltip) then
		return
	end
	plan = plan or Plan()
	GameTooltip:SetOwner(owner, "ANCHOR_TOP", 0, 4)
	GameTooltip:SetText(LABEL)
	local function Line(text)
		GameTooltip:AddLine(text, 1, 1, 1, true)
	end
	if settling then
		Line("Waiting for the trainer.")
	elseif #plan.buy > 0 then
		Line(("Learns %d %s%s."):format(#plan.buy, Skills(#plan.buy), For(plan.cost)))
	elseif plan.rows > 0 and plan.read == 0 then
		Line("The game did not say what the trainer offers.")
	else
		Line("Nothing here you can learn now.")
	end
	if plan.short > 0 then
		Line(("Not enough money for %d more (%s)."):format(plan.short, E.Money(plan.shortCost)))
	end
	local professions = #plan.professions
	if professions == 1 and type(plan.professions[1]) == "string" then
		Line(("%s is a profession: learn it with Train, which asks first."):format(plan.professions[1]))
	elseif professions > 0 then
		Line(("%d professions: learn them with Train, which asks first."):format(professions))
	end
	if plan.other > 0 then
		Line(("%d more: learn %s with Train."):format(plan.other, plan.other == 1 and "it" or "them"))
	end
	if plan.noMoney then
		Line("The game does not say how much money you have.")
	end
	if #plan.buy == 0 and Filtered() then
		Line("The trainer's filter hides what you can learn.")
	end
	if E.Fighting() then
		Line("Not in a fight.")
	end
	GameTooltip:Show()
end

-- The trainer window and its Train button, or nil and why not: "client" (no BuyTrainerService), "window" (missing, forbidden or protected),
-- "train" (no Train button).
local function Window()
	if type(BuyTrainerService) ~= "function" then
		return nil, nil, "client"
	end
	local frame, train = ClassTrainerFrame, ClassTrainerTrainButton
	if type(frame) ~= "table" or ns.Forbidden(frame) or (ns.MaybeProtected and ns.MaybeProtected(frame)) then
		return nil, nil, "window"
	end
	if type(train) ~= "table" or ns.Forbidden(train) then
		return nil, nil, "train"
	end
	return frame, train
end

-- Makes the button, out of the lockdown only. False while it cannot be made now.
local function Build(frame, train)
	if button then
		return true
	end
	if broken then
		return false
	end
	if E.Fighting() then
		-- In the lockdown the make waits for its end; in the moment before it, PLAYER_REGEN_ENABLED brings the next try.
		if E.InCombat() and not queued then
			queued = true
			ns.OutOfCombat(function()
				queued = false
				E.Run(part, Update)
			end)
		end
		return false
	end
	-- The hover runs as a part of the module, so its errors count toward stopping the part and are seen.
	local ok, made = pcall(E.Button, frame, LABEL, WIDTH, function()
		E.Run(part, TrainAll)
	end, function(owner)
		E.Run(part, Explain, owner)
	end)
	if not ok or type(made) ~= "table" then
		broken = true
		return false
	end
	button = made
	button:SetPoint("RIGHT", train, "LEFT", -GAP, 0)
	button.Keep(function()
		return E.On("trainAll") and not E.Gamepad() and not TheirsShown() and not ns.PartStopped("errands", part.label)
	end)
	return true
end

local function Follow()
	if followed then
		return
	end
	followed = ns.FollowGlobal("ClassTrainerFrame_Update", function()
		E.Run(part, Update)
	end) == true
end

Update = function()
	if not E.On("trainAll") or E.Gamepad() or TheirsShown() then
		if button then
			button:Hide()
		end
		return
	end
	local frame, train = Window()
	if not frame then
		if button then
			button:Hide()
		end
		return
	end
	Follow()
	if not E.Shown(frame) and not button then
		return
	end
	if not Build(frame, train) then
		return
	end
	local plan = Plan()
	button.SetUsable(#plan.buy > 0 and not settling and not E.Fighting())
	button:Show()
	if E.TipOwned(button) then
		Explain(button, plan)
	end
end

E.Listen(part, "ADDON_LOADED", function(name)
	if name == "Blizzard_TrainerUI" then
		Update()
	end
end)
-- Events that change what the button shows. Until the trainer UI exists there is nothing to do.
for _, event in ipairs({ "TRAINER_SHOW", "TRAINER_UPDATE", "PLAYER_MONEY", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
	"INPUT_DEVICE_INTERFACE_TRANSITION" }) do
	E.Listen(part, event, function()
		if button or ClassTrainerFrame ~= nil then
			Update()
		end
	end)
end

-- At the start (the trainer UI may have been loaded before, by another addon) and at each refresh (the row, the page, the profile).
local function Look()
	broken = false
	if button or ClassTrainerFrame ~= nil then
		Update()
	end
end
part.Start, part.Refresh = Look, Look

-- /flatui train: the same as a click, for the gamepad interface or a macro, at an open trainer.
E.slash.train = function()
	local frame = Window()
	if not frame or not E.Shown(frame) then
		print("Flat UI: /flatui train works while a trainer window is open.")
		return
	end
	if not ns.Enabled("errands") then
		print("Flat UI: Errands is off. Tick Run errands on the Errands page.")
		return
	end
	if E.Opt("trainAll") ~= true then
		print("Flat UI: Train all button is off on the Errands page.")
		return
	end
	if E.Fighting() then
		print("Flat UI: not in a fight.")
		return
	end
	local learned, cost, plan = 0, 0, nil
	if not E.Run(part, function()
		learned, cost, plan = TrainAll()
	end) then
		print("Flat UI: Train all failed. /flatui status shows why.")
	elseif learned == 0 then
		print("Flat UI: nothing here you can learn now.")
	elseif E.Opt("chat") == false then
		-- A typed command always answers, even with Say what was done off.
		print("Flat UI: " .. Said(learned, cost, plan))
	end
end
E.help[#E.help + 1] = "/flatui train - at an open trainer, learn everything you can pay for, as the Train all button does"

function part.Status()
	if E.Opt("trainAll") ~= true or ns.PartStopped("errands", part.label) then
		return {}
	end
	local _, _, why = Window()
	if why == "client" then
		return { "Trainer: this client cannot buy from a trainer, so there is no Train all button." }
	elseif E.Gamepad() then
		return { "Trainer: no Train all button while the gamepad interface is on. /flatui train does the same." }
	elseif why == "window" and ClassTrainerFrame ~= nil then
		return { "Trainer: the trainer window does not take a button, so there is no Train all button." }
	elseif why == "train" then
		return { "Trainer: the trainer window has no Train button here, so there is no Train all button." }
	end
	if TheirsShown() then
		return { "Trainer: EnhanceQoL's Train All button is shown, so this one stands aside. /flatui train still works." }
	end
	local lines = { "Trainer: Train all button." }
	if last then
		lines[1] = ("Trainer: Train all button. Last click: %d %s%s."):format(last.count, Skills(last.count), For(last.cost))
	end
	if refusedLast then
		lines[#lines + 1] = "Trainer: the game refused the last Train all click."
	end
	return lines
end
