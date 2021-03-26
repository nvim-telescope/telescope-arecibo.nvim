local ts = vim.treesitter
local utils = require'telescope._extensions.arecibo.websearch.utils'

local M = {
  filter = {}
}

-- https://github.com/luvit/luvit/blob/master/deps/querystring.lua#L36-L43
local function decode_uri(str)
  str = string.gsub(str, '+', ' ')
  str = string.gsub(str, '%%(%x%x)', function(h)
    return string.char(tonumber(h, 16))
  end)
  str = string.gsub(str, '\r\n', '\n')

  return str
end

local function remove_google_amp(url)
  return url:gmatch('%/url%?q=(.-)%&amp;.*')()
end

local function get_node_text(lines, node)
  local start_line, start_col, end_line, end_col = node:range()
  local text = lines[start_line+1]
  if start_line ~= end_line then
    print("handle me")
  end
  return text:sub(start_col+1, end_col)
end

M.filter.google = function(document, ts_query)
  local parser = ts.get_string_parser(document, 'html')
  local query  = ts.parse_query('html', ts_query)
  local tree   = parser:parse()[1]

  -- query:iter_matches() requires us to have a `bufnr`, so create a temp buffer
  local scratch_bufnr = vim.api.nvim_create_buf(false, true)
  local response_tbl = {}
  for line in document:gmatch('[^\r\n]+') do
    table.insert(response_tbl, line)
  end
  vim.api.nvim_buf_set_lines(scratch_bufnr, 0, #response_tbl - 1, false, response_tbl)

  local results = {}
  local match_name, entry
  local idx = 0
  for _, match, _ in query:iter_matches(tree:root(), scratch_bufnr, 0, #response_tbl) do
    entry = {}
    for id, node in pairs(match) do
      match_name = query.captures[id]

      entry.title = match_name == 'title' and get_node_text(response_tbl, node) or entry.title
      entry.url   = match_name == 'url'   and remove_google_amp(get_node_text(response_tbl, node)) or entry.url
    end
    entry.title = utils.unescape_html(entry.title)

    idx = idx + 1
    entry.idx = idx
    table.insert(results, entry)
    --TODO: jump out of this loop when we have what we need
  end

  vim.api.nvim_buf_delete(scratch_bufnr, {force=true})

  return results
end

M.filter.duckduckgo = function(document, ts_query)
  local query  = ts.parse_query('html', ts_query)

  -- query:iter_matches() requires us to have a `bufnr`, so create a temp buffer
  local scratch_bufnr = vim.api.nvim_create_buf(false, true)
  local response_tbl = {}
  for line in document:gmatch('[^\r\n]+') do
    -- duckduckgo gave the title as bold
    -- ex. Home - <b>Neovim</b>
    -- remove the bold html tag to make parsing easier
    local no_bold = line:gsub('</?b>', {['<b>'] = '',['</b>'] = ''})
    table.insert(response_tbl, no_bold)
  end
  vim.api.nvim_buf_set_lines(scratch_bufnr, 0, #response_tbl-1, false, response_tbl)

  -- TODO: figure out why this won't work with `get_string_parser`
  local parser = ts.get_parser(scratch_bufnr, 'html')
  local tree   = parser:parse()[1]

  local entry, match_name, text
  local results = {}
  local idx = 0

  for _, match, _ in query:iter_matches(tree:root(), scratch_bufnr, 0, #response_tbl) do
    entry = {}
    for id, node in pairs(match) do
      text = get_node_text(response_tbl, node)
      match_name = query.captures[id]

      entry.url   = match_name == 'url' and decode_uri(text:gsub('//duckduckgo.com/l/%?uddg=', '')) or entry.url
      entry.title = match_name == 'title' and text:gsub('&amp;', '&'):gsub('&#x27;', "'") or entry.title
    end

    idx = idx + 1
    entry.idx = idx
    table.insert(results, entry)
  end

  vim.api.nvim_buf_delete(scratch_bufnr, {force=true})

  return results
end

-- TODO: this is just copypasta, need a way to handle this better
--       maybe provide a generic function which accepts some `transform` function
--       for each result or lines, like removing bold tag before putting it into
--       a table, resolve links, strip amp, decode URI, etc
M.filter.npmjs = function(document, ts_query)
  local query  = ts.parse_query('html', ts_query)

  -- query:iter_matches() requires us to have a `bufnr`, so create a temp buffer
  local scratch_bufnr = vim.api.nvim_create_buf(false, true)
  local response_tbl = {}
  for line in document:gmatch('[^\r\n]+') do
    table.insert(response_tbl, line)
  end
  vim.api.nvim_buf_set_lines(scratch_bufnr, 0, #response_tbl-1, false, response_tbl)

  -- TODO: figure out why this won't work with `get_string_parser`
  local parser = ts.get_parser(scratch_bufnr, 'html')
  local tree   = parser:parse()[1]

  local entry, match_name, text
  local results = {}
  local idx = 0

  for _, match, _ in query:iter_matches(tree:root(), scratch_bufnr, 0, #response_tbl) do
    entry = {}
    for id, node in pairs(match) do
      text = get_node_text(response_tbl, node)
      match_name = query.captures[id]

      entry.url   = match_name == 'url' and "https://npmjs.com"..text or entry.url
      entry.title = match_name == 'title' and text or entry.title
    end

    idx = idx + 1
    entry.idx = idx
    table.insert(results, entry)
  end

  vim.api.nvim_buf_delete(scratch_bufnr, {force=true})

  return results
end

return M
