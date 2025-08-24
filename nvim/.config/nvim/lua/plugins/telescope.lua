-- lua/plugins/telescope.lua
return {
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" }, -- faster sorting
      "nvim-tree/nvim-web-devicons", -- icons in picker
    },
    cmd = "Telescope",
    keys = {
      -- Files & search
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live Grep" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
      { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help Tags" },
      { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent Files" },
      { "<leader>fw", "<cmd>Telescope grep_string<cr>", desc = "Find Word Under Cursor" },
      -- Git
      { "<leader>gc", "<cmd>Telescope git_commits<cr>", desc = "Git Commits" },
      { "<leader>gs", "<cmd>Telescope git_status<cr>", desc = "Git Status" },
    },
    config = function()
      local telescope = require("telescope")
      local actions = require("telescope.actions")

      telescope.setup({
        defaults = {
          prompt_prefix = "  ",
          selection_caret = " ",
          path_display = { "smart" },
          sorting_strategy = "ascending",
          layout_config = {
            prompt_position = "top",
            width = 0.9,
            height = 0.9,
          },
          -- Performance optimizations
          file_ignore_patterns = { 
            "node_modules", 
            ".git/",
            "vendor/",
            "%.lock",
            "__pycache__",
            "%.sqlite3",
            "%.ipynb_checkpoints",
            "dist/",
            "build/",
            "target/",
            "*.min.js",
          },
          -- Use ripgrep for live_grep
          vimgrep_arguments = {
            "rg",
            "--color=never",
            "--no-heading",
            "--with-filename",
            "--line-number",
            "--column",
            "--smart-case",
            "--trim",  -- Remove indentation
            "--hidden",
            "--glob=!.git/",
          },
          mappings = {
            i = {
              ["<C-j>"] = actions.move_selection_next,
              ["<C-k>"] = actions.move_selection_previous,
              ["<esc>"] = actions.close,
              ["<C-u>"] = false,  -- Clear prompt with Ctrl+u
            },
            n = {
              ["q"] = actions.close,
            },
          },
        },
        pickers = {
          find_files = {
            -- Use fd for finding files (much faster than the default find)
            find_command = { 
              "fd", 
              "--type", "f", 
              "--hidden", 
              "--follow",
              "--exclude", ".git",
              "--exclude", "node_modules",
              "--exclude", "vendor",
              "--exclude", "dist",
              "--exclude", "build",
              "--strip-cwd-prefix",  -- Remove ./ prefix
            },
            hidden = true,
          },
          live_grep = {
            additional_args = function()
              return { "--hidden", "--glob", "!.git/" }
            end,
          },
          buffers = {
            sort_mru = true,  -- Sort by most recently used
            ignore_current_buffer = true,
            mappings = {
              i = {
                ["<c-d>"] = actions.delete_buffer,
              },
            },
          },
          oldfiles = {
            cwd_only = true,  -- Show only files from current working directory
          },
        },
        extensions = {
          fzf = {
            fuzzy = true,                    -- false will only do exact matching
            override_generic_sorter = true,  -- override the generic sorter
            override_file_sorter = true,     -- override the file sorter
            case_mode = "smart_case",        -- or "ignore_case" or "respect_case"
          },
        },
      })

      -- Load fzf extension for better performance
      telescope.load_extension("fzf")
    end,
  },
}