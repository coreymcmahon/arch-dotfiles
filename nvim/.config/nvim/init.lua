-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Load config
require("config.options")
require("config.keymaps")

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  defaults = {
    lazy = false,
    version = false,
  },
  -- install = { colorscheme = { "habamax" } },
  checker = { enabled = false },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})

require("config.languages").setup({
  prefer_editorconfig = true, -- let .editorconfig win (set to false to force Neovim settings)
})

-- Auto-close empty unnamed buffers when opening a file
vim.api.nvim_create_autocmd("BufHidden", {
  callback = function(event)
    if vim.bo[event.buf].buftype == "" and vim.fn.bufname(event.buf) == "" then
      if vim.fn.getbufline(event.buf, 1, "$")[1] == "" and #vim.fn.getbufline(event.buf, 1, "$") == 1 then
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(event.buf) then
            vim.api.nvim_buf_delete(event.buf, { force = true })
          end
        end)
      end
    end
  end,
})

