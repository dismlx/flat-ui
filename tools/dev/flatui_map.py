#!/usr/bin/env python3
"""flatui_map.py: the data of the Flat UI code map, and the page built from it.

Rebuilt at 0.5.15, after the generator the map was first made with (at 0.4.66) was lost. It reads the addon and
writes the same data as that one did, by the rules the old data states in its "gaps" and "checks":

  FlatUI/*.lua in the order of FlatUI/FlatUI.toc    files, lines, descriptions, functions, ns definitions, calls between
                                                   files (written as ns.Name) and the game names each file uses
  FlatUI/Config.lua, run by lua5.4 with a stub ns   every setting row and page (there is no settings.json any more)
  FlatUI_test.lua                                  the labels of check("label", ...) and what each check calls
  Forever's interface source and the client lists  which names are the game's frames, functions, events and CVars

Nothing of the addon is changed. It needs Python 3 and its standard library, lua5.4 for the settings dump, and git
for --fetch. The game names come from two repositories, which --fetch clones into tools/dev/sources, one commit deep,
or brings up to date:

  Forever's interface source   https://github.com/Gethe/wow-ui-source, branch forever: Interface/AddOns
  the client lists             https://github.com/wowless/wowless: data/products/wowf

From the repository's root,

  python3 tools/dev/flatui_map.py --fetch

writes tools/dev/out/data_<version>.json and tools/dev/out/flat-ui-map.html, the page with the data in it, which is
published in place of the last one. tools/dev/flatui_map_template.html is that page with __DATA__ where the data goes.
tools/dev/out and tools/dev/sources are left out of git.

  python3 tools/dev/flatui_map.py [--fetch] [--sources DIR] [--interface DIR] [--products DIR]
                                  [--repo DIR] [--out DIR] [--template FILE] [--lua LUA]
"""

import argparse
import collections
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULTS = {
    "repo": os.path.dirname(os.path.dirname(HERE)),
    "out": os.path.join(HERE, "out"),
    "template": os.path.join(HERE, "flatui_map_template.html"),
    "sources": os.path.join(HERE, "sources"),
}
# the repositories of the game names: the folder in --sources, the address, the branch, and the folder read in it
SOURCE_REPOS = (
    ("wow-ui-source", "https://github.com/Gethe/wow-ui-source.git", "forever", ("Interface", "AddOns")),
    ("wowless", "https://github.com/wowless/wowless.git", "main", ("data", "products", "wowf")),
)
VERSION_LABEL = "tools/dev/flatui_map.py"
CODE_MAX = 150      # a quoted line of code is cut at this many characters
DOC_MAX = 300       # a comment above a function is cut at this many characters
DOC_LINES = 6       # and only its last lines, the ones nearest the function, are read
EXAMPLES = 4        # places quoted per call pair or per game name


# ----------------------------------------------------------------------------------------------------------------
# Lua lexer
# ----------------------------------------------------------------------------------------------------------------

KEYWORDS = frozenset("and break do else elseif end false for function goto if in local nil not or repeat return then"
                     " true until while".split())
LONG_OPEN = re.compile(r"\[(=*)\[")
NAME_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
NUM_RE = re.compile(r"0[xX](?:[0-9a-fA-F]*\.?[0-9a-fA-F]*)(?:[pP][+-]?\d+)?|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?")
OPS = ("...", "..", "==", "~=", "<=", ">=", "<<", ">>", "//", "::")
ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v", "\\": "\\", '"': '"',
           "'": "'", "\n": "\n"}


class Tok(object):
    __slots__ = ("t", "v", "raw", "line", "eline", "pos", "i")

    def __init__(self, t, v, raw, line, eline, pos):
        self.t, self.v, self.raw, self.line, self.eline, self.pos = t, v, raw, line, eline, pos
        self.i = 0

    def __repr__(self):
        return "Tok(%s,%r,%d)" % (self.t, self.v, self.line)


class Comment(object):
    __slots__ = ("line", "eline", "text", "long", "pos", "alone")

    def __init__(self, line, eline, text, long_, pos, alone):
        self.line, self.eline, self.text, self.long, self.pos, self.alone = line, eline, text, long_, pos, alone


def decode_string(body):
    """The value of a short string literal from the text between its quotes."""
    out, i, n = [], 0, len(body)
    while i < n:
        c = body[i]
        if c != "\\":
            out.append(c)
            i += 1
            continue
        i += 1
        if i >= n:
            break
        c = body[i]
        if c in ESCAPES:
            out.append(ESCAPES[c])
            i += 1
        elif c == "z":
            i += 1
            while i < n and body[i] in " \t\r\n\f\v":
                i += 1
        elif c == "x":
            try:
                out.append(chr(int(body[i + 1:i + 3], 16)))
            except ValueError:
                pass
            i += 3
        elif c == "u":
            j = body.find("}", i)
            try:
                out.append(chr(int(body[i + 2:j], 16)))
            except ValueError:
                pass
            i = j + 1 if j > 0 else n
        elif c.isdigit():
            j = i
            while j < n and j < i + 3 and body[j].isdigit():
                j += 1
            try:
                out.append(chr(int(body[i:j])))
            except ValueError:
                pass
            i = j
        else:
            out.append(c)
            i += 1
    return "".join(out)


def lex(text):
    """Tokens and comments of a Lua source. Strings keep their source text in raw and their value in v."""
    toks, comments = [], []
    i, n, line = 0, len(text), 1
    last_code_line = 0
    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if c in " \t\r\f\v":
            i += 1
            continue
        if c == "-" and text.startswith("--", i):
            m = LONG_OPEN.match(text, i + 2)
            if m:
                close = "]" + m.group(1) + "]"
                j = text.find(close, m.end())
                j = n if j < 0 else j
                body = text[m.end():j]
                eline = line + body.count("\n")
                comments.append(Comment(line, eline, body, True, i, last_code_line != line))
                line = eline
                i = min(n, j + len(close))
                continue
            j = text.find("\n", i)
            j = n if j < 0 else j
            comments.append(Comment(line, line, text[i + 2:j], False, i, last_code_line != line))
            i = j
            continue
        start, sline = i, line
        if c.isalpha() or c == "_":
            m = NAME_RE.match(text, i)
            w = m.group(0)
            toks.append(Tok("kw" if w in KEYWORDS else "name", w, w, line, line, start))
            i = m.end()
        elif c.isdigit() or (c == "." and i + 1 < n and text[i + 1].isdigit()):
            m = NUM_RE.match(text, i)
            j = m.end() if m and m.end() > i else i + 1
            toks.append(Tok("num", text[i:j], text[i:j], line, line, start))
            i = j
        elif c == '"' or c == "'":
            j = i + 1
            while j < n:
                d = text[j]
                if d == "\\":
                    if j + 1 < n and text[j + 1] == "\n":
                        line += 1
                    elif j + 1 < n and text[j + 1] == "z":
                        k = j + 2
                        while k < n and text[k] in " \t\r\n\f\v":
                            if text[k] == "\n":
                                line += 1
                            k += 1
                        j = k
                        continue
                    j += 2
                    continue
                if d == c or d == "\n":
                    break
                j += 1
            body = text[i + 1:j]
            toks.append(Tok("str", decode_string(body), body, sline, line, start))
            i = j + 1
        elif c == "[" and LONG_OPEN.match(text, i):
            m = LONG_OPEN.match(text, i)
            close = "]" + m.group(1) + "]"
            j = text.find(close, m.end())
            j = n if j < 0 else j
            body = text[m.end():j]
            if body.startswith("\r\n"):
                body = body[2:]
            elif body.startswith("\n"):
                body = body[1:]
            line += text.count("\n", i, j)
            toks.append(Tok("str", body, body, sline, line, start))
            i = min(n, j + len(close))
        else:
            for op in OPS:
                if text.startswith(op, i):
                    break
            else:
                op = c
            toks.append(Tok("op", op, op, line, line, start))
            i += len(op)
        last_code_line = line
    toks.append(Tok("eof", "", "", line, line, n))
    for k, t in enumerate(toks):
        t.i = k
    return toks, comments


# ----------------------------------------------------------------------------------------------------------------
# One Lua file
# ----------------------------------------------------------------------------------------------------------------

CLOSE_OF = {"(": ")", "[": "]", "{": "}"}


class LuaFile(object):
    def __init__(self, path, rel, mid, text):
        self.path, self.rel, self.id, self.text = path, rel, mid, text
        self.lines = text.split("\n")
        if self.lines and self.lines[-1] == "":
            self.lines.pop()
        self.toks, self.comments = lex(text)
        self.comment_lines = {}
        for c in self.comments:
            if not c.long:
                self.comment_lines.setdefault(c.line, c)
        self._structure()
        self.functions = []
        self.fn_spans = []

    # brackets ( [ { and blocks function/do/if/repeat, their partners, and the innermost one open at each token
    def _structure(self):
        self.partner, self.block_end, self.block_start = {}, {}, {}
        self.container = [None] * len(self.toks)
        stack = []
        for t in self.toks:
            self.container[t.i] = stack[-1] if stack else None
            if t.t == "op":
                if t.v in CLOSE_OF:
                    stack.append(t.i)
                elif t.v in (")", "]", "}"):
                    for depth in range(len(stack) - 1, -1, -1):
                        o = self.toks[stack[depth]]
                        if o.t == "op" and CLOSE_OF[o.v] == t.v:
                            del stack[depth:]
                            self.partner[o.i] = t.i
                            self.partner[t.i] = o.i
                            break
            elif t.t == "kw":
                if t.v in ("function", "do", "if", "repeat"):
                    stack.append(t.i)
                elif t.v in ("end", "until"):
                    for depth in range(len(stack) - 1, -1, -1):
                        o = self.toks[stack[depth]]
                        if o.t == "kw":
                            del stack[depth:]
                            self.block_end[o.i] = t.i
                            self.block_start[t.i] = o.i
                            break
        self.unclosed = len(stack)

    def code(self, line):
        s = self.lines[line - 1].strip() if 0 < line <= len(self.lines) else ""
        return s if len(s) <= CODE_MAX else s[:CODE_MAX - 3] + "..."

    def at(self, line):
        return "%s:%d" % (self.rel, line)


# ----------------------------------------------------------------------------------------------------------------
# Functions
# ----------------------------------------------------------------------------------------------------------------

def dotted_back(toks, k):
    """The dotted name (a.b.c or a.b:c) that ends at token k, read backwards, and the index of its first token."""
    parts = []
    j = k
    if toks[j].t != "name":
        return None, k
    parts.append(toks[j].v)
    while j >= 2 and toks[j - 1].t == "op" and toks[j - 1].v in (".", ":") and toks[j - 2].t == "name":
        parts.append(toks[j - 1].v)
        parts.append(toks[j - 2].v)
        j -= 2
    parts.reverse()
    return "".join(parts), j


def callee_before(f, open_i):
    """The name a call shows for its argument list opening at token open_i: a.b.c for a plain call, the method name
    for obj:method(...) and for a call on the result of another call or index, or None when the bracket opens no call."""
    toks = f.toks
    k = open_i - 1
    if k < 0:
        return None
    p = toks[k]
    if p.t == "name":
        name, j = dotted_back(toks, k)
        if ":" in name:
            return name.rsplit(":", 1)[1]
        if j >= 1 and toks[j - 1].t == "op" and toks[j - 1].v in (".", ":"):
            return name.split(".")[-1]
        return name
    if p.t == "op" and p.v in (")", "]"):
        return ""
    return None


def first_string(f, a, b):
    """The source text of the first string literal between token indexes a and b."""
    for t in f.toks[a:b]:
        if t.t == "str":
            return t.raw
    return None


def find_functions(f, locals_declared):
    """Every function of the file, named by the way it is declared."""
    toks = f.toks
    out = []
    for t in toks:
        if t.t != "kw" or t.v != "function":
            continue
        k = t.i
        prev = toks[k - 1] if k > 0 else None
        nxt = toks[k + 1]
        kind = name = None
        params_open = None
        if prev is not None and prev.t == "kw" and prev.v == "local" and nxt.t == "name":
            kind, name, params_open = "local", nxt.v, k + 2
        elif nxt.t == "name":
            # function a.b.c:d(...) statement
            parts, j = [nxt.v], k + 2
            while toks[j].t == "op" and toks[j].v in (".", ":") and toks[j + 1].t == "name":
                parts.append(toks[j].v)
                parts.append(toks[j + 1].v)
                j += 2
            full = "".join(parts)
            params_open = j
            if full.startswith("ns.") and len(parts) > 1:
                kind, name = "ns", full[3:]
            elif len(parts) == 1:
                kind, name = "local", full
            else:
                kind, name = "table", full
        else:
            params_open = k + 1
            kind, name = expression_name(f, k, locals_declared)
        close = f.partner.get(params_open)
        args = ""
        if close is not None and toks[params_open].v == "(":
            args = ", ".join(x.v for x in toks[params_open + 1:close] if x.t == "name" or x.v == "...")
        end_i = f.block_end.get(k)
        end_line = toks[end_i].line if end_i is not None else t.line
        rec = {"name": name, "kind": kind, "line": t.line}
        if end_line != t.line:
            rec["end"] = end_line
        if args:
            rec["args"] = args
        if kind in ("local", "table", "ns", "field"):
            doc = doc_above(f, statement_line(f, k))
            if doc:
                rec["doc"] = doc
        rec["_tok"] = k
        rec["_end_tok"] = end_i if end_i is not None else k
        out.append(rec)
    return out


def statement_line(f, k):
    """The line the declaration of the function at token k starts on (its local keyword or its name)."""
    toks = f.toks
    j = k
    if j > 0 and toks[j - 1].t == "kw" and toks[j - 1].v == "local":
        return toks[j - 1].line
    return toks[k].line


def doc_above(f, line):
    """The comment lines just above a line, joined, without a blank line between."""
    parts = []
    ln = line - 1
    while ln >= 1 and len(parts) < DOC_LINES:
        c = f.comment_lines.get(ln)
        if c is None or not c.alone:
            break
        parts.append(c.text)
        ln -= 1
    if not parts:
        return ""
    parts.reverse()
    text = " ".join(p.strip() for p in parts if p.strip()).strip()
    return text[:DOC_MAX]


def expression_name(f, k, locals_declared):
    """The name of a function written as an expression at token k."""
    toks = f.toks
    prev = toks[k - 1]
    if prev.t == "kw" and prev.v == "return":
        return "anonymous", "returned function"
    if prev.t == "op" and prev.v == "=":
        lhs = toks[k - 2]
        if lhs.t == "op" and lhs.v == "]":
            return "field", "[...]"
        if lhs.t == "name":
            name, j = dotted_back(toks, lhs.i)
            c = f.container[j]
            if c is not None and toks[c].v == "{" and "." not in name and ":" not in name:
                return "field", name
            if j >= 1 and toks[j - 1].t == "op" and toks[j - 1].v in (".", ":"):
                return "table", name
            if name.startswith("ns.") and name.count(".") >= 1:
                return "ns", name[3:]
            if "." in name or ":" in name:
                return "table", name
            return "local", name
        return "anonymous", "unnamed function"
    c = f.container[k]
    if c is None or toks[c].v != "(":
        return "anonymous", "unnamed function"
    # an argument of a call: only the first function among the arguments is its callback
    for x in toks[c + 1:k]:
        if x.t == "kw" and x.v == "function" and f.container[x.i] == c:
            return "anonymous", "unnamed function"
    callee = callee_before(f, c)
    if callee is None:
        return "anonymous", "unnamed function"
    s = first_string(f, c + 1, k)
    label = callee if callee else "call"
    if s is not None:
        label += '("%s")' % s
    return "callback", label + " callback"


# ----------------------------------------------------------------------------------------------------------------
# Definitions on ns
# ----------------------------------------------------------------------------------------------------------------

def ns_definitions(f):
    """What the file puts on ns: function ns.X (function), ns.X = function (function), ns.X = ns.X or ... (declare),
    ns.X = { (table), ns.X = Name (alias), anything else (value). A name the file keeps in a local and puts back
    (local old = ns.X ... ns.X = old) is a wrap, not a definition."""
    toks = f.toks
    out = []
    saved = {}      # local name -> ns name read into it
    for t in toks:
        if t.t == "kw" and t.v == "local":
            # local a = ns.X
            j = t.i + 1
            if toks[j].t == "name" and toks[j + 1].v == "=" and toks[j + 2].v == "ns" and toks[j + 3].v == "." \
                    and toks[j + 4].t == "name" and toks[j + 5].v not in (".", ":", "(", "["):
                saved[toks[j].v] = toks[j + 4].v
    wrapped = set()
    for t in toks:
        if t.v == "ns" and t.t == "name" and toks[t.i + 1].v == "." and toks[t.i + 2].t == "name" and toks[t.i + 3].v == "=":
            r = toks[t.i + 4]
            if r.t == "name" and saved.get(r.v) == toks[t.i + 2].v:
                wrapped.add(r.v and toks[t.i + 2].v)
    for t in toks:
        if t.t == "kw" and t.v == "function" and toks[t.i + 1].v == "ns" and toks[t.i + 2].v == "." \
                and toks[t.i + 3].t == "name":
            out.append({"name": toks[t.i + 3].v, "kind": "function", "line": t.line, "_tok": t.i + 1})
            continue
        if not (t.t == "name" and t.v == "ns" and toks[t.i + 1].v == "." and toks[t.i + 2].t == "name"
                and toks[t.i + 3].v == "="):
            continue
        if t.i > 0 and toks[t.i - 1].v in (".", ":"):
            continue
        name = toks[t.i + 2].v
        if name in wrapped:
            continue
        r = toks[t.i + 4]
        if r.t == "kw" and r.v == "function":
            kind = "function"
        elif r.v == "ns" and toks[r.i + 1].v == "." and toks[r.i + 2].v == name and toks[r.i + 3].v == "or":
            kind = "declare"
        elif r.v == "{":
            kind = "table"
        elif r.t == "name" and (toks[r.i + 1].line != r.line or toks[r.i + 1].t == "eof" or toks[r.i + 1].v == ";"):
            kind = "alias"
        else:
            kind = "value"
        out.append({"name": name, "kind": kind, "line": t.line, "_tok": t.i})
    out.sort(key=lambda x: x["line"])
    return out


def ns_uses(f, defined_here):
    """Every ns.Name the file writes, as (name, token index), leaving out the places that define a name."""
    toks = f.toks
    out = []
    for t in toks:
        if t.t == "name" and t.v == "ns" and toks[t.i + 1].v == "." and toks[t.i + 2].t == "name":
            if t.i > 0 and toks[t.i - 1].v in (".", ":"):
                continue
            if t.i in defined_here:
                continue
            out.append((toks[t.i + 2].v, t.i))
    return out


def enclosing_names(f, functions):
    """The named functions of the file as (first line, last line, token, name), for name_at."""
    spans = []
    for r in functions:
        if r["kind"] in ("callback", "anonymous"):
            continue
        spans.append((r["line"], r.get("end", r["line"]), r["_tok"], r["name"]))
    spans.sort()
    return spans


def name_at(spans, line):
    """The innermost named function whose lines hold this line, or ''."""
    best = ""
    for a, b, _, name in spans:
        if a > line:
            break
        if b >= line:
            best = name
    return best


# ----------------------------------------------------------------------------------------------------------------
# Settings: Config.lua run by lua5.4 with a stub ns
# ----------------------------------------------------------------------------------------------------------------

DUMP_LUA = r'''
-- Runs FlatUI/Config.lua with a stub ns and writes every page and row of ns.PAGES as JSON.
local path = ...
local ns = setmetatable({}, { __index = function() return nil end })
local chunk = assert(loadfile(path))
chunk("FlatUI", ns)
local function esc(s)
  return (s:gsub('[%c"\\]', function(c)
    if c == "\n" then return "\\n" elseif c == "\t" then return "\\t" elseif c == '"' then return '\\"'
    elseif c == "\\" then return "\\\\" end
    return string.format("\\u%04x", c:byte())
  end))
end
local function enc(v)
  local t = type(v)
  if t == "string" then return '"' .. esc(v) .. '"'
  elseif t == "boolean" then return tostring(v)
  elseif t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return "null" end
    if math.type(v) == "integer" then return tostring(v) end
    if v == math.floor(v) and math.abs(v) < 2^53 then return string.format("%d", v) end
    return string.format("%.17g", v)
  elseif t == "table" then
    local parts = {}
    if #v > 0 then
      for _, x in ipairs(v) do parts[#parts + 1] = enc(x) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do if type(k) == "string" then keys[#keys + 1] = k end end
    table.sort(keys)
    for _, k in ipairs(keys) do parts[#parts + 1] = enc(k) .. ":" .. enc(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "null"
end
local PAGE_FIELDS = { "key", "label", "parent", "owner", "switch", "tabLabel", "group" }
local ROW_FIELDS = { "key", "kind", "label", "default", "tip", "needs", "page", "min", "max", "step", "unit", "cvar",
  "changed", "items", "pick", "get", "set", "live", "none", "reload", "scale" }
local out = {}
for pi, page in ipairs(ns.PAGES or {}) do
  local p = {}
  for _, k in ipairs(PAGE_FIELDS) do
    local v = page[k]
    if type(v) == "string" or type(v) == "number" or type(v) == "boolean" then p[#p + 1] = enc(k) .. ":" .. enc(v) end
  end
  local rows, section = {}, nil
  for _, row in ipairs(page) do
    if type(row) == "table" then
      if row.section ~= nil and row.key == nil then
        section = row.section
      elseif row.key ~= nil then
        local r = {}
        for _, k in ipairs(ROW_FIELDS) do
          local v = row[k]
          if type(v) == "string" or type(v) == "number" or type(v) == "boolean" then r[#r + 1] = enc(k) .. ":" .. enc(v) end
        end
        if type(row.default) == "table" then r[#r + 1] = '"default":' .. enc(row.default) end
        if type(row.needsIn) == "table" then r[#r + 1] = '"needsIn":' .. enc(row.needsIn) end
        if type(row.choices) == "string" then
          r[#r + 1] = '"choices":' .. enc(row.choices)
        elseif type(row.choices) == "table" then
          local cs = {}
          for _, c in ipairs(row.choices) do
            if type(c) == "table" then cs[#cs + 1] = "[" .. enc(c[1]) .. "," .. enc(c[2] == nil and c[1] or c[2]) .. "]" end
          end
          r[#r + 1] = '"choices":[' .. table.concat(cs, ",") .. "]"
        end
        if type(section) == "string" then r[#r + 1] = '"section":' .. enc(section) end
        rows[#rows + 1] = "{" .. table.concat(r, ",") .. "}"
      end
    end
  end
  p[#p + 1] = '"rows":[' .. table.concat(rows, ",") .. "]"
  out[#out + 1] = "{" .. table.concat(p, ",") .. "}"
end
io.write("[" .. table.concat(out, ",\n") .. "]\n")
'''


def dump_config(config_path, lua="lua5.4"):
    """ns.PAGES of Config.lua as a list of pages, each with its rows, by running the file with a stub ns."""
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False) as tf:
        tf.write(DUMP_LUA)
        script = tf.name
    try:
        res = subprocess.run([lua, script, config_path], capture_output=True, text=True, timeout=120)
    except FileNotFoundError:
        raise SystemExit("%s was not found: Config.lua is read by running it with Lua 5.4 (--lua names another)" % lua)
    finally:
        os.unlink(script)
    if res.returncode != 0:
        raise SystemExit("Config.lua could not be dumped with %s: %s" % (lua, res.stderr.strip()))
    return json.loads(res.stdout)


def module_keys(f):
    """The module keys of a file, in order: the value of local KEY = "x" and the keys of ns.Register("x", ...).
    Returns (keys, registered) where registered are the keys this file passes to ns.Register."""
    toks = f.toks
    keys, registered = [], []
    consts = {}
    for t in toks:
        if t.t == "kw" and t.v == "local":
            names, j = [], t.i + 1
            while toks[j].t == "name":
                names.append(toks[j].v)
                if toks[j + 1].v == ",":
                    j += 2
                else:
                    j += 1
                    break
            if toks[j].v == "=" and names:
                vals, k = [], j + 1
                while len(vals) < len(names):
                    if toks[k].t == "str" and toks[k + 1].v in (",", ";") or (toks[k].t == "str" and toks[k + 1].line != toks[k].line) \
                            or (toks[k].t == "str" and toks[k + 1].t in ("kw", "name", "eof")):
                        vals.append(toks[k].v)
                    else:
                        vals.append(None)
                    if toks[k + 1].v == ",":
                        k += 2
                    else:
                        break
                for n, v in zip(names, vals):
                    if v is not None and f.container[t.i] is None:
                        consts.setdefault(n, v)
                        if n == "KEY" and v not in keys:
                            keys.append(v)
    for t in toks:
        if t.t == "name" and t.v == "ns" and toks[t.i + 1].v == "." and toks[t.i + 2].v == "Register" \
                and toks[t.i + 3].v == "(":
            a = toks[t.i + 4]
            v = a.v if a.t == "str" else consts.get(a.v) if a.t == "name" else None
            if v is not None:
                if v not in keys:
                    keys.append(v)
                if v not in registered:
                    registered.append(v)
    return keys, registered, consts


def is_setup_file(mid):
    return mid.startswith("Setup")


# The fields of a row that name a function of ns, and the order in which the ways a file names a row are shown: a file
# that writes the row's path shows "path" even when it also defines the row's changed function (0.4.66 data: Scale on
# general.scaleOn; ButtonText and ButtonStates show "key" for rows whose changed function they define).
HANDLER_FIELDS = ("changed", "choices", "get", "set")
WAY_ORDER = ("path", "key", "changed", "choices", "get", "set")


def attribute_settings(rows, files, order):
    """Who names each setting row and which file owns it.

    A file names a row by its saved path written as a string, by its key written as a string when the file has the
    row's module key (local KEY or ns.Register), or by a function of ns it defines that the row names (changed, the
    function its choices name, get or set). Setup files only use rows, but for the rows saved under setup. The way
    shown is the first of path, key, changed, choices, get and set that applies.

    A row of a module goes to the file that defines its changed function, else the one that defines its choices
    function, else a file with the module key (the one that registers the module first, then TOC order). A row that no
    such file names "matched only files that do not own them": the file that registers its module is listed with it,
    and it goes to the first file that writes its path, else to that file (0.4.66 data: unitframes.playerScale went to
    Movers, which writes its path and defines its get and set functions, with UnitFrames listed by its module). A row
    saved under a name that no file registers (general, and setup and panel, which rows of the Flat UI page are saved
    under) goes to the file that holds its value (defines its get or set function: Setup for setup.newCharacter in
    0.4.66), else the first file in TOC order that writes its path, else one that names it by a function, else the
    first that writes its key, else Core; it shows "module".

    shared_with is the number of files that name the row, less one, for every file listed with it (0.4.66 data: also
    for the file listed only because it registers the module).

    rows: dicts with path, key, module and the handler fields. files: id -> LuaFile with .strings, .mkeys,
    .registered, .defined_fns. Returns {path: [(file id, role, found_by, shared_with)]}, the number of rows that
    matched only files that do not own them, and the number that no file names."""
    toc = {mid: i for i, mid in enumerate(order)}
    registers = {}
    for mid in order:
        for k in files[mid].registered:
            registers.setdefault(k, mid)
    result, fallback_rows, unmatched = {}, 0, 0
    for r in rows:
        path, key, mod = r["path"], r["key"], r["module"]
        named = {}
        for mid in order:
            f = files[mid]
            ways = set()
            if path in f.strings:
                ways.add("path")
            if key in f.strings and mod in f.mkeys:
                ways.add("key")
            for field in HANDLER_FIELDS:
                fn = r.get(field)
                if isinstance(fn, str) and fn in f.defined_fns:
                    ways.add(field)
            if ways:
                named[mid] = [w for w in WAY_ORDER if w in ways]
        if not named:
            unmatched += 1
        entries = {mid: ways[0] for mid, ways in named.items()}
        reg = registers.get(mod)

        def may_own(mid):
            return not is_setup_file(mid) or (reg is None and mod == "setup")

        def holds(mid, fields):
            return any(w in named[mid] for w in fields)

        owner = owner_way = None
        if reg is None:
            # a row saved under a name that no file registers
            pool = [mid for mid in order if mid in named and may_own(mid) and holds(mid, ("get", "set"))]
            pool = pool or [mid for mid in order if mid in named and may_own(mid) and "path" in named[mid]]
            pool = pool or [mid for mid in order if mid in named and may_own(mid)]
            pool = pool or [mid for mid in order if may_own(mid) and key in files[mid].strings]
            owner = pool[0] if pool else ("Core" if "Core" in files else order[0])
            owner_way = "module"
            entries[owner] = "module"
        else:
            def level(mid):
                if not may_own(mid):
                    return None
                if holds(mid, ("changed",)):
                    return 0
                if holds(mid, ("choices",)):
                    return 1
                if mod in files[mid].mkeys:
                    return 2
                return None
            best = sorted((lv, mid != reg, toc[mid], mid) for mid in named for lv in [level(mid)] if lv is not None)
            if best:
                owner = best[0][3]
                owner_way = named[owner][0]
            else:
                fallback_rows += 1
                writers = [mid for mid in order if mid in named and may_own(mid) and "path" in named[mid]]
                if reg not in named:
                    entries[reg] = "module"
                if writers:
                    owner = writers[0]
                    owner_way = named[owner][0]
                else:
                    owner, owner_way = reg, "module"
                    entries[reg] = "module"
        shared = max(0, len(named) - 1)
        out = []
        for mid in sorted(entries, key=lambda m: toc[m]):
            role = "owns" if mid == owner else "uses"
            way = owner_way if mid == owner else entries[mid]
            out.append((mid, role, way, shared))
        result[path] = out
    return result, fallback_rows, unmatched


# ----------------------------------------------------------------------------------------------------------------
# Tests: the labels of check("label", ...) in FlatUI_test.lua
# ----------------------------------------------------------------------------------------------------------------

def read_tests(path):
    """Every check("label", ...) of the test file: [(label, line, set of ns names the call writes)], in file order."""
    text = open(path, encoding="utf-8", errors="replace").read()
    f = LuaFile(path, os.path.basename(path), "test", text)
    toks = f.toks
    out = []
    for t in toks:
        if t.t == "name" and t.v == "check" and toks[t.i + 1].v == "(" and toks[t.i + 2].t == "str" \
                and (t.i == 0 or toks[t.i - 1].v not in (".", ":", "function", "local")):
            close = f.partner.get(t.i + 1)
            if close is None:
                continue
            # what the check calls: every ns.Name written in the call after its label, W.ns.Name too
            refs = set(NS_REF.findall(text, toks[t.i + 3].pos, toks[close].pos + 1))
            out.append((toks[t.i + 2].v, t.line, refs))
    return out


NS_REF = re.compile(r"\bns\.([A-Za-z_][A-Za-z0-9_]*)")


def label_prefix(label):
    return label.split(":", 1)[0].strip() if ":" in label else ""


def test_links(labels, mid, mkeys, defined):
    """The labels listed for a module: by key (the prefix is a module key or the file name, or the label names the
    file) and by reference (the check writes ns.Name for a function the file defines)."""
    names = {k.lower() for k in mkeys} | {mid.lower()}
    fname = mid + ".lua"
    key_idx, ref_idx = [], []
    for i, (label, line, refs) in enumerate(labels):
        pre = label_prefix(label).lower()
        if pre in names or fname in label:
            key_idx.append(i)
        elif refs & defined:
            ref_idx.append(i)
    counts = collections.Counter()
    for i in key_idx + ref_idx:
        pre = label_prefix(labels[i][0])
        if pre:
            counts[pre] += 1
    top = [{"prefix": p, "labels": c} for p, c in sorted(counts.items(), key=lambda x: (-x[1], x[0]))[:6]]
    return {"labels_by_key": len(key_idx), "labels_by_reference": len(ref_idx), "top_prefixes": top,
            "key_labels": key_idx, "ref_labels": ref_idx}


# ----------------------------------------------------------------------------------------------------------------
# Game names: what the game client has, from its lists and Forever's own interface source
# ----------------------------------------------------------------------------------------------------------------

# Lua's own library and the string, table and math shortcuts the client adds: not the game's API.
LUA_STD = frozenset("""assert collectgarbage error getmetatable ipairs next pairs pcall print rawequal rawget rawlen rawset
select setmetatable tonumber tostring type unpack xpcall getfenv setfenv loadstring newproxy gcinfo require load dofile
strsplit strjoin strconcat strtrim strlen strsub strfind strmatch strupper strlower strrep strbyte strchar strrev format
gsub gmatch tinsert tremove tContains wipe sort abs floor ceil min max sqrt random mod exp log fmod frexp ldexp
strsplittable strlenutf8 strcmputf8i tostringall bit math string table coroutine os debug utf8 _G _VERSION""".split())
# Words of the client's object model, mouse buttons and the like: shaped like frame names but no frame.
NOT_FRAMES = frozenset("""Frame Button CheckButton ScrollFrame MessageFrame ScrollingMessageFrame EditBox StatusBar Slider
ColorSelect Cooldown GameTooltip Minimap Model ModelScene PlayerModel DressUpModel SimpleHTML Texture FontString
LeftButton RightButton MiddleButton Button4 Button5 AnyUp AnyDown""".split())
FRAME_SHAPE = re.compile(r"^[A-Z][A-Za-z0-9_]*?(?:Frame|Button|Bar|Container|Tooltip|Popup|Panel|Tab|Dialog|Window|Cluster)\d*$")
CVAR_FUNCS = {"GetCVar", "SetCVar", "GetCVarBool", "GetCVarDefault", "GetCVarInfo", "C_CVar.GetCVar", "C_CVar.SetCVar",
              "C_CVar.GetCVarBool", "C_CVar.GetCVarDefault", "C_CVar.GetCVarInfo", "C_CVar.RegisterCVar", "C_CVar.ResetTestCVars"}
SECURE_CALLS = {"SecureHandlerWrapScript", "SecureHandlerUnwrapScript", "SecureHandlerSetFrameRef", "SecureHandlerExecute"}
SECURE_METHODS = {"SetAttribute": True, "SetFrameRef": True, "Execute": False, "WrapScript": False, "UnwrapScript": False}
STATE_DRIVERS = {"RegisterStateDriver", "RegisterAttributeDriver"}
CVAR_NAMES = {"GetCVar", "SetCVar", "GetCVarBool", "GetCVarDefault", "GetCVarInfo"}


class Client(object):
    """The names the game client has: functions, events, CVars and frames."""

    def __init__(self, interface_dir, products_dir):
        self.api, self.events, self.cvars, self.frames, self.frame_prefixes = set(), set(), set(), set(), set()
        self.sources = []
        self._products(products_dir)
        self._interface(interface_dir)
        self.api -= LUA_STD

    def _products(self, d):
        def keys(name):
            p = os.path.join(d, name)
            if not os.path.exists(p):
                return set()
            self.sources.append(p)
            return set(re.findall(r"^([A-Za-z_][\w.]*):", open(p, encoding="utf-8").read(), re.M))
        self.api |= keys("apis.yaml")
        self.events |= keys("events.yaml")
        self.cvars |= {c.lower() for c in keys("cvars.yaml")}

    def _interface(self, root):
        if not os.path.isdir(root):
            return
        self.sources.append(root)
        doc_dir = os.path.join(root, "Blizzard_APIDocumentationGenerated")
        for dp, dn, fn in os.walk(root):
            dn.sort()
            for name in sorted(fn):
                p = os.path.join(dp, name)
                if name.endswith(".lua"):
                    text = open(p, encoding="utf-8", errors="replace").read()
                    if dp.startswith(doc_dir):
                        self._doc(text)
                        continue
                    for m in re.finditer(r"^function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", text, re.M):
                        self.api.add(m.group(1))
                    for m in re.finditer(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?:function\b|C_\w+\.\w+\s*$|C_\w+\.\w+\s*;)", text, re.M):
                        self.api.add(m.group(1))
                    for m in re.finditer(r"CreateFrame\(\s*\"\w+\"\s*,\s*\"([A-Za-z_][A-Za-z0-9_]*)\"", text):
                        self.frames.add(m.group(1))
                    for m in re.finditer(r"^([A-Z][A-Za-z0-9_]*)\s*=\s*[A-Za-z_][\w.:]*\(", text, re.M):
                        self.frames.add(m.group(1))
                elif name.endswith(".xml"):
                    text = open(p, encoding="utf-8", errors="replace").read()
                    for m in re.finditer(r"<(\w+)\b([^>]*)>", text):
                        attrs = m.group(2)
                        if 'virtual="true"' in attrs or m.group(1) in ("Font", "FontFamily", "Include", "Script"):
                            continue
                        n = re.search(r'\bname="([A-Za-z_][A-Za-z0-9_]*)"', attrs)
                        if n:
                            self.frames.add(n.group(1))
                        k = re.search(r'\bparentKey="([A-Za-z_][A-Za-z0-9_]*)"', attrs)
                        if k:
                            self.frame_prefixes.add(k.group(1))
        for n in list(self.frames):
            m = re.match(r"^(.*?[A-Za-z_])\d+$", n)
            if m:
                self.frame_prefixes.add(m.group(1))

    def _doc(self, text):
        ns = re.search(r'^\s*Namespace\s*=\s*"(\w+)"', text, re.M)
        ns = ns.group(1) if ns else None
        for block in re.finditer(r'Name\s*=\s*"(\w+)",\s*\n\s*Type\s*=\s*"(Function|Event)"', text):
            name, kind = block.group(1), block.group(2)
            if kind == "Function":
                self.api.add(ns + "." + name if ns else name)
        for m in re.finditer(r'LiteralName\s*=\s*"(\w+)"', text):
            self.events.add(m.group(1))

    def is_api(self, name):
        return name in self.api or name.startswith("C_")

    def frame_known(self, name):
        return name in self.frames or name in self.frame_prefixes

    def frame_string(self, s):
        return bool(FRAME_SHAPE.match(s)) and s not in NOT_FRAMES and not s.endswith("Template") \
            and not s.endswith("Mixin") and "_" not in s and not s.startswith("FlatUI")


# ----------------------------------------------------------------------------------------------------------------
# Scopes: which names of a file are globals
# ----------------------------------------------------------------------------------------------------------------

def global_refs(f):
    """Every read of a global name in the file, as token indexes, and the set of token indexes that declare names."""
    toks = f.toks
    n = len(toks)
    # where each scope opener closes
    closer = {}
    for k, t in enumerate(toks):
        if t.t != "kw":
            continue
        if t.v in ("function", "do", "repeat"):
            closer[k] = f.block_end.get(k, n - 1)
        elif t.v in ("then", "else"):
            c = f.container[k]
            if c is None or toks[c].v != "if":
                continue
            if t.v == "else":
                closer[k] = f.block_end.get(c, n - 1)
            else:
                j = k + 1
                end = f.block_end.get(c, n - 1)
                while j < end:
                    x = toks[j]
                    if x.t == "kw" and x.v in ("elseif", "else") and f.container[j] == c:
                        break
                    j += 1
                closer[k] = j
    stack = [(n, set())]
    declared = set()
    refs = []
    pending_for = None
    k = 0
    while k < n:
        while stack and stack[-1][0] <= k and len(stack) > 1:
            stack.pop()
        t = toks[k]
        if t.t == "kw":
            if t.v == "local":
                if toks[k + 1].v == "function" and toks[k + 2].t == "name":
                    stack[-1][1].add(toks[k + 2].v)
                    declared.add(k + 2)
                    k += 1
                    continue
                j = k + 1
                names = []
                while toks[j].t == "name":
                    names.append(j)
                    j += 1
                    if toks[j].v == "<":
                        j += 3
                    if toks[j].v == ",":
                        j += 1
                    else:
                        break
                for j2 in names:
                    declared.add(j2)
                # the names are seen after the statement's values; close enough to declare them here
                after = set(toks[j2].v for j2 in names)
                stack[-1][1].update(after)
                k += 1
                continue
            if t.v == "for":
                j = k + 1
                names = []
                while toks[j].t == "name":
                    names.append(j)
                    declared.add(j)
                    j += 1
                    if toks[j].v == ",":
                        j += 1
                    else:
                        break
                pending_for = set(toks[x].v for x in names)
                k = j
                continue
            if t.v == "function":
                scope = set()
                j = k + 1
                if toks[j].t == "name":
                    # function a.b:c(...): the first name is read, the rest are fields
                    parts = [j]
                    while toks[j + 1].v in (".", ":") and toks[j + 2].t == "name":
                        if toks[j + 1].v == ":":
                            scope.add("self")
                        j += 2
                        parts.append(j)
                    if len(parts) == 1:
                        declared.add(parts[0])
                    else:
                        if not any(toks[parts[0]].v in s for _, s in stack):
                            refs.append(parts[0])
                        for x in parts[1:]:
                            declared.add(x)
                    j += 1
                if toks[j].v == "(":
                    close = f.partner.get(j, j)
                    for x in range(j + 1, close):
                        if toks[x].t == "name":
                            scope.add(toks[x].v)
                            declared.add(x)
                    j = close
                stack.append((closer.get(k, n), scope))
                k = j + 1
                continue
            if t.v in ("do", "then", "else", "repeat") and k in closer:
                scope = set()
                if t.v == "do" and pending_for is not None:
                    scope, pending_for = pending_for, None
                stack.append((closer[k], scope))
            k += 1
            continue
        if t.t == "name" and k not in declared:
            prev = toks[k - 1] if k > 0 else None
            nxt = toks[k + 1]
            if prev is not None and prev.t == "op" and prev.v in (".", ":", "::"):
                k += 1
                continue
            if prev is not None and prev.t == "kw" and prev.v == "goto":
                k += 1
                continue
            c = f.container[k]
            if nxt.v == "=" and c is not None and toks[c].v == "{" and (prev is None or prev.v in ("{", ",", ";")):
                k += 1
                continue
            if not any(t.v in s for _, s in stack):
                refs.append(k)
        k += 1
    return refs, declared


# ----------------------------------------------------------------------------------------------------------------
# Game names of one file
# ----------------------------------------------------------------------------------------------------------------

def string_at(f, k, consts):
    """The string at token k: a literal, a local constant of the file, or the literal that starts a concatenation."""
    t = f.toks[k]
    if t.t == "str":
        return t.v
    if t.t == "name" and t.v in consts and f.toks[k + 1].v != ".":
        return consts[t.v]
    return None


def call_args(f, open_i):
    """The start token of each argument of the call whose bracket opens at open_i."""
    toks = f.toks
    close = f.partner.get(open_i)
    if close is None:
        return []
    args, start, j = [], open_i + 1, open_i + 1
    if start == close:
        return []
    while j < close:
        x = toks[j]
        if x.v in ("(", "[", "{") and x.t == "op" and j in f.partner:
            j = f.partner[j] + 1
            continue
        if x.t == "kw" and x.v == "function":
            j = f.block_end.get(j, j) + 1
            continue
        if x.t == "op" and x.v == ",":
            args.append(start)
            start = j + 1
        j += 1
    args.append(start)
    return args


class GameNames(object):
    def __init__(self):
        self.groups = {g: collections.OrderedDict() for g in ("frames", "api", "events", "cvars", "hooks", "secure")}
        self.dynamic = 0

    def add(self, group, name, line, via=None, extra=None):
        g = self.groups[group]
        rec = g.get(name)
        if rec is None:
            rec = g[name] = {"name": name, "count": 0, "lines": [], "via": via, "extra": {}}
        rec["count"] += 1
        if line is not None and line not in rec["lines"]:
            rec["lines"].append(line)
        if extra:
            for k, v in extra.items():
                if v is not None:
                    rec["extra"].setdefault(k, [])
                    if v not in rec["extra"][k]:
                        rec["extra"][k].append(v)
        return rec


def game_names(f, client, spans, consts, helpers, owned_cvars):
    """Every game name the file uses, by group."""
    toks = f.toks
    out = GameNames()
    refs, declared = global_refs(f)
    called = f.called_names
    member_seen = set()
    calls_here = set()
    for k in refs:
        t = toks[k]
        at = k
        if t.v == "_G" and toks[k + 1].v == "." and toks[k + 2].t == "name":
            at = k + 2
        name = toks[at].v
        if name.startswith("C_") and toks[at + 1].v == "." and toks[at + 2].t == "name":
            member_seen.add(name)
        if toks[at + 1].v == "(":
            calls_here.add(name)
        if toks[k - 1].v == "(" and toks[k - 2].v in ("pcall", "xpcall") and toks[k - 3].v not in (".", ":"):
            calls_here.add(name)
    # api and frames read by name
    frame_occ = []
    for k in refs:
        t = toks[k]
        name = t.v
        if name == "_G":
            nxt = toks[k + 1]
            g = None
            if nxt.v == "." and toks[k + 2].t == "name":
                g, at = toks[k + 2].v, k + 2
            elif nxt.v == "[" and toks[k + 2].t == "str" and toks[k + 3].v == "]":
                g, at = toks[k + 2].v, k + 2
            if g is None:
                continue
            if g.startswith("C_"):
                if toks[at + 1].v == "." and toks[at + 2].t == "name":
                    out.add("api", g + "." + toks[at + 2].v, t.line)
                elif g not in member_seen:
                    out.add("api", g, t.line)
            elif g in client.api:
                if toks[at + 1].v == "(":
                    out.add("api", g, t.line)
            elif g not in called and g not in NOT_FRAMES and "_" not in g and not g.startswith("FlatUI") \
                    and (client.frame_known(g) or FRAME_SHAPE.match(g)):
                frame_occ.append((k, g, "_G"))
            continue
        if name.startswith("C_"):
            if toks[k + 1].v == "." and toks[k + 2].t == "name":
                out.add("api", name + "." + toks[k + 2].v, t.line)
            elif name not in member_seen:
                out.add("api", name, t.line)
            continue
        if name in client.api:
            # a call, the function pcall runs, or what type() is asked about; a name only passed on is not counted
            if toks[k + 1].v == "(" or (toks[k - 1].v == "(" and toks[k - 2].v in ("pcall", "xpcall", "type")
                                         and toks[k - 3].v not in (".", ":")):
                out.add("api", name, t.line)
            continue
        if name in client.frames and name not in called and client.frame_string(name):
            frame_occ.append((k, name, None))
    # strings and keys: frame names and event names, added in the order they are written
    occ = []
    for t in toks:
        if t.t == "str":
            sv = t.v
            if sv in client.events:
                way = event_way(f, t.i)
                if way is not None:
                    c = f.container[t.i]
                    if way == "event list" and table_field_name(f, c) == "events":
                        way = "events table"
                    occ.append((t.i, "events", sv, way, None))
            elif client.frame_string(sv) and sv not in called:
                frame_occ.append((t.i, sv, "name string"))
        elif t.t == "name" and t.v in client.events:
            prev, nxt = toks[t.i - 1], toks[t.i + 1]
            c = f.container[t.i]
            if nxt.v == "=" and c is not None and toks[c].v == "{" and prev.v in ("{", ",", ";") \
                    and table_field_name(f, c) == "events":
                occ.append((t.i, "events", t.v, "events table", {"handler": table_value_name(f, t.i + 2)}))
        elif t.t == "name" and t.v in ("RegisterEvent", "RegisterUnitEvent") and toks[t.i + 1].v == "(":
            args = call_args(f, t.i + 1)
            if args and toks[args[0]].t == "name" and string_at(f, args[0], consts) in client.events:
                occ.append((args[0], "events", string_at(f, args[0], consts), t.v, None))
    for k, group, name, way, extra in sorted(occ, key=lambda x: x[0]):
        out.add(group, name, toks[k].line, way, extra)
    # frames: named in a string first, else read from _G, else read as a bare global (counted once a line, and only
    # for a name the file does not name otherwise)
    by_name = collections.OrderedDict()
    for k, name, way in sorted(frame_occ):
        by_name.setdefault(name, []).append((k, way))
    for name, found in by_name.items():
        ways = [w for _, w in found]
        via = "name string" if "name string" in ways else "_G" if "_G" in ways else None
        named = [k for k, w in found if w is not None]
        counted = named if named else []
        if not named:
            seen = set()
            for k, w in found:
                if toks[k].line not in seen:
                    seen.add(toks[k].line)
                    counted.append(k)
        for k in counted:
            out.add("frames", name, toks[k].line, via)
    # registrations whose event is no fixed string
    for t in toks:
        if t.t == "name" and t.v in ("RegisterEvent", "RegisterUnitEvent") and toks[t.i + 1].v == "(":
            args = call_args(f, t.i + 1)
            if args and string_at(f, args[0], consts) is None and not loop_over_list(f, args[0]):
                out.dynamic += 1
    # CVars passed to the CVar functions: GetCVar(name), C_CVar.SetCVar(name, v), cvar.GetCVar(name) on a local copy,
    # and pcall(C_CVar.GetCVar, name); the name written as a string or held by a constant of the file
    for t in toks:
        if t.t != "name" or t.v not in CVAR_NAMES:
            continue
        prev, nxt = toks[t.i - 1], toks[t.i + 1]
        s_name, via = None, None
        if nxt.v == "(" and prev.v != ":":
            args = call_args(f, t.i + 1)
            s_name, via = (string_at(f, args[0], consts) if args else None), t.v
        elif nxt.v == "," and (prev.v == "(" or (prev.v == "." and toks[t.i - 2].t == "name")):
            j = t.i - 1 if prev.v == "(" else t.i - 3
            while j > 0 and toks[j].v == ".":
                j -= 2
            if toks[j].v == "(" and toks[j - 1].v in ("pcall", "xpcall"):
                args = call_args(f, j)
                s_name, via = (string_at(f, args[1], consts) if len(args) > 1 else None), "pcall"
        if s_name and s_name.lower() in client.cvars:
            out.add("cvars", s_name, t.line, via)
    for cvar in owned_cvars:
        rec = out.groups["cvars"].get(cvar)
        if rec is None:
            out.groups["cvars"][cvar] = {"name": cvar, "count": 1, "lines": [], "via": "setting row", "extra": {}}
    # hooks
    for t in toks:
        if t.t != "name" or toks[t.i + 1].v != "(":
            continue
        name, prev = t.v, toks[t.i - 1]
        if name == "hooksecurefunc" and prev.v not in (".", ":"):
            hook_target(f, out, t, call_args(f, t.i + 1), consts, None)
        elif name == "pcall" and prev.v not in (".", ":"):
            args = call_args(f, t.i + 1)
            if args and toks[args[0]].v == "hooksecurefunc" and len(args) > 1:
                hook_target(f, out, t, args[1:], consts, "pcall")
        elif name == "HookScript":
            args = call_args(f, t.i + 1)
            if prev.v == ":":
                obj, _ = dotted_back(toks, t.i - 2) if toks[t.i - 2].t == "name" else ("", 0)
                s = string_at(f, args[0], consts) if args else None
                if s:
                    out.add("hooks", "HookScript:" + s, t.line, None, {"receivers": obj or ""})
            elif prev.v != ".":
                s = string_at(f, args[1], consts) if len(args) > 1 else None
                if s:
                    out.add("hooks", "HookScript:" + s, t.line, None, {"receivers": ""})
        elif name in helpers and prev.v != ":":
            args = call_args(f, t.i + 1)
            if t.i > 0 and toks[t.i - 1].v == "." and toks[t.i - 2].v != "ns":
                continue
            hook_target(f, out, t, args, consts, name)
    # secure code
    for t in toks:
        if t.t != "name" or toks[t.i + 1].v != "(":
            continue
        prev = toks[t.i - 1]
        if t.v in SECURE_CALLS and prev.v not in (".", ":"):
            out.add("secure", t.v, t.line)
        elif t.v in STATE_DRIVERS and prev.v not in (".", ":"):
            args = call_args(f, t.i + 1)
            s = string_at(f, args[1], consts) if len(args) > 1 else None
            out.add("secure", t.v + (":" + s if s else ""), t.line)
        elif t.v in SECURE_METHODS and prev.v == ":":
            args = call_args(f, t.i + 1)
            if SECURE_METHODS[t.v]:
                s = None
                if args and toks[args[0]].t == "str":
                    s = toks[args[0]].v
                if s is None:
                    continue
                out.add("secure", t.v + ":" + s, t.line)
            else:
                out.add("secure", t.v, t.line)
    return out


def hook_target(f, out, t, args, consts, via):
    toks = f.toks
    if not args:
        return
    first = string_at(f, args[0], consts)
    if first is not None:
        out.add("hooks", first, t.line, via)
        return
    if len(args) > 1:
        s = string_at(f, args[1], consts)
        if s is None:
            return
        a = args[0]
        end = args[1] - 1
        obj = "".join(x.v for x in toks[a:end] if x.t in ("name", "op") and x.v not in (",",))
        out.add("hooks", (obj or "?") + ":" + s, t.line, via)


EVENT_CALL = re.compile(r"Event|Listen")


def event_way(f, k):
    """How an event name written as a string at token k is used, or None when it is only named in passing."""
    toks = f.toks
    prev, nxt = toks[k - 1], toks[k + 1]
    if prev.v in ("==", "~=") or nxt.v in ("==", "~="):
        return "compared"
    c = f.container[k]
    if c is not None and toks[c].v == "(":
        callee = callee_before(f, c)
        args = call_args(f, c)
        if k not in args:
            return None
        if callee in ("RegisterEvent", "RegisterUnitEvent"):
            return callee
        if callee == "pcall" and args and toks[args[0] + 1].v in (".", ":") \
                and toks[args[0] + 2].v in ("RegisterEvent", "RegisterUnitEvent"):
            return "pcall"
        if callee and EVENT_CALL.search(callee):
            return "event call"
        return None
    if c is not None and toks[c].v == "{" and prev.v in ("{", ",", ";") and nxt.v in (",", ";", "}"):
        return "event list"
    return None


def table_field_name(f, open_i):
    """The name a table constructor is the value of: events in events = { ... }."""
    toks = f.toks
    if open_i >= 2 and toks[open_i - 1].v == "=" and toks[open_i - 2].t == "name":
        return toks[open_i - 2].v
    return None


def table_value_name(f, k):
    """What a field of a table constructor holds: the name of a function, or 'function' for one written there."""
    t = f.toks[k]
    if t.t == "kw" and t.v == "function":
        return "function"
    if t.t == "name" and f.toks[k + 1].v not in (".", ":", "(", "["):
        return t.v
    return None


def loop_over_list(f, k):
    """True when token k is the variable of a for loop over a table of fixed strings written in the loop."""
    toks = f.toks
    t = toks[k]
    if t.t != "name":
        return False
    j = k
    while j > 0:
        x = toks[j]
        if x.t == "kw" and x.v == "for":
            names, m = [], j + 1
            while toks[m].t == "name":
                names.append(toks[m].v)
                m += 1 if toks[m + 1].v != "," else 2
                if toks[m - 1].v != ",":
                    break
            if t.v in names:
                rest = toks[m:m + 6]
                return any(y.v == "{" for y in rest)
            return False
        j -= 1
    return False


# ----------------------------------------------------------------------------------------------------------------
# Areas
# ----------------------------------------------------------------------------------------------------------------

# The seven areas of 0.4.66, each with its files, and an eighth for the errands, the data panels and the world rows
# of the Flat UI page, which fit none of them. A file that is in no list and matches a pattern is listed under that
# area and named in unlisted_files.
AREAS = [
    ("core", "Core and settings", """Config Core TaintScan Scale Fonts Fade LayoutSpots LayoutText ConfigGame Options Reload
        Panel ProfileSwitch ProfileShare PanelLook PanelCards PanelSamples PanelColour PanelTrust PanelSearch PanelNav
        PanelTabs PanelHome PanelPreview TestMode TestUnits TestHud"""),
    ("setup", "Setup", "SetupSteps SetupProfiles SetupStops Setup SetupWalk SetupWelcome"),
    ("unitframes", "Unit frames", """ClassData UnitFrames UnitFramePortrait UnitFrameLevel UnitFrameCells UnitFrameLooks
        UnitFrameHead UnitText UnitParts UnitExtras UnitGroupMarks UnitDruidMana UnitPetTarget UnitHots HealthColour
        PetFrameSize"""),
    ("nameplates", "Nameplates, combat text and cast bars", """Nameplates PlateThreat PlateColours PlateThreatLook PlateText
        PlateClick PlateThreatText PlateOverpower CombatBurst CombatTextSpells CombatText ScrollText CombatCues Bars CastTime CastRank
        Interrupt CastBarSize"""),
    ("actionbars", "Action bars", """ActionBars OwnBars OwnPaint ButtonText Cooldowns CooldownLooks ButtonStates CooldownData
        ProcData Procs ProcArt ProcGlow ButtonEffects ProcTriggers BarBlock BarBlockButtons BarBlockLists Blocks"""),
    ("trackers", "Trackers and cooldowns", """Trackers TrackerSound TrackerSlots IconRow Tracking Defensives PartyCooldowns
        PartySync EnemyCooldowns Threat HealerMana GroupTools OwnBuffs TrackerShapes TrackerKinds TrackerMarks
        TrackerShare TrackerGroup TrackerClicks Pulse Items Absorbs PingBar"""),
    ("hud", "HUD, windows, movers, chat and tooltips", """BagSort BagKey Bags BagsData BagsCategories BagsSearch BagsItems
        BagsLayout BagsWindow BagsBank BagsTooltip BagsOrder BagsPins Windows ItemMarks CharacterDurability CharacterThorns Hud MapButtons
        AuraTime XpStats XpBar QuestCount QuestieSkin MapText ErrorFilter ScreenText MeterClear HitTableCalc HitTable HitTableTip Chat
        ChatText ChatTips ChatLinks ItemCompare ChatHistory SpellData SpellModel GearModel GearAvoid SpellLines GearLines GearWindow
        ItemIndex RotationData GearSearch GearButton Movers MoversMode MoversSnap Hide Tooltip"""),
    ("errands", "Errands, panels and world", """Sparkle SparkleGlow CameraZoom CursorRing MountKey Errands ErrandsMerchant
        ErrandsLoot ErrandsTrainer ErrandsPopups ErrandsSocial ErrandsQuests ErrandsRanks ErrandsLevelling
        ErrandsNavigation ErrandsBulkBuy ConsumableData Consumables DataPanels DataStreams LavaWalk"""),
]
AREA_PATTERNS = [("SetupDraw*", re.compile(r"^SetupDraw"), "setup")]


def area_of(mid):
    for aid, _, names in AREAS:
        if mid in names.split():
            return aid, None
    for label, pat, aid in AREA_PATTERNS:
        if pat.match(mid):
            return aid, label
    return None, None


# ----------------------------------------------------------------------------------------------------------------
# The whole addon
# ----------------------------------------------------------------------------------------------------------------

def read_toc(path):
    files, version = [], ""
    for line in open(path, encoding="utf-8", errors="replace"):
        s = line.strip()
        m = re.match(r"^##\s*Version:\s*(.+)$", s)
        if m:
            version = m.group(1).strip()
        if s and not s.startswith("#") and s.lower().endswith(".lua"):
            files.append(s.replace("\\", "/"))
    return files, version


def description(f):
    """The file's header comment: the first block of comment lines, before any code but `local _, ns = ...`."""
    parts, started = [], False
    for i, raw in enumerate(f.lines):
        s = raw.strip()
        if not started:
            if not s or re.match(r"^local\s+[\w\s,]*=\s*\.\.\.\s*$", s):
                continue
            if s.startswith("--") and not s.startswith("--[["):
                started = True
            else:
                break
        if started:
            if s.startswith("--") and not s.startswith("--[["):
                parts.append(s[2:].strip())
            else:
                break
    return " ".join(p for p in parts if p).strip()


def build(args):
    repo = args.repo
    addon = os.path.join(repo, "FlatUI")
    toc_files, version = read_toc(os.path.join(addon, "FlatUI.toc"))
    on_disk = sorted(n for n in os.listdir(addon) if n.lower().endswith(".lua"))
    present = [n for n in toc_files if os.path.exists(os.path.join(addon, n))]
    order = [n[:-4] for n in present]
    client = Client(args.interface, args.products)

    # files
    files = {}
    for n in present:
        mid = n[:-4]
        path = os.path.join(addon, n)
        f = LuaFile(path, "FlatUI/" + n, mid, open(path, encoding="utf-8", errors="replace").read())
        f.fns = find_functions(f, set())
        f.nsd = ns_definitions(f)
        f.spans = enclosing_names(f, f.fns)
        f.mkeys, f.registered, f.consts = module_keys(f)
        f.strings = {t.v for t in f.toks if t.t == "str"}
        f.defined_fns = {d["name"] for d in f.nsd if d["kind"] == "function"}
        f.defined_all = {d["name"] for d in f.nsd}
        files[mid] = f
    called = set()
    helpers = set()
    for mid in order:
        f = files[mid]
        toks = f.toks
        for t in toks:
            if t.t == "name" and toks[t.i + 1].v == "(" and toks[t.i - 1].v not in (".", ":", "function"):
                called.add(t.v)
        f.local_helpers = set()
        for r in f.fns:
            if r["kind"] not in ("local", "ns"):
                continue
            if any(x.t == "name" and x.v == "hooksecurefunc" for x in toks[r["_tok"]:r["_end_tok"]]):
                (helpers if r["kind"] == "ns" else f.local_helpers).add(r["name"])
    for mid in order:
        files[mid].called_names = called

    # settings
    pages = dump_config(os.path.join(addon, "Config.lua"), args.lua)
    rows, page_list, n = [], [], 0
    for pg in pages:
        page_list.append({"key": pg["key"], "label": pg.get("label", pg["key"]), "parent": pg.get("parent"),
                          "rows": len(pg["rows"])})
        for r in pg["rows"]:
            owner = r.get("page") or pg.get("owner") or pg["key"]
            path = owner + "." + r["key"]
            row = collections.OrderedDict()
            row["path"] = path
            row["label"] = r.get("label") or ""
            row["kind"] = r.get("kind") or ""
            row["default"] = r.get("default")
            if isinstance(r.get("choices"), list):
                row["choices"] = [[str(c[0]), str(c[1])] for c in r["choices"]]
            elif isinstance(r.get("choices"), str):
                row["choices"] = r["choices"]
            if row["kind"] == "number" and "min" in r and "max" in r:
                rng = collections.OrderedDict([("min", r["min"]), ("max", r["max"]), ("step", r.get("step", 1))])
                if isinstance(r.get("unit"), str) and r["unit"]:
                    rng["unit"] = r["unit"]
                row["range"] = rng
            if isinstance(r.get("tip"), str):
                row["tip"] = r["tip"]
            if isinstance(r.get("needs"), str):
                row["needs"] = r["needs"]
            if isinstance(r.get("cvar"), str):
                row["cvar"] = r["cvar"]
            row["page"] = pg["key"]
            row["page_label"] = pg.get("label", pg["key"])
            row["section"] = r.get("section")
            row["order"] = n
            n += 1
            rows.append((row, {"path": path, "key": r["key"], "module": owner, "changed": r.get("changed"),
                               "choices": r.get("choices") if isinstance(r.get("choices"), str) else None,
                               "get": r.get("get"), "set": r.get("set")}))
    code_files = [m for m in order if m != "Config"]
    attribution, fallback_rows, unmatched = attribute_settings([x[1] for x in rows], files, code_files)
    page_label = {p["key"]: p["label"] for p in page_list}
    by_file = collections.defaultdict(list)
    owners = collections.Counter()
    for row, meta in rows:
        for mid, role, way, shared in attribution[meta["path"]]:
            rec = collections.OrderedDict(row)
            rec["found_by"] = way
            rec["role"] = role
            rec["shared_with"] = shared
            by_file[mid].append(rec)
            if role == "owns":
                owners[meta["path"]] += 1

    # links
    rank = {"function": 0, "table": 1, "alias": 2, "value": 3, "declare": 4}
    defs = collections.defaultdict(list)
    for i, mid in enumerate(order):
        for d in files[mid].nsd:
            defs[d["name"]].append((rank[d["kind"]], i, mid))
    owner_of = {name: min(v)[2] for name, v in defs.items()}
    definers = {name: {x[2] for x in v} for name, v in defs.items()}
    pairs = collections.OrderedDict()
    for mid in order:
        f = files[mid]
        here = {d["_tok"] for d in f.nsd}
        for name, ti in ns_uses(f, here):
            if name not in owner_of or mid in definers[name]:
                continue
            to = owner_of[name]
            p = pairs.setdefault((mid, to), {"uses": [], "names": collections.Counter()})
            p["uses"].append((name, ti))
            p["names"][name] += 1
    links = []
    for (fr, to), p in pairs.items():
        f = files[fr]
        lines = []
        for _, ti in p["uses"]:
            ln = f.toks[ti].line
            if ln not in lines:
                lines.append(ln)
        lines = lines[:EXAMPLES]
        link = collections.OrderedDict()
        link["from"], link["to"] = fr, to
        link["functions"] = [nm for nm, _ in sorted(p["names"].items(), key=lambda x: -x[1])]
        link["count"] = len(p["uses"])
        link["examples"] = [f.at(ln) for ln in lines]
        link["code"] = [f.code(ln) for ln in lines]
        link["fns"] = [name_at(f.spans, ln) for ln in lines]
        links.append(link)
    links.sort(key=lambda l: (-l["count"], l["from"], l["to"]))

    # tests
    test_path = os.path.join(repo, "FlatUI_test.lua")
    labels = read_tests(test_path) if os.path.exists(test_path) else []

    # modules
    page_by_key = {p["key"]: p["label"] for p in page_list}
    modules, unlisted = [], []
    for i, mid in enumerate(order, 1):
        f = files[mid]
        aid, pattern = area_of(mid)
        if aid is None:
            raise SystemExit("%s.lua is in no area: add it to AREAS" % mid)
        if pattern:
            unlisted.append("%s.lua -> %s (%s)" % (mid, aid, pattern))
        settings = sorted(by_file.get(mid, []), key=lambda s: s["path"])
        # CVars: those the file passes to the CVar functions, and the CVar of each row it lists
        first_at = {}
        for s in settings:
            if s.get("cvar"):
                key = s["path"].split(".", 1)[1]
                at = min([t.pos for t in f.toks if t.t == "str" and t.v in (s["path"], key)] or [10 ** 9])
                first_at[s["cvar"]] = (at, s["order"])
        row_cvars = [c for c, _ in sorted(first_at.items(), key=lambda x: x[1])]
        gn = game_names(f, client, f.spans, f.consts, helpers | f.local_helpers, row_cvars)
        game = collections.OrderedDict()
        for g in ("frames", "api", "events", "cvars", "hooks", "secure"):
            items = list(gn.groups[g].values())
            if g == "cvars":
                items.sort(key=lambda x: -x["count"])
            else:
                items.sort(key=lambda x: (-x["count"], x["name"]))
            out = []
            for x in items:
                e = collections.OrderedDict()
                e["name"], e["count"] = x["name"], x["count"]
                lines = x["lines"][:EXAMPLES]
                e["lines"] = [f.at(ln) for ln in lines]
                e["code"] = [f.code(ln) for ln in lines]
                e["fns"] = [name_at(f.spans, ln) for ln in lines]
                if x["via"] is not None:
                    e["via"] = x["via"]
                if g == "events" and x["via"] == "events table":
                    hs = x["extra"].get("handler") or []
                    if hs:
                        e["handler"] = ", ".join(h for h in hs if h)
                if g == "hooks" and "receivers" in x["extra"]:
                    e["receivers"] = ", ".join(x["extra"]["receivers"])
                out.append(e)
            game[g] = out
        functions = []
        for r in f.fns:
            functions.append(collections.OrderedDict((k, r[k]) for k in ("name", "kind", "line", "end", "args", "doc")
                                                     if k in r))
        m = collections.OrderedDict()
        m["id"] = mid
        m["file"] = f.rel
        m["area"] = aid
        m["toc"] = i
        m["lines"] = len(f.lines)
        m["description"] = description(f)
        m["module_keys"] = list(f.mkeys)
        m["page_labels"] = [page_by_key[k] for k in f.mkeys if k in page_by_key]
        m["ns_functions"] = [collections.OrderedDict((k, d[k]) for k in ("name", "kind", "line")) for d in f.nsd]
        m["local_functions"] = sum(1 for r in f.fns if r["kind"] == "local")
        m["functions"] = functions
        m["settings"] = settings
        m["links_out"] = [l for l in links if l["from"] == mid]
        m["links_in"] = [collections.OrderedDict((k, v) for k, v in l.items() if k != "to") for l in links if l["to"] == mid]
        m["game"] = game
        m["events_dynamic"] = gn.dynamic
        m["tests"] = test_links(labels, mid, f.mkeys, f.defined_all)
        modules.append(m)
    mod_area = {m["id"]: m["area"] for m in modules}

    # areas
    areas = []
    for aid, label, _ in AREAS:
        ms = [m for m in modules if m["area"] == aid]
        a = collections.OrderedDict()
        a["id"], a["label"] = aid, label
        a["files"] = len(ms)
        a["lines"] = sum(m["lines"] for m in ms)
        a["functions"] = sum(len(m["functions"]) for m in ms)
        a["settings"] = sum(1 for m in ms for s in m["settings"] if s["role"] == "owns")
        a["modules"] = [m["id"] for m in ms]
        areas.append(a)
    al = collections.OrderedDict()
    for l in links:
        k = (mod_area[l["from"]], mod_area[l["to"]])
        e = al.setdefault(k, {"links": 0, "uses": 0})
        e["links"] += 1
        e["uses"] += l["count"]
    area_links = [collections.OrderedDict([("from", a), ("to", b), ("links", e["links"]), ("uses", e["uses"]),
                                           ("cross", a != b)]) for (a, b), e in al.items()]
    area_links.sort(key=lambda x: (-x["links"], x["from"], x["to"]))

    # checks
    all_rows = [meta["path"] for _, meta in rows]
    dump_ok = all(row["kind"] and meta["key"] for row, meta in rows) and len(set(all_rows)) == len(all_rows)
    listed_owned = sorted(s["path"] for m in modules for s in m["settings"] if s["role"] == "owns")
    one_owner = sum(1 for p in all_rows if owners[p] == 1)
    checks = [
        ("every file in the TOC is present", len(present) == len(toc_files)),
        ("every Lua file on disk is in the TOC", set(on_disk) <= set(toc_files)),
        ("no module has zero lines", all(m["lines"] > 0 for m in modules)),
        ("settings come from Config.lua now that settings.json is gone: %d rows on %d pages, each saved path once"
         % (len(all_rows), len(page_list)), dump_ok and len(all_rows) > 0),
        ("settings equal Config.lua (lua5.4 dump)", listed_owned == sorted(all_rows)),
        ("every module has a description", all(m["description"] for m in modules)),
        ("every setting is attributed to a file", all(attribution.get(p) for p in all_rows)),
        ("every setting has exactly one owning file (%d of %d)" % (one_owner, len(all_rows)), one_owner == len(all_rows)),
        ("the test file was read", len(labels) > 0),
    ]
    checks = [collections.OrderedDict([("check", c), ("ok", bool(ok))]) for c, ok in checks]

    summary = collections.OrderedDict()
    summary["version"] = version
    summary["files"] = len(modules)
    summary["lines"] = sum(m["lines"] for m in modules)
    summary["ns_definitions"] = sum(len(m["ns_functions"]) for m in modules)
    summary["local_functions"] = sum(m["local_functions"] for m in modules)
    summary["functions"] = sum(len(m["functions"]) for m in modules)
    summary["settings"] = len(all_rows)
    summary["settings_pages"] = len(page_list)
    summary["links"] = len(links)
    summary["link_uses"] = sum(l["count"] for l in links)
    summary["cross_area_links"] = sum(1 for l in links if mod_area[l["from"]] != mod_area[l["to"]])
    summary["test_labels"] = len(labels)

    data = collections.OrderedDict()
    data["meta"] = collections.OrderedDict([
        ("title", "Flat UI map"), ("version", version), ("generated_by", VERSION_LABEL),
        ("source", "FlatUI/*.lua in TOC order, FlatUI/Config.lua (ns.PAGES, run by lua5.4), FlatUI_test.lua; game names "
                   "from Forever's interface source (Interface/AddOns, Blizzard_APIDocumentationGenerated) and the "
                   "client lists of wowless (apis.yaml, events.yaml, cvars.yaml)")])
    data["summary"] = summary
    data["areas"] = areas
    data["area_links"] = area_links
    data["modules"] = modules
    data["links"] = links
    data["settings_pages"] = page_list
    data["checks"] = checks
    data["unlisted_files"] = unlisted
    data["test_labels"] = [[label, line] for label, line, _ in labels]
    data["gaps"] = gaps(fallback_rows, unmatched)
    return data


def gaps(fallback_rows, unmatched):
    return [
        "Settings: a row is matched to a file by its saved path or its key written as a string (the key only in a file "
        "with the row's module key), or by a function of ns the file defines that the row names (its changed function, "
        "the function its choices name, or its get or set function). A key built while the game runs is not matched. A "
        "row goes to the file that defines its changed function, else its choices function, else a file with its module "
        "key; when several files of one module name its key, the file that registers the module. %d rows matched no file "
        "and %d more matched only files that do not own them; they went to the file that registers their module, unless "
        "another file writes their path. A row saved under a name that no file registers (general, and setup and panel, "
        "which rows of the Flat UI page are saved under) goes to the file that holds its value (its get or set "
        "function), else the first file in TOC order that writes its path. Setup files only use rows, but for those saved "
        "under setup. Each row has one owning file; other files that name it show it as used." % (unmatched, fallback_rows),
        "Links: only calls written as ns.Name are counted. A call through a local copy of ns, through ns[name] or "
        "through a table passed as an argument is missed. A name defined in several files links to the file with the "
        "function; a name a file wraps and puts back is not a definition.",
        "Events: names in RegisterEvent calls, in the events table of a module, in lists of event names, in names "
        "compared with the event argument and in calls whose name holds Event or Listen. An event name written as a key "
        "counts only in the events table of a module, and a name passed to any other call is not counted. A "
        "registration through pcall that names the event with a variable is not counted; a direct one is counted per "
        "file and listed by name only when the variable holds a fixed string.",
        "Frames: strings shaped like frame names (ending in Frame, Button, Bar, Container, Tooltip, Popup, Panel, Tab, "
        "Dialog, Window or Cluster), names read as _G.Name or as _G[\"Name\"], and bare global reads of a frame the "
        "game's interface makes, counted once a line and only when the file does not name the frame otherwise. Names "
        "called anywhere as functions are left out, and so are the addon's own frames. The rule of 0.4.66 is "
        "approximated: a key of a child frame written as a string (BorderFrame, IconFrame) can be listed, and frames "
        "built from a name made while the game runs are missed.",
        "API: global functions of the game the file calls, runs through pcall or asks type() about, and C_ names. A "
        "function only passed on to another (Ask(UnitGUID, unit)) is not listed. The game's functions are those of "
        "apis.yaml, of Blizzard_APIDocumentationGenerated and the global functions of Forever's interface source, "
        "without Lua's own library. Methods called on frames, such as frame:SetPoint, are not listed.",
        "CVars: names passed to the CVar functions (GetCVar, SetCVar, GetCVarBool, GetCVarDefault, GetCVarInfo, as globals, "
        "on C_CVar or on a local copy of it, directly or through pcall), plus the CVar of each setting row the file names, "
        "owned or used. A CVar named by a variable that holds no fixed string is missed.",
        "Hooks and secure code: targets written as strings, including through helpers that call hooksecurefunc. The "
        "object of a HookScript is the name written before it. Secure code is SecureHandlerWrapScript, state drivers, "
        "SetAttribute and SetFrameRef with the name written as a string, and Execute.",
        "Tests: a label is listed for a module when its prefix is a module key or the file name, when it names the "
        "file, or when its check writes ns.Name for a name the file defines (W.ns.Name too). Most prefixes name a "
        "feature (sortbags, procs); a test that reaches code through a local copy of ns is missed.",
        "Functions: every function written in the file, named by the way it is declared: ns functions, local "
        "functions, functions kept in tables, functions inside table constructors, and callbacks named by the call "
        "they are passed to. The comment above is its last six lines, cut at 300 characters.",
        "Config.lua defines the rows, read by running it with lua5.4. Each row is listed under the file that owns it, "
        "and all of them are listed by settings page.",
        "Nothing is run: no order of events, no timing and no run-time cost is read.",
    ]


# ----------------------------------------------------------------------------------------------------------------
# Output
# ----------------------------------------------------------------------------------------------------------------

def write_outputs(data, args):
    os.makedirs(args.out, exist_ok=True)
    tag = re.sub(r"\D", "", data["meta"]["version"]).rjust(4, "0")
    json_path = os.path.join(args.out, "data_%s.json" % tag)
    with open(json_path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, separators=(",", ":"))
    template = open(args.template, encoding="utf-8").read()
    if template.count("__DATA__") != 1:
        raise SystemExit("the template must hold __DATA__ once")
    blob = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    page = template.replace("__DATA__", blob)
    html_path = os.path.join(args.out, "flat-ui-map.html")
    with open(html_path, "w", encoding="utf-8") as fh:
        fh.write(page)
    return json_path, html_path


def fetch_sources(sources):
    """Clones the repositories of the game names into sources, one commit deep, or brings them up to date."""
    os.makedirs(sources, exist_ok=True)
    for name, url, branch, _ in SOURCE_REPOS:
        d = os.path.join(sources, name)
        if os.path.isdir(os.path.join(d, ".git")):
            cmds = [["git", "-C", d, "fetch", "--quiet", "--depth", "1", "origin", branch],
                    ["git", "-C", d, "reset", "--quiet", "--hard", "FETCH_HEAD"]]
        else:
            cmds = [["git", "clone", "--quiet", "--depth", "1", "--single-branch", "--branch", branch, url, d]]
        for cmd in cmds:
            try:
                ok = subprocess.run(cmd).returncode == 0
            except FileNotFoundError:
                raise SystemExit("git was not found: --fetch clones the repositories of the game names with it")
            if not ok:
                raise SystemExit("could not fetch %s: %s" % (name, " ".join(cmd)))
        head = subprocess.run(["git", "-C", d, "log", "-1", "--format=%h %cs %s"], capture_output=True, text=True)
        print("%s %s: %s" % (name, branch, head.stdout.strip()))


def main(argv=None):
    ap = argparse.ArgumentParser(description="Build the data and the page of the Flat UI code map.")
    ap.add_argument("--fetch", action="store_true",
                    help="clone the repositories of the game names into --sources, or bring them up to date")
    ap.add_argument("--sources", default=DEFAULTS["sources"], help="where those repositories are (tools/dev/sources)")
    ap.add_argument("--interface", help="Forever's Interface/AddOns source (default: wow-ui-source in --sources)")
    ap.add_argument("--products", help="wowless data/products/wowf (default: wowless in --sources)")
    ap.add_argument("--repo", default=DEFAULTS["repo"], help="the Flat UI repository, read only (default: this one)")
    ap.add_argument("--out", default=DEFAULTS["out"], help="where data_<version>.json and flat-ui-map.html go")
    ap.add_argument("--template", default=DEFAULTS["template"], help="the page, with __DATA__ where the data goes")
    ap.add_argument("--lua", default="lua5.4", help="the Lua that runs Config.lua")
    args = ap.parse_args(argv)
    if args.fetch:
        fetch_sources(args.sources)
    args.interface = args.interface or os.path.join(args.sources, SOURCE_REPOS[0][0], *SOURCE_REPOS[0][3])
    args.products = args.products or os.path.join(args.sources, SOURCE_REPOS[1][0], *SOURCE_REPOS[1][3])
    game = [args.interface] + [os.path.join(args.products, n) for n in ("apis.yaml", "events.yaml", "cvars.yaml")]
    missing = [p for p in [os.path.join(args.repo, "FlatUI", "FlatUI.toc"), args.template] + game
               if not os.path.exists(p)]
    if missing:
        hint = ""
        if any(p in game for p in missing):
            hint = "\n--fetch clones the repositories of the game names, or --interface and --products name them."
        raise SystemExit("not found: " + ", ".join(missing) + hint)
    data = build(args)
    json_path, html_path = write_outputs(data, args)
    s = data["summary"]
    print("Flat UI %s: %d files, %d lines, %d functions, %d settings on %d pages, %d links (%d calls), %d test labels"
          % (s["version"], s["files"], s["lines"], s["functions"], s["settings"], s["settings_pages"], s["links"],
             s["link_uses"], s["test_labels"]))
    for c in data["checks"]:
        print("  %s  %s" % ("pass" if c["ok"] else "FAIL", c["check"]))
    print(json_path)
    print(html_path)


if __name__ == "__main__":
    main()
