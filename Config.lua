local Config = {}

Config.Colors = {
    Primary = Color3.fromRGB(140, 70, 255),
    Secondary = Color3.fromRGB(190, 120, 255),
    Accent = Color3.fromRGB(75, 45, 130),

    Background = Color3.fromRGB(22, 17, 35),
    Surface = Color3.fromRGB(30, 22, 48),
    SurfaceLight = Color3.fromRGB(40, 30, 60),
    Panel = Color3.fromRGB(26, 20, 42),
    Border = Color3.fromRGB(60, 45, 85),

    Text = Color3.fromRGB(229, 220, 234),
    TextDim = Color3.fromRGB(140, 130, 160),
    TextMuted = Color3.fromRGB(100, 90, 120),

    Success = Color3.fromRGB(77, 245, 105),
    Warning = Color3.fromRGB(245, 200, 60),
    Error = Color3.fromRGB(245, 77, 77),

    Transparent = Color3.fromRGB(0, 0, 0),
}

Config.MethodColors = {
    fireserver = Color3.fromRGB(242, 255, 0),
    invokeserver = Color3.fromRGB(99, 140, 245),
    onclientevent = Color3.fromRGB(77, 245, 105),
    onclientinvoke = Color3.fromRGB(77, 178, 245),
    fire = Color3.fromRGB(245, 160, 77),
    invoke = Color3.fromRGB(245, 77, 140),
    event = Color3.fromRGB(77, 245, 181),
    oninvoke = Color3.fromRGB(245, 77, 209),
}

Config.ClassIcons = {
    RemoteEvent = "→",
    RemoteFunction = "⇄",
    UnreliableRemoteEvent = "⇢",
    BindableEvent = "◆",
    BindableFunction = "◇",
}

Config.Settings = {
    LogReceive = false,
    LogExploit = false,
    Paused = false,
    Autoblock = false,
    IgnoreNilParent = false,
    MaxLogs = 200,
    AutoblockThreshold = 3,
    AutoblockWindow = 1,
}

Config.BlacklistedServices = {
    "RobloxReplicatedStorage",
}

Config.RemoteClassData = {
    RemoteEvent = {
        Send = {"FireServer", "fireServer"},
        Receive = {"OnClientEvent"},
    },
    RemoteFunction = {
        IsRemoteFunction = true,
        Send = {"InvokeServer", "invokeServer"},
        Receive = {"OnClientInvoke"},
    },
    UnreliableRemoteEvent = {
        Send = {"FireServer", "fireServer"},
        Receive = {"OnClientEvent"},
    },
    BindableEvent = {
        NoReceiveHook = true,
        Send = {"Fire"},
        Receive = {"Event"},
    },
    BindableFunction = {
        IsRemoteFunction = true,
        NoReceiveHook = true,
        Send = {"Invoke"},
        Receive = {"OnInvoke"},
    },
}

Config.UI = {
    WindowSize = UDim2.fromOffset(800, 500),
    MinSize = Vector2.new(500, 300),
    CornerRadius = UDim.new(0, 8),
    SmallCorner = UDim.new(0, 6),
    TinyCorner = UDim.new(0, 4),
    Font = Enum.Font.GothamMedium,
    MonoFont = Enum.Font.Code,
    TitleSize = 14,
    TextSize = 12,
    SmallTextSize = 11,
    ListPanelWidth = 170,
    ToolbarHeight = 36,
    TitleBarHeight = 32,
    ButtonHeight = 26,
    LogItemHeight = 22,
    InfoPanelHeight = 0.28,
    AnimationSpeed = 0.2,
}

return Config
