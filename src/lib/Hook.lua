--[[

	在偷我的方法 💖💖
	我喜欢抄袭狗和小白，真让我恶心

]]

local Hook = {
	OriginalNamecall = nil,
	OriginalIndex = nil,
	PreviousFunctions = {},
	DefaultConfig = {
		FunctionPatches = true
	}
}

type table = {
	[any]: any
}

type MetaFunc = (Instance, ...any) -> ...any
type UnkFunc = (...any) -> ...any

--// 模块
local Modules
local Process
local Configuration
local Config
local Communication

local ExeENV = getfenv(1)

function Hook:Init(Data)
    Modules = Data.Modules

	Process = Modules.Process
	Communication = Modules.Communication or Communication
	Config = Modules.Config or Config
	Configuration = Modules.Configuration or Configuration
end

--// 回调函数有时可能返回 nil 值，这种情况应当被忽略
local HookMiddle = newcclosure(function(OriginalFunc, Callback, AlwaysTable: boolean?, ...)
	--// 调用回调并检查返回值，如果为 nil 则忽略
	local ReturnValues = Callback(...)
	if ReturnValues then
		--// 解包
		if not AlwaysTable then
			return Process:Unpack(ReturnValues)
		end

		--// 返回打包后的结果
		return ReturnValues
	end

	--// 返回打包结果
	if AlwaysTable then
		return {OriginalFunc(...)}
	end

	--// 原始解包调用
	return OriginalFunc(...)
end)

local function Merge(Base: table, New: table)
	for Key, Value in next, New do
		Base[Key] = Value
	end
end

function Hook:Index(Object: Instance, Key: string)
	return Object[Key]
end

function Hook:PushConfig(Overwrites)
    Merge(self, Overwrites)
end

--// getrawmetatable
function Hook:ReplaceMetaMethod(Object: Instance, Call: string, Callback: MetaFunc): MetaFunc
	local Metatable = getrawmetatable(Object)
	local OriginalFunc = clonefunction(Metatable[Call])
	
	--// 替换函数
	setreadonly(Metatable, false)
	Metatable[Call] = newcclosure(function(...)
		return HookMiddle(OriginalFunc, Callback, false, ...)
	end)
	setreadonly(Metatable, true)

	return OriginalFunc
end

--// hookfunction
function Hook:HookFunction(Func: UnkFunc, Callback: UnkFunc)
	local OriginalFunc
	local WrappedCallback = newcclosure(Callback)
	OriginalFunc = clonefunction(hookfunction(Func, function(...)
		return HookMiddle(OriginalFunc, WrappedCallback, false, ...)
	end))
	return OriginalFunc
end

--// hookmetamethod
function Hook:HookMetaCall(Object: Instance, Call: string, Callback: MetaFunc): MetaFunc
	local Metatable = getrawmetatable(Object)
	local Unhooked
	
	Unhooked = self:HookFunction(Metatable[Call], function(...)
		return HookMiddle(Unhooked, Callback, true, ...)
	end)
	return Unhooked
end

function Hook:HookMetaMethod(Object: Instance, Call: string, Callback: MetaFunc): MetaFunc
	local Func = newcclosure(Callback)
	
	--// getrawmetatable 替换
	if Config.ReplaceMetaCallFunc then
		return self:ReplaceMetaMethod(Object, Call, Func)
	end
	
	--// hookmetamethod
	return self:HookMetaCall(Object, Call, Func)
end

--// 包含一些对执行器函数的补丁，防止检测
--// 这并非百分百安全，因为像 hookfunction 之类的函数我无法修补
--// 顺便说一句，谢谢你们抄袭这些代码！超感动的复制粘贴怪们
function Hook:PatchFunctions()
	--// 检查是否在配置里禁用此功能
	if Config.NoFunctionPatching then return end

	local Patches = {
		--// 错误检测补丁
		--// hookfunction 仍可能被检测，取决于执行器
		[pcall] =  function(OldFunc, Func, ...)
			local Responce = {OldFunc(Func, ...)}
			local Success, Error = Responce[1], Responce[2]
			local IsC = iscclosure(Func)

			--// 修复 c-closure 错误检测
			if Success == false and IsC then
				local NewError = Process:CleanCError(Error)
				Responce[2] = NewError
			end

			--// 修复堆栈溢出检测
			if Success == false and not IsC and Error:find("C stack overflow") then
				local Tracetable = Error:split(":")
				local Caller, Line = Tracetable[1], Tracetable[2]
				local Count = Process:CountMatches(Error, Caller)

				if Count == 196 then
					Communication:ConsolePrint(`堆栈溢出已修补，计数为 {Count}`)
					Responce[2] = Error:gsub(`{Caller}:{Line}: `, Caller, 1)
				end
			end

			return Responce
		end,
		[getfenv] = function(OldFunc, Level: number, ...)
			Level = Level or 1

			--// 防止捕获执行器的环境
			if type(Level) == "number" then
				Level += 2
			end

			local Responce = {OldFunc(Level, ...)}
			local ENV = Responce[1]

			--// __tostring 环境检测补丁
			if not checkcaller() and ENV == ExeENV then
				Communication:ConsolePrint("环境逃逸已修补")
				return OldFunc(999999, ...)
			end

			return Responce
		end
	}

	--// hook 每个函数
	for Func, CallBack in Patches do
		local Wrapped = newcclosure(CallBack)
		local OldFunc; OldFunc = self:HookFunction(Func, function(...)
			return Wrapped(OldFunc, ...)
		end)

		--// 缓存原始函数
		self.PreviousFunctions[Func] = OldFunc
	end
end

function Hook:GetOriginalFunc(Func)
	return self.PreviousFunctions[Func] or Func
end

function Hook:RunOnActors(Code: string, ChannelId: number)
	if not getactors or not run_on_actor then return end
	
	local Actors = getactors()
	if not Actors then return end
	
	for _, Actor in Actors do 
		pcall(run_on_actor, Actor, Code, ChannelId)
	end
end

local function ProcessRemote(OriginalFunc, MetaMethod: string, self, Method: string, ...)
	return Process:ProcessRemote({
		Method = Method,
		OriginalFunc = OriginalFunc,
		MetaMethod = MetaMethod,
		TransferType = "Send",
		IsExploit = checkcaller()
	}, self, ...)
end

function Hook:HookRemoteTypeIndex(ClassName: string, FuncName: string)
	local Remote = Instance.new(ClassName)
	local Func = Remote[FuncName]
	local OriginalFunc

	--// 不同 Remote 会共享相同的函数
	--// 例如 FireServer 会完全相同
	--// 此外，这用于 __index 调用
	--// __namecall hook 无法检测到这一点
	OriginalFunc = self:HookFunction(Func, function(self, ...)
		--// 检查是否允许该对象
		if not Process:RemoteAllowed(self, "Send", FuncName) then return end

		--// 处理远程数据
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
	--// Hook Remote 函数
	self:HookRemoteIndexes()

	--// Namecall hook
	local OriginalNameCall
	OriginalNameCall = self:HookMetaMethod(game, "__namecall", function(self, ...)
		local Method = getnamecallmethod()
		return ProcessRemote(OriginalNameCall, "__namecall", self, Method, ...)
	end)

	Merge(self, {
		OriginalNamecall = OriginalNameCall,
		--OriginalIndex = Oi
	})
end

function Hook:HookClientInvoke(Remote, Method, Callback)
	local Success, Function = pcall(function()
		return getcallbackvalue(Remote, Method)
	end)

	--// 一些执行器（例如 Potassium）会在 Callback 为 nil 时抛出错误
	if not Success then return end
	if not Function then return end
	
	--// 尝试 hookfunction
	local HookSuccess = pcall(function()
		self:HookFunction(Function, Callback)
	end)
	if HookSuccess then return end

	--// 否则替换回调函数
	Remote[Method] = function(...)
		return HookMiddle(Function, Callback, false, ...)
	end
end

function Hook:MultiConnect(Remotes)
	for _, Remote in next, Remotes do
		self:ConnectClientRecive(Remote)
	end
end

function Hook:ConnectClientRecive(Remote)
	--// 检查是否允许接收该 Remote 类
	local Allowed = Process:RemoteAllowed(Remote, "Receive")
	if not Allowed then return end

	--// 检查该对象是否有远程类数据
    local ClassData = Process:GetClassData(Remote)
    local IsRemoteFunction = ClassData.IsRemoteFunction
	local NoReciveHook = ClassData.NoReciveHook
    local Method = ClassData.Receive[1]

	--// 检查是否应当 hook 接收
	if NoReciveHook then return end

	--// 新的回调函数
	local function Callback(...)
        return Process:ProcessRemote({
            Method = Method,
            IsReceive = true,
            MetaMethod = "Connect",
			IsExploit = checkcaller()
        }, Remote, ...)
	end

	--// 连接远程
	if not IsRemoteFunction then
   		Remote[Method]:Connect(Callback)
	else -- RemoteFunction
		self:HookClientInvoke(Remote, Method, Callback)
	end
end

function Hook:BeginService(Libraries, ExtraData, ChannelId, ...)
	--// 库
	local ReturnSpoofs = Libraries.ReturnSpoofs
	local ProcessLib = Libraries.Process
	local Communication = Libraries.Communication
	local Generation = Libraries.Generation
	local Config = Libraries.Config

	--// 检查配置覆盖
	ProcessLib:CheckConfig(Config)

	--// 初始化数据
	local InitData = {
		Modules = {
			ReturnSpoofs = ReturnSpoofs,
			Generation = Generation,
			Communication = Communication,
			Process = ProcessLib,
			Config = Config,
			Hook = self
		},
		Services = setmetatable({}, {
			__index = function(self, Name: string): Instance
				local Service = game:GetService(Name)
				return cloneref(Service)
			end,
		})
	}

	--// 初始化库
	Communication:Init(InitData)
	ProcessLib:Init(InitData)

	--// 通信配置
	local Channel, IsWrapped = Communication:GetCommChannel(ChannelId)
	Communication:SetChannel(Channel)
	Communication:AddTypeCallbacks({
		["RemoteData"] = function(Id: string, RemoteData)
			ProcessLib:SetRemoteData(Id, RemoteData)
		end,
		["AllRemoteData"] = function(Key: string, Value)
			ProcessLib:SetAllRemoteData(Key, Value)
		end,
		["UpdateSpoofs"] = function(Content: string)
			local Spoofs = loadstring(Content)()
			ProcessLib:SetNewReturnSpoofs(Spoofs)
		end,
		["BeginHooks"] = function(Config)
			if Config.PatchFunctions then
				self:PatchFunctions()
			end
			self:BeginHooks()
			Communication:ConsolePrint("Hooks 已加载")
		end
	})
	
	--// Process 配置
	ProcessLib:SetChannel(Channel, IsWrapped)
	ProcessLib:SetExtraData(ExtraData)

	--// Hook 配置
	self:Init(InitData)

	if ExtraData and ExtraData.IsActor then
		Communication:ConsolePrint("Actor 已连接！")
	end
end

function Hook:LoadMetaHooks(ActorCode: string, ChannelId: number)
	--// Hook actors
	if not Configuration.NoActors then
		self:RunOnActors(ActorCode, ChannelId)
	end

	--// Hook 当前线程
	self:BeginService(Modules, nil, ChannelId) 
end

function Hook:LoadReceiveHooks()
	local NoReceiveHooking = Config.NoReceiveHooking
	local BlackListedServices = Config.BlackListedServices

	if NoReceiveHooking then return end

	--// Remote 添加时
	game.DescendantAdded:Connect(function(Remote) -- TODO
		self:ConnectClientRecive(Remote)
	end)

	--// 收集父级为 nil 的 Remotes
	self:MultiConnect(getnilinstances())

	--// 遍历搜索 Remotes
	for _, Service in next, game:GetChildren() do
		if table.find(BlackListedServices, Service.ClassName) then continue end
		self:MultiConnect(Service:GetDescendants())
	end
end

function Hook:LoadHooks(ActorCode: string, ChannelId: number)
	self:LoadMetaHooks(ActorCode, ChannelId)
	self:LoadReceiveHooks()
end

return Hook
