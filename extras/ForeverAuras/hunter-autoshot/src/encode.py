"""Builds the ForeverAuras import string: LibSerialize (v1) + raw DEFLATE + LibDeflate EncodeForPrint, prefixed "!WA:2!".

The data comes from build.lua (run in Lua 5.1 through lupa). The string is decoded again by an independent
reader written from LibSerialize's _ReadObject, and every custom code block is compiled with Lua 5.1.
"""
import math
import os
import sys
import zlib

import lupa.lua51 as lua51

HERE = os.path.dirname(os.path.abspath(__file__))
ALPHABET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789()"

lua = lua51.LuaRuntime(unpack_returned_tuples=True)
lua.globals().BUILDDIR = HERE
lua.globals().read = lambda p: open(p, encoding="utf-8").read()


def to_py(v):
    """Lua value -> Python: dict for map tables, list for 1..n arrays, ("mixed", list, dict) otherwise."""
    if lua51.lua_type(v) == "table":
        items = list(v.items())
        arr, mp = {}, {}
        for k, val in items:
            if isinstance(k, float) and k.is_integer():
                k = int(k)
            (arr if isinstance(k, int) and not isinstance(k, bool) and k >= 1 else mp)[k] = to_py(val)
        n = 0
        while (n + 1) in arr:
            n += 1
        for k in list(arr):
            if k > n:
                mp[k] = arr.pop(k)
        lst = [arr[i] for i in range(1, n + 1)]
        if lst and mp:
            return ("mixed", lst, mp)
        if lst:
            return lst
        return mp
    if lua51.lua_type(v) is not None:
        raise TypeError("unsupported Lua value: %r" % lua51.lua_type(v))
    if isinstance(v, bytes):
        v = v.decode("utf-8")
    if isinstance(v, float) and v.is_integer():
        v = int(v)
    return v


def be(n, size):
    return n.to_bytes(size, "big")


def size_for(n):
    for size, limit in ((1, 1 << 8), (2, 1 << 16), (3, 1 << 24)):
        if n < limit:
            return size
    raise ValueError("too large")


def write(v, out):
    if v is None:
        out.append(0)
    elif v is True:
        out.append(12 * 8)
    elif v is False:
        out.append(13 * 8)
    elif isinstance(v, int):
        if 0 <= v < 128:
            out.append(v * 2 + 1)
        else:
            mag = abs(v)
            for size, pos in ((2, 1), (3, 3), (4, 5), (7, 7)):
                if mag < (1 << (8 * size)):
                    out.append(8 * (pos + (1 if v < 0 else 0)))
                    out += be(mag, size)
                    break
            else:
                raise ValueError(v)
    elif isinstance(v, float):
        assert math.isfinite(v)
        s = repr(abs(v)).encode()
        out.append(8 * (11 if v < 0 else 10))
        out.append(len(s))
        out += s
    elif isinstance(v, str):
        b = v.encode("utf-8")
        if len(b) < 16:
            out.append(16 * len(b) + 2)
        else:
            size = size_for(len(b))
            out.append(8 * {1: 14, 2: 15, 3: 16}[size])
            out += be(len(b), size)
        out += b
    elif isinstance(v, list):
        size = size_for(len(v))
        out.append(8 * {1: 20, 2: 21, 3: 22}[size])
        out += be(len(v), size)
        for x in v:
            write(x, out)
    elif isinstance(v, tuple) and v[0] == "mixed":
        _, lst, mp = v
        size = size_for(max(len(lst), len(mp)))
        out.append(8 * {1: 23, 2: 24, 3: 25}[size])
        out += be(len(lst), size) + be(len(mp), size)
        for x in lst:
            write(x, out)
        for k in sorted(mp, key=str):
            write(k, out)
            write(mp[k], out)
    elif isinstance(v, dict):
        size = size_for(len(v))
        out.append(8 * {1: 17, 2: 18, 3: 19}[size])
        out += be(len(v), size)
        for k in sorted(v, key=str):
            write(k, out)
            write(v[k], out)
    else:
        raise TypeError(type(v))


def serialize(v):
    out = bytearray([1])  # SERIALIZATION_VERSION
    write(v, out)
    return bytes(out)


class Reader:
    """Independent reader, following LibSerialize's _ReadObject and _ReaderTable."""

    def __init__(self, data):
        self.d, self.i = data, 0

    def take(self, n):
        b = self.d[self.i:self.i + n]
        assert len(b) == n, "truncated"
        self.i += n
        return b

    def int(self, n):
        return int.from_bytes(self.take(n), "big")

    def obj(self):
        v = self.int(1)
        if v % 2 == 1:
            return (v - 1) // 2
        if v % 4 == 2:
            typ = (v - 2) // 4
            count, typ = typ // 4, typ % 4
            if typ == 0:
                return self.take(count).decode("utf-8")
            if typ == 1:
                return self.table(count)
            if typ == 2:
                return [self.obj() for _ in range(count)]
            return self.mixed(count % 4 + 1, count // 4 + 1)
        if v % 8 == 4:
            packed = self.int(1) * 256 + v
            return -((packed - 12) // 16) if v % 16 == 12 else (packed - 4) // 16
        t = v // 8
        if t == 0:
            return None
        if 1 <= t <= 8:
            size = {1: 2, 2: 2, 3: 3, 4: 3, 5: 4, 6: 4, 7: 7, 8: 7}[t]
            n = self.int(size)
            return -n if t % 2 == 0 else n
        if t in (10, 11):
            f = float(self.take(self.int(1)).decode())
            return -f if t == 11 else f
        if t == 12:
            return True
        if t == 13:
            return False
        if t in (14, 15, 16):
            return self.take(self.int(t - 13)).decode("utf-8")
        if t in (17, 18, 19):
            return self.table(self.int(t - 16))
        if t in (20, 21, 22):
            return [self.obj() for _ in range(self.int(t - 19))]
        if t in (23, 24, 25):
            n = t - 22
            return self.mixed(self.int(n), self.int(n))
        raise ValueError("unexpected type %d at %d" % (t, self.i))

    def table(self, n):
        out = {}
        for _ in range(n):
            k = self.obj()
            out[k] = self.obj()
        return out

    def mixed(self, na, nm):
        lst = [self.obj() for _ in range(na)]
        return ("mixed", lst, self.table(nm))


def encode_for_print(b):
    out = []
    i = 0
    while i + 3 <= len(b):
        c = b[i] + b[i + 1] * 256 + b[i + 2] * 65536
        out += [ALPHABET[(c >> s) & 63] for s in (0, 6, 12, 18)]
        i += 3
    cache, bits = 0, 0
    while i < len(b):
        cache += b[i] << bits
        bits += 8
        i += 1
    while bits > 0:
        out.append(ALPHABET[cache & 63])
        cache >>= 6
        bits -= 6
    return "".join(out)


def decode_for_print(s):
    rev = {c: i for i, c in enumerate(ALPHABET)}
    out = bytearray()
    i = 0
    while i + 4 <= len(s):
        c = sum(rev[s[i + j]] << (6 * j) for j in range(4))
        out += bytes([c & 255, (c >> 8) & 255, (c >> 16) & 255])
        i += 4
    cache, bits = 0, 0
    while i < len(s):
        cache += rev[s[i]] << bits
        bits += 6
        i += 1
    while bits >= 8:
        out.append(cache & 255)
        cache >>= 8
        bits -= 8
    return bytes(out)


def norm(v):
    if isinstance(v, tuple):
        return ("mixed", [norm(x) for x in v[1]], norm(v[2]))
    if isinstance(v, list):
        return [norm(x) for x in v]
    if isinstance(v, dict):
        return {k: norm(x) for k, x in v.items()}
    return v


def main():
    data = to_py(lua.execute(open(os.path.join(HERE, "build.lua"), encoding="utf-8").read()))
    raw = serialize(data)
    c = zlib.compressobj(9, zlib.DEFLATED, -15)
    deflated = c.compress(raw) + c.flush()
    encoded = "!WA:2!" + encode_for_print(deflated)

    # Round trip the way Transmission.lua's StringToTable reads it.
    assert encoded.startswith("!WA:2!")
    back = Reader(zlib.decompress(decode_for_print(encoded[6:]), -15))
    assert back.int(1) == 1
    value = back.obj()
    assert back.i == len(back.d), "trailing bytes"
    assert norm(value) == norm(data), "round trip differs"

    # Compile every code block with Lua 5.1, as ForeverAuras does.
    check = lua.eval("function(src, name) local f, err = loadstring(src, name); return f ~= nil, err end")
    blocks = 0
    for child in data["c"]:
        trig = child["triggers"][1][0]["trigger"] if isinstance(child["triggers"], tuple) else child["triggers"][0]["trigger"]
        for src in ("return " + trig["custom"], "return function() return " + trig["customVariables"] + " end",
                    child["actions"].get("init", {}).get("custom")):
            if src:
                ok, err = check(src, child["id"])
                assert ok, "%s: %s" % (child["id"], err)
                blocks += 1

    with open(os.path.join(HERE, "..", "import.txt"), "w") as f:
        f.write(encoded)
    print("ok: %d bytes serialized, %d chars encoded, %d code blocks compiled" % (len(raw), len(encoded), blocks))


if __name__ == "__main__":
    sys.exit(main())
