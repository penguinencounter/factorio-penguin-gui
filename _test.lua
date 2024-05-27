local function target() end
local function proxy(func)
    print(require 'serpnt'.block(debug.getinfo(func)))
end

proxy(target)