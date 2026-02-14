local Ui = {}

local Config = nil
local Process = nil
local Serializer = nil
local Hook = nil

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local screenGui = nil
local mainFrame = nil
local logList = nil
local codeBox = nil
local infoPanel = nil
local statusLabel = nil
local counterLabel = nil
local settingsFrame = nil

local selectedLog = nil
local logs = {}
local logHeaders = {}
local logCount = 0
local totalRemotes = 0
local isDragging = false
local dragStart = nil
local startPos = nil
local isResizing = false
local resizeStart = nil
local startSize = nil
local isMinimized = false
local settingsVisible = false

function Ui:Init(config, process, serializer, hook)
    Config = config
    Process = process
    Serializer = serializer
    Hook = hook
end

local function create(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" and k ~= "Children" then
            inst[k] = v
        end
    end
    if props.Children then
        for _, child in ipairs(props.Children) do
            child.Parent = inst
        end
    end
    if props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

local function tweenProp(inst, props, duration)
    local info = TweenInfo.new(duration or Config.UI.AnimationSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(inst, info, props):Play()
end

local function addCorner(parent, radius)
    return create("UICorner", {
        CornerRadius = radius or Config.UI.CornerRadius,
        Parent = parent,
    })
end

local function addStroke(parent, color, thickness)
    return create("UIStroke", {
        Color = color or Config.Colors.Border,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function addPadding(parent, t, b, l, r)
    return create("UIPadding", {
        PaddingTop = UDim.new(0, t or 6),
        PaddingBottom = UDim.new(0, b or 6),
        PaddingLeft = UDim.new(0, l or 8),
        PaddingRight = UDim.new(0, r or 8),
        Parent = parent,
    })
end

local function makeBtn(parent, text, size, callback, bgColor)
    local colors = Config.Colors
    local ui = Config.UI
    local btn = create("TextButton", {
        Text = text,
        Font = ui.Font,
        TextSize = ui.SmallTextSize,
        TextColor3 = colors.Text,
        BackgroundColor3 = bgColor or colors.SurfaceLight,
        Size = size or UDim2.new(0, 0, 0, ui.ButtonHeight),
        AutomaticSize = Enum.AutomaticSize.X,
        Parent = parent,
    })
    addCorner(btn, ui.TinyCorner)
    addPadding(btn, 4, 4, 10, 10)

    btn.MouseEnter:Connect(function()
        tweenProp(btn, {BackgroundColor3 = colors.Primary}, 0.15)
    end)
    btn.MouseLeave:Connect(function()
        tweenProp(btn, {BackgroundColor3 = bgColor or colors.SurfaceLight}, 0.15)
    end)
    if callback then
        btn.MouseButton1Click:Connect(callback)
    end
    return btn
end

function Ui:Build()
    local colors = Config.Colors
    local ui = Config.UI

    if screenGui then screenGui:Destroy() end

    screenGui = create("ScreenGui", {
        Name = "ArcvourSpy",
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
        DisplayOrder = 999,
    })
    screenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

    mainFrame = create("Frame", {
        Name = "Main",
        Size = ui.WindowSize,
        Position = UDim2.new(0.5, -ui.WindowSize.X.Offset / 2, 0.5, -ui.WindowSize.Y.Offset / 2),
        BackgroundColor3 = colors.Background,
        BorderSizePixel = 0,
        Parent = screenGui,
    })
    addCorner(mainFrame)
    addStroke(mainFrame, colors.Border, 1.5)

    create("Frame", {
        Name = "Shadow",
        Size = UDim2.new(1, 12, 1, 12),
        Position = UDim2.new(0, -6, 0, -6),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.6,
        ZIndex = -1,
        Parent = mainFrame,
        Children = {
            Instance.new("UICorner"),
        },
    })
    mainFrame.Shadow.UICorner.CornerRadius = UDim.new(0, 12)

    self:BuildTitleBar()
    self:BuildToolbar()
    self:BuildContent()
    self:BuildSettings()
    self:BuildResizeHandle()
end

function Ui:BuildTitleBar()
    local colors = Config.Colors
    local ui = Config.UI

    local titleBar = create("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, ui.TitleBarHeight),
        BackgroundColor3 = colors.Surface,
        BorderSizePixel = 0,
        Parent = mainFrame,
    })
    create("UICorner", {
        CornerRadius = ui.CornerRadius,
        Parent = titleBar,
    })
    create("Frame", {
        Name = "BottomFill",
        Size = UDim2.new(1, 0, 0, 10),
        Position = UDim2.new(0, 0, 1, -10),
        BackgroundColor3 = colors.Surface,
        BorderSizePixel = 0,
        Parent = titleBar,
    })

    local dot = create("Frame", {
        Size = UDim2.new(0, 10, 0, 10),
        Position = UDim2.new(0, 12, 0.5, -5),
        BackgroundColor3 = colors.Primary,
        Parent = titleBar,
    })
    addCorner(dot, UDim.new(1, 0))

    create("TextLabel", {
        Text = "Arcvour Spy",
        Font = Enum.Font.GothamBold,
        TextSize = ui.TitleSize,
        TextColor3 = colors.Text,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 28, 0, 0),
        Size = UDim2.new(0.5, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = titleBar,
    })

    local btnContainer = create("Frame", {
        Size = UDim2.new(0, 80, 1, 0),
        Position = UDim2.new(1, -85, 0, 0),
        BackgroundTransparency = 1,
        Parent = titleBar,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 4),
        Parent = btnContainer,
    })

    local function winBtn(text, color, callback)
        local b = create("TextButton", {
            Text = text,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextColor3 = colors.TextDim,
            BackgroundColor3 = colors.SurfaceLight,
            Size = UDim2.new(0, 24, 0, 20),
            Parent = btnContainer,
        })
        addCorner(b, ui.TinyCorner)
        b.MouseEnter:Connect(function()
            tweenProp(b, {BackgroundColor3 = color, TextColor3 = colors.Text}, 0.15)
        end)
        b.MouseLeave:Connect(function()
            tweenProp(b, {BackgroundColor3 = colors.SurfaceLight, TextColor3 = colors.TextDim}, 0.15)
        end)
        b.MouseButton1Click:Connect(callback)
        return b
    end

    winBtn("—", colors.Warning, function()
        self:ToggleMinimize()
    end)
    winBtn("✕", colors.Error, function()
        self:Shutdown()
    end)

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

function Ui:BuildToolbar()
    local colors = Config.Colors
    local ui = Config.UI

    local toolbar = create("Frame", {
        Name = "Toolbar",
        Size = UDim2.new(1, -16, 0, ui.ToolbarHeight),
        Position = UDim2.new(0, 8, 0, ui.TitleBarHeight + 4),
        BackgroundColor3 = colors.Surface,
        BorderSizePixel = 0,
        Parent = mainFrame,
    })
    addCorner(toolbar, ui.SmallCorner)
    addPadding(toolbar, 4, 4, 6, 6)

    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6),
        Parent = toolbar,
    })

    local spyBtn = makeBtn(toolbar, "● Spy ON", nil, function()
        if Hook:IsHooked() then
            Hook:DisableHooks()
            spyBtn.Text = "○ Spy OFF"
            spyBtn.TextColor3 = colors.Error
            self:SetStatus("Spy disabled")
        else
            Hook:Start()
            spyBtn.Text = "● Spy ON"
            spyBtn.TextColor3 = colors.Success
            self:SetStatus("Spy enabled")
        end
    end)
    spyBtn.TextColor3 = colors.Success

    makeBtn(toolbar, "Clear", nil, function()
        self:ClearLogs()
    end)

    makeBtn(toolbar, "⚙ Settings", nil, function()
        self:ToggleSettings()
    end)

    makeBtn(toolbar, "Pause", nil, function()
        Config.Settings.Paused = not Config.Settings.Paused
        local btn = toolbar:FindFirstChild("PauseBtn")
    end)

    counterLabel = create("TextLabel", {
        Name = "Counter",
        Text = "0 remotes",
        Font = ui.Font,
        TextSize = ui.SmallTextSize,
        TextColor3 = colors.TextMuted,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 100, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
        AutomaticSize = Enum.AutomaticSize.X,
        Parent = toolbar,
    })

    self.toolbar = toolbar
    self.spyBtn = spyBtn
end

function Ui:BuildResizeHandle()
    local colors = Config.Colors
    local ui = Config.UI

    local handle = create("ImageButton", {
        Name = "ResizeHandle",
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new(1, -16, 1, -16),
        BackgroundTransparency = 1,
        Image = "rbxassetid://6035282286", -- Resize icon
        ImageColor3 = colors.TextDim,
        ZIndex = 10,
        Parent = mainFrame,
    })

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            isResizing = true
            resizeStart = input.Position
            startSize = mainFrame.AbsoluteSize
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isResizing = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isResizing and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - resizeStart
            local newX = math.max(ui.MinSize.X, startSize.X + delta.X)
            local newY = math.max(ui.MinSize.Y, startSize.Y + delta.Y)
            
            mainFrame.Size = UDim2.fromOffset(newX, newY)
        end
    end)
end

function Ui:BuildContent()
    local colors = Config.Colors
    local ui = Config.UI

    local contentY = ui.TitleBarHeight + ui.ToolbarHeight + 12
    local content = create("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -16, 1, -contentY - 8),
        Position = UDim2.new(0, 8, 0, contentY),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = mainFrame,
    })

    local listPanel = create("Frame", {
        Name = "ListPanel",
        Size = UDim2.new(0, ui.ListPanelWidth, 1, 0),
        BackgroundColor3 = colors.Surface,
        BorderSizePixel = 0,
        Parent = content,
    })
    addCorner(listPanel, ui.SmallCorner)
    addStroke(listPanel, colors.Border, 0.5)

    local listScroll = create("ScrollingFrame", {
        Name = "LogScroll",
        Size = UDim2.new(1, -4, 1, -4),
        Position = UDim2.new(0, 2, 0, 2),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = colors.Primary,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        Parent = listPanel,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 1),
        Parent = listScroll,
    })
    addPadding(listScroll, 2, 2, 2, 2)

    logList = listScroll

    local rightPanel = create("Frame", {
        Name = "RightPanel",
        Size = UDim2.new(1, -ui.ListPanelWidth - 8, 1, 0),
        Position = UDim2.new(0, ui.ListPanelWidth + 8, 0, 0),
        BackgroundTransparency = 1,
        Parent = content,
    })

    local codeFrame = create("Frame", {
        Name = "CodeFrame",
        Size = UDim2.new(1, 0, 1, -ui.InfoPanelHeight * 420 - 8),
        BackgroundColor3 = colors.Surface,
        BorderSizePixel = 0,
        Parent = rightPanel,
    })
    addCorner(codeFrame, ui.SmallCorner)
    addStroke(codeFrame, colors.Border, 0.5)

    local codeHeader = create("Frame", {
        Name = "CodeHeader",
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = colors.SurfaceLight,
        BorderSizePixel = 0,
        Parent = codeFrame,
    })
    create("UICorner", {
        CornerRadius = ui.SmallCorner,
        Parent = codeHeader,
    })
    create("Frame", {
        Size = UDim2.new(1, 0, 0, 6),
        Position = UDim2.new(0, 0, 1, -6),
        BackgroundColor3 = colors.SurfaceLight,
        BorderSizePixel = 0,
        Parent = codeHeader,
    })

    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 4),
        Parent = codeHeader,
    })
    addPadding(codeHeader, 0, 0, 6, 6)

    makeBtn(codeHeader, "Copy", nil, function()
        if codeBox then
            local text = codeBox.Text
            if setclipboard then setclipboard(text) end
            self:SetStatus("Code copied!")
        end
    end)
    makeBtn(codeHeader, "Run", nil, function()
        if codeBox then
            local text = codeBox.Text
            local fn, err = loadstring(text, "ArcvourSpy")
            if fn then
                local ok, runErr = pcall(fn)
                if ok then
                    self:SetStatus("Executed successfully!")
                else
                    self:SetStatus("Error: " .. tostring(runErr))
                end
            else
                self:SetStatus("Syntax error: " .. tostring(err))
            end
        end
    end)
    makeBtn(codeHeader, "Block", nil, function()
        if selectedLog then
            local script = Serializer:GenerateBlockScript(selectedLog.remote, selectedLog.method)
            codeBox.Text = script
            self:SetStatus("Block script generated")
        end
    end)
    makeBtn(codeHeader, "Repeat", nil, function()
        if selectedLog then
            local script = Serializer:GenerateRepeatScript(selectedLog.remote, selectedLog.method, selectedLog.args)
            codeBox.Text = script
            self:SetStatus("Repeat script generated")
        end
    end)
    makeBtn(codeHeader, "Spam", nil, function()
        if selectedLog then
            local script = Serializer:GenerateSpamScript(selectedLog.remote, selectedLog.method, selectedLog.args)
            codeBox.Text = script
            self:SetStatus("Spam script generated")
        end
    end)

    local codeScroll = create("ScrollingFrame", {
        Name = "CodeScroll",
        Size = UDim2.new(1, -4, 1, -32),
        Position = UDim2.new(0, 2, 0, 30),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = colors.Primary,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.XY,
        BorderSizePixel = 0,
        Parent = codeFrame,
    })

    codeBox = create("TextBox", {
        Name = "CodeBox",
        Text = "-- Arcvour Spy\n-- Select a remote to view generated code",
        Font = ui.MonoFont,
        TextSize = ui.TextSize,
        TextColor3 = colors.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -12, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ClearTextOnFocus = false,
        MultiLine = true,
        TextWrapped = false,
        TextEditable = true,
        Parent = codeScroll,
    })
    addPadding(codeBox, 6, 6, 6, 6)

    local infoPanelHeight = math.floor(ui.InfoPanelHeight * 420)
    local infoFrame = create("Frame", {
        Name = "InfoFrame",
        Size = UDim2.new(1, 0, 0, infoPanelHeight),
        Position = UDim2.new(0, 0, 1, -infoPanelHeight),
        BackgroundColor3 = colors.Surface,
        BorderSizePixel = 0,
        Parent = rightPanel,
    })
    addCorner(infoFrame, ui.SmallCorner)
    addStroke(infoFrame, colors.Border, 0.5)

    local infoHeader = create("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundColor3 = colors.SurfaceLight,
        BorderSizePixel = 0,
        Parent = infoFrame,
    })
    create("UICorner", {CornerRadius = ui.SmallCorner, Parent = infoHeader})
    create("Frame", {
        Size = UDim2.new(1, 0, 0, 6),
        Position = UDim2.new(0, 0, 1, -6),
        BackgroundColor3 = colors.SurfaceLight,
        BorderSizePixel = 0,
        Parent = infoHeader,
    })

    create("TextLabel", {
        Text = "📋 Remote Info",
        Font = ui.Font,
        TextSize = ui.SmallTextSize,
        TextColor3 = colors.TextDim,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = infoHeader,
    })
    addPadding(infoHeader, 0, 0, 8, 0)

    local actionRow = create("Frame", {
        Name = "Actions",
        Size = UDim2.new(1, -8, 0, 24),
        Position = UDim2.new(0, 4, 0, 24),
        BackgroundTransparency = 1,
        Parent = infoFrame,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 4),
        Parent = actionRow,
    })

    makeBtn(actionRow, "Copy Remote", nil, function()
        if selectedLog and setclipboard then
            setclipboard(Serializer:ValueToString(selectedLog.remote))
            self:SetStatus("Remote path copied!")
        end
    end)
    makeBtn(actionRow, "Copy Script", nil, function()
        if selectedLog and selectedLog.callingScript and setclipboard then
            setclipboard(Serializer:ValueToString(selectedLog.callingScript))
            self:SetStatus("Script path copied!")
        end
    end)
    
    if decompile then
        makeBtn(actionRow, "Decompile", nil, function()
            if selectedLog and selectedLog.callingScript then
                local source = decompile(selectedLog.callingScript)
                if setclipboard then
                    setclipboard(source)
                    self:SetStatus("Source copied to clipboard!")
                else
                    codeBox.Text = "-- Decompiled Source:\n\n" .. source
                    self:SetStatus("Source shown in editor")
                end
            else
                self:SetStatus("No calling script!")
            end
        end)
    end
    makeBtn(actionRow, "Exclude", nil, function()
        if selectedLog then
            Process:BlacklistById(selectedLog.id)
            self:SetStatus("Remote excluded!")
        end
    end)
    makeBtn(actionRow, "Block Fire", nil, function()
        if selectedLog then
            Process:BlockById(selectedLog.id)
            self:SetStatus("Remote blocked!")
        end
    end)

    local infoScroll = create("ScrollingFrame", {
        Name = "InfoScroll",
        Size = UDim2.new(1, -4, 1, -52),
        Position = UDim2.new(0, 2, 0, 50),
        BackgroundTransparency = 1,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = colors.Primary,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        Parent = infoFrame,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
        Parent = infoScroll,
    })
    addPadding(infoScroll, 2, 2, 6, 6)

    infoPanel = infoScroll

    statusLabel = create("TextLabel", {
        Name = "Status",
        Text = "Ready",
        Font = ui.Font,
        TextSize = 10,
        TextColor3 = colors.TextMuted,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -16, 0, 16),
        Position = UDim2.new(0, 8, 1, -18),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = mainFrame,
    })

    self.content = content
end

function Ui:BuildSettings()
    local colors = Config.Colors
    local ui = Config.UI

    settingsFrame = create("Frame", {
        Name = "Settings",
        Size = UDim2.new(0, 220, 0, 0),
        Position = UDim2.new(1, -228, 0, ui.TitleBarHeight + ui.ToolbarHeight + 50),
        BackgroundColor3 = colors.Surface,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 10,
        Parent = mainFrame,
    })
    addCorner(settingsFrame, ui.SmallCorner)
    addStroke(settingsFrame, colors.Primary, 1)

    local settingsLayout = create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
        Parent = settingsFrame,
    })
    addPadding(settingsFrame, 6, 6, 8, 8)

    create("TextLabel", {
        Text = "⚙ Settings",
        Font = Enum.Font.GothamBold,
        TextSize = ui.TextSize,
        TextColor3 = colors.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 22),
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 0,
        Parent = settingsFrame,
    })

    local toggles = {
        {key = "LogReceive", label = "Log Receives", order = 1},
        {key = "LogExploit", label = "Log Exploit Calls", order = 2},
        {key = "Autoblock", label = "Autoblock Spam", order = 3},
        {key = "IgnoreNilParent", label = "Ignore Nil Parents", order = 4},
        {key = "Paused", label = "Pause Logging", order = 5},
    }

    for _, toggle in ipairs(toggles) do
        self:CreateToggle(settingsFrame, toggle.label, Config.Settings[toggle.key], toggle.order, function(state)
            Config.Settings[toggle.key] = state
        end)
    end

    makeBtn(settingsFrame, "Clear Blacklist", UDim2.new(1, 0, 0, ui.ButtonHeight), function()
        Process:ClearBlacklist()
        self:SetStatus("Blacklist cleared!")
    end)
    makeBtn(settingsFrame, "Clear Blocklist", UDim2.new(1, 0, 0, ui.ButtonHeight), function()
        Process:ClearBlocklist()
        self:SetStatus("Blocklist cleared!")
    end)

    settingsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        settingsFrame.Size = UDim2.new(0, 220, 0, settingsLayout.AbsoluteContentSize.Y + 16)
    end)
    task.defer(function()
        settingsFrame.Size = UDim2.new(0, 220, 0, settingsLayout.AbsoluteContentSize.Y + 16)
    end)
end

function Ui:CreateToggle(parent, label, default, order, callback)
    local colors = Config.Colors
    local ui = Config.UI
    local state = default

    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        LayoutOrder = order,
        Parent = parent,
    })

    create("TextLabel", {
        Text = label,
        Font = ui.Font,
        TextSize = ui.SmallTextSize,
        TextColor3 = colors.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -40, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })

    local box = create("Frame", {
        Size = UDim2.new(0, 32, 0, 16),
        Position = UDim2.new(1, -34, 0.5, -8),
        BackgroundColor3 = state and colors.Primary or colors.SurfaceLight,
        Parent = row,
    })
    addCorner(box, UDim.new(1, 0))

    local knob = create("Frame", {
        Size = UDim2.new(0, 12, 0, 12),
        Position = state and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6),
        BackgroundColor3 = colors.Text,
        Parent = box,
    })
    addCorner(knob, UDim.new(1, 0))

    local btn = create("TextButton", {
        Text = "",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Parent = row,
    })
    btn.MouseButton1Click:Connect(function()
        state = not state
        tweenProp(box, {BackgroundColor3 = state and colors.Primary or colors.SurfaceLight}, 0.15)
        tweenProp(knob, {Position = state and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)}, 0.15)
        if callback then callback(state) end
    end)
end

function Ui:CreateLog(data)
    local colors = Config.Colors
    local ui = Config.UI
    local method = data.method
    local remote = data.remote
    local remoteName = tostring(remote)
    if #remoteName > 25 then
        remoteName = remoteName:sub(1, 25) .. "…"
    end

    local methodColor = Config.MethodColors[method:lower()] or colors.Text
    local icon = Config.ClassIcons[data.className] or "●"

    logCount = logCount + 1
    totalRemotes = totalRemotes + 1

    local item = create("TextButton", {
        Name = "Log_" .. logCount,
        Text = "",
        Size = UDim2.new(1, 0, 0, ui.LogItemHeight),
        BackgroundColor3 = colors.Surface,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        LayoutOrder = -logCount,
        AutoButtonColor = false,
        Parent = logList,
    })
    addCorner(item, ui.TinyCorner)

    create("TextLabel", {
        Text = icon,
        Font = ui.Font,
        TextSize = ui.SmallTextSize,
        TextColor3 = methodColor,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 16, 1, 0),
        Position = UDim2.new(0, 4, 0, 0),
        Parent = item,
    })

    local nameLabel = create("TextLabel", {
        Text = remoteName,
        Font = ui.Font,
        TextSize = ui.SmallTextSize,
        TextColor3 = colors.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -24, 1, 0),
        Position = UDim2.new(0, 22, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = item,
    })

    if data.isReceive then
        nameLabel.TextColor3 = colors.Success
    end

    item.MouseEnter:Connect(function()
        if item ~= (selectedLog and selectedLog._uiItem) then
            tweenProp(item, {BackgroundTransparency = 0.2}, 0.1)
        end
    end)
    item.MouseLeave:Connect(function()
        if item ~= (selectedLog and selectedLog._uiItem) then
            tweenProp(item, {BackgroundTransparency = 0.5}, 0.1)
        end
    end)

    data._uiItem = item
    table.insert(logs, data)

    item.MouseButton1Click:Connect(function()
        self:SelectLog(data)
    end)

    if counterLabel then
        counterLabel.Text = totalRemotes .. " remotes"
    end

    local maxLogs = Config.Settings.MaxLogs
    if #logs > maxLogs then
        local old = table.remove(logs, 1)
        if old._uiItem then
            old._uiItem:Destroy()
        end
    end
end

function Ui:SelectLog(data)
    local colors = Config.Colors

    if selectedLog and selectedLog._uiItem then
        tweenProp(selectedLog._uiItem, {BackgroundTransparency = 0.5, BackgroundColor3 = colors.Surface}, 0.1)
    end

    selectedLog = data
    tweenProp(data._uiItem, {BackgroundTransparency = 0, BackgroundColor3 = colors.Accent}, 0.1)

    local script = Serializer:GenerateScript(data.remote, data.method, data.args)
    if codeBox then
        codeBox.Text = script
    end

    self:UpdateInfoPanel(data)
    self:SetStatus("Selected: " .. tostring(data.remote))
end

function Ui:UpdateInfoPanel(data)
    local colors = Config.Colors
    local ui = Config.UI

    if not infoPanel then return end

    for _, child in pairs(infoPanel:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end

    local fields = {
        {"Method", data.method},
        {"MetaMethod", data.metamethod},
        {"Remote", tostring(data.remote)},
        {"Class", data.className},
        {"Script", data.callingScript and tostring(data.callingScript) or "N/A"},
        {"ID", data.id},
        {"Type", data.isReceive and "Receive" or "Send"},
        {"Args", "#" .. tostring(#data.args)},
    }

    for i, field in ipairs(fields) do
        local row = create("Frame", {
            Size = UDim2.new(1, 0, 0, 14),
            BackgroundTransparency = 1,
            LayoutOrder = i,
            Parent = infoPanel,
        })
        create("TextLabel", {
            Text = field[1] .. ":",
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = colors.TextDim,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 70, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })
        create("TextLabel", {
            Text = field[2],
            Font = ui.MonoFont,
            TextSize = 10,
            TextColor3 = colors.Text,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -74, 1, 0),
            Position = UDim2.new(0, 74, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = row,
        })
    end
end

function Ui:ClearLogs()
    for _, data in ipairs(logs) do
        if data._uiItem then
            data._uiItem:Destroy()
        end
    end
    table.clear(logs)
    logCount = 0
    totalRemotes = 0
    selectedLog = nil

    if counterLabel then
        counterLabel.Text = "0 remotes"
    end
    if codeBox then
        codeBox.Text = "-- Logs cleared"
    end
    if infoPanel then
        for _, child in pairs(infoPanel:GetChildren()) do
            if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                child:Destroy()
            end
        end
    end
    self:SetStatus("Logs cleared!")
end

function Ui:ToggleMinimize()
    local ui = Config.UI
    isMinimized = not isMinimized

    if isMinimized then
        tweenProp(mainFrame, {Size = UDim2.new(0, ui.WindowSize.X.Offset, 0, ui.TitleBarHeight)}, 0.2)
    else
        tweenProp(mainFrame, {Size = ui.WindowSize}, 0.2)
    end
end

function Ui:ToggleSettings()
    settingsVisible = not settingsVisible
    settingsFrame.Visible = settingsVisible
end

function Ui:SetStatus(text)
    if statusLabel then
        statusLabel.Text = text
        task.delay(3, function()
            if statusLabel and statusLabel.Text == text then
                statusLabel.Text = "Ready"
            end
        end)
    end
end

function Ui:Shutdown()
    Hook:DisableHooks()
    Process:Shutdown()

    if screenGui then
        screenGui:Destroy()
        screenGui = nil
    end

    if getgenv then
        getgenv().ArcvourSpyExecuted = false
    end
end

function Ui:IsAlive()
    return screenGui ~= nil and screenGui.Parent ~= nil
end

return Ui
