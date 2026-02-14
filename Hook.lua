local Hook = {}

local Config = nil
local Process = nil

local originalNamecall = nil
local originalFireServer = nil
local originalInvokeServer = nil
local originalUnreliableFireServer = nil
local hooked = false

function Hook:Init(config, process)
    Config = config
    Process = process
end

local function processRemoteCall(originalFunc, metaMethod, remote, method, ...)
    return Process:ProcessRemote({
        Method = method,
        OriginalFunc = originalFunc,
        MetaMethod = metaMethod,
        IsExploit = checkcaller(),
    }, remote, ...)
end

function Hook:BeginHooks()
    if hooked then return end
    hooked = true

    local newNamecall = newcclosure(function(...)
        local method = getnamecallmethod()

        if method == "FireServer" or method == "fireServer"
            or method == "InvokeServer" or method == "invokeServer" then

            local remote = ...
            if typeof(remote) == "Instance" then
                local className = remote.ClassName
                if className == "RemoteEvent" or className == "RemoteFunction"
                    or className == "UnreliableRemoteEvent" then

                    if not Process:IsRemoteAllowed(remote, "Send", method) then
                        return originalNamecall(...)
                    end

                    return processRemoteCall(originalNamecall, "__namecall", remote, method, select(2, ...))
                end
            end
        end

        return originalNamecall(...)
    end)

    if hookmetamethod then
        originalNamecall = hookmetamethod(game, "__namecall", newNamecall)
    else
        originalNamecall = hookfunction(getrawmetatable(game).__namecall, newNamecall)
    end

    local newFireServer = newcclosure(function(remote, ...)
        if typeof(remote) == "Instance" and
            (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent")) then

            if Process:IsRemoteAllowed(remote, "Send", "FireServer") then
                return processRemoteCall(originalFireServer, "__index", remote, "FireServer", ...)
            end
        end
        return originalFireServer(remote, ...)
    end)

    local newInvokeServer = newcclosure(function(remote, ...)
        if typeof(remote) == "Instance" and remote:IsA("RemoteFunction") then
            if Process:IsRemoteAllowed(remote, "Send", "InvokeServer") then
                return processRemoteCall(originalInvokeServer, "__index", remote, "InvokeServer", ...)
            end
        end
        return originalInvokeServer(remote, ...)
    end)

    originalFireServer = hookfunction(
        Instance.new("RemoteEvent").FireServer,
        newFireServer
    )
    originalInvokeServer = hookfunction(
        Instance.new("RemoteFunction").InvokeServer,
        newInvokeServer
    )

    pcall(function()
        local newUnreliableFire = newcclosure(function(remote, ...)
            if typeof(remote) == "Instance" and remote:IsA("UnreliableRemoteEvent") then
                if Process:IsRemoteAllowed(remote, "Send", "FireServer") then
                    return processRemoteCall(originalUnreliableFireServer, "__index", remote, "FireServer", ...)
                end
            end
            return originalUnreliableFireServer(remote, ...)
        end)

        originalUnreliableFireServer = hookfunction(
            Instance.new("UnreliableRemoteEvent").FireServer,
            newUnreliableFire
        )
    end)
end

function Hook:ConnectReceive(remote)
    if not Config.Settings.LogReceive then return end

    local classData = Process:GetClassData(remote)
    if not classData then return end
    if classData.NoReceiveHook then return end

    local method = classData.Receive[1]
    if not method then return end

    if classData.IsRemoteFunction then
        pcall(function()
            local existingCallback = getcallbackvalue(remote, method)
            if existingCallback then
                hookfunction(existingCallback, newcclosure(function(...)
                    Process:ProcessRemote({
                        Method = method,
                        IsReceive = true,
                        MetaMethod = "Connect",
                        IsExploit = false,
                    }, remote, ...)
                    return existingCallback(...)
                end))
            end
        end)
    else
        pcall(function()
            remote[method]:Connect(function(...)
                Process:ProcessRemote({
                    Method = method,
                    IsReceive = true,
                    MetaMethod = "Connect",
                    IsExploit = false,
                }, remote, ...)
            end)
        end)
    end
end

function Hook:HookReceives()
    local blacklistedServices = Config.BlacklistedServices

    game.DescendantAdded:Connect(function(remote)
        if Process:GetClassData(remote) then
            self:ConnectReceive(remote)
        end
    end)

    if getnilinstances then
        for _, inst in getnilinstances() do
            if Process:GetClassData(inst) then
                self:ConnectReceive(inst)
            end
        end
    end

    for _, service in game:GetChildren() do
        if table.find(blacklistedServices, service.ClassName) then continue end
        pcall(function()
            for _, desc in service:GetDescendants() do
                if Process:GetClassData(desc) then
                    self:ConnectReceive(desc)
                end
            end
        end)
    end
end

function Hook:Start()
    self:BeginHooks()

    if Config.Settings.LogReceive then
        task.spawn(function()
            self:HookReceives()
        end)
    end
end

function Hook:DisableHooks()
    if not hooked then return end
    hooked = false

    pcall(function()
        if hookmetamethod then
            hookmetamethod(game, "__namecall", originalNamecall)
        else
            hookfunction(getrawmetatable(game).__namecall, originalNamecall)
        end
    end)

    pcall(function()
        hookfunction(Instance.new("RemoteEvent").FireServer, originalFireServer)
    end)

    pcall(function()
        hookfunction(Instance.new("RemoteFunction").InvokeServer, originalInvokeServer)
    end)

    if originalUnreliableFireServer then
        pcall(function()
            hookfunction(Instance.new("UnreliableRemoteEvent").FireServer, originalUnreliableFireServer)
        end)
    end
end

function Hook:IsHooked()
    return hooked
end

return Hook
