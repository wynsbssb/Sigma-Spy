type table = {
    [any]: any
}

--// 模块
local Module = {
    CommCallbacks = {}
}

local CommWrapper = {}
CommWrapper.__index = CommWrapper

--// 序列化缓存
local SerializeCache = setmetatable({}, {__mode = "k"})
local DeserializeCache = setmetatable({}, {__mode = "k"})

--// Roblox 服务
local CoreGui

--// 模块引用
local Hook
local Channel
local Config
local Process

--// 初始化模块
function Module:Init(Data)
    local Modules = Data.Modules
    local Services = Data.Services

    Hook = Modules.Hook
    Process = Modules.Process
    Config = Modules.Config or Config
    CoreGui = Services.CoreGui
end

--// 将数据加入队列
function CommWrapper:Fire(...)
    local Queue = self.Queue
    table.insert(Queue, {...})
end

--// 处理参数并触发事件
function CommWrapper:ProcessArguments(Arguments) 
    local Channel = self.Channel
    Channel:Fire(Process:Unpack(Arguments))
end

--// 处理队列
function CommWrapper:ProcessQueue()
    local Queue = self.Queue

    for Index = 1, #Queue do
        local Arguments = table.remove(Queue)
        pcall(function()
            self:ProcessArguments(Arguments) 
        end)
    end
end

--// 启动队列处理服务
function CommWrapper:BeginQueueService()
    coroutine.wrap(function()
        while wait() do
            self:ProcessQueue()
        end
    end)()
end

--// 创建新的通信包装器
function Module:NewCommWrap(Channel: BindableEvent)
    local Base = {
        Queue = setmetatable({}, {__mode = "v"}), -- 弱引用队列
        Channel = Channel,
        Event = Channel.Event
    }

    --// 创建包装类实例
    local Wrapped = setmetatable(Base, CommWrapper)
    Wrapped:BeginQueueService()

    return Wrapped
end

--// 创建调试 ID 处理器
function Module:MakeDebugIdHandler(): BindableFunction
    --// 使用 BindableFunction，因为不需要线程权限更改
    local Remote = Instance.new("BindableFunction")
    function Remote.OnInvoke(Object: Instance): string
        return Object:GetDebugId()
    end

    self.DebugIdRemote = Remote
    self.DebugIdInvoke = Remote.Invoke

    return Remote
end

--// 获取对象的调试 ID
function Module:GetDebugId(Object: Instance): string
    local Invoke = self.DebugIdInvoke
    local Remote = self.DebugIdRemote
	return Invoke(Remote, Object)
end

--// 获取隐藏父级，用于存放 BindableEvent
function Module:GetHiddenParent(): Instance
    --// 如果存在 gethui，则使用
    if gethui then return gethui() end
    return CoreGui
end

--// 创建通信通道
function Module:CreateCommChannel(): (number, BindableEvent)
    --// 如果存在原生函数且未强制使用自定义通道，则使用原生
    local Force = Config.ForceUseCustomComm
    if create_comm_channel and not Force then
        return create_comm_channel()
    end

    local Parent = self:GetHiddenParent()
    local ChannelId = math.random(1, 10000000)

    --// 创建 BindableEvent
    local Channel = Instance.new("BindableEvent", Parent)
    Channel.Name = ChannelId

    return ChannelId, Channel
end

--// 获取通信通道
function Module:GetCommChannel(ChannelId: number): BindableEvent?
    local Force = Config.ForceUseCustomComm
    if get_comm_channel and not Force then
        local Channel = get_comm_channel(ChannelId)
        return Channel, false
    end

    local Parent = self:GetHiddenParent()
    local Channel = Parent:FindFirstChild(ChannelId)

    --// 包装通道，防止线程权限错误
    local Wrapped = self:NewCommWrap(Channel)
    return Wrapped, true
end

--// 检查值并序列化或反序列化
function Module:CheckValue(Value, Inbound: boolean?)
    if typeof(Value) ~= "table" then 
        return Value 
    end
   
    if Inbound then
        return self:DeserializeTable(Value)
    end

    return self:SerializeTable(Value)
end

local Tick = 0
--// 用于避免长时间阻塞
function Module:WaitCheck()
    Tick += 1
    if Tick > 40 then
        Tick = 0 -- 可以用取模，但整数会很大
        wait()
    end
end

--// 创建数据包
function Module:MakePacket(Index, Value): table
    self:WaitCheck()
    return {
        Index = self:CheckValue(Index), 
        Value = self:CheckValue(Value)
    }
end

--// 读取数据包
function Module:ReadPacket(Packet: table): (any, any)
    if typeof(Packet) ~= "table" then return Packet end
    
    local Key = self:CheckValue(Packet.Index, true)
    local Value = self:CheckValue(Packet.Value, true)
    self:WaitCheck()

    return Key, Value
end

--// 序列化表
function Module:SerializeTable(Table: table): table
    local Cached = SerializeCache[Table]
    if Cached then return Cached end

    local Serialized = {}
    SerializeCache[Table] = Serialized

    for Index, Value in next, Table do
        local Packet = self:MakePacket(Index, Value)
        table.insert(Serialized, Packet)
    end

    return Serialized
end

--// 反序列化表
function Module:DeserializeTable(Serialized: table): table
    local Cached = DeserializeCache[Serialized]
    if Cached then return Cached end

    local Table = {}
    DeserializeCache[Serialized] = Table
    
    for _, Packet in next, Serialized do
        local Index, Value = self:ReadPacket(Packet)
        if Index == nil then continue end

        Table[Index] = Value
    end

    return Table
end

--// 设置全局通信通道
function Module:SetChannel(NewChannel: number)
    Channel = NewChannel
end

--// 打印到控制台
function Module:ConsolePrint(...)
    self:Communicate("Print", ...)
end

--// 队列日志
function Module:QueueLog(Data)
    spawn(function()
        local SerializedArgs = self:SerializeTable(Data.Args)
        Data.Args = SerializedArgs

        self:Communicate("QueueLog", Data)
    end)
end

--// 添加通信回调
function Module:AddCommCallback(Type: string, Callback: (...any) -> ...any)
    local CommCallbacks = self.CommCallbacks
    CommCallbacks[Type] = Callback
end

--// 获取通信回调
function Module:GetCommCallback(Type: string): (...any) -> ...any
    local CommCallbacks = self.CommCallbacks
    return CommCallbacks[Type]
end

--// 获取通道属性
function Module:ChannelIndex(Channel, Property: string)
    if typeof(Channel) == "Instance" then
        return Hook:Index(Channel, Property)
    end

    --// 一些执行器返回 UserData 类型
    return Channel[Property]
end

--// 发送通信数据
function Module:Communicate(...)
    local Fire = self:ChannelIndex(Channel, "Fire")
    Fire(Channel, ...)
end

--// 添加事件连接
function Module:AddConnection(Callback): RBXScriptConnection
    local Event = self:ChannelIndex(Channel, "Event")
    return Event:Connect(Callback)
end

--// 根据类型添加回调
function Module:AddTypeCallback(Type: string, Callback): RBXScriptConnection
    local Event = self:ChannelIndex(Channel, "Event")
    return Event:Connect(function(RecivedType: string, ...)
        if RecivedType ~= Type then return end
        Callback(...)
    end)
end

--// 添加多个类型回调
function Module:AddTypeCallbacks(Types: table)
    for Type: string, Callback in next, Types do
        self:AddTypeCallback(Type, Callback)
    end
end

--// 创建通道并绑定通信回调
function Module:CreateChannel(): number
    local ChannelID, Event = self:CreateCommChannel()

    --// 连接回调函数
    Event.Event:Connect(function(Type: string, ...)
        local Callback = self:GetCommCallback(Type)
        if Callback then
            Callback(...)
        end
    end)

    return ChannelID, Event
end

Module:MakeDebugIdHandler()

return Module
