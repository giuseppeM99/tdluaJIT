--[[
lds - LuaJIT Data Structures

Copyright (c) 2012 Evan Wies.  All righs reserved.
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

[ MIT license: http://www.opensource.org/licenses/mit-license.php ]

Queue

TODO: documentation here

See ArrayStack at opendatastructures.org:
http://opendatastructures.org/ods-cpp/2_1_Fast_Stack_Operations_U.html

TODO: bounds check (return nil or error?) [NIL]
TODO: allocator [i did it :)]
TODO: iterator
TODO: full __index and __newindex?

--]]

local lds = require 'allocator'

local ffi = require 'ffi'
local C = ffi.C


local QueueT_cdef = [[
struct {
    $   *a;
    int alength;
    int j;
    int n;
}
]]


local function QueueT__resize( q, reserve_n )
    local blength = math.max( 1, reserve_n or (2 * q.n) )
    if q.alength >= blength then return end

    local new_data = q.__alloc:reallocate(q.a, blength *q._ct_size)
    q.a = ffi.cast(q.a, new_data)
    q.alength = blength
    --[[
    local b = ffi.cast( q.a, q.__alloc:allocate( blength * q._ct_size ) )
    local k = 0
    while k < q.n do
        local idx = (q.j + k) % q.alength
        b[k] = q.a[idx]
        k = k + 1
    end
    q.__alloc:deallocate( q.a )
    q.a = b
    q.alength = blength
    --]]
end


local QueueT_mt = {

    __new = function( qt )
        return ffi.new( qt, {
            a = qt.__alloc:allocate( 1 * qt._ct_size ),
            alength = 1,
            n = 0,
            j = 0,
        })
    end,

    __gc = function( self )
        self.__alloc:deallocate( self.a )
    end,

    __len = function( self )
        return self.n
    end,

    __index = {

        size = function( self )
            return self.n
        end,

        capacity = function( self )
            return math.floor( self.alength / self._ct_size )
        end,

        reserve = function( self, n )
            QueueT__resize( self, n )
        end,

        empty = function( self )
            return self.n == 0
        end,

        get_front = function( self )
            lds.assert( self.n ~= 0, "get_front: Queue is empty" )
            return self.a[self.j]
        end,

        get_back = function( self )
            lds.assert( self.n ~= 0, "get_back: Queue is empty" )
            local idx = (self.j + (self.n - 1)) % self.alength
            return self.a[idx]
        end,

        push = function( self, x )
            if self.n + 1 > self.alength then QueueT__resize(self) end
            self.a[(self.j+self.n) % self.alength] = x
            self.n = self.n + 1
            return true
        end,

        pop = function( self )
            lds.assert( self.n ~= 0, "pop_front: Queue is empty" )
            local x = self.a[self.j]
            self.j = (self.j + 1) % self.alength
            self.n = self.n - 1
            if self.alength >= (3 * self.n) then QueueT__resize(self) end
            return x
        end,

        clear = function( self )
            self.n = 0
            self.j = 0
        end,
    },
}


function lds.QueueT( ct )
    if type(ct) ~= 'cdata' then error("argument 1 is not a valid 'cdata'") end

    -- clone the metatable and insert type-specific data
    local qt_mt = lds.simple_deep_copy(QueueT_mt)
    qt_mt.__index._ct = ct
    qt_mt.__index._ct_size = ffi.sizeof(ct)
    qt_mt.__index.__alloc = lds.MallocAllocator(ct)

    local qt = ffi.typeof( QueueT_cdef, ct )
    return ffi.metatype( qt, qt_mt )
end


function lds.Queue( ct )
    return lds.QueueT( ct )()
end


-- Return the lds API
return lds.Queue
