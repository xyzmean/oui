-- VenusWRT OUI backend RPC — thin wrapper over the `venus` control CLI.
-- The CLI already speaks JSON (`venus status|lists --json`) and owns all the
-- privileged work; here we only marshal calls and whitelist the verbs.

local cjson = require 'cjson'

local M = {}

local function read_json(cmd)
    local f = io.popen(cmd .. ' 2>/dev/null')
    if not f then
        return nil
    end
    local out = f:read('*a')
    f:close()
    local ok, data = pcall(cjson.decode, out)
    if ok then
        return data
    end
    return nil
end

-- Runtime snapshot (tunnel/zapret/health/list counts/system load).
function M.status()
    return read_json('venus status --json') or { ok = false }
end

-- List sources, sizes, mtimes, cron schedule.
function M.lists()
    return read_json('venus lists --json') or { ok = false }
end

-- Whitelisted control verbs. `arg` only used by `update` (ipsum|ru|all|community).
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
        return read_json('venus update ' .. arg) or { ok = false, msg = 'no output' }
    end

    if not SIMPLE[cmd] then
        return { ok = false, msg = 'unknown command' }
    end

    local rc = os.execute('venus ' .. cmd .. ' >/dev/null 2>&1')
    local ok = (rc == true or rc == 0)
    return { ok = ok, cmd = cmd }
end

return M
