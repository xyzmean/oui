-- VenusWRT OUI backend RPC for NetShift (sing-box domain-routing engine).
-- Reads/writes the `netshift` UCI config and drives the init.d service.

local uci = require 'eco.uci'

local M = {}

local function trim(s)
    return (s or ''):gsub('%s+$', '')
end

local function popen_read(cmd)
    local f = io.popen(cmd .. ' 2>/dev/null')
    if not f then return '' end
    local out = f:read('*a')
    f:close()
    return out or ''
end

-- Runtime + config snapshot.
function M.status()
    local c = uci.cursor()
    local connection = c:get('netshift', 'main', 'connection_type') or 'proxy'
    local pcfg = c:get('netshift', 'main', 'proxy_config_type') or 'url'
    local proxy = c:get('netshift', 'main', 'proxy_string') or ''
    local enabled = (popen_read('/etc/init.d/netshift enabled >/dev/null 2>&1; echo $?'):match('%d') == '0')
    local singbox = trim(popen_read('pgrep -x sing-box | head -1'))
    local running = singbox ~= ''

    local lists = {}
    c:foreach('netshift', 'main', function(s)
        for _, v in ipairs(s.community_lists or {}) do
            lists[#lists + 1] = v
        end
    end)

    return {
        running = running,
        enabled = enabled,
        connection_type = connection,
        proxy_config_type = pcfg,
        proxy_string = proxy,
        community_lists = lists,
        singbox_pid = singbox
    }
end

local SVC = { start = true, stop = true, restart = true, reload = true, enable = true, disable = true }

function M.action(params)
    params = params or {}
    local cmd = params.cmd or ''
    if not SVC[cmd] then
        return { ok = false, msg = 'unknown command' }
    end
    local rc = os.execute('/etc/init.d/netshift ' .. cmd .. ' >/dev/null 2>&1')
    return { ok = (rc == true or rc == 0), cmd = cmd }
end

-- Set the proxy outbound string (vless://… / ss://… / subscription URL) and reload.
function M.set_proxy(params)
    params = params or {}
    local s = params.proxy_string
    if type(s) ~= 'string' then
        return { ok = false, msg = 'proxy_string required' }
    end
    local c = uci.cursor()
    c:set('netshift', 'main', 'proxy_string', s)
    c:commit('netshift')
    os.execute('/etc/init.d/netshift reload >/dev/null 2>&1')
    return { ok = true }
end

return M
