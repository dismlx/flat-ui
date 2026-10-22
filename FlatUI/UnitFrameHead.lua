local ADDON_NAME, ns = ...

-- Portrait style 3D head: a live model of the head of the unit in the picture square of the player, target, focus, pet and party frames. This file adds its work after
-- the picture of UnitFrames.lua through ns.UnitFrameExtra: a part that stops on errors counts as off here, and every function can run twice with the same result.
-- The model is made once for each frame, on the picture frame and at its level (the marks of the game are a level above it), and shows only while the client allows it: the identity of the unit must not be withheld
-- (C_Secrets.ShouldUnitIdentityBeSecret answers a plain false, Blizzard_APIDocumentationGenerated/SecretPredicateAPIDocumentation.lua:305-319) and SetUnit must not
-- raise (FrameAPICharacterModelBaseDocumentation.lua:239-247). Both are asked again at every draw. Where either fails, the picture shows as style Picture draws it
-- and /flatui status says why. A unit that is out of view or, for a party member, offline has no model to show: the picture shows then, with no line. The target of target keeps the picture: it is drawn again every 0.2 seconds.

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART = "3D head"

local KINDS = { player = true, target = true, focus = true, pet = true, party = true, partypet = true }
-- The zoom of the portrait and the distance of the camera for each framing. These numbers are stand-ins until the author picks them.
local FRAMING = { face = { 1, 0.8 }, head = { 1, 1 }, shoulders = { 0.6, 1.3 } }
-- The tint over the model for a unit that is low on health, a ghost or tapped: this share of the colour of the tint.
local OVERLAY = 0.35
local NOTE = { on = "3D head", withheld = "3D head not shown: identity withheld, picture shown", refused = "3D head not shown: the game refused the head, picture shown" }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- Every record that has a head, and how many frames say each line, so that a line stays on the status until the last frame that needs it no longer does.
local heads, held = {}, {}
local watcher

-- Says a line for one frame, or takes back what the frame said.
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

-- True while the unit is in view and, for a party member, connected: a model of any other unit is an empty square.
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

-- The GUID of the unit, nil while it is withheld.
local function Guid(unit)
	local ok, guid = pcall(UnitGUID, unit)
	if ok and type(guid) == "string" and not ns.IsSecret(guid) then
		return guid
	end
end

-- Nil while the identity of the unit is not withheld, else why the head cannot show: "withheld" when the client says so or does not answer a plain false, "refused" while
-- there is no way to ask.
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
-- The game says a unit has a new model or came online, and the world is drawn again after a loading screen. The model is loaded again for each.
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


-- The frame that hears the events, made with the first head.
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

-- The model and the frame over it, made once for a frame, in this order and both at the level of the picture frame, below the marks of the game, which are a level
-- above it. The frame over the model holds what must be drawn over the head: the tint, the fade of the top of the picture and the lines of its inner border.
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

-- What must be over the model goes to the frame over it while a head shows, and back to the picture frame while none does: the fade of the picture and the lines
-- inside its border, the rounded line of its border included. The four edges of the border are just outside the picture and stay where they are.
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

-- Hides the head, and the picture shows as the style Picture draws it.
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

-- The tint of the picture for the state of the unit: grey with Desaturation, low health red, ghost blue and any other tint of the game as a colour over the head.
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

-- The head of the frame drawn again: the unit, when it is not the one loaded or when asked to (force), then the framing and the tint. The alpha of the model is its
-- own 1: it is a child of the picture frame and follows the alpha of that frame and of the frames above it.
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

-- After each draw of a picture: a frame that has the style head and a picture to show has a model on it, and any other frame has none.
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

-- The game tinted the portrait again: the head takes the new tint and desaturation at once.
local function Retint(rec)
	local head = rec.pic and rec.pic.head
	if head ~= nil and head.showing and not ns.PartStopped(KEY, PART) then
		State(rec, head)
	end
end

table.insert(X.after.tint, { part = PART, fn = Retint })
