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

local warnings = {}

local function warn(message)
    log("[WARNING] " .. message)
    if settings.startup["penguin-gui-dev-mode"].value then
        if game then
            game.print("[WARNING] " .. message, {
                sound_path = "utility/cannot_build",
                game_state = false,
                color = { r = 1, g = 0.8, b = 0 }
            })
        elseif not is_runtime() then
            table.insert(warnings, message)
        end
    end
end

---@param evt EventData.on_player_created
local function on_player_created(evt)
    if #warnings > 0 then
        local player = game.get_player(evt.player_index)
        if not player then return end
        player.print("Warnings while loading control.lua: (penguin gui developer mode)", { color = { r = 0.5, g = 1, b = 0 } })
        for _, warning in ipairs(warnings) do
            player.print("[warning] " .. warning, {
                sound_path = "utility/cannot_build",
                game_state = false,
                color = { r = 1, g = 0.8, b = 0 }
            })
        end
        warnings = {}
    end
end

return {
    on_init = freeze,
    on_load = freeze,
    on_player_created = on_player_created,
    assert_const = assert_const,
    is_runtime = is_runtime,
    warn = warn
}