{ config, lib, pkgs, ... }:
let
  cfg = config.dotfiles.nvim;

  # LazyVim extras that turn it into an IDE (C/C++, CMake, Java, OCaml,
  # debugger, tests). Off on the Pi, where only the editor is wanted.
  ideExtras = lib.optionals cfg.ide [
    "lang.clangd"
    "lang.cmake"
    "lang.java"
    "lang.ocaml"
    "dap.core"
    "test.core"
  ];
  extras = [ "editor.neo-tree" "lang.markdown" ] ++ ideExtras;
  importExtras = lib.concatMapStrings (e: ''
        { import = "lazyvim.plugins.extras.${e}" },
  '') extras;

  # Markdown preview like VS Code's: an HTML page, live, scroll-synced
  # (markdown-preview.nvim), styled with the rice's colours.
  # Stylix only runs on the desktop; elsewhere use the same palette directly.
  c = config.lib.stylix.colors.withHashtag
    or (lib.mapAttrs (_: v: "#${v}") (import ../../palette.nix));
  # The stylesheets live in assets/nvim and read the palette as --baseXX.
  paletteVars = ":root {\n"
    + lib.concatMapStrings (n: "  --${n}: ${c.${n}};\n") (lib.attrNames (import ../../palette.nix))
    + "}\n";
  previewStyle = name: file: pkgs.writeText name (paletteVars + builtins.readFile file);
  previewCss = previewStyle "markdown-preview.css" ../../../assets/nvim/markdown-preview.css;
  previewHighlightCss = previewStyle "markdown-preview-highlight.css" ../../../assets/nvim/markdown-preview-highlight.css;

  # A Firefox profile only for previews: no tabs or toolbars, so it looks
  # like a preview pane; Hyprland tiles it next to kitty.
  previewUserJs = pkgs.writeText "markdown-preview-user.js" ''
    user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
    user_pref("dom.allow_scripts_to_close_windows", true);
    user_pref("browser.shell.checkDefaultBrowser", false);
    user_pref("browser.aboutwelcome.enabled", false);
    user_pref("browser.startup.homepage_override.mstone", "ignore");
    user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);
    user_pref("browser.sessionstore.resume_from_crash", false);
    user_pref("browser.tabs.warnOnClose", false);
    user_pref("layout.css.prefers-color-scheme.content-override", 0);
  '';
  previewUserChrome = pkgs.writeText "markdown-preview-userChrome.css" ''
    #navigator-toolbox { visibility: collapse !important; }
  '';
  previewOpen = pkgs.writeShellApplication {
    name = "markdown-preview-open";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      # A second name gives a second profile, so two pages can be open at once.
      profile=''${XDG_CACHE_HOME:-$HOME/.cache}/''${2:-markdown-preview}-firefox
      mkdir -p "$profile/chrome"
      install -m 644 ${previewUserJs} "$profile/user.js"
      install -m 644 ${previewUserChrome} "$profile/chrome/userChrome.css"
      exec firefox --profile "$profile" --no-remote --new-instance --name markdown-preview "$1"
    '';
  };

  # :help opens this page: my own short guide (assets/nvim/guide.md) and the
  # full Vim guide (assets/nvim/help.md), picked in the sidebar, rendered with
  # the preview's own markdown-it and stylesheet, in the preview's window on
  # Linux and the default browser on the Mac.
  helpPage = pkgs.runCommand "nvim-help" { nativeBuildInputs = [ pkgs.nodejs ]; } ''
    mkdir -p $out
    node ${../../../assets/nvim/help-render.js} \
      ${pkgs.vimPlugins.markdown-preview-nvim}/app $out/index.html \
      ${../../../assets/nvim/guide.md} ${../../../assets/nvim/help.md} \
      ${previewCss} ${previewHighlightCss} ${../../../assets/nvim/help.css}
  '';
  helpOpen = if pkgs.stdenv.hostPlatform.isDarwin
    then "{ 'open', '${helpPage}/index.html' }"
    else "{ '${previewOpen}/bin/markdown-preview-open', 'file://${helpPage}/index.html', 'nvim-help' }";
  # Opening a .pdf shows it in Firefox's viewer, in the preview's window
  # (the default viewer on the Mac); arguments: path, profile name.
  pdfOpen = if pkgs.stdenv.hostPlatform.isDarwin
    then "function(path) return { 'open', path } end"
    else "function(path, name) return { '${previewOpen}/bin/markdown-preview-open', path, name } end";

  # C and Java formatting on save, in one house style: code-style runs
  # clang-format with this style and adds the layout clang-format can't do
  # (one-line blocks kept, includes and imports by length, grouped defines
  # and typedefs, class members in a fixed order, three blank lines around
  # main). `code-style c` or `code-style java`, the file on stdin.
  clangFormat = ../../../assets/nvim/clang-format.yaml;
  # 2-space indents with spaces and a guide at column 80, the limit
  # code-style wraps at.
  cIndent = ''
    vim.opt_local.expandtab = true
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.colorcolumn = "81"
  '';
  codeStyle = pkgs.writeShellScriptBin "code-style" ''
    exec ${pkgs.python3}/bin/python3 ${../../../assets/nvim/code-style.py} \
      "$1" ${pkgs.clang-tools}/bin/clang-format ${clangFormat}
  '';
in {
  options.dotfiles.nvim.ide = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "C/C++, Java and OCaml tooling (LSPs, debugger, tests) in Neovim.";
  };

  config = {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      vimAlias = true;

      # On Neovim's PATH only. LazyVim's tools: pickers (ripgrep, fd), git,
      # lazygit, and what Mason and nvim-treesitter need to build and unpack.
      # clangd and jdtls come from Nix rather than Mason: Mason's clangd doesn't
      # find the system headers on NixOS (the nixpkgs wrapper does), and Mason
      # installs a jdtls snapshot that already needs Java 25. The Java debug
      # adapter and test runner are plain jars, so Mason installs those, and
      # codelldb too (NixOS runs it through nix-ld, see hosts/desktop).
      # ocaml-lsp and ocamlformat from Nix too, built with the same OCaml as
      # the compiler in packages.nix (Mason's need opam).
      extraPackages = with pkgs; [
        ripgrep
        fd
        git
        lazygit
        gcc
        gnumake
        tree-sitter
        unzip
        curl
        wget
        python3
        nodejs_22
      ] ++ lib.optionals cfg.ide [
        clang-tools
        jdt-language-server
        cmake
        jdk21
        maven
        gradle
        codeStyle
        ocamlPackages.ocaml-lsp
        ocamlformat
        dune_3
      ];

      extraLuaConfig = ''
        require("config.lazy")
      '';
    };

    # The same style for clangd and clang-format run by hand anywhere in ~.
    home.file = lib.mkIf cfg.ide { ".clang-format".source = clangFormat; };

    # vim.loader keeps compiled Lua in ~/.cache/nvim/luac and only checks a
    # file's mtime and size. Everything in the Nix store has the same mtime,
    # so a config file that changes only a store path (same length) kept
    # running the old code, e.g. :help opening the previous page. Drop the
    # cache on every switch; nvim rebuilds it on the next start.
    home.activation.nvimLuaCacheReset = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run rm -rf "''${XDG_CACHE_HOME:-$HOME/.cache}/nvim/luac"
    '';

    xdg.configFile = {
      "nvim/lua/config/lazy.lua".text = ''
        -- Bootstrap lazy.nvim, then load LazyVim with its extras and the
        -- overrides in lua/plugins.
        local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
        if not (vim.uv or vim.loop).fs_stat(lazypath) then
          local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable",
            "https://github.com/folke/lazy.nvim.git", lazypath })
          if vim.v.shell_error ~= 0 then
            vim.api.nvim_echo({ { "Failed to clone lazy.nvim:\n", "ErrorMsg" }, { out, "WarningMsg" } }, true, {})
            vim.fn.getchar()
            os.exit(1)
          end
        end
        vim.opt.rtp:prepend(lazypath)

        require("lazy").setup({
          spec = {
            { "LazyVim/LazyVim", import = "lazyvim.plugins", opts = { colorscheme = "carbonfox" } },
        ${importExtras}    { import = "plugins" },
          },
          defaults = { lazy = false, version = false },
          install = { colorscheme = { "carbonfox", "habamax" } },
          checker = { enabled = true, notify = false },
          rocks = { enabled = false },
          performance = {
            rtp = {
              disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" },
            },
          },
        })
      '';

      # LazyVim turns on English spell checking in Markdown and text, which
      # underlines everything written in Spanish; Space u s toggles it.
      "nvim/lua/config/autocmds.lua".text = ''
        pcall(vim.api.nvim_del_augroup_by_name, "lazyvim_wrap_spell")
        vim.api.nvim_create_autocmd("FileType", {
          pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
          callback = function() vim.opt_local.wrap = true end,
        })

        -- `nvim .` leaves an empty [No Name] tab behind when neo-tree takes
        -- over the directory buffer: drop such buffers once a file is open.
        vim.api.nvim_create_autocmd("BufEnter", {
          callback = function(ev)
            if vim.api.nvim_buf_get_name(ev.buf) == "" or vim.bo[ev.buf].buftype ~= "" then return end
            vim.schedule(function()
              for _, b in ipairs(vim.api.nvim_list_bufs()) do
                if b ~= ev.buf and vim.bo[b].buflisted and vim.bo[b].buftype == ""
                  and vim.api.nvim_buf_get_name(b) == "" and not vim.bo[b].modified
                  and vim.api.nvim_buf_line_count(b) == 1
                  and vim.api.nvim_buf_get_lines(b, 0, 1, false)[1] == ""
                  and #vim.fn.win_findbuf(b) == 0 then
                  pcall(vim.api.nvim_buf_delete, b, {})
                end
              end
            end)
          end,
        })

        -- A .pdf opens in the browser, like :md, instead of as bytes: the
        -- buffer only says where it went, and closing it closes the window.
        -- Each open PDF gets its own preview profile (pdf-preview, -2, ...).
        local pdf_open = ${pdfOpen}
        local pdf_jobs = {}
        vim.api.nvim_create_autocmd("BufReadCmd", {
          pattern = "*.pdf",
          callback = function(ev)
            local buf, path = ev.buf, vim.fn.fnamemodify(ev.file, ":p")
            vim.bo[buf].buftype = "nofile"
            vim.bo[buf].swapfile = false
            vim.bo[buf].modifiable = true
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "PDF abierto en el navegador: " .. path })
            vim.bo[buf].modifiable = false
            if pdf_jobs[buf] then return end
            local used = {}
            for _, j in pairs(pdf_jobs) do used[j.name] = true end
            local name, n = "pdf-preview", 1
            while used[name] do n = n + 1; name = "pdf-preview-" .. n end
            local id = vim.fn.jobstart(pdf_open(path, name), {
              detach = true,
              on_exit = function() pdf_jobs[buf] = nil end,
            })
            if id > 0 then pdf_jobs[buf] = { id = id, name = name } end
          end,
        })
        vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
          pattern = "*.pdf",
          callback = function(ev)
            local job = pdf_jobs[ev.buf]
            pdf_jobs[ev.buf] = nil
            if job then pcall(vim.fn.jobstop, job.id) end
          end,
        })
      '';

      "nvim/lua/config/options.lua".text = ''
        vim.opt.tabstop = 2
        vim.opt.shiftwidth = 2
        vim.opt.relativenumber = true
        vim.opt.mouse = "a"
        vim.opt.clipboard = "unnamedplus"
        -- .h files are C headers, not C++.
        vim.g.c_syntax_for_h = true
      '';

      # VS Code's shortcuts on top of LazyVim's (Space is the leader; press it
      # and which-key lists everything).
      "nvim/lua/config/keymaps.lua".text = ''
        local map = vim.keymap.set

        map({ "n", "i", "v" }, "<C-p>", function() Snacks.picker.files() end, { desc = "Go to file" })
        map({ "n", "i", "v" }, "<C-S-p>", function() Snacks.picker.commands() end, { desc = "Command palette" })
        map({ "n", "i", "v" }, "<C-S-f>", function() Snacks.picker.grep() end, { desc = "Search in files" })
        map({ "n", "i", "v" }, "<C-b>", "<cmd>Neotree toggle<cr>", { desc = "Explorer" })
        map({ "n", "i", "t" }, "<C-`>", function() Snacks.terminal() end, { desc = "Terminal" })
        map("n", "<C-Tab>", "<cmd>bnext<cr>", { desc = "Next tab" })
        map("n", "<C-S-Tab>", "<cmd>bprevious<cr>", { desc = "Previous tab" })

        -- Ctrl+/ comments, as in VS Code (LazyVim puts the terminal there;
        -- terminals send it as Ctrl+_).
        for _, key in ipairs({ "<C-/>", "<C-_>" }) do
          pcall(vim.keymap.del, { "n", "t" }, key)
          map("n", key, "gcc", { remap = true, desc = "Toggle comment" })
          map("v", key, "gc", { remap = true, desc = "Toggle comment" })
          map("i", key, "<C-o>gcc", { remap = true, desc = "Toggle comment" })
        end

        -- Move lines with Alt+arrows (LazyVim already has Alt+j/k).
        map({ "n", "i", "v" }, "<A-Up>", "<A-k>", { remap = true, desc = "Move up" })
        map({ "n", "i", "v" }, "<A-Down>", "<A-j>", { remap = true, desc = "Move down" })

        -- Code
        map("n", "<F12>", function() Snacks.picker.lsp_definitions() end, { desc = "Go to definition" })
        map("n", "<S-F12>", function() Snacks.picker.lsp_references() end, { desc = "Go to references" })
        map("n", "<F2>", vim.lsp.buf.rename, { desc = "Rename symbol" })
        map({ "n", "i", "v" }, "<C-.>", vim.lsp.buf.code_action, { desc = "Quick fix" })

        -- Terminals that open in the editor window like a file (a tab; the
        -- explorer stays), focused so they can be typed into. q closes them
        -- once in normal mode.
        local term_bufs = {}
        -- From the explorer or another side panel, move to the editor window.
        local function focus_editor()
          local function editor(win)
            local buf = vim.api.nvim_win_get_buf(win)
            return vim.api.nvim_win_get_config(win).relative == ""
              and (vim.bo[buf].buftype == "" or term_bufs[buf])
          end
          if editor(0) then return end
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if editor(win) then return vim.api.nvim_set_current_win(win) end
          end
        end
        -- Back to normal mode when the command ends, so a key doesn't close it.
        local function stop_on_exit(buf)
          vim.api.nvim_create_autocmd("TermClose", {
            buffer = buf,
            callback = function()
              vim.schedule(function()
                if vim.api.nvim_get_current_buf() == buf then vim.cmd("stopinsert") end
              end)
            end,
          })
        end
        local function open_term(cmd, dir)
          focus_editor()
          vim.cmd("enew")
          local buf = vim.api.nvim_get_current_buf()
          term_bufs[buf] = true
          vim.fn.jobstart(cmd, { cwd = dir, term = true })
          -- A blank margin between the explorer's border and the output
          -- (Neovim clears the side columns when the terminal opens).
          vim.opt_local.statuscolumn = ""
          vim.opt_local.signcolumn = "yes:1"
          vim.api.nvim_create_autocmd("BufWipeout", { buffer = buf, callback = function() term_bufs[buf] = nil end })
          vim.keymap.set("n", "q", function() Snacks.bufdelete({ buf = buf, force = true }) end, { buffer = buf, desc = "Close terminal" })
          vim.cmd("startinsert")
          return buf
        end

        -- :Make (and a typed :make) saves everything and runs make from the
        -- nearest Makefile above the current file. Running it again replaces
        -- the previous one.
        local make_buf
        local function run_make(args)
          vim.cmd("silent! wall")
          local file = vim.api.nvim_buf_get_name(0)
          local start = file ~= "" and vim.fs.dirname(file) or vim.uv.cwd()
          local makefile = vim.fs.find({ "GNUmakefile", "makefile", "Makefile" }, { upward = true, path = start })[1]
          local old = make_buf
          make_buf = open_term(vim.list_extend({ "make" }, args), makefile and vim.fs.dirname(makefile) or vim.uv.cwd())
          if old and vim.api.nvim_buf_is_valid(old) then
            vim.api.nvim_buf_delete(old, { force = true })
          end
          stop_on_exit(make_buf)
        end
        vim.api.nvim_create_user_command("Make", function(o) run_make(o.fargs) end, { nargs = "*", desc = "make in a terminal" })
        vim.cmd([[cnoreabbrev <expr> make getcmdtype() ==# ':' && getcmdline() ==# 'make' ? 'Make' : 'make']])
        map("n", "<leader>m", "<cmd>Make<cr>", { desc = "Make" })

        -- :Terminal (and a typed :terminal or :term) opens a shell the same
        -- way, in Neovim's working directory; if one is already open it goes
        -- back to it. :terminal cmd runs a command instead, like :make.
        -- Esc Esc leaves terminal mode; exiting the shell closes the tab.
        local shell_buf
        local function run_terminal(args)
          if #args == 0 and shell_buf and vim.api.nvim_buf_is_valid(shell_buf) then
            focus_editor()
            vim.api.nvim_win_set_buf(0, shell_buf)
            return vim.cmd("startinsert")
          end
          local buf = open_term(#args > 0 and table.concat(args, " ") or { vim.o.shell }, vim.uv.cwd())
          vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { buffer = buf, desc = "Normal mode" })
          if #args > 0 then return stop_on_exit(buf) end
          shell_buf = buf
          vim.api.nvim_create_autocmd("TermClose", {
            buffer = buf,
            callback = function()
              vim.schedule(function()
                if vim.api.nvim_buf_is_valid(buf) then Snacks.bufdelete({ buf = buf, force = true }) end
              end)
            end,
          })
        end
        vim.api.nvim_create_user_command("Terminal", function(o) run_terminal(o.fargs) end, { nargs = "*", complete = "shellcmd", desc = "Terminal in the editor" })
        for _, abbr in ipairs({ "terminal", "term" }) do
          vim.cmd(("cnoreabbrev <expr> %s getcmdtype() ==# ':' && getcmdline() ==# '%s' ? 'Terminal' : '%s'"):format(abbr, abbr, abbr))
        end

        -- :Test (and a typed :test) saves everything and runs the project's
        -- tests the same way: mvn test next to the nearest pom.xml, Gradle's
        -- test task, or make test. :test Name runs only that test class.
        local test_buf
        local function run_test(args)
          vim.cmd("silent! wall")
          local file = vim.api.nvim_buf_get_name(0)
          local start = file ~= "" and vim.fs.dirname(file) or vim.uv.cwd()
          local root = vim.fs.find({ "pom.xml", "build.gradle", "build.gradle.kts", "GNUmakefile", "makefile", "Makefile" },
            { upward = true, path = start })[1]
          if not root then
            return vim.notify("No pom.xml, Gradle build or Makefile above this file", vim.log.levels.WARN)
          end
          local dir, name = vim.fs.dirname(root), vim.fs.basename(root)
          local cmd
          if name == "pom.xml" then
            cmd = { "mvn", "test" }
            if args[1] then table.insert(cmd, "-Dtest=" .. table.concat(args, ",")) end
          elseif name:match("^build%.gradle") then
            local gradlew = dir .. "/gradlew"
            cmd = { vim.uv.fs_stat(gradlew) and gradlew or "gradle", "test" }
            for _, a in ipairs(args) do vim.list_extend(cmd, { "--tests", a }) end
          else
            cmd = vim.list_extend({ "make", "test" }, args)
          end
          local old = test_buf
          test_buf = open_term(cmd, dir)
          if old and vim.api.nvim_buf_is_valid(old) then
            vim.api.nvim_buf_delete(old, { force = true })
          end
          stop_on_exit(test_buf)
        end
        vim.api.nvim_create_user_command("Test", function(o) run_test(o.fargs) end, { nargs = "*", desc = "Run the tests in a terminal" })
        vim.cmd([[cnoreabbrev <expr> test getcmdtype() ==# ':' && getcmdline() ==# 'test' ? 'Test' : 'test']])
      '' + lib.optionalString cfg.ide ''

        -- :Help (and a typed :help with nothing after it) opens a Vim guide
        -- in the browser, styled like the Markdown preview. :help topic is
        -- still Vim's manual.
        vim.api.nvim_create_user_command("Help", function()
          vim.fn.jobstart(${helpOpen}, { detach = true })
        end, { desc = "Vim guide in the browser" })
        vim.cmd([[cnoreabbrev <expr> help getcmdtype() ==# ':' && getcmdline() ==# 'help' ? 'Help' : 'help']])

        -- :Getset (and a typed :getset), or Space c G: getters and setters
        -- for the Java field under the cursor (for every field when the
        -- cursor isn't on one), skipping those that exist. final fields get
        -- only a getter, booleans isX. The file is then formatted, so they
        -- land with the other accessors.
        local function java_accessors()
          if vim.bo.filetype ~= "java" then
            return vim.notify("Getters and setters are for Java files", vim.log.levels.WARN)
          end
          local ok, node = pcall(vim.treesitter.get_node)
          if not ok or not node then
            return vim.notify("No Java syntax tree here", vim.log.levels.WARN)
          end
          local field, class = nil, nil
          while node do
            local t = node:type()
            if t == "field_declaration" and not field then field = node end
            if t == "class_declaration" or t == "enum_declaration" then
              class = node
              break
            end
            node = node:parent()
          end
          if not class then
            return vim.notify("Not inside a class", vim.log.levels.WARN)
          end
          local text = function(n) return vim.treesitter.get_node_text(n, 0) end
          local body = class:field("body")[1]
          local class_name = text(class:field("name")[1])
          local existing, fields = {}, {}
          for child in body:iter_children() do
            if child:type() == "method_declaration" then
              existing[text(child:field("name")[1])] = true
            elseif child:type() == "field_declaration" then
              table.insert(fields, child)
            end
          end
          local lines = {}
          for _, f in ipairs(field and { field } or fields) do
            local mods = ""
            for child in f:iter_children() do
              if child:type() == "modifiers" then mods = text(child) end
            end
            local static = mods:match("%f[%w]static%f[%W]") ~= nil
            local final = mods:match("%f[%w]final%f[%W]") ~= nil
            -- Constants only when asked for one by name.
            if field or not (static and final) then
              local type = text(f:field("type")[1])
              for _, decl in ipairs(f:field("declarator")) do
                local name = text(decl:field("name")[1])
                local cap = name:sub(1, 1):upper() .. name:sub(2)
                local prefix = static and "public static " or "public "
                local getter = (type == "boolean" and "is" or "get") .. cap
                if not existing[getter] then
                  table.insert(lines, ("%s%s %s () { return %s; }"):format(prefix, type, getter, name))
                end
                if not final and not existing["set" .. cap] then
                  table.insert(lines, ("%svoid set%s (%s %s) { %s.%s = %s; }"):format(
                    prefix, cap, type, name, static and class_name or "this", name, name))
                end
              end
            end
          end
          if #lines == 0 then
            return vim.notify("The getters and setters already exist", vim.log.levels.INFO)
          end
          -- Before the class's closing brace; the formatter puts them in place.
          local last = body:end_()
          local indent = vim.fn.indent(last + 1) + vim.bo.shiftwidth
          for k, l in ipairs(lines) do lines[k] = string.rep(" ", indent) .. l end
          vim.api.nvim_buf_set_lines(0, last, last, false, lines)
          require("conform").format({ async = false })
        end
        vim.api.nvim_create_user_command("Getset", java_accessors, { desc = "Generate getters and setters" })
        vim.cmd([[cnoreabbrev <expr> getset getcmdtype() ==# ':' && getcmdline() ==# 'getset' ? 'Getset' : 'getset']])
        map("n", "<leader>cG", java_accessors, { desc = "Generate getters and setters" })

        -- :Fold (and a typed :fold): folds every C function / Java method
        -- and constructor except main, so only their first line shows;
        -- structs, typedefs, fields and classes stay open. Again opens them.
        -- The window switches to manual folds meanwhile and gets back its
        -- own folding afterwards.
        local fold_nodes = {
          c = { function_definition = true },
          java = { method_declaration = true, constructor_declaration = true },
        }
        local function fold_name(node)
          local name = node:field("name")[1]
          while not name do
            node = node:field("declarator")[1]
            if not node then return nil end
            if node:type() == "identifier" then name = node end
          end
          return vim.treesitter.get_node_text(name, 0)
        end
        local function toggle_folds()
          local saved = vim.w.fold_saved
          if saved then
            vim.w.fold_saved = nil
            vim.cmd("normal! zE")
            vim.wo.foldmethod, vim.wo.foldexpr, vim.wo.foldlevel = saved[1], saved[2], saved[3]
            return
          end
          local types = fold_nodes[vim.bo.filetype]
          if not types then
            return vim.notify("Folding functions is for C and Java files", vim.log.levels.WARN)
          end
          local ok, parser = pcall(vim.treesitter.get_parser, 0)
          if not ok or not parser then
            return vim.notify("No syntax tree here", vim.log.levels.WARN)
          end
          local ranges = {}
          local function walk(node)
            for child in node:iter_children() do
              if types[child:type()] then
                local first, _, last = child:range()
                if last > first and fold_name(child) ~= "main" then
                  table.insert(ranges, { first + 1, last + 1 })
                end
              else
                walk(child)
              end
            end
          end
          walk(parser:parse()[1]:root())
          if #ranges == 0 then
            return vim.notify("No functions to fold", vim.log.levels.INFO)
          end
          vim.w.fold_saved = { vim.wo.foldmethod, vim.wo.foldexpr, vim.wo.foldlevel }
          vim.wo.foldmethod = "manual"
          vim.cmd("normal! zE")
          for _, r in ipairs(ranges) do vim.cmd(("%d,%dfold"):format(r[1], r[2])) end
        end
        vim.api.nvim_create_user_command("Fold", toggle_folds, { desc = "Fold every function but main" })
        vim.cmd([[cnoreabbrev <expr> fold getcmdtype() ==# ':' && getcmdline() ==# 'fold' ? 'Fold' : 'fold']])

        -- Debugging
        map("n", "<F5>", function() require("dap").continue() end, { desc = "Start / continue debugging" })
        map("n", "<S-F5>", function() require("dap").terminate() end, { desc = "Stop debugging" })
        map("n", "<F9>", function() require("dap").toggle_breakpoint() end, { desc = "Toggle breakpoint" })
        map("n", "<F10>", function() require("dap").step_over() end, { desc = "Step over" })
        map("n", "<F11>", function() require("dap").step_into() end, { desc = "Step into" })
        map("n", "<S-F11>", function() require("dap").step_out() end, { desc = "Step out" })
      '';

      # Carbonfox, monochrome, on kitty's glass (transparent background).
      "nvim/lua/plugins/theme.lua".text = ''
        return {
          {
            "EdenEast/nightfox.nvim",
            lazy = false,
            priority = 1000,
            opts = {
              options = {
                transparent = true,
                styles = { sidebars = "transparent", floats = "transparent" },
              },
            },
          },
        }
      '';

      # Markdown like VS Code: the file stays plain, and :md or Space c v opens a
      # styled preview to the right that follows the text and the cursor
      # (render-markdown's own preview). Space u m still renders in place.
      "nvim/lua/plugins/markdown.lua".text = ''
        return {
          {
            "MeanderingProgrammer/render-markdown.nvim",
            opts = {
              enabled = false,
              overrides = {
                preview = {
                  enabled = true,
                  render_modes = true,
                  anti_conceal = { enabled = false },
                  checkbox = { enabled = true },
                  heading = { icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " } },
                  win_options = {
                    number = { default = false, rendered = false },
                    relativenumber = { default = false, rendered = false },
                    signcolumn = { default = "no", rendered = "no" },
                    spell = { default = false, rendered = false },
                  },
                },
              },
            },
            keys = {
              { "<leader>cV", function() require("render-markdown").preview() end,
                ft = "markdown", desc = "Markdown Preview (terminal)" },
            },
          },
          {
            -- nixpkgs' build, which runs its server with Nix's Node, so
            -- nothing gets downloaded.
            "iamcco/markdown-preview.nvim",
            dir = "${pkgs.vimPlugins.markdown-preview-nvim}",
            build = false,
            init = function()
              vim.g.mkdp_theme = "dark"
              vim.g.mkdp_markdown_css = "${previewCss}"
              vim.g.mkdp_highlight_css = "${previewHighlightCss}"
              vim.g.mkdp_page_title = "''${name}"
              vim.g.mkdp_combine_preview = 1
              vim.g.mkdp_auto_close = 0
              vim.g.mkdp_preview_options = { disable_filename = 1, sync_scroll_type = "middle" }
              -- :md opens (or closes) the preview.
              vim.api.nvim_create_user_command("Md", "MarkdownPreviewToggle", { desc = "Markdown Preview" })
              vim.cmd([[cnoreabbrev <expr> md getcmdtype() ==# ':' && getcmdline() ==# 'md' ? 'Md' : 'md']])
              ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
              vim.cmd([[
                function! MkdpOpen(url) abort
                  call jobstart(['${previewOpen}/bin/markdown-preview-open', a:url], { 'detach': v:true })
                endfunction
              ]])
              vim.g.mkdp_browserfunc = "MkdpOpen"
              ''}
            end,
            keys = {
              { "<leader>cv", "<cmd>MarkdownPreviewToggle<cr>", ft = "markdown", desc = "Markdown Preview" },
            },
          },
          -- No markdownlint: VS Code doesn't lint Markdown by default, and its
          -- fixes on save would rewrite the files.
          {
            "mfussenegger/nvim-lint",
            opts = function(_, opts) opts.linters_by_ft.markdown = nil end,
          },
          {
            "stevearc/conform.nvim",
            opts = function(_, opts)
              opts.formatters_by_ft.markdown = nil
              opts.formatters_by_ft["markdown.mdx"] = nil
            end,
          },
        }
      '';

      # The author of the current line at its end, as in the old config.
      "nvim/lua/plugins/git.lua".text = ''
        return {
          {
            "lewis6991/gitsigns.nvim",
            opts = { current_line_blame = true, current_line_blame_opts = { delay = 500 } },
          },
        }
      '';

      # The explorer opens files with a single click, like VS Code's.
      "nvim/lua/plugins/explorer.lua".text = ''
        return {
          {
            "nvim-neo-tree/neo-tree.nvim",
            opts = {
              window = { mappings = { ["<LeftRelease>"] = "open" } },
              filesystem = {
                filtered_items = { hide_dotfiles = false, hide_gitignored = false },
              },
            },
          },
        }
      '';
    } // lib.optionalAttrs cfg.ide {
      # clangd and jdtls from Nix (see extraPackages), so Mason doesn't install
      # its own. LazyVim only adds Lombok to jdtls from Mason's copy, so the
      # command line is set here with nixpkgs' jar.
      # C: 2-space indents and the column-80 guide (cIndent above).
      "nvim/after/ftplugin/c.lua".text = cIndent;
      # Java in the same style.
      "nvim/after/ftplugin/java.lua".text = cIndent;
      # And OCaml.
      "nvim/after/ftplugin/ocaml.lua".text = cIndent;

      # gd and gn (keys in plugins/nix.lua): a function's definition and its
      # uses, for the function under the cursor or, anywhere else in a body,
      # the function the cursor is inside.
      "nvim/lua/config/code_nav.lua".text = ''
        local M = {}

        -- The function's name: called or declared under the cursor ("call" /
        -- "decl"), else the name of the function around the cursor ("decl").
        local function target()
          local ok, node = pcall(vim.treesitter.get_node)
          if not ok or not node then return end
          local t = node:type()
          if t == "identifier" or t == "field_identifier" then
            local inner, p = node, node:parent()
            -- s->f(...) and s.f(...) in C.
            if p and p:type() == "field_expression" and p:field("field")[1] == node then
              inner, p = p, p:parent()
            end
            if p then
              local pt = p:type()
              if (pt == "call_expression" and p:field("function")[1] == inner)
                or (pt == "method_invocation" and p:field("name")[1] == node) then
                return { node = node, kind = "call" }
              end
              if (pt == "function_declarator" and p:field("declarator")[1] == node)
                or ((pt == "method_declaration" or pt == "constructor_declaration") and p:field("name")[1] == node) then
                return { node = node, kind = "decl" }
              end
            end
          end
          local n = node
          while n do
            local nt = n:type()
            if nt == "method_declaration" or nt == "constructor_declaration" then
              return { node = n:field("name")[1], kind = "decl", around = true }
            end
            if nt == "function_definition" then
              local d = n:field("declarator")[1]
              while d and d:type() ~= "function_declarator" do d = d:field("declarator")[1] end
              local name = d and d:field("declarator")[1]
              if name then return { node = name, kind = "decl", around = true } end
            end
            n = n:parent()
          end
        end

        -- clangd only knows the open files (and, with a compile_commands.json,
        -- its index), so from a .h it finds no uses. Open the project's C
        -- files that mention the name, hidden, and wait until clangd has read
        -- them. The project is the nearest folder up with a Makefile or
        -- CMakeLists.txt, else the file's folder.
        local function open_mentions(client, node)
          if client.name ~= "clangd" then return end
          local file = vim.api.nvim_buf_get_name(0)
          if vim.fs.root(file, "compile_commands.json") then return end
          local root = vim.fs.root(file, { "GNUmakefile", "makefile", "Makefile", "CMakeLists.txt" })
            or vim.fs.dirname(file)
          local name = vim.treesitter.get_node_text(node, 0)
          local res = vim.system({ "rg", "-l", "-w", "-F", "-t", "c", "-t", "cpp", "--", name, root }, { text = true }):wait()
          local files = vim.split(res.stdout or "", "\n", { trimempty = true })
          for i = 1, math.min(#files, 50) do
            local b = vim.fn.bufadd(files[i])
            if not vim.api.nvim_buf_is_loaded(b) then
              vim.bo[b].buflisted = false
              vim.fn.bufload(b)
              -- Answered once clangd has parsed the file (and indexed it).
              if vim.lsp.get_clients({ bufnr = b, name = "clangd" })[1] then
                client:request_sync("textDocument/documentSymbol",
                  { textDocument = { uri = vim.uri_from_bufnr(b) } }, 5000, b)
              end
            end
          end
        end

        -- Ask the language server about the name node; returns the
        -- locations as { uri, range } and the server's position encoding.
        local function ask(method, node, extra)
          local client = vim.lsp.get_clients({ bufnr = 0, method = method })[1]
          if not client then return {}, "utf-16" end
          open_mentions(client, node)
          local row, col = node:start()
          local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ""
          local params = vim.tbl_extend("force", {
            textDocument = vim.lsp.util.make_text_document_params(0),
            position = { line = row, character = vim.str_utfindex(line, client.offset_encoding, col, false) },
          }, extra or {})
          local res = client:request_sync(method, params, 3000, 0)
          local result = res and res.result or {}
          if result.uri or result.targetUri then result = { result } end
          local out = {}
          for _, l in ipairs(result) do
            table.insert(out, { uri = l.uri or l.targetUri, range = l.targetSelectionRange or l.range })
          end
          return out, client.offset_encoding
        end

        local function here(node)
          local row = node:start()
          return { uri = vim.uri_from_bufnr(0), line = row }
        end
        local function elsewhere(locs, at)
          return vim.tbl_filter(function(l) return not (l.uri == at.uri and l.range.start.line == at.line) end, locs)
        end
        local function jump(loc, enc)
          vim.cmd("normal! m'")
          vim.lsp.util.show_document({ uri = loc.uri, range = loc.range }, enc, { focus = true })
        end

        -- gd: on a call, to the function's code; on a declaration or inside
        -- a body, to the prototype (or from a prototype to the code).
        function M.definition()
          local t = target()
          if not t then return vim.lsp.buf.definition() end
          local at = here(t.node)
          local methods = t.kind == "call" and { "textDocument/definition" }
            or { "textDocument/declaration", "textDocument/definition" }
          for _, method in ipairs(methods) do
            local locs, enc = ask(method, t.node)
            locs = elsewhere(locs, at)
            if #locs > 0 then return jump(locs[1], enc) end
          end
          -- No prototype anywhere else: at least the function's own name.
          if t.around then
            vim.cmd("normal! m'")
            local row, col = t.node:start()
            return vim.api.nvim_win_set_cursor(0, { row + 1, col })
          end
          vim.notify("No other definition", vim.log.levels.INFO)
        end

        -- gn / gN: the next / previous call of that function, in file order,
        -- wrapping around.
        function M.use(dir)
          local t = target()
          if not t then return vim.notify("Not on or inside a function", vim.log.levels.WARN) end
          local locs, enc = ask("textDocument/references", t.node, { context = { includeDeclaration = false } })
          if #locs == 0 then return vim.notify("No uses found", vim.log.levels.INFO) end
          local function before(a, b)
            if a.uri ~= b.uri then return a.uri < b.uri end
            if a.range.start.line ~= b.range.start.line then return a.range.start.line < b.range.start.line end
            return a.range.start.character < b.range.start.character
          end
          table.sort(locs, before)
          local cur = vim.api.nvim_win_get_cursor(0)
          local line = vim.api.nvim_get_current_line()
          local me = { uri = vim.uri_from_bufnr(0), range = { start = {
            line = cur[1] - 1, character = vim.str_utfindex(line, enc, cur[2], false) } } }
          local pick, index
          if dir > 0 then
            for i, l in ipairs(locs) do
              if before(me, l) then pick, index = l, i break end
            end
            if not pick then pick, index = locs[1], 1 end
          else
            for i = #locs, 1, -1 do
              if before(locs[i], me) then pick, index = locs[i], i break end
            end
            if not pick then pick, index = locs[#locs], #locs end
          end
          jump(pick, enc)
          vim.api.nvim_echo({ { ("Use %d of %d"):format(index, #locs) } }, false, {})
        end

        return M
      '';

      "nvim/lua/plugins/nix.lua".text = ''
        return {
          {
            "neovim/nvim-lspconfig",
            opts = function(_, opts)
              opts.servers.clangd = vim.tbl_extend("force", opts.servers.clangd or {}, { mason = false })
              opts.servers.jdtls = vim.tbl_extend("force", opts.servers.jdtls or {}, { mason = false })
              opts.servers.ocamllsp = vim.tbl_extend("force", opts.servers.ocamllsp or {}, { mason = false })
              -- No inlay hints in C or Java: the parameter names the servers
              -- draw push the code right, past the column-80 guide (Space u h
              -- shows them).
              opts.inlay_hints.exclude = opts.inlay_hints.exclude or {}
              table.insert(opts.inlay_hints.exclude, "c")
              table.insert(opts.inlay_hints.exclude, "java")
              -- Without a compile_commands.json clangd reads a .h as C++, so its
              -- functions aren't the ones the .c files call (gn found no uses
              -- from a header). Tell it each header is C, as Neovim has it.
              vim.api.nvim_create_autocmd("LspAttach", {
                callback = function(ev)
                  local client = vim.lsp.get_client_by_id(ev.data.client_id)
                  local file = vim.api.nvim_buf_get_name(ev.buf)
                  if not client or client.name ~= "clangd" or not file:match("%.h$")
                    or vim.fs.root(file, "compile_commands.json") then return end
                  client:notify("workspace/didChangeConfiguration", { settings = {
                    compilationDatabaseChanges = { [file] = {
                      workingDirectory = vim.fs.dirname(file),
                      compilationCommand = { "clang", "-xc-header", file },
                    } },
                  } })
                end,
              })
              -- gd also works from inside a function's body, gn / gN walk
              -- through its uses (lua/config/code_nav.lua).
              local all = opts.servers["*"]
              all.keys = all.keys or {}
              vim.list_extend(all.keys, {
                { "gd", function() require("config.code_nav").definition() end, desc = "Goto Definition", has = "definition" },
                { "gn", function() require("config.code_nav").use(1) end, desc = "Next use of the function", has = "references" },
                { "gN", function() require("config.code_nav").use(-1) end, desc = "Previous use of the function", has = "references" },
              })
            end,
          },
          {
            "stevearc/conform.nvim",
            opts = {
              formatters_by_ft = {
                c = { "c_style" },
                java = { "java_style" },
                ocaml = { "ocamlformat" },
              },
              formatters = {
                c_style = { command = "code-style", args = { "c" } },
                java_style = { command = "code-style", args = { "java" } },
                -- Only in projects with an .ocamlformat: it drops the ;; the
                -- course files use for the toplevel.
                ocamlformat = {
                  condition = function(_, ctx)
                    return vim.fs.find(".ocamlformat", { path = ctx.dirname, upward = true })[1] ~= nil
                  end,
                },
              },
            },
          },
          -- jdtls rebuilds the project on every save (for cross-file errors);
          -- its progress messages for that are hidden. The ones while it
          -- starts (importing, indexing) still show.
          {
            "folke/noice.nvim",
            opts = function(_, opts)
              opts.routes = opts.routes or {}
              table.insert(opts.routes, {
                filter = {
                  event = "lsp",
                  kind = "progress",
                  cond = function(message)
                    local p = message.opts.progress or {}
                    local title = (p.title or "") .. " " .. (p.message or "")
                    return p.client == "jdtls"
                      and (title:find("Building") or title:find("Validate documents")
                        or title:find("Publish Diagnostics")) ~= nil
                  end,
                },
                opts = { skip = true },
              })
            end,
          },
          {
            "mfussenegger/nvim-jdtls",
            opts = function(_, opts)
              opts.cmd = {
                vim.fn.exepath("jdtls"),
                "--jvm-arg=-javaagent:${pkgs.lombok}/share/java/lombok.jar",
              }
              return opts
            end,
          },
        }
      '';
    };
  };
}
