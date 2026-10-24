# Neovim

My Neovim is [LazyVim](https://www.lazyvim.org) inside kitty, set up to replace VS Code: an explorer, tabs, fuzzy finders, LSP, a debugger and tests, with C/C++ and Java ready to go, and VS Code's shortcuts on top of LazyVim's own. Everything is declared in [`modules/home/editors/nvim.nix`](modules/home/editors/nvim.nix); this file is the cheat sheet.

- [The basics](#the-basics)
- [VS Code shortcuts](#vs-code-shortcuts)
- [Files and search](#files-and-search)
- [Explorer](#explorer)
- [Buffers, windows and tabs](#buffers-windows-and-tabs)
- [Editing](#editing)
- [Code (LSP)](#code-lsp)
- [Completion](#completion)
- [C and C++](#c-and-c)
- [Java](#java)
- [Debugging](#debugging)
- [Tests](#tests)
- [Git](#git)
- [Terminal](#terminal)
- [Markdown](#markdown)
- [Toggles](#toggles)
- [Sessions, plugins and tools](#sessions-plugins-and-tools)
- [How it's set up](#how-its-set-up)

## The basics

- **Space is the leader key.** Press it and wait: which-key pops up with every command grouped by letter (`f` files, `s` search, `c` code, `g` git, `d` debug, `t` tests, `u` toggles…). `Space ?` lists the keys of the current buffer, `Space s k` searches all keymaps.
- **The mouse works everywhere**: click to place the cursor, select, scroll, click tabs and their ×, click files in the explorer (a single click opens them).
- **Modes**: Normal (move and run commands), Insert (`i`, `a`, `o` to type; `Esc` to leave), Visual (`v` characters, `V` lines, `Ctrl+V` block). Undo `u`, redo `Ctrl+R`.
- **The first launch** downloads the plugins and Mason's tools (about a minute). `Space l` opens Lazy, the plugin manager; `Space c m` opens Mason.

In the tables, `Space f f` means: press Space, then `f`, then `f`.

## VS Code shortcuts

Added on top of LazyVim's keys, so muscle memory from VS Code still works.

| Keys | Action |
|---|---|
| `Ctrl+S` | Save |
| `Ctrl+P` | Go to file |
| `Ctrl+Shift+P` | Command palette |
| `Ctrl+Shift+F` | Search in files |
| `Ctrl+B` | Toggle the explorer |
| ``Ctrl+` `` | Toggle the terminal |
| `Ctrl+/` | Toggle comment (line, or the selection) |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Next / previous tab |
| `Alt+↑` / `Alt+↓` | Move the line or selection up / down |
| `F12` / `Shift+F12` | Go to definition / references |
| `F2` | Rename symbol |
| `Ctrl+.` | Quick fix (code actions) |
| `F5` / `Shift+F5` | Start or continue debugging / stop |
| `F9` | Toggle breakpoint |
| `F10` / `F11` / `Shift+F11` | Step over / into / out |

kitty normally keeps `Ctrl+Shift+P`, `Ctrl+Shift+F` and `Ctrl+Tab` for itself; [`assets/kitty/unmap.conf`](assets/kitty/unmap.conf) frees them so they reach Neovim.

## Files and search

| Keys | Action |
|---|---|
| `Space Space` or `Space f f` | Find files (project root) |
| `Space f r` | Recent files |
| `Space ,` or `Space f b` | Open buffers |
| `Space f n` | New file |
| `Space f c` | Find a config file |
| `Space /` or `Space s g` | Grep the project |
| `Space s w` | Grep the word under the cursor (or the selection) |
| `Space s r` | Search and replace across files |
| `Space s b` | Lines in the current buffer |
| `Space s s` / `Space s S` | Symbols in the file / in the workspace |
| `Space s d` | Diagnostics |
| `Space s t` | TODO / FIXME comments |
| `Space s h` | Help pages |
| `Space s k` | Keymaps |
| `Space s C` | Commands |
| `Space s R` | Resume the last search |
| `Space s u` | Undo tree |

Inside a picker: type to filter, `↑`/`↓` or `Ctrl+J`/`Ctrl+K` to move, `Enter` to open, `Ctrl+V` / `Ctrl+S` to open in a vertical / horizontal split, `Esc` to close.

## Explorer

`Ctrl+B` or `Space e` toggles Neo-tree at the project root, `Space E` at the current directory. A single click opens a file.

| Key (in the tree) | Action |
|---|---|
| `Enter`, `l` or a click | Open |
| `h` | Collapse the folder |
| `a` | New file (end the name with `/` for a folder) |
| `A` | New folder |
| `r` | Rename |
| `d` | Delete |
| `y` / `x` / `p` | Copy / cut / paste |
| `c` / `m` | Copy to / move to (asks for the path) |
| `Y` | Copy the path |
| `O` | Open with the system's app |
| `P` | Toggle the preview |
| `s` / `S` / `t` | Open in a vertical split / horizontal split / new tab |
| `H` | Show or hide hidden files |
| `/` | Filter |
| `.` / `Backspace` | Make this folder the root / go up |
| `z` | Collapse everything |
| `R` | Refresh |
| `?` | All the keys |
| `q` | Close |

## Buffers, windows and tabs

Each open file is a *buffer*, shown as a tab in the bar at the top.

| Keys | Action |
|---|---|
| `Shift+H` / `Shift+L` | Previous / next buffer |
| `[b` / `]b` | Same |
| `[B` / `]B` | Move the buffer left / right in the bar |
| `Space b b` or ``Space ` `` | Switch to the last buffer |
| `Space b d` | Close the buffer |
| `Space b o` | Close the others |
| `Space b l` / `Space b r` | Close the ones to the left / right |
| `Space b p` / `Space b P` | Pin / close the unpinned ones |
| `Space b j` | Pick a buffer by letter |

| Keys | Action |
|---|---|
| `Space -` / `Space \|` | Split below / to the right |
| `Ctrl+H` / `Ctrl+J` / `Ctrl+K` / `Ctrl+L` | Go to the window left / below / above / right |
| `Ctrl+←` / `Ctrl+→` / `Ctrl+↑` / `Ctrl+↓` | Resize the window |
| `Space w d` | Close the window |
| `Space w m` or `Space u Z` | Zoom the window |
| `Space u z` | Zen mode |

Real tabs (sets of windows): `Space Tab Tab` new, `Space Tab ]` / `Space Tab [` next / previous, `Space Tab d` close.

## Editing

| Keys | Action |
|---|---|
| `gcc` / `gc` (visual) | Comment the line / the selection (`Ctrl+/` too) |
| `gco` / `gcO` | Add a comment below / above |
| `Alt+J` / `Alt+K` | Move the line or selection down / up |
| `s` | Flash: jump anywhere on screen by typing a couple of letters |
| `S` | Flash Treesitter: select a whole code block |
| `Ctrl+Space` | Grow the selection by syntax (repeat to grow, `Backspace` to shrink) |
| `]f` / `[f`, `]c` / `[c` | Next / previous function, class |
| `]t` / `[t` | Next / previous TODO comment |
| `Space s u` | Undo tree |
| `Space s "` | Registers (clipboard history inside Neovim) |

Brackets and quotes close themselves. Text objects work with code: `vaf` selects a function, `vif` its body, `vac` a class, `ci"` changes inside quotes, `da(` deletes a bracketed group with the brackets.

## Code (LSP)

| Keys | Action |
|---|---|
| `gd` (or `F12`) | Go to definition |
| `gr` (or `Shift+F12`) | References |
| `gI` | Implementation |
| `gy` | Type definition |
| `gD` | Declaration |
| `K` | Documentation of the symbol |
| `gK` or `Ctrl+K` (insert) | Signature help |
| `Space c a` (or `Ctrl+.`) | Code actions |
| `Space c A` | Source actions |
| `Space c r` (or `F2`) | Rename |
| `Space c f` | Format (files are also formatted on save) |
| `Space c d` | Diagnostics of the line |
| `]d` / `[d`, `]e` / `[e`, `]w` / `[w` | Next / previous diagnostic, error, warning |
| `Space x x` / `Space x X` | Diagnostics panel (project / buffer) |
| `Space c s` | Symbols outline |
| `gai` / `gao` | Incoming / outgoing calls |
| `Space c l` | LSP info |

## Completion

Suggestions appear while typing. `Enter` accepts, `↑`/`↓` or `Ctrl+N`/`Ctrl+P` move, `Ctrl+Space` opens the menu, `Ctrl+E` closes it, and `Tab` / `Shift+Tab` jump between the fields of a snippet.

## C and C++

clangd provides completion, errors, go-to-definition, formatting (clang-format) and `Space c h` to switch between a source file and its header.

- clangd needs a `compile_commands.json`. CMake projects get one with `set(CMAKE_EXPORT_COMPILE_COMMANDS ON)` (or `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`); for Make, run `bear -- make`.
- CMake, through cmake-tools: `:CMakeGenerate`, `:CMakeBuild`, `:CMakeRun`, `:CMakeDebug`, `:CMakeSelectBuildType`, `:CMakeSelectLaunchTarget`, `:CMakeClean`.
- To debug, build with debug info (`-g`, or the Debug build type) and press `F5`.

### C style on save

Saving a `.c` or `.h` file runs `c-style` (`assets/nvim/c-style.py`), which runs clang-format (`assets/nvim/clang-format.yaml`, also linked as `~/.clang-format`) and adds what clang-format can't do:

- A space between a function's name and its parameters where it's defined or declared (`int foo (int a)`), not in calls (`foo(1)`).
- 2-space indents, spaces only, nothing past column 80 (long lines and strings are split; the guide line marks the limit).
- When a call, prototype or function header doesn't fit, the first argument stays on the first line and all the others go together below it, two spaces further in, as many per line as fit, and it closes like a block: `);` (or `) {` for a function header) on its own line, at the indentation where it started (`printf("...",` / `  n, t, mark, ...` / `);`). Other wrapped lines also continue two spaces in. Inlay hints (the grey parameter names) are off in C because they push the code past the guide; `Space u h` shows them.
- If that first argument is a string too long for the first line, it still starts there: it's cut after a space into `"..."` pieces (C joins them back), the next pieces go two spaces in, and the other arguments follow the last piece.
- An initializer (`AlgInfo x = { ... };`) that doesn't fit on one line gets `{` at the end of the first line, the elements below two spaces in and `};` on its own line. Elements followed by a comment keep their line and the comments are aligned; the rest are packed as many per line as fit.
- A trailing comment that would go past column 80 is split onto aligned `//` lines below it; the code stays whole.
- Short functions, ifs and loops go on one line when they fit: `if (x) return 1;`, `int f(int n) { return n; }`. Blocks with several statements written on one line, like `if (x) { printf("..."); return 1; }`, stay that way while they fit in 80 columns; past that they're split. That includes an `else if` after a braced branch, which clang-format alone splits.
- Casts have a space: `(int) v`.
- Includes, `#define`s and typedefs are moved to the top, each group a blank line apart (nothing is pulled out of an `#if` block).
- System includes (`<...>`) first, then a blank line and the project's (`"..."`), each from the shortest line to the longest, not alphabetically.
- `#define`s stay in their order.
- One-line typedefs come first, then the multi-line ones (structs) and struct/union/enum definitions, from the longest to the shortest with a blank line between each. A struct always stays below the types it uses, even if it's longer.
- One blank line between functions, three before and after `main`. One-line functions written together stay together.
- `.h` files open as C, not C++.

`Space u f` turns format on save off if a file must stay as it is.

## Java

jdtls takes a few seconds to index a project the first time; Maven and Gradle projects are picked up from `pom.xml` / `build.gradle`.

| Keys | Action |
|---|---|
| `Space c o` | Organize imports |
| `Space c x v` / `Space c x c` | Extract variable / constant |
| `Space c x m` (visual) | Extract method |
| `Space c g s` | Go to the super implementation |
| `Space c g S` | Go to the class under test |
| `Space c c` | Run the code lens (e.g. *Run* / *Debug* above `main`) |
| `Space t t` | Run all the tests of the class |
| `Space t r` | Run the nearest test |
| `Space t T` | Pick a test to run |
| `F5` | Debug (it finds the `main` classes) |

## Debugging

| Keys | Action |
|---|---|
| `F5` or `Space d c` | Start / continue |
| `Shift+F5` or `Space d t` | Stop |
| `F9` or `Space d b` | Toggle breakpoint |
| `Space d B` | Conditional breakpoint |
| `F10` or `Space d O` | Step over |
| `F11` or `Space d i` | Step into |
| `Shift+F11` or `Space d o` | Step out |
| `Space d C` | Run to the cursor |
| `Space d a` | Run with arguments |
| `Space d l` | Run the last configuration again |
| `Space d u` | Show / hide the debugger UI (variables, stack, breakpoints, console) |
| `Space d e` | Evaluate the expression under the cursor |
| `Space d r` | REPL |
| `Space d j` / `Space d k` | Down / up the stack |
| `Space d P` | Pause |

C/C++ use codelldb; Java uses the Java debug adapter.

## Tests

| Keys | Action |
|---|---|
| `Space t t` | Run the file |
| `Space t r` | Run the nearest test |
| `Space t T` | Run every test file |
| `Space t l` | Run the last test again |
| `Space t d` | Debug the nearest test |
| `Space t s` | Summary panel |
| `Space t o` / `Space t O` | Output / output panel |
| `Space t w` | Watch the file |
| `Space t S` | Stop |

In Java files `Space t t`, `t r` and `t T` run through jdtls instead (see [Java](#java)).

## Git

| Keys | Action |
|---|---|
| `Space g g` | Lazygit (full Git UI in a floating window) |
| `Space g s` | Status |
| `Space g l` | Log |
| `Space g f` | History of the current file |
| `Space g d` | Changed hunks |
| `Space g b` | Blame the line |
| `Space g B` | Open the file on GitHub |
| `]h` / `[h` | Next / previous change |
| `Space g h s` / `Space g h r` | Stage / reset the change |
| `Space g h S` / `Space g h R` | Stage / reset the whole file |
| `Space g h u` | Undo the stage |
| `Space g h p` | Preview the change inline |
| `Space g h d` | Diff the file |

Changes show in the margin, and the author of the current line appears at its end.

## Terminal

``Ctrl+` `` opens or closes a terminal at the bottom (from inside it too). `Space f t` / `Space f T` open one at the project root / current directory.

## Markdown

| Keys | Action |
|---|---|
| `Space c v` | VS Code-style preview: an HTML page in its own window (a toolbar-less Firefox profile) that Hyprland tiles to the right; live and scroll-synced. Again to stop it |
| `Space c V` | Styled preview inside the terminal, to the right |
| `Space u m` | Render the Markdown in place instead |

The file itself stays plain, like in VS Code. There is no markdownlint (VS Code doesn't lint Markdown by default); marksman handles links and headings.

## Toggles

All under `Space u`:

| Keys | Toggle |
|---|---|
| `Space u w` | Line wrap |
| `Space u l` / `Space u L` | Line numbers / relative numbers |
| `Space u d` | Diagnostics |
| `Space u h` | Inlay hints (parameter names and types in the code) |
| `Space u f` / `Space u F` | Format on save (everywhere / this buffer) |
| `Space u s` | Spell checking |
| `Space u g` | Indent guides |
| `Space u G` | Git signs |
| `Space u C` | Colourscheme picker |
| `Space u n` | Dismiss notifications |

## Sessions, plugins and tools

| Keys | Action |
|---|---|
| `Space q s` | Restore the session of this folder |
| `Space q l` | Restore the last session |
| `Space q q` | Quit everything |
| `Space l` | Lazy (plugins) |
| `Space c m` | Mason (language tools) |
| `Space n` | Notification history |
| `Space .` | Scratch buffer |

- `:LazyExtras` browses and enables more of LazyVim's extras (Python, TypeScript, Rust…). Add the ones to keep to `extras` in `nvim.nix` so they're declared.
- `:checkhealth` checks that everything is installed correctly.

## How it's set up

- **LazyVim + extras**: `editor.neo-tree` and `lang.markdown` everywhere; `lang.clangd`, `lang.cmake`, `lang.java`, `dap.core` and `test.core` on the desktop and the Mac. The Pi keeps just the editor (`dotfiles.nvim.ide = false` in `hosts/tphome/home.nix`).
- **Tools from Nix**: ripgrep, fd, lazygit, git, gcc, make, tree-sitter, Node and Python for LazyVim and Mason; clangd (clang-tools), jdtls (`jdt-language-server`, which runs on Java 21) with Lombok, CMake, JDK 21, Maven and Gradle for the IDE. They're only on Neovim's PATH.
- **Tools from Mason**: the Java debug adapter and test runner (plain jars), codelldb (NixOS runs it through nix-ld), neocmakelsp, marksman and the formatters (clang-format comes from Nix). clangd and jdtls are kept away from Mason: its clangd can't find the system headers on NixOS, and its jdtls is a snapshot that already needs Java 25.
- **Look**: carbonfox, monochrome, with a transparent background so kitty's glass shows through. English spell checking is off by default (it underlined everything written in Spanish).
- **Files**: `lua/config/{lazy,options,keymaps,autocmds}.lua` and `lua/plugins/*.lua` under `~/.config/nvim`, all generated from `nvim.nix`. Lazy writes `lazy-lock.json` next to them.
