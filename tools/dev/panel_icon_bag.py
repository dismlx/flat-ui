#!/usr/bin/env python3
"""panel_icon_bag.py: draws the backpack of the Bags page into cell 39 of FlatUI/Media/Panel.tga.

Panel.tga is the atlas of the options window's icons: 8 columns and 8 rows of 64 by 64 cells, white line art on
transparent, tinted in game with SetVertexColor (FlatUI/PanelNav.lua:15-21). Nav.Cell counts the cells from the top
left, row by row, and gives a cell its texture coordinates with row 0 at the top (FlatUI/PanelNav.lua:39-45), so
cell 39 is the last cell of the fifth row: column 7, row 4, pixels 448 to 511 across and 256 to 319 down. The game
shows a cell at 16 px in the sidebar (FlatUI/PanelNav.lua:303), 20 px on Home (FlatUI/PanelHome.lua:433) and 32 px in
the setup walk (FlatUI/SetupWalk.lua:743).

The script that drew the other cells is not in the repository (FlatUI/PanelNav.lua:15-17), so this one draws the way
the atlas itself shows they were drawn. A stroke is every point within half its width of a path, which gives round caps
and round joins; it is drawn 16 times larger and scaled down with Lanczos. That leaves the same edge as on the window of
cell 17: alpha 0, 1, 0, 17, 238, 255, 255, 238, 17, 0, 1, 0 across a 4 px stroke. The outline is 4.5 px, as on the
warning sign of cell 34 and the flask of cell 36 beside it in the fifth row, and the flap and the buckle inside it are
lighter, as the first rows draw their details lighter than their outlines (the lines in the chat bubble of cell 18, the
door of the house of cell 22). The drawing keeps 4 to 6 px from the edges of the cell, as the others do.

The drawing is a backpack: a body with a rounded top, a carry loop, a top flap fastened by a buckle, and a pocket on
each side, so that it reads as bags and not as the round pouch of Errands in cell 32. It is white, with its shape in
the alpha, as every other cell is.

Only cell 39 is written. The header, the size, the bit depth, the row order (the file keeps its bottom row first) and
every pixel outside the cell stay as they are. The cell is drawn whole, so running the script again gives the same
file. It needs Python 3 and Pillow. From the repository's root,

  python3 tools/dev/panel_icon_bag.py [--atlas FILE]
"""

import argparse
import math
import os
import shutil
import struct
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("panel_icon_bag.py needs Pillow: python3 -m pip install Pillow")

HERE = os.path.dirname(os.path.abspath(__file__))
ATLAS = os.path.join(os.path.dirname(os.path.dirname(HERE)), "FlatUI", "Media", "Panel.tga")
COLUMNS, ROWS = 8, 8    # as FlatUI/PanelNav.lua:21
CELL = 64               # the side of a cell, in pixels of the atlas
INDEX = 39              # the cell of the Bags page
SCALE = 16              # the drawing is made this many times larger, then scaled down
STEP = 3.0              # degrees between the points of an arc
# Pillow 9.1 moved the filters into Image.Resampling; older ones have them on Image.
LANCZOS = getattr(Image, "Resampling", Image).LANCZOS

# The widths of the strokes, in pixels of the cell.
OUTLINE = 4.5           # the body, the carry loop and the pockets
FLAP = 4.0              # the edge of the flap
BUCKLE = 3.5            # the buckle

# The body, by the middle of its outline: 17 to 47 across and 17 to 57.5 down, centred in the cell. Its upper corners
# have a radius of 10, which makes the rounded top of a backpack, and its lower ones 6.
LEFT, RIGHT, TOP, BOTTOM = 17.0, 47.0, 17.0, 57.5
TOP_RADIUS, BOTTOM_RADIUS = 10.0, 6.0
MIDDLE = CELL / 2


# The paths ------------------------------------------------------------------------------------------------------

def arc(cx, cy, radius, start, end):
    """The points of an arc round (cx, cy), from the angle start to end in degrees: 0 is to the right and 90 is down."""
    count = max(2, int(math.ceil(abs(end - start) / STEP)) + 1)
    points = []
    for i in range(count):
        angle = math.radians(start + (end - start) * i / (count - 1))
        points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    return points


def rounded(x0, y0, x1, y1, top, bottom):
    """A closed rectangle with round corners: radius top for the upper two, bottom for the lower two."""
    points = (arc(x1 - top, y0 + top, top, 270, 360) + arc(x1 - bottom, y1 - bottom, bottom, 0, 90)
              + arc(x0 + bottom, y1 - bottom, bottom, 90, 180) + arc(x0 + top, y0 + top, top, 180, 270))
    return points + points[:1]


def curve(start, control, end, t0, t1, count=24):
    """The points of the quadratic curve from start to end with the given control point, from t0 to t1."""
    points = []
    for i in range(count + 1):
        t = t0 + (t1 - t0) * i / count
        u = 1 - t
        points.append((u * u * start[0] + 2 * u * t * control[0] + t * t * end[0],
                       u * u * start[1] + 2 * u * t * control[1] + t * t * end[1]))
    return points


def mirrored(points):
    """The same path on the other side of the cell's middle."""
    return [(CELL - x, y) for x, y in points]


def body_left(y):
    """Where the middle of the body's left outline is at the height y, on its straight side or its lower corner."""
    corner = BOTTOM - BOTTOM_RADIUS
    if y <= corner:
        return LEFT
    return LEFT + BOTTOM_RADIUS - math.sqrt(BOTTOM_RADIUS ** 2 - (y - corner) ** 2)


def backpack():
    """The strokes of the backpack, as (points, width). Every line that meets the body ends on the middle of the body's
    outline, so its round end stays inside the body's stroke."""
    body = rounded(LEFT, TOP, RIGHT, BOTTOM, TOP_RADIUS, BOTTOM_RADIUS)
    # The carry loop: a half circle of radius 4.5 on two short legs, which stand on the flat part of the body's top
    # (27 to 37 across).
    loop = [(MIDDLE - 4.5, TOP), (MIDDLE - 4.5, 12.0)] + arc(MIDDLE, 12.0, 4.5, 180, 360) + [(MIDDLE + 4.5, TOP)]
    # The buckle, 8 by 9, hangs from the lowest part of the flap.
    buckle_left, buckle_right = MIDDLE - 4.0, MIDDLE + 4.0
    buckle = rounded(buckle_left, 30.0, buckle_right, 39.0, 1.5, 1.5)
    # The edge of the flap runs from side to side and sags 4.5 at the middle. Its control point is midway across, so
    # across the cell the curve moves evenly with t. Each half stops half a pixel outside the buckle's line, so its
    # round end (radius 2) stays in the buckle's stroke and the hole of the buckle stays clear.
    start, control, end = (LEFT, 28.0), (MIDDLE, 37.0), (RIGHT, 28.0)
    stop_left = (buckle_left - 0.5 - LEFT) / (RIGHT - LEFT)
    stop_right = (buckle_right + 0.5 - LEFT) / (RIGHT - LEFT)
    flap_left = curve(start, control, end, 0.0, stop_left)
    flap_right = curve(start, control, end, stop_right, 1.0)
    # A pocket on each side of the lower body, 8.5 out from the body's line, with a corner of 3.5 at the top and 5 at
    # the bottom. Its bottom line ends where it meets the body's lower corner.
    pocket = ([(LEFT, 39.0), (12.0, 39.0)] + arc(12.0, 42.5, 3.5, 270, 180) + arc(13.5, 50.0, 5.0, 180, 90)
              + [(body_left(55.0), 55.0)])
    return [(body, OUTLINE), (loop, OUTLINE), (pocket, OUTLINE), (mirrored(pocket), OUTLINE),
            (flap_left, FLAP), (flap_right, FLAP), (buckle, BUCKLE)]


# The drawing ----------------------------------------------------------------------------------------------------

def draw(strokes):
    """The alpha of the cell. A sample of a grid SCALE times finer is inked when it lies within half a stroke's width of
    one of the stroke's segments, which gives round caps and joins; Lanczos then scales the grid down to the cell."""
    side = CELL * SCALE
    ink = bytearray(side * side)
    for points, width in strokes:
        half = width / 2
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            dx, dy = x1 - x0, y1 - y0
            length2 = dx * dx + dy * dy
            left = max(0, int((min(x0, x1) - half) * SCALE))
            right = min(side, int(math.ceil((max(x0, x1) + half) * SCALE)) + 1)
            top = max(0, int((min(y0, y1) - half) * SCALE))
            bottom = min(side, int(math.ceil((max(y0, y1) + half) * SCALE)) + 1)
            for j in range(top, bottom):
                sy = (j + 0.5) / SCALE - y0
                row = j * side
                for i in range(left, right):
                    if ink[row + i]:
                        continue
                    sx = (i + 0.5) / SCALE - x0
                    t = (sx * dx + sy * dy) / length2 if length2 else 0.0
                    t = min(1.0, max(0.0, t))
                    ex, ey = sx - t * dx, sy - t * dy
                    if ex * ex + ey * ey <= half * half:
                        ink[row + i] = 255
    return Image.frombytes("L", (side, side), bytes(ink)).resize((CELL, CELL), LANCZOS)


# The atlas ------------------------------------------------------------------------------------------------------

def patch(path, alpha):
    """Writes alpha into cell INDEX of the TGA at path, in white, and leaves every other byte of the file as it was."""
    with open(path, "rb") as f:
        data = bytearray(f.read())
    if len(data) < 18:
        sys.exit("%s: too short for a TGA" % path)
    id_length, map_type, kind = data[0], data[1], data[2]
    map_length, map_depth = struct.unpack_from("<H", data, 5)[0], data[7]
    width, height = struct.unpack_from("<HH", data, 12)
    depth, descriptor = data[16], data[17]
    # Type 2 is uncompressed true colour; Panel.tga is that, with 32 bits a pixel, 8 of them alpha, and no colour map.
    if kind != 2 or map_type != 0 or depth != 32 or (descriptor & 0x0F) != 8:
        sys.exit("%s: not an uncompressed 32-bit TGA with 8 bits of alpha (type %d, %d bits, descriptor 0x%02x)"
                 % (path, kind, depth, descriptor))
    if (width, height) != (COLUMNS * CELL, ROWS * CELL):
        sys.exit("%s: %d by %d, not the %d by %d atlas" % (path, width, height, COLUMNS * CELL, ROWS * CELL))
    start = 18 + id_length + map_length * ((map_depth + 7) // 8)
    if len(data) < start + width * height * 4:
        sys.exit("%s: shorter than its header says" % path)
    # Bit 5 of the descriptor puts the top row first in the file, and bit 4 the right column first. Panel.tga has
    # neither (0x08), so the first row in the file is the bottom of the picture.
    top_first, right_first = descriptor & 0x20, descriptor & 0x10
    column, row = INDEX % COLUMNS, INDEX // COLUMNS
    values = alpha.tobytes()
    for y in range(CELL):
        picture_y = row * CELL + y
        file_y = picture_y if top_first else height - 1 - picture_y
        for x in range(CELL):
            picture_x = column * CELL + x
            file_x = width - 1 - picture_x if right_first else picture_x
            at = start + (file_y * width + file_x) * 4
            data[at:at + 4] = bytes((255, 255, 255, values[y * CELL + x]))    # blue, green, red, alpha
    # Written beside the atlas and moved over it, so a failed write leaves the old file whole.
    temporary = path + ".tmp"
    with open(temporary, "wb") as f:
        f.write(data)
    shutil.copymode(path, temporary)
    os.replace(temporary, path)


def main():
    parser = argparse.ArgumentParser(
        description="Draws the backpack of the Bags page into cell 39 of FlatUI/Media/Panel.tga.")
    parser.add_argument("--atlas", default=ATLAS, help="the atlas to write (default: %(default)s)")
    args = parser.parse_args()
    patch(args.atlas, draw(backpack()))
    print("%s: cell %d drawn (column %d, row %d)" % (args.atlas, INDEX, INDEX % COLUMNS, INDEX // COLUMNS))


if __name__ == "__main__":
    main()
