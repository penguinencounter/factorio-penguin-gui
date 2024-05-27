local pgui = require "__penguin-gui__.pgui"
local flib_gui = require "__flib__.gui-lite"


local test_pgui_perf
do
    local pg_root = pgui.blocks.ClosableWindow("perf_test_a", "Performance test")
    pg_root:add(pgui.blocks.table(18, "table"))
    local add_pg_root = pgui.compile(pg_root)

    local component = pgui.ElementSpec.new {
        type = "flow",
        direction = "vertical",
        s = {
            vertical_spacing = 0,
            width = 32
        },
        c = {
            {
                type = "sprite",
                sprite = "technology/"..pgui.param "tech_id",
                elem_tooltip = {
                    type = "technology",
                    name = pgui.param "tech_id"
                },
                s = {
                    stretch_image_to_widget_size = true,
                    width = 32,
                    height = 32
                }
            },
            {
                type = "progressbar",
                value = pgui.param "progress",
                s = {
                    horizontally_stretchable = true,
                    height = 8
                }
            }
        }
    }
    local add_component = pgui.compile(component)

    ---@param player LuaPlayer
    function test_pgui_perf(player)
        if player.gui.screen.perf_test_a then
            player.gui.screen.perf_test_a.destroy()
        end
        local ui = add_pg_root(player.gui.screen)
        local table = ui.table

        local techs = player.force.technologies
        local tech_list = {}
        for tech_id in pairs(techs) do
            tech_list[#tech_list+1] = tech_id
        end

        local profile = game.create_profiler()
        for i = 1, 100 do
            table.clear()
            for j = 1, 1000 do
                local n = (i * 1000) + j
                local tech_id = tech_list[(n % #tech_list) + 1]
                local progress = (n % 100) / 100
                add_component(table, {tech_id = tech_id, progress = progress})
            end
        end
        profile.stop()
        game.print({"", "PGui perf: ", profile})
    end
end

local test_flib_perf
do
    ---@type GuiElemDef
    local fl_root = {
        type = "frame",
        style = "inside_shallow_frame",
        direction = "vertical",
        name = "perf_test_b",
        children = {
            {
                type = "table",
                name = "table",
                column_count = 18,
                children = {}
            }
        }
    }

    ---@type GuiElemDef
    local component = {
        type = "flow",
        direction = "vertical",
        ---@diagnostic disable-next-line: missing-fields
        style_mods = {
            vertical_spacing = 0,
            width = 32
        },
        children = {
            {
                type = "sprite",
                sprite = "technology/",
                elem_tooltip = {
                    type = "technology",
                    name = "?"
                },
                ---@diagnostic disable-next-line: missing-fields
                style_mods = {
                    stretch_image_to_widget_size = true,
                    width = 32,
                    height = 32
                }
            },
            {
                type = "progressbar",
                value = 0,
                ---@diagnostic disable-next-line: missing-fields
                style_mods = {
                    horizontally_stretchable = true,
                    height = 8
                }
            }
        }
    }
    ---@param player LuaPlayer
    function test_flib_perf(player)
        
        if player.gui.screen.perf_test_b then
            player.gui.screen.perf_test_b.destroy()
            return
        end
        local ui = flib_gui.add(player.gui.screen, fl_root)
        local table = ui.table

        local techs = player.force.technologies
        local tech_list = {}
        for tech_id in pairs(techs) do
            tech_list[#tech_list+1] = tech_id
        end

        local profile = game.create_profiler()
        for i = 1, 100 do
            table.clear()
            for j = 1, 1000 do
                local n = (i * 1000) + j
                local tech_id = tech_list[(n % #tech_list) + 1]
                local progress = (n % 100) / 100
                component.children[1].sprite = "technology/"..tech_id
                component.children[1].elem_tooltip.name = tech_id
                component.children[2].value = progress
                flib_gui.add(table, component)
            end
        end
        profile.stop()
        game.print({"", "Flib perf: ", profile})
    end
end

---@param target fun(player: LuaPlayer)
local function cmd_intermediate(target)
    ---@param cmdd CustomCommandData
    return function (cmdd)
        local player = game.players[cmdd.player_index]
        if not player then return end
        target(player)
    end
end

commands.add_command("pgui_perf", "Run a performance test of PGui", cmd_intermediate(test_pgui_perf))
commands.add_command("flib_perf", "Run a performance test of FLib", cmd_intermediate(test_flib_perf))