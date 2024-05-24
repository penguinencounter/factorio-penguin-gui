local at_runtime = false

local function freeze()
    at_runtime = true
end

local function assert_const()
    local frame_name
    local anons = 0
    -- if we aren't sandboxed, get the calling method name
    if debug.getinfo then
        local n = 2
        while not frame_name do
            local frame = debug.getinfo(n, 'n')
            if frame then
                if frame.name then
                    frame_name = frame.name
                else
                    anons = anons + 1
                end
            else
                frame_name = '[frame unavailable]'
            end
            n = n + 1
        end
    else
        frame_name = '[name unavailable]'
    end
    if anons > 0 then
        frame_name = frame_name .. " (..." .. anons .. " anonymous)"
    end
    if at_runtime then
        error("Cannot call " .. frame_name .. " at runtime", 2)
    end
end

local function is_runtime() return at_runtime end

return {
    on_init = freeze,
    on_load = freeze,
    assert_const = assert_const,
    is_runtime = is_runtime
}