{ config, lib, pkgs, ... }:
let
  cfg = config.dotfiles.nvim;

  # LazyVim extras that turn it into an IDE (C/C++, CMake, Java, debugger,
  # tests). Off on the Pi, where only the editor is wanted.
  ideExtras = lib.optionals cfg.ide [
    "lang.clangd"
    "lang.cmake"
    "lang.java"
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

  # :help opens this page: a Vim guide (assets/nvim/help.md) rendered with
  # the preview's own markdown-it and stylesheet, in the preview's window on
  # Linux and the default browser on the Mac.
  helpPage = pkgs.runCommand "nvim-help" { nativeBuildInputs = [ pkgs.nodejs ]; } ''
    mkdir -p $out
    node ${../../../assets/nvim/help-render.js} \
      ${pkgs.vimPlugins.markdown-preview-nvim}/app ${../../../assets/nvim/help.md} \
      $out/index.html ${previewCss} ${previewHighlightCss} ${../../../assets/nvim/help.css}
  '';
  helpOpen = if pkgs.stdenv.hostPlatform.isDarwin
    then "{ 'open', '${helpPage}/index.html' }"
    else "{ '${previewOpen}/bin/markdown-preview-open', 'file://${helpPage}/index.html', 'nvim-help' }";

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
    description = "C/C++ and Java tooling (LSPs, debugger, tests) in Neovim.";
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
      ];

      extraLuaConfig = ''
        require("config.lazy")
      '';
    };

    # The same style for clangd and clang-format run by hand anywhere in ~.
    home.file = lib.mkIf cfg.ide { ".clang-format".source = clangFormat; };

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

      "nvim/lua/plugins/nix.lua".text = ''
        return {
          {
            "neovim/nvim-lspconfig",
            opts = function(_, opts)
              opts.servers.clangd = vim.tbl_extend("force", opts.servers.clangd or {}, { mason = false })
              opts.servers.jdtls = vim.tbl_extend("force", opts.servers.jdtls or {}, { mason = false })
              -- No inlay hints in C or Java: the parameter names the servers
              -- draw push the code right, past the column-80 guide (Space u h
              -- shows them).
              opts.inlay_hints.exclude = opts.inlay_hints.exclude or {}
              table.insert(opts.inlay_hints.exclude, "c")
              table.insert(opts.inlay_hints.exclude, "java")
            end,
          },
          {
            "stevearc/conform.nvim",
            opts = {
              formatters_by_ft = { c = { "c_style" }, java = { "java_style" } },
              formatters = {
                c_style = { command = "code-style", args = { "c" } },
                java_style = { command = "code-style", args = { "java" } },
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
