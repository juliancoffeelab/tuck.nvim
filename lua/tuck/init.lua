local M = {}

local config = require('tuck.config')
local fold = require('tuck.fold')

local augroup = vim.api.nvim_create_augroup('Tuck', { clear = true })
local last_line = nil

local lsp_navigation_methods = {
  ['textDocument/definition'] = true,
  ['textDocument/declaration'] = true,
  ['textDocument/typeDefinition'] = true,
  ['textDocument/implementation'] = true,
  ['textDocument/references'] = true,
}

local function setup_autocmds()
  vim.api.nvim_clear_autocmds({ group = augroup })

  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = augroup,
    callback = function(args)
      if config.options.enabled then
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(args.buf) then
            fold.apply_folds(args.buf)
          end
        end)
      end
    end,
  })

  vim.api.nvim_create_autocmd('LspRequest', {
    group = augroup,
    callback = function(args)
      if not config.options.enabled then
        return
      end
      local request = args.data and args.data.request
      if request and lsp_navigation_methods[request.method] then
        vim.defer_fn(function()
          fold.unfold_at_cursor()
        end, 50)
      end
    end,
  })

  vim.api.nvim_create_autocmd('TextChanged', {
    group = augroup,
    callback = function(args)
      fold.invalidate_cache(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd('CursorMoved', {
    group = augroup,
    callback = function()
      if not config.options.enabled or not config.options.auto_unfold then
        return
      end
      local line = vim.fn.line('.')
      if line ~= last_line then
        last_line = line
        if vim.fn.foldclosed('.') ~= -1 then
          vim.cmd('silent! foldopen')
        end
      end
    end,
  })
end

local function setup_integrations()
  if config.options.integrations.fzf_lua then
    require('tuck.integrations.fzf_lua').setup()
  end
end

function M.setup(opts)
  config.setup(opts)
  setup_autocmds()
  setup_integrations()

  if config.options.enabled then
    local bufnr = vim.api.nvim_get_current_buf()
    if vim.bo[bufnr].filetype ~= '' then
      fold.apply_folds(bufnr)
    end
  end
end

function M.enable()
  config.options.enabled = true
  setup_autocmds()
  fold.apply_folds()
  vim.notify('Tuck enabled', vim.log.levels.INFO)
end

function M.disable()
  config.options.enabled = false
  vim.api.nvim_clear_autocmds({ group = augroup })
  fold.reset_folds()

  if config.options.integrations.fzf_lua then
    require('tuck.integrations.fzf_lua').restore()
  end

  vim.notify('Tuck disabled', vim.log.levels.INFO)
end

function M.toggle()
  if config.options.enabled then
    M.disable()
  else
    M.enable()
  end
end

return M
