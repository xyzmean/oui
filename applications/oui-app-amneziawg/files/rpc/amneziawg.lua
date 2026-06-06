-- AmneziaWG backend RPC. Manages uci `network` interfaces of proto `amneziawg`
-- and their peers (sections of type `amneziawg_<ifname>`), plus key generation
-- and live link status via `awg show`. Built on eco.uci + the awg CLI.

local uci = require 'eco.uci'
local ubus = require 'eco.ubus'

local M = {}

local OBF = { 'awg_jc', 'awg_jmin', 'awg_jmax', 'awg_s1', 'awg_s2', 'awg_s3', 'awg_s4',
              'awg_h1', 'awg_h2', 'awg_h3', 'awg_h4' }

local function shq(s)
    return "'" .. tostring(s == nil and '' or s):gsub("'", "'\\''") .. "'"
end

local function popen_read(cmd)
    local f = io.popen(cmd .. ' 2>/dev/null')
    if not f then return '' end
    local out = f:read('*a') or ''
    f:close()
    return out
end

local function as_list(v)
    if type(v) == 'table' then return v end
    if v == nil or v == '' then return {} end
    local t = {}
    for w in tostring(v):gmatch('%S+') do t[#t + 1] = w end
    return t
end

-- public key for a private key (best effort; '' if awg missing or key invalid)
local function pubkey_of(priv)
    if not priv or priv == '' or priv == 'generate' then return '' end
    return (popen_read('printf %s ' .. shq(priv) .. ' | awg pubkey'):gsub('%s+$', ''))
end

-- parse `awg show <iface> dump` into a per-pubkey status table
local function link_status(iface)
    local out = popen_read('awg show ' .. shq(iface) .. ' dump')
    local peers, first = {}, true
    for line in out:gmatch('[^\n]+') do
        if first then
            first = false  -- interface line: priv pub listen fwmark
        else
            local pub, psk, endpoint, aips, hs, rx, tx, keep =
                line:match('^(%S+)\t(%S+)\t(%S+)\t(%S+)\t(%S+)\t(%S+)\t(%S+)\t(%S+)')
            if pub then
                peers[pub] = {
                    endpoint = endpoint ~= '(none)' and endpoint or '',
                    handshake = tonumber(hs) or 0,
                    rx = tonumber(rx) or 0, tx = tonumber(tx) or 0
                }
            end
        end
    end
    return peers
end

function M.list()
    local c = uci.cursor()

    -- Pass 1: gather UCI data only (no yielding calls inside uci:foreach — ubus
    -- and io.popen would yield across the C-call boundary and abort).
    local raw = {}
    c:foreach('network', 'interface', function(s)
        if s['.type'] ~= 'interface' or s.proto ~= 'amneziawg' then return end
        local obf = {}
        for _, k in ipairs(OBF) do obf[k] = s[k] or '' end
        raw[#raw + 1] = {
            name = s['.name'],
            private_key = s.private_key or '',
            listen_port = s.listen_port or '',
            mtu = s.mtu or '',
            addresses = as_list(s.addresses),
            obf = obf,
            peers = {}
        }
    end)
    for _, it in ipairs(raw) do
        c:foreach('network', 'amneziawg_' .. it.name, function(p)
            it.peers[#it.peers + 1] = {
                sid = p['.name'],
                public_key = p.public_key or '',
                endpoint_host = p.endpoint_host or '',
                endpoint_port = p.endpoint_port or '',
                allowed_ips = as_list(p.allowed_ips),
                persistent_keepalive = p.persistent_keepalive or '',
                disabled = (p.disabled == '1')
            }
        end)
    end

    -- Pass 2: enrich with live link/handshake (awg) + iface up (ubus).
    local interfaces = {}
    for _, it in ipairs(raw) do
        local link = link_status(it.name)
        local st = ubus.call('network.interface.' .. it.name, 'status', {})
        for _, peer in ipairs(it.peers) do
            local ls = link[peer.public_key] or {}
            peer.handshake = ls.handshake or 0
            peer.rx = ls.rx or 0
            peer.tx = ls.tx or 0
            peer.endpoint_live = ls.endpoint or ''
        end
        it.public_key = pubkey_of(it.private_key)
        it.up = (st and st.up) and true or false
        interfaces[#interfaces + 1] = it
    end

    return { interfaces = interfaces }
end

function M.genkey()
    local priv = (popen_read('awg genkey'):gsub('%s+$', ''))
    if priv == '' then return { ok = false, msg = 'awg genkey failed' } end
    return { ok = true, private_key = priv, public_key = pubkey_of(priv) }
end

function M.pubkey(params)
    params = params or {}
    return { ok = true, public_key = pubkey_of(params.private_key) }
end

-- reload networking so changes take effect
local function reload_net()
    os.execute('ubus call network reload >/dev/null 2>&1 || /etc/init.d/network reload >/dev/null 2>&1')
end

function M.set_iface(params)
    params = params or {}
    local name = params.name
    if not name or name == '' then return { ok = false, msg = 'name required' } end
    local c = uci.cursor()

    -- create the interface if new
    if not c:get('network', name) then
        c:set('network', name, 'interface')
        c:set('network', name, 'proto', 'amneziawg')
    end
    local scalar = { 'private_key', 'listen_port', 'mtu' }
    for _, k in ipairs(scalar) do
        if params[k] ~= nil then c:set('network', name, k, tostring(params[k])) end
    end
    for _, k in ipairs(OBF) do
        if params.obf and params.obf[k] ~= nil and params.obf[k] ~= '' then
            c:set('network', name, k, tostring(params.obf[k]))
        end
    end
    if params.addresses ~= nil then
        c:delete('network', name, 'addresses')
        c:set('network', name, 'addresses', as_list(params.addresses))
    end
    c:commit('network')
    reload_net()
    return { ok = true }
end

function M.set_peer(params)
    params = params or {}
    local iface = params.iface
    if not iface or iface == '' then return { ok = false, msg = 'iface required' } end
    local c = uci.cursor()
    local sid = params.sid
    if not sid or sid == '' then
        sid = c:add('network', 'amneziawg_' .. iface)
    end
    local function setp(k, v) c:set('network', sid, k, tostring(v == nil and '' or v)) end
    setp('public_key', params.public_key)
    setp('endpoint_host', params.endpoint_host)
    setp('endpoint_port', params.endpoint_port)
    setp('persistent_keepalive', params.persistent_keepalive)
    setp('disabled', params.disabled and '1' or '0')
    c:delete('network', sid, 'allowed_ips')
    c:set('network', sid, 'allowed_ips', as_list(params.allowed_ips))
    c:commit('network')
    reload_net()
    return { ok = true, sid = sid }
end

function M.del_peer(params)
    params = params or {}
    if not params.sid then return { ok = false, msg = 'sid required' } end
    local c = uci.cursor()
    c:delete('network', params.sid)
    c:commit('network')
    reload_net()
    return { ok = true }
end

function M.del_iface(params)
    params = params or {}
    local name = params.name
    if not name or name == '' then return { ok = false, msg = 'name required' } end
    local c = uci.cursor()
    -- remove peers first
    local kill = {}
    c:foreach('network', 'amneziawg_' .. name, function(p) kill[#kill + 1] = p['.name'] end)
    for _, sid in ipairs(kill) do c:delete('network', sid) end
    c:delete('network', name)
    c:commit('network')
    reload_net()
    return { ok = true }
end

return M
