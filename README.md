# penguin-gui

An over-engineered Factorio GUI library 

## Features

### Performance
Compiled `penguin-gui` templates run *slightly* faster than other GUI libraries due to not recursively reading the template data. **This is probably not a useful difference unless you're rendering thousands of templates.**

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
