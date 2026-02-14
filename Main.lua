if getgenv().ArcvourSpyExecuted then
    warn("[Arcvour Spy] Already running!")
    return
end

if not game:GetService("RunService"):IsClient() then
    error("[Arcvour Spy] Cannot run on server!")
    return
end

local requiredFunctions = {
    "hookmetamethod",
    "hookfunction",
    "getrawmetatable",
    "newcclosure",
    "checkcaller",
    "cloneref",
}

for _, name in requiredFunctions do
    if not getfenv()[name] then
        if name == "hookmetamethod" then
            if not getfenv()["hookfunction"] then
                error("[Arcvour Spy] Missing critical function: " .. name)
                return
            end
        elseif name == "cloneref" then
            getfenv().cloneref = function(obj) return obj end
        else
            error("[Arcvour Spy] Missing critical function: " .. name)
            return
        end
    end
end

local REPO_BASE = "https://raw.githubusercontent.com/Fami-dev/Arcvour-Spy/main/"

local function loadModule(name)
    local url = REPO_BASE .. name .. ".lua"
    local success, result = pcall(function()
        return loadstring(game:HttpGet(url), "ArcvourSpy-" .. name)()
    end)
    if not success then
        error("[Arcvour Spy] Failed to load " .. name .. ": " .. tostring(result))
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
            UiModule:Shutdown()
            getgenv().ArcvourSpyExecuted = false
            getgenv().ArcvourSpy = nil
        end,
    }

    getgenv().getNil = function(name, class)
        if getnilinstances then
            for _, v in getnilinstances() do
                if v.ClassName == class and v.Name == name then
                    return v
                end
            end
        end
    end
end)

if not ok then
    warn("[Arcvour Spy] Failed to initialize: " .. tostring(err))
    getgenv().ArcvourSpyExecuted = false
end
