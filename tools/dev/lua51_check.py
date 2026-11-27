#!/usr/bin/env python3
import re
import sys

CODE = [(r'\bgoto\b', 'goto'), (r'::\w+::', 'label'), (r'//', 'floor division'), (r'<<|>>', 'shift'),
        (r'(?<![~=<>])~(?!=)', 'bitwise not or xor'), (r'&', 'bitwise and'), (r'\|', 'bitwise or'), (r'<const>|<close>', 'attribute'),
        (r'\btable\.(unpack|pack|move)\b', 'table function of 5.2+'), (r'\butf8\.', 'utf8'), (r'\bmath\.(type|tointeger|ult)\b', 'math 5.3'),
        (r'\bstring\.(pack|unpack|packsize)\b', 'string.pack'), (r'\b_ENV\b', '_ENV'), (r'\bbit32\.', 'bit32'),
        (r'\b0[xX][0-9a-fA-F]*\.?[0-9a-fA-F]*[pP]', 'hex float')]
ESCAPES = [(r'\\x', '\\x escape'), (r'\\z', '\\z escape'), (r'\\u\{', '\\u escape')]
LONG = re.compile(r'\[(=*)\[')


def blank(text):
    return re.sub(r'[^\n]', ' ', text)


def scan(source):
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
        plain = text.replace('\\\\', '')
        for pattern, name in ESCAPES:
            if re.search(pattern, plain):
                found += 1
                print(f'{path}:{number}: {name}: {lines[number - 1].strip()[:140]}')
sys.exit(1 if found else 0)
