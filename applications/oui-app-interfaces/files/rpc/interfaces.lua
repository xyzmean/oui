-- Network interfaces RPC: merges the `network` UCI config with live status from
-- ubus (network.interface.<name> status) for the OUI Interfaces app.

local uci = require 'eco.uci'
local ubus = require 'eco.ubus'

local M = {}

local function as_list(v)
    if type(v) == 'table' then return v end
    if v == nil or v == '' then return {} end
    local t = {}
    for w in tostring(v):gmatch('%S+') do t[#t + 1] = w end
    return t
end

function M.list()
    local c = uci.cursor()

    -- Pass 1: collect plain UCI data only. No yielding calls (ubus) may run
    -- inside a uci:foreach callback — that yields across a C-call boundary.
    local raw = {}
    c:foreach('network', 'interface', function(s)
        local name = s['.name']
        if name == 'loopback' then return end
        raw[#raw + 1] = {
            name = name,
            proto = s.proto or 'none',
            device = s.device or s.ifname or '',
            -- ipaddr may be a scalar or (CIDR-style) a one-element list
            ipaddr = (type(s.ipaddr) == 'table' and s.ipaddr[1] or s.ipaddr) or '',
            netmask = s.netmask or '',
            gateway = s.gateway or '',
            dns = as_list(s.dns),
            username = s.username or '',
            mtu = s.mtu or ''
        }
    end)

    -- Pass 2: enrich with live ubus status (safe to yield here).
    local ifaces = {}
    for _, r in ipairs(raw) do
        local st = ubus.call('network.interface.' .. r.name, 'status', {}) or {}
        local addr = ''
        if st['ipv4-address'] and st['ipv4-address'][1] then
            local a = st['ipv4-address'][1]
            addr = a.address .. '/' .. (a.mask or '')
        end
        r.up = st.up == true
        r.l3_device = st.l3_device or ''
        r.address = addr
        r.uptime = st.uptime or 0
        if r.device == '' then r.device = st.l3_device or '' end
        ifaces[#ifaces + 1] = r
    end

    return { interfaces = ifaces }
end

local function reload_net()
    os.execute('ubus call network reload >/dev/null 2>&1 || /etc/init.d/network reload >/dev/null 2>&1')
end

-- Set an interface's protocol and the fields relevant to it; stale fields from
-- the previous proto are cleared so the config stays clean.
function M.set(params)
    params = params or {}
    local name = params.name
    if not name or name == '' then return { ok = false, msg = 'name required' } end
    local c = uci.cursor()
    if not c:get('network', name) then
        c:set('network', name, 'interface')
    end

    local proto = params.proto or 'dhcp'
    c:set('network', name, 'proto', proto)
    if params.device and params.device ~= '' then c:set('network', name, 'device', params.device) end
    if params.mtu and params.mtu ~= '' then c:set('network', name, 'mtu', tostring(params.mtu)) end

    -- clear proto-specific fields, then set the ones for this proto
    for _, k in ipairs({ 'ipaddr', 'netmask', 'gateway', 'dns', 'username', 'password' }) do
        c:delete('network', name, k)
    end
    if proto == 'static' then
        if params.ipaddr ~= nil then c:set('network', name, 'ipaddr', params.ipaddr) end
        if params.netmask ~= nil then c:set('network', name, 'netmask', params.netmask) end
        if params.gateway and params.gateway ~= '' then c:set('network', name, 'gateway', params.gateway) end
        local dns = as_list(params.dns)
        if #dns > 0 then c:set('network', name, 'dns', dns) end
    elseif proto == 'pppoe' then
        if params.username ~= nil then c:set('network', name, 'username', params.username) end
        if params.password ~= nil then c:set('network', name, 'password', params.password) end
    end

    c:commit('network')
    reload_net()
    return { ok = true }
end

function M.restart(params)
    params = params or {}
    if params.name and params.name ~= '' then
        os.execute('ubus call network.interface.' .. ("%q"):format(params.name) .. ' down >/dev/null 2>&1')
        os.execute('ifup ' .. ("%q"):format(params.name) .. ' >/dev/null 2>&1')
    else
        reload_net()
    end
    return { ok = true }
end

return M
