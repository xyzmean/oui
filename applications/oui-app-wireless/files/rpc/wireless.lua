-- Wireless RPC: uci `wireless` (wifi-device radios + wifi-iface SSIDs) merged
-- with live ubus `network.wireless status`. ubus is called AFTER the uci
-- foreach passes (never inside a foreach callback — that yields across C).

local uci = require 'eco.uci'
local ubus = require 'eco.ubus'

local M = {}

function M.list()
    local c = uci.cursor()

    -- pass 1: radios
    local radios = {}
    local order = {}
    c:foreach('wireless', 'wifi-device', function(s)
        local name = s['.name']
        radios[name] = {
            name = name,
            band = s.band or '',
            channel = s.channel or 'auto',
            htmode = s.htmode or '',
            country = s.country or '',
            txpower = s.txpower or '',
            disabled = (s.disabled == '1'),
            ifaces = {}
        }
        order[#order + 1] = name
    end)

    -- pass 1b: SSIDs grouped by their radio
    c:foreach('wireless', 'wifi-iface', function(s)
        local dev = s.device
        local rec = {
            sid = s['.name'],
            device = dev,
            mode = s.mode or 'ap',
            ssid = s.ssid or '',
            encryption = s.encryption or 'none',
            key = s.key or '',
            network = s.network or '',
            hidden = (s.hidden == '1'),
            disabled = (s.disabled == '1')
        }
        if radios[dev] then radios[dev].ifaces[#radios[dev].ifaces + 1] = rec end
    end)

    -- pass 2: live status (safe to yield here)
    local status = ubus.call('network.wireless', 'status', {}) or {}
    for name, r in pairs(radios) do
        local st = status[name]
        if st then
            r.up = st.up == true
            if st.config and st.config.channel then r.live_channel = st.config.channel end
        else
            r.up = false
        end
    end

    local list = {}
    for _, name in ipairs(order) do list[#list + 1] = radios[name] end
    return { radios = list }
end

local function wifi_reload()
    os.execute('wifi reload >/dev/null 2>&1 || /sbin/wifi up >/dev/null 2>&1')
end

function M.set_device(params)
    params = params or {}
    local name = params.name
    if not name then return { ok = false, msg = 'name required' } end
    local c = uci.cursor()
    for _, k in ipairs({ 'band', 'channel', 'htmode', 'country', 'txpower' }) do
        if params[k] ~= nil and params[k] ~= '' then c:set('wireless', name, k, tostring(params[k])) end
    end
    if params.disabled ~= nil then c:set('wireless', name, 'disabled', params.disabled and '1' or '0') end
    c:commit('wireless')
    wifi_reload()
    return { ok = true }
end

function M.set_iface(params)
    params = params or {}
    local sid = params.sid
    local c = uci.cursor()
    if not sid or sid == '' then
        if not params.device then return { ok = false, msg = 'device required' } end
        sid = c:add('wireless', 'wifi-iface')
        c:set('wireless', sid, 'device', params.device)
        c:set('wireless', sid, 'mode', 'ap')
        c:set('wireless', sid, 'network', params.network or 'lan')
    end
    for _, k in ipairs({ 'ssid', 'encryption', 'key', 'mode', 'network' }) do
        if params[k] ~= nil then c:set('wireless', sid, k, tostring(params[k])) end
    end
    c:set('wireless', sid, 'hidden', params.hidden and '1' or '0')
    c:set('wireless', sid, 'disabled', params.disabled and '1' or '0')
    -- a 'none' encryption must not keep a stale key
    if params.encryption == 'none' then c:delete('wireless', sid, 'key') end
    c:commit('wireless')
    wifi_reload()
    return { ok = true, sid = sid }
end

function M.del_iface(params)
    params = params or {}
    if not params.sid then return { ok = false, msg = 'sid required' } end
    local c = uci.cursor()
    c:delete('wireless', params.sid)
    c:commit('wireless')
    wifi_reload()
    return { ok = true }
end

return M
