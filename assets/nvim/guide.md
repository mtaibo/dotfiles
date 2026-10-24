# My guide

Only the commands I actually use. Everything else Vim can do is in **Vim help** (the switch at the top left). `Space c v` means: press Space, then `c`, then `v`.

## Comments

| Keys | Does |
|---|---|
| `Ctrl+/` | Comment or uncomment the line, or every selected line in visual mode (works while typing too) |
| `gcc` | The same, the Vim way |
| `gc` + a motion | Comment a stretch: `gcap` the paragraph, `gc3j` this line and the 3 below, `gcG` to the end of the file |

The comment style comes from the language at the cursor: `//` in C and Java, `#` in Nix and shell scripts, `--` in Lua, `<!-- -->` in Markdown and HTML, and the right one inside embedded code too.

## Definitions and uses

| Keys | Does |
|---|---|
| `gd` | **Go to definition.** On a call: to the function's code (the `.c`). On a function's name where it's written, or anywhere inside its body: to its prototype (the `.h`). On a prototype: to the code. Anywhere else (a variable, a type): its definition |
| `gn` | **Next use** of that same function: the one under the cursor, or the one you're inside. Again and again walks through every call, file by file, and wraps around |
| `gN` | Previous use |
| `Ctrl+o` / `Ctrl+i` | Back / forward to where you were before the jump |
| `F12` | Plain definition of whatever is under the cursor (a variable inside a body too) |
| `Shift+F12` | Every use, in a list to pick from |
| `K` | Documentation of what's under the cursor |

Uses in files that aren't open need the project indexed: clangd reads `compile_commands.json` (CMake writes it with `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`; `bear -- make` makes one from a Makefile). Without it only the open files count. In Java jdtls indexes the project by itself.

## Folding functions

| Keys | Does |
|---|---|
| `:fold` | Fold every function so only its first line shows, except `main`. Structs, typedefs and globals stay open. In Java: every method and constructor except `main`; classes and fields stay open |
| `:fold` again | Open them all back |
| `za` | Open or close only the one under the cursor |
| `zR` / `zM` | Open / close every fold |

## Terminal

| Keys | Does |
|---|---|
| `:terminal` or `:term` | A shell in the editor window, like one more file; again goes back to it |
| `:terminal cmd` | Run a command there instead (it stays open with the output) |
| `Esc Esc` | Normal mode inside it: scroll, search and copy like in a file; `i` to type again |
| `q` | Close it (in normal mode); `exit` in the shell closes it too |
| ``Ctrl+` `` | A terminal at the bottom instead, toggled |
| `:make` / `Space m` | Save everything and run make from the nearest Makefile (`:make run` with targets) |

## Java tests

| Keys | Does |
|---|---|
| `:test` | Save everything and run `mvn test` next to the nearest `pom.xml` (Gradle's tests or `make test` in other projects), in a terminal tab |
| `:test ColegioTest` | Only that test class (several: `:test ColegioTest IntegranteTest`) |
| `q` | Close the output |

## Markdown

| Keys | Does |
|---|---|
| `:md` / `Space c v` | Preview in the browser, live, following the cursor and the scroll; again to close it |
| `Space c V` | Preview inside the terminal |
| `Space u m` | Render the Markdown in place, in the file itself |

## This page

| Keys | Does |
|---|---|
| `:help` | Opens this page (`:help topic` is still Vim's own manual) |
