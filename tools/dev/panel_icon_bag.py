#!/usr/bin/env python3

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
COLUMNS, ROWS = 8, 8
CELL = 64
INDEX = 39
SCALE = 16
STEP = 3.0
LANCZOS = getattr(Image, "Resampling", Image).LANCZOS

OUTLINE = 4.5
FLAP = 4.0
BUCKLE = 3.5

LEFT, RIGHT, TOP, BOTTOM = 17.0, 47.0, 17.0, 57.5
TOP_RADIUS, BOTTOM_RADIUS = 10.0, 6.0
MIDDLE = CELL / 2


def arc(cx, cy, radius, start, end):
    count = max(2, int(math.ceil(abs(end - start) / STEP)) + 1)
    points = []
    for i in range(count):
        angle = math.radians(start + (end - start) * i / (count - 1))
        points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    return points


def rounded(x0, y0, x1, y1, top, bottom):
    points = (arc(x1 - top, y0 + top, top, 270, 360) + arc(x1 - bottom, y1 - bottom, bottom, 0, 90)
              + arc(x0 + bottom, y1 - bottom, bottom, 90, 180) + arc(x0 + top, y0 + top, top, 180, 270))
    return points + points[:1]


def curve(start, control, end, t0, t1, count=24):
    points = []
    for i in range(count + 1):
        t = t0 + (t1 - t0) * i / count
        u = 1 - t
        points.append((u * u * start[0] + 2 * u * t * control[0] + t * t * end[0],
                       u * u * start[1] + 2 * u * t * control[1] + t * t * end[1]))
    return points


def mirrored(points):
    return [(CELL - x, y) for x, y in points]


def body_left(y):
    corner = BOTTOM - BOTTOM_RADIUS
    if y <= corner:
        return LEFT
    return LEFT + BOTTOM_RADIUS - math.sqrt(BOTTOM_RADIUS ** 2 - (y - corner) ** 2)


def backpack():
    body = rounded(LEFT, TOP, RIGHT, BOTTOM, TOP_RADIUS, BOTTOM_RADIUS)
    loop = [(MIDDLE - 4.5, TOP), (MIDDLE - 4.5, 12.0)] + arc(MIDDLE, 12.0, 4.5, 180, 360) + [(MIDDLE + 4.5, TOP)]
    buckle_left, buckle_right = MIDDLE - 4.0, MIDDLE + 4.0
    buckle = rounded(buckle_left, 30.0, buckle_right, 39.0, 1.5, 1.5)
    start, control, end = (LEFT, 28.0), (MIDDLE, 37.0), (RIGHT, 28.0)
    stop_left = (buckle_left - 0.5 - LEFT) / (RIGHT - LEFT)
    stop_right = (buckle_right + 0.5 - LEFT) / (RIGHT - LEFT)
    flap_left = curve(start, control, end, 0.0, stop_left)
    flap_right = curve(start, control, end, stop_right, 1.0)
    pocket = ([(LEFT, 39.0), (12.0, 39.0)] + arc(12.0, 42.5, 3.5, 270, 180) + arc(13.5, 50.0, 5.0, 180, 90)
              + [(body_left(55.0), 55.0)])
    return [(body, OUTLINE), (loop, OUTLINE), (pocket, OUTLINE), (mirrored(pocket), OUTLINE),
            (flap_left, FLAP), (flap_right, FLAP), (buckle, BUCKLE)]


def draw(strokes):
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


def patch(path, alpha):
    with open(path, "rb") as f:
        data = bytearray(f.read())
    if len(data) < 18:
        sys.exit("%s: too short for a TGA" % path)
    id_length, map_type, kind = data[0], data[1], data[2]
    map_length, map_depth = struct.unpack_from("<H", data, 5)[0], data[7]
    width, height = struct.unpack_from("<HH", data, 12)
    depth, descriptor = data[16], data[17]
    if kind != 2 or map_type != 0 or depth != 32 or (descriptor & 0x0F) != 8:
        sys.exit("%s: not an uncompressed 32-bit TGA with 8 bits of alpha (type %d, %d bits, descriptor 0x%02x)"
                 % (path, kind, depth, descriptor))
    if (width, height) != (COLUMNS * CELL, ROWS * CELL):
        sys.exit("%s: %d by %d, not the %d by %d atlas" % (path, width, height, COLUMNS * CELL, ROWS * CELL))
    start = 18 + id_length + map_length * ((map_depth + 7) // 8)
    if len(data) < start + width * height * 4:
        sys.exit("%s: shorter than its header says" % path)
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
            data[at:at + 4] = bytes((255, 255, 255, values[y * CELL + x]))
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
