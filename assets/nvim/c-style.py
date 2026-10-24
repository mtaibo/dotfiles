"""Formats a C file: clang-format, plus the layout rules clang-format can't
express. Reads the file on stdin, writes it to stdout.

    c-style.py CLANG_FORMAT STYLE_FILE < file.c

- Blocks with several statements that fit on one line, such as
  `if (x) { printf("..."); return 1; }`, stay on one line (clang-format always
  splits them): their bodies are swapped for a placeholder of the same length
  while clang-format runs.
- A call, prototype or function header that doesn't fit in 80 columns keeps
  its first argument on the first line and packs the rest together below,
  two spaces further in (clang-format fills the first line instead).
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
"""
import re
import subprocess
import sys

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
            while j < n and lines[j].strip() and (
                    info[j][0] or not info[j][2].strip()):
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


def run(clang_format, style, text):
    return subprocess.run([clang_format, "--style=" + style,
                           "--assume-filename=file.c"], input=text,
                          capture_output=True, text=True, check=True).stdout


def format_bodies(clang_format, bodies):
    """Each body formatted by clang-format, one line per statement."""
    if not bodies:
        return []
    snippet = "".join("void _cs%d(void) {\n%s\n}\n" % (n, b)
                      for n, b in enumerate(bodies))
    style = "{BasedOnStyle: LLVM, ColumnLimit: 0, " \
            "AllowShortFunctionsOnASingleLine: None}"
    lines, out = run(clang_format, style, snippet).split("\n"), []
    for line in lines:
        if line.startswith("void _cs"):
            out.append([])
        elif line.strip() and line != "}" and out:
            out[-1].append(line.strip())
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
                line = line[:m.start()] + " ".join(body) + line[m.end():]
            m = PLACEHOLDER.search(line)
        out.append(line)
    return "\n".join(out)


LIMIT = 80
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


def pack(indent, joined):
    """The statement laid out as described above, or None to leave it."""
    m = CALL.match(joined)
    if not m or m.group("name") in ("if", "for", "while", "switch", "return"):
        return None
    args = split_args(m.group("args"))
    if not args or len(args) < 2:
        return None
    head = indent + m.group("prefix") + m.group("name") + m.group("space") + "("
    tail = ")" + m.group("end")
    if len(head + args[0] + ",") <= LIMIT:
        lines, rest = [head + args[0] + ","], args[1:]
    elif len(head) <= LIMIT:
        lines, rest = [head], args
    else:
        return None
    cont, line = indent + "  ", None
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
    lines.append(line)
    return lines


def repack_calls(text):
    lines, out, i = text.split("\n"), [], 0
    while i < len(lines):
        first = mask(lines[i]).rstrip()
        j = i
        if first.strip() and not first.lstrip().startswith(("#", "//", "/*")) \
                and first.endswith((",", "(", "=")):
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
    for line in content:
        parts = split_comment(line)
        if parts is None:
            return None
        code, comment = parts
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


def main():
    clang_format, style_file = sys.argv[1], sys.argv[2]
    text, bodies = protect(sys.stdin.read())
    bodies = format_bodies(clang_format, bodies)
    # The placeholders take the length of the formatted bodies, so
    # clang-format keeps a block on one line only if the real one fits.
    text = PLACEHOLDER.sub(
        lambda m: ("_cs" + m.group(1)).ljust(
            len(" ".join(bodies[int(m.group(1))])) - 1, "_") + ";", text)
    text = run(clang_format, "file:" + style_file, text)
    sys.stdout.write(format_c(repack_inits(repack_calls(restore(text, bodies)))))


if __name__ == "__main__":
    main()
