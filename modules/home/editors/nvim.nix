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
  c = config.lib.stylix.colors.withHashtag;
  previewCss = pkgs.writeText "markdown-preview.css" ''
    html, body, #page-ctn, .markdown-body {
      background: ${c.base00} !important;
    }
    .markdown-body {
      max-width: 1180px;
      margin: 0 auto;
      padding: 32px 36px;
      color: ${c.base05};
      font-family: "Inter", -apple-system, sans-serif;
      font-size: 16px;
      line-height: 1.65;
    }
    .markdown-body h1, .markdown-body h2, .markdown-body h3,
    .markdown-body h4, .markdown-body h5, .markdown-body h6 {
      color: ${c.base07};
      font-weight: 650;
      border-color: ${c.base02};
    }
    .markdown-body a { color: ${c.base0D}; }
    .markdown-body code, .markdown-body pre, .markdown-body tt {
      font-family: "FiraCode Nerd Font Mono", monospace;
    }
    .markdown-body :not(pre) > code {
      background: ${c.base01};
      color: ${c.base06};
      border-radius: 6px;
      padding: 0.15em 0.4em;
    }
    .markdown-body pre {
      background: ${c.base01} !important;
      border: 1px solid ${c.base02};
      border-radius: 10px;
    }
    .markdown-body table { display: table; width: auto; }
    .markdown-body table th, .markdown-body table td { border-color: ${c.base02}; }
    .markdown-body table tr { background: transparent; border-color: ${c.base02}; }
    .markdown-body table tr:nth-child(2n) { background: ${c.base01}; }
    .markdown-body blockquote { color: ${c.base04}; border-left-color: ${c.base0D}; }
    .markdown-body hr { background: ${c.base02}; }
  '';

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
      profile=''${XDG_CACHE_HOME:-$HOME/.cache}/markdown-preview-firefox
      mkdir -p "$profile/chrome"
      install -m 644 ${previewUserJs} "$profile/user.js"
      install -m 644 ${previewUserChrome} "$profile/chrome/userChrome.css"
      exec firefox --profile "$profile" --no-remote --new-instance --name markdown-preview "$1"
    '';
  };

  # C formatting on save: c-style runs clang-format with this style and adds
  # the layout clang-format can't do (one-line blocks kept, includes by
  # length, grouped defines and typedefs, three blank lines around main).
  clangFormat = ../../../assets/nvim/clang-format.yaml;
  cStyle = pkgs.writeShellScriptBin "c-style" ''
    exec ${pkgs.python3}/bin/python3 ${../../../assets/nvim/c-style.py} \
      ${pkgs.clang-tools}/bin/clang-format ${clangFormat}
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
        cStyle
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

        -- :Make (and a typed :make) saves everything and runs make, from the
        -- nearest Makefile above the current file, in a terminal that opens
        -- in the editor window like a file (a tab; the explorer stays),
        -- focused so the program can be typed into. Running it again replaces
        -- the previous one; once it ends, q closes it.
        local make_buf
        local function run_make(args)
          vim.cmd("silent! wall")
          local file = vim.api.nvim_buf_get_name(0)
          local start = file ~= "" and vim.fs.dirname(file) or vim.uv.cwd()
          local makefile = vim.fs.find({ "GNUmakefile", "makefile", "Makefile" }, { upward = true, path = start })[1]
          local dir = makefile and vim.fs.dirname(makefile) or vim.uv.cwd()
          -- From the explorer or another side panel, use the editor window.
          local function editor(win)
            local buf = vim.api.nvim_win_get_buf(win)
            return vim.api.nvim_win_get_config(win).relative == ""
              and (vim.bo[buf].buftype == "" or buf == make_buf)
          end
          if not editor(0) then
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
              if editor(win) then
                vim.api.nvim_set_current_win(win)
                break
              end
            end
          end
          local old = make_buf
          vim.cmd("enew")
          make_buf = vim.api.nvim_get_current_buf()
          if old and vim.api.nvim_buf_is_valid(old) then
            vim.api.nvim_buf_delete(old, { force = true })
          end
          vim.fn.jobstart(vim.list_extend({ "make" }, args), { cwd = dir, term = true })
          local buf = make_buf
          -- Back to normal mode when it ends, so a key doesn't close it.
          vim.api.nvim_create_autocmd("TermClose", {
            buffer = buf,
            callback = function()
              vim.schedule(function()
                if vim.api.nvim_get_current_buf() == buf then vim.cmd("stopinsert") end
              end)
            end,
          })
          vim.keymap.set("n", "q", function() Snacks.bufdelete({ buf = buf, force = true }) end, { buffer = buf, desc = "Close make" })
          vim.cmd("startinsert")
        end
        vim.api.nvim_create_user_command("Make", function(o) run_make(o.fargs) end, { nargs = "*", desc = "make in a terminal" })
        vim.cmd([[cnoreabbrev <expr> make getcmdtype() ==# ':' && getcmdline() ==# 'make' ? 'Make' : 'make']])
        map("n", "<leader>m", "<cmd>Make<cr>", { desc = "Make" })
      '' + lib.optionalString cfg.ide ''

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

      # Markdown like VS Code: the file stays plain, and Space c v opens a
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
              vim.g.mkdp_page_title = "''${name}"
              vim.g.mkdp_combine_preview = 1
              vim.g.mkdp_auto_close = 0
              vim.g.mkdp_preview_options = { disable_filename = 1, sync_scroll_type = "middle" }
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
      # C: 2-space indents with spaces and a guide at column 80, the limit
      # clang-format wraps at.
      "nvim/after/ftplugin/c.lua".text = ''
        vim.opt_local.expandtab = true
        vim.opt_local.shiftwidth = 2
        vim.opt_local.tabstop = 2
        vim.opt_local.colorcolumn = "81"
      '';

      "nvim/lua/plugins/nix.lua".text = ''
        return {
          {
            "neovim/nvim-lspconfig",
            opts = function(_, opts)
              opts.servers.clangd = vim.tbl_extend("force", opts.servers.clangd or {}, { mason = false })
              opts.servers.jdtls = vim.tbl_extend("force", opts.servers.jdtls or {}, { mason = false })
              -- No inlay hints in C: the parameter names clangd draws push the
              -- code right, past the column-80 guide (Space u h shows them).
              opts.inlay_hints.exclude = opts.inlay_hints.exclude or {}
              table.insert(opts.inlay_hints.exclude, "c")
            end,
          },
          {
            "stevearc/conform.nvim",
            opts = {
              formatters_by_ft = { c = { "c_style" } },
              formatters = { c_style = { command = "c-style" } },
            },
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
