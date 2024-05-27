# penguin-gui

An over-engineered Factorio GUI library 

## Features

### Performance
Compiled `penguin-gui` templates run *slightly* faster than other GUI libraries.
To test this, I ran a benchmark with 100000 components (a flow containing sprite and progressbar). The relevant `add` or `add_component` function was called 100000 times.

The benchmark code is available in `bench.lua`. flib is required.

| Library | Time (ms) |
| --- | --- |
| `penguin-gui` | 3096.2 |
| `flib` | 3296.3 |

<details>
<summary>Benchmark structures</summary>

This is the `pgui` structure:
```lua
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
```

This is the `flib` structure:
```lua
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
```

For `flib_gui`, prior to calling `add`, the `sprite` and `progressbar` elements must be modified to set the correct values.
```lua
component.children[1].sprite = "technology/"..tech_id
component.children[1].elem_tooltip.name = tech_id
component.children[2].value = progress
```

</details>

### Flexibility
Use one template for many variations of the same component with parameters.

```lua
local component = {
    type = "label",
    caption = pgui.param 'caption'
}
local add_component = pgui.compile(component)

-- later...
add_component(gui, {caption = "hello, world!"})
add_component(gui, {caption = "how are you?"})
```

## Documentation
soonTM (look at `bench.lua` for an example, or `control.lua` (messy and hard to read, sorry))
