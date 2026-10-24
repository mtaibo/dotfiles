# Vim help

Everything Vim can do that's worth knowing, from the basics to the tricks. Keys are written as you type them: `Ctrl+w` is Control and w together, `<leader>` is Space. Counts go before a command (`3w`, `5dd`). Things marked **changed here** behave differently in this setup than in plain Vim.

## The idea

Vim is a language: an **operator** (what to do) followed by a **motion** or **text object** (where). `d` deletes, `w` is "to the next word", so `dw` deletes a word; `c` changes, `i(` is "inside the brackets", so `ci(` replaces what's between `(` and `)`. Learn a few of each and they combine.

- `.` repeats the last change. Make a change once, then `n.` / `j.` to repeat it elsewhere.
- A count multiplies: `3dw`, `d3w` and `2d3w` all delete words.
- Doubling an operator acts on the whole line: `dd`, `cc`, `yy`, `>>`, `gUU`.
- An uppercase operator acts to the end of the line: `D` = `d$`, `C` = `c$`, `Y` = `y$`.

## Modes

| Keys | Mode |
|---|---|
| `Esc` or `Ctrl+[` | Back to normal mode (also clears the search highlight here) |
| `i` / `a` | Insert before / after the cursor |
| `I` / `A` | Insert at the start (first non-blank) / end of the line |
| `gI` | Insert at column 1 |
| `o` / `O` | New line below / above and insert |
| `v` / `V` / `Ctrl+v` | Visual: characters / lines / block |
| `R` | Replace mode: typing overwrites |
| `:` | Command line |
| `gi` | Insert where you last left insert mode |
| `Ctrl+o` (in insert) | Run one normal-mode command, then back to insert |

## Moving around

### Characters, words and lines

| Keys | Moves |
|---|---|
| `h` `j` `k` `l` | Left, down, up, right (arrows work too) |
| `w` / `b` / `e` | Next word start / previous word start / word end |
| `W` / `B` / `E` | Same, but WORDs (anything between spaces: `foo.bar(x)` is one) |
| `ge` / `gE` | Previous word / WORD end |
| `0` | Column 1 |
| `^` or `_` | First non-blank character |
| `$` | End of the line |
| `g_` | Last non-blank character |
| `gj` / `gk` | Down / up by screen line in wrapped text (**changed here**: `j`/`k` already do this without a count) |
| `g0` / `g$` / `gm` | Start / end / middle of the screen line |
| `\|` | Column N (`20\|`) |

### Inside a line: find a character

| Keys | Moves |
|---|---|
| `f{c}` / `F{c}` | To the next / previous `{c}` on the line |
| `t{c}` / `T{c}` | To just before / after the next / previous `{c}` |
| `;` / `,` | Repeat the last f/t/F/T forward / backward |

`dt)` deletes up to the bracket, `cf,` changes up to and including the comma, `vf.` selects to the dot.

### Bigger jumps

| Keys | Moves |
|---|---|
| `gg` / `G` | First / last line; `42G` or `42gg` or `:42` to line 42 |
| `{` / `}` | Previous / next blank line (paragraph) |
| `(` / `)` | Previous / next sentence |
| `%` | To the matching bracket, or `50%` to the middle of the file |
| `[(` / `])` | To the enclosing unmatched `(` / `)` (also `[{` / `]}`) |
| `[[` / `]]` | Previous / next section (here: previous / next use of the word under the cursor, via the LSP) |
| `H` / `M` / `L` | Top / middle / bottom of the screen (**changed here**: `H`/`L` switch tabs; `M` still works) |
| `s{chars}` | **Here:** flash jump. Type a couple of letters of where you want to go, then the label that appears there |
| `S` | **Here:** flash treesitter: pick a whole syntax node (function, block, argument...) with a label |

### Scrolling

| Keys | Does |
|---|---|
| `Ctrl+d` / `Ctrl+u` | Half a page down / up |
| `Ctrl+f` / `Ctrl+b` | A page down / up (**changed here**: `Ctrl+b` toggles the explorer) |
| `Ctrl+e` / `Ctrl+y` | The view one line down / up, cursor stays |
| `zz` / `zt` / `zb` | Put the current line in the middle / top / bottom of the screen |
| `zh` / `zl` / `zs` / `ze` | Scroll sideways when lines don't wrap |

### Jumps and the jump list

| Keys | Does |
|---|---|
| `Ctrl+o` / `Ctrl+i` | Back / forward through places you jumped from (searches, `G`, `%`, go to definition...) |
| `''` or ` `` ` | Back to where you were before the last jump |
| `g;` / `g,` | Back / forward through the places you changed text |
| `` `. `` \| The last change \|
| `` `^ `` \| Where you last left insert mode \|
| `` `[ `` / `` `] `` | Start / end of the last change or yank |
| `:jumps` / `:changes` | List them |

### Marks

| Keys | Does |
|---|---|
| `m{a-z}` | Set a mark in this file |
| `m{A-Z}` | Set a global mark (jumps across files) |
| `` `{mark} `` \| Jump to the mark's exact position \|
| `'{mark}` | Jump to the mark's line |
| `:marks` / `:delmarks a` / `:delm!` | List / delete one / delete all lowercase |

Marks work as motions: `d'a` deletes from here to mark `a`'s line, `` y`a `` yanks to its exact spot.

## Editing

### Operators

| Operator | Does |
|---|---|
| `d` | Delete (cut: it goes to a register) |
| `c` | Change: delete and enter insert mode |
| `y` | Yank (copy) |
| `>` / `<` | Indent / unindent |
| `=` | Reindent |
| `gu` / `gU` / `g~` | Lowercase / uppercase / toggle case |
| `gq` | Reflow text to the line width (`gw` keeps the cursor) |
| `g?` | ROT13 |
| `!` | Filter through a shell command (`!ip sort`) |
| `gc` | Comment / uncomment (`gcc` the line, `gcip` the paragraph) |
| `zf` | Create a fold |

### Single keys

| Keys | Does |
|---|---|
| `x` / `X` | Delete the character under / before the cursor |
| `r{c}` | Replace the character with `{c}` (`5rx` five of them) |
| `~` | Toggle the case of the character and move on |
| `s` / `S` | Substitute character / line (**changed here**: flash jumps; use `cl` / `cc`) |
| `J` / `gJ` | Join the next line onto this one, with / without a space |
| `p` / `P` | Paste after / before the cursor (a yanked line goes below / above) |
| `gp` / `gP` | Paste and leave the cursor after the pasted text |
| `]p` / `[p` | Paste with the indentation adjusted to the current line |
| `u` / `Ctrl+r` | Undo / redo |
| `U` | Undo all the changes on the last edited line |
| `Ctrl+a` / `Ctrl+x` | Add / subtract 1 to the number under or after the cursor (`5Ctrl+a`) |
| `.` | Repeat the last change |
| `xp` | Swap two characters; `ddp` swaps two lines |
| `Alt+j` / `Alt+k` | **Here:** move the line (or selection) down / up |

### Text objects

Used after an operator or in visual mode. `i` = inside, `a` = around (with the delimiters or the surrounding space).

| Object | Selects |
|---|---|
| `iw` / `aw` | A word / with the space after it |
| `iW` / `aW` | A WORD |
| `is` / `as` | A sentence |
| `ip` / `ap` | A paragraph / with the blank line after it |
| `i"` `i'` `` i` `` \| Inside quotes (`a"` with them). Works from anywhere on the line \|
| `i(` or `ib` / `a(` | Inside brackets; also `i[`, `i{` (`iB`), `i<` |
| `it` / `at` | Inside an HTML/XML tag / the whole tag |

Added here (mini.ai, they also work on the next one if the cursor isn't inside):

| Object | Selects |
|---|---|
| `if` / `af` | Function body / whole function |
| `ic` / `ac` | Class body / whole class |
| `io` / `ao` | Block, conditional or loop |
| `ia` / `aa` | An argument / with its comma |
| `iq` / `aq` | Any quotes |
| `ib` / `ab` | Any brackets |
| `iu` / `au` | A function call ("usage") |
| `id` | Digits |
| `ie` | A word inside camelCase or snake_case |
| `ig` / `ag` | The whole buffer |
| `in(` / `il(` | The next / last `( )` (works with any object: `cin"`, `dal]`) |

Examples: `ci"` rewrite a string, `da(` delete a call's arguments with the brackets, `yif` copy a function body, `vac` select a class, `=ap` reindent a paragraph, `gUiw` uppercase a word, `daa` delete an argument and its comma.

### Insert mode

| Keys | Does |
|---|---|
| `Ctrl+w` | Delete the word before the cursor |
| `Ctrl+u` | Delete back to the start of the line |
| `Ctrl+h` | Backspace |
| `Ctrl+t` / `Ctrl+d` | Indent / unindent the line |
| `Ctrl+r {reg}` | Paste a register (`Ctrl+r "` the last yank, `Ctrl+r +` the clipboard, `Ctrl+r =` the result of an expression: `Ctrl+r =` `6*7` `Enter`) |
| `Ctrl+a` | Insert the text you typed last time |
| `Ctrl+o {cmd}` | One normal-mode command (`Ctrl+o zz`, `Ctrl+o dd`) |
| `Ctrl+v {key}` | Insert a key literally (`Ctrl+v Tab` a real tab, `Ctrl+v u00e9` é) |
| `Ctrl+k {a}{b}` | Digraph: `Ctrl+k e'` é, `Ctrl+k n?` ñ, `Ctrl+k Eu` € (`:digraphs` lists them) |
| `Ctrl+n` / `Ctrl+p` | Next / previous completion |
| `Ctrl+x Ctrl+f` | Complete a file path; `Ctrl+x Ctrl+l` a whole line |
| `Ctrl+k` | **Here:** signature help (parameters of the call) |
| `Ctrl+s` | **Here:** save (any mode) |

### Visual mode

| Keys | Does |
|---|---|
| `v` / `V` / `Ctrl+v` | Start a character / line / block selection (or switch between them) |
| `o` | Go to the other end of the selection |
| `O` | In a block, the other corner on the same line |
| `gv` | Select the last selection again |
| `aw`, `ip`, `i(`... | Grow the selection by a text object (repeat to grow more) |
| `d` `c` `y` `>` `<` `=` `~` `u` `U` `J` `gq` `gc` | Apply an operator to the selection (`>`/`<` keep it selected here) |
| `r{c}` | Replace every selected character with `{c}` |
| `:` | Command on the selected lines (`:'<,'>` is filled in) |
| `p` | Replace the selection with the register (`P` keeps the register as it was) |
| `g Ctrl+a` | In a column of numbers, make them a sequence (1, 2, 3...) |
| `Ctrl+v` `I` / `A` | Block: insert / append on every line, then `Esc` |
| `Ctrl+v` `$A` | Append at the end of every line, even ragged ones |
| `Ctrl+v` `c` | Change the block on every line |

### Registers (clipboards)

Every delete and yank goes into a register. Prefix a command with `"{reg}` to choose one: `"ayy` yanks into `a`, `"ap` pastes it.

| Register | Holds |
|---|---|
| `""` | The default: the last delete or yank |
| `"0` | The last yank (a delete doesn't overwrite it: yank, delete something, `"0p` still pastes the yank) |
| `"1`–`"9` | The last nine line deletes, newest first |
| `"-` | The last small delete (less than a line) |
| `"a`–`"z` | Your own; `"A`–`"Z` append to them |
| `"+` / `"*` | The system clipboard (`"+y`, `"+p`) |
| `"_` | The black hole: `"_d` deletes without touching any register |
| `".` / `":` / `"/` | Last inserted text / last command / last search |
| `"%` / `"#` | Current / alternate file name |
| `"=` | An expression: `"=` `2+2` `Enter` `p` |

`:reg` (or `:registers`) shows them. `:let @a = 'text'` sets one. In the command line, `Ctrl+r a` inserts register `a`, `Ctrl+r Ctrl+w` the word under the cursor.

### Undo history

| Keys | Does |
|---|---|
| `u` / `Ctrl+r` | Undo / redo |
| `g-` / `g+` | Go back / forward in time through every state, including undone branches |
| `:earlier 10m` / `:later 1h` | Back / forward in time (`s`, `m`, `h`, `d`, or `f` for file writes: `:earlier 1f`) |
| `:undolist` | The undo branches |

Undo history is kept after closing the file (persistent undo is on in LazyVim).

## Macros

Record a sequence of keys and play it back.

| Keys | Does |
|---|---|
| `q{a-z}` | Start recording into register `{a-z}`; `q` again stops |
| `@{a-z}` | Play it; `5@a` five times |
| `@@` | Play the last played macro again |
| `qA` | Append to macro `a` |
| `:'<,'>normal @a` | Play it on every selected line (`:%norm @a` on every line) |
| `@:` | Repeat the last command-line command |

Tips: start the macro with `0` or `^` so it works from any column, and end it with `j` so `100@a` walks down the file. A macro stops at the first error, so a big count runs until it can't. It's just a register: `"ap` pastes it to edit, `"ayy` (on the edited line, without the newline: `0"ay$`) stores it back.

## Search and replace

### Searching

| Keys | Does |
|---|---|
| `/text` / `?text` | Search forward / backward, `Enter` to go |
| `n` / `N` | Next / previous match (here a folded match is opened) |
| `*` / `#` | Search the word under the cursor forward / backward (`g*` / `g#` also inside other words) |
| `/` `Up` | Previous searches |
| `/text/e` | Land on the end of the match (`/text/+1` a line below) |
| `//` | Search the last pattern again |
| `cgn` | Change the next match, then `.` changes the next one (`dgn` deletes it). **Changed here:** a plain `gn` / `gN` goes to the next use of a function |
| `:noh` | Hide the highlights (or `Esc` here) |

Patterns: `\c` anywhere makes it ignore case (`/\cfoo`); here searches already ignore case unless you type a capital. `\<word\>` matches the whole word. `\v` at the start makes it "very magic" (regex like elsewhere: `/\v(foo|bar)\d+`). `.` any character, `*` repeat, `^` `$` line start / end, `\s` space, `\d` digit, `\w` word character, `\n` newline, `[abc]` a set, `\{2,4}` 2 to 4 times, `\zs` / `\ze` start / end of what counts as the match.

### Replacing

| Command | Does |
|---|---|
| `:s/old/new/` | First match on the line |
| `:s/old/new/g` | Every match on the line |
| `:%s/old/new/g` | Every match in the file |
| `:%s/old/new/gc` | Asking each time (`y` yes, `n` no, `a` all, `q` quit, `l` this one and stop) |
| `:'<,'>s/old/new/g` | In the selected lines |
| `:5,20s/old/new/g` | In lines 5 to 20 |
| `:%s//new/g` | Replace the last search (search first with `*` or `/`, then leave the pattern empty) |
| `:%s/\(\w\+\) \(\w\+\)/\2 \1/` | Groups: swap two words (`\v(\w+) (\w+)` with very magic) |
| `:%s/x/\r/g` | Replace with a newline (`\r` in the replacement, `\n` in the pattern) |
| `:%s/old/\=line('.')/` | Replace with an expression (here, the line number) |
| `:%s/word/\U&/g` | `&` is the whole match; `\U` `\L` uppercase / lowercase what follows, `\u` `\l` one letter |
| `&` / `g&` | Repeat the last `:s` on this line / on every line |
| `:%s/old/new/gn` | Only count the matches |

### Commands on many lines

| Command | Does |
|---|---|
| `:g/pattern/d` | Delete every line that matches |
| `:v/pattern/d` or `:g!/pattern/d` | Delete every line that doesn't |
| `:g/pattern/normal A;` | Run normal-mode keys on every matching line |
| `:g/pattern/m0` | Move matching lines to the top (`:g/^/m0` reverses the file) |
| `:g/pattern/t$` | Copy matching lines to the end |
| `:g/^$/d` | Delete blank lines |
| `:%norm A;` | Append `;` to every line |
| `:sort` / `:sort u` / `:sort n` / `:sort!` | Sort lines / dropping duplicates / by number / reversed (works on a range) |
| `:%!jq .` | Filter the whole file through a command |

### In many files

| Command | Does |
|---|---|
| `:vimgrep /pattern/ **/*.c` | Search files into the quickfix list (`:grep` uses ripgrep here) |
| `:copen` / `:cclose` | Open / close the quickfix list |
| `:cnext` / `:cprev` or `]q` / `[q` | Next / previous entry |
| `:cdo s/old/new/ \| update` | Run a command on every entry and save |
| `:cfdo %s/old/new/g \| update` | Once per file in the list |
| `:bufdo` / `:windo` / `:argdo` | On every buffer / window / file in the argument list |

## Files, buffers, windows and tabs

### Files

| Command | Does |
|---|---|
| `:e file` | Open a file (`Tab` completes; `:e .` the directory) |
| `:e!` | Reload the file, throwing away changes |
| `:w` / `:w file` / `:sav file` | Save / save a copy / save as (and switch to it) |
| `:wa` | Save everything |
| `:q` / `:q!` / `:qa` / `:qa!` | Quit / without saving / everything / everything without saving |
| `:x` or `ZZ` | Save if changed and quit; `ZQ` quit without saving |
| `:r file` / `:r !cmd` | Insert a file / a command's output below the cursor |
| `:w !sudo tee %` | Save a file you opened without permission |
| `gf` | Open the file whose name is under the cursor (`Ctrl+w f` in a split) |
| `gx` | Open the link under the cursor in the browser |
| `Ctrl+g` | File name, position and size; `g Ctrl+g` counts words and characters |
| `:pwd` / `:cd dir` / `:lcd dir` | Working directory / change it / for this window only |

### Buffers (open files)

| Keys | Does |
|---|---|
| `:ls` | List the open buffers |
| `:b name` / `:b 3` | Switch to a buffer by part of its name or number |
| `:bn` / `:bp` | Next / previous buffer (here also `]b` / `[b`, `Shift+l` / `Shift+h`, `Ctrl+Tab`) |
| `Ctrl+^` | The alternate (previous) file |
| `:bd` | Close the buffer (here `Space b d` keeps the window) |

### Windows (splits)

| Keys | Does |
|---|---|
| `:sp file` / `:vs file` | Split horizontally / vertically (`Ctrl+w s` / `Ctrl+w v`) |
| `Ctrl+w h/j/k/l` | Go to the window left / down / up / right (here just `Ctrl+h/j/k/l`) |
| `Ctrl+w w` / `Ctrl+w p` | Next / previous window |
| `Ctrl+w c` / `Ctrl+w o` | Close this window / close all the others |
| `Ctrl+w =` | Make them all the same size |
| `Ctrl+w _` / `Ctrl+w \|` | Maximise height / width |
| `Ctrl+w +` / `-` / `>` / `<` | Taller / shorter / wider / narrower (`10 Ctrl+w +`; here `Ctrl+arrows`) |
| `Ctrl+w x` / `Ctrl+w r` | Swap with the next / rotate |
| `Ctrl+w H/J/K/L` | Move the window to the far left / bottom / top / right |
| `Ctrl+w T` | Move the window to a new tab |
| `:only` | Keep only this window |

### Tabs (layouts of windows)

| Keys | Does |
|---|---|
| `:tabnew` / `:tabe file` | New tab / open a file in one |
| `gt` / `gT` / `3gt` | Next / previous / third tab |
| `:tabclose` / `:tabonly` | Close it / close the others |
| `:tabm 0` | Move the tab first |

Here, the "tabs" at the top are buffers; real Vim tabs are under `Space Tab`.

## The command line

### Ranges

Most `:` commands take a range before them.

| Range | Means |
|---|---|
| `:5` / `:5,10` | Line 5 / lines 5 to 10 |
| `.` / `$` / `%` | This line / the last line / the whole file |
| `.,+3` / `.,$` | This line and the next 3 / to the end |
| `'<,'>` | The visual selection |
| `'a,'b` | From mark `a` to mark `b` |
| `/start/,/end/` | From the next line matching `start` to the next matching `end` |

### Line commands

| Command | Does |
|---|---|
| `:d` / `:y` | Delete / yank the lines (`:5,10d`, `:%y +` copy the file to the clipboard) |
| `:m 0` / `:m $` / `:m 12` | Move the lines to the top / bottom / after line 12 |
| `:t .` / `:t 0` / `:co $` | Copy the lines below / to the top / to the end |
| `:>` / `:<` | Indent / unindent |
| `:j` | Join |
| `:norm keys` | Run normal-mode keys on each line in the range |
| `:center` / `:right` / `:left` | Align text |
| `:retab` | Turn tabs into spaces with the current settings |

### Working in the command line

| Keys | Does |
|---|---|
| `Up` / `Down` | History, filtered by what you've typed |
| `Tab` / `Ctrl+d` | Complete / list the completions |
| `Ctrl+r Ctrl+w` | Insert the word under the cursor (`Ctrl+r Ctrl+a` the WORD, `Ctrl+r Ctrl+l` the line) |
| `Ctrl+r {reg}` | Insert a register |
| `Ctrl+f` or `q:` | Edit the command history in a window, `Enter` runs a line (`q/` for searches) |
| `Ctrl+b` / `Ctrl+e` | Start / end of the command line |
| `Ctrl+w` / `Ctrl+u` | Delete a word / everything |
| `@:` | Repeat the last command (`@@` after that) |
| `:!cmd` | Run a shell command (`:!%` would run the file; `%` is the file name) |
| `:= 2**10` | Evaluate Lua (`:lua print(...)`) |

## Formatting and indentation

| Keys | Does |
|---|---|
| `>>` / `<<` | Indent / unindent the line (`5>>` five lines) |
| `==` / `=ip` / `gg=G` | Reindent the line / paragraph / file |
| `gqip` / `gqq` | Reflow the paragraph / line to the text width |
| `:set tw=72` | Text width for `gq` |
| `Space c f` | **Here:** format with the language's formatter (C and Java also on save) |

## Folding

| Keys | Does |
|---|---|
| `za` | Open / close the fold under the cursor |
| `zo` / `zc` | Open / close (`zO` / `zC` recursively) |
| `zR` / `zM` | Open / close every fold |
| `zr` / `zm` | Open / close one more level |
| `zj` / `zk` | Next / previous fold |
| `zv` | Open enough to show the cursor line |
| `zf{motion}` / `zd` / `zE` | Create a manual fold / delete one / delete all |

Here folds follow the syntax tree (functions, blocks) and everything starts open.

## Spelling

| Keys | Does |
|---|---|
| `:set spell` / `:set spelllang=es,en` | Turn it on / choose languages (`Space u s` toggles it here) |
| `]s` / `[s` | Next / previous misspelling |
| `z=` | Suggestions for the word (`1z=` take the first) |
| `zg` / `zw` | Add the word as good / mark it wrong |
| `zug` | Undo `zg` |

## Code (LSP) here

| Keys | Does |
|---|---|
| `gd` | **Here:** go to definition; inside a function's body, to its prototype (the `.h`); on a prototype, to the code |
| `gn` / `gN` | **Here:** next / previous use of the function under the cursor or the one you're inside, across files |
| `F12` | Plain definition of what's under the cursor |
| `gr` / `Shift+F12` | References |
| `gI` / `gy` / `gD` | Implementation / type definition / declaration |
| `K` | Documentation of what's under the cursor (`K` again to enter the window) |
| `gK` | Signature help |
| `Space c a` / `Ctrl+.` | Code actions (quick fixes) |
| `Space c r` / `F2` | Rename everywhere |
| `]d` / `[d` | Next / previous diagnostic (`]e` errors, `]w` warnings) |
| `Space c d` | Show the diagnostic of the line |
| `Space x x` | All the diagnostics in a list |
| `Space s s` | Symbols in the file |

## Options worth knowing

`:set option` turns it on, `:set nooption` off, `:set option!` toggles, `:set option?` shows it. LazyVim's `Space u` menu toggles the common ones.

| Option | Does |
|---|---|
| `number` / `relativenumber` | Line numbers / relative to the cursor (`Space u l` / `Space u L`) |
| `wrap` | Wrap long lines (`Space u w`) |
| `list` | Show tabs and trailing spaces |
| `ignorecase` / `smartcase` | Case-insensitive search, unless there's a capital |
| `hlsearch` / `incsearch` | Highlight matches / while typing |
| `expandtab` / `shiftwidth` / `tabstop` | Spaces for tabs / indent size / tab width |
| `colorcolumn=81` | A guide line at a column (on for C and Java here) |
| `scrolloff=8` | Keep lines visible above and below the cursor |
| `spell` / `spelllang` | Spell checking |
| `paste` | Not needed in Neovim: pasting from the terminal keeps the indentation |

## Handy tricks

| Keys | Does |
|---|---|
| `ga` | Code of the character under the cursor |
| `g8` | Its UTF-8 bytes |
| `gv` | The last selection again |
| `gi` | Back to the last insert position, in insert mode |
| `g Ctrl+g` | Word and character count (of the selection in visual mode) |
| `:%s/\s\+$//e` | Delete trailing spaces |
| `:g/^\s*$/d` | Delete empty and blank lines |
| `ddkP` / `ddp` | Move a line up / down (here `Alt+k` / `Alt+j`) |
| `yyp` | Duplicate a line |
| `xp` | Swap two characters |
| `ciw` + `Ctrl+r 0` | Replace a word with the last yank |
| `viwp` | Replace a word with the register (the word goes to the register) |
| `:r !date` | Insert the date |
| `!!sh` | Run the line as a shell command and replace it with the output |
| `Ctrl+v` `jjj` `I// ` `Esc` | Comment out lines by hand (or `gc` here) |
| `:echo expand('%:p')` | The file's full path (`%:h` its directory, `%:t` its name) |
| `q:` | The command history as an editable window |
| `:checkhealth` | Check that Neovim and the plugins are set up right |
| `:Inspect` | Highlight groups under the cursor |
| `:messages` | Messages that went by (`Space s n h` notification history here) |
| `:h topic` | Vim's own manual (`:h motion.txt`, `:h text-objects`, `:h ctrl-r`); `Ctrl+]` follows a link, `Ctrl+o` back |

## Terminal inside Neovim

| Keys | Does |
|---|---|
| `:terminal` | **Here:** a shell in the editor window, like a file (goes back to it if it's open) |
| `Esc Esc` | **Here:** leave terminal mode in it (anywhere: `Ctrl+\` `Ctrl+n`) |
| `i` / `a` | Back into terminal mode |
| `q` | **Here:** close it (in normal mode) |
| ``Ctrl+` `` | **Here:** a terminal at the bottom, toggled |

## Commands of this setup

| Command | Does |
|---|---|
| `:help` | This page (`:h topic` is still Vim's manual) |
| `:make` / `Space m` | Save everything and run make from the nearest Makefile, in a terminal tab (`:make run` with targets) |
| `:test` | Save everything and run the tests: `mvn test`, Gradle's, or `make test` (`:test PersonTest` only that class) |
| `:terminal` | A shell in a terminal tab (`:terminal cmd` runs a command) |
| `:md` / `Space c v` | Markdown preview in the browser |
| `:getset` / `Space c G` | Java getters and setters for the field under the cursor (or every field) |
| `Space Space` or `Ctrl+p` | Find a file |
| `Space /` or `Ctrl+Shift+f` | Search in every file |
| `Ctrl+Shift+p` | Command palette |
| `Ctrl+b` / `Space e` | Explorer |
| `Ctrl+/` | Comment the line or selection |
| `Space` (and wait) | Shows every Space shortcut, grouped |
| `Space s k` | Search every key mapping |

C and Java are formatted on save in one house style; `Space u f` turns that off for a file. Every shortcut of this setup is in [NVIM.md](https://github.com/mtaibo/dotfiles/blob/main/NVIM.md).
