--[[
tdluaJIT - pure lua interface with tdlib usign FFI
testloop.lua
© Giuseppe Marino 2019 see LICENSE
--]]

local loop    = require 'loop'
local tdlua   = require 'tdlua'
local yield   = coroutine.yield
local serpent = require 'serpent'

local function vardump(wut)
    print(serpent.block(wut, {comment=false}))
end

print('loop', loop)

local function callback(client)
    print(client)
    client:getTextEntities({ text = '@telegram /test_command https://telegram.org telegram.me'}, function(client, result) print 'CBed' vardump(result) end)
    print 'let\'s go'
    while true do
        local update = yield()
        vardump(update)
    end
end

local i = loop:new(tdlua(), coroutine.wrap(callback))
print('i', i)
i:loop()
