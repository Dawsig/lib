```lua
local Cresent = loadstring(game:HttpGet("https://your-host/CresentLibrary_Pro.lua"))()

local Window = Cresent:CreateWindow({
    Title = "Cresent",
    SubTitle = "Example UI",
    Loader = true,
})

local Main = Window:CreateTab({ Name = "Main", Icon = "⌂" })

Main:CreateSection("Getting Started")
Main:CreateLabel({ Text = "This is a label." })

Main:CreateButton({
    Title = "Notify",
    Callback = function()
        Window:Notify({
            Title = "Cresent",
            Content = "Button pressed.",
            Type = "success",
            Duration = 3,
        })
    end,
})

Main:CreateToggle({
    Title = "Enable Feature",
    Default = false,
    Callback = function(state)
        print("Toggle:", state)
    end,
})

Main:CreateSlider({
    Title = "Speed",
    Min = 0,
    Max = 100,
    Default = 35,
    Prefix = "x",
    Callback = function(value)
        print("Slider:", value)
    end,
})

Main:CreateDropdown({
    Title = "Mode",
    Options = { "Easy", "Normal", "Hard" },
    Default = "Normal",
    Callback = function(value)
        print("Selected:", value)
    end,
})

Main:CreateKeybind({
    Title = "Open/Close",
    Default = Enum.KeyCode.RightShift,
    Callback = function()
        Window:Toggle()
    end,
})
```
