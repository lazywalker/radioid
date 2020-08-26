#!/usr/bin/env tarantool

-- Copyright 2019-2020 Michael BD7MQB <bd7mqb@qq.com>
-- This is free software, licensed under the GNU GENERAL PUBLIC LICENSE, Version 3.0

require "io"

local DMRID_FILE = '../download/user.csv'
local CC_FILE = '../CountryCode.csv'
local DMRID_FILE_EXPORT = '../export/DMRIds.dat'
local CC_FILE_EXPORT = '../export/CountryCode.txt'

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
        local lastname = tokens[4] or ""
        local city = tokens[5] or ""
        local state = tokens[6]
        local country = tokens[7] or ""
        local remarks = tokens[8]

        box.space.dmrid:replace{id, callsign, name:trim(), lastname:trim(), city:trim(), state, country, remarks}
        if city:trim() ~= "" and not box.space.dmrid_city.index.name:get(city) then
            box.space.dmrid_city:insert{nil, city}
        end 

        i = i + 1
    until true -- end repeat
    end

    print(("%s records loaded."):format(i))
end

--- Export CountryCode.txt
function export_country_code()
    local file = assert(io.open(CC_FILE_EXPORT, 'w'))

    for _, tuple in box.space.country_code:pairs(nil, {iterator = box.index.ALL}) do
        local iso = tuple[1]
        local country = tuple[2]

        file:write(("%s\t%s\n"):format(iso, country))
    end

    file:close()
end

--- Export DMRIds.dat
function export_dmrid_iso()
    local file = assert(io.open(DMRID_FILE_EXPORT, 'w'))

    for _, tuple in box.space.dmrid.index.id:pairs(nil, {iterator = box.index.ALL}) do
        local id = tuple[1]
        local callsign = tuple[2]
        local name = ("%s %s"):format(tuple[3], tuple[4])
        local city = tuple[5]
        local country = tuple[7]
        local country_iso
        country_iso = box.space.country_code.index.country:get(country)
        if country_iso then
            country_iso = country_iso[1]
        else
            country_iso = country
        end

        city_id = box.space.dmrid_city.index.name:get(city)
        if city_id then
            city_id = city_id[1]
        else
            city_id = ""
        end
        
        file:write(("%s\t%s\t%s\t%s\n"):format(id, callsign, name:trim(), country_iso))
    end

    file:close()
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
    cc:create_index('iso', {
        type = 'hash',
        parts = {'iso'}
    })
    cc:create_index('country', {
        type = 'hash',
        parts = {'country'}
    })

    -- dmrid table
    dmrid = box.schema.space.create('dmrid')
    dmrid:format({
        {name = 'id', type = 'unsigned'},
        {name = 'callsign', type = 'string', is_nullable = true},
        {name = 'name', type = 'string', is_nullable = true},
        {name = 'lastname', type = 'string', is_nullable = true},
        {name = 'city', type = 'string', is_nullable = true},
        {name = 'state', type = 'string', is_nullable = true},
        {name = 'country', type = 'string', is_nullable = true},
        {name = 'remarks', type = 'string', is_nullable = true}

    })
    dmrid:create_index('id', {
        type = 'hash',
        parts = {'id'}
    })
    dmrid:create_index('callsign', {
        type = 'tree',
        parts = {'callsign'},
        unique = false
    })

    -- city
    box.schema.sequence.create('s_city_id', {min=1, start=1})
    ct = box.schema.space.create('dmrid_city')
    ct:format({
        {name = 'id', type = 'unsigned'},
        {name = 'name', type = 'string'}
    })
    ct:create_index('id', {
        sequence='s_city_id',
        type = 'hash',
        parts = {'id'}
    })
    ct:create_index('name', {
        type = 'hash',
        parts = {'name'}
    })

    -- Grant permission to all
    box.schema.user.grant('guest', 'read,write,execute', 'universe')

    -- Load data at first time
    load_country_code()
    load_dmrid()
end)

require('console').start()
