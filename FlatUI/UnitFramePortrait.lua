local ADDON_NAME, ns = ...

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART = "Portrait options"

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function BorderColour(rec)
	local kind = rec.kind
	if kind == "player" or kind == "pet" then
		return ns.ClassColour()
	end
	local unit = X.unitOf(rec)
	if unit == nil then
		return nil
	end
	if kind == "partypet" then
		local owner = unit:match("^partypet(%d+)$")
		if owner then
			return ns.ClassColourOf("party" .. owner)
		end
		return nil
	elseif kind == "party" then
		return ns.ClassColourOf(unit)
	end
	local ok, player = pcall(UnitIsPlayer, unit)
	if not ok or ns.IsSecret(player) or type(player) ~= "boolean" then
		return nil
	end
	if player then
		return ns.ClassColourOf(unit)
	end
	return ns.ReactionColour(unit)
end

local function Bare(outline, bare)
	if type(X.bareOutline) == "function" then
		X.bareOutline(outline, bare)
	else
		ns.SetOutlineBare(outline, bare)
	end
end

local function Outlines(rec)
	local list = type(X.frameOutlines) == "function" and X.frameOutlines(rec) or nil
	if type(list) ~= "table" then
		list = { rec.pic and rec.pic.outline }
	end
	return list
end

local function Colour(rec, on)
	local pic = rec.pic
	local joined = type(X.joined) == "function" and X.joined(rec) == true
	if pic == nil and not joined then
		return
	end
	local list = Outlines(rec)
	local coloured
	if pic ~= nil then
		coloured = pic.coloured == true
	else
		coloured = list[1] ~= nil and list[1].r ~= nil
	end
	local border = "thin"
	if on and Opt("squarePortrait") == true and (joined or not pic.none) and not ns.PartStopped(KEY, PART) then
		border = Opt("portraitBorder")
	end
	local r, g, b
	if border == "class" and not coloured then
		r, g, b = X.mute(BorderColour(rec))
	end
	for _, outline in pairs(list) do
		if border == "class" and not coloured then
			X.colourOutline(outline, r, g, b)
		end
		Bare(outline, border == "none" and not coloured)
	end
end

local function Back()
	if type(X.backColour) == "function" then
		local r, g, b = X.backColour()
		if ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
			return r, g, b
		end
	end
	return ns.Colour("general.backdrop")
end

local function Fade(rec)
	local pic = rec.pic
	if pic == nil or pic.fadeTex == nil then
		return
	end
	local on = pic.drawn == true and rec.tall == true and X.large[rec.kind] == true and X.rowOn(rec) and Opt("portraitFade") == true
		and Opt("stripColour") == "gradient" and not ns.PartStopped(KEY, PART)
	if on then
		local r, g, b = Back()
		local strength = Opt("stripFade") / 100
		local key = table.concat({ r, g, b, strength }, ":")
		if pic.fadeKey ~= key then
			pic.fadeKey = key
			pic.fadeOk = X.gradient(pic.fadeTex, nil, r, g, b, 0, strength) == true
		end
		on = pic.fadeOk == true
	end
	pic.fadeTex:SetShown(on)
end

table.insert(X.after.colour, { part = PART, fn = Colour })
table.insert(X.after.apply, { part = PART, fn = Fade })
table.insert(X.after.layout, { part = PART, fn = Fade })
table.insert(X.after.picture, { part = PART, fn = Fade })
table.insert(X.after.picture, { part = PART, fn = Colour })
