local ADDON_NAME, ns = ...

-- The options of the square portrait on unit frames that work on top of UnitFrames.lua: the colour of the border by class or reaction, and the fade
-- of the top of the picture into the background beside a name row that fades. The style, the size, the switches of each kind of frame and
-- the border None are in UnitFrames.lua, in the functions that draw and lay out the picture. This file adds its work after the steps of that file
-- through ns.UnitFrameExtra: a part that stops on errors counts as off here, and every function can run twice with the same result.

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART = "Portrait options"

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- The class colour of the unit of a frame, or the reaction colour of a unit that is not a player, or nil while the client withholds what decides it.
-- The player and the pet take the class of the player, and a party pet that of its owner.
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

-- The border of the picture after UnitFrames.lua has coloured it for a state, a kind or a look: Class or reaction colour fills in only where none of
-- those did (Muted colours mutes it), and None draws the background of the picture without its edges unless a colour was given.
local function Colour(rec, on)
	local pic = rec.pic
	if pic == nil then
		return
	end
	local border = "thin"
	if on and Opt("squarePortrait") == true and not pic.none and not ns.PartStopped(KEY, PART) then
		border = Opt("portraitBorder")
	end
	if border == "class" and not pic.coloured then
		X.colourOutline(pic.outline, X.mute(BorderColour(rec)))
	end
	ns.SetOutlineBare(pic.outline, border == "none" and not pic.coloured)
end

-- The top of the picture beside a name row that fades upward takes the colour of the background, as strong at the top as the row fades. It is
-- there only while the picture is drawn, is as tall as the frame, and the frame has a name row of that colour.
local function Fade(rec)
	local pic = rec.pic
	if pic == nil or pic.fadeTex == nil then
		return
	end
	local on = pic.drawn == true and rec.tall == true and X.large[rec.kind] == true and X.rowOn(rec) and Opt("portraitFade") == true
		and Opt("stripColour") == "gradient" and not ns.PartStopped(KEY, PART)
	if on then
		local r, g, b = ns.Colour("general.backdrop")
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
