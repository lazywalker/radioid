#!/usr/bin/env tarantool

-- Copyright 2019 BD7MQB <bd7mqb@qq.com>
-- This is free software, licensed under the GNU GENERAL PUBLIC LICENSE, Version 2
-- a DmdIds service via ubus

require "io"

local DMRID_FILE = '../download/DMRIds.csv'
local CC_FILE = '../download/CountryCode.csv'

-- string.split = function(s, p)
--     local rt= {}
--     string.gsub(s, '[^'..p..']+', function(w) table.insert(rt, w) end )
--     return rt
-- end

string.trim = function(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

string.split = function(str, pat, max, regex)
	pat = pat or "\n"
	max = max or #str

	local t = {}
	local c = 1

	if #str == 0 then
		return {""}
	end

	if #pat == 0 then
		return nil
	end

	if max == 0 then
		return str
	end

	repeat
		local s, e = str:find(pat, c, not regex)
		max = max - 1
		if s and max < 0 then
			t[#t+1] = str:sub(c)
		else
			t[#t+1] = str:sub(c, s and s - 1)
		end
		c = e and e + 1 or #str + 1
	until not s or max < 0

	return t
end

--- Load records into box.space.country_code
function load_country_code()
    local file = assert(io.open(CC_FILE,'r'))

    local i = 0
    for line in file:lines() do
        i = i + 1
    repeat
        if i == 1 then break end

        local tokens = line:split(",")
        local country = tokens[1]
        local iso = tokens[2]
        local un = tokens[3]
        local num = tonumber(tokens[4])

        box.space.country_code:replace{iso, country, un, num}
    until true -- end repeat
    end

    print(("%s records loaded."):format(i-1))
end

--- Load records into box.space.dmrid
function load_dmrid()
    local file = assert(io.open(DMRID_FILE,'r'))

    local i = 0
    for line in file:lines() do
    repeat
        local tokens = line:split(",")
        local id = tonumber(tokens[1])
        -- skips possible title row
        if not id then
            break
        end

        local callsign = tokens[2]
        local name = tokens[3] or ""
        local city = tokens[4] or ""
        local state = tokens[5]
        local country = tokens[6] or ""
        local country_iso
        country_iso = box.space.country_code.index.secondary:get(country)
        if country_iso then
            country_iso = country_iso[1]
        end
        local remarks = tokens[7]

        box.space.dmrid:replace{id, callsign, name:trim(), city:trim(), state, country, country_iso, remarks}

        i = i + 1
    until true -- end repeat
    end

    print(("%s records loaded."):format(i))
end

-- Configure database
box.cfg {
    listen = 3301,
    background = false,
    work_dir = './data',
    log = 'radioid.log',
    pid_file = 'radioid.pid'
}

box.once("bootstrap", function()
    -- country code table
    cc = box.schema.space.create('country_code')
    cc:format({
        {name = 'iso', type = 'string'},
        {name = 'country', type = 'string'},
        {name = 'un', type = 'string'},
        {name = 'num', type = 'unsigned'}
    })
    cc:create_index('primary', {
        type = 'hash',
        parts = {'iso'}
    })
    cc:create_index('secondary', {
        type = 'hash',
        parts = {'country'}
    })

    -- dmrid table
    dmrid = box.schema.space.create('dmrid')
    dmrid:format({
        {name = 'id', type = 'unsigned'},
        {name = 'callsign', type = 'string', is_nullable = true},
        {name = 'name', type = 'string', is_nullable = true},
        {name = 'city', type = 'string', is_nullable = true},
        {name = 'state', type = 'string', is_nullable = true},
        {name = 'country', type = 'string', is_nullable = true},
        {name = 'country_iso', type = 'string', is_nullable = true},
        {name = 'remarks', type = 'string', is_nullable = true}

    })
    dmrid:create_index('primary', {
        type = 'hash',
        parts = {'id'}
    })
    dmrid:create_index('secondary', {
        type = 'tree',
        parts = {'callsign'},
        unique = false
    })

    -- Grant permission to all
    box.schema.user.grant('guest', 'read,write,execute', 'universe')

    -- Load data at first time
    load_country_code()
    load_dmrid()
end)

require('console').start()
