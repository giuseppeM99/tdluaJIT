--[[
tdluaJIT - pure lua interface with tdlib usign FFI
loop.lua
© Giuseppe Marino 2019 see LICENSE
--]]

local _M = {}
local mt = {}

function _M:new(instance, callback)
    local i = {instance = instance, callback = callback, upd_id = 0, upd_cb = {}, threads = {}}
    table.insert(self.instances, i)
    setmetatable(i, {__index = self})
    callback(i)
    return i
end

function _M:loop()
    while true do
        for _, i in ipairs(self.instances) do
            local instance = i.instance
            local callback = i.callback
            local upd_cb   = i.upd_cb
            local update   = instance:rawReceive(1)
            local threads  = i.threads
            if not update then
                goto continue
            end

            local extra = update['@extra']
            update['@extra'] = nil
            if extra and upd_cb[extra] then
                local cb = upd_cb[extra]
                if type(cb) == 'function' then
                    cb(self, update)
                else
                    coroutine.resume(cb, self, update)
                    table.insert(threads, cb)
                end
                upd_cb[extra] = nil
                goto continue
            end

            callback(update)

            self:runCoros()

            ::continue::
        end
    end
end

function _M:send(request)
    return self.instance:send(request)
end

function _M:receive(request, timeout)
    timeout = tonumber(timeout) or 1
    return self.instance:rawReceive(request, timeout)
end

function _M:execute(request, callback)
    print ('execute', callback)
    if not type(request) == 'table' then
        if type(request) == 'function' or type(params) == 'thread' then
            callback = request
        end
        request = {}
    end
    if type(callback) == 'function' or type(params) == 'thread' then
        self.upd_id = self.upd_id +1
        request['@extra'] = self.upd_id
        self.upd_cb[self.upd_id] = callback
        self.instance:send(request)
    end
end

function _M:rawExecute(request)
    self.instance:rawExecute(request)
end

function _M:runCoros()
    local threads = self.threads
    for k, v in pairs(threads) do
        local status = coroutine.status(v)
        if status == 'dead' then
            table.remove(threads, k)
        elseif status == 'suspended' then
            coroutine.resume(v)
        end
    end
end

_M.instances = {}

function mt.__index(self, method)
    return function(instance, ...)
        local params, callback = ...
        if not type(params) == 'table' then
            if type(params) == 'function' or type(params) == 'thread' then
                callback = params
            end
            params = {}
        end
        params._ = method
        return instance:execute(params, callback)
    end
end

_M = setmetatable(_M, mt)

return _M
