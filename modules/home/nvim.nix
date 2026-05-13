{ pkgs, ... }: {
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;

    plugins = with pkgs.vimPlugins; [
      tokyonight-nvim
      nvim-lspconfig
      plenary-nvim
      neo-tree-nvim
      nvim-web-devicons
      lualine-nvim
      bufferline-nvim
      telescope-nvim
      which-key-nvim
      gitsigns-nvim
    ];

    extraLuaConfig = ''
      -- Transparent background
      vim.cmd([[highlight Normal ctermbg=NONE guibg=NONE]])
      vim.cmd([[highlight NonText ctermbg=NONE guibg=NONE]])
      vim.cmd([[highlight NormalFloat ctermbg=NONE guibg=NONE]])
      vim.cmd([[highlight LineNr ctermbg=NONE guibg=NONE]])
      vim.cmd([[highlight SignColumn ctermbg=NONE guibg=NONE]])

      -- TokyoNight
      require("tokyonight").setup({
        transparent = true,
        styles = {
          sidebars = "transparent",
          floats = "transparent",
        },
      })
      vim.cmd([[colorscheme tokyonight]])

      -- General options
      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.tabstop = 2
      vim.opt.shiftwidth = 2
      vim.opt.expandtab = true
      vim.opt.mouse = "a"
      vim.opt.termguicolors = true
      vim.opt.clipboard = "unnamedplus"
      vim.opt.ignorecase = true
      vim.opt.smartcase = true
      vim.opt.splitright = true
      vim.opt.splitbelow = true
      vim.opt.hidden = true
      vim.opt.updatetime = 300
      vim.opt.timeoutlen = 500

      vim.g.mapleader = " "

      -- Neo-tree (VS Code-like file explorer)
      vim.cmd([[highlight! NeoTreeNormal ctermbg=NONE guibg=NONE]])
      vim.cmd([[highlight! NeoTreeNormalNC ctermbg=NONE guibg=NONE]])
      vim.cmd([[highlight! NeoTreeEndOfBuffer ctermbg=NONE guibg=NONE]])

      require("neo-tree").setup({
        close_if_last_window = true,
        window = {
          position = "left",
          width = 35,
          mappings = {
            ["<space>"] = "toggle_node",
            ["<cr>"] = "open",
            ["<esc>"] = "revert_preview",
            ["P"] = { "toggle_preview", config = { use_float = true } },
            ["l"] = "focus_preview",
            ["S"] = "open_split",
            ["s"] = "open_vsplit",
            ["t"] = "open_tabnew",
            ["w"] = "open_with_window_picker",
            ["C"] = "close_node",
            ["z"] = "close_all_nodes",
            ["R"] = "refresh",
            ["a"] = "add",
            ["d"] = "delete",
            ["r"] = "rename",
            ["y"] = "copy_to_clipboard",
            ["x"] = "cut_to_clipboard",
            ["p"] = "paste_from_clipboard",
            ["c"] = "copy",
            ["m"] = "move",
            ["q"] = "close_window",
          },
        },
        filesystem = {
          filtered_items = {
            visible = false,
            hide_dotfiles = false,
            hide_gitignored = false,
            hide_by_name = {
              ".DS_Store",
              "thumbs.db",
              "node_modules",
            },
          },
          follow_current_file = { enabled = true },
          use_libuv_file_watcher = true,
        },
        buffers = { follow_current_file = { enabled = true } },
        git_status = { window = { position = "float" } },
      })

      -- Lualine (statusline)
      require("lualine").setup({
        options = {
          theme = "tokyonight",
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          disabled_filetypes = { "neo-tree", "TelescopePrompt" },
          always_divide_middle = true,
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { "encoding", "fileformat", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      })

      -- Bufferline (tabs at top like VS Code)
      vim.opt.termguicolors = true
      require("bufferline").setup({
        options = {
          numbers = "none",
          close_command = "bdelete! %d",
          right_mouse_command = "bdelete! %d",
          indicator = { style = "underline" },
          buffer_close_icon = "",
          modified_icon = "●",
          left_trunc_marker = "",
          right_trunc_marker = "",
          max_name_length = 18,
          max_prefix_length = 15,
          tab_size = 18,
          show_buffer_close_icons = true,
          get_element_icon = function(element)
            local icon, color = require("nvim-web-devicons").get_icon(element.path, element.extension, { default = false })
            if icon then return icon, color end
            return "", nil
          end,
          diagnostics = "nvim_lsp",
          diagnostics_indicator = function(count)
            return "(" .. count .. ")"
          end,
          offsets = {
            {
              filetype = "neo-tree",
              text = "󰙅  Explorer",
              highlight = "Directory",
              text_align = "left",
            },
          },
          separator_style = "thin",
          always_show_bufferline = true,
          sort_by = "insert_at_end",
        },
      })

      -- Which-key
      require("which-key").setup({
        plugins = { spelling = true, presets = { operators = false } },
        icons = { breadcrumb = ">", separator = " ", group = "+" },
        window = { border = "rounded", margin = { 0, 0, 0, 0 } },
        layout = { height = { min = 4, max = 25 }, width = { min = 20, max = 50 } },
      })

      -- Telescope (fuzzy finder)
      require("telescope").setup({
        defaults = {
          prompt_prefix = "   ",
          selection_caret = "  ",
          layout_strategy = "horizontal",
          layout_config = {
            horizontal = { prompt_position = "top", preview_width = 0.5 },
            vertical = { mirror = false },
            width = 0.85,
            height = 0.80,
          },
          file_ignore_patterns = { "node_modules", ".git" },
        },
        pickers = {
          find_files = { hidden = true },
          live_grep = { additional_args = { "--hidden" } },
        },
      })

      -- Gitsigns (git decorations in gutter)
      require("gitsigns").setup({
        signs = {
          add = { text = "│" },
          change = { text = "│" },
          delete = { text = "_" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
          untracked = { text = "┆" },
        },
        current_line_blame = true,
        current_line_blame_opts = { delay = 500 },
      })

      -- Keymaps
      local keymap = vim.keymap.set
      local opts = { noremap = true, silent = true }

      -- Better window navigation
      keymap("n", "<C-h>", "<C-w>h", opts)
      keymap("n", "<C-j>", "<C-w>j", opts)
      keymap("n", "<C-k>", "<C-w>k", opts)
      keymap("n", "<C-l>", "<C-w>l", opts)

      -- Neo-tree toggle (like VS Code Ctrl+B)
      keymap("n", "<leader>e", ":Neotree toggle<CR>", opts)

      -- Telescope (like VS Code Ctrl+P / Ctrl+Shift+F)
      keymap("n", "<leader>ff", "<cmd>Telescope find_files<CR>", opts)
      keymap("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", opts)
      keymap("n", "<leader>fb", "<cmd>Telescope buffers<CR>", opts)
      keymap("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", opts)

      -- Buffer navigation (like VS Code tabs)
      keymap("n", "<Tab>", ":bnext<CR>", opts)
      keymap("n", "<S-Tab>", ":bprevious<CR>", opts)
      keymap("n", "<leader>x", ":bdelete<CR>", opts)
    '';
  };
}
