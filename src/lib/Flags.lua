type FlagValue = boolean|number|any
type Flag = {
    Value: FlagValue,
    Label: string,
    Category: string
}
type Flags = {
    [string]: Flag
}
type table = {
    [any]: any
}

local Module = {
    Flags = {
        -- PreventRenaming = {
        --     Value = false,
        --     Label = "禁止重命名",
        -- },
        -- PreventParenting = {
        --     Value = false,
        --     Label = "禁止设置父级",
        -- },
        NoComments = {
            Value = false,
            Label = "无注释",
        },
        SelectNewest = {
            Value = false,
            Label = "自动选择最新",
        },
        DecompilePopout = { -- Lovre SHUSH
            Value = false,
            Label = "反编译弹出窗口",
        },
        IgnoreNil = {
            Value = true,
            Label = "忽略空父级",
        },
        LogExploit = {
            Value = true,
            Label = "记录 Exploit 调用",
        },
        LogRecives = {
            Value = true,
            Label = "记录接收",
        },
        Paused = {
            Value = false,
            Label = "暂停",
            Keybind = Enum.KeyCode.Q
        },
        KeybindsEnabled = {
            Value = true,
            Label = "启用快捷键"
        },
        FindStringForName = {
            Value = true,
            Label = "查找参数对应名称"
        },
        UiVisible = {
            Value = true,
            Label = "界面可见",
            Keybind = Enum.KeyCode.P
        },
        NoTreeNodes = {
            Value = false,
            Label = "无分组"
        },
        TableArgs = {
            Value = false,
            Label = "表参数"
        },
        NoVariables = {
            Value = false,
            Label = "无变量压缩"
        }
    }
}

function Module:GetFlagValue(Name: string): FlagValue
    local Flag = self:GetFlag(Name)
    return Flag.Value
end

function Module:SetFlagValue(Name: string, Value: FlagValue)
    local Flag = self:GetFlag(Name)
    Flag.Value = Value
end

function Module:SetFlagCallback(Name: string, Callback: (...any) -> ...any)
    local Flag = self:GetFlag(Name)
    Flag.Callback = Callback
end

function Module:SetFlagCallbacks(Dict: {})
    for Name, Callback: (...any) -> ...any in next, Dict do 
        self:SetFlagCallback(Name, Callback)
    end
end

function Module:GetFlag(Name: string): Flag
    local AllFlags = self:GetFlags()
    local Flag = AllFlags[Name]
    assert(Flag, "标志不存在！")
    return Flag
end

function Module:AddFlag(Name: string, Flag: Flag)
    local AllFlags = self:GetFlags()
    AllFlags[Name] = Flag
end

function Module:GetFlags(): Flags
    return self.Flags
end

return Module
