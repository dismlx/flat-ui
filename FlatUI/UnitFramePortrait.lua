local ADDON_NAME, ns = ...

-- The options of the portrait on unit frames that work on top of UnitFrames.lua: Portrait border Class or reaction colour and None, on the border of the
-- picture or, with Frame style One frame, on the whole frame's border and the ring of a round picture, and the fade of the top of the picture into the
-- background colour beside a name row that fades. The style, the size, the shape, the switches of each kind of frame and the colours of states and kinds
-- are in UnitFrames.lua, in the functions that draw, lay out and colour the picture and the frame. This file adds its work after the steps of that file
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

-- Draws an outline with or without its plain line, and its rounded line with it (ns.UnitFrameExtra.bareOutline, UnitFrames.lua, where it has it).
local function Bare(outline, bare)
	if type(X.bareOutline) == "function" then
		X.bareOutline(outline, bare)
	else
		ns.SetOutlineBare(outline, bare)
	end
end

-- The outlines Portrait border colours: in one frame the frame's body and the picture, else the picture's border alone (ns.UnitFrameExtra.frameOutlines).
local function Outlines(rec)
	local list = type(X.frameOutlines) == "function" and X.frameOutlines(rec) or nil
	if type(list) ~= "table" then
		list = { rec.pic and rec.pic.outline }
	end
	return list
end

-- The border after UnitFrames.lua has coloured it for a state, a kind or a look: Class or reaction colour fills in only where none of those did (Muted
-- colours mutes it), and None draws the outline without its plain line unless a colour was given. With Separate parts it is the border of the picture,
-- while the frame shows Flat UI's picture. In one frame it is the whole frame's border and the ring of a round picture, whatever the picture is, and on a
-- frame with no picture (a boss frame) the colour that UnitFrames.lua gave the body just before this ran says whether a state or a kind coloured it.
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
	-- pairs, since a list may have a hole where an outline could not be made.
	for _, outline in pairs(list) do
		if border == "class" and not coloured then
			X.colourOutline(outline, r, g, b)
		end
		Bare(outline, border == "none" and not coloured)
	end
end

-- The colour of the plate behind the frame (ns.UnitFrameExtra.backColour: the Own background colour while Own border and background is on), else the
-- general background colour.
local function Back()
	if type(X.backColour) == "function" then
		local r, g, b = X.backColour()
		if ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
			return r, g, b
		end
	end
	return ns.Colour("general.backdrop")
end

-- The top of the picture beside a name row that fades upward takes the colour of the background behind the frame, as strong at the top as the row fades.
-- It is there only while the picture is drawn, is as tall as the frame, and the frame has a name row of that colour.
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
