local M = {}

M.defaults = {
  enabled = true,
  manage_folds = true,
  auto_unfold = true,
  navigation_unfold = true,
  unfold_delay = 50,
  exclude_filetypes = {},
  exclude_paths = {},
  integrations = {
    fzf_lua = false,
    gitsigns = false,
    telescope = false,
  },
}

M.options = vim.deepcopy(M.defaults)

--- Merge user options with defaults.
function M.setup(opts)
  M.options = vim.tbl_deep_extend('force', {}, M.defaults, opts or {})
end

--- Check whether the buffer should be excluded.
function M.is_excluded(bufnr)
  bufnr = bufnr or 0
  local ft = vim.bo[bufnr].filetype
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  for _, excluded_ft in ipairs(M.options.exclude_filetypes) do
    if ft == excluded_ft then
      return true
    end
  end

  for _, pattern in ipairs(M.options.exclude_paths) do
    if vim.fn.match(filepath, vim.fn.glob2regpat(pattern)) >= 0 then
      return true
    end
  end

  return false
end

return M
