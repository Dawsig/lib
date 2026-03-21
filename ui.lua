-- Cresent Library Pro
-- Clean, functional, mobile-friendly UI library for Roblox
-- API style: Tab:CreateDropdown({ Title = "...", Options = {...}, Default = ..., Callback = function(Value) end })

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local function getPlayerGui()
    if not LocalPlayer then
        return nil
    end

    local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:FindFirstChild("PlayerGui")
    if gui then
        return gui
    end

    local ok, found = pcall(function()
        return LocalPlayer:WaitForChild("PlayerGui", 2)
    end)

    if ok then
        return found
    end

    return nil
end

local Library = {}
Library.__index = Library
Library.Name = "Cresent"
Library.Version = "4.0.0"

Library.DefaultTheme = {
    Background = Color3.fromRGB(12, 12, 14),
    Panel = Color3.fromRGB(18, 18, 22),
    Sidebar = Color3.fromRGB(20, 20, 26),
    Element = Color3.fromRGB(29, 29, 35),
    ElementHover = Color3.fromRGB(38, 38, 46),
    Stroke = Color3.fromRGB(52, 52, 62),
    Text = Color3.fromRGB(245, 245, 245),
    SubText = Color3.fromRGB(172, 172, 182),
    Accent = Color3.fromRGB(86, 214, 190),
    Accent2 = Color3.fromRGB(124, 158, 255),
    Success = Color3.fromRGB(96, 219, 133),
    Warning = Color3.fromRGB(255, 196, 84),
    Danger = Color3.fromRGB(255, 88, 88),
    Shadow = Color3.fromRGB(0, 0, 0),
}

pcall(function()
    local env = getgenv and getgenv() or _G
    env.Cresent = Library
end)

local function create(className, properties)
    local inst = Instance.new(className)
    if properties then
        for key, value in pairs(properties) do
            inst[key] = value
        end
    end
    return inst
end

local function clamp(n, min, max)
    if n < min then return min end
    if n > max then return max end
    return n
end

local function round(n, decimals)
    decimals = decimals or 0
    local p = 10 ^ decimals
    return math.floor(n * p + 0.5) / p
end

local function tween(inst, tweenInfo, props)
    local t = TweenService:Create(inst, tweenInfo, props)
    t:Play()
    return t
end

local function safeParent()
    local gui = getPlayerGui()
    if gui then
        return gui
    end

    local ok, core = pcall(function()
        return CoreGui
    end)
    if ok and core then
        return core
    end

    return nil
end

local function themeFrom(value)
    local theme = {}
    for k, v in pairs(Library.DefaultTheme) do
        theme[k] = v
    end

    if typeof(value) == "table" then
        for k, v in pairs(value) do
            theme[k] = v
        end
    end

    return theme
end

local function makeCorner(parent, radius)
    return create("UICorner", {
        CornerRadius = radius or UDim.new(0, 10),
        Parent = parent,
    })
end

local function makeStroke(parent, color, thickness, transparency)
    return create("UIStroke", {
        Parent = parent,
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
    })
end

local function makePadding(parent, l, r, t, b)
    return create("UIPadding", {
        Parent = parent,
        PaddingLeft = UDim.new(0, l or 0),
        PaddingRight = UDim.new(0, r or 0),
        PaddingTop = UDim.new(0, t or 0),
        PaddingBottom = UDim.new(0, b or 0),
    })
end

local function fmtKey(key)
    if typeof(key) ~= "EnumItem" or key.EnumType ~= Enum.KeyCode or key == Enum.KeyCode.Unknown then
        return "NONE"
    end
    local name = key.Name:gsub("Left", ""):gsub("Right", "")
    return string.upper(name)
end

local function isTouchDevice()
    return UserInputService.TouchEnabled
end

local function viewport()
    local cam = workspace.CurrentCamera
    if not cam then
        cam = workspace:WaitForChild("Camera", 5) or workspace.CurrentCamera
    end
    if not cam then
        return Vector2.new(1280, 720)
    end
    return cam.ViewportSize
end

local function autoScale(vp)
    local shortest = math.min(vp.X, vp.Y)
    local base = shortest / 1000
    if isTouchDevice() then
        base = base + 0.04
    end
    return clamp(base, 0.72, 1.10)
end

local function normalizeOptions(options)
    local list = {}
    if typeof(options) ~= "table" then
        return list
    end

    for i, option in ipairs(options) do
        if typeof(option) == "table" then
            local text = option.Text or option.Label or option.Name or option.Value or ("Option " .. i)
            local value = option.Value
            if value == nil then
                value = option.Text or option.Label or option.Name or option.Value
            end
            table.insert(list, {
                Text = tostring(text),
                Value = value,
            })
        else
            table.insert(list, {
                Text = tostring(option),
                Value = option,
            })
        end
    end

    return list
end

local function toastColor(theme, level)
    level = tostring(level or "info"):lower()
    if level == "success" then
        return theme.Success
    elseif level == "warning" then
        return theme.Warning
    elseif level == "error" or level == "danger" then
        return theme.Danger
    end
    return theme.Accent
end

local function extractTextSizeForParagraph(label)
    local abs = label.AbsoluteSize
    local lines = math.max(1, math.ceil(abs.Y / 14))
    return lines
end

function Library:CreateWindow(config)
    config = config or {}

    local window = setmetatable({}, self)
    window.Config = config
    window.Theme = themeFrom(config.Theme)
    window.Title = tostring(config.Title or "Cresent")
    window.SubTitle = tostring(config.SubTitle or config.Subtitle or "Mobile-friendly UI")
    window.Parent = config.Parent or safeParent()
    window.AutoScale = config.AutoScale ~= false
    window.UseLoader = config.Loader ~= false
    window.Visible = true
    window._closed = false
    window._connections = {}
    window._tabs = {}
    window._activeTab = nil
    window._dragging = false
    window._dragStart = nil
    window._dragOrigin = nil

    assert(window.Parent, "Cresent: no GUI parent available. Use this on the client.")

    local theme = window.Theme
    local viewportPadding = isTouchDevice() and 14 or 20
    local baseSize = isTouchDevice() and Vector2.new(920, 620) or Vector2.new(940, 640)

    local screenGui = create("ScreenGui", {
        Name = window.Title .. "_Cresent",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = window.Parent,
    })

    local root = create("Frame", {
        Name = "Root",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(baseSize.X, baseSize.Y),
        Parent = screenGui,
    })

    local scaleObject = create("UIScale", {
        Scale = 1,
        Parent = root,
    })

    local shadow = create("Frame", {
        Name = "Shadow",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 26, 1, 26),
        Parent = root,
    })
    makeCorner(shadow, UDim.new(0, 22))

    local main = create("Frame", {
        Name = "Main",
        BackgroundColor3 = theme.Background,
        Size = UDim2.fromScale(1, 1),
        ClipsDescendants = true,
        Parent = root,
    })
    makeCorner(main, UDim.new(0, 22))
    makeStroke(main, theme.Stroke, 1, 0)

    local sidebarWidth = isTouchDevice() and 160 or 180

    local sidebar = create("Frame", {
        Name = "Sidebar",
        BackgroundColor3 = theme.Sidebar,
        Size = UDim2.new(0, sidebarWidth, 1, 0),
        Parent = main,
    })
    makeCorner(sidebar, UDim.new(0, 22))

    local content = create("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(sidebarWidth, 0),
        Size = UDim2.new(1, -sidebarWidth, 1, 0),
        Parent = main,
    })

    local header = create("Frame", {
        Name = "Header",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, isTouchDevice() and 56 or 52),
        Parent = main,
    })

    local dragHandle = create("TextButton", {
        Name = "DragHandle",
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = header,
        ZIndex = 10,
    })

    local titleLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(18, 14),
        Size = UDim2.new(1, -120, 0, 22),
        Font = Enum.Font.GothamBold,
        Text = window.Title,
        TextColor3 = theme.Text,
        TextSize = isTouchDevice() and 20 or 22,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header,
        ZIndex = 11,
    })

    local subtitleLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(18, 34),
        Size = UDim2.new(1, -120, 0, 14),
        Font = Enum.Font.Gotham,
        Text = window.SubTitle,
        TextColor3 = theme.Accent,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header,
        ZIndex = 11,
    })

    local closeButton = create("TextButton", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -18, 0, 12),
        Size = UDim2.fromOffset(28, 28),
        Text = "×",
        Font = Enum.Font.GothamBold,
        TextColor3 = theme.SubText,
        TextSize = 24,
        AutoButtonColor = false,
        Parent = header,
        ZIndex = 11,
    })

    local minimizeButton = create("TextButton", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -52, 0, 12),
        Size = UDim2.fromOffset(28, 28),
        Text = "—",
        Font = Enum.Font.GothamBold,
        TextColor3 = theme.SubText,
        TextSize = 24,
        AutoButtonColor = false,
        Parent = header,
        ZIndex = 11,
    })

    local sidebarTitle = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(16, 14),
        Size = UDim2.new(1, -32, 0, 20),
        Font = Enum.Font.GothamBold,
        Text = window.Title,
        TextColor3 = theme.Text,
        TextSize = isTouchDevice() and 18 or 20,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = sidebar,
        ZIndex = 5,
    })

    local sidebarSub = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(16, 34),
        Size = UDim2.new(1, -32, 0, 14),
        Font = Enum.Font.GothamMedium,
        Text = window.SubTitle,
        TextColor3 = theme.Accent,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = sidebar,
        ZIndex = 5,
    })

    local profile = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 1, -56),
        Size = UDim2.new(1, -24, 0, 44),
        Parent = sidebar,
        ZIndex = 5,
    })

    local avatar = create("Frame", {
        BackgroundColor3 = theme.Element,
        Size = UDim2.fromOffset(36, 36),
        Parent = profile,
        ZIndex = 6,
    })
    makeCorner(avatar, UDim.new(1, 0))
    makeStroke(avatar, theme.Stroke, 1, 0.15)

    create("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = ("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=48&height=48&format=png"):format(LocalPlayer.UserId),
        Parent = avatar,
        ZIndex = 7,
    })

    create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(44, 2),
        Size = UDim2.new(1, -44, 0, 16),
        Font = Enum.Font.GothamSemibold,
        Text = LocalPlayer.Name,
        TextColor3 = theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = profile,
        ZIndex = 6,
    })

    create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(44, 18),
        Size = UDim2.new(1, -44, 0, 14),
        Font = Enum.Font.Gotham,
        Text = "Touch + Desktop",
        TextColor3 = theme.SubText,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = profile,
        ZIndex = 6,
    })

    local tabsScroll = create("ScrollingFrame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 72),
        Size = UDim2.new(1, 0, 1, -132),
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = theme.Accent,
        AutomaticCanvasSize = Enum.AutomaticSize.None,
        Parent = sidebar,
        ZIndex = 6,
    })
    create("UIListLayout", {
        Parent = tabsScroll,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    })
    makePadding(tabsScroll, 12, 12, 4, 4)

    local pagesHolder = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, isTouchDevice() and 56 or 52),
        Size = UDim2.new(1, 0, 1, -(isTouchDevice() and 56 or 52)),
        Parent = content,
    })

    local notificationHost = create("Frame", {
        Name = "Notifications",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.fromOffset(360, 320),
        Parent = screenGui,
        ZIndex = 100,
    })

    create("UIListLayout", {
        Parent = notificationHost,
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0, 8),
    })

    local dockButton = create("TextButton", {
        Name = "DockButton",
        BackgroundColor3 = theme.Background,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.fromOffset(54, 54),
        AutoButtonColor = false,
        Text = "C",
        Font = Enum.Font.GothamBlack,
        TextColor3 = theme.Text,
        TextSize = 20,
        Visible = false,
        Parent = screenGui,
        ZIndex = 200,
    })
    makeCorner(dockButton, UDim.new(1, 0))
    makeStroke(dockButton, theme.Stroke, 1, 0)

    local dockGlow = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 18, 1, 18),
        Position = UDim2.new(0, -9, 0, -9),
        Parent = dockButton,
        ZIndex = 199,
    })
    makeCorner(dockGlow, UDim.new(1, 0))
    makeStroke(dockGlow, theme.Accent, 1, 0.9)

    local loader = nil
    if window.UseLoader then
        local overlay = create("Frame", {
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 0.25,
            Size = UDim2.fromScale(1, 1),
            Parent = screenGui,
            ZIndex = 400,
        })

        local card = create("Frame", {
            BackgroundColor3 = theme.Panel,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(420, 190),
            Parent = overlay,
            ZIndex = 401,
        })
        makeCorner(card, UDim.new(0, 18))
        makeStroke(card, theme.Stroke, 1, 0)

        local loaderTitle = create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(20, 18),
            Size = UDim2.new(1, -40, 0, 24),
            Font = Enum.Font.GothamBold,
            Text = window.Title,
            TextColor3 = theme.Text,
            TextSize = 22,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card,
            ZIndex = 402,
        })

        local loaderText = create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(20, 44),
            Size = UDim2.new(1, -40, 0, 18),
            Font = Enum.Font.Gotham,
            Text = "Preparing interface...",
            TextColor3 = theme.SubText,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card,
            ZIndex = 402,
        })

        local barBg = create("Frame", {
            BackgroundColor3 = Color3.fromRGB(36, 36, 44),
            Position = UDim2.fromOffset(20, 122),
            Size = UDim2.new(1, -40, 0, 8),
            Parent = card,
            ZIndex = 402,
        })
        makeCorner(barBg, UDim.new(1, 0))

        local barFill = create("Frame", {
            BackgroundColor3 = theme.Accent,
            Size = UDim2.new(0, 0, 1, 0),
            Parent = barBg,
            ZIndex = 403,
        })
        makeCorner(barFill, UDim.new(1, 0))

        local percent = create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(20, 138),
            Size = UDim2.new(1, -40, 0, 16),
            Font = Enum.Font.GothamMedium,
            Text = "0%",
            TextColor3 = theme.Accent,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = card,
            ZIndex = 402,
        })

        loader = {
            Overlay = overlay,
            Card = card,
            Title = loaderTitle,
            Subtitle = loaderText,
            Bar = barFill,
            Percent = percent,
            SetText = function(_, text)
                loaderText.Text = tostring(text or "")
            end,
            SetProgress = function(_, progress)
                progress = clamp(progress or 0, 0, 1)
                barFill.Size = UDim2.new(progress, 0, 1, 0)
                percent.Text = tostring(math.floor(progress * 100)) .. "%"
            end,
            Finish = function(self)
                self:SetProgress(1)
                task.wait(0.12)
                local fade1 = tween(overlay, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    BackgroundTransparency = 1,
                })
                tween(card, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    BackgroundTransparency = 1,
                })
                fade1.Completed:Wait()
                if overlay.Parent then
                    overlay:Destroy()
                end
            end,
        }
    end

    local function updateCanvas(page)
        local layout = page:FindFirstChildOfClass("UIListLayout")
        if layout then
            page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 18)
        end
    end

    local function activateTab(tabData)
        if window._activeTab == tabData then
            return
        end

        for _, tab in ipairs(window._tabs) do
            if tab.Page then
                tab.Page.Visible = false
            end
            tween(tab.Button, TweenInfo.new(0.18), {
                BackgroundColor3 = theme.Element,
                TextColor3 = theme.SubText,
            })
            tween(tab.Indicator, TweenInfo.new(0.18), {
                BackgroundTransparency = 1,
            })
        end

        window._activeTab = tabData
        tabData.Page.Visible = true
        tabData.Page.Position = UDim2.fromOffset(0, 10)
        tween(tabData.Button, TweenInfo.new(0.20), {
            BackgroundColor3 = theme.ElementHover,
            TextColor3 = theme.Text,
        })
        tween(tabData.Indicator, TweenInfo.new(0.20), {
            BackgroundTransparency = 0,
        })
        tween(tabData.Page, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = UDim2.fromOffset(0, 0),
        })
    end

    local function setVisible(state)
        window.Visible = state
        root.Visible = state
        dockButton.Visible = not state
    end

    local function updateResponsive()
        local vp = viewport()
        local s = autoScale(vp)
        scaleObject.Scale = s

        local maxW = vp.X - (viewportPadding * 2)
        local maxH = vp.Y - (viewportPadding * 2)
        local w = math.min(baseSize.X, math.max(320, maxW))
        local h = math.min(baseSize.Y, math.max(420, maxH))
        root.Size = UDim2.fromOffset(w, h)

        sidebarWidth = isTouchDevice() and math.max(150, math.floor(w * 0.19)) or 180
        sidebar.Size = UDim2.new(0, sidebarWidth, 1, 0)
        content.Position = UDim2.fromOffset(sidebarWidth, 0)
        content.Size = UDim2.new(1, -sidebarWidth, 1, 0)
        pagesHolder.Position = UDim2.fromOffset(0, isTouchDevice() and 56 or 52)
        pagesHolder.Size = UDim2.new(1, 0, 1, -(isTouchDevice() and 56 or 52))
        dockButton.Size = isTouchDevice() and UDim2.fromOffset(58, 58) or UDim2.fromOffset(54, 54)
    end

    local function clampWindowToScreen()
        local vp = viewport()
        local abs = root.AbsoluteSize
        local pos = root.AbsolutePosition

        local halfW = abs.X / 2
        local halfH = abs.Y / 2

        local left = clamp(pos.X, viewportPadding, math.max(viewportPadding, vp.X - abs.X - viewportPadding))
        local top = clamp(pos.Y, viewportPadding, math.max(viewportPadding, vp.Y - abs.Y - viewportPadding))

        root.Position = UDim2.fromOffset(left + halfW, top + halfH)
    end

    local function beginDrag(input)
        window._dragging = true
        window._dragStart = input.Position
        window._dragOrigin = root.AbsolutePosition
    end

    local function handleDrag(input)
        if not window._dragging then
            return
        end

        local delta = input.Position - window._dragStart
        local vp = viewport()
        local abs = root.AbsoluteSize
        local x = window._dragOrigin.X + delta.X
        local y = window._dragOrigin.Y + delta.Y

        x = clamp(x, viewportPadding, math.max(viewportPadding, vp.X - abs.X - viewportPadding))
        y = clamp(y, viewportPadding, math.max(viewportPadding, vp.Y - abs.Y - viewportPadding))

        root.Position = UDim2.fromOffset(x + abs.X / 2, y + abs.Y / 2)
    end

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            beginDrag(input)
        end
    end)

    dragHandle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            window._dragging = false
            clampWindowToScreen()
        end
    end)

    table.insert(window._connections, UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            handleDrag(input)
        end
    end))

    table.insert(window._connections, RunService.RenderStepped:Connect(function()
        if window.AutoScale then
            local target = autoScale(viewport())
            if math.abs(scaleObject.Scale - target) > 0.001 then
                scaleObject.Scale = scaleObject.Scale + (target - scaleObject.Scale) * 0.12
            end
        end
    end))

    table.insert(window._connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        updateResponsive()
    end))

    table.insert(window._connections, closeButton.MouseButton1Click:Connect(function()
        window:Destroy()
    end))

    table.insert(window._connections, minimizeButton.MouseButton1Click:Connect(function()
        setVisible(false)
    end))

    table.insert(window._connections, dockButton.MouseButton1Click:Connect(function()
        setVisible(true)
    end))

    function window:Notify(options)
        options = options or {}
        local title = tostring(options.Title or "Cresent")
        local body = tostring(options.Content or options.Description or options.Text or "Notification")
        local duration = tonumber(options.Duration) or 3
        local level = options.Type or options.Level or "info"
        local accent = toastColor(theme, level)

        local holder = create("Frame", {
            BackgroundColor3 = theme.Panel,
            Size = UDim2.fromOffset(isTouchDevice() and 320 or 340, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BorderSizePixel = 0,
            Parent = notificationHost,
            ZIndex = 110,
        })
        makeCorner(holder, UDim.new(0, 16))
        makeStroke(holder, theme.Stroke, 1, 0)

        local bar = create("Frame", {
            BackgroundColor3 = accent,
            Size = UDim2.new(0, 4, 1, 0),
            Parent = holder,
            ZIndex = 111,
        })
        makeCorner(bar, UDim.new(1, 0))

        local titleLabel = create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(16, 10),
            Size = UDim2.new(1, -28, 0, 18),
            Font = Enum.Font.GothamBold,
            Text = title,
            TextColor3 = theme.Text,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = holder,
            ZIndex = 112,
        })

        local bodyLabel = create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(16, 28),
            Size = UDim2.new(1, -28, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Font = Enum.Font.Gotham,
            Text = body,
            TextColor3 = theme.SubText,
            TextSize = 12,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = holder,
            ZIndex = 112,
        })
        makePadding(holder, 0, 0, 0, 12)

        holder.BackgroundTransparency = 1
        titleLabel.TextTransparency = 1
        bodyLabel.TextTransparency = 1
        bar.BackgroundTransparency = 1

        tween(holder, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
        tween(titleLabel, TweenInfo.new(0.16), {TextTransparency = 0})
        tween(bodyLabel, TweenInfo.new(0.16), {TextTransparency = 0})
        tween(bar, TweenInfo.new(0.16), {BackgroundTransparency = 0})

        task.delay(duration, function()
            if holder.Parent then
                tween(holder, TweenInfo.new(0.20, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
                tween(titleLabel, TweenInfo.new(0.14), {TextTransparency = 1})
                tween(bodyLabel, TweenInfo.new(0.14), {TextTransparency = 1})
                tween(bar, TweenInfo.new(0.14), {BackgroundTransparency = 1})
                task.wait(0.22)
                if holder.Parent then
                    holder:Destroy()
                end
            end
        end)

        return holder
    end

    window.Notification = window.Notify

    function window:SetTitle(text)
        window.Title = tostring(text or window.Title)
        titleLabel.Text = window.Title
        sidebarTitle.Text = window.Title
    end

    function window:SetSubtitle(text)
        window.SubTitle = tostring(text or window.SubTitle)
        subtitleLabel.Text = window.SubTitle
        sidebarSub.Text = window.SubTitle
    end

    function window:Show()
        setVisible(true)
    end

    function window:Hide()
        setVisible(false)
    end

    function window:Toggle()
        setVisible(not window.Visible)
    end

    function window:Destroy()
        if window._closed then
            return
        end
        window._closed = true

        for _, connection in ipairs(window._connections) do
            pcall(function()
                connection:Disconnect()
            end)
        end

        if screenGui and screenGui.Parent then
            screenGui:Destroy()
        end
    end

    function window:CreateTab(configOrName, icon)
        local configTab = configOrName
        local tabName = "Tab"
        local tabIcon = icon

        if typeof(configTab) == "table" then
            tabName = tostring(configTab.Name or configTab.Title or "Tab")
            tabIcon = configTab.Icon or configTab.Symbol or icon
        else
            tabName = tostring(configTab or "Tab")
        end

        local page = create("ScrollingFrame", {
            BackgroundTransparency = 1,
            Visible = false,
            Size = UDim2.fromScale(1, 1),
            CanvasSize = UDim2.fromOffset(0, 0),
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = theme.Accent,
            AutomaticCanvasSize = Enum.AutomaticSize.None,
            Parent = pagesHolder,
            ZIndex = 10,
        })

        local pageLayout = create("UIListLayout", {
            Parent = page,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, isTouchDevice() and 12 or 10),
        })

        makePadding(page, 2, 6, 2, 12)

        local tabButton = create("TextButton", {
            BackgroundColor3 = theme.Element,
            Size = UDim2.new(1, 0, 0, isTouchDevice() and 40 or 36),
            AutoButtonColor = false,
            Text = "",
            Parent = tabsScroll,
            ZIndex = 7,
        })
        makeCorner(tabButton, UDim.new(0, 10))
        makeStroke(tabButton, theme.Stroke, 1, 0)

        local indicator = create("Frame", {
            BackgroundColor3 = theme.Accent,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 6),
            Size = UDim2.new(0, 3, 1, -12),
            Parent = tabButton,
            ZIndex = 8,
        })
        makeCorner(indicator, UDim.new(1, 0))

        local tabText = create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(14, 0),
            Size = UDim2.new(1, -28, 1, 0),
            Font = Enum.Font.GothamSemibold,
            Text = (tabIcon and (tabIcon .. "  ") or "") .. tabName,
            TextColor3 = theme.SubText,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = tabButton,
            ZIndex = 8,
        })

        local tab = {
            Name = tabName,
            Icon = tabIcon,
            Button = tabButton,
            Page = page,
            Indicator = indicator,
            Layout = pageLayout,
        }

        table.insert(window._tabs, tab)

        tabButton.MouseButton1Click:Connect(function()
            activateTab(tab)
        end)

        table.insert(window._connections, pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            updateCanvas(page)
        end))

        local api = {}

        local function card(height)
            local item = create("Frame", {
                BackgroundColor3 = theme.Element,
                Size = UDim2.new(1, 0, 0, height or 42),
                Parent = page,
            })
            makeCorner(item, UDim.new(0, 12))
            makeStroke(item, theme.Stroke, 1, 0)
            return item
        end

        function api:CreateSection(text)
            local section = create("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 30),
                Parent = page,
            })
            create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(2, 6),
                Size = UDim2.new(1, -4, 0, 18),
                Font = Enum.Font.GothamBold,
                Text = tostring(text),
                TextColor3 = theme.Accent,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = section,
            })
            return section
        end

        function api:CreateDivider()
            return create("Frame", {
                BackgroundColor3 = theme.Stroke,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 1),
                Parent = page,
            })
        end

        function api:CreateLabel(config)
            if typeof(config) ~= "table" then
                config = { Text = tostring(config) }
            end

            local item = card(42)
            create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(14, 0),
                Size = UDim2.new(1, -28, 1, 0),
                Font = Enum.Font.Gotham,
                Text = tostring(config.Text or config.Title or ""),
                TextColor3 = theme.Text,
                TextSize = 13,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = item,
            })
            return item
        end

        function api:CreateParagraph(config)
            if typeof(config) ~= "table" then
                config = { Title = tostring(config) }
            end

            local item = create("Frame", {
                BackgroundColor3 = theme.Element,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = page,
            })
            makeCorner(item, UDim.new(0, 12))
            makeStroke(item, theme.Stroke, 1, 0)

            create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(14, 12),
                Size = UDim2.new(1, -28, 0, 18),
                Font = Enum.Font.GothamBold,
                Text = tostring(config.Title or ""),
                TextColor3 = theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = item,
            })

            local body = create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(14, 32),
                Size = UDim2.new(1, -28, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Font = Enum.Font.Gotham,
                Text = tostring(config.Content or config.Text or ""),
                TextColor3 = theme.SubText,
                TextSize = 12,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = item,
            })

            makePadding(item, 0, 0, 0, 12)

            local function refreshHeight()
                item.Size = UDim2.new(1, 0, 0, math.max(44, body.TextBounds.Y + 44))
            end

            body:GetPropertyChangedSignal("TextBounds"):Connect(refreshHeight)
            body:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshHeight)

            task.defer(function()
                refreshHeight()
                task.defer(refreshHeight)
            end)

            return item
        end

        function api:CreateButton(config)
            if typeof(config) ~= "table" then
                config = { Title = tostring(config) }
            end

            local item = create("TextButton", {
                BackgroundColor3 = theme.Element,
                Size = UDim2.new(1, 0, 0, isTouchDevice() and 44 or 40),
                AutoButtonColor = false,
                Text = "",
                Parent = page,
            })
            makeCorner(item, UDim.new(0, 12))
            makeStroke(item, theme.Stroke, 1, 0)

            local label = create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(14, 0),
                Size = UDim2.new(1, -28, 1, 0),
                Font = Enum.Font.GothamSemibold,
                Text = tostring(config.Title or config.Text or "Button"),
                TextColor3 = theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = item,
            })

            item.MouseEnter:Connect(function()
                tween(item, TweenInfo.new(0.14), { BackgroundColor3 = theme.ElementHover })
            end)
            item.MouseLeave:Connect(function()
                tween(item, TweenInfo.new(0.14), { BackgroundColor3 = theme.Element })
            end)

            item.MouseButton1Click:Connect(function()
                if typeof(config.Callback) == "function" then
                    config.Callback()
                end
            end)

            return {
                Instance = item,
                SetText = function(_, value)
                    label.Text = tostring(value)
                end,
            }
        end

        function api:CreateToggle(config)
            if typeof(config) ~= "table" then
                config = { Title = tostring(config) }
            end

            local titleText = tostring(config.Title or "Toggle")
            local state = config.Default == true
            local callback = typeof(config.Callback) == "function" and config.Callback or function() end

            local item = create("TextButton", {
                BackgroundColor3 = theme.Element,
                Size = UDim2.new(1, 0, 0, isTouchDevice() and 48 or 44),
                AutoButtonColor = false,
                Text = "",
                Parent = page,
            })
            makeCorner(item, UDim.new(0, 12))
            makeStroke(item, theme.Stroke, 1, 0)

            create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(14, 0),
                Size = UDim2.new(1, -92, 1, 0),
                Font = Enum.Font.GothamSemibold,
                Text = titleText,
                TextColor3 = theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = item,
            })

            local track = create("Frame", {
                BackgroundColor3 = state and theme.Accent or Color3.fromRGB(56, 56, 64),
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -14, 0.5, 0),
                Size = UDim2.fromOffset(44, 22),
                Parent = item,
            })
            makeCorner(track, UDim.new(1, 0))

            local knob = create("Frame", {
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                Position = state and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
                Size = UDim2.fromOffset(16, 16),
                Parent = track,
            })
            makeCorner(knob, UDim.new(1, 0))

            local function apply(value, fire)
                state = value == true
                tween(track, TweenInfo.new(0.18), {
                    BackgroundColor3 = state and theme.Accent or Color3.fromRGB(56, 56, 64),
                })
                tween(knob, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Position = state and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
                })

                if fire ~= false then
                    callback(state)
                end
            end

            item.MouseButton1Click:Connect(function()
                apply(not state, true)
            end)

            apply(state, true)

            return {
                Instance = item,
                Set = function(_, value)
                    apply(value, true)
                end,
                Get = function()
                    return state
                end,
            }
        end

        function api:CreateInput(config)
            if typeof(config) ~= "table" then
                config = { Title = tostring(config) }
            end

            local titleText = tostring(config.Title or "Input")
            local placeholder = tostring(config.Placeholder or "")
            local defaultText = tostring(config.Default or "")
            local callback = typeof(config.Callback) == "function" and config.Callback or function() end

            local item = create("Frame", {
                BackgroundColor3 = theme.Element,
                Size = UDim2.new(1, 0, 0, 60),
                Parent = page,
            })
            makeCorner(item, UDim.new(0, 12))
            makeStroke(item, theme.Stroke, 1, 0)

            create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(14, 8),
                Size = UDim2.new(1, -28, 0, 16),
                Font = Enum.Font.GothamMedium,
                Text = titleText,
                TextColor3 = theme.SubText,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = item,
            })

            local box = create("TextBox", {
                BackgroundColor3 = Color3.fromRGB(24, 24, 28),
                Position = UDim2.fromOffset(12, 28),
                Size = UDim2.new(1, -24, 0, 24),
                ClearTextOnFocus = false,
                PlaceholderText = placeholder,
                PlaceholderColor3 = theme.SubText,
                Text = defaultText,
                Font = Enum.Font.GothamMedium,
                TextColor3 = theme.Text,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = item,
            })
            makeCorner(box, UDim.new(0, 8))
            makeStroke(box, theme.Stroke, 1, 0.15)
            makePadding(box, 10, 10, 0, 0)

            box.FocusLost:Connect(function(enterPressed)
                if enterPressed then
                    callback(box.Text)
                end
            end)

            return {
                Instance = item,
                Set = function(_, value)
                    box.Text = tostring(value)
                end,
                Get = function()
                    return box.Text
                end,
            }
        end

        function api:CreateSlider(config)
            if typeof(config) ~= "table" then
                config = { Title = tostring(config) }
            end

            local titleText = tostring(config.Title or "Slider")
            local minValue = tonumber(config.Min or config.Minimum or 0) or 0
            local maxValue = tonumber(config.Max or config.Maximum or 100) or 100
            local decimals = tonumber(config.Decimals or 0) or 0
            local prefix = tostring(config.Prefix or "")
            local suffix = tostring(config.Suffix or "")
            local callback = typeof(config.Callback) == "function" and config.Callback or function() end

            if maxValue < minValue then
                minValue, maxValue = maxValue, minValue
            end

            local defaultValue = tonumber(config.Default)
            if defaultValue == nil then
                defaultValue = minValue
            end
            defaultValue = clamp(defaultValue, minValue, maxValue)
            defaultValue = round(defaultValue, decimals)

            local current = defaultValue
            local range = math.max(0.0001, maxValue - minValue)

            local item = create("Frame", {
                BackgroundColor3 = theme.Element,
                Size = UDim2.new(1, 0, 0, 68),
                Parent = page,
            })
            makeCorner(item, UDim.new(0, 12))
            makeStroke(item, theme.Stroke, 1, 0)

            create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(14, 8),
                Size = UDim2.new(1, -120, 0, 16),
                Font = Enum.Font.GothamMedium,
                Text = titleText,
                TextColor3 = theme.SubText,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = item,
            })

            local valueLabel = create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(1, -86, 0, 8),
                Size = UDim2.fromOffset(72, 16),
                Font = Enum.Font.GothamBold,
                Text = prefix .. tostring(current) .. suffix,
                TextColor3 = theme.Accent,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = item,
            })

            create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(14, 49),
                Size = UDim2.fromOffset(96, 12),
                Font = Enum.Font.Gotham,
                Text = "Min: " .. tostring(minValue),
                TextColor3 = theme.SubText,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = item,
            })

            create("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -14, 0, 49),
                Size = UDim2.fromOffset(96, 12),
                Font = Enum.Font.Gotham,
                Text = "Max: " .. tostring(maxValue),
                TextColor3 = theme.SubText,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = item,
            })

            local track = create("Frame", {
                BackgroundColor3 = Color3.fromRGB(50, 50, 58),
                Position = UDim2.fromOffset(14, 37),
                Size = UDim2.new(1, -28, 0, 5),
                Parent = item,
            })
            makeCorner(track, UDim.new(1, 0))

            local fill = create("Frame", {
                BackgroundColor3 = theme.Accent,
                Size = UDim2.new((current - minValue) / range, 0, 1, 0),
                Parent = track,
            })
            makeCorner(fill, UDim.new(1, 0))

            local hit = create("TextButton", {
                BackgroundTransparency = 1,
                Text = "",
                Size = UDim2.fromScale(1, 1),
                Parent = track,
            })

            local dragging = false

            local function setValue(newValue, fire)
                newValue = clamp(tonumber(newValue) or minValue, minValue, maxValue)
                newValue = round(newValue, decimals)
                current = newValue
                local percent = (current - minValue) / range
                fill.Size = UDim2.new(percent, 0, 1, 0)
                valueLabel.Text = prefix .. tostring(current) .. suffix
                if fire ~= false then
                    callback(current)
                end
            end

            local function applyFromX(x, fire)
                local percent = clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
                setValue(minValue + range * percent, fire)
            end

            hit.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    applyFromX(input.Position.X, true)
                end
            end)

            table.insert(window._connections, UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    applyFromX(input.Position.X, true)
                end
            end))

            table.insert(window._connections, UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end))

            setValue(current, true)

            return {
                Instance = item,
                Min = minValue,
                Max = maxValue,
                Default = defaultValue,
                Set = function(_, value)
                    setValue(value, true)
                end,
                Get = function()
                    return current
                end,
            }
        end

        function api:CreateDropdown(config)
            if typeof(config) ~= "table" then
                config = { Title = tostring(config) }
            end

            local titleText = tostring(config.Title or "Dropdown")
            local options = normalizeOptions(config.Options or config.Values or {})
            local callback = typeof(config.Callback) == "function" and config.Callback or function() end
            local maxVisible = tonumber(config.MaxVisible or 6) or 6
            local current = config.Default
            local expanded = false

            if current == nil and #options > 0 then
                current = options[1].Value
            end

            local item = create("Frame", {
                BackgroundColor3 = theme.Element,
                Size = UDim2.new(1, 0, 0, 42),
                ClipsDescendants = true,
                Parent = page,
            })
            makeCorner(item, UDim.new(0, 12))
            makeStroke(item, theme.Stroke, 1, 0)

            local click = create("TextButton", {
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                Size = UDim2.fromScale(1, 1),
                Parent = item,
            })

            create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(14, 0),
                Size = UDim2.new(0.52, -16, 1, 0),
                Font = Enum.Font.GothamSemibold,
                Text = titleText,
                TextColor3 = theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = item,
            })

            local selectedLabel = create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0.52, 0, 0, 0),
                Size = UDim2.new(0.48, -34, 1, 0),
                Font = Enum.Font.GothamBold,
                Text = "Select...",
                TextColor3 = theme.Accent,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = item,
            })

            local chevron = create("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -12, 0.5, 0),
                Size = UDim2.fromOffset(16, 16),
                Font = Enum.Font.GothamBold,
                Text = "⌄",
                TextColor3 = theme.SubText,
                TextSize = 16,
                Parent = item,
            })

            local listHolder = create("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(0, 42),
                Size = UDim2.new(1, 0, 0, 0),
                ClipsDescendants = true,
                Parent = item,
            })

            local list = create("ScrollingFrame", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                CanvasSize = UDim2.fromOffset(0, 0),
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = theme.Accent,
                Parent = listHolder,
            })
            local listLayout = create("UIListLayout", {
                Parent = list,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 6),
            })
            makePadding(list, 10, 10, 8, 8)

            local function refreshList()
                for _, child in ipairs(list:GetChildren()) do
                    if child:IsA("TextButton") then
                        child:Destroy()
                    end
                end

                for _, option in ipairs(options) do
                    local optionButton = create("TextButton", {
                        BackgroundColor3 = Color3.fromRGB(24, 24, 28),
                        Size = UDim2.new(1, 0, 0, 28),
                        AutoButtonColor = false,
                        Text = tostring(option.Text),
                        Font = Enum.Font.GothamMedium,
                        TextColor3 = theme.SubText,
                        TextSize = 12,
                        Parent = list,
                    })
                    makeCorner(optionButton, UDim.new(0, 8))

                    optionButton.MouseEnter:Connect(function()
                        tween(optionButton, TweenInfo.new(0.12), { BackgroundColor3 = theme.ElementHover })
                    end)
                    optionButton.MouseLeave:Connect(function()
                        tween(optionButton, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(24, 24, 28) })
                    end)

                    optionButton.MouseButton1Click:Connect(function()
                        current = option.Value
                        selectedLabel.Text = tostring(option.Text)
                        callback(current)
                        expanded = false
                        tween(item, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                            Size = UDim2.new(1, 0, 0, 42),
                        })
                        tween(listHolder, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                            Size = UDim2.new(1, 0, 0, 0),
                        })
                        tween(chevron, TweenInfo.new(0.18), { Rotation = 0 })
                        task.defer(function()
                            if page.Parent then
                                page.CanvasSize = UDim2.fromOffset(0, 0)
                            end
                        end)
                    end)
                end

                list.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 8)
            end

            local function setCurrent(value, fire)
                current = value
                local found = nil
                for _, option in ipairs(options) do
                    if option.Value == value then
                        found = option
                        break
                    end
                end
                selectedLabel.Text = found and tostring(found.Text) or tostring(value or "Select...")
                if fire ~= false then
                    callback(current)
                end
            end

            local function toggleExpanded()
                expanded = not expanded
                local extra = 0
                if expanded then
                    extra = math.min(#options, maxVisible) * 34 + 18
                end

                tween(item, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Size = UDim2.new(1, 0, 0, 42 + extra),
                })
                tween(listHolder, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Size = UDim2.new(1, 0, 0, extra),
                })
                tween(chevron, TweenInfo.new(0.18), { Rotation = expanded and 180 or 0 })
                task.defer(function()
                    updateCanvas(page)
                end)
            end

            refreshList()
            setCurrent(current, false)

            click.MouseButton1Click:Connect(toggleExpanded)

            return {
                Instance = item,
                Set = function(_, value)
                    setCurrent(value, true)
                end,
                Get = function()
                    return current
                end,
                SetOptions = function(_, newOptions)
                    options = normalizeOptions(newOptions or {})
                    refreshList()
                    if current ~= nil then
                        setCurrent(current, false)
                    end
                    task.defer(function()
                        updateCanvas(page)
                    end)
                end,
                Refresh = function()
                    refreshList()
                    if current ~= nil then
                        setCurrent(current, false)
                    end
                    task.defer(function()
                        updateCanvas(page)
                    end)
                end,
            }
        end

        function api:CreateKeybind(config)
            if typeof(config) ~= "table" then
                config = { Title = tostring(config) }
            end

            local titleText = tostring(config.Title or "Keybind")
            local current = config.Default
            if typeof(current) ~= "EnumItem" or current.EnumType ~= Enum.KeyCode then
                current = Enum.KeyCode.RightShift
            end
            local callback = typeof(config.Callback) == "function" and config.Callback or function() end
            local listening = false

            local item = create("TextButton", {
                BackgroundColor3 = theme.Element,
                Size = UDim2.new(1, 0, 0, 40),
                AutoButtonColor = false,
                Text = "",
                Parent = page,
            })
            makeCorner(item, UDim.new(0, 12))
            makeStroke(item, theme.Stroke, 1, 0)

            create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(14, 0),
                Size = UDim2.new(1, -110, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = titleText,
                TextColor3 = theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = item,
            })

            local keyLabel = create("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -14, 0.5, 0),
                Size = UDim2.fromOffset(92, 18),
                Font = Enum.Font.GothamBold,
                Text = fmtKey(current),
                TextColor3 = theme.Accent,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = item,
            })

            item.MouseButton1Click:Connect(function()
                listening = true
                keyLabel.Text = "..."
            end)

            local conn = UserInputService.InputBegan:Connect(function(input, gpe)
                if gpe then
                    return
                end

                if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                    current = input.KeyCode
                    keyLabel.Text = fmtKey(current)
                    listening = false
                    callback(current)
                    return
                end

                if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == current then
                    callback(current)
                end
            end)
            table.insert(window._connections, conn)

            return {
                Instance = item,
                Set = function(_, key)
                    if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
                        current = key
                        keyLabel.Text = fmtKey(current)
                    end
                end,
                Get = function()
                    return current
                end,
            }
        end

        function api:CreateLabelText(text)
            return self:CreateLabel({ Text = text })
        end

        function api:CreateParagraphText(titleText, bodyText)
            return self:CreateParagraph({
                Title = titleText,
                Content = bodyText,
            })
        end

        tab.Api = api

        if #window._tabs == 1 then
            activateTab(tab)
        end

        updateCanvas(page)
        return api
    end

    function window:CreateTabFromName(name, icon)
        return self:CreateTab({ Name = name, Icon = icon })
    end

    window.Loader = loader
    window.ScreenGui = screenGui
    window.Root = root
    window.Main = main
    window.Sidebar = sidebar
    window.Content = content
    window.DockButton = dockButton
    window.SetVisible = setVisible

    updateResponsive()
    clampWindowToScreen()

    if loader then
        loader:SetProgress(0)
        loader:SetText("Loading Cresent...")
    end

    setVisible(true)

    return window
end

Library.Create = Library.CreateWindow
Library.New = Library.CreateWindow
Library.new = Library.CreateWindow

function Library:Notify()
    error("Create a window first, then call Window:Notify({...}).")
end
return Library
