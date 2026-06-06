-- VenusWRT OUI backend RPC for NetShift (sing-box domain-routing engine, a
-- de-branded podkop). Reads/writes the `netshift` UCI config, manages list
-- members, drives the init.d service, and tails the sing-box log.

local uci = require 'eco.uci'

local M = {}

local function trim(s) return (s or ''):gsub('%s+$', '') end

local function popen_read(cmd)
    local f = io.popen(cmd .. ' 2>/dev/null')
    if not f then return '' end
    local out = f:read('*a') or ''
    f:close()
    return out
end

-- Runtime snapshot: service state + sing-box process.
function M.status()
    local c = uci.cursor()
    local singbox = trim(popen_read('pgrep -x sing-box | head -1'))
    return {
        running = singbox ~= '',
        enabled = trim(popen_read('/etc/init.d/netshift enabled >/dev/null 2>&1; echo $?')) == '0',
        connection_type = c:get('netshift', 'main', 'connection_type') or 'proxy',
        proxy_config_type = c:get('netshift', 'main', 'proxy_config_type') or 'url',
        proxy_string = c:get('netshift', 'main', 'proxy_string') or '',
        singbox_pid = singbox,
        config_path = c:get('netshift', 'settings', 'config_path') or '/etc/sing-box/config.json'
    }
end

-- Full config (settings + main connection section) for the editor UI.
function M.config()
    local c = uci.cursor()
    return {
        settings = c:get_all('netshift', 'settings') or {},
        main = c:get_all('netshift', 'main') or {}
    }
end

-- Set one option in a section (settings|main), then reload sing-box.
function M.set(params)
    params = params or {}
    local section = params.section
    local option = params.option
    if not section or not option then
        return { ok = false, msg = 'section/option required' }
    end
    if section ~= 'settings' and section ~= 'main' then
        return { ok = false, msg = 'bad section' }
    end
    local c = uci.cursor()
    c:set('netshift', section, option, tostring(params.value == nil and '' or params.value))
    c:commit('netshift')
    os.execute('/etc/init.d/netshift reload >/dev/null 2>&1')
    return { ok = true }
end

-- Replace a list option wholesale (community_lists, user_domains, user_subnets…).
function M.set_list(params)
    params = params or {}
    local section = params.section or 'main'
    local option = params.option
    if not option then return { ok = false, msg = 'option required' } end
    if section ~= 'settings' and section ~= 'main' then
        return { ok = false, msg = 'bad section' }
    end
    local items = params.items or {}
    local c = uci.cursor()
    c:delete('netshift', section, option)
    if #items > 0 then c:set('netshift', section, option, items) end
    c:commit('netshift')
    os.execute('/etc/init.d/netshift reload >/dev/null 2>&1')
    return { ok = true }
end

-- Backwards-compatible single setter for the proxy outbound string.
function M.set_proxy(params)
    params = params or {}
    if type(params.proxy_string) ~= 'string' then
        return { ok = false, msg = 'proxy_string required' }
    end
    local c = uci.cursor()
    c:set('netshift', 'main', 'proxy_string', params.proxy_string)
    c:commit('netshift')
    os.execute('/etc/init.d/netshift reload >/dev/null 2>&1')
    return { ok = true }
end

-- Tail the sing-box / netshift log (array of lines; UI paginates client-side).
function M.logs(params)
    params = params or {}
    local n = tonumber(params.lines) or 200
    if n > 1000 then n = 1000 end
    local out = popen_read('logread -e sing-box 2>/dev/null | tail -n ' .. n)
    if trim(out) == '' then
        out = popen_read('logread 2>/dev/null | grep -iE "sing-box|netshift|podkop" | tail -n ' .. n)
    end
    local lines = {}
    for line in out:gmatch('[^\n]+') do lines[#lines + 1] = line end
    if #lines == 0 then lines = { 'Журнал пуст или служба не запущена' } end
    return lines
end

local SVC = { start = true, stop = true, restart = true, reload = true, enable = true, disable = true }
function M.action(params)
    params = params or {}
    local cmd = params.cmd or ''
    if not SVC[cmd] then return { ok = false, msg = 'unknown command' } end
    local rc = os.execute('/etc/init.d/netshift ' .. cmd .. ' >/dev/null 2>&1')
    return { ok = (rc == true or rc == 0), cmd = cmd }
end

return M
