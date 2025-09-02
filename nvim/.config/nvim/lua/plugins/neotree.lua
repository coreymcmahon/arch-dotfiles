-- lua/plugins/neo-tree.lua
return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons", -- optional but nice
      "MunifTanjim/nui.nvim",
    },
    cmd = { "Neotree" },
    keys = {
      { "<leader>e", function() vim.cmd("Neotree toggle reveal left") end, desc = "Explorer" },
      { "<leader>E", function() vim.cmd("Neotree toggle float") end, desc = "Explorer (float)" },
    },
    init = function()
      -- Auto-open Neo-tree when vim starts with a directory
      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function(data)
          -- Check if we opened a directory
          local directory = vim.fn.isdirectory(data.file) == 1
          
          if directory then
            -- Change to the directory
            vim.cmd.cd(data.file)
            -- Wipe the empty buffer
            vim.cmd("bwipeout")
            -- Open Neo-tree (only once)
            vim.cmd("Neotree filesystem reveal left")
          end
        end,
      })
    end,
    opts = {
      close_if_last_window = true,
      popup_border_style = "rounded",
      enable_git_status = true,
      enable_diagnostics = true,
      sources = { "filesystem", "buffers", "git_status" },
      source_selector = {
        winbar = true, statusline = false,
        content_layout = "center",
        sources = {
          { source = "filesystem", display_name = " Files" },
          { source = "buffers",    display_name = " Buffers" },
          { source = "git_status", display_name = " Git" },
        },
      },
      window = {
        position = "left",
        width = 32,
        mapping_options = {
          noremap = true,
          nowait = true,
        },
      },
      filesystem = {
        bind_to_cwd = true,
        follow_current_file = { enabled = true, leave_dirs_open = false },
        use_libuv_file_watcher = true,
        hijack_netrw_behavior = "disabled",  -- Disable netrw hijacking to prevent double opening
        filtered_items = {
          visible = false,  -- set true to show “hidden” entries by default
          hide_dotfiles = true,
          hide_gitignored = true,
          never_show = { ".DS_Store" },
        },
        window = {
          mappings = {
            ["<CR>"] = "open",
            ["l"]    = "open",
            ["h"]    = "close_node",
            ["H"]    = "toggle_hidden",
            ["P"]    = "toggle_preview",
            ["a"]    = { "add", config = { show_path = "relative" } },
            ["A"]    = "add_directory",
            ["r"]    = "rename",
            ["d"]    = "delete",
            ["y"]    = "copy_to_clipboard",
            ["p"]    = "paste_from_clipboard",
            ["c"]    = "copy",   -- duplicate
            ["m"]    = "move",
            ["q"]    = "close_window",
          },
        },
      },
      default_component_configs = {
        git_status = {
          symbols = {
            added = "A", modified = "M", deleted = "D", renamed = "R",
            untracked = "U", ignored = "󰚌", unstaged = "", staged = "", conflict = "",
          },
        },
        indent = { with_expanders = true, expander_collapsed = "", expander_expanded = "" },
      },
    },
  },
}

