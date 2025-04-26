local Hook = {
	OrignalNamecall = nil,
	OrignalIndex = nil,
}

type table = {
	[any]: any
}

type MetaCallback = (Instance, ...any)->...any

--// Modules
local Process

--// This is a custom hookmetamethod function, feel free to replace with your own
--// The callback is expected to return a nil value sometimes which should be ingored
local function HookMetaMethod(self, Call: string, Callback: MetaCallback): MetaCallback
	local CallbackC = newcclosure(Callback)
	local OriginalFunc

	--// Hook metamethod call
	OriginalFunc = hookmetamethod(self, Call, newcclosure(function(...)
		--// Invoke callback and check for a reponce otherwise ignored
		local ReturnValues = CallbackC(...)
		if ReturnValues then
			local Length = table.maxn(ReturnValues)
			return unpack(ReturnValues, 1, Length)
		end

		--// Invoke orignal function
		return OriginalFunc(...)
	end))

	return OriginalFunc
end

local function HookFunction(Func: (...any) -> ...any, Callback: (...any) -> ...any)
	local OriginalFunc

	OriginalFunc = hookfunction(Func, function(...)
		--// Invoke callback and check for a reponce otherwise ignored
		local ReturnValues = Callback(...)
		if ReturnValues then
			local Length = table.maxn(ReturnValues)
			return unpack(ReturnValues, 1, Length)
		end

		--// Invoke orignal function
		return OriginalFunc(...)
	end)
end

--// Replace metatable function method, this can be a workaround on some games if hookmetamethod is detected
--// To use this, just uncomment it and comment out the method above
--//
-- local function HookMetaMethod(self, Call: string, Callback: MetaCallback): MetaCallback
-- 	local Metatable = getrawmetatable(self)
-- 	local OriginalFunc = rawget(Metatable, Call)
	
-- 	--// Replace function
-- 	setreadonly(Metatable, false)
-- 	rawset(Metatable, Call, newcclosure(function(...)
-- 		--// Invoke callback and check for a reponce otherwise ignored
-- 		local ReturnValues = Callback(...)
-- 		if ReturnValues then
-- 			local Length = table.maxn(ReturnValues)
-- 			return unpack(ReturnValues, 1, Length)
-- 		end

-- 		return OriginalFunc(...)
-- 	end))
-- 	setreadonly(Metatable, true)

-- 	return OriginalFunc
-- end

local function Merge(Base: table, New: table)
	for Key, Value in next, New do
		Base[Key] = Value
	end
end

function Hook:RunOnActors(Code: string, ChannelId: number)
	if not getactors then return end
	for _, Actor in getactors() do 
		run_on_actor(Actor, Code, ChannelId)
	end
end

local function ProcessRemote(OriginalFunc, MetaMethod: string, self, Method: string, ...)
	return Process:ProcessRemote({
		Remote = self,
		Method = Method,
		OriginalFunc = OriginalFunc,
		MetaMethod = MetaMethod,
		TransferType = "Send"
	}, ...)
end

function Hook:HookRemoteTypeIndex(ClassName: string, FuncName: string)
	local Remote = Instance.new(ClassName)
	local Func = Remote[FuncName]
	local OriginalFunc

	--// Remotes will share the same functions
	--// 	For example FireServer will be identical
	--// Addionally, this is for __index calls.
	--// 	A __namecall hook will not detect this
	OriginalFunc = HookFunction(Func, function(self, ...)
		--// Check if the Object is allowed 
		if not Process:RemoteAllowed(self, "Send", FuncName) then return end

		--// Process the remote data
		return ProcessRemote(OriginalFunc, "__index", self, FuncName, ...)
	end)
end

function Hook:HookRemoteIndexes()
	local RemoteClassData = Process.RemoteClassData

	for ClassName, Data in RemoteClassData do
		local FuncName = Data.Send[1]
		self:HookRemoteTypeIndex(ClassName, FuncName)
	end
end

function Hook:BeginHooks()
	--// Namecall hook
	local On; On = HookMetaMethod(game, "__namecall", function(self, ...)
		local Method = getnamecallmethod()
		return ProcessRemote(On, "__namecall", self, Method, ...)
	end)

	--// Hook Remote functions
	self:HookRemoteIndexes()

	Merge(self, {
		OrignalNamecall = On,
		--OrignalIndex = Oi
	})
end

function Hook:Index(Object: Instance, Key: string)
	-- local OrignalIndex = self.OrignalIndex
	-- if OrignalIndex then
	-- 	return OrignalIndex(Object, Key)
	-- end
	return Object[Key]
end

function Hook:Init(Data)
    local Modules = Data.Modules
	Process = Modules.Process
end

function Hook:PushConfig(Overwrites)
    Merge(self, Overwrites)
end

function Hook:HookClientInvoke(Remote, Method, Callback): ((...any) -> ...any)?
	local Success, Function = pcall(function()
		return getcallbackvalue(Remote, Method)
	end)

	--// Some executors like Potassium will throw a error if the Callback value is nil
	if not Success then return end

	local PreviousFunction = Function
	Remote[Method] = Callback

	return PreviousFunction
end

function Hook:MultiConnect(Remotes)
	for _, Remote in next, Remotes do
		Hook:ConnectClientRecive(Remote)
	end
end

function Hook:ConnectClientRecive(Remote)
	--// Check if the Remote class is allowed for receiving
	local Allowed = Process:RemoteAllowed(Remote, "Receive")
	if not Allowed then return end

	--// Check if the Object has Remote class data
    local ClassData = Process:GetClassData(Remote)
    if not ClassData then return end

    local IsRemoteFunction = ClassData.IsRemoteFunction
    local Method = ClassData.Receive[1]
	local PreviousFunction = nil

	--// New callback function
	local function Callback(...)
        return Process:ProcessRemote({
            Remote = Remote,
            Method = Method,
            OriginalFunc = PreviousFunction,
            IsReceive = true,
            MetaMethod = "Connect"
        }, ...)
	end

	--// Connect remote
	if not IsRemoteFunction then
   		Remote[Method]:Connect(Callback)
	else -- Remote functions
		self:HookClientInvoke(Remote, Method, Callback)
	end
end

function Hook:BeginService(Libraries, ExtraData, ChannelId, ...)
	--// Librareis
	local ReturnSpoofs = Libraries.ReturnSpoofs
	local ProcessLib = Libraries.Process
	local Communication = Libraries.Communication
	local Generation = Libraries.Generation

	--// Init data
	local InitData = {
		Modules = {
			ReturnSpoofs = ReturnSpoofs,
			Generation = Generation,
			Communication = Communication,
			Process = ProcessLib,
			Hook = self
		}
	}

	print("ChannelId:", ChannelId, "...:", ...)
	
	--// Communication configuration
	local Channel = Communication:GetChannel(ChannelId)
	Communication:Init(InitData)
	Communication:SetChannel(Channel)
	Communication:AddConnection(function(Type: string, Id: string, RemoteData)
		if Type ~= "RemoteData" then return end
		ProcessLib:SetRemoteData(Id, RemoteData)
	end)
	
	--// Process configuration
	ProcessLib:Init(InitData)
	ProcessLib:SetChannelId(ChannelId)
	ProcessLib:SetExtraData(ExtraData)

	--// Hook configuration
	self:Init(InitData)
	self:BeginHooks()
end

return Hook