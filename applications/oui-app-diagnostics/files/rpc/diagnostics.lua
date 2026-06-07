-- Network diagnostics RPC: ping / traceroute / nslookup / arp. The host is
-- shell-quoted; the tool is whitelisted.

local M = {}

local function shq(s)
    return "'" .. tostring(s == nil and '' or s):gsub("'", "'\\''") .. "'"
end

local function popen_read(cmd)
    local f = io.popen(cmd .. ' 2>&1')
    if not f then return '' end
    local out = f:read('*a') or ''
    f:close()
    return out
end

local TOOLS = {
    ping = function(h) return 'ping -c 4 -W 2 ' .. shq(h) end,
    ping6 = function(h) return 'ping6 -c 4 -W 2 ' .. shq(h) end,
    traceroute = function(h) return 'traceroute -w 2 -q 1 ' .. shq(h) end,
    nslookup = function(h) return 'nslookup ' .. shq(h) end,
    arp = function() return 'cat /proc/net/arp' end
}

function M.run(params)
    params = params or {}
    local tool = params.tool or 'ping'
    local builder = TOOLS[tool]
    if not builder then return { ok = false, msg = 'unknown tool' } end
    local host = params.host or ''
    if tool ~= 'arp' and host == '' then return { ok = false, msg = 'host required' } end
    local out = popen_read(builder(host))
    return { ok = true, tool = tool, host = host, output = out }
end

return M
