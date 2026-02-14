local Process = {}

local Config = nil
local Serializer = nil
local Ui = nil

local blacklist = {}
local blocklist = {}
local history = {}
local excluding = {}
local logQueue = {}

local schedulerConnection = nil

local instanceCreatedRemotes = setmetatable({}, {__mode = "k"})

function Process:Init(config, serializer)
    Config = config
    Serializer = serializer

    pcall(function()
        local oldNew
        oldNew = hookfunction(Instance.new, newcclosure(function(className, ...)
            local inst = oldNew(className, ...)
            if typeof(inst) == "Instance" and Config.RemoteClassData[className] then
                instanceCreatedRemotes[inst] = true
            end
            return inst
        end))
    end)
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

function Process:GetRemoteId(remote)
    if not remote then return "" end
    local success, id = pcall(function()
        return remote:GetDebugId()
    end)
    return success and id or tostring(remote)
end

function Process:IsBlacklisted(id)
    return excluding[id] or blacklist[id]
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

    pcall(function()
        local script = getcallingscript()
        if script and typeof(script) == "Instance" then
            callingScript = script
        end
    end)

    return callingScript
end

function Process:BlacklistById(id)
    blacklist[id] = true
end

function Process:BlockById(id)
    blocklist[id] = true
end

function Process:ClearBlacklist()
    table.clear(blacklist)
    table.clear(excluding)
end

function Process:ClearBlocklist()
    table.clear(blocklist)
end

function Process:LogRemote(info)
    local settings = Config.Settings
    if settings.Paused then return end
    if not settings.LogExploit and info.isExploit then return end
    if not settings.LogReceive and info.isReceive then return end

    local remote = info.remote
    local id = self:GetRemoteId(remote)

    if self:IsBlacklisted(id) then return end
    if self:ShouldAutoblock(id) then return end

    if settings.IgnoreNilParent then
        pcall(function()
            if remote.Parent == nil then return end
        end)
    end

    local callingScript = nil
    if not info.isReceive then
        callingScript = self:GetCallerInfo()
    end

    local data = {
        remote = remote,
        method = info.method,
        args = self:DeepClone(info.args),
        id = id,
        metamethod = info.metamethod or "__namecall",
        isReceive = info.isReceive or false,
        isExploit = info.isExploit or false,
        callingScript = callingScript,
        className = remote.ClassName,
        timestamp = tick(),
        blocked = blocklist[id] or false,
    }

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
