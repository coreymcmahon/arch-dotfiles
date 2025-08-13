return {
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    config = function()
      require("mason").setup({
        ui = { border = "rounded" },
      })
    end,
  },

  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "neovim/nvim-lspconfig", "hrsh7th/cmp-nvim-lsp" },
    config = function()
      local servers = {
        -- PHP
        "intelephense",
        -- Web/JS/TS
        "html",
        "cssls",
        "ts_ls",    -- typescript-language-server
        "eslint",   -- eslint-lsp
        "jsonls",
        "yamlls",
        -- Shell + Lua
        "bashls",
        "lua_ls",
      }

      require("mason-lspconfig").setup({
        ensure_installed = servers,
        automatic_installation = true,
      })

      local lspconfig = require("lspconfig")
      local caps = require("cmp_nvim_lsp").default_capabilities()

      -- generic
      local function setup(name, opts)
        opts = opts or {}
        opts.capabilities = vim.tbl_deep_extend("force", {}, caps, opts.capabilities or {})
        lspconfig[name].setup(opts)
      end

      -- Lua
      setup("lua_ls", {
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
          },
        },
      })

      -- PHP
      setup("intelephense", {
        settings = {
          intelephense = {
            files = { maxSize = 10 * 1024 * 1024 },
            telemetry = { enabled = false },
          },
        },
      })

      -- TypeScript/JavaScript
      -- Disable tsserver formatting so Prettier/Biome or eslint --fix can own it.
      setup("ts_ls", {
        single_file_support = true,
        on_attach = function(client, _)
          client.server_capabilities.documentFormattingProvider = false
          client.server_capabilities.documentRangeFormattingProvider = false
        end,
        settings = {
          javascript = { inlayHints = { includeInlayParameterNameHints = "all" } },
          typescript  = { inlayHints = { includeInlayParameterNameHints = "all" } },
        },
      })

      -- ESLint LSP (diagnostics + codeActions). Keep formatting off here too.
      setup("eslint", {
        settings = {
          -- Let your editor formatter (conform/biome/prettier) handle formatting
          format = false,
          workingDirectory = { mode = "auto" },
        },
      })

      -- The rest
      for _, s in ipairs({ "html", "cssls", "jsonls", "yamlls", "bashls" }) do
        setup(s)
      end
    end,
  },

  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    config = function()
      require("mason-tool-installer").setup({
        ensure_installed = {
          -- PHP
          "phpcs", "phpcbf", "phpstan", "pint",
          -- JS/TS formatters (pick one stack)
          "prettier",      -- classic Prettier CLI
          "eslint_d",      -- fast eslint fixer for conform/nvim-lint
          -- OR use Biome instead of both Prettier + eslint_d:
          -- "biome",
          -- Shell
          "shfmt", "shellcheck",
        },
        run_on_start = true,
      })
    end,
  },
}

