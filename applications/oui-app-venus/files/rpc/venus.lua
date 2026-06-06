-- VenusWRT OUI backend RPC — thin, safe wrapper over the `venus` control CLI.
-- The CLI already speaks JSON and owns all privileged work; here we only marshal
-- calls, whitelist verbs, and shell-quote every user-supplied argument.
--
-- Conventions: `this.$oui.call('venus', '<func>', params)` from the Vue views.
-- Read verbs return the CLI's JSON; mutating verbs return the CLI's {ok,msg}.

local cjson = require 'cjson'

local M = {}

-- Single-quote an argument so the shell treats it literally (injection-safe).
local function shq(s)
    return "'" .. tostring(s == nil and '' or s):gsub("'", "'\\''") .. "'"
end

-- Build `venus <quoted args...>` from a plain Lua array.
local function venus_cmd(args)
    local parts = { 'venus' }
    for _, a in ipairs(args) do
        parts[#parts + 1] = shq(a)
    end
    return table.concat(parts, ' ')
end

local function read_json_cmd(cmd)
    local f = io.popen(cmd .. ' 2>/dev/null')
    if not f then return nil end
    local out = f:read('*a')
    f:close()
    local ok, data = pcall(cjson.decode, out)
    if ok then return data end
    return nil
end

-- Run a venus verb and return its JSON output (read or {ok,msg} verbs).
local function run_json(args)
    return read_json_cmd(venus_cmd(args)) or { ok = false, msg = 'no output' }
end

-- ---- read verbs ---------------------------------------------------------
function M.status()    return read_json_cmd('venus status --json') or { ok = false } end
function M.lists()     return read_json_cmd('venus lists --json')  or { ok = false } end
function M.config()    return read_json_cmd('venus config-get')    or { ok = false } end
function M.diagnose()  return read_json_cmd('venus diagnose')      or { findings = {} } end
function M.pkg_status() return read_json_cmd('venus pkg-status')   or { components = {} } end
function M.logs()      return read_json_cmd('venus logs')          or {} end

function M.check_host(params)
    params = params or {}
    return run_json({ 'check-host', params.host or 'youtube.com' })
end

function M.fetch_url(params)
    params = params or {}
    if not params.url or params.url == '' then
        return { ok = false, msg = 'no url' }
    end
    return run_json({ 'fetch-url', params.url, params.ua or '' })
end

-- DPI-bypass autotest: sub in start|progress|stop. Returns the live progress JSON.
local ZAPRET_TEST_SUB = { start = true, progress = true, stop = true }
function M.zapret_test(params)
    params = params or {}
    local sub = params.sub or 'progress'
    if not ZAPRET_TEST_SUB[sub] then
        return { ok = false, msg = 'bad subcommand' }
    end
    return run_json({ 'zapret-test', sub })
end

-- Paginated list viewer. Reads only a window of lines (never the whole file
-- into the response) — this is the server side of the big-list hang fix.
function M.view_list(params)
    params = params or {}
    local fpath = params.file or ''
    -- hard path allow-list: only the venus list dir, plain filenames.
    if not fpath:match('^/etc/venus/[%w%._%-]+$') then
        return { ok = false, msg = 'bad path', rows = {}, total = 0 }
    end
    local offset = tonumber(params.offset) or 0
    local limit = tonumber(params.limit) or 100
    if limit > 1000 then limit = 1000 end

    local f = io.open(fpath, 'r')
    if not f then
        return { ok = false, msg = 'not found', rows = {}, total = 0 }
    end
    local rows, total = {}, 0
    for line in f:lines() do
        if total >= offset and #rows < limit then
            rows[#rows + 1] = line
        end
        total = total + 1
    end
    f:close()
    return { ok = true, rows = rows, total = total, file = fpath }
end

-- ---- mutating verbs (config) -------------------------------------------
function M.config_set(params)
    params = params or {}
    if not params.section or not params.option then
        return { ok = false, msg = 'section/option required' }
    end
    return run_json({ 'config-set', params.section, params.option, params.value or '' })
end

function M.config_add_list(params)
    params = params or {}
    return run_json({ 'config-add-list', params.section, params.option, params.value })
end

function M.config_del_list(params)
    params = params or {}
    return run_json({ 'config-del-list', params.section, params.option, params.value })
end

-- params.name + ordered tunnel fields (empty strings are skipped by the CLI).
function M.config_add_tunnel(params)
    params = params or {}
    if not params.name or params.name == '' then
        return { ok = false, msg = 'name required' }
    end
    return run_json({
        'config-add-tunnel', params.name,
        params.proto or '', params.endpoint or '', params.public_key or '',
        params.private_key or '', params.addresses or '', params.mtu or '',
        params.sni or '', params.uuid or '', params.security or '', params.transport or ''
    })
end

function M.config_del_tunnel(params)
    params = params or {}
    return run_json({ 'config-del-tunnel', params.name })
end

-- params: id, label, dest, tunnel. List members (ipset/domains/services) are
-- added afterwards via config_add_list.
function M.config_add_profile(params)
    params = params or {}
    if not params.id or params.id == '' then
        return { ok = false, msg = 'id required' }
    end
    return run_json({
        'config-add-profile', params.id,
        params.label or params.id, params.dest or 'direct', params.tunnel or ''
    })
end

function M.config_del_profile(params)
    params = params or {}
    return run_json({ 'config-del-profile', params.id })
end

function M.pkg_install(params)
    params = params or {}
    if not params.id or params.id == '' then
        return { ok = false, msg = 'no component id' }
    end
    return run_json({ 'pkg-install', params.id })
end

-- ---- simple control verbs (back-compat with the existing dashboard) -----
local SIMPLE = {
    apply = true, enable = true, disable = true, start = true, stop = true,
    watchdog = true, failover = true, ['zapret-restart'] = true
}
local UPDATE_ARG = { ipsum = true, ru = true, all = true, community = true }

function M.action(params)
    params = params or {}
    local cmd = params.cmd or ''

    if cmd == 'update' then
        local arg = params.arg or 'all'
        if not UPDATE_ARG[arg] then
            return { ok = false, msg = 'bad update target' }
        end
        return run_json({ 'update', arg })
    end

    if not SIMPLE[cmd] then
        return { ok = false, msg = 'unknown command' }
    end

    local rc = os.execute('venus ' .. cmd .. ' >/dev/null 2>&1')
    local ok = (rc == true or rc == 0)
    return { ok = ok, cmd = cmd }
end

return M
