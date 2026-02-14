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

function Hook:BeginHooks()
    if hooked then return end
    hooked = true

    local _checkcaller = checkcaller or function() return false end
    local _hookmetamethod = hookmetamethod
    local _hookfunction = hookfunction
    local _newcclosure = newcclosure
    local _getnamecallmethod = getnamecallmethod

    local newNamecall = _newcclosure(function(...)
        local ok, method = pcall(_getnamecallmethod)
        if not ok or not method then
            return originalNamecall(...)
        end

        if method == "FireServer" or method == "fireServer"
            or method == "InvokeServer" or method == "invokeServer" then

            local remote = ...
            if typeof(remote) == "Instance" then
                local className = remote.ClassName
                if className == "RemoteEvent" or className == "RemoteFunction"
                    or className == "UnreliableRemoteEvent" then

                    if Process:IsRemoteAllowed(remote, "Send", method) then
                        local isExploit = _checkcaller()
                        local args = {select(2, ...)}

                        task.spawn(function()
                            Process:LogRemote({
                                remote = remote,
                                method = method,
                                args = args,
                                metamethod = "__namecall",
                                isExploit = isExploit,
                                isReceive = false,
                            })
                        end)
                    end
                end
            end
        end

        return originalNamecall(...)
    end)

    if _hookmetamethod then
        originalNamecall = _hookmetamethod(game, "__namecall", newNamecall)
    elseif getrawmetatable then
        originalNamecall = _hookfunction(getrawmetatable(game).__namecall, newNamecall)
    end

    pcall(function()
        local testEvent = Instance.new("RemoteEvent")

        local newFireServer = _newcclosure(function(remote, ...)
            if typeof(remote) == "Instance" and
                (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent")) then

                if Process:IsRemoteAllowed(remote, "Send", "FireServer") then
                    local isExploit = _checkcaller()
                    local args = {...}

                    task.spawn(function()
                        Process:LogRemote({
                            remote = remote,
                            method = "FireServer",
                            args = args,
                            metamethod = "__index",
                            isExploit = isExploit,
                            isReceive = false,
                        })
                    end)
                end
            end
            return originalFireServer(remote, ...)
        end)

        originalFireServer = _hookfunction(testEvent.FireServer, newFireServer)
        testEvent:Destroy()
    end)

    pcall(function()
        local testFunc = Instance.new("RemoteFunction")

        local newInvokeServer = _newcclosure(function(remote, ...)
            if typeof(remote) == "Instance" and remote:IsA("RemoteFunction") then
                if Process:IsRemoteAllowed(remote, "Send", "InvokeServer") then
                    local isExploit = _checkcaller()
                    local args = {...}

                    task.spawn(function()
                        Process:LogRemote({
                            remote = remote,
                            method = "InvokeServer",
                            args = args,
                            metamethod = "__index",
                            isExploit = isExploit,
                            isReceive = false,
                        })
                    end)
                end
            end
            return originalInvokeServer(remote, ...)
        end)

        originalInvokeServer = _hookfunction(testFunc.InvokeServer, newInvokeServer)
        testFunc:Destroy()
    end)

    pcall(function()
        local testURE = Instance.new("UnreliableRemoteEvent")

        local newUnreliableFire = _newcclosure(function(remote, ...)
            if typeof(remote) == "Instance" and remote:IsA("UnreliableRemoteEvent") then
                if Process:IsRemoteAllowed(remote, "Send", "FireServer") then
                    local isExploit = _checkcaller()
                    local args = {...}

                    task.spawn(function()
                        Process:LogRemote({
                            remote = remote,
                            method = "FireServer",
                            args = args,
                            metamethod = "__index",
                            isExploit = isExploit,
                            isReceive = false,
                        })
                    end)
                end
            end
            return originalUnreliableFireServer(remote, ...)
        end)

        originalUnreliableFireServer = _hookfunction(testURE.FireServer, newUnreliableFire)
        testURE:Destroy()
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
            local existingCallback = getcallbackvalue and getcallbackvalue(remote, method)
            if existingCallback then
                hookfunction(existingCallback, newcclosure(function(...)
                    local args = {...}
                    task.spawn(function()
                        Process:LogRemote({
                            remote = remote,
                            method = method,
                            args = args,
                            metamethod = "Connect",
                            isExploit = false,
                            isReceive = true,
                        })
                    end)
                    return existingCallback(unpack(args))
                end))
            end
        end)
    else
        pcall(function()
            remote[method]:Connect(function(...)
                local args = {...}
                Process:LogRemote({
                    remote = remote,
                    method = method,
                    args = args,
                    metamethod = "Connect",
                    isExploit = false,
                    isReceive = true,
                })
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

    for _, inst in pairs(getnilinstances()) do
        if Process:GetClassData(inst) then
            self:ConnectReceive(inst)
        end
    end

    for _, service in pairs(game:GetChildren()) do
        if not table.find(blacklistedServices, service.ClassName) then
            pcall(function()
                for _, desc in pairs(service:GetDescendants()) do
                    if Process:GetClassData(desc) then
                        self:ConnectReceive(desc)
                    end
                end
            end)
        end
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
        elseif getrawmetatable then
            hookfunction(getrawmetatable(game).__namecall, originalNamecall)
        end
    end)

    if originalFireServer then
        pcall(function()
            hookfunction(originalFireServer, originalFireServer)
        end)
    end

    if originalInvokeServer then
        pcall(function()
            hookfunction(originalInvokeServer, originalInvokeServer)
        end)
    end

    if originalUnreliableFireServer then
        pcall(function()
            hookfunction(originalUnreliableFireServer, originalUnreliableFireServer)
        end)
    end
end

function Hook:IsHooked()
    return hooked
end

return Hook
