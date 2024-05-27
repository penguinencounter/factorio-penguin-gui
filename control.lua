local runtime   = require 'runtime'
local compiler  = require 'compile'
local types     = require 'types'
local events    = require 'events'
local blocks    = require 'components'.blocks
local build     = require 'components'.build
local auto_name = require 'components'.auto_name
local spec      = require 'spec'

local template  = blocks.ClosableWindow("ui_cmp_debug", "Playground", false)

template:sty {
    width = types.lazy(function(opt)
        local player = opt.player --[[@as LuaPlayer?]]
        if not player then return 600 end
        return math.ceil(player.display_resolution.width / player.display_scale)
    end),
    height = types.lazy(function(opt)
        local player = opt.player --[[@as LuaPlayer?]]
        if not player then return 300 end
        return math.ceil(player.display_resolution.height / player.display_scale)
    end),
}

local columns = template:add(blocks.hflow "columns"):sty { horizontal_spacing = 12 }

local input_half = columns:add(
    blocks.vframe("inside_shallow_frame", "input")
):sty { horizontally_stretchable = true, vertically_stretchable = true }
local input_header = input_half:add(
    blocks.hframe("subheader_frame", "header")
):sty { horizontally_stretchable = true }

local input_text = input_half:add {
    type = "text-box",
    name = "textbox",
    s = {
        horizontally_stretchable = true,
        vertically_stretchable = true,
        width = 0,
        minimal_width = 400,
    }
}

input_header:add(blocks.label("Input", "subheader_caption_label"))
input_header:add(blocks.pushx)
input_header:add {
    type = "sprite-button",
    style = "tool_button_red",
    tooltip = "Clear",
    sprite = "utility/trash",
}:on("click", function(event)
    local player = game.players[event.player_index]
    if not player then return end
    local window = player.gui.screen.ui_cmp_debug
    if not window then return end
    window.columns.input.textbox.text = ""
end)

local output_half = columns:add(
    blocks.vflow "output"
):sty { horizontally_stretchable = true, vertically_stretchable = true, vertical_spacing = 12 }

local func_output = output_half:add(
    blocks.vframe("inside_shallow_frame", "func_output")
):sty { horizontally_stretchable = true, vertically_stretchable = true }
local output_header = func_output:add(
    blocks.hframe("subheader_frame", "header")
):sty { horizontally_stretchable = true }
output_header:add(blocks.label("Output (code)", "subheader_caption_label"))
func_output:add {
    type = "text-box",
    name = "textbox",
    s = {
        horizontally_stretchable = true,
        vertically_stretchable = true,
        width = 0,
    },
    x = {
        read_only = true,
        word_wrap = true,
    }
}

local resources = output_half:add(
    blocks.vframe("inside_shallow_frame", "resources")
):sty { horizontally_stretchable = true, horizontally_squashable = true, vertically_stretchable = true }
local res_header = resources:add(
    blocks.hframe("subheader_frame", "header")
):sty { horizontally_stretchable = true }
res_header:add(blocks.label("Output (_RESOURCES)", "subheader_caption_label"))
local sbox = resources:add(blocks.scroll {
    h = "never",
    v = "auto",
    name = "sbox"
}):sty {
    horizontally_stretchable = true,
    vertically_stretchable = true,
    horizontally_squashable = true,
    vertically_squashable = true,
    padding = 6
}
local res_table = sbox:add {
    type = "table",
    column_count = 2,
    name = "res_table",
    draw_horizontal_line_after_headers = true,
    draw_horizontal_lines = true,
    draw_vertical_lines = true,
    s = {
        vertically_stretchable = true,
        horizontally_stretchable = true,
        horizontally_squashable = true,
        -- minimal_height = 100,
        -- minimal_width = 100,
    }
}
res_table:add(blocks.label "Index")
res_table:add(blocks.label "Value")
-- res_table:add(blocks.label "0")
-- res_table:add(blocks.hflow())
-- :sty { horizontally_squashable = true }
-- :add(blocks.label "Maecenas odio erat, dictum in leo quis, iaculis blandit urna. Curabitur aliquet dapibus efficitur. Mauris tempor risus diam, ac mattis mi accumsan vel. Cras ullamcorper eros vulputate, vulputate nisi at, dignissim massa. Pellentesque gravida, felis quis laoreet tempor, justo massa eleifend nisi, et aliquam dolor odio in nibh. Pellentesque ac risus quam. Sed a ante id quam vehicula hendrerit. Mauris euismod in elit quis tempus. In at lacus accumsan, lobortis libero vitae, molestie magna. Duis eleifend risus felis, eleifend porta sem mollis in. Morbi eget porta libero. Morbi sit amet bibendum leo. Ut eu lacus congue, vestibulum diam nec, vehicula.")
-- :sty { horizontally_squashable = true }

---@param target LuaGuiElement
local function header_style_runtime(target)
    target.style.horizontally_stretchable = true
end

local res_table_label = compiler.compile2({
    type = "label",
    caption = types.param "caption",
    s = { margin = 4, horizontally_squashable = true }
})

---@type ui.Handler
local function update(event)
    -- Grab the UI
    local player = game.players[event.player_index]
    if not player then return end
    local window = player.gui.screen.ui_cmp_debug
    if not window then return end

    -- Clear the output windows
    local func_out = window.columns.output.func_output
    local res_out = window.columns.output.resources
    func_out.textbox.text = "Compiling..."
    res_out.sbox.res_table.clear()

    -- Try to compile the input window
    local input = window.columns.input.textbox.text
    local func, parser_error = load(input, input, "t", {
        runtime = runtime,
        types = types,
        events = events,
        blocks = blocks,
        spec = spec,
        table = table,
        math = math,
        string = string,
        error = error,
        pairs = pairs,
        ipairs = ipairs,
        next = next,
        pcall = pcall,
        xpcall = xpcall,
        select = select,
        assert = assert,
        type = type,
        tostring = tostring,
        tonumber = tonumber,
        rawget = rawget,
        rawset = rawset,
        setmetatable = setmetatable,
        getmetatable = getmetatable,
    })
    if not func then
        func_out.header.style = "negative_subheader_frame"
        res_out.header.style = "negative_subheader_frame"
        header_style_runtime(func_out.header)
        header_style_runtime(res_out.header)
        func_out.textbox.text = "Error parsing input: " ..
            (parser_error --[[@as string]] or "<unknown error parsing input>")
        return
    end

    local ok, result = pcall(
        function()
            local result = func()
            if (not result) or (type(result) ~= "table") then error("Expected a template result from the input") end
            return result
        end)
    if not ok then
        func_out.header.style = "negative_subheader_frame"
        res_out.header.style = "negative_subheader_frame"
        header_style_runtime(func_out.header)
        header_style_runtime(res_out.header)
        func_out.textbox.text = "Error running input: " .. (result --[[@as string]] or "<unknown error running input>")
        return
    end

    local res = {
        set = {},
        rget = {}
    }
    local ok2, result2, source2 = pcall(function()
        return compiler.compile2(result, nil, res)
    end)
    if not ok2 then
        func_out.header.style = "negative_subheader_frame"
        res_out.header.style = "negative_subheader_frame"
        header_style_runtime(func_out.header)
        header_style_runtime(res_out.header)
        func_out.textbox.text = "Error compiling input: " ..
            (result2 --[[@as string]] or "<unknown error compiling input>")
        return
    end
    func_out.header.style = "subheader_frame"
    res_out.header.style = "subheader_frame"
    header_style_runtime(func_out.header)
    header_style_runtime(res_out.header)
    func_out.textbox.text = source2

    local res_table = res_out.sbox.res_table
    res_table_label(res_table, { caption = "ID" }).style.font = "default-bold"
    res_table_label(res_table, { caption = "Value" }).style.font = "default-bold"
    for i, v in ipairs(res.set) do
        res_table_label(res_table, { caption = tostring(i) })
        res_table_label(res_table, { caption = tostring(v) })
    end
end
_G.update = update

input_text:on("text_changed", update)

local c_debugger = compiler.compile2(template)

local function open_testing_interface()
    local player = game.player
    if not player then
        game.print("No player to open GUI for")
        return
    end
    local gui = player.gui.screen
    if gui.ui_cmp_debug then
        gui.ui_cmp_debug.destroy()
    end
    local window = c_debugger(gui, {
        player = player
    })
    window.force_auto_center()
end

remote.add_interface("penguingui", {
    open_testing_interface = function()
        local player = game.player
        if not player then
            game.print("No player to open GUI for")
            return
        end
        local gui = player.gui.screen
        if gui.ui_cmp_debug then
            gui.ui_cmp_debug.destroy()
        end
        local window = c_debugger(gui, {
            player = player
        })
        window.force_auto_center()
    end
})

local template2 = blocks.ClosableWindow("ui_cmp_debug2", "Example Window", true)
template2:add {
    type = "label",
    caption = types.lazy(function(_)
        return "For example, " .. game.tick
    end),
    s = {
        padding = types.const(12)
    },
    tooltip = types.lazy(function(_) return '' .. game.tick end) .. " is the current tick"
}
auto_name(template2)

local function test_live_render(player)
    if player.gui.screen.ui_cmp_debug2 then
        player.gui.screen.ui_cmp_debug2.destroy()
    end
    build(template2, player.gui.screen)
end

if settings.startup["penguin-gui-dev-mode"].value then
    commands.add_command("pgui-playground", "Open the Penguin GUI testing interface", open_testing_interface)
    commands.add_command("pgui-test", "Test the live rendering of a GUI. Intentionally includes warnings.",
        function(event)
            local player = game.players[event.player_index]
            if not player then return end
            test_live_render(player)
        end)
end

script.on_init(function()
    runtime.on_init()
end)
script.on_load(function()
    runtime.on_load()
end)
script.on_event(defines.events.on_player_created, runtime.on_player_created)
