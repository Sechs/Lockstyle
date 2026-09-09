-- Copyright © 2026, Sechs
-- All rights reserved.
-- 
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
-- 
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--     * Neither the name of AnnounceTarget nor the
--       names of its contributors may be used to endorse or promote products
--       derived from this software without specific prior written permission.
-- 
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL Sechs BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

local config = require('config')
require('logger')

_addon.name       = 'Lockstyle'
_addon.author     = 'Sechs'
_addon.version    = '1.1'
_addon.commands   = {'lockstyle', 'ls'}

local job_list = {'WAR','MNK','WHM','BLM','RDM','THF','PLD','DRK','BST','BRD','RNG','SAM','NIN','DRG','SMN','BLU','COR','PUP','DNC','SCH','GEO','RUN'}

local defaults = {}
defaults.delay = 8
for _, job in ipairs(job_list) do
    defaults[job] = ''
end

local settings = config.load(defaults)

local function init_random()
    math.randomseed(os.time())
    math.random()
end

local function parse_list(str)
    local t = {}
    if str == nil then
        return t
    end
    for token in tostring(str):gmatch('[^,%s]+') do
        local n = tonumber(token)
        if n then
            table.insert(t, n)
        end
    end
    return t
end

local function pick_style(job)
    if not job or settings[job] == nil then
        return nil
    end
    local list = parse_list(settings[job])
    local count = #list
    if count == 0 then
        return nil
    elseif count == 1 then
        return list[1]
    else
        return list[math.random(count)]
    end
end

local pending_id = 0

local function schedule_apply(job, forced_delay)
    pending_id = pending_id + 1
    local my_id = pending_id

    local delay = forced_delay
    if delay == nil then
        delay = tonumber(settings.delay) or 0
    end
    if delay < 0 then
        delay = 0
    end

    coroutine.schedule(function()
        if my_id ~= pending_id then
            return
        end

        local player = windower.ffxi.get_player()
        if not player then
            return
        end
        if job ~= nil and player.main_job ~= job then
            return
        end

        local style = pick_style(player.main_job)
        if style then
            windower.send_command('input /lockstyleset ' .. style)
        end
    end, delay)
end

local last_main_id = nil
local last_sub_id   = nil

local function track_current_job()
    local player = windower.ffxi.get_player()
    if player then
        last_main_id = player.main_job_id
        last_sub_id  = player.sub_job_id
    end
end

config.register(settings, function(s)
    settings = s
    config.save(settings)
    track_current_job()
    local player = windower.ffxi.get_player()
    if player then
        schedule_apply(player.main_job)
    end
end)

windower.register_event('load', function()
    init_random()
end)

windower.register_event('job change', function(main_job_id, main_job_level, sub_job_id, sub_job_level)
    local player = windower.ffxi.get_player()
    if not player then
        return
    end

    if main_job_id ~= last_main_id then
        last_main_id = main_job_id
        last_sub_id  = sub_job_id
        schedule_apply(player.main_job)

    elseif sub_job_id ~= last_sub_id then
        last_sub_id = sub_job_id
        schedule_apply(player.main_job)
    end
end)

windower.register_event('incoming text', function(original, modified, original_mode, modified_mode, blocked)
    if original and original:lower():find('style lock disabled', 1, true) then
        local player = windower.ffxi.get_player()
        if player then
            schedule_apply(player.main_job)
        end
    end
end)


-- Manual commands section
windower.register_event('addon command', function(...)
    local args = {...}
    local cmd = args[1] and args[1]:lower() or ''

    if cmd == 'random' or cmd == 'reroll' then
        local player = windower.ffxi.get_player()
        if not player then
            return
        end
        schedule_apply(player.main_job, 0)
        windower.add_to_chat(207, 'Lockstyle: new random for ' .. player.main_job .. '.')

    elseif cmd == 'status' then
        local player = windower.ffxi.get_player()
        if not player then
            return
        end
        local job = player.main_job
        local list_str = settings[job] or ''
        if list_str == '' then
            windower.add_to_chat(207, 'Lockstyle [' .. job .. ']: no set defined.')
        else
            windower.add_to_chat(207, 'Lockstyle [' .. job .. ']: ' .. list_str
                .. ' (delay: ' .. tostring(settings.delay) .. 's)')
        end

    elseif cmd == 'reload' then
        config.reload(settings)
        windower.add_to_chat(207, 'Lockstyle: config reloaded from the file.')

    else
        windower.add_to_chat(207, 'Lockstyle commands: //lockstyle random | status | reload | help')
    end
end)
