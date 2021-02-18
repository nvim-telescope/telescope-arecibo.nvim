local http_parser
do
  local ok
  ok, http_parser = pcall(require, 'http.parser')
  if not ok then
    error 'Could not find lua package "http.parser". Install it from luarocks with Packer.'
  end
end
local uv_sslctx   = require'telescope._extensions.arecibo.websearch.sslctx'

local debug = false -- enable to see all traffic

local DEFAULT_CIPHERS = 'ECDHE-RSA-AES128-SHA256:AES128-GCM-SHA256:' ..   -- TLS 1.2
                        '!RC4:HIGH:!MD5:!aNULL:!EDH'                      -- TLS 1.0
local Client = {}
local Client_mt = {}

local function log(...)
  if debug then
    return print(...)
  end
end

local body = {}
local body_count = 0
local on_complete_callback = nil

local parser = http_parser.response {
  -- on_url          = function(url)  ... end
  on_header       = function(hkey, hval)
    log("< [" .. hkey .. "] : " .. hval)
    body = {}
    body_count = 0
   end,

  on_status = function(code, msg)
    log("< Status : " .. code .. " - " .. msg)
  end,
  -- on_message_begin = function() print("msg_begin") end,
  on_body = function(chunk)
    if chunk == nil then
      -- print("Response complete.")
      if on_complete_callback then
        on_complete_callback(table.concat(body))
      end
    end
    body[#body+1] = chunk
    body_count = body_count + 1
    end,

  on_message_complete = function()
    -- print("COMPLETIO")
  end,
  -- on_headers_complete = function() ... end

  on_chunk_header = function(content_length)
    -- print("Chunk Start: " .. content_length)
  end
  -- on_chunk_complete = function() ... end
}

-- TODO: pehaps this shouldn't have an on_complete_cb and that should be in the `request` func
-- TODO: change this to a `request` function that re-uses connection?
function Client.connect(args)
  -- host, port, on_connect_cb, on_complete_cb
  local params = {
    protocol = "TLS",
    ciphers  = DEFAULT_CIPHERS,
    mode     = 'client',
    -- cafile   = './cacert.pem',
    -- cafile   = '/etc/ssl/certs/ca-certificates.crt',
    -- cafile   = '~/xenia.gif',
    -- verify   = {"peer", "fail_if_no_peer_cert"},
    -- verify = ssl.peer + ssl.fail,
    -- verify = ssl.fail,
    -- options = {"all", "no_sslv2"}
  }

  debug = args.verbose

  local ctx = assert(uv_sslctx.new_ctx(params))

  -- ctx:timeout(0)
  -- print("Timeout: " ..ctx:timeout())

  local cli = assert(uv_sslctx.connect(args.host, args.port, ctx, args.on_connect))

  on_complete_callback = args.on_complete

  function cli:ondata(chunk)
    if not chunk then return end
    local parsed_bytes = parser:execute(chunk)
    -- print('bytes parsed: ' .. parsed_bytes .. " : " .. os.clock())
    -- print("-------")
  end

  function cli:onerror(err)
    log("Socket error" .. (err or "?"))
    -- TODO: call socket:error() to get last error
  end

  function cli:onend()
    -- print("TADA!")
    self:close()
  end

  function cli:onclose()
    log("Socket closed")
  end
  -- print("Cipher: ")
  -- print(vim.inspect(ctx:on_complete_cipher()))
  -- print("state: ")
  -- print(vim.inspect(ssl_socket:get('state_string')))
  -- local verified, verified_info = ssl_socket:getpeerverification()

  -- print("verified_peer: " ..(tostring(verified) or "b?"))
  -- returns:
  -- boolean true for success
  -- table all certificate in chains verify result preverify_ok as boolean verify result error as number error code error_string as string error message error_depth as number verify depth on_complete_cert as x509 certificate to verified

  return setmetatable({
    client = cli,
    id = 1
  }, Client_mt)
end

function Client_mt:__gc()
    self.socket:shutdown()
    self.cli:shutdown()
    self.cli:close()
    self.cli = nil
    collectgarbage()
end

-- local function formatCommand(id, cmd, ...)
--   local args = {n = select("#", ...) + 2, id, cmd:upper(), ...}
--   local str = table.concat(args, " ", 1, args.n)
--   return str
-- end

function Client_mt:command(cmd, ...)
  -- local id = string.format("a%04d", self.id)
  -- self.id = self.id + 1

  local res = {}

  -- local str = formatCommand(id, cmd, ...)
  local str = cmd:upper() .. " " .. ...
  self.client:write(str .. "\r\n", self.client.ondata)
  log(">", str)

  return res
end

function Client_mt.__index(t, k)
  if rawget(Client_mt, k) then
    return Client_mt[k]
  else
    return function(self, ...)
      return self:command(k, ...)
    end
  end
end

return Client
