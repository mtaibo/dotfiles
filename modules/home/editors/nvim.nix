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
  extras = [ "editor.neo-tree" ] ++ ideExtras;
  importExtras = lib.concatMapStrings (e: ''
        { import = "lazyvim.plugins.extras.${e}" },
  '') extras;
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
      ];

      extraLuaConfig = ''
        require("config.lazy")
      '';
    };

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

      "nvim/lua/config/options.lua".text = ''
        vim.opt.tabstop = 2
        vim.opt.shiftwidth = 2
        vim.opt.relativenumber = true
        vim.opt.mouse = "a"
        vim.opt.clipboard = "unnamedplus"
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
      "nvim/lua/plugins/nix.lua".text = ''
        return {
          {
            "neovim/nvim-lspconfig",
            opts = { servers = { clangd = { mason = false }, jdtls = { mason = false } } },
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
