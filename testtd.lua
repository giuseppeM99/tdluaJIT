--[[
tdluaJIT - pure lua interface with tdlib usign FFI
testtd.lua
© Giuseppe Marino 2019 see LICENSE
--]]

local tdjson = require 'tdjson'
local serpent = require 'serpent'
local jit = require 'jit'
local function vardump(w)
  print(serpent.block(w, {comment=false}))
end
--jit.off()
local client = tdjson()

print 'ok'

--[[
vardump(
    client:execute({
        ['@type'] = 'getTextEntities', text = '@telegram /test_command https://telegram.org telegram.me',
        ['@extra'] = {'5', 7.0},
    })
)
--]]
print(client)
vardump(client:receive())
--client:send({['@type'] = 'getAuthorizationState', ['@extra'] = 1.01234})
vardump(client:getAuthorizationState('asd'))


while true do
    print 'while loop'
    if not client then
      break
    end
    local res = client:receive(1)
    if res then
        vardump(res)
        if res['@type'] == 'updateAuthorizationState' and res['authorization_state']['@type'] == 'authorizationStateClosed' then
            print('exiting')
            break
        end
    else
        print('res is nil')
        --client:close(true)
        --Same as client:send({["@type"] = "close"})
        break
    end
end

client:destroy()
