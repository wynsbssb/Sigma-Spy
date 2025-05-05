type table = {
	[any]: any
}

type RemoteData = {
	Remote: Instance,
	IsReceive: boolean?,
	Args: table,
	Method: string,
    TransferType: string,
	ValueReplacements: table
}

--// Module
local Generation = {}

--// Modules
local Config
local Hook
local ParserModule
local ThisScript = script

function Generation:Init(Data: table)
    local Modules = Data.Modules
	local Configuration = Modules.Configuration

	--// Modules
	Config = Modules.Config
	Hook = Modules.Hook
	
	--// Import parser
	local ParserUrl = Configuration.ParserUrl
	self:LoadParser(ParserUrl)
end

function Generation:LoadParser(ImportUrl: string)
	local MainPath = `{ImportUrl}/main.lua`
	local MainContent = game:HttpGet(MainPath)
	ParserModule = loadstring(MainContent, "Parser")()
	
	--// Configure Parser imports to use game:HttpGet
	function ParserModule:Import(Name: string)
		local Url = `{ImportUrl}/{Name}.lua`
		local Content = game:HttpGet(Url)
		local Closure = loadstring(Content, Name)
		return Closure()
	end

	--// Load parser module
	ParserModule:Load()
end

function Generation:MakeValueSwapsTable(): table
	local Formatter = ParserModule.Modules.Formatter
	return Formatter:MakeReplacements()
end

function Generation:SetSwapsCallback(Callback: (Interface: table) -> ())
	self.SwapsCallback = Callback
end

function Generation:GetBase(Module): string
	local Version = ParserModule.Version
	local Code = "-- Generated with sigma spy BOIIIIIIIII (+9999999 AURA)\n"
	Code ..= `-- Parser version {Version}\n\n`

	--// Generate variables code
	Code ..= Module.Parser:MakeVariableCode({
		"Services", "Variables", "Remote"
	})

	return Code
end

function Generation:GetSwaps()
	local Func = self.SwapsCallback
	local Swaps = {}

	local Interface = {}
	function Interface:AddSwap(Object: Instance, Data: table)
		if not Object then return end
		Swaps[Object] = Data
	end

	--// Invoke GetSwaps function
	Func(Interface)

	return Swaps
end

function Generation:PickVariableName(): string
	local Names = Config.VariableNames
	return Names[math.random(1, #Names)]
end

function Generation:NewParser()
	local VariableName = self:PickVariableName()
	local Swaps = self:GetSwaps()

	--// Create new parser instance
	local Module = ParserModule:New({
		VariableBase = VariableName,
		Swaps = Swaps,
		IndexFunc = function(...)
			return Hook:Index(...)
		end,
	})

	return Module
end

function Generation:RemoteScript(Module, Data: RemoteData): string
	--// Unpack data
	local Remote = Data.Remote
	local IsReceive = Data.IsReceive
	local Args = Data.Args
	local Method = Data.Method

	--// Remote info
	local ClassName = Hook:Index(Remote, "ClassName")
	local IsNilParent = Hook:Index(Remote, "Parent") == nil
	
	local Variables = Module.Variables
	local Formatter = Module.Formatter
	local Parser = Module.Parser
	
	--// Pre-render variables
	Variables:PrerenderVariables(Args, {"Instance"})

	--// Parse arguments
	local ParsedArgs, ItemsCount = Parser:ParseTableIntoString({
		NoBrackets = true,
		Table = Args
	})

	--// Create remote variable
	local RemoteVariable = Variables:MakeVariable({
		Value = Formatter:Format(Remote, {
			NoVariableCreate = true
		}),
		Comment = `{ClassName} {IsNilParent and " | Remote parent is nil" or ""}`,
		Lookup = Remote,
		Name = Formatter:MakeName(Remote),
		Class = "Remote"
	})

	--// Make code
	local Code = self:GetBase(Module)
	
	--// Firesignal script for client recieves
	if IsReceive then
		local Second = ItemsCount == 0 and "" or `, {ParsedArgs}`
		local Signal = `{RemoteVariable}.{Method}`

		Code ..= `\n-- This data was received from the server`
		Code ..= `\nfiresignal({Signal}{Second})`
		return Code
	end
	
	--// Remote invoke script
	Code ..= `\n{RemoteVariable}:{Method}({ParsedArgs})`
	return Code
end

function Generation:ConnectionsTable(Signal: RBXScriptSignal): table
	local Connections = getconnections(Signal)
	local DataArray = {}

	for _, Connection in next, Connections do
		local Function = Connection.Function
		local Script = rawget(getfenv(Function), "script")

		--// Skip if self
		if Script == ThisScript then continue end

		--// Connection data
		local Data = {
			Function = Function,
			State = Connection.State,
			Script = Script
		}

		table.insert(DataArray, Data)
	end

	return DataArray
end

function Generation:TableScript(Table: table)
	local Module = self:NewParser()

	--// Pre-render variables
	Module.Variables:PrerenderVariables(Table, {"Instance"})

	--// Parse arguments
	local ParsedTable = Module.Parser:ParseTableIntoString({
		Table = Table
	})

	--// Generate script
	local Code = self:GetBase(Module)
	Code ..= `\nreturn {ParsedTable}`

	return Code
end

function Generation:MakeTypesTable(Table: table): table
	local Types = {}

	for Key, Value in next, Table do
		local Type = typeof(Value)
		if Type == "table" then
			Type = self:MakeTypesTable(Value)
		end

		Types[Key] = Type
	end

	return Types
end

function Generation:ConnectionInfo(Remote: Instance, ClassData: table): table
	local ReceiveMethods = ClassData.Receive
	if not ReceiveMethods then return end

	local Connections = {}
	for _, Method: string in next, ReceiveMethods do
		pcall(function() -- TODO: GETCALLBACKVALUE
			local Signal = Hook:Index(Remote, Method)
			Connections[Method] = self:ConnectionsTable(Signal)
		end)
	end

	return Connections
end

function Generation:AdvancedInfo(Data: table): string
	--// Unpack remote data
	local MetaMethod = Data.MetaMethod
	local Function = Data.CallingFunction
	local ClassData = Data.ClassData
	local Method = Data.Method
	local Remote = Data.Remote
	local Script = Data.CallingScript
	local Id = Data.Id
	local Args = Data.Args

	--// Unpack info
	local SourceScript = rawget(getfenv(Function), "script")

	--// Advanced info table base
	local FunctionInfo = {
		["Caller"] = {
			["SourceScript"] = SourceScript,
			["CallingScript"] = Script,
			["CallingFunction"] = Function
		},
		["Remote"] = {
			["Remote"] = Remote,
			["RemoteID"] = Id,
			["Method"] = Method,
			["Connections"] = self:ConnectionInfo(Remote, ClassData)
		},
		["Arguments"] = {
			["Length"] = #Args,
			["Types"] = self:MakeTypesTable(Args),
		},
		["MetaMethod"] = MetaMethod,
		["IsActor"] = Data.IsActor,
	}

	--// Some closures may not be lua
	if islclosure(Function) then
		FunctionInfo["UpValues"] = debug.getupvalues(Function)
		FunctionInfo["Constants"] = debug.getconstants(Function)
	end

	--// Generate script
	return self:TableScript(FunctionInfo)
end

return Generation