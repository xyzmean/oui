-- DHCP/DNS RPC over uci `dhcp`: dnsmasq options, per-interface pools, static
-- leases. Pure uci, so foreach is safe.

local uci = require 'eco.uci'
local M = {}

function M.get()
    local c = uci.cursor()
    local dnsmasq = {}
    c:foreach('dhcp', 'dnsmasq', function(s)
        dnsmasq = {
            sid = s['.name'], domain = s.domain or '', local_ = s['local'] or '',
            rebind_protection = (s.rebind_protection ~= '0'),
            domainneeded = (s.domainneeded ~= '0'),
            authoritative = (s.authoritative ~= '0')
        }
        return false
    end)
    local pools, hosts = {}, {}
    c:foreach('dhcp', 'dhcp', function(s)
        pools[#pools + 1] = {
            sid = s['.name'], interface = s.interface or s['.name'],
            start = s.start or '', limit = s.limit or '', leasetime = s.leasetime or '12h',
            ignore = (s.ignore == '1')
        }
    end)
    c:foreach('dhcp', 'host', function(s)
        hosts[#hosts + 1] = {
            sid = s['.name'], name = s.name or '',
            mac = (type(s.mac) == 'table' and table.concat(s.mac, ' ') or s.mac) or '',
            ip = s.ip or ''
        }
    end)
    return { dnsmasq = dnsmasq, pools = pools, hosts = hosts }
end

local function reload()
    os.execute('/etc/init.d/dnsmasq reload >/dev/null 2>&1; /etc/init.d/odhcpd reload >/dev/null 2>&1')
end

function M.set_pool(params)
    params = params or {}
    if not params.sid then return { ok = false, msg = 'sid required' } end
    local c = uci.cursor()
    for _, k in ipairs({ 'start', 'limit', 'leasetime' }) do
        if params[k] ~= nil then c:set('dhcp', params.sid, k, tostring(params[k])) end
    end
    c:set('dhcp', params.sid, 'ignore', params.ignore and '1' or '0')
    c:commit('dhcp'); reload()
    return { ok = true }
end

function M.set_host(params)
    params = params or {}
    local c = uci.cursor()
    local sid = params.sid
    if not sid or sid == '' then sid = c:add('dhcp', 'host') end
    for _, k in ipairs({ 'name', 'mac', 'ip' }) do
        if params[k] ~= nil then c:set('dhcp', sid, k, tostring(params[k])) end
    end
    c:commit('dhcp'); reload()
    return { ok = true, sid = sid }
end

function M.del_host(params)
    params = params or {}
    if not params.sid then return { ok = false, msg = 'sid required' } end
    local c = uci.cursor()
    c:delete('dhcp', params.sid); c:commit('dhcp'); reload()
    return { ok = true }
end

function M.set_dnsmasq(params)
    params = params or {}
    if not params.sid then return { ok = false, msg = 'sid required' } end
    local c = uci.cursor()
    if params.domain ~= nil then c:set('dhcp', params.sid, 'domain', tostring(params.domain)) end
    if params['local'] ~= nil then c:set('dhcp', params.sid, 'local', tostring(params['local'])) end
    if params.rebind_protection ~= nil then c:set('dhcp', params.sid, 'rebind_protection', params.rebind_protection and '1' or '0') end
    c:commit('dhcp'); reload()
    return { ok = true }
end

return M
