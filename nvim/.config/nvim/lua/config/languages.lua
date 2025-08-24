local M = {}

-- Edit this table to add/adjust filetype rules.
M.specs = {
  -- PHP: 4 spaces, let php.vim handle the indentation logic
  { 
    patterns = { "php" }, 
    opts = { 
      shiftwidth = 4, 
      tabstop = 4, 
      expandtab = true,
      autoindent = true,
      -- Don't set smartindent or cindent - let the PHP plugin handle it
    } 
  },

  -- JS/TS: 2 spaces
  {
    patterns = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
    opts = { shiftwidth = 2, tabstop = 2, expandtab = true },
  },

  -- Go: hard tabs
  { patterns = { "go" }, opts = { shiftwidth = 0, tabstop = 4, expandtab = false } },
}

-- prefer_editorconfig=true means: if .editorconfig has already set options for this buffer,
-- we skip our rules (good for team repos). Set to false to always enforce these settings.
function M.setup(opts)
  local prefer_editorconfig = (opts and opts.prefer_editorconfig) ~= false
  local group = vim.api.nvim_create_augroup("PerLanguageIndent", { clear = true })

  for _, spec in ipairs(M.specs) do
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = table.concat(spec.patterns, ","),
      callback = function(args)
        if prefer_editorconfig and vim.b.editorconfig then return end
        for k, v in pairs(spec.opts or {}) do
          vim.opt_local[k] = v
        end
      end,
    })
  end
end

return M

