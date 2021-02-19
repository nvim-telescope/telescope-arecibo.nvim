local uv = vim.loop
local util = {}

util.resolve_hostname = function(opts)
  local family = opts.ipv6 and "ipv6" or "inet"
  local res = uv.getaddrinfo(opts.host, opts.port, { socktype = "stream", family = family })

  return res[1].addr
end

util.get_time = function()
  local v = vim.fn
  return v.reltimefloat(v.reltime())
end

util.strip_html_tags = function(document, tags)
  for _, tagname in ipairs(tags) do
    document = document:gsub(('<%s.->.-</%s>'):format(tagname, tagname), '')
  end
  return document
end
-- util.read_file = function(path)
--   local fd = assert(vim.loop.fs_open(path, "r", 438))
--   local stat = assert(vim.loop.fs_fstat(fd))
--   local data = assert(vim.loop.fs_read(fd, stat.size, 0))
--   assert(vim.loop.fs_close(fd))
--   return data
-- end

util.highlight = function(group, styles)
  local gui = styles.gui  and "gui="   .. styles.gui or "gui=NONE"
  local sp  = styles.sp   and "guisp=" .. styles.sp  or "guisp=NONE"
  local fg  = styles.fg   and "guifg=" .. styles.fg  or "guifg=NONE"
  local bg  = styles.bg   and "guibg=" .. styles.bg  or "guibg=NONE"
  -- print('highlight! '..group..' '..gui..' '..sp..' '..fg..' '..bg)
  vim.api.nvim_command("highlight! " .. group .. " " .. gui .. " " .. sp .. " " .. fg .. " " .. bg)
end

--

local gsub = string.gsub
local entityMap  = {["lt"]="<",["gt"]=">",["amp"]="&",["quot"]='"',["apos"]="'"}

local entitySwap = function(orig,n,s)
  return (n=='' and entityMap[s]) or
    (n=="#" and tonumber(s)) and
    string.char(s) or (n=="#x" and tonumber(s,16)) and string.char(tonumber(s,16)) or orig
end

util.unescape_html = function(str)
  return (gsub( str, '(&(#?x?)([%d%a]+);)', entitySwap ))
end

return util


