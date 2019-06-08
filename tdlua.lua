--[[
tdluaJIT - pure lua interface with tdlib usign FFI
tdlua.lua
© Giuseppe Marino 2019 see LICENSE
--]]

local ffi = require 'ffi'
local json = require 'cjson'
local queue = require 'queue'

ffi.cdef[[
void* td_json_client_create ();
void td_json_client_send (void *client, const char *request);
const char* td_json_client_receive (void *client, double timeout);
const char* td_json_client_execute (void *client, const char *request);
void td_json_client_destroy (void *client);
void td_set_log_verbosity_level(int new_verbosity_level);
]]

local buffer_t = ffi.typeof(queue(ffi.typeof"char*"))

local tdlua_t = [[
struct {
    void* client;
    $ updatesBuffer;
    bool ready;
}
]]

local function new2old(obj)
    for k, v in pairs(obj) do
        if type(v) == 'table' then
            new2old(v)
        end
        if k == '@type' and not obj._ then
            obj._ = v
            obj['@type'] = nil
        end
    end
    return obj
end

local function old2new(obj)
    for k, v in pairs(obj) do
        if type(v) == 'table' then
            old2new(v)
        end
        if k == '_' and not obj['@type'] then
            obj['@type'] = v
            obj._ = nil
        end
    end
    return obj
end

local function pushUpdateBuffer(buffer, update)
    local jupd = json.encode(update)
    local cstr = ffi.C.malloc(#jupd+1)
    ffi.copy(cstr, jupd)
    buffer:push(cstr)
end

local function popUpdateBuffer(buffer)
    local cstr = buffer:pop()
    local jupd = ffi.string(cstr)
    ffi.C.free(cstr)
    return json.decode(jupd)
end

local tdlib = ffi.load('/usr/local/lib/libtdjson.so')
tdlib.td_set_log_verbosity_level(0)

local _M = {}

function _M.send(self, request)
    tdlib.td_json_client_send(self.client, json.encode(old2new(request)))
end

function _M.execute(self, request, timeout)
    timeout = tonumber(timeout) or 10
    local nonce = math.random(0, 0xFFFFFFFF)
    local extra = {
        nonce = nonce,
        extra = request['@extra']
    }
    extra = request['@extra']
    request['@extra'] = nonce
    self:send(request)

    local start = os.time()

    while os.time() - start < timeout do
        local update = self:rawReceive(timeout)
        if update['@extra'] == nonce then
            update['@extra'] = extra
            return update
        end
        pushUpdateBuffer(self.updatesBuffer, update)
    end

end

function _M.rawExecute(self, request)
    local resp = ffi.string(tdlib.td_json_client_execute(self.client, json.encode(old2new(request))))
    return new2old(json.decode(resp))
end

function _M.rawReceive(self, timeout)
   local resp = tdlib.td_json_client_receive(self.client, timeout or 10)
   if resp == nil then
       return
   end
   return new2old(json.decode(ffi.string(resp)))
end

function _M.receive(self, timeout)
    ---[[
    if not self.updatesBuffer:empty()  then
        return popUpdateBuffer(self.updatesBuffer)
    end
    --]]

    return self:rawReceive(timeout)
end

function _M.destroy(self)
    print 'destory called'
    if self.ready then
        print 'client is ready, closing'
        self:send({_='close'})
        while self.ready do
            local update = self:rawReceive()
            pushUpdateBuffer(self.updatesBuffer, update)
            self:checkAuthState(update)
        end
    end
    tdlib.td_json_client_destroy(self.client)
end

function _M.checkAuthState(self, update)
    if update['@type'] == 'updateAuthorizationState' then
        if not self.ready and update['authorization_state']['@type'] == 'authorizationStateReady' then
            --TODO load updates buffer
            self.ready = true
        elseif update['authorization_state']['@type'] == 'authorizationStateClosed' then
            --TODO save updates buffer
            self:emptyUpdatesBuffer()
            self.ready = false
        end
    end
end

function _M.emptyUpdatesBuffer(self)
    while not self.updatesBuffer:empty() do
        popUpdateBuffer(updatesBuffer)
    end
end

local mt = {}

function mt.__new(self)
    self = ffi.new(self)
    self.client = tdlib.td_json_client_create();
    return self
end


function mt.__gc(self)
    self:destroy()
end

mt.__index = _M
return ffi.metatype(ffi.typeof(tdlua_t, buffer_t), mt)
