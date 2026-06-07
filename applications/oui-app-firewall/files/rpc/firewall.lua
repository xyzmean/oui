-- Firewall RPC over uci `firewall`: zones, port forwards (redirect), traffic
-- rules. Pure uci (no ubus), so foreach callbacks are safe.

local uci = require 'eco.uci'

local M = {}

local function as_list(v)
    if type(v) == 'table' then return v end
    if v == nil or v == '' then return {} end
    local t = {}; for w in tostring(v):gmatch('%S+') do t[#t + 1] = w end; return t
end

function M.get()
    local c = uci.cursor()
    local zones, forwards, rules = {}, {}, {}

    c:foreach('firewall', 'zone', function(s)
        zones[#zones + 1] = {
            sid = s['.name'], name = s.name or '',
            input = s.input or 'DROP', output = s.output or 'ACCEPT', forward = s.forward or 'DROP',
            masq = (s.masq == '1'), network = as_list(s.network)
        }
    end)
    c:foreach('firewall', 'redirect', function(s)
        forwards[#forwards + 1] = {
            sid = s['.name'], name = s.name or '', target = s.target or 'DNAT',
            proto = (type(s.proto) == 'table' and table.concat(s.proto, ' ') or s.proto) or 'tcp udp',
            src = s.src or 'wan', src_dport = s.src_dport or '',
            dest_ip = s.dest_ip or '', dest_port = s.dest_port or '',
            enabled = not (s.enabled == '0')
        }
    end)
    c:foreach('firewall', 'rule', function(s)
        rules[#rules + 1] = {
            sid = s['.name'], name = s.name or '', target = s.target or 'ACCEPT',
            proto = (type(s.proto) == 'table' and table.concat(s.proto, ' ') or s.proto) or '',
            src = s.src or '', dest = s.dest or '', dest_port = s.dest_port or '',
            enabled = not (s.enabled == '0')
        }
    end)

    return { zones = zones, forwards = forwards, rules = rules }
end

local function reload() os.execute('/etc/init.d/firewall reload >/dev/null 2>&1') end

function M.set_forward(params)
    params = params or {}
    local c = uci.cursor()
    local sid = params.sid
    if not sid or sid == '' then sid = c:add('firewall', 'redirect') end
    local map = { 'name', 'src', 'src_dport', 'dest_ip', 'dest_port', 'proto', 'target' }
    for _, k in ipairs(map) do if params[k] ~= nil then c:set('firewall', sid, k, tostring(params[k])) end end
    if not params.target or params.target == '' then c:set('firewall', sid, 'target', 'DNAT') end
    c:set('firewall', sid, 'dest', params.dest or 'lan')
    c:set('firewall', sid, 'enabled', params.enabled == false and '0' or '1')
    c:commit('firewall'); reload()
    return { ok = true, sid = sid }
end

function M.set_rule(params)
    params = params or {}
    local c = uci.cursor()
    local sid = params.sid
    if not sid or sid == '' then sid = c:add('firewall', 'rule') end
    for _, k in ipairs({ 'name', 'src', 'dest', 'proto', 'dest_port', 'target' }) do
        if params[k] ~= nil then c:set('firewall', sid, k, tostring(params[k])) end
    end
    c:set('firewall', sid, 'enabled', params.enabled == false and '0' or '1')
    c:commit('firewall'); reload()
    return { ok = true, sid = sid }
end

function M.del(params)
    params = params or {}
    if not params.sid then return { ok = false, msg = 'sid required' } end
    local c = uci.cursor()
    c:delete('firewall', params.sid)
    c:commit('firewall'); reload()
    return { ok = true }
end

function M.toggle(params)
    params = params or {}
    if not params.sid then return { ok = false, msg = 'sid required' } end
    local c = uci.cursor()
    c:set('firewall', params.sid, 'enabled', params.enabled and '1' or '0')
    c:commit('firewall'); reload()
    return { ok = true }
end

return M
