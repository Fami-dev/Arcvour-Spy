if getgenv().ArcvourSpyExecuted then
    warn("[Arcvour Spy] Already running!")
    return
end

if not game:GetService("RunService"):IsClient() then
    error("[Arcvour Spy] Cannot run on server!")
    return
end

if not hookfunction then
    error("[Arcvour Spy] Missing critical function: hookfunction")
    return
end

if not newcclosure then
    error("[Arcvour Spy] Missing critical function: newcclosure")
    return
end

if not getnamecallmethod then
    error("[Arcvour Spy] Missing critical function: getnamecallmethod")
    return
end

if not checkcaller then
    getgenv().checkcaller = function() return false end
end

if not cloneref then
    getgenv().cloneref = function(obj) return obj end
end

if not getcallingscript then
    getgenv().getcallingscript = function() return nil end
end

if not getnilinstances then
    getgenv().getnilinstances = function() return {} end
end

local REPO_BASE = "https://raw.githubusercontent.com/Fami-dev/Arcvour-Spy/main/"

local function loadModule(name)
    local url = REPO_BASE .. name .. ".lua"
    local source = game:HttpGet(url)
    if not source or source == "" or source:find("404") then
        error("[Arcvour Spy] Failed to download " .. name)
    end
    local fn, compileErr = loadstring(source, "ArcvourSpy_" .. name)
    if not fn then
        error("[Arcvour Spy] Failed to compile " .. name .. ": " .. tostring(compileErr))
    end
    local success, result = pcall(fn)
    if not success then
        error("[Arcvour Spy] Failed to execute " .. name .. ": " .. tostring(result))
    end
    return result
end

local ok, err = pcall(function()
    local Config = loadModule("Config")
    local Serializer = loadModule("Serializer")
    local Process = loadModule("Process")
    local Hook = loadModule("Hook")
    local UiModule = loadModule("Ui")

    Process:Init(Config, Serializer)
    Hook:Init(Config, Process)
    UiModule:Init(Config, Process, Serializer, Hook)

    UiModule:Build()
    Process:SetUi(UiModule)
    Process:StartScheduler()
    Hook:Start()

    getgenv().ArcvourSpyExecuted = true
    getgenv().ArcvourSpy = {
        Config = Config,
        Process = Process,
        Hook = Hook,
        Ui = UiModule,
        Serializer = Serializer,
        Shutdown = function()
            Hook:DisableHooks()
            Process:Shutdown()
            UiModule:Shutdown()
            getgenv().ArcvourSpyExecuted = false
            getgenv().ArcvourSpy = nil
        end,
    }

    getgenv().getNil = function(name, class)
        for _, v in getnilinstances() do
            if v.ClassName == class and v.Name == name then
                return v
            end
        end
    end
end)

if not ok then
    warn("[Arcvour Spy] Failed to initialize: " .. tostring(err))
    getgenv().ArcvourSpyExecuted = false
end
