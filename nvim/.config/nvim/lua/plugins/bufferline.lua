-- lua/plugins/bufferline.lua
return {
  {
    "akinsho/bufferline.nvim",
    version = "*", -- use latest stable
    event = "UIEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" }, -- optional, for icons
    config = function()
      require("bufferline").setup({
        options = {
          mode = "buffers", -- show buffer tabs
          numbers = "none", -- "ordinal" | "buffer_id" | "both"
          close_command = "bdelete! %d",
          right_mouse_command = "bdelete! %d",
          show_close_icon = false,
          show_buffer_close_icons = true,
          show_tab_indicators = true,
          separator_style = "slant", -- "slant" | "thick" | "thin" | { 'any', 'any' }
          diagnostics = "nvim_lsp", -- show LSP errors/warnings per buffer
          offsets = {
            {
              filetype = "neo-tree", -- if you use neo-tree, shift bufferline right
              text = "File Explorer",
              text_align = "center",
              separator = true,
            },
          },
        },
      })
    end,
  },
}

