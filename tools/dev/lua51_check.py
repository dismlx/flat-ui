#!/usr/bin/env python3
"""Lists Lua 5.2+ constructs in Lua files; WoW runs Lua 5.1. Usage: python3 tools/dev/lua51_check.py FILE...

luac5.4 -p accepts every construct below, and Lua 5.1 rejects them or, for the escapes, reads them otherwise without a word. The file is read
once from the start, as the Lua lexer reads it: a comment or a string (short, or long at any level of =) is found where it starts, so a "--"
inside a string is no comment and a quote inside a comment is no string. Strings and comments become blanks of the same lines, the escapes of each
short string are checked, and the code left is matched against the patterns.
"""
import re
import sys

CODE = [(r'\bgoto\b', 'goto'), (r'::\w+::', 'label'), (r'//', 'floor division'), (r'<<|>>', 'shift'),
        (r'(?<![~=<>])~(?!=)', 'bitwise not or xor'), (r'&', 'bitwise and'), (r'\|', 'bitwise or'), (r'<const>|<close>', 'attribute'),
        (r'\btable\.(unpack|pack|move)\b', 'table function of 5.2+'), (r'\butf8\.', 'utf8'), (r'\bmath\.(type|tointeger|ult)\b', 'math 5.3'),
        (r'\bstring\.(pack|unpack|packsize)\b', 'string.pack'), (r'\b_ENV\b', '_ENV'), (r'\bbit32\.', 'bit32'),
        (r'\b0[xX][0-9a-fA-F]*\.?[0-9a-fA-F]*[pP]', 'hex float')]
# Escapes of a short string that Lua 5.1 does not have: \x (5.1 reads "\x41" as "x41"), \z and \u{...}.
ESCAPES = [(r'\\x', '\\x escape'), (r'\\z', '\\z escape'), (r'\\u\{', '\\u escape')]
LONG = re.compile(r'\[(=*)\[')


def blank(text):
    """The text with every character but a newline made a space, so line numbers stay."""
    return re.sub(r'[^\n]', ' ', text)


def scan(source):
    """The code with strings and comments blanked, and the short strings with the line each starts on."""
    out, strings, i, n = [], [], 0, len(source)
    while i < n:
        if source.startswith('--', i):
            long = LONG.match(source, i + 2)
            if long:
                close = ']' + long.group(1) + ']'
                j = source.find(close, long.end())
                j = n if j < 0 else j + len(close)
            else:
                j = source.find('\n', i)
                j = n if j < 0 else j
            out.append(blank(source[i:j]))
            i = j
            continue
        long = LONG.match(source, i)
        if long:
            close = ']' + long.group(1) + ']'
            j = source.find(close, long.end())
            j = n if j < 0 else j + len(close)
            out.append(blank(source[i:j]))
            i = j
            continue
        c = source[i]
        if c in '"\'':
            j = i + 1
            while j < n and source[j] != c and source[j] != '\n':
                j += 2 if source[j] == '\\' else 1
            closed = j < n and source[j] == c
            end = j + 1 if closed else min(j, n)
            strings.append((source.count('\n', 0, i) + 1, source[i:end]))
            out.append(c + blank(source[i + 1:end - 1 if closed else end]) + (c if closed else ''))
            i = end
            continue
        out.append(c)
        i += 1
    return ''.join(out), strings


found = 0
for path in sys.argv[1:]:
    with open(path, encoding='utf-8') as handle:
        source = handle.read()
    lines = source.split('\n')
    code, strings = scan(source)
    for number, line in enumerate(code.split('\n'), 1):
        for pattern, name in CODE:
            if re.search(pattern, line):
                found += 1
                print(f'{path}:{number}: {name}: {lines[number - 1].strip()[:140]}')
    for number, text in strings:
        # An escaped backslash is no escape: drop the pairs first.
        plain = text.replace('\\\\', '')
        for pattern, name in ESCAPES:
            if re.search(pattern, plain):
                found += 1
                print(f'{path}:{number}: {name}: {lines[number - 1].strip()[:140]}')
sys.exit(1 if found else 0)
