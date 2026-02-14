local Process = {}

local Config = nil
local Serializer = nil
local Ui = nil

local blacklist = {}
local blocklist = {}
local remoteData = {}
local history = {}
local excluding = {}
local logQueue = {}

local spyENV = getfenv(1)
local schedulerConnection = nil

local instanceCreatedRemotes = setmetatable({}, {__mode = "k"})

function Process:Init(config, serializer)
    Config = config
    Serializer = serializer

    local oldNew
    oldNew = hookfunction(getrenv().Instance.new, newcclosure(function(...)
        local inst = oldNew(...)
        if typeof(inst) == "Instance" and Config.RemoteClassData[inst.ClassName] then
            instanceCreatedRemotes[inst] = true
        end
        return inst
    end))
end

function Process:SetUi(ui)
    Ui = ui
end

function Process:GetClassData(remote)
    if typeof(remote) ~= "Instance" then return nil end
    return Config.RemoteClassData[remote.ClassName]
end

function Process:IsRemoteAllowed(remote, transferType, method)
    if typeof(remote) ~= "Instance" then return false end
    if instanceCreatedRemotes[remote] then return false end

    local classData = self:GetClassData(remote)
    if not classData then return false end

    local allowed = classData[transferType]
    if not allowed then return false end

    if method then
        return table.find(allowed, method) ~= nil
    end

    return true
end

function Process:IsSelfENV(env)
    return env == spyENV
end

function Process:GetRemoteId(remote)
    if not remote then return "" end
    local success, id = pcall(function()
        return remote:GetDebugId()
    end)
    return success and id or tostring(remote)
end

function Process:IsBlacklisted(remote, id)
    return blacklist[id] or blacklist[remote.Name]
end

function Process:IsBlocked(remote, id)
    return blocklist[id] or blocklist[remote.Name]
end

function Process:BlacklistById(id)
    blacklist[id] = true
end

function Process:BlacklistByName(name)
    blacklist[name] = true
end

function Process:BlockById(id)
    blocklist[id] = true
end

function Process:BlockByName(name)
    blocklist[name] = true
end

function Process:ClearBlacklist()
    table.clear(blacklist)
end

function Process:ClearBlocklist()
    table.clear(blocklist)
end

function Process:ShouldAutoblock(id)
    local settings = Config.Settings
    if not settings.Autoblock then return false end

    if excluding[id] then return true end

    if not history[id] then
        history[id] = {count = 0, lastCall = tick()}
    end

    local h = history[id]
    local now = tick()

    if now - h.lastCall < settings.AutoblockWindow then
        h.count = h.count + 1
        if h.count > settings.AutoblockThreshold then
            excluding[id] = true
            return true
        end
        return false
    else
        h.count = 0
        h.lastCall = now
        return false
    end
end

function Process:DeepClone(value, visited)
    if typeof(value) ~= "table" then
        if typeof(value) == "Instance" then
            return cloneref and cloneref(value) or value
        end
        return value
    end

    visited = visited or {}
    if visited[value] then return visited[value] end

    local new = {}
    visited[value] = new

    for k, v in next, value do
        new[self:DeepClone(k, visited)] = self:DeepClone(v, visited)
    end

    return new
end

function Process:GetCallerInfo()
    local callingScript = nil
    local callingFunc = nil

    pcall(function()
        callingFunc = debug.info(5, "f")
    end)

    pcall(function()
        local script = getcallingscript()
        if script and typeof(script) == "Instance" then
            callingScript = cloneref and cloneref(script) or script
        end
    end)

    if callingFunc then
        pcall(function()
            local env = getfenv(callingFunc)
            if env and not self:IsSelfENV(env) then
                local s = rawget(env, "script")
                if s and typeof(s) == "Instance" then
                    callingScript = callingScript or (cloneref and cloneref(s) or s)
                end
            end
        end)
    end

    return callingScript, callingFunc
end

function Process:QueueLog(data)
    local settings = Config.Settings
    if settings.Paused then return end
    if not settings.LogExploit and data.isExploit then return end
    if not settings.LogReceive and data.isReceive then return end
    if settings.IgnoreNilParent and data.remote.Parent == nil then return end

    table.insert(logQueue, data)
end

function Process:ProcessQueue()
    if #logQueue <= 0 then return end

    for i = 1, math.min(#logQueue, 5) do
        local data = table.remove(logQueue, 1)
        if data and Ui then
            Ui:CreateLog(data)
        end
    end
end

function Process:StartScheduler()
    local RunService = game:GetService("RunService")
    schedulerConnection = RunService.Heartbeat:Connect(function()
        self:ProcessQueue()
    end)
end

function Process:StopScheduler()
    if schedulerConnection then
        schedulerConnection:Disconnect()
        schedulerConnection = nil
    end
end

function Process:ProcessRemote(info, remote, ...)
    local method = info.Method
    local isReceive = info.IsReceive
    local isExploit = info.IsExploit
    local originalFunc = info.OriginalFunc

    local remote = cloneref and cloneref(remote) or remote
    local id = self:GetRemoteId(remote)

    if self:IsBlacklisted(remote, id) then
        if originalFunc and not isReceive then
            return originalFunc(remote, ...)
        end
        return
    end

    if self:ShouldAutoblock(id) then
        if originalFunc and not isReceive then
            return originalFunc(remote, ...)
        end
        return
    end

    local blocked = self:IsBlocked(remote, id)

    local args = self:DeepClone({...})
    local callingScript, callingFunc = nil, nil

    if not isReceive then
        callingScript, callingFunc = self:GetCallerInfo()
    end

    local data = {
        remote = remote,
        method = method,
        args = args,
        id = id,
        metamethod = info.MetaMethod or "__namecall",
        isReceive = isReceive or false,
        isExploit = isExploit or false,
        callingScript = callingScript,
        callingFunc = callingFunc,
        className = remote.ClassName,
        timestamp = tick(),
        blocked = blocked,
    }

    self:QueueLog(data)

    if blocked then return end

    if originalFunc and not isReceive then
        return originalFunc(remote, ...)
    end
end

function Process:Shutdown()
    self:StopScheduler()
    table.clear(logQueue)
    table.clear(blacklist)
    table.clear(blocklist)
    table.clear(history)
    table.clear(excluding)
    table.clear(instanceCreatedRemotes)
end

return Process
