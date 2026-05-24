local M = {}

local patched = false
local replacement_map = nil
local original_edit = nil
local original_replacements = nil

local function schedule_unfold()
  local config = require('tuck.config')
  if not config.options.enabled or not config.options.navigation_unfold then
    return
  end

  vim.defer_fn(function()
    require('tuck.fold').unfold_at_cursor()
  end, config.options.unfold_delay)
end

local function run_original_edit(prompt_bufnr, command)
  for _, replacements in ipairs(original_replacements or {}) do
    for condition, replacement in pairs(replacements) do
      if condition == true or condition(prompt_bufnr, command) then
        return replacement(prompt_bufnr, command)
      end
    end
  end

  return original_edit(prompt_bufnr, command)
end

function M.is_patched()
  return patched
end

function M.setup()
  if patched then
    return
  end

  local action_set_ok, action_set = pcall(require, 'telescope.actions.set')
  if not action_set_ok then
    vim.notify('Tuck: telescope.nvim not found, skipping integration', vim.log.levels.WARN)
    return
  end

  original_edit = action_set.edit._func.edit
  original_replacements = vim.list_extend({}, action_set.edit._replacements.edit or {})

  replacement_map = {
    [true] = function(prompt_bufnr, command)
      local result = run_original_edit(prompt_bufnr, command)
      schedule_unfold()
      return result
    end,
  }

  action_set.edit:replace_map(replacement_map)
  patched = true
end

function M.restore()
  if not patched then
    return
  end

  local action_set_ok, action_set = pcall(require, 'telescope.actions.set')
  if action_set_ok and replacement_map then
    local replacements = action_set.edit._replacements.edit or {}
    for i, map in ipairs(replacements) do
      if map == replacement_map then
        table.remove(replacements, i)
        break
      end
    end
  end

  patched = false
  replacement_map = nil
  original_edit = nil
  original_replacements = nil
end

function M.debug()
  print('=== Tuck telescope.nvim Integration Debug ===')
  print('Patched: ' .. tostring(patched))

  local action_set_ok, action_set = pcall(require, 'telescope.actions.set')
  if not action_set_ok then
    print('telescope.actions.set: NOT FOUND')
  else
    print('telescope.actions.set: loaded')
    local replacements = action_set.edit._replacements.edit or {}
    local is_wrapped = false
    for _, map in ipairs(replacements) do
      if map == replacement_map then
        is_wrapped = true
        break
      end
    end
    print('edit action wrapped: ' .. tostring(is_wrapped))
  end

  print('')
  print('=== End Debug ===')
end

return M
