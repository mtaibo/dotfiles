"""Formats a C or Java file in one house style: clang-format, plus the layout
rules clang-format can't express. Reads the file on stdin, writes it to
stdout.

    code-style.py c|java CLANG_FORMAT STYLE_FILE < file

For both languages:

- Blocks with several statements that fit on one line, such as
  `if (x) { printf("..."); return 1; }`, stay on one line (clang-format always
  splits them): their bodies are swapped for a placeholder of the same length
  while clang-format runs.
- An `if`, `else if`, `else`, `for` or `while` with a single statement goes
  on one line when it fits (clang-format splits an `else if` that follows a
  braced branch).
- A call that doesn't fit in 80 columns keeps its first argument on the
  first line, packs the rest together below, two spaces further in
  (clang-format fills the first line instead), and closes with `);` on its
  own line, like a block. A prototype or function header that doesn't fit
  puts all its parameters below the `(`, packed, and closes with `);` or
  `) {` on its own line.
- An initializer `x = { ... };` that doesn't fit on one line gets `{` at the
  end of the first line, the elements below two spaces in (a line per
  comment, comments aligned, the rest packed) and `};` on its own line.
- Includes, #defines and typedefs are hoisted to the top of the file (not out
  of #if blocks), each group a blank line apart:
  - system includes, then a blank line and the project's ("..."), each from
    the shortest line to the longest;
  - #defines in their original order;
  - one-line typedefs in their original order;
  - multi-line typedefs and struct/union/enum definitions from the longest to
    the shortest, a blank line between each, always after the types they use.
- One blank line between top-level blocks, three around main. One-line
  functions written together stay together.

The includes, #defines and typedefs above are C's. In Java instead:
- Constructors get the space too: `Person (String name)`.
- A long string isn't cut (Java doesn't join "a" "b"); the arguments go
  below the `(` instead.
- Imports: the JDK's (java., javax.), then the rest, then static imports,
  each group from the shortest line to the longest, duplicates dropped.
- A blank line after a class's opening brace. Each class body in a fixed
  order, a blank line between kinds: nested types,
  static fields and initializers, fields and initializers (each keeping its
  own order, which initialization depends on), constructors, methods,
  getters in field order, setters in field order (each block together,
  however long its methods), @Override methods, main (three blank lines
  before it). The accessors of a single property go together; with more,
  each block of two or more gets a // Getters or // Setters label (labels
  already there are replaced).
- A method whose body is a single statement goes on one line when it fits,
  even with an annotation above it. Enum constants stay first, packed onto as few lines as fit.
  Comments and annotations above a member move with it.
- If reordering would change any token, the file is left as it was before
  reordering; files with text blocks aren't reordered at all.
"""
import os
import re
import subprocess
import sys
import tempfile

IDENT = re.compile(r"[A-Za-z_]\w*")


def scan(lines):
    """Per line: whether it starts inside a block comment, its brace depth at
    the end, and its code with comments and string contents removed."""
    depth, in_comment, pp_cont = 0, False, False
    out = []
    for line in lines:
        starts_in_comment = in_comment
        is_pp = pp_cont or (not in_comment and line.lstrip().startswith("#"))
        pp_cont = is_pp and line.endswith("\\")
        code, quote, i = [], None, 0
        while i < len(line):
            c = line[i]
            if in_comment:
                if line.startswith("*/", i):
                    in_comment = False
                    i += 1
            elif quote:
                if c == "\\":
                    i += 1
                elif c == quote:
                    quote = None
                    code.append(c)
            elif line.startswith("/*", i):
                in_comment = True
                i += 1
            elif line.startswith("//", i):
                break
            else:
                code.append(c)
                if c in "\"'":
                    quote = c
                elif not is_pp and c == "{":
                    depth += 1
                elif not is_pp and c == "}":
                    depth -= 1
            i += 1
        out.append((starts_in_comment, max(depth, 0), "".join(code)))
    return out


class Unit:
    def __init__(self, kind, lines, code):
        self.kind = kind      # blank, comment, pp or code
        self.lines = lines
        self.code = code      # code without comments, lines joined by \n
        self.comments = []    # comment units right above it
        self.directive = ""
        if kind == "pp":
            m = re.match(r"\s*#\s*(\w+)", lines[0])
            self.directive = m.group(1) if m else ""


def split_units(lines):
    info = scan(lines)
    units, i, n = [], 0, len(lines)
    while i < n:
        in_comment, _, code = info[i]
        stripped = lines[i].strip()
        if not in_comment and not stripped:
            units.append(Unit("blank", [lines[i]], ""))
            i += 1
        elif not in_comment and stripped.startswith("#"):
            j = i
            while lines[j].endswith("\\") and j + 1 < n:
                j += 1
            units.append(Unit("pp", lines[i:j + 1], ""))
            i = j + 1
        elif in_comment or not code.strip():
            j = i
            # Blank lines inside a block comment belong to it.
            while j < n and (info[j][0] or (
                    lines[j].strip() and not info[j][2].strip())):
                j += 1
            units.append(Unit("comment", lines[i:j], ""))
            i = j
        else:
            j = i
            while j + 1 < n:
                _, depth, code = info[j]
                if depth == 0 and not info[j + 1][0] and \
                        code.rstrip().endswith((";", "}")):
                    break
                j += 1
            units.append(Unit("code", lines[i:j + 1],
                              "\n".join(c for _, _, c in info[i:j + 1])))
            i = j + 1
    return units


def outer(code):
    """The code outside braces (what's left of a struct when its body goes)."""
    out, depth = [], 0
    for c in code:
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        elif depth == 0:
            out.append(c)
    return "".join(out)


def code_lines(u):
    """Lines of code, not counting a wrapped trailing comment."""
    return len(u.code.split("\n"))


def is_typedef(u):
    return u.kind == "code" and re.match(r"\s*typedef\b", u.code)


def is_record(u):
    """A plain struct/union/enum definition, without a variable."""
    return (u.kind == "code"
            and re.match(r"\s*(struct|union|enum)\b[^;(=]*\{", u.code)
            and u.code[u.code.rindex("}") + 1:].strip() == ";")


def is_function(u):
    if u.kind != "code" or "{" not in u.code or is_typedef(u) or is_record(u):
        return False
    last = u.code.rstrip().splitlines()[-1].strip()
    return "(" in u.code[:u.code.index("{")] and last.endswith("}") \
        and not last.endswith(";")


def is_main(u):
    return is_function(u) and re.search(r"\bmain\s*\(",
                                        u.code[:u.code.index("{")])


def names(u):
    """The names a typedef or definition introduces."""
    found = set()
    m = re.match(r"\s*(?:typedef\s+)?(?:struct|union|enum)\s+([A-Za-z_]\w*)",
                 u.code)
    if m:
        found.add(m.group(1))
    if re.match(r"\s*(?:typedef\s+)?enum\b", u.code) and "{" in u.code:
        body = u.code[u.code.index("{") + 1:u.code.rindex("}")]
        found |= set(re.findall(r"(?:^|,)\s*([A-Za-z_]\w*)", body))
    if is_typedef(u):
        rest = outer(u.code)
        if "{" in u.code:
            rest = u.code[u.code.rindex("}") + 1:]
        pointers = re.findall(r"\(\s*\*\s*([A-Za-z_]\w*)", rest)
        if pointers:
            found |= set(pointers)
        else:
            for decl in re.sub(r"\[[^\]]*\]", "", rest).rstrip(" ;\n").split(","):
                idents = IDENT.findall(decl)
                if idents:
                    found.add(idents[-1])
    return found


def sort_types(singles, multis):
    """One-liners first; then the rest longest first, each after what it uses.
    A one-liner that needs a multi-line type goes down with them."""
    items = singles + multis
    own = {id(u): names(u) for u in items}
    uses = {id(u): set(IDENT.findall(u.code)) - own[id(u)] for u in items}

    def deps(u, pool):
        return [v for v in pool if v is not u and own[id(v)] & uses[id(u)]]

    down = list(multis)
    changed = True
    while changed:
        changed = False
        for u in singles:
            if u not in down and deps(u, down):
                down.append(u)
                changed = True
    top = [u for u in singles if u not in down]
    order = {id(u): k for k, u in enumerate(items)}
    placed, left = [], sorted(down, key=lambda u: order[id(u)])
    while left:
        ready = [u for u in left if not deps(u, left)] or left[:1]
        pick = max(ready, key=lambda u: (code_lines(u), -order[id(u)]))
        placed.append(pick)
        left.remove(pick)
    return top, placed


def is_one_line_function(u):
    return is_function(u) and code_lines(u) == 1


def lines_of(u):
    return [l for c in u.comments for l in c.lines] + u.lines


def format_c(text):
    units = split_units(text.split("\n"))

    # Comments directly above a unit travel with it.
    merged = []
    for u in units:
        # The aligned rest of a wrapped trailing comment stays with its line.
        if u.kind == "comment" and u.lines[0].startswith(" ") and merged \
                and merged[-1].kind != "blank":
            merged[-1].lines += u.lines
            continue
        if u.kind != "blank" and u.kind != "comment" and merged \
                and merged[-1].kind == "comment":
            u.comments = [merged.pop()]
        merged.append(u)
    units = merged

    header, guard = [], []
    k = 0
    while k < len(units) and units[k].kind in ("comment", "blank"):
        if units[k].kind == "comment":
            header.append(units[k])
        k += 1
    if k < len(units) and units[k].kind == "pp":
        u = units[k]
        if u.directive == "pragma" and "once" in u.lines[0]:
            guard, k = [u], k + 1
        elif u.directive == "ifndef" and k + 1 < len(units):
            v = units[k + 1]
            name = u.lines[0].split()[-1]
            if v.kind == "pp" and v.directive == "define" \
                    and v.lines[0].split()[1:2] == [name]:
                guard, k = [u, v], k + 2

    includes, defines, singles, multis = [], [], [], []
    rest = []  # (unit, blank line before it)
    cond, undef, blank = 0, False, False
    for u in units[k:]:
        if u.kind == "blank":
            blank = True
            continue
        hoist = cond == 0
        if u.kind == "pp":
            if u.directive in ("if", "ifdef", "ifndef"):
                cond += 1
            elif u.directive == "endif":
                cond -= 1
            elif u.directive == "undef":
                undef = True
            if hoist and not undef and u.directive == "include":
                includes.append(u)
            elif hoist and not undef and u.directive == "define":
                defines.append(u)
            else:
                rest.append((u, blank))
        elif hoist and is_typedef(u) and code_lines(u) == 1:
            singles.append(u)
        elif hoist and (is_typedef(u) or is_record(u)):
            multis.append(u)
        else:
            rest.append((u, blank))
        blank = False

    def key(u):
        line = u.lines[0].split("//")[0].split("/*")[0].rstrip()
        return (len(line), line)

    top, placed = sort_types(singles, multis)
    blocks = [[l for u in header for l in u.lines],
              [l for u in guard for l in lines_of(u)],
              [l for u in sorted(includes, key=key) if "<" in u.lines[0]
               for l in lines_of(u)],
              [l for u in sorted(includes, key=key) if "<" not in u.lines[0]
               for l in lines_of(u)],
              [l for u in defines for l in lines_of(u)],
              [l for u in top for l in lines_of(u)]]
    blocks += [lines_of(u) for u in placed]
    chunks = [(b, False) for b in blocks if b]
    preamble = len(chunks)

    # The rest, in blank-separated chunks. Functions longer than a line get
    # one each; one-line functions written together stay together.
    def group(u):
        if is_main(u):
            return "main"
        if is_function(u):
            return "one-line" if is_one_line_function(u) else "function"
        return "other"

    prev = None
    for u, blank_before in rest:
        if blank_before or len(chunks) == preamble or group(u) in ("function", "main") \
                or group(u) != prev or prev == "main":
            chunks.append(([], False))
        prev = group(u)
        lines, has_main = chunks[-1]
        chunks[-1] = (lines + lines_of(u), has_main or bool(is_main(u)))

    out = []
    for n, (lines, has_main) in enumerate(chunks):
        if n:
            out += [""] * (3 if has_main or chunks[n - 1][1] else 1)
        out += lines
    return "\n".join(out).rstrip("\n") + "\n"


def mask(line):
    """The line with comments and string contents blanked out, same length."""
    out, quote, i = list(line), None, 0
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                out[i] = " "
                if i + 1 < len(line):
                    out[i + 1] = " "
                i += 1
            elif c == quote:
                quote = None
            else:
                out[i] = " "
        elif line.startswith("//", i) or line.startswith("/*", i):
            end = line.find("*/", i + 2) if line[i + 1] == "*" else -1
            stop = len(line) if end < 0 else end + 2
            out[i:stop] = " " * (stop - i)
            i = stop
            continue
        elif c in "\"'":
            quote = c
        i += 1
    return "".join(out)


ONE_LINE_BLOCK = re.compile(r"\{([^{}]*)\}")
PLACEHOLDER = re.compile(r"_cs(\d+)_*;")


def protect(text):
    """Swaps the bodies of one-line blocks with several statements (after an
    `if (...)`, a function header, `else` or `do`) for placeholders."""
    bodies, out = [], []
    for line in text.split("\n"):
        masked = mask(line)
        if masked.lstrip().startswith("#"):
            out.append(line)
            continue
        for m in reversed(list(ONE_LINE_BLOCK.finditer(masked))):
            before = masked[:m.start()].rstrip()
            if masked[m.start(1):m.end(1)].count(";") < 2 or not (
                    before.endswith(")") or re.search(r"\b(else|do)$", before)):
                continue
            n = len(bodies)
            bodies.append(line[m.start(1):m.end(1)].strip())
            line = line[:m.start(1)] + " _cs%d; " % n + line[m.end(1):]
        out.append(line)
    return "\n".join(out), bodies


FILENAMES = {"c": "file.c", "java": "File.java"}


def run(clang_format, style, text, lang):
    return subprocess.run([clang_format, "--style=" + style,
                           "--assume-filename=" + FILENAMES[lang]],
                          input=text, capture_output=True, text=True,
                          check=True).stdout


def format_bodies(clang_format, style_file, bodies, lang):
    """Each body formatted by clang-format in the same style, one line per
    statement."""
    if not bodies:
        return []
    snippet = "".join("void _cs%d() {\n%s\n}\n" % (n, b)
                      for n, b in enumerate(bodies))
    if lang == "java":
        snippet = "class _Cs {\n" + snippet + "}\n"
    overrides = {"ColumnLimit": "0", "AllowShortFunctionsOnASingleLine": "None",
                 "AllowShortIfStatementsOnASingleLine": "Never",
                 "AllowShortLoopsOnASingleLine": "false",
                 "AllowShortBlocksOnASingleLine": "Never"}
    lines = [l for l in open(style_file).read().split("\n")
             if l.split(":")[0] not in overrides]
    # Into the shared section, before the per-language ones.
    at = lines.index("---") if "---" in lines else len(lines)
    lines[at:at] = ["%s: %s" % kv for kv in overrides.items()]
    style = "\n".join(lines) + "\n"
    with tempfile.NamedTemporaryFile("w", suffix=".yaml") as f:
        f.write(style)
        f.flush()
        formatted = run(clang_format, "file:" + f.name, snippet, lang)
    # Each line keeps its indentation relative to the body.
    lines, out, base = formatted.split("\n"), [], 4 if lang == "java" else 2
    for line in lines[1:-2] if lang == "java" else lines:
        if line.strip().startswith("void _cs"):
            out.append([])
        elif line.strip() and line != " " * (base - 2) + "}" and out:
            out[-1].append(line[base:] if line.startswith(" " * base)
                           else line.strip())
    return out


def restore(text, bodies):
    out = []
    for line in text.split("\n"):
        m = PLACEHOLDER.search(line)
        while m:
            body = bodies[int(m.group(1))]
            if line.strip() == m.group(0):
                indent = line[:len(line) - len(line.lstrip())]
                out += [indent + b for b in body[:-1]]
                line = indent + body[-1]
            else:
                line = line[:m.start()] + " ".join(b.strip() for b in body) + \
                    line[m.end():]
            m = PLACEHOLDER.search(line)
        out.append(line)
    return "\n".join(out)


LIMIT = 80
LANG = "c"
CONTROL = re.compile(r"(\s*)(?:(?:else\s+)?if|for|while)\s*\(|(\s*)else$")
NESTED = re.compile(r"(if|else|for|while|do|switch)\b")


def balanced(code):
    depth = 0
    for c in code:
        depth += {"(": 1, ")": -1}.get(c, 0)
        if depth < 0:
            return False
    return depth == 0


def join_short_controls(text):
    """`if (x)` / `  stmt;` back onto one line when it fits."""
    lines, out, i = text.split("\n"), [], 0
    while i < len(lines):
        line = lines[i]
        code = mask(line).rstrip()
        m = CONTROL.match(code)
        if m and i + 1 < len(lines) and code == line.rstrip() and \
                (code.endswith(")") or code.strip() == "else") and \
                balanced(code):
            indent = m.group(1) if m.group(1) is not None else m.group(2)
            nxt = lines[i + 1]
            body = mask(nxt)
            if nxt.startswith(indent + "  ") and \
                    not nxt.startswith(indent + "   ") and \
                    body.rstrip().endswith(";") and balanced(body) and \
                    not NESTED.match(nxt.strip()) and \
                    len(line.rstrip() + " " + nxt.strip()) <= LIMIT:
                out.append(line.rstrip() + " " + nxt.strip())
                i += 2
                continue
        out.append(line)
        i += 1
    return "\n".join(out)


CALL = re.compile(r"(?P<prefix>[^()]*?)(?P<name>[A-Za-z_][\w.]*(?:->[\w.]+)*)"
                  r"(?P<space> ?)\((?P<args>.*)\)(?P<end>;| \{)$")


def split_args(args):
    """Top-level comma-separated arguments, or None if they can't be split."""
    masked, out, depth, start = mask(args), [], 0, 0
    for i, c in enumerate(masked):
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
            if depth < 0:
                return None
        elif c == "," and depth == 0:
            out.append(args[start:i].strip())
            start = i + 1
    out.append(args[start:].strip())
    return out if depth == 0 and all(out) else None


LITERALS = re.compile(r'\s*(?:"(?:[^"\\]|\\.)*"\s*)+')
PIECE = re.compile(r'"((?:[^"\\]|\\.)*)"')


def split_literal(arg, first, cont, suffix):
    """A string literal (or adjacent ones) spread over lines that start with
    `first` and then `cont`, cut after spaces, the last line ending with
    `suffix`; None if it isn't a literal or can't be cut."""
    if not LITERALS.fullmatch(arg):
        return None
    pieces = PIECE.findall(arg)
    # Joining "\x4" "1" would change the escape; leave those alone.
    if any(re.search(r"\\(x[0-9a-fA-F]*|[0-7]{1,2})$", p) for p in pieces[:-1]):
        return None
    text, lines, start = "".join(pieces), [], first
    while True:
        if len(start) + len(text) + 2 + len(suffix) <= LIMIT:
            return lines + [start + '"' + text + '"' + suffix]
        room = LIMIT - len(start) - 2
        cut = text.rfind(" ", 0, room) + 1
        if cut <= 0 or cut >= len(text):
            return None
        lines.append(start + '"' + text[:cut] + '"')
        text, start = text[cut:], cont


def pack(indent, joined):
    """The statement laid out as described above, or None to leave it."""
    m = CALL.match(joined)
    if not m or m.group("name") in ("if", "for", "while", "switch", "return"):
        return None
    args = split_args(m.group("args"))
    if not args:
        return None
    head = indent + m.group("prefix") + m.group("name") + m.group("space") + "("
    # Split over lines, the call closes like a block: `);` on its own line.
    close = indent + ")" + m.group("end")
    tail = ""
    cont = indent + "  "
    first_end = "," if len(args) > 1 else tail
    lines, line, rest = [], None, args[1:]
    # Prototypes and definitions (the ones with a space before the bracket)
    # take all their parameters below the opening bracket.
    if m.group("space"):
        if len(head) > LIMIT:
            return None
        lines, rest = [head], args
    elif len(head + args[0] + first_end) <= LIMIT:
        lines = [head + args[0] + first_end]
    else:
        # A long string first: it starts on the first line and is cut into
        # pieces; the other arguments follow its last piece.
        # (Java doesn't join adjacent literals, so there it isn't cut.)
        pieces = LANG != "java" and split_literal(args[0], head, cont, first_end)
        if pieces:
            lines, line = pieces[:-1], pieces[-1]
        elif len(head) <= LIMIT and len(args) > 1:
            lines, rest = [head], args
        else:
            return None
    for n, arg in enumerate(rest):
        end = tail if n == len(rest) - 1 else ","
        if line is not None and len(line + " " + arg + end) <= LIMIT:
            line += " " + arg + end
            continue
        if line is not None:
            lines.append(line)
        line = cont + arg + end
        if len(line) > LIMIT:
            return None
    if line is not None:
        lines.append(line)
    return lines + [close]


def repack_calls(text):
    lines, out, i = text.split("\n"), [], 0
    while i < len(lines):
        first = mask(lines[i]).rstrip()
        j = i
        if first.strip() and not first.lstrip().startswith(("#", "//", "/*")) \
                and first.endswith((",", "(", "=", '"')):
            indent = lines[i][:len(lines[i]) - len(lines[i].lstrip())]
            while j + 1 < len(lines) and lines[j + 1].startswith(indent + " ") \
                    and not mask(lines[j]).rstrip().endswith((";", "{")):
                j += 1
        if j > i and mask(lines[j]).rstrip().endswith((";", "{")):
            joined = ""
            for l in lines[i:j + 1]:
                sep = "" if not joined or joined.endswith("(") else " "
                joined += sep + l.strip()
            packed = pack(lines[i][:len(lines[i]) - len(lines[i].lstrip())],
                          joined.strip())
            if packed:
                out += packed
                i = j + 1
                continue
        out += lines[i:j + 1]
        i = j + 1
    return "\n".join(out)


def split_comment(line):
    """(code, trailing comment) of a line, or None if a comment sits in the
    middle of the code."""
    quote, i = None, 0
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                i += 1
            elif c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif line.startswith("//", i):
            return line[:i].rstrip(), line[i:].strip()
        elif line.startswith("/*", i):
            end = line.find("*/", i)
            if end >= 0 and line[end + 2:].strip():
                return None
            return line[:i].rstrip(), line[i:].strip()
        i += 1
    return line.rstrip(), ""


INIT = re.compile(r"(?P<head>\s*[^{}()]*=\s*)\{(?P<body>.*)$")


def layout_init(lines):
    """The initializer in `lines` laid out as described above, or None."""
    m = INIT.match(lines[0])
    if not m:
        return None
    indent = lines[0][:len(lines[0]) - len(lines[0].lstrip())]
    cont = indent + "  "
    content = [m.group("body")] + [l.strip() for l in lines[1:]]
    last = split_comment(content[-1])
    if last is None or not last[0].endswith("};"):
        return None
    content[-1] = (last[0][:-2] + " " + last[1]).strip()

    rows = []  # (items, comment)
    for k, line in enumerate(content):
        parts = split_comment(line)
        if parts is None:
            return None
        code, comment = parts
        # The aligned rest of a trailing comment clang-format wrapped goes
        # back onto its line.
        lead = len(lines[k]) - len(lines[k].lstrip()) if k else 0
        if not code.strip() and comment.startswith("//") and lead > len(cont) \
                and rows and rows[-1][1].startswith("//"):
            rows[-1] = (rows[-1][0], rows[-1][1] + " " + comment[2:].strip())
            continue
        items = split_args(code.rstrip(",")) if code.strip() else []
        if items is None:
            return None
        rows.append((items, comment))
    total = sum(len(items) for items, _ in rows)
    trailing = content and split_comment(content[-1])[0].endswith(",")

    out, line, n = [], None, 0
    for items, comment in rows:
        for item in items:
            n += 1
            item += "," if n < total or trailing else ""
            if line is not None and len(line + " " + item) <= LIMIT:
                line += " " + item
            else:
                if line is not None:
                    out.append([line, ""])
                line = cont + item
                if len(line) > LIMIT:
                    return None
        if comment:
            if line is None:
                out.append([cont + comment, None])
            else:
                out.append([line, comment])
                line = None
    if line is not None:
        out.append([line, ""])

    width = max([len(l) for l, c in out if c] or [0])
    fits = all(width + 1 + len(c) <= LIMIT for l, c in out if c)
    result = [m.group("head").rstrip() + " {"]
    for code, comment in out:
        if comment:
            pad = width - len(code) + 1 if fits else 1
            result.append(code + " " * pad + comment)
        else:
            result.append(code)
    return result + [indent + "};"]


def repack_inits(text):
    lines, out, i = text.split("\n"), [], 0
    while i < len(lines):
        m = INIT.match(mask(lines[i]))
        if m:
            depth, j = 0, i
            while j < len(lines):
                code = mask(lines[j])
                depth += code.count("{") - code.count("}")
                if depth <= 0:
                    break
                j += 1
            if j > i and j < len(lines):
                laid = layout_init(lines[i:j + 1])
                if laid:
                    out += laid
                    i = j + 1
                    continue
        out.append(lines[i])
        i += 1
    return "\n".join(out)


# Java ----------------------------------------------------------------------

TYPE_DECL = re.compile(r"\b(class|interface|enum|record)\s+([A-Za-z_]\w*)")
ANNOTATION = re.compile(r"\s*@(?!interface\b)[\w.]+(?:\s*\([^()]*(?:\([^()]*\)[^()]*)*\))?")
MODIFIERS = re.compile(r"\s*((?:(?:public|protected|private|static|final|abstract|"
                       r"synchronized|native|transient|volatile|strictfp|default|"
                       r"sealed|non-sealed)\s+)*)")


def space_constructors(text):
    """`Name (int a)` for constructors, like any other declaration
    (clang-format only spaces methods)."""
    names = {m.group(2) for m in TYPE_DECL.finditer(mask_all(text))}
    if not names:
        return text
    ctor = re.compile(r"\s*(?:(?:public|protected|private)\s+)?(?:<[^>]*>\s*)?"
                      r"(?P<name>" + "|".join(map(re.escape, sorted(names))) +
                      r")\(")
    out = []
    for line in text.split("\n"):
        m = ctor.match(mask(line))
        if m:
            line = line[:m.end("name")] + " " + line[m.end("name"):]
        out.append(line)
    return "\n".join(out)


def mask_all(text):
    return "\n".join(mask(l) for l in text.split("\n"))


def strip_annotations(code):
    while True:
        m = ANNOTATION.match(code)
        if not m:
            return code
        code = code[m.end():]


class Member:
    def __init__(self, unit, blank_before, floating):
        self.unit = unit
        self.blank_before = blank_before
        self.floating = floating   # comments above it, a blank line apart
        code = " ".join(strip_annotations(unit.code).split())
        self.code = code
        self.head = re.split(r"[{;=]", code, 1)[0]
        mods = MODIFIERS.match(code).group(1).split()
        self.static = "static" in mods
        self.kind, self.name = self.classify()

    def classify(self):
        head = self.head
        if TYPE_DECL.search(head) or head.lstrip().startswith("@interface"):
            return "type", ""
        if self.code.startswith("{") or re.fullmatch(r"static\s*", head):
            return "init", ""
        before = re.split(r"[=;]", self.code, 1)[0]
        m = re.search(r"([A-Za-z_]\w*)\s*\($", before.split("(")[0] + "(") \
            if "(" in before else None
        if m:
            words = MODIFIERS.sub("", before.split("(")[0], 1).split()
            return ("ctor" if len(words) == 1 else "method"), m.group(1)
        idents = IDENT.findall(re.sub(r"<[^<>]*>", "", head))
        return "field", idents[-1] if idents else ""

    def lines(self):
        out = []
        for n, c in enumerate(self.unit.comments):
            out += c.lines
            if self.floating and n == len(self.unit.comments) - 1:
                out.append("")
        return out + self.unit.lines

    def one_line(self):
        return len(self.unit.lines) == 1


def body_units(lines, indent):
    """Members of a class body, with the comments above each one."""
    units, merged = split_units(lines), []
    blank = False
    pending = []          # comment units waiting for the member below
    floating = False
    members, trailing = [], []
    for u in units:
        if u.kind == "blank":
            if pending:
                floating = True
            blank = True
            continue
        # The aligned rest of a wrapped trailing comment stays with its line.
        lead = len(u.lines[0]) - len(u.lines[0].lstrip())
        if u.kind == "comment" and lead > len(indent) and members \
                and not blank and not pending:
            members[-1].unit.lines += u.lines
            continue
        if u.kind == "comment":
            if pending and blank:
                floating = True
            pending.append(u)
            blank = False
            continue
        u.comments = pending
        members.append(Member(u, blank, floating and bool(pending)))
        pending, floating, blank = [], False, False
    trailing = [l for u in pending for l in u.lines]
    return members, trailing


def property_of(member, fields):
    m = re.fullmatch(r"(get|is|set)([A-Z]\w*)", member.name)
    if not m or member.kind != "method":
        return None
    name = m.group(2)[0].lower() + m.group(2)[1:]
    if name not in fields:
        return None
    return m.group(1) == "set", fields.index(name)


def pack_constants(member, indent):
    """Enum constants packed onto as few lines as fit, like initializers
    (clang-format puts one per line when the enum has a body)."""
    code = member.unit.code.strip()
    if member.unit.comments or "{" in code or "//" in "".join(member.unit.lines) \
            or not code.endswith(";"):
        return member.lines()
    items = split_args(" ".join(code[:-1].split()))
    if not items:
        return member.lines()
    out, line = [], None
    for n, item in enumerate(items):
        item += ";" if n == len(items) - 1 else ","
        if line is not None and len(line + " " + item) <= LIMIT:
            line += " " + item
        else:
            if line is not None:
                out.append(line)
            line = indent + item
    return out + [line]


# A comment that only names a block of accessors (// Getters, // Setters,
# // Getters y setters...): dropped and written again where it belongs.
LABEL = re.compile(r"\s*//\s*(getters?|setters?)(\s*(y|and|&|/|,)\s*"
                   r"(getters?|setters?))?\s*:?\s*$", re.IGNORECASE)


def join_short_method(lines):
    """A method whose body is a single statement on one line when it fits
    (clang-format leaves it split when an annotation sits above it)."""
    if len(lines) < 3 or mask(lines[-1]).strip() != "}":
        return lines
    head, stmt = lines[-3], lines[-2]
    code = mask(stmt).strip()
    if not mask(head).rstrip().endswith("{") or "{" in code or "}" in code \
            or not code.endswith(";") or "//" in stmt or "/*" in stmt \
            or NESTED.match(stmt.strip()):
        return lines
    # The header must start on that line (annotations above are fine).
    if mask(head).lstrip().startswith((")", "@")) or (
            len(lines) > 3 and mask(lines[-4]).rstrip().endswith((",", "("))):
        return lines
    joined = head.rstrip() + " " + stmt.strip() + " }"
    return lines[:-3] + [joined] if len(joined) <= LIMIT else lines


def organize(lines, enum):
    """A class body laid out in the order described above."""
    indent = next((l[:len(l) - len(l.lstrip())] for l in lines if l.strip()), "")
    members, trailing = body_units(lines, indent)
    constants = []
    if enum and members:
        constants = [members.pop(0)]
    for m in members:
        if m.kind == "type":
            m.unit.lines = organize_type(m.unit.lines)
        elif m.kind in ("method", "ctor"):
            m.unit.lines = join_short_method(m.unit.lines)
    fields = [m.name for m in members if m.kind == "field"]
    groups = {k: [] for k in ("types", "static", "fields", "ctors", "methods",
                              "accessors", "overrides", "main")}
    accessors = []
    for m in members:
        if m.kind == "type":
            groups["types"].append(m)
        elif m.kind in ("field", "init"):
            groups["static" if m.static else "fields"].append(m)
        elif m.kind == "ctor":
            groups["ctors"].append(m)
        elif m.name == "main" and m.static:
            groups["main"].append(m)
        elif property_of(m, fields) is not None:
            accessors.append(m)
        elif re.search(r"@Override\b", m.unit.code):
            groups["overrides"].append(m)
        else:
            groups["methods"].append(m)
    accessors.sort(key=lambda m: property_of(m, fields))

    # Accessors of one property stay together; with more, getters and
    # setters are two blocks, each labelled when it has several methods.
    for m in accessors:
        for c in m.unit.comments:
            while c.lines and LABEL.match(c.lines[0]):
                c.lines.pop(0)
        m.unit.comments = [c for c in m.unit.comments if c.lines]
        if not m.unit.comments:
            m.floating = False
    several = len({property_of(m, fields)[1] for m in accessors}) > 1
    labels = {}
    if several:
        for setter, label in ((False, "// Getters"), (True, "// Setters")):
            block = [m for m in accessors if property_of(m, fields)[0] == setter]
            if len(block) > 1:
                labels[id(block[0])] = indent + label
    groups["accessors"] = accessors

    out = []
    if constants:
        out += pack_constants(constants[0], indent)
    for name, group in groups.items():
        for n, m in enumerate(group):
            if not out:
                pass
            elif name == "main":
                out += [""] * 3
            elif n == 0:
                out.append("")
            elif name in ("static", "fields"):
                if m.blank_before or m.unit.comments:
                    out.append("")
            elif name == "accessors":
                # Getters together and setters together, however long; a
                # blank line between the two blocks.
                if m.unit.comments or several and property_of(m, fields)[0] != \
                        property_of(group[n - 1], fields)[0]:
                    out.append("")
            elif m.unit.comments or not (
                    m.one_line() and group[n - 1].one_line() and
                    not m.blank_before):
                out.append("")
            if id(m) in labels:
                out.append(labels[id(m)])
            out += m.lines()
    if trailing:
        out += ([""] if out else []) + trailing
    return out


def organize_type(lines):
    """A type declaration with its body organized; one-liners stay as they are."""
    info = scan(lines)
    open_at = next((k for k, (_, depth, _) in enumerate(info) if depth > 0), None)
    if open_at is None or open_at == len(lines) - 1:
        return lines
    last = mask(lines[-1]).strip()
    if not last.startswith("}"):
        return lines
    head = " ".join(mask(l) for l in lines[:open_at + 1])
    enum = re.search(r"\benum\b", strip_annotations(head)) is not None
    if mask(lines[open_at]).rstrip()[-1:] != "{":
        return lines
    body = organize(lines[open_at + 1:-1], enum)
    # A blank line between the declaration and its first member.
    return lines[:open_at + 1] + ([""] if body else []) + body + lines[-1:]


def format_java(text):
    lines = text.rstrip("\n").split("\n")
    # Text blocks can hold anything; leave those files as clang-format left them.
    if '"""' in text:
        return text.rstrip("\n") + "\n"
    units = split_units(lines)
    header, package, imports, rest = [], [], [], []
    pending, blank = [], False
    for u in units:
        if u.kind == "blank":
            blank = True
            continue
        code = u.code.strip() if u.kind == "code" else ""
        if u.kind == "comment":
            if not package and not imports and not rest:
                header.append(u)
            else:
                pending.append(u)
        elif code.startswith("package ") and not rest:
            package = pending + [u]
            pending = []
        elif code.startswith("import ") and not rest:
            u.comments, pending = pending, []
            imports.append(u)
        else:
            u.comments, pending = pending, []
            rest.append((u, blank))
        blank = False

    def key(u):
        line = u.lines[0].split("//")[0].rstrip()
        return (len(line), line)

    seen, unique = set(), []
    for u in imports:
        if u.lines[0].strip() not in seen:
            seen.add(u.lines[0].strip())
            unique.append(u)
    static = [u for u in unique if re.match(r"\s*import\s+static\b", u.lines[0])]
    plain = [u for u in unique if u not in static]
    jdk = [u for u in plain if re.match(r"\s*import\s+javax?\.", u.lines[0])]
    others = [u for u in plain if u not in jdk]

    blocks = [[l for u in header for l in u.lines],
              [l for u in package for l in u.lines]]
    for group in (jdk, others, static):
        blocks.append([l for u in sorted(group, key=key) for l in lines_of(u)])
    chunks = [b for b in blocks if b]
    for n, (u, blank_before) in enumerate(rest):
        body = lines_of(u)
        if u.kind == "code" and TYPE_DECL.search(strip_annotations(u.code)):
            body = [l for c in u.comments for l in c.lines] + organize_type(u.lines)
        if n == 0 or blank_before or u.kind == "code":
            chunks.append(body)
        else:
            chunks[-1] += body
    if pending:
        chunks.append([l for u in pending for l in u.lines])

    out = []
    for n, chunk in enumerate(chunks):
        if n:
            out.append("")
        out += chunk
    result = "\n".join(out).rstrip("\n") + "\n"
    # Only ever moves code around: if any token changed, keep the input.
    # (Accessor labels are the exception: they're rewritten.)
    def content(t):
        return sorted(w for l in t.split("\n") if not LABEL.match(l)
                      for w in l.split())
    deduped = text
    for u in imports:
        if u not in unique:
            deduped = deduped.replace(u.lines[0] + "\n", "", 1)
    if content(result) != content(deduped):
        if os.environ.get("CODE_STYLE_DEBUG"):
            sys.stderr.write("code-style: member reordering skipped\n")
        return text.rstrip("\n") + "\n"
    return result


def main():
    global LANG
    lang, clang_format, style_file = sys.argv[1:4]
    LANG = lang
    source = sys.stdin.read()
    text, bodies = protect(source)
    bodies = format_bodies(clang_format, style_file, bodies, lang)
    # The placeholders take the length of the formatted bodies, so
    # clang-format keeps a block on one line only if the real one fits.
    text = PLACEHOLDER.sub(
        lambda m: ("_cs" + m.group(1)).ljust(
            len(" ".join(b.strip() for b in bodies[int(m.group(1))])) - 1,
            "_") + ";", text)
    text = restore(run(clang_format, "file:" + style_file, text, lang), bodies)
    if lang == "java":
        text = space_constructors(text)
    text = repack_inits(repack_calls(join_short_controls(text)))
    sys.stdout.write(format_java(text) if lang == "java" else format_c(text))


if __name__ == "__main__":
    main()
