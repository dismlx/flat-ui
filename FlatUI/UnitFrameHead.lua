local ADDON_NAME, ns = ...

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART = "3D head"

local KINDS = { player = true, target = true, focus = true, pet = true, party = true, partypet = true }
local FRAMING = { face = { 1, 0.8 }, head = { 1, 1 }, shoulders = { 0.6, 1.3 } }
local OVERLAY = 0.35
local NOTE = { on = "3D head", withheld = "3D head not shown: identity withheld, picture shown", refused = "3D head not shown: the game refused the head, picture shown" }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local heads, held = {}, {}
local watcher

local function Say(rec, text)
	local pic = rec.pic
	local old = pic.headNote
	if old == text then
		return
	end
	pic.headNote = text
	if old ~= nil then
		held[old] = held[old] - 1
		if held[old] <= 0 then
			held[old] = nil
			ns.ClearNote(KEY, old)
		end
	end
	if text ~= nil then
		held[text] = (held[text] or 0) + 1
		ns.Note(KEY, text)
	end
end

local function Line(rec, text)
	local label = X.labels[rec.kind] or rec.kind
	return ("%s%s portrait: %s"):format(label:sub(1, 1):upper(), label:sub(2), text)
end

local function Number(value)
	return type(value) == "number" and not ns.IsSecret(value)
end

local function Visible(rec, unit)
	local ok, seen = pcall(UnitIsVisible, unit)
	if not (ok and not ns.IsSecret(seen) and seen == true) then
		return false
	end
	if rec.kind == "party" then
		local good, online = pcall(UnitIsConnected, unit)
		return good and not ns.IsSecret(online) and online == true
	end
	return true
end

local function Guid(unit)
	local ok, guid = pcall(UnitGUID, unit)
	if ok and type(guid) == "string" and not ns.IsSecret(guid) then
		return guid
	end
end

local function Identity(unit)
	if type(C_Secrets) ~= "table" or ns.IsSecret(C_Secrets) or type(C_Secrets.ShouldUnitIdentityBeSecret) ~= "function" then
		return "refused"
	end
	local ok, secret = pcall(C_Secrets.ShouldUnitIdentityBeSecret, unit)
	if ok and not ns.IsSecret(secret) and secret == false then
		return nil
	end
	return "withheld"
end

local Place
local function Repaint(_, event, unit)
	if ns.PartStopped(KEY, PART) then
		return
	end
	for _, rec in ipairs(heads) do
		local head = rec.pic and rec.pic.head
		if head and head.want and (event == "PLAYER_ENTERING_WORLD" or ns.IsSecret(unit) or type(unit) ~= "string" or X.unitOf(rec) == unit) then
			ns.EachPart(KEY, PART, Place, rec, true)
		end
	end
end

local function Watch()
	if watcher == nil then
		watcher = CreateFrame("Frame")
		ns.Own[watcher] = true
		watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
		pcall(watcher.RegisterEvent, watcher, "UNIT_MODEL_CHANGED")
		pcall(watcher.RegisterEvent, watcher, "UNIT_CONNECTION")
		watcher:SetScript("OnEvent", Repaint)
	end
end

local function Make(rec)
	local pic = rec.pic
	if pic.head ~= nil then
		return pic.head
	end
	local ok, model = pcall(CreateFrame, "PlayerModel", nil, pic.frame)
	if not ok or type(model) ~= "table" then
		return nil
	end
	local level = pic.frame:GetFrameLevel()
	local over = CreateFrame("Frame", nil, pic.frame)
	local tint = over:CreateTexture(nil, "OVERLAY", nil, 7)
	local head = { model = model, over = over, tint = tint }
	ns.Own[model], ns.Own[over], ns.Own[tint] = true, true, true
	model:SetAllPoints(pic.frame)
	over:SetAllPoints(pic.frame)
	if Number(level) then
		model:SetFrameLevel(level)
		over:SetFrameLevel(level)
	end
	tint:SetAllPoints(over)
	tint:Hide()
	pcall(model.SetKeepModelOnHide, model, true)
	model:Hide()
	pic.head = head
	heads[#heads + 1] = rec
	Watch()
	model:SetScript("OnShow", function()
		if not head.busy and head.want and not ns.PartStopped(KEY, PART) then
			ns.EachPart(KEY, PART, Place, rec, true)
		end
	end)
	return head
end

local function Parents(rec, over)
	local pic = rec.pic
	local to = over and pic.head.over or pic.frame
	if pic.head.parent == to then
		return
	end
	pic.head.parent = to
	local lift = over and to or nil
	local list = { pic.fadeTex }
	for _, outline in ipairs({ pic.outline, pic.inner }) do
		if outline ~= nil then
			outline.liftTo = lift
			list[#list + 1] = X.rimLine(outline)
		end
	end
	if pic.inner ~= nil then
		for _, edge in ipairs(pic.inner.edges) do
			list[#list + 1] = edge
		end
	end
	for _, region in ipairs(list) do
		pcall(region.SetParent, region, to)
	end
end

local function Fallback(rec, why)
	local pic = rec.pic
	local head = pic.head
	if head ~= nil then
		pcall(head.model.Hide, head.model)
		head.tint:Hide()
		head.loaded, head.showing = nil, false
		Parents(rec, false)
	end
	pic.texture:SetShown(pic.drawn == true)
	Say(rec, why and NOTE[why] and Line(rec, NOTE[why]) or nil)
end

local function State(rec, head)
	local pic = rec.pic
	local r, g, b = pic.r, pic.g, pic.b
	local grey = pic.grey == true or (Number(r) and r == g and g == b and r < 0.6)
	pcall(head.model.SetDesaturation, head.model, grey and 1 or 0)
	local tinted = not grey and Number(r) and Number(g) and Number(b) and (r < 0.99 or g < 0.99 or b < 0.99)
	if tinted then
		head.tint:SetColorTexture(r, g, b, OVERLAY)
	end
	head.tint:SetShown(tinted and true or false)
end

function Place(rec, force)
	local pic = rec.pic
	local head = pic.head
	if head == nil then
		return
	end
	local unit = X.unitOf(rec)
	local why = unit == nil and "refused" or Identity(unit)
	local model = head.model
	if why == nil and not Visible(rec, unit) then
		why = "unseen"
	end
	if why == nil then
		head.busy = true
		local guid = Guid(unit)
		local ok = true
		if force or not head.loaded or head.unit ~= unit or guid == nil or head.guid ~= guid then
			head.loaded = nil
			pcall(model.ClearModel, model)
			ok = pcall(model.SetUnit, model, unit)
			if ok then
				head.loaded, head.unit, head.guid = true, unit, guid
			end
		end
		if ok then
			local frame = FRAMING[Opt("headFraming")] or FRAMING.head
			pcall(model.SetPortraitZoom, model, frame[1])
			pcall(model.SetCamDistanceScale, model, frame[2])
			pcall(model.SetPosition, model, 0, 0, 0)
			pcall(model.SetRotation, model, 0, false)
			Parents(rec, true)
			head.showing = true
			State(rec, head)
			pic.texture:Hide()
			pcall(model.Show, model)
			Say(rec, Line(rec, NOTE.on))
		else
			why = "refused"
		end
		head.busy = nil
	end
	if why ~= nil then
		Fallback(rec, why)
	end
end

local function Update(rec, on, shown)
	local pic = rec.pic
	if pic == nil then
		return
	end
	local wanted = on and shown and pic.style == "head" and KINDS[rec.kind] == true and not ns.PartStopped(KEY, PART)
	local head = wanted and Make(rec) or pic.head
	if head == nil then
		Say(rec, wanted and Line(rec, NOTE.refused) or nil)
		return
	end
	head.want = wanted and true or false
	if wanted then
		Place(rec)
	else
		Fallback(rec, nil)
	end
end

table.insert(X.after.picture, { part = PART, fn = Update })

local function Retint(rec)
	local head = rec.pic and rec.pic.head
	if head ~= nil and head.showing and not ns.PartStopped(KEY, PART) then
		State(rec, head)
	end
end

table.insert(X.after.tint, { part = PART, fn = Retint })
