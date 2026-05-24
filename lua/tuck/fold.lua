local M = {}

local config = require('tuck.config')

local query_cache = {}
local range_cache = {}
local warned = {}

local function warn_once(key, message)
  if warned[key] then
    return
  end
  warned[key] = true
  vim.notify(message, vim.log.levels.WARN)
end

local function get_lang(bufnr)
  local ft = vim.bo[bufnr].filetype
  return vim.treesitter.language.get_lang(ft) or ft
end

local function get_query(lang)
  if query_cache[lang] ~= nil then
    return query_cache[lang] or nil
  end

  local query_path = vim.api.nvim_get_runtime_file('queries/tuck/' .. lang .. '.scm', false)[1]
  if not query_path then
    query_cache[lang] = false
    return nil
  end

  local query_file = io.open(query_path, 'r')
  if not query_file then
    query_cache[lang] = false
    warn_once('open:' .. lang, 'Tuck: failed to open query file for ' .. lang)
    return nil
  end

  local query_text = query_file:read('*all')
  query_file:close()

  local ok, query = pcall(vim.treesitter.query.parse, lang, query_text)
  if not ok then
    query_cache[lang] = false
    warn_once('parse:' .. lang, 'Tuck: failed to parse query for ' .. lang .. ': ' .. tostring(query))
    return nil
  end

  local has_fold = false
  local has_owner = false
  for _, capture in ipairs(query.captures) do
    has_fold = has_fold or capture == 'fold'
    has_owner = has_owner or capture == 'owner'
  end

  if not has_fold or not has_owner then
    query_cache[lang] = false
    warn_once('captures:' .. lang, 'Tuck: query for ' .. lang .. ' must capture both @owner and @fold')
    return nil
  end

  query_cache[lang] = query
  return query
end

local function has_query(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lang = get_lang(bufnr)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not ok or not parser then
    return false
  end
  return get_query(lang) ~= nil
end

local function first_node(nodes)
  if type(nodes) == 'table' then
    return nodes[1]
  end
  return nodes
end

local function node_range(node)
  local start_row, _, end_row, _ = node:range()
  return start_row + 1, end_row + 1
end

local function normalize_ranges(fold_ranges)
  local seen = {}
  local normalized = {}

  for _, range in ipairs(fold_ranges) do
    local key = table.concat({
      range.start_line,
      range.end_line,
      range.body_start_line,
      range.owner_start_line,
      range.owner_end_line,
      range.kind,
    }, ':')

    if not seen[key] then
      seen[key] = true
      table.insert(normalized, range)
    end
  end

  table.sort(normalized, function(a, b)
    if a.start_line == b.start_line then
      return a.end_line < b.end_line
    end
    return a.start_line < b.start_line
  end)

  return normalized
end

local function get_fold_ranges(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if config.is_excluded(bufnr) then
    return {}
  end

  local changedtick = vim.b[bufnr].changedtick
  local cached = range_cache[bufnr]
  if cached and cached.changedtick == changedtick then
    return cached.ranges
  end

  local lang = get_lang(bufnr)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not ok or not parser then
    range_cache[bufnr] = { changedtick = changedtick, ranges = {} }
    return {}
  end

  local query = get_query(lang)
  if not query then
    range_cache[bufnr] = { changedtick = changedtick, ranges = {} }
    return {}
  end

  local tree = parser:parse()[1]
  if not tree then
    range_cache[bufnr] = { changedtick = changedtick, ranges = {} }
    return {}
  end

  local fold_ranges = {}
  for _, match, _ in query:iter_matches(tree:root(), bufnr, 0, -1) do
    local owner
    local fold

    for id, nodes in pairs(match) do
      local name = query.captures[id]
      if name == 'owner' then
        owner = first_node(nodes)
      elseif name == 'fold' then
        fold = first_node(nodes)
      end
    end

    if owner and fold then
      local owner_start_line, owner_end_line = node_range(owner)
      local body_start_line, end_line = node_range(fold)
      if end_line > owner_start_line then
        table.insert(fold_ranges, {
          start_line = owner_start_line,
          end_line = end_line,
          body_start_line = body_start_line,
          kind = 'body',
          owner_start_line = owner_start_line,
          owner_end_line = owner_end_line,
          trigger_start_line = owner_start_line,
          trigger_end_line = body_start_line,
        })
      end
    else
      warn_once('match:' .. lang, 'Tuck: query for ' .. lang .. ' produced a match without @owner and @fold')
    end
  end

  fold_ranges = normalize_ranges(fold_ranges)
  range_cache[bufnr] = { changedtick = changedtick, ranges = fold_ranges }
  return fold_ranges
end

local function debug_ranges(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  local lang = get_lang(bufnr)

  print('Buffer: ' .. bufnr)
  print('Filetype: ' .. ft)
  print('Language: ' .. lang)

  local query_path = vim.api.nvim_get_runtime_file('queries/tuck/' .. lang .. '.scm', false)[1]
  if query_path then
    print('Query file: ' .. query_path)
  else
    print('Query file: NOT FOUND')
    print('  Searched for: queries/tuck/' .. lang .. '.scm')
    return false
  end

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not ok then
    print('Parser: FAILED - ' .. tostring(parser))
    return false
  end
  if not parser then
    print('Parser: NIL')
    return false
  end
  print('Parser: OK')

  local query = get_query(lang)
  if not query then
    print('Query: FAILED')
    return false
  end
  print('Query: OK')

  local tree = parser:parse()[1]
  if not tree then
    print('Tree: NIL')
    return false
  end
  print('Tree: OK')

  return true
end

function M.foldexpr(lnum)
  local bufnr = vim.api.nvim_get_current_buf()

  for _, range in ipairs(get_fold_ranges(bufnr)) do
    if lnum == range.start_line then
      return '>1'
    elseif lnum > range.start_line and lnum <= range.end_line then
      return '1'
    end
  end

  return '0'
end

function M.invalidate_cache(bufnr)
  range_cache[bufnr or vim.api.nvim_get_current_buf()] = nil
end

function M.apply_folds(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not config.options.manage_folds then
    return
  end

  if config.is_excluded(bufnr) or not has_query(bufnr) then
    return
  end

  M.invalidate_cache(bufnr)

  vim.wo.foldmethod = 'expr'
  vim.wo.foldexpr = "v:lua.require'tuck.fold'.foldexpr(v:lnum)"
  vim.wo.foldenable = true

  if vim.b[bufnr].tuck_initialized then
    return
  end
  vim.b[bufnr].tuck_initialized = true

  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_get_current_buf() == bufnr then
      vim.wo.foldlevel = 0
      vim.cmd('silent! normal! zM')
    end
  end)
end

function M.reset_folds(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  M.invalidate_cache(bufnr)
  vim.b[bufnr].tuck_initialized = nil

  if not config.options.manage_folds then
    return
  end

  vim.wo.foldmethod = 'manual'
  vim.wo.foldexpr = ''
  vim.wo.foldenable = false
  vim.cmd('silent! normal! zR')
end

function M.refold(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  M.invalidate_cache(bufnr)

  if not config.options.manage_folds then
    local ufo = package.loaded.ufo
    if ufo and type(ufo.closeFoldsWith) == 'function' then
      local ok = pcall(ufo.closeFoldsWith, 0)
      if ok then
        return
      end
    end
    vim.notify('Tuck: fold management is disabled; close folds with your fold backend', vim.log.levels.WARN)
    return
  end

  vim.b[bufnr].tuck_initialized = nil
  vim.cmd('silent! normal! zM')
  vim.b[bufnr].tuck_initialized = true
end

function M.unfold_at_cursor()
  pcall(vim.cmd, 'silent! normal! zv')

  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  for _, range in ipairs(get_fold_ranges(bufnr)) do
    if cursor_line >= range.trigger_start_line and cursor_line <= range.trigger_end_line then
      pcall(vim.cmd, 'silent! ' .. range.start_line .. 'foldopen!')
      return
    end
  end
end

function M.ufo_provider(bufnr)
  local folds = {}

  for _, range in ipairs(get_fold_ranges(bufnr)) do
    table.insert(folds, {
      startLine = range.start_line - 1,
      endLine = range.end_line - 1,
      kind = range.kind,
    })
  end

  return folds
end

function M.get_ranges(bufnr)
  return get_fold_ranges(bufnr)
end

function M.debug(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  print('=== Tuck Debug ===')
  print('Enabled: ' .. tostring(config.options.enabled))
  print('Manage folds: ' .. tostring(config.options.manage_folds))
  debug_ranges(bufnr)

  local fold_ranges = get_fold_ranges(bufnr)
  print('Fold ranges found: ' .. #fold_ranges)
  for i, range in ipairs(fold_ranges) do
    print(
      '  '
        .. i
        .. ': body '
        .. range.body_start_line
        .. '-'
        .. range.end_line
        .. ', owner '
        .. range.owner_start_line
        .. '-'
        .. range.owner_end_line
    )
  end

  print('=== End Debug ===')
end

return M
