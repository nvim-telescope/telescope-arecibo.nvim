local ts = vim.treesitter
local utils = require'telescope._extensions.arecibo.websearch.utils'

local M = {}

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

M.filter = function(document, ts_query)
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

return M
