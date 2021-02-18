local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  error("This plugin requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

-- TODO: show query text as dimmed while search is in progres, then reset prompt on search_complete

local actions       = require'telescope.actions'
local entry_display = require'telescope.pickers.entry_display'
local finders       = require'telescope.finders'
local pickers       = require'telescope.pickers'
local previewers    = require'telescope.previewers'
local putils        = require'telescope.previewers.utils'
local sorters       = require'telescope.sorters'

local arecibo_utils   = require'telescope._extensions.arecibo.websearch.utils'
local misc            = require'telescope._extensions.arecibo.websearch.misc'
local engines         = require'telescope._extensions.arecibo.websearch.engines'
-- local selected_engine = engines.google
--

local domain_icons = misc.domain_icons
local spinner_anim_frames = misc.anim_frames

local state = {}

local function set_config_state(opt_name, value, default)
  state[opt_name] = value == nil and default or value
end

-- TODO: make this an init function
local idx = 1
for domain, style in pairs(domain_icons) do
  arecibo_utils.highlight('Arecibo_' .. idx, {fg=style.hl})
  domain_icons[domain].hl_idx = idx
  idx = idx + 1
end
vim.cmd[[ hi! AreciboNumber guifg=#74a976]]

local display_widths = {
  { width = 3 }, -- index column
  { width = 65 },
  { remaining = true }
}

local displayer = entry_display.create {
  items = display_widths,
  separator = "",
}

-- local make_ordinal = function(entry)
--   return
-- end

local make_display = function(entry)
  local display_items = {
    { entry.result_idx, 'AreciboNumber' },
    entry.name,
    { entry.value, "comment" }
  }

  if state.show_domain_icons then
    table.insert(display_items, 2, { entry.icon, entry.icon_hl_group })
    if not state.regenerated_displayer then
      table.insert(display_widths, 2, { width = 4 })
      displayer = entry_display.create {
        items = display_widths,
        separator = "",
      }
      state.regenerated_displayer = true
    end
  end

  return displayer(display_items)
end

local function get_domain_icon(domain)
  local default_icon = '… '
  return domain_icons[domain] and domain_icons[domain].icon or default_icon
end

local function get_domain_hl_group(domain)
  local hl_idx = domain_icons[domain] and domain_icons[domain].hl_idx
  return hl_idx and 'Arecibo_' ..hl_idx or 'Comment'
end

local entry_maker = function(entry)
  local domain = entry.url:match('^%w+://([^/]+)')
  domain = domain and domain:gsub('^www%.', '')
  return {
    display       = make_display,
    name          = entry.title,
    icon          = get_domain_icon(domain),
    icon_hl_group = get_domain_hl_group(domain),
    result_idx    = entry.idx,
    value         = entry.url,
    ordinal       = entry.idx .. ' ' .. entry.title .. ' ' .. entry.url,
  }
end

local current_frame = 0 -- TODO: reset this at search start and make a state.var
local function in_progress_animation()
  current_frame = current_frame >= #spinner_anim_frames and 1 or current_frame + 1
  state.picker:change_prompt_prefix(spinner_anim_frames[current_frame])
  state.picker:reset_prompt()
end

local function create_previewer()
  return previewers.new_buffer_previewer {
    get_buffer_by_name = function(_, entry)
      return entry.value
    end,
    define_preview = function(self, entry, status)
      putils.job_maker({ 'elinks', '-dump', '-no-numbering', '-dump-color-mode', '1',  entry.value }, self.state.bufnr, {
      value = entry.value,
      bufname = self.state.bufname,
      conv = true,
      })
    end
  }
end

local function set_prompt_hl(hl_group)
  state.picker:change_prompt_prefix(
    state.original_prompt_prefix,
    hl_group
  )
end

-- clear current results and reset prompt
local function reset_search(show_prompt_text)
  state.results = show_prompt_text == nil  and {} or state.search_prompt_message
  local new_finder = finders.new_table {
    results     = state.results,
    entry_maker = entry_maker
  }
  vim.cmd[[echo]]
  actions.refresh(
    state.picker.prompt_bufnr,
    new_finder,
    {reset_prompt=true}
  )
  set_prompt_hl('TelescopeAreciboPrompt')
end

local function on_search_result(response)

  vim.fn.timer_stop(state.anim_timer)
  state.anim_timer = nil

  --update results
  local new_finder = finders.new_table {
    results     = response,
    entry_maker = entry_maker
  }
  actions.refresh(
    state.picker.prompt_bufnr,
    new_finder,
    {
      reset_prompt = true,
      new_prefix = state.original_prompt_prefix
    }
  )
end

local function do_search()
  local query_text = vim.fn.trim(vim.fn.getline('.'):gsub(state.original_prompt_prefix, ''))
  if query_text == '' then return end

  reset_search()

  -- start in-progress animation
  if not state.anim_timer then
    state.anim_timer = vim.fn.timer_start(80, in_progress_animation, {['repeat'] = -1})
  end

  -- perform search
  state.requester:search(query_text, on_search_result)
end

local function search_or_select(_)
  local current_results = state.picker.finder.results
  if #current_results == 1 and not current_results[1].valid then
    do_search()
  else
    local selection = actions.get_selected_entry()
    os.execute(state.open_command .. ' "' .. selection.value..'"')
  end
end


local websearch = function(opts)
  opts = opts or {}

  state.requester = require'telescope._extensions.arecibo.websearch.requester':new(state.selected_engine, state.show_http_messages)
  -- TODO: put selected_engine.name in first column
  state.search_prompt_message = {{
    title=('[%s] Enter search query'):format(state.selected_engine.name),
    url='',
    idx='',
    valid=false
  }}

  state.picker = pickers.new(opts, {
    prompt_title = "Arecibo Web Search",
    finder = finders.new_table {
      results = state.search_prompt_message,
      entry_maker = entry_maker
    },
    previewer = create_previewer(),
    sorter = sorters.get_substr_matcher(opts),
    attach_mappings = function(_, map)
      actions.goto_file_selection_edit:replace(search_or_select)
      map('i', '<C-l>', reset_search)
      return true
    end
  })
  state.original_prompt_prefix = state.picker.prompt_prefix -- TODO: only do this once
  state.picker:find()
  set_prompt_hl('TelescopeAreciboPrompt')
end


return telescope.register_extension {
  setup = function(ext_config)
    set_config_state('selected_engine',     engines[ext_config.selected_engine], engines.google)
    set_config_state('open_command',        ext_config.url_open_command, 'xdg-open')
    set_config_state('show_domain_icons',   ext_config.show_domain_icons, false)
    set_config_state('show_http_messages',  ext_config.show_http_messages, false)
  end,
  exports = {
    websearch = websearch,
  },
}

