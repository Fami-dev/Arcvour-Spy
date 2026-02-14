local Serializer = {}

local HttpService = game:GetService("HttpService")

local instanceCache = {}
local indent = "    "
local nilInstances = nil

local function getNilInstances()
    if not nilInstances then
        nilInstances = (getnilinstances and getnilinstances()) or {}
    end
    return nilInstances
end

local function refreshNilCache()
    nilInstances = nil
end

local function getInstancePath(obj)
    if not obj or typeof(obj) ~= "Instance" then return "nil" end

    local cached = instanceCache[obj]
    if cached then return cached end

    local path = ""
    local current = obj
    local parts = {}

    while current and current ~= game do
        local name = current.Name
        local parent = current.Parent

        if parent == nil then
            for _, inst in getNilInstances() do
                if inst == current then
                    local className = current.ClassName
                    instanceCache[obj] = ('getNil("%s", "%s")'):format(name, className)
                    return instanceCache[obj]
                end
            end
            instanceCache[obj] = "nil --[[ parent is nil ]]"
            return instanceCache[obj]
        end

        local needsBracket = name:match("[^%w_]") or name:match("^%d")
        if needsBracket then
            table.insert(parts, 1, ('[\"%s\"]'):format(name:gsub('"', '\\"')))
        else
            table.insert(parts, 1, "." .. name)
        end

        current = parent
    end

    if current == game then
        path = "game" .. table.concat(parts)

        local firstChild = obj
        local temp = obj
        while temp.Parent and temp.Parent ~= game do
            firstChild = temp
            temp = temp.Parent
        end
        if temp.Parent == game then
            local serviceName = temp.ClassName
            local success = pcall(function()
                game:GetService(serviceName)
            end)
            if success then
                local remaining = path:sub(6 + #temp.Name)
                if remaining:sub(1, 1) == "." then
                    remaining = remaining:sub(2)
                elseif remaining:sub(1, 1) == "[" then
                else
                    remaining = ""
                end
                local servicePath = ('game:GetService("%s")'):format(serviceName)
                if remaining ~= "" then
                    if remaining:sub(1, 1) == "[" then
                        path = servicePath .. remaining
                    else
                        path = servicePath .. "." .. remaining
                    end
                else
                    path = servicePath
                end
            end
        end
    else
        path = "nil --[[ could not resolve path ]]"
    end

    instanceCache[obj] = path
    return path
end

local function escapeString(str)
    local result = str
    result = result:gsub("\\", "\\\\")
    result = result:gsub('"', '\\"')
    result = result:gsub("\n", "\\n")
    result = result:gsub("\r", "\\r")
    result = result:gsub("\t", "\\t")
    result = result:gsub("\0", "\\0")

    local printable = result:gsub("[%g%s]", "")
    if #printable > 0 then
        result = result:gsub("[^%g%s]", function(c)
            return ("\\%d"):format(c:byte())
        end)
    end

    return result
end

local function isArray(t)
    local i = 0
    for _ in pairs(t) do
        i = i + 1
        if t[i] == nil then return false end
    end
    return true
end

function Serializer:ValueToString(value, depth, visited)
    depth = depth or 0
    visited = visited or {}

    local vType = typeof(value)

    if vType == "nil" then
        return "nil"
    end

    if vType == "boolean" then
        return tostring(value)
    end

    if vType == "number" then
        if value ~= value then return "0/0" end
        if value == math.huge then return "math.huge" end
        if value == -math.huge then return "-math.huge" end
        return tostring(value)
    end

    if vType == "string" then
        return '"' .. escapeString(value) .. '"'
    end

    if vType == "Instance" then
        return getInstancePath(value)
    end

    if vType == "Vector3" then
        return ("Vector3.new(%s, %s, %s)"):format(value.X, value.Y, value.Z)
    end

    if vType == "Vector2" then
        return ("Vector2.new(%s, %s)"):format(value.X, value.Y)
    end

    if vType == "CFrame" then
        local components = {value:GetComponents()}
        local str = table.concat(components, ", ")
        return ("CFrame.new(%s)"):format(str)
    end

    if vType == "Color3" then
        local r = math.floor(value.R * 255)
        local g = math.floor(value.G * 255)
        local b = math.floor(value.B * 255)
        return ("Color3.fromRGB(%d, %d, %d)"):format(r, g, b)
    end

    if vType == "BrickColor" then
        return ('BrickColor.new("%s")'):format(tostring(value))
    end

    if vType == "UDim" then
        return ("UDim.new(%s, %s)"):format(value.Scale, value.Offset)
    end

    if vType == "UDim2" then
        return ("UDim2.new(%s, %s, %s, %s)"):format(
            value.X.Scale, value.X.Offset,
            value.Y.Scale, value.Y.Offset
        )
    end

    if vType == "Rect" then
        return ("Rect.new(%s, %s, %s, %s)"):format(
            value.Min.X, value.Min.Y,
            value.Max.X, value.Max.Y
        )
    end

    if vType == "Ray" then
        return ("Ray.new(Vector3.new(%s, %s, %s), Vector3.new(%s, %s, %s))"):format(
            value.Origin.X, value.Origin.Y, value.Origin.Z,
            value.Direction.X, value.Direction.Y, value.Direction.Z
        )
    end

    if vType == "Region3" then
        local cf = value.CFrame
        local size = value.Size
        local min = cf.Position - size / 2
        local max = cf.Position + size / 2
        return ("Region3.new(Vector3.new(%s, %s, %s), Vector3.new(%s, %s, %s))"):format(
            min.X, min.Y, min.Z,
            max.X, max.Y, max.Z
        )
    end

    if vType == "EnumItem" then
        return tostring(value)
    end

    if vType == "Enum" then
        return tostring(value)
    end

    if vType == "Enums" then
        return "Enum"
    end

    if vType == "NumberSequence" then
        local keypoints = value.Keypoints
        local kpStrings = {}
        for _, kp in keypoints do
            table.insert(kpStrings, ("NumberSequenceKeypoint.new(%s, %s, %s)"):format(
                kp.Time, kp.Value, kp.Envelope
            ))
        end
        return ("NumberSequence.new({%s})"):format(table.concat(kpStrings, ", "))
    end

    if vType == "ColorSequence" then
        local keypoints = value.Keypoints
        local kpStrings = {}
        for _, kp in keypoints do
            local c = kp.Value
            local r = math.floor(c.R * 255)
            local g = math.floor(c.G * 255)
            local b = math.floor(c.B * 255)
            table.insert(kpStrings, ("ColorSequenceKeypoint.new(%s, Color3.fromRGB(%d, %d, %d))"):format(
                kp.Time, r, g, b
            ))
        end
        return ("ColorSequence.new({%s})"):format(table.concat(kpStrings, ", "))
    end

    if vType == "NumberRange" then
        return ("NumberRange.new(%s, %s)"):format(value.Min, value.Max)
    end

    if vType == "TweenInfo" then
        return ("TweenInfo.new(%s, %s, %s, %s, %s, %s)"):format(
            value.Time,
            "Enum.EasingStyle." .. value.EasingStyle.Name,
            "Enum.EasingDirection." .. value.EasingDirection.Name,
            value.RepeatCount,
            tostring(value.Reverses),
            value.DelayTime
        )
    end

    if vType == "PathWaypoint" then
        return ("PathWaypoint.new(Vector3.new(%s, %s, %s), %s)"):format(
            value.Position.X, value.Position.Y, value.Position.Z,
            tostring(value.Action)
        )
    end

    if vType == "DateTime" then
        return ("DateTime.fromUnixTimestamp(%s)"):format(value.UnixTimestamp)
    end

    if vType == "Font" then
        return ('Font.new("%s", %s, %s)'):format(
            value.Family,
            "Enum.FontWeight." .. value.Weight.Name,
            "Enum.FontStyle." .. value.Style.Name
        )
    end

    if vType == "table" then
        if visited[value] then
            return '"[Circular Reference]"'
        end
        visited[value] = true

        if next(value) == nil then
            visited[value] = nil
            return "{}"
        end

        local lines = {}
        local currentIndent = indent:rep(depth + 1)
        local closingIndent = indent:rep(depth)
        local arrayMode = isArray(value)

        if arrayMode then
            for i, v in ipairs(value) do
                local serialized = self:ValueToString(v, depth + 1, visited)
                table.insert(lines, currentIndent .. serialized)
            end
        else
            local keys = {}
            for k in pairs(value) do
                table.insert(keys, k)
            end
            table.sort(keys, function(a, b)
                local ta, tb = type(a), type(b)
                if ta == tb then
                    if ta == "number" or ta == "string" then
                        return a < b
                    end
                    return tostring(a) < tostring(b)
                end
                return ta < tb
            end)

            for _, k in keys do
                local v = value[k]
                local keyStr
                if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                    keyStr = k
                else
                    keyStr = "[" .. self:ValueToString(k, depth + 1, visited) .. "]"
                end
                local valStr = self:ValueToString(v, depth + 1, visited)
                table.insert(lines, currentIndent .. keyStr .. " = " .. valStr)
            end
        end

        visited[value] = nil
        return "{\n" .. table.concat(lines, ",\n") .. "\n" .. closingIndent .. "}"
    end

    if vType == "function" then
        return '"[Function]"'
    end

    if vType == "userdata" then
        return ('"[Userdata: %s]"'):format(tostring(value))
    end

    if vType == "thread" then
        return '"[Thread]"'
    end

    if vType == "buffer" then
        return '"[Buffer]"'
    end

    return ('"[Unknown: %s]"'):format(vType)
end

function Serializer:GenerateScript(remote, method, args)
    local remotePath = self:ValueToString(remote)
    local argsStr = ""

    if args and #args > 0 then
        local parts = {}
        for _, arg in ipairs(args) do
            table.insert(parts, self:ValueToString(arg, 0))
        end
        argsStr = table.concat(parts, ", ")
    end

    local header = ""
    local remoteVar = ("local Remote = %s\n"):format(remotePath)

    if method == "FireServer" or method == "fireServer" then
        return header .. remoteVar .. ("Remote:FireServer(%s)\n"):format(argsStr)
    elseif method == "InvokeServer" or method == "invokeServer" then
        return header .. remoteVar .. ("local Result = Remote:InvokeServer(%s)\n"):format(argsStr)
    elseif method == "OnClientEvent" then
        return header .. ("-- Received from server via OnClientEvent\n") ..
            remoteVar .. ("firesignal(Remote.OnClientEvent%s)\n"):format(
                #argsStr > 0 and (", " .. argsStr) or ""
            )
    elseif method == "OnClientInvoke" then
        return header .. ("-- Received via OnClientInvoke\n") ..
            remoteVar .. ("-- Return values: %s\n"):format(argsStr)
    elseif method == "Fire" then
        return header .. remoteVar .. ("Remote:Fire(%s)\n"):format(argsStr)
    elseif method == "Invoke" then
        return header .. remoteVar .. ("local Result = Remote:Invoke(%s)\n"):format(argsStr)
    end

    return header .. remoteVar .. ("Remote:%s(%s)\n"):format(method, argsStr)
end

function Serializer:GenerateBlockScript(remote, method)
    local remotePath = self:ValueToString(remote)
    local header = ""

    return header .. ("local Remote = %s\n"):format(remotePath)
        .. "local Old; Old = hookmetamethod(game, \"__namecall\", function(self, ...)\n"
        .. '    local Method = getnamecallmethod()\n'
        .. ('    if self == Remote and Method == "%s" then\n'):format(method)
        .. "        return\n"
        .. "    end\n"
        .. "    return Old(self, ...)\n"
        .. "end)\n"
end

function Serializer:GenerateRepeatScript(remote, method, args, count)
    count = count or 10
    local base = self:GenerateScript(remote, method, args)
    local lines = base:split("\n")

    local callLine = lines[#lines - 1] or lines[#lines]
    if callLine and callLine:match("^local Result") then
        callLine = callLine:gsub("^local Result = ", "")
    end

    local remotePath = self:ValueToString(remote)
    local header = ""

    return header .. ("local Remote = %s\n"):format(remotePath)
        .. ("for i = 1, %d do\n"):format(count)
        .. ("    %s\n"):format(callLine or "")
        .. "end\n"
end

function Serializer:GenerateSpamScript(remote, method, args)
    local base = self:GenerateScript(remote, method, args)
    local lines = base:split("\n")

    local callLine = lines[#lines - 1] or lines[#lines]

    local remotePath = self:ValueToString(remote)
    local header = ""

    return header .. ("local Remote = %s\n"):format(remotePath)
        .. "while task.wait() do\n"
        .. ("    %s\n"):format(callLine or "")
        .. "end\n"
end

function Serializer:ClearCache()
    table.clear(instanceCache)
    refreshNilCache()
end

return Serializer
