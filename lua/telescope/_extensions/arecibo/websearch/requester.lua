-- TODO: look into using lua-resty-openssl for HTTP2
-- https://github.com/fffonion/lua-resty-openssl/blob/master/examples/tls-alpn-01.lua

-- TODO: set more `var = opt.param or default` in functions

-- local engines      = require'telescope._extensions.arecibo.websearch.engines'
local https_client = require'telescope._extensions.arecibo.websearch.http_client'
local utils        = require'telescope._extensions.arecibo.websearch.utils'
local treesitter   = require'telescope._extensions.arecibo.websearch.treesitter'


local POLL_TIME = 10 --ms
local DEFAULT_USERAGENT = 'Mozilla/4.0 (compatible; MSIE5.01; Windows NT)'

local co_state = {
  RUNNING   = 'running',
  SUSPENDED = 'suspended',
  DEAD      = 'dead'
}

--

local function generate_headers(params)
  local protocol = 'HTTP/1.1'
  local headers = (params.query_template .. ' %s\n'):format(params.query, protocol)

  local header_items = {
    {'Host', params.host},
    {'user-agent', DEFAULT_USERAGENT},
    {'accept', '*/*'}
    -- {'Connection', 'Keep-Alive'}
    -- accept-encoding: gzip
  }

  for _, v in ipairs(header_items) do
    headers = headers .. ('%s: %s\n'):format(v[1], v[2])
  end

  return headers
end

--

local M = {}

function M:new(engine, verbose)
  -- print(vim.inspect(engines))
  -- if not engines[engine] then
  --   print("invalid engine.")
  --   return
  -- end

  local o = {}
  setmetatable(o, self)
  self.__index = self

  self.engine = engine
  self.verbose = verbose or false

  return o
end

function M:search(query_text, response_callback) -- dorequest should take a callback
  if not self.engine then return end
  -- TODO: validate query and escape/substitute query
  self.start_time = nil
  self.response   = nil
  local headers = generate_headers {
    query          = query_text:gsub('%s+', "+"),
    query_template = self.engine.query_template,
    host           = self.engine.host,
  }

  local client
  self.start_time = utils.get_time()
  client = https_client.connect {
    -- TODO: cache dns response
    host = utils.resolve_hostname {host=self.engine.host, port=self.engine.port}, -- TODO: bring resolve_hostname back into this class
    port = self.engine.port,
    on_connect = function()
      -- print("Connected:")
      -- TODO: upgrade connection to HTTP/2
      client:get(headers)
    end,
    on_complete = function(response)
      self.response = utils.strip_html_tags(response, {'script', 'style'})
    end,
    verbose = self.verbose
  }

  -- TODO: check connection is okay, stop timer if it isn't
  local wait_response = coroutine.create(function()
    while not self.response do coroutine.yield() end
  end)


  -- TODO: response_poller should be a single instance for multiple ongoing/queue requests
  -- Note: Polling timer to avoid errors when trying to do any of this in a callback
  self.response_poller = vim.loop.new_timer()
  self.response_poller:start(POLL_TIME, POLL_TIME, vim.schedule_wrap(function()
    if coroutine.status(wait_response) == co_state.SUSPENDED then
      coroutine.resume(wait_response)
    else
      self.response_poller:stop()
      self.response_poller:close()
      self.response_poller = nil

      local document_bytes = #self.response
      local search_results = treesitter.filter[self.engine.name:lower()](self.response, self.engine.ts_query)
      local response_time = utils.get_time() - self.start_time

      print(('request complete. %d bytes in %0.4f seconds [%d KB/s].'):format(document_bytes, response_time, document_bytes/response_time))

      response_callback(search_results)
    end
  end))
end

return M
