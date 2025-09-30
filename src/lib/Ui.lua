local Ui = {
	DefaultEditorContent = [=[--[[
	Sigma Spy, 由 depso 编写
	钩子重写及更多修复！

	Discord: https://discord.gg/bkUkm2vSbv
]]]=],
	LogLimit = 100, -- 日志限制
    SeasonLabels = { -- 季节标签
        January = "⛄ %s ⛄", -- 一月
        February = "🌨️ %s 🏂", -- 二月
        March = "🌹 %s🌺 ", -- 三月
        April = "🐣 %s ✝️", -- 四月
        May = "🐝 %s 🌞", -- 五月
        June = "🌲 %s 🥕", -- 六月
        July = "🌊 %s 🌅", -- 七月
        August = "☀️ %s 🌞", -- 八月
        September = "🍁 %s 🍁", -- 九月
        October = "🎃 %s 🎃", -- 十月
        November = "🍂 %s 🍂", -- 十一月
        December = "🎄 %s 🎁" -- 十二月
    },
	Scales = { -- 界面尺寸
		["Mobile"] = UDim2.fromOffset(480, 280), -- 移动端
		["Desktop"] = UDim2.fromOffset(600, 400), -- 桌面端
	},
    BaseConfig = { -- 基础配置
        Theme = "SigmaSpy",
        NoScroll = true, -- 无滚动条
    },
	OptionTypes = { -- 选项类型映射
		boolean = "Checkbox", -- 布尔值 -> 复选框
	},
	DisplayRemoteInfo = { -- 显示的远程信息项
		"MetaMethod", -- 元方法
		"Method", -- 方法
		"Remote", -- 远程对象
		"CallingScript", -- 调用脚本
		"IsActor", -- 是否为Actor
		"Id" -- ID
	},

    Window = nil, -- 主窗口
    RandomSeed = Random.new(tick()), -- 随机种子
	Logs = setmetatable({}, {__mode = "k"}), -- 日志存储（弱引用键）
	LogQueue = setmetatable({}, {__mode = "v"}), -- 日志队列（弱引用值）
}

type table = {
	[any]: any
}

type Log = { -- 日志类型定义
	Remote: Instance, -- 远程对象
	Method: string, -- 方法名
	Args: table, -- 参数
	IsReceive: boolean?, -- 是否为接收端
	MetaMethod: string?, -- 元方法
	OrignalFunc: ((...any) -> ...any)?, -- 原始函数
	CallingScript: Instance?, -- 调用脚本
	CallingFunction: ((...any) -> ...any)?, -- 调用函数
	ClassData: table?, -- 类数据
	ReturnValues: table?, -- 返回值
	RemoteData: table?, -- 远程数据
	Id: string, -- ID
	Selectable: table, -- 可选择项（UI元素）
	HeaderData: table, -- 头部数据
	ValueSwaps: table, -- 值替换表
	Timestamp: number, -- 时间戳
	IsExploit: boolean -- 是否由漏洞利用工具调用
}

--// 兼容性
local SetClipboard = setclipboard or toclipboard or set_clipboard -- 设置剪贴板函数

--// 库
local ReGui = loadstring(game:HttpGet('https://github.com/depthso/Dear-ReGui/raw/refs/heads/main/ReGui.lua'), "ReGui")() -- 加载ReGui库

--// 模块
local Flags -- 标志模块
local Generation -- 生成模块
local Process -- 处理模块
local Hook  -- 钩子模块
local Config -- 配置模块
local Communication -- 通信模块
local Files -- 文件模块

local ActiveData = nil -- 当前选中的日志数据
local RemotesCount = 0 -- 远程对象计数

local TextFont = Font.fromEnum(Enum.Font.Code) -- 文本字体
local FontSuccess = false -- 字体加载是否成功
local CommChannel -- 通信通道

function Ui:Init(Data) -- 初始化
    local Modules = Data.Modules

	--// 模块
	Flags = Modules.Flags -- 标志
	Generation = Modules.Generation -- 生成
	Process = Modules.Process -- 处理
	Hook = Modules.Hook -- 钩子
	Config = Modules.Config -- 配置
	Communication = Modules.Communication -- 通信
	Files = Modules.Files -- 文件

	--// ReGui
	self:LoadFont() -- 加载字体
	self:LoadReGui() -- 加载ReGui
	self:CheckScale() -- 检查尺寸
end

function Ui:SetCommChannel(NewCommChannel: BindableEvent) -- 设置通信通道
	CommChannel = NewCommChannel
end

function Ui:CheckScale() -- 检查尺寸
	local BaseConfig = self.BaseConfig
	local Scales = self.Scales

	local IsMobile = ReGui:IsMobileDevice() -- 是否为移动设备
	local Device = IsMobile and "Mobile" or "Desktop" -- 设备类型

	BaseConfig.Size = Scales[Device] -- 设置尺寸
end

function Ui:SetClipboard(Content: string) -- 设置剪贴板
	SetClipboard(Content)
end

function Ui:TurnSeasonal(Text: string): string -- 添加季节装饰
    local SeasonLabels = self.SeasonLabels
    local Month = os.date("%B") -- 获取月份
    local Base = SeasonLabels[Month] -- 获取对应月份的格式

    return Base:format(Text) -- 格式化文本
end

function Ui:LoadFont() -- 加载字体
	local FontFile = self.FontJsonFile

	--// 获取字体资源ID
	local AssetId = Files:LoadCustomasset(FontFile) -- 加载自定义资源
	if not AssetId then return end -- 失败则返回

	--// 创建自定义字体
	local NewFont = Font.new(AssetId) -- 创建新字体
	TextFont = NewFont
	FontSuccess = true -- 标记成功
end

function Ui:SetFontFile(FontFile: string) -- 设置字体文件
	self.FontJsonFile = FontFile
end

function Ui:FontWasSuccessful() -- 检查字体是否加载成功
	if FontSuccess then return end -- 成功则返回

	--// 错误消息
	self:ShowModal({ -- 显示模态窗口
		"很遗憾，您的执行器无法下载字体，因此已切换至深色主题。",
		"\n如果您想使用 ImGui 主题，\n请下载字体 (assets/ProggyClean.ttf)",
		"并将其放在您的工作区文件夹中\n(Sigma Spy/assets)"
	})
end

function Ui:LoadReGui() -- 加载ReGui
	local ThemeConfig = Config.ThemeConfig -- 主题配置
	ThemeConfig.TextFont = TextFont -- 设置文本字体

	--// ReGui
	ReGui:DefineTheme("SigmaSpy", ThemeConfig) -- 定义主题
end

type CreateButtons = { -- 创建按钮配置类型
	Base: table?, -- 基础配置
	Buttons: table, -- 按钮列表
	NoTable: boolean? -- 是否不使用表格布局
}
function Ui:CreateButtons(Parent, Data: CreateButtons) -- 创建按钮
	local Base = Data.Base or {} -- 基础配置（默认为空）
	local Buttons = Data.Buttons -- 按钮列表
	local NoTable = Data.NoTable -- 是否不使用表格布局

	--// 创建表格布局
	if not NoTable then
		Parent = Parent:Table({ -- 创建表格
			MaxColumns = 3 -- 最大列数
		}):NextRow() -- 下一行
	end

	--// 创建按钮
	for _, Button in next, Buttons do
		local Container = Parent
		if not NoTable then
			Container = Parent:NextColumn() -- 下一列
		end

		ReGui:CheckConfig(Button, Base) -- 检查并合并配置
		Container:Button(Button) -- 创建按钮
	end
end

function Ui:CreateWindow(WindowConfig) -- 创建窗口
    local BaseConfig = self.BaseConfig -- 基础配置
	local Config = Process:DeepCloneTable(BaseConfig) -- 深度克隆
	Process:Merge(Config, WindowConfig) -- 合并配置

	--// 创建窗口
	local Window = ReGui:Window(Config)

	--// 如果字体无法加载，则切换至深色主题
	if not FontSuccess then 
		Window:SetTheme("DarkTheme") -- 设置主题为深色主题
	end
	
	--// 返回窗口
	return Window
end

type AskConfig = { -- 询问用户配置类型
	Title: string, -- 标题
	Content: table, -- 内容（行列表）
	Options: table -- 选项列表
}
function Ui:AskUser(Config: AskConfig): string -- 询问用户
	local Window = self.Window
	local Answered = false -- 用户是否已回答

	--// 创建模态窗口
	local ModalWindow = Window:PopupModal({ -- 弹出模态窗口
		Title = Config.Title -- 标题
	})
	ModalWindow:Label({ -- 标签（内容）
		Text = table.concat(Config.Content, "\n"), -- 连接内容行
		TextWrapped = true -- 文本自动换行
	})
	ModalWindow:Separator() -- 分隔线

	--// 答案按钮
	local Row = ModalWindow:Row({ -- 行
		Expanded = true -- 扩展
	})
	for _, Answer in next, Config.Options do -- 遍历选项
		Row:Button({ -- 创建按钮
			Text = Answer, -- 按钮文本
			Callback = function() -- 回调函数
				Answered = Answer -- 设置答案
				ModalWindow:ClosePopup() -- 关闭模态窗口
			end,
		})
	end

	repeat wait() until Answered -- 等待用户回答
	return Answered -- 返回答案
end

function Ui:CreateMainWindow() -- 创建主窗口
	local Window = self:CreateWindow() -- 创建窗口
	self.Window = Window -- 存储窗口引用

	--// 检查字体是否成功下载
	self:FontWasSuccessful()
	self:AuraCounterService() -- 启动AURA计数器服务

	--// UI可见性标志回调
	Flags:SetFlagCallback("UiVisible", function(self, Visible) -- 设置标志回调
		Window:SetVisible(Visible) -- 设置窗口可见性
	end)

	return Window -- 返回窗口
end

function Ui:ShowModal(Lines: table) -- 显示模态窗口
	local Window = self.Window
	local Message = table.concat(Lines, "\n") -- 连接消息行

	--// 模态窗口
	local ModalWindow = Window:PopupModal({ -- 弹出模态窗口
		Title = "Sigma Spy --汉化版" -- 标题
	})
	ModalWindow:Label({ -- 标签（消息）
		Text = Message, -- 消息文本
		RichText = true, -- 富文本
		TextWrapped = true -- 文本自动换行
	})
	ModalWindow:Button({ -- 按钮
		Text = "确定", -- 按钮文本
		Callback = function() -- 回调函数
			ModalWindow:ClosePopup() -- 关闭模态窗口
		end,
	})
end

function Ui:ShowUnsupportedExecutor(Name: string) -- 显示不支持的执行器消息
	Ui:ShowModal({ -- 显示模态窗口
		"很遗憾，Sigma Spy 不支持您的执行器。",
		"最好的免费选择是 Swift (discord.gg/getswiftgg)",
		`\n您的执行器: {Name}` -- 显示执行器名称
	})
end

function Ui:ShowUnsupported(FuncName: string) -- 显示不支持的功能消息
	Ui:ShowModal({ -- 显示模态窗口
		"很遗憾，Sigma Spy 不支持您的执行器。",
		`\n缺失的函数: {FuncName}` -- 显示缺失的函数名
	})
end

function Ui:CreateOptionsForDict(Parent, Dict: table, Callback) -- 为字典创建选项
	local Options = {}

	--// 字典包装
	for Key, Value in next, Dict do
		Options[Key] = {
			Value = Value, -- 当前值
			Label = Key, -- 标签（键名）
			Callback = function(_, Value) -- 回调函数
				Dict[Key] = Value -- 更新字典值

				--// 调用回调函数
				if not Callback then return end
				Callback()
			end
		}
	end

	--// 创建元素
	self:CreateElements(Parent, Options) -- 创建选项元素
end

function Ui:CheckKeybindLayout(Container, KeyCode: Enum.KeyCode, Callback) -- 检查快捷键布局
	if not KeyCode then return Container end -- 无快捷键则返回原容器

	--// 创建行布局
	Container = Container:Row({ -- 创建行
		HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween -- 水平对齐（两端对齐）
	})

	--// 添加快捷键元素
	Container:Keybind({ -- 创建快捷键元素
		Label = "", -- 无标签
		Value = KeyCode, -- 键值
		LayoutOrder = 2, -- 布局顺序
		IgnoreGameProcessed = false, -- 不忽略游戏处理
		Callback = function() -- 回调函数
			--// 检查快捷键是否启用
			local Enabled = Flags:GetFlagValue("KeybindsEnabled") -- 获取标志值
			if not Enabled then return end -- 未启用则返回

			--// 调用回调函数
			Callback()
		end,
	})

	return Container -- 返回容器
end

function Ui:CreateElements(Parent, Options) -- 创建选项元素
	local OptionTypes = self.OptionTypes -- 选项类型映射
	
	--// 创建表格布局
	local Table = Parent:Table({ -- 创建表格
		MaxColumns = 3 -- 最大列数
	}):NextRow() -- 下一行

	for Name, Data in next, Options do -- 遍历选项
		local Value = Data.Value -- 值
		local Type = typeof(Value) -- 值类型

		--// 为选项表添加缺失值
		ReGui:CheckConfig(Data, { -- 检查并合并配置
			Class = OptionTypes[Type], -- 根据类型获取UI类
			Label = Name, -- 标签（选项名）
		})
		
		--// 检查值类型是否存在对应的UI元素类型
		local Class = Data.Class -- UI类
		assert(Class, `不存在 {Type} 类型的选项`) -- 断言存在

		local Container = Table:NextColumn() -- 下一列容器
		local Checkbox = nil -- 复选框引用（用于快捷键）

		--// 检查快捷键布局
		local Keybind = Data.Keybind -- 快捷键
		Container = self:CheckKeybindLayout(Container, Keybind, function() -- 处理快捷键布局
			Checkbox:Toggle() -- 切换复选框状态
		end)
		
		--// 创建列和元素
		Checkbox = Container[Class](Container, Data) -- 创建元素（复选框、滑块等）
	end
end

--// 兄弟，你对 Sigma Spy 说了啥？ 💀💀
function Ui:DisplayAura() -- 显示AURA
    local Window = self.Window
    local Rand = self.RandomSeed -- 随机数生成器

	--// AURA (兄弟)
    local AURA = Rand:NextInteger(1, 9999999) -- 随机AURA值
    local AURADELAY = Rand:NextInteger(1, 5) -- 随机延迟

	--// 标题
	local Title = `Sigma Spy | AURA: {AURA}` -- 标题模板
	local Seasonal = self:TurnSeasonal(Title) -- 添加季节装饰
    Window:SetTitle(Seasonal) -- 设置窗口标题

    wait(AURADELAY) -- 等待延迟
end

function Ui:AuraCounterService() -- AURA计数器服务
    task.spawn(function() -- 创建协程
        while true do
            self:DisplayAura() -- 持续显示AURA
        end
    end)
end

function Ui:CreateWindowContent(Window) -- 创建窗口内容
    --// 窗口组布局
    local Layout = Window:List({ -- 创建列表布局
        UiPadding = 2, -- UI内边距
        HorizontalFlex = Enum.UIFlexAlignment.Fill, -- 水平填充
        VerticalFlex = Enum.UIFlexAlignment.Fill, -- 垂直填充
        FillDirection = Enum.FillDirection.Vertical, -- 填充方向（垂直）
        Fill = true -- 填充
    })

	--// 远程对象列表
    self.RemotesList = Layout:Canvas({ -- 创建画布（可滚动）
        Scroll = true, -- 可滚动
        UiPadding = 5, -- UI内边距
        AutomaticSize = Enum.AutomaticSize.None, -- 非自动尺寸
        FlexMode = Enum.UIFlexMode.None, -- 非Flex模式
        Size = UDim2.new(0, 130, 1, 0) -- 尺寸（固定宽度130）
    })

	--// 选项卡选择器
	local InfoSelector = Layout:TabSelector({ -- 创建选项卡选择器
        NoAnimation = true, -- 无动画
        Size = UDim2.new(1, -130, 0.4, 0), -- 尺寸（宽度减去130，高度40%）
    })

	self.InfoSelector = InfoSelector -- 存储引用
	self.CanvasLayout = Layout -- 存储引用

	--// 创建选项卡
	self:MakeEditorTab(InfoSelector) -- 编辑器选项卡
	self:MakeOptionsTab(InfoSelector) -- 选项选项卡
	
	if Config.Debug then -- 调试模式
		self:ConsoleTab(InfoSelector) -- 控制台选项卡
	end
end

function Ui:ConsoleTab(InfoSelector) -- 控制台选项卡
	local Tab = InfoSelector:CreateTab({ -- 创建选项卡
		Name = "控制台" -- 选项卡名称
	})

	local Console -- 控制台引用
	local ButtonsRow = Tab:Row() -- 创建按钮行

	ButtonsRow:Button({ -- 清除按钮
		Text = "清除",
		Callback = function()
			Console:Clear() -- 清除控制台内容
		end
	})
	ButtonsRow:Button({ -- 复制按钮
		Text = "复制",
		Callback = function()
			toclipboard(Console:GetValue()) -- 复制控制台内容到剪贴板
		end
	})
	ButtonsRow:Button({ -- 暂停按钮
		Text = "暂停",
		Callback = function(self) -- 按钮自身引用
			local Enabled = not Console.Enabled -- 切换启用状态
			local Text = Enabled and "暂停" or "已暂停" -- 更新按钮文本
			self.Text = Text -- 设置按钮文本

			--// 更新控制台状态
			Console.Enabled = Enabled
		end,
	})
	ButtonsRow:Expand() -- 扩展行

	--// 创建控制台
	Console = Tab:Console({ -- 创建控制台元素
		Text = "-- 由 depso 创建", -- 初始文本
		ReadOnly = true, -- 只读
		Border = false, -- 无边框
		Fill = true, -- 填充
		Enabled = true, -- 启用
		AutoScroll = true, -- 自动滚动
		RichText = true, -- 富文本
		MaxLines = 50 -- 最大行数
	})

	self.Console = Console -- 存储引用
end

function Ui:ConsoleLog(...: string?) -- 控制台日志
	local Console = self.Console
	if not Console then return end -- 控制台未初始化则返回

	Console:AppendText(...) -- 追加文本
end

function Ui:MakeOptionsTab(InfoSelector) -- 选项选项卡
	local Tab = InfoSelector:CreateTab({ -- 创建选项卡
		Name = "选项" -- 选项卡名称
	})

	--// 添加全局选项
	Tab:Separator({Text="日志"}) -- 日志分隔线
	self:CreateButtons(Tab, { -- 创建按钮组
		Base = { -- 基础配置
			Size = UDim2.new(1, 0, 0, 20), -- 尺寸（宽度100%，高度20）
			AutomaticSize = Enum.AutomaticSize.Y, -- 高度自动
		},
		Buttons = { -- 按钮列表
			{
				Text = "清除日志", -- 清除日志按钮
				Callback = function()
					local Tab = ActiveData and ActiveData.Tab or nil -- 当前选中的远程选项卡

					--// 移除远程选项卡
					if Tab then
						InfoSelector:RemoveTab(Tab) -- 移除选项卡
					end

					--// 清除所有日志元素
					ActiveData = nil -- 清空当前选中数据
					self:ClearLogs() -- 清除日志
				end,
			},
			{
				Text = "清除阻止", -- 清除阻止按钮
				Callback = function()
					Process:UpdateAllRemoteData("Blocked", false) -- 将所有远程的Blocked标志设为false
				end,
			},
			{
				Text = "清除排除", -- 清除排除按钮
				Callback = function()
					Process:UpdateAllRemoteData("Excluded", false) -- 将所有远程的Excluded标志设为false
				end,
			},
			{
				Text = "加入 Discord", -- 加入 Discord 按钮
				Callback = function()
					Process:PromptDiscordInvite("s9ngmUDWgb") -- 提示加入Discord
					self:SetClipboard("https://discord.gg/s9ngmUDWgb") -- 复制链接到剪贴板
				end,
			},
			{
				Text = "复制 Github", -- 复制 Github 按钮
				Callback = function()
					self:SetClipboard("https://github.com/depthso/Sigma-Spy") -- 复制链接到剪贴板
				end,
			},
			{
				Text = "编辑脚本", -- 编辑脚本按钮
				Callback = function()
					self:EditFile("Return spoofs.lua", true, function(Window, Content: string) -- 编辑文件
						Window:Close() -- 关闭窗口
						CommChannel:Fire("UpdateSpoofs", Content) -- 通过通信通道更新脚本
					end)
				end,
			}
		}
	})

	--// 标志选项
	Tab:Separator({Text="设置"}) -- 设置分隔线
	self:CreateElements(Tab, Flags:GetFlags()) -- 创建标志选项元素

	self:AddDetailsSection(Tab) -- 添加详细信息部分
end

function Ui:AddDetailsSection(OptionsTab) -- 添加详细信息部分
	OptionsTab:Separator({Text="信息"}) -- 信息分隔线
	OptionsTab:BulletText({ -- 项目符号文本
		Rows = { -- 行列表
			"Sigma spy - 由 depso 编写！",
			"库: Roblox-Parser, Dear-ReGui",
			"感谢 syn.lua 建议我制作这个工具"
		}
	})
end

local function MakeActiveDataCallback(Name: string) -- 创建当前数据回调函数
	return function(...)
		if not ActiveData then return end -- 无当前数据则返回
		return ActiveData[Name](ActiveData, ...) -- 调用当前数据的指定方法
	end
end

function Ui:MakeEditorTab(InfoSelector) -- 编辑器选项卡
	local Default = self.DefaultEditorContent -- 默认编辑器内容
	local SyntaxColors = Config.SyntaxColors -- 语法高亮颜色

	--// 创建选项卡
	local EditorTab = InfoSelector:CreateTab({ -- 创建选项卡
		Name = "编辑器" -- 选项卡名称
	})

	--// 代码编辑器
	local CodeEditor = EditorTab:CodeEditor({ -- 创建代码编辑器
		Fill = true, -- 填充
		Editable = true, -- 可编辑
		FontSize = 13, -- 字体大小
		Colors = SyntaxColors, -- 语法高亮颜色
		FontFace = TextFont, -- 字体
		Text = Default -- 初始文本
	})

	--// 按钮
	local ButtonsRow = EditorTab:Row() -- 创建按钮行
	self:CreateButtons(ButtonsRow, { -- 创建按钮组
		NoTable = true, -- 不使用表格布局
		Buttons = { -- 按钮列表
			{
				Text = "复制", -- 复制按钮
				Callback = function()
					local Script = CodeEditor:GetText() -- 获取编辑器文本
					self:SetClipboard(Script) -- 复制到剪贴板
				end
			},
			{
				Text = "运行", -- 运行按钮
				Callback = function()
					local Script = CodeEditor:GetText() -- 获取编辑器文本
					local Func, Error = loadstring(Script, "SigmaSpy-USERSCRIPT") -- 加载脚本

					--// 语法检查
					if not Func then
						self:ShowModal({"运行脚本出错！\n", Error}) -- 显示错误消息
						return
					end

					Func() -- 执行脚本
				end
			},
			{
				Text = "获取返回值", -- 获取返回值按钮
				Callback = MakeActiveDataCallback("GetReturn") -- 绑定到当前数据的GetReturn方法
			},
			{
				Text = "脚本选项", -- 脚本选项按钮
				Callback = MakeActiveDataCallback("ScriptOptions") -- 绑定到当前数据的ScriptOptions方法
			},
			{
				Text = "构建", -- 构建按钮
				Callback = MakeActiveDataCallback("BuildScript") -- 绑定到当前数据的BuildScript方法
			},
			{
				Text = "弹出", -- 弹出按钮
				Callback = function()
					local Script = CodeEditor:GetText() -- 获取编辑器文本
					local Tile = ActiveData and ActiveData.Task or "Sigma Spy" -- 窗口标题（默认为"Sigma Spy"）
					self:MakeEditorPopoutWindow(Script, { -- 创建弹出式编辑器窗口
						Title = Tile -- 窗口标题
					})
				end
			},
		}
	})
	
	self.CodeEditor = CodeEditor -- 存储引用
end

function Ui:ShouldFocus(Tab): boolean -- 检查是否应聚焦到选项卡
	local InfoSelector = self.InfoSelector
	local ActiveTab = InfoSelector.ActiveTab -- 当前活动选项卡

	--// 如果没有活动选项卡
	if not ActiveTab then
		return true -- 应聚焦
	end

	return InfoSelector:CompareTabs(ActiveTab, Tab) -- 比较选项卡是否相同
end

function Ui:MakeEditorPopoutWindow(Content: string, WindowConfig: table) -- 创建弹出式编辑器窗口
	local Window = self:CreateWindow(WindowConfig) -- 创建窗口
	local Buttons = WindowConfig.Buttons or {} -- 按钮列表（默认为空）
	local Colors = Config.SyntaxColors -- 语法高亮颜色

	local CodeEditor = Window:CodeEditor({ -- 创建代码编辑器
		Text = Content, -- 内容
		Editable = true, -- 可编辑
		Fill = true, -- 填充
		FontSize = 13, -- 字体大小
		Colors = Colors, -- 语法高亮颜色
		FontFace = TextFont -- 字体
	})

	--// 默认按钮（复制）
	table.insert(Buttons, {
		Text = "复制", -- 复制按钮
		Callback = function()
			local Script = CodeEditor:GetText() -- 获取编辑器文本
			self:SetClipboard(Script) -- 复制到剪贴板
		end
	})

	--// 按钮
	local ButtonsRow = Window:Row() -- 创建按钮行
	self:CreateButtons(ButtonsRow, { -- 创建按钮组
		NoTable = true, -- 不使用表格布局
		Buttons = Buttons -- 按钮列表
	})

	Window:Center() -- 窗口居中
	return CodeEditor, Window -- 返回编辑器和窗口引用
end

function Ui:EditFile(FilePath: string, InFolder: boolean, OnSaveFunc: ((table, string) -> nil)?) -- 编辑文件
	local Folder = Files.FolderName -- Sigma Spy文件夹名
	local CodeEditor, Window -- 编辑器、窗口引用

	--// 相对于Sigma Spy文件夹
	if InFolder then
		FilePath = `{Folder}/{FilePath}` -- 构建完整路径
	end

	--// 获取文件内容
	local Content = readfile(FilePath) -- 读取文件
	Content = Content:gsub("\r\n", "\n") -- 替换换行符（兼容Windows）
	
	local Buttons = { -- 按钮列表（保存按钮）
		{
			Text = "保存", -- 保存按钮
			Callback = function()
				local Script = CodeEditor:GetText() -- 获取编辑器文本
				local Success, Error = loadstring(Script, "SigmaSpy-Editor") -- 语法检查

				--// 语法检查
				if not Success then
					self:ShowModal({"保存文件出错！\n", Error}) -- 显示错误消息
					return
				end
				
				--// 保存内容
				writefile(FilePath, Script) -- 写入文件

				--// 调用保存后函数（如果存在）
				if OnSaveFunc then
					OnSaveFunc(Window, Script)
				end
			end
		}
	}

	--// 创建编辑器窗口
	CodeEditor, Window = self:MakeEditorPopoutWindow(Content, { -- 创建弹出式编辑器窗口
		Title = `正在编辑: {FilePath}`, -- 窗口标题
		Buttons = Buttons -- 按钮列表
	})
end

type MenuOptions = { -- 菜单选项类型
	[string]: (GuiButton, ...any) -> nil -- 选项名: 回调函数
}
function Ui:MakeButtonMenu(Button: Instance, Unpack: table, Options: MenuOptions) -- 创建按钮菜单
	local Window = self.Window
	local Popup = Window:PopupCanvas({ -- 创建弹出画布
		RelativeTo = Button, -- 相对于按钮
		MaxSizeX = 500, -- 最大宽度
	})

	--// 为字符串、函数创建选择项
	for Name, Func in next, Options do
		 Popup:Selectable({ -- 创建可选择项
			Text = Name, -- 选项文本
			Callback = function()
				Func(Process:Unpack(Unpack)) -- 调用函数并解包参数
			end,
		})
	end
end

function Ui:RemovePreviousTab(Title: string): boolean -- 移除之前的选项卡
	--// 没有之前的选项卡
	if not ActiveData then 
		return false 
	end

	--// 选项卡选择器
	local InfoSelector = self.InfoSelector

	--// 之前的元素
	local PreviousTab = ActiveData.Tab -- 之前的选项卡
	local PreviousSelectable = ActiveData.Selectable -- 之前的选择项

	--// 移除之前的选项卡并取消选择项焦点
	local TabFocused = self:ShouldFocus(PreviousTab) -- 检查之前的选项卡是否聚焦
	InfoSelector:RemoveTab(PreviousTab) -- 移除选项卡
	PreviousSelectable:SetSelected(false) -- 取消选择

	--// 返回之前的选项卡是否聚焦（用于新选项卡）
	return TabFocused
end

function Ui:MakeTableHeaders(Table, Rows: table) -- 创建表头
	local HeaderRow = Table:HeaderRow() -- 创建表头行
	for _, Catagory in next, Rows do -- 遍历行
		local Column = HeaderRow:NextColumn() -- 下一列
		Column:Label({Text=Catagory}) -- 创建标签（列名）
	end
end

function Ui:Decompile(Editor: table, Script: Script) -- 反编译脚本
	local Header = "--兄弟这也太硬核了，FLIPPY SKIBIDI AURA (SIGMA SPY)" -- 反编译标题
	Editor:SetText("--反编译中... +9999999 AURA (芒果 Phonk)") -- 设置编辑器文本（反编译中）

	--// 反编译脚本
	local Decompiled, IsError = Process:Decompile(Script) -- 反编译

	--// 为成功的反编译添加标题
	if not IsError then
		Decompiled = `{Header}\n{Decompiled}` -- 拼接标题和反编译结果
	end

	Editor:SetText(Decompiled) -- 设置编辑器文本（反编译结果）
end

type DisplayTableConfig = { -- 显示表格配置类型
	Rows: table, -- 行名列表
	Flags: table?, -- 标志（配置）
	ToDisplay: table, -- 要显示的数据表
	Table: table -- 数据表
}
function Ui:DisplayTable(Parent, Config: DisplayTableConfig): table -- 显示表格
	--// 配置
	local Rows = Config.Rows -- 行名
	local Flags = Config.Flags -- 标志（配置）
	local DataTable = Config.Table -- 数据表
	local ToDisplay = Config.ToDisplay -- 要显示的数据

	Flags.MaxColumns = #Rows -- 最大列数（等于行名数量）

	--// 创建表格
	local Table = Parent:Table(Flags) -- 创建表格

	--// 表头
	self:MakeTableHeaders(Table, Rows) -- 创建表头

	--// 表格布局
	for RowIndex, Name in next, ToDisplay do -- 遍历要显示的数据
		local Row = Table:Row() -- 创建行
		
		--// 创建列
		for Count, Catagory in next, Rows do -- 遍历行名
			local Column = Row:NextColumn() -- 下一列
			
			--// 值文本
			local Value = Catagory == "Name" and Name or DataTable[Name] -- 如果是"Name"列则用Name，否则用数据表中的值
			if not Value then continue end -- 无值则跳过

			--// 创建过滤后的标签
			local String = self:FilterName(`{Value}`, 150) -- 过滤名称（限制长度）
			Column:Label({Text=String}) -- 创建标签（显示值）
		end
	end

	return Table -- 返回表格
end

function Ui:SetFocusedRemote(Data) -- 设置聚焦的远程对象
	--// 解包远程数据
	local Remote = Data.Remote -- 远程对象
	local Method = Data.Method -- 方法名
	local IsReceive = Data.IsReceive -- 是否为接收端
	local Script = Data.CallingScript -- 调用脚本
	local ClassData = Data.ClassData -- 类数据
	local HeaderData = Data.HeaderData -- 头部数据
	local ValueSwaps = Data.ValueSwaps -- 值替换表
	local Args = Data.Args -- 参数
	local Id = Data.Id -- ID

	--// 标志
	local TableArgs = Flags:GetFlagValue("TableArgs") -- 是否以表格形式显示参数
	local NoVariables = Flags:GetFlagValue("NoVariables") -- 是否不使用变量名

	--// 解包信息
	local RemoteData = Process:GetRemoteData(Id) -- 获取远程数据
	local IsRemoteFunction = ClassData.IsRemoteFunction -- 是否为RemoteFunction
	local RemoteName = self:FilterName(`{Remote}`, 50) -- 过滤远程对象名（限制长度）

	--// UI数据
	local CodeEditor = self.CodeEditor -- 代码编辑器
	local ToDisplay = self.DisplayRemoteInfo -- 要显示的远程信息项
	local InfoSelector = self.InfoSelector -- 选项卡选择器

	local TabFocused = self:RemovePreviousTab() -- 移除之前的选项卡并获取其是否聚焦
	local Tab = InfoSelector:CreateTab({ -- 创建新选项卡
		Name = self:FilterName(`远程: {RemoteName}`, 50), -- 选项卡名称（过滤后）
		Focused = TabFocused -- 是否聚焦
	})

	--// 创建新的解析器
	local Module = Generation:NewParser({ -- 创建新解析器模块
		NoVariables = NoVariables -- 是否不使用变量名
	})
	local Parser = Module.Parser -- 解析器
	local Formatter = Module.Formatter -- 格式化器
	Formatter:SetValueSwaps(ValueSwaps) -- 设置值替换表

	--// 设置此日志为选中状态
	ActiveData = Data -- 设置为当前数据
	Data.Tab = Tab -- 存储选项卡引用
	Data.Selectable:SetSelected(true) -- 设置选择项为选中状态

	local function SetIDEText(Content: string, Task: string?) -- 设置IDE文本
		Data.Task = Task or "Sigma Spy" -- 设置任务名（默认为"Sigma Spy"）
		CodeEditor:SetText(Content) -- 设置编辑器文本
	end
	local function DataConnection(Name, ...) -- 数据连接函数
		local Args = {...} -- 参数列表
		return function()
			return Data[Name](Data, Process:Unpack(Args)) -- 调用数据的方法并解包参数
		end
	end
	local function ScriptCheck(Script, NoMissingCheck: boolean): boolean? -- 脚本检查函数
		--// 拒绝客户端事件（接收端没有脚本）
		if IsReceive then 
			Ui:ShowModal({ -- 显示模态窗口
				"接收端没有脚本，因为它是一个连接(Connection)"
			})
			return 
		end

		--// 检查脚本是否存在
		if not Script and not NoMissingCheck then 
			Ui:ShowModal({"脚本已被游戏销毁 (-9999999 AURA)"}) -- 显示模态窗口
			return
		end

		return true -- 检查通过
	end

	--// 函数（附加到Data）
	function Data:ScriptOptions(Button: GuiButton) -- 脚本选项
		Ui:MakeButtonMenu(Button, {self}, { -- 创建按钮菜单
			["调用者信息"] = DataConnection("GenerateInfo"), -- 生成调用者信息
			["反编译"] = DataConnection("Decompile", "SourceScript"), -- 反编译源脚本
			["反编译调用者"] = DataConnection("Decompile", "CallingScript"), -- 反编译调用脚本
			["重复调用"] = DataConnection("RepeatCall"), -- 重复调用
			["保存字节码"] = DataConnection("SaveBytecode"), -- 保存字节码
		})
	end
	function Data:BuildScript(Button: GuiButton) -- 构建脚本
		Ui:MakeButtonMenu(Button, {self}, { -- 创建按钮菜单
			["保存"] = DataConnection("SaveScript"), -- 保存脚本
			["调用远程"] = DataConnection("MakeScript", "Remote"), -- 生成调用远程脚本
			["阻止远程"] = DataConnection("MakeScript", "Block"), -- 生成阻止远程脚本
			["重复调用"] = DataConnection("MakeScript", "Repeat"), -- 生成重复调用脚本
			["刷屏远程"] = DataConnection("MakeScript", "Spam") -- 生成刷屏远程脚本
		})
	end
	function Data:SaveScript() -- 保存脚本
		local FilePath = Generation:TimeStampFile(self.Task) -- 生成带时间戳的文件名
		writefile(FilePath, CodeEditor:GetText()) -- 写入文件

		Ui:ShowModal({"脚本已保存至", FilePath}) -- 显示模态窗口
	end
	function Data:SaveBytecode() -- 保存字节码
		--// 问题检查
		if not ScriptCheck(Script, true) then return end -- 脚本检查（允许缺失）

		--// 获取脚本字节码
    	local Success, Bytecode = pcall(getscriptbytecode, Script) -- 安全调用
		if not Success then
			Ui:ShowModal({"获取脚本字节码失败 (-9999999 AURA)"}) -- 显示模态窗口
			return
		end

		--// 保存文件
		local PathBase = `{Script} %s.txt` -- 路径模板
		local FilePath = Generation:TimeStampFile(PathBase) -- 生成带时间戳的文件名
		writefile(FilePath, Bytecode) -- 写入文件

		Ui:ShowModal({"字节码已保存至", FilePath}) -- 显示模态窗口
	end
	function Data:MakeScript(ScriptType: string) -- 生成脚本
		local Script = Generation:RemoteScript(Module, self, ScriptType) -- 生成远程脚本
		SetIDEText(Script, `正在编辑: {RemoteName}.lua`) -- 设置IDE文本
	end
	function Data:RepeatCall() -- 重复调用
		local Signal = Hook:Index(Remote, Method) -- 获取信号

		if IsReceive then -- 如果是接收端
			firesignal(Signal, Process:Unpack(Args)) -- 触发信号（解包参数）
		else -- 如果是发送端
			Signal(Remote, Process:Unpack(Args)) -- 调用信号（解包参数）
		end
	end
	function Data:GetReturn() -- 获取返回值
		local ReturnValues = self.ReturnValues -- 返回值

		--// 错误消息
		if not IsRemoteFunction then -- 不是RemoteFunction
			Ui:ShowModal({"该远程对象不是 RemoteFunction (-9999999 AURA)"}) -- 显示模态窗口
			return
		end
		if not ReturnValues then -- 无返回值
			Ui:ShowModal({"无返回值 (-9999999 AURA)"}) -- 显示模态窗口
			return
		end

		--// 生成脚本
		local Script = Generation:TableScript(Module, ReturnValues) -- 生成表脚本
		SetIDEText(Script, `{RemoteName} 的返回值`) -- 设置IDE文本
	end
	function Data:GenerateInfo() -- 生成调用者信息
		--// 问题检查
		if not ScriptCheck(nil, true) then return end -- 脚本检查（允许缺失）

		--// 生成脚本
		local Script = Generation:AdvancedInfo(Module, self) -- 生成高级信息脚本
		SetIDEText(Script, `{RemoteName} 的高级信息`) -- 设置IDE文本
	end
	function Data:Decompile(WhichScript: string) -- 反编译
		local DecompilePopout = Flags:GetFlagValue("DecompilePopout") -- 是否弹出反编译窗口
		local ToDecompile = Data[WhichScript] -- 要反编译的脚本
		local Editor = CodeEditor -- 编辑器（默认为主编辑器）

		--// 问题检查
		if not ScriptCheck(ToDecompile, true) then return end -- 脚本检查（允许缺失）
		local Task = Ui:FilterName(`正在查看: {ToDecompile}.lua`, 200) -- 任务名（过滤后）
		
		--// 如果启用了自动弹出，则使用弹出窗口进行反编译
		if DecompilePopout then
			Editor = Ui:MakeEditorPopoutWindow("", { -- 创建弹出式编辑器窗口
				Title = Task -- 窗口标题
			})
		end

		Ui:Decompile(Editor, ToDecompile) -- 反编译
	end
	
	--// 远程选项
	self:CreateOptionsForDict(Tab, RemoteData, function() -- 为远程数据创建选项
		Process:UpdateRemoteData(Id, RemoteData) -- 更新远程数据
	end)

	--// 实例选项
	self:CreateButtons(Tab, { -- 创建按钮组
		Base = { -- 基础配置
			Size = UDim2.new(1, 0, 0, 20), -- 尺寸（宽度100%，高度20）
			AutomaticSize = Enum.AutomaticSize.Y, -- 高度自动
		},
		Buttons = { -- 按钮列表
			{
				Text = "复制脚本路径", -- 复制脚本路径按钮
				Callback = function()
					SetClipboard(Parser:MakePathString({ -- 复制路径字符串到剪贴板
						Object = Script, -- 对象（脚本）
						NoVariables = true -- 不使用变量名
					}))
				end,
			},
			{
				Text = "复制远程路径", -- 复制远程路径按钮
				Callback = function()
					SetClipboard(Parser:MakePathString({ -- 复制路径字符串到剪贴板
						Object = Remote, -- 对象（远程对象）
						NoVariables = true -- 不使用变量名
					}))
				end,
			},
			{
				Text = "移除日志", -- 移除日志按钮
				Callback = function()
					InfoSelector:RemoveTab(Tab) -- 移除选项卡
					Data.Selectable:Remove() -- 移除选择项
					HeaderData:Remove() -- 移除头部数据
					ActiveData = nil -- 清空当前数据
				end,
			},
			{
				Text = "转储日志", -- 转储日志按钮
				Callback = function()
					local Logs = HeaderData.Entries -- 日志条目
					local FilePath = Generation:DumpLogs(Logs) -- 转储日志到文件
					self:ShowModal({"转储已保存至", FilePath}) -- 显示模态窗口
				end,
			},
			{
				Text = "查看连接", -- 查看连接按钮
				Callback = function()
					local Method = ClassData.Receive[1] -- 接收方法名
					local Signal = Remote[Method] -- 信号
					self:ViewConnections(RemoteName, Signal) -- 查看连接
				end,
			}
		}
	})

	--// 远程信息表格
	self:DisplayTable(Tab, { -- 显示表格
		Rows = {"名称", "值"}, -- 行名
		Table = Data, -- 数据表
		ToDisplay = ToDisplay, -- 要显示的数据
		Flags = { -- 标志（配置）
			Border = true, -- 边框
			RowBackground = true, -- 行背景
			MaxColumns = 2 -- 最大列数
		}
	})
	
	--// 参数表格脚本
	if TableArgs then -- 如果启用以表格形式显示参数
		local Parsed = Generation:TableScript(Module, Args) -- 生成参数表脚本
		SetIDEText(Parsed, `{RemoteName} 的参数`) -- 设置IDE文本
		return
	end

	--// 远程调用脚本（默认）
	Data:MakeScript("Remote") -- 生成远程调用脚本
end

function Ui:ViewConnections(RemoteName: string, Signal: RBXScriptConnection) -- 查看连接
	local Window = self:CreateWindow({ -- 创建窗口
		Title = `{RemoteName} 的连接`, -- 窗口标题
		Size = UDim2.fromOffset(450, 250) -- 窗口尺寸
	})

	local ToDisplay = { -- 要显示的属性
		"Enabled", -- 是否启用
		"LuaConnection", -- Lua连接
		"Script" -- 脚本
	}

	--// 获取过滤后的连接
	local Connections = Process:FilterConnections(Signal, ToDisplay) -- 过滤连接

	--// 表格
	local Table = Window:Table({ -- 创建表格
		Border = true, -- 边框
		RowBackground = true, -- 行背景
		MaxColumns = 3 -- 最大列数
	})

	local ButtonsForValues = { -- 值对应的按钮函数
		["Script"] = function(Row, Value) -- 脚本列
			Row:Button({ -- 创建按钮
				Text = "反编译", -- 按钮文本
				Callback = function()
					local Task = self:FilterName(`正在查看: {Value}.lua`, 200) -- 任务名（过滤后）
					local Editor = self:MakeEditorPopoutWindow(nil, { -- 创建弹出式编辑器窗口
						Title = Task -- 窗口标题
					})
					self:Decompile(Editor, Value) -- 反编译脚本
				end
			})
		end,
		["Enabled"] = function(Row, Enabled, Connection) -- 启用状态列
			Row:Button({ -- 创建按钮
				Text = Enabled and "禁用" or "启用", -- 按钮文本（根据状态）
				Callback = function(self)
					Enabled = not Enabled -- 切换状态
					self.Text = Enabled and "禁用" or "启用" -- 更新按钮文本

					--// 启用或禁用连接
					if Enabled then
						Connection:Enable() -- 启用连接
					else
						Connection:Disable() -- 禁用连接
					end
				end
			})
		end
	}

	--// 创建表头
	self:MakeTableHeaders(Table, ToDisplay) -- 创建表头

	for _, Connection in next, Connections do -- 遍历连接
		local Row = Table:Row() -- 创建行

		for _, Property in next, ToDisplay do -- 遍历属性
			local Column = Row:NextColumn() -- 下一列
			local ColumnRow = Column:Row() -- 列内行

			local Value = Connection[Property] -- 属性值
			local Callback = ButtonsForValues[Property] -- 对应的按钮函数

			--// 值标签
			ColumnRow:Label({Text=`{Value}`}) -- 创建标签（显示值）

			--// 添加按钮（如果存在）
			if Callback then
				Callback(ColumnRow, Value, Connection) -- 调用按钮函数
			end
		end
	end

	--// 窗口居中
	Window:Center() -- 居中窗口
end

function Ui:GetRemoteHeader(Data: Log) -- 获取远程头部数据
	local LogLimit = self.LogLimit -- 日志限制
	local Logs = self.Logs -- 日志存储
	local RemotesList = self.RemotesList -- 远程对象列表

	--// 远程信息
	local Id = Data.Id -- ID
	local Remote = Data.Remote -- 远程对象
	local RemoteName = self:FilterName(`{Remote}`, 30) -- 过滤远程对象名（限制长度）

	--// 是否禁用树节点
	local NoTreeNodes = Flags:GetFlagValue("NoTreeNodes") -- 获取标志值

	--// 检查是否存在树节点
	local Existing = Logs[Id] -- 检查是否存在
	if Existing then return Existing end -- 存在则返回

	--// 头部数据
	local HeaderData = {	-- 头部数据结构
		LogCount = 0, -- 日志计数
		Data = Data, -- 日志数据
		Entries = {} -- 日志条目列表
	}

	--// 增加树节点计数
	RemotesCount += 1

	--// 创建新的树节点元素
	if not NoTreeNodes then
		HeaderData.TreeNode = RemotesList:TreeNode({ -- 创建树节点
			LayoutOrder = -1 * RemotesCount, -- 布局顺序（负值确保新日志在顶部）
			Title = RemoteName -- 标题（远程对象名）
		})
	end

	function HeaderData:CheckLimit() -- 检查日志限制
		local Entries = self.Entries -- 日志条目
		if #Entries < LogLimit then return end -- 未超限则返回
			
		--// 获取并移除最后一个元素
		local Log = table.remove(Entries, 1) -- 移除第一个条目
		Log.Selectable:Remove() -- 移除其选择项
	end

	function HeaderData:LogAdded(Data) -- 日志添加
		--// 增加日志计数
		self.LogCount += 1
		self:CheckLimit() -- 检查限制

		--// 添加条目
		local Entries = self.Entries -- 日志条目列表
		table.insert(Entries, Data) -- 添加新条目
		
		return self -- 返回自身
	end

	function HeaderData:Remove() -- 移除
		--// 移除树节点
		local TreeNode = self.TreeNode
		if TreeNode then
			TreeNode:Remove() -- 移除UI元素
		end

		--// 从内存中清除表
		Logs[Id] = nil -- 从日志存储中移除
		table.clear(HeaderData) -- 清空头部数据表
	end

	Logs[Id] = HeaderData -- 存储到日志存储
	return HeaderData -- 返回头部数据
end

function Ui:ClearLogs() -- 清除日志
	local Logs = self.Logs -- 日志存储
	local RemotesList = self.RemotesList -- 远程对象列表

	--// 清除所有元素
	RemotesCount = 0 -- 重置计数
	RemotesList:ClearChildElements() -- 清除子元素

	--// 从内存中清除日志
	table.clear(Logs) -- 清空日志存储
end

function Ui:QueueLog(Data) -- 将日志加入队列
	local LogQueue = self.LogQueue -- 日志队列
	Process:Merge(Data, { -- 合并数据（深度克隆参数）
		Args = Process:DeepCloneTable(Data.Args), -- 深度克隆参数
	})

	if Data.ReturnValues then -- 如果有返回值
        Data.ReturnValues = Process:DeepCloneTable(Data.ReturnValues) -- 深度克隆返回值
    end
	
    table.insert(LogQueue, Data) -- 加入队列
end

function Ui:ProcessLogQueue() -- 处理日志队列
	local Queue = self.LogQueue -- 日志队列
    if #Queue <= 0 then return end -- 队列为空则返回

	--// 为队列中的每个日志创建UI元素
    for Index, Data in next, Queue do -- 遍历队列
        self:CreateLog(Data) -- 创建日志UI元素
        table.remove(Queue, Index) -- 从队列中移除
    end
end

function Ui:BeginLogService() -- 启动日志服务
	coroutine.wrap(function() -- 创建协程
		while true do
			self:ProcessLogQueue() -- 持续处理日志队列
			task.wait()
		end
	end)()
end

function Ui:FilterName(Name: string, CharacterLimit: number?): string -- 过滤名称
	local Trimmed = Name:sub(1, CharacterLimit or 20) -- 截断（默认限制20字符）
	local Filtred = Trimmed:gsub("[\n\r]", "") -- 移除换行符
	Filtred = Generation:MakePrintable(Filtred) -- 确保可打印

	return Filtred -- 返回过滤后的名称
end

function Ui:CreateLog(Data: Log) -- 创建日志UI元素
	--// 解包日志数据
    local Remote = Data.Remote -- 远程对象
	local Method = Data.Method -- 方法名
    local Args = Data.Args -- 参数
    local IsReceive = Data.IsReceive -- 是否为接收端
	local Id = Data.Id -- ID
	local Timestamp = Data.Timestamp -- 时间戳
	local IsExploit = Data.IsExploit -- 是否由漏洞利用工具调用
	
	local IsNilParent = Hook:Index(Remote, "Parent") == nil -- 父级是否为nil
	local RemoteData = Process:GetRemoteData(Id) -- 获取远程数据

	--// 是否暂停
	local Paused = Flags:GetFlagValue("Paused") -- 获取标志值
	if Paused then return end -- 暂停则返回

	--// 检查调用者（忽略漏洞利用工具的调用）
	local LogExploit = Flags:GetFlagValue("LogExploit") -- 获取标志值
	if not LogExploit and IsExploit then return end -- 不记录漏洞调用且是漏洞调用则返回

	--// 忽略父级为nil的远程对象
	local IgnoreNil = Flags:GetFlagValue("IgnoreNil") -- 获取标志值
	if IgnoreNil and IsNilParent then return end -- 忽略且父级为nil则返回

    --// 是否记录接收端日志
	local LogRecives = Flags:GetFlagValue("LogRecives") -- 获取标志值
	if not LogRecives and IsReceive then return end -- 不记录接收端且是接收端则返回

	local SelectNewest = Flags:GetFlagValue("SelectNewest") -- 是否自动选择最新日志
	local NoTreeNodes = Flags:GetFlagValue("NoTreeNodes") -- 是否禁用树节点

    --// 排除检查
    if RemoteData.Excluded then return end -- 被排除则返回

	--// 反序列化参数
	Args = Communication:DeserializeTable(Args) -- 反序列化参数表

	--// 深度克隆数据
	local ClonedArgs = Process:DeepCloneTable(Args) -- 深度克隆参数
	Data.Args = ClonedArgs -- 更新数据中的参数
	Data.ValueSwaps = Generation:MakeValueSwapsTable(Timestamp) -- 创建值替换表（基于时间戳）

	--// 生成日志标题
	local Color = Config.MethodColors[Method:lower()] -- 方法对应的颜色
	local Text = NoTreeNodes and `{Remote} | {Method}` or Method -- 标题文本（禁用树节点时包含远程名）

	--// 检查是否使用字符串作为名称
	local FindString = Flags:GetFlagValue("FindStringForName") -- 获取标志值
	if FindString then
		for _, Arg in next, ClonedArgs do -- 遍历参数
			if typeof(Arg) == "string" then -- 如果是字符串
				local Filtred = self:FilterName(Arg) -- 过滤参数
				Text = `{Filtred} | {Text}` -- 更新标题文本
				break -- 找到第一个字符串即跳出
			end
		end
	end

	--// 通过RemoteID获取HeaderData（用于日志堆叠）
	local Header = self:GetRemoteHeader(Data) -- 获取或创建头部数据
	local RemotesList = self.RemotesList -- 远程对象列表

	local LogCount = Header.LogCount -- 当前日志计数
	local TreeNode = Header.TreeNode  -- 树节点
	local Parent = TreeNode or RemotesList -- 父级（树节点或列表）

	--// 增加日志计数 - 树节点在GetRemoteHeader函数中已增加
	if NoTreeNodes then -- 禁用树节点
		RemotesCount += 1 -- 增加远程计数
		LogCount = RemotesCount -- 日志计数等于远程计数
	end

    --// 创建焦点按钮
	Data.HeaderData = Header -- 存储头部数据引用
	Data.Selectable = Parent:Selectable({ -- 创建可选择项
		Text = Text, -- 文本
        LayoutOrder = -1 * LogCount, -- 布局顺序（负值确保新日志在顶部）
		TextColor3 = Color, -- 文本颜色
		TextXAlignment = Enum.TextXAlignment.Left, -- 文本左对齐
		Callback = function() -- 回调函数
			self:SetFocusedRemote(Data) -- 设置此日志为焦点
		end,
    })

	Header:LogAdded(Data) -- 将日志添加到头部数据

	--// 自动选择检查
	local GroupSelected = ActiveData and ActiveData.HeaderData == Header -- 当前选中的数据是否属于同一组
	if SelectNewest and GroupSelected then -- 自动选择最新且属于同一组
		self:SetFocusedRemote(Data) -- 设置此日志为焦点
	end
end

return Ui -- 返回Ui模块