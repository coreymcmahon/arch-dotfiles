return {
  {
    "nvim-lualine/lualine.nvim",
    event = "UIEnter",
    init = function()
      if vim.fn.has("nvim-0.8") == 1 then
        vim.o.laststatus = 3 -- global statusline
      else
        vim.o.laststatus = 2 -- per-window
      end
    end,
    config = function()
      require("lualine").setup({
        options = {
          theme = "auto",
          -- globalstatus = (vim.o.laststatus == 3),
          globalstatus = true, -- one statusline across all windows
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          disabled_filetypes = { statusline = {} },
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch" },
          lualine_c = {
            { "filename", path = 1, newfile_status = true },
            { "diagnostics" },
          },
          lualine_x = { "encoding", "fileformat", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { "location" },
          lualine_y = {},
          lualine_z = {},
        },
        tabline = {},
        extensions = {},
      })
    end,
  },
}

