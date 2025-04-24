--// Debug ID interface
local DebugIdRemote = Instance.new("BindableFunction")

--// Module
local Module = {
    CommCallbacks = {},
    DebugIdRemote = DebugIdRemote,
}

--// Modules
local Hook

local Channel

--// DebugId functions
local InvokeGetDebugId = DebugIdRemote.Invoke
function DebugIdRemote.OnInvoke(Object: Instance): string
	return Object:GetDebugId()
end

function Module:Init(Data)
    local Modules = Data.Modules
    Hook = Modules.Hook
end

function Module:SetChannel(NewChannel: number)
    Channel = NewChannel
end

function Module:Warn(...)
    self:Communicate("Warn", ...)
end

function Module:QueueLog(Data)
    self:Communicate("QueueLog", Data)
end

function Module:GetDebugId(Object: Instance): string
	return InvokeGetDebugId(DebugIdRemote, Object)
end

function Module:AddCommCallback(Type: string, Callback: (...any) -> ...any)
    local CommCallbacks = self.CommCallbacks
    CommCallbacks[Type] = Callback
end

function Module:GetCommCallback(Type: string): (...any) -> ...any
    local CommCallbacks = self.CommCallbacks
    return CommCallbacks[Type]
end

function Module:ChannelIndex(Channel, Property: string)
    if typeof(Channel) == "Instance" then
        return Hook:Index(Channel, Property)
    end

    --// Some executors return a UserData type
    return Channel[Property]
end

function Module:Communicate(...)
    local Fire = self:ChannelIndex(Channel, "Fire")
    Fire(Channel, ...)
end

function Module:AddConnection(Callback): RBXScriptConnection
    local Event = self:ChannelIndex(Channel, "Event")
    return Event:Connect(Callback)
end

function Module:AddDefaultCallbacks(Event: BindableEvent)
    self:AddCommCallback("Warn", function(...)
        warn(...)
    end)
end

function Module:CreateChannel(): number
    local ChannelID, Event = create_comm_channel()

    --// Connect GetCommCallback function
    Event.Event:Connect(function(Type: string, ...)
        local Callback = self:GetCommCallback(Type)
        if Callback then
            Callback(...)
        end
    end)

    --// Add default communication callbacks
    self:AddDefaultCallbacks(Event)

    return ChannelID, Event
end

function Module:GetChannel(ChannelId: number)
    return get_comm_channel(ChannelId)
end

return Module