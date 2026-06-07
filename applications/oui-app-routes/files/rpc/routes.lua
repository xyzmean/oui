-- Routes RPC: static routes from uci `network` (route sections) plus the live
-- kernel routing table from `ip route`. popen is called outside any uci
-- foreach, so no cross-C-boundary yield.

local uci = require 'eco.uci'
local M = {}

local function popen_read(cmd)
    local f = io.popen(cmd .. ' 2>/dev/null')
    if not f then return '' end
    local out = f:read('*a') or ''
    f:close()
    return out
end

function M.get()
    local c = uci.cursor()
    local static = {}
    c:foreach('network', 'route', function(s)
        static[#static + 1] = {
            sid = s['.name'], interface = s.interface or '',
            target = s.target or '', netmask = s.netmask or '',
            gateway = s.gateway or '', metric = s.metric or ''
        }
    end)

    local active = {}
    for line in popen_read('ip -4 route show'):gmatch('[^\n]+') do
        local target = line:match('^(%S+)')
        local via = line:match('via (%S+)')
        local dev = line:match('dev (%S+)')
        local metric = line:match('metric (%S+)')
        active[#active + 1] = {
            target = target == 'default' and '0.0.0.0/0' or target,
            gateway = via or '', device = dev or '', metric = metric or '', raw = line
        }
    end

    return { static = static, active = active }
end

local function reload_net()
    os.execute('ubus call network reload >/dev/null 2>&1 || /etc/init.d/network reload >/dev/null 2>&1')
end

function M.set_route(params)
    params = params or {}
    local c = uci.cursor()
    local sid = params.sid
    if not sid or sid == '' then sid = c:add('network', 'route') end
    for _, k in ipairs({ 'interface', 'target', 'netmask', 'gateway', 'metric' }) do
        if params[k] ~= nil then c:set('network', sid, k, tostring(params[k])) end
    end
    c:commit('network'); reload_net()
    return { ok = true, sid = sid }
end

function M.del_route(params)
    params = params or {}
    if not params.sid then return { ok = false, msg = 'sid required' } end
    local c = uci.cursor()
    c:delete('network', params.sid); c:commit('network'); reload_net()
    return { ok = true }
end

return M
