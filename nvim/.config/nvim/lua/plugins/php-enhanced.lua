-- lua/plugins/php-enhanced.lua
-- Enhanced PHP/Laravel support with better indentation
return {
  -- Use the maintained fork of PHP indenting that works better with modern PHP
  {
    "yaegassy/neoformat-prettierd",
    enabled = false,
  },
  
  -- Better PHP indentation using vim's built-in indentexpr
  {
    "StanAngeloff/php.vim",
    ft = "php",
    priority = 100,  -- Load before other PHP plugins
    config = function()
      -- This provides better PHP syntax and indentation
      vim.g.php_version_id = 80200  -- PHP 8.2
      vim.g.php_html_load = 0
      vim.g.php_sql_query = 0
      vim.g.php_sql_heredoc = 0
      vim.g.php_sql_nowdoc = 0
      vim.g.php_parent_error_open = 1
      vim.g.php_parent_error_close = 1
      vim.g.php_folding = 0
      vim.g.php_sync_method = -1
      
      -- Fix indentation after { on the same line (common in Laravel)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "php",
        callback = function()
          -- Custom mapping to handle indentation after {
          vim.keymap.set('i', '<CR>', function()
            local line = vim.api.nvim_get_current_line()
            local col = vim.api.nvim_win_get_cursor(0)[2]
            local before_cursor = line:sub(1, col)
            local after_cursor = line:sub(col + 1)
            
            -- Check if we're after an opening brace
            if before_cursor:match("{%s*$") and after_cursor:match("^%s*}") then
              -- We're between braces, do the smart expansion
              return "<CR><CR><Up><Tab>"
            elseif before_cursor:match("{%s*$") then
              -- We're after an opening brace, ensure proper indentation
              return "<CR><Tab>"
            else
              -- Normal enter behavior
              return "<CR>"
            end
          end, { expr = true, buffer = true })
        end,
      })
    end,
  },

  -- Laravel Blade syntax support
  {
    "jwalton512/vim-blade",
    ft = "blade",
    config = function()
      -- Define blade filetype for *.blade.php files
      vim.cmd([[
        augroup BladeFtDetect
          autocmd!
          autocmd BufRead,BufNewFile *.blade.php set filetype=blade
        augroup END
      ]])
    end,
  },

  -- Optional: Laravel-specific tools and helpers
  {
    "adalessa/laravel.nvim",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "tpope/vim-dotenv",
      "MunifTanjim/nui.nvim",
      "kevinhwang91/promise-async",  -- Required dependency for async operations
    },
    cmd = { "Sail", "Artisan", "Composer", "Npm", "Yarn", "Laravel" },
    keys = {
      { "<leader>la", ":Laravel artisan<cr>", desc = "Laravel Artisan" },
      { "<leader>lr", ":Laravel routes<cr>", desc = "Laravel Routes" },
      { "<leader>lm", ":Laravel related<cr>", desc = "Laravel Related Files" },
    },
    event = { "VeryLazy" },
    config = function()
      require("laravel").setup({
        lsp_server = "intelephense",
        features = {
          null_ls = {
            enable = false,  -- Disable null-ls integration since we're not using it
          },
          route_info = {
            enable = true,
            position = "right",
          },
        },
      })
      
      -- Only load telescope extension if it exists
      local ok, telescope = pcall(require, "telescope")
      if ok then
        pcall(telescope.load_extension, "laravel")
      end
    end,
  },

  -- PHP Refactoring Tools
  {
    "phpactor/phpactor",
    ft = "php",
    build = "composer install --no-dev -o",
    config = function()
      vim.cmd([[
        augroup PhpactorMappings
          autocmd!
          autocmd FileType php nmap <buffer> <Leader>pm :PhpactorContextMenu<CR>
          autocmd FileType php nmap <buffer> <Leader>pn :PhpactorClassNew<CR>
          autocmd FileType php nmap <buffer> <Leader>pe :PhpactorClassInflect<CR>
          autocmd FileType php nmap <buffer> <Leader>pfm :PhpactorMoveFile<CR>
          autocmd FileType php nmap <buffer> <Leader>pfc :PhpactorCopyFile<CR>
          autocmd FileType php nmap <buffer> <Leader>pi :PhpactorImportClass<CR>
          autocmd FileType php nmap <buffer> <Leader>pe :PhpactorExtractExpression<CR>
          autocmd FileType php nmap <buffer> <Leader>pee :PhpactorExtractMethod<CR>
        augroup END
      ]])
    end,
  },

  -- PHP namespace handling
  {
    "arnaud-lb/vim-php-namespace",
    ft = "php",
    keys = {
      { "<Leader>pu", "<cmd>call PhpInsertUse()<CR>", desc = "PHP Insert Use" },
      { "<Leader>pe", "<cmd>call PhpExpandClass()<CR>", desc = "PHP Expand Class" },
    },
    config = function()
      vim.g.php_namespace_sort_after_insert = 1
    end,
  },
}