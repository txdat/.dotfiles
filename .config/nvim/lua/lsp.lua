-- prevent LSP from overwriting treesitter color setting (< 100)
vim.highlight.priorities.semantic_tokens = 0

vim.diagnostic.config({
    update_in_insert = true,
    underline = false,
    severity_sort = true,
    signs = {
        severity = { min = vim.diagnostic.severity.ERROR },
        text = {
          [vim.diagnostic.severity.ERROR] = " ",
          [vim.diagnostic.severity.WARN]  = " ",
          [vim.diagnostic.severity.INFO]  = " ",
          [vim.diagnostic.severity.HINT]  = " ",
        },
        linehl = {
          -- [vim.diagnostic.severity.ERROR] = "Error",
          -- [vim.diagnostic.severity.WARN]  = "Warn",
          -- [vim.diagnostic.severity.INFO]  = "Info",
          -- [vim.diagnostic.severity.HINT]  = "Hint",
        },
    },
    virtual_text = {
        severity = { min = vim.diagnostic.severity.ERROR },
        spacing = 5,
    },
    float = {
        severity = { min = vim.diagnostic.severity.ERROR },
        border = "none",
    },
})

-- lsp servers config
local keymap = require("util").keymap
local merge_tables = require("util").merge_tables

vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
        local buf = vim.lsp.buf
        local diag = vim.diagnostic
        local opts = { buffer = args.buf }

        keymap("n", "gk", buf.hover, opts)
        keymap("n", "gn", buf.rename, opts)
        keymap("n", "gd", buf.definition, opts)
        -- keymap("n", "gc", buf.declaration, opts)
        keymap("n", "gt", buf.type_definition, opts)
        keymap("n", "gs", buf.signature_help, opts)
        keymap("n", "gi", buf.implementation, opts)
        keymap("n", "gr", buf.references, opts)
        keymap("n", "ga", buf.code_action, opts)
        -- keymap("n", "gf", diag.open_float, opts)
        -- keymap("n", "[d", diag.goto_prev, opts)
        -- keymap("n", "]d", diag.goto_next, opts)
        keymap("n", "[e", function()
            diag.goto_prev({ severity = diag.severity.ERROR })
        end, opts)
        keymap("n", "]e", function()
            diag.goto_next({ severity = diag.severity.ERROR })
        end, opts)
    end
})

-- https://github.com/hrsh7th/cmp-nvim-lsp/blob/main/lua/cmp_nvim_lsp/init.lua
local capabilities = {
  textDocument = {
    completion = {
      dynamicRegistration = false,
      completionItem = {
        snippetSupport = true,
        commitCharactersSupport = true,
        deprecatedSupport = true,
        preselectSupport = true,
        tagSupport = {
          valueSet = {
            1, -- Deprecated
          }
        },
        insertReplaceSupport = true,
        resolveSupport = {
            properties = {
                "documentation",
                "additionalTextEdits",
                "insertTextFormat",
                "insertTextMode",
                "command",
            },
        },
        insertTextModeSupport = {
          valueSet = {
            1, -- asIs
            2, -- adjustIndentation
          }
        },
        labelDetailsSupport = true,
      },
      contextSupport = true,
      insertTextMode = 1,
      completionList = {
        itemDefaults = {
          'commitCharacters',
          'editRange',
          'insertTextFormat',
          'insertTextMode',
          'data',
        }
      }
    },
  },
  workspace = {
    didChangeWatchedFiles = {
      dynamicRegistration = true
    }
  }
}

vim.lsp.config("clangd", {
  cmd = {
    "clangd",
    "-log=error",
    "--limit-results=500",
    "--background-index",
    "--clang-tidy",
    "--header-insertion=iwyu",
    "--completion-style=detailed",
    "--function-arg-placeholders",
    "--fallback-style=llvm"
  },
  filetypes = { 'c', 'cpp', 'cuda', 'proto' },
  root_markers = { 'compile_commands.json', 'compile_flags.txt', '.clangd', 'CMakeLists.txt', '.git' },
  capabilities = merge_tables(
    {
      textDocument = {
        completion = {
          editsNearCursor = true,
        },
      },
      offsetEncoding = { 'utf-8', 'utf-16' },
    },
    capabilities
  ),
})

vim.lsp.config("rust_analyzer", {
  cmd = { 'rust-analyzer' },
  filetypes = { 'rust' },
  root_markers = { 'Cargo.toml', '.git' },
  settings = {
    ['rust-analyzer'] = {
      imports = {
          granularity = {
              group = "module",
          },
          prefix = "self",
      },
      cargo = {
          buildScripts = {
              enable = true,
          },
      },
      procMacro = {
          enable = true
      },
    },
  },
  capabilities = merge_tables(
    {
      experimental = {
        serverStatusNotification = true,
      },
    },
    capabilities
  ),
})

vim.lsp.config("gopls", {
  cmd = { 'gopls' },
  filetypes = { 'go', 'gomod', 'gowork' },
  root_markers = { 'go.mod', 'go.work', '.git' },
  capabilities = capabilities,
})

vim.lsp.config("pyright", {
  cmd = { 'pyright-langserver', '--stdio' },
  filetypes = { 'python' },
  root_markers = { 'pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt', '.git' },
  settings = {
    python = {
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = 'openFilesOnly',
      },
    },
  },
  capabilities = capabilities,
})

vim.lsp.config("vtsls", {
  cmd = { 'vtsls', '--stdio' },
  filetypes = {
    'javascript',
    'javascriptreact',
    'typescript',
    'typescriptreact',
  },
  root_markers = { 'tsconfig.json', 'jsconfig.json', 'package.json', '.git' },
  capabilities = capabilities,
})

vim.lsp.config("eslint", {
  cmd = { 'vscode-eslint-language-server', '--stdio' },
  filetypes = {
    'javascript',
    'javascriptreact',
    'typescript',
    'typescriptreact',
  },
  root_markers = { 'package.json', '.eslintrc', '.eslintrc.js', '.eslintrc.cjs', '.eslintrc.json', 'eslint.config.js', 'eslint.config.mjs', '.git' },
  workspace_required = true,
  settings = {
    validate = 'on',
    packageManager = nil,
    useESLintClass = false,
    experimental = {
      useFlatConfig = false,
    },
    codeActionOnSave = {
      enable = false,
      mode = 'all',
    },
    format = true,
    quiet = false,
    onIgnoredFiles = 'off',
    rulesCustomizations = {},
    run = 'onType',
    problems = {
      shortenToSingleLine = false,
    },
    nodePath = '',
    workingDirectory = { mode = 'auto' },
    codeAction = {
      disableRuleComment = {
        enable = true,
        location = 'separateLine',
      },
      showDocumentation = {
        enable = true,
      },
    },
  },
  capabilities = capabilities,
})

vim.lsp.enable({
  "clangd",
  "rust_analyzer",
  "gopls",
  "pyright",
  "vtsls",
  "eslint",
})
