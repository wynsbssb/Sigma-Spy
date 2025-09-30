
---

# Sigma-Spy

一个完整的远程监听工具，配备了强大的解析器，可捕获进出远程事件的数据，并支持 Actor 功能！

## 社交 💬

* [Sigma Spy 演示 (YouTube)](https://www.youtube.com/watch?v=Q4VrpE1UfHg)
* [Discord](https://discord.gg/s9ngmUDWgb)

## Loadstring

```lua
--// Sigma Spy @depso
loadstring(game:HttpGet("https://raw.githubusercontent.com/wynsbssb/Sigma-Spy/refs/heads/main/Main.lua"))()
```

## 注意事项 🔔

* Sigma Spy 可能存在 bug，请通过在 Github 上 [提交 issue](https://github.com/depthso/Sigma-Spy/issues) 来报告任何问题。
* 如果你有建议，请在 [discussions](https://github.com/depthso/Sigma-Spy/discussions) 中提出。
* 如果你的执行器的 comm 库（`get_comm_channel`、`create_comm_channel`）出现问题，请在 Sigma Spy/Config.lua 中启用 `ForceUseCustomComm`。该文件位于运行后执行器的工作目录中。
* 截至 2025/11/06，推荐使用 AWP 和 Zenith 执行器。

## 功能 ⚡

以下是 Sigma Spy 的部分功能：

| 功能                               | 描述                                 |
| -------------------------------- | ---------------------------------- |
| **Actors** 支持                    | 可通过 **快捷键** 切换选项                   |
| 支持 **__index** 和 **__namecall**  | 可将日志 **导出到文件**                     |
| 支持大脚本 **反编译**                    | 日志标题显示参数值                          |
| 阻止远程事件触发                         | 支持多种数据类型                           |
| **伪造** 返回值 *(Return spoofs.lua)* | 可记录客户端接收事件 *(如 **OnClientEvent**)* |
| 解析器支持变量压缩                        | 支持远程事件堆叠（称为“分组”） *(可选)*            |
| 支持移动设备                           | 弹出编辑器窗口                            |

## 截图 🖼️

<table>
	<tr>
		<td>
			<img src="/docs/images/Basic.png">
		</td>
		<td>
			<img src="/docs/images/DecompileConnection.png">
            弹出反编译窗口与连接查看器
		</td>
	</tr>
    <tr>
        <td>
            <img src="/docs/images/PopoutWindows.png">
            多个弹出编辑器
        </td>
        <td>
            <img src="https://github.com/user-attachments/assets/87d6b97f-320a-4bff-ab16-4bab1b397d07">
            执行器函数补丁
        </td>
    </tr>
</table>

## Config.lua 配置选项 ⚙️

<table>
  <tr>
    <th>名称</th>
    <th>描述</th>
  </tr>
  <tr>
    <td><b>ForceUseCustomComm</b></td>
    <td>强制 Sigma Spy 使用内置 comm 库。如果你的执行器不支持，将自动启用</td>
  </tr>
  <tr>
    <td><b>ForceKonstantDecompiler</b></td>
    <td>强制反编译选项使用 Konstant 库。如果执行器不支持 `decompile`，将自动启用</td>
  </tr>
  <tr>
    <td><b>NoFunctionPatching</b></td>
    <td>禁用对执行器可能存在漏洞的函数补丁</td>
  </tr>
  <tr>
    <td><b>ReplaceMetaCallFunc</b></td>
    <td>使用 `getrawmetatable` 替换 meta 调用函数，而非使用 hookmetamethod</td>
  </tr>
  <tr>
    <td><b>NoReceiveHooking</b></td>
    <td>禁用对回调函数（如 `.OnClientInvoke`）的挂钩</td>
  </tr>
  <tr>
    <td><b>VariableNames</b></td>
    <td>解析器使用的变量名称，如果自动生成的名称不可用，可在此设置</td>
  </tr>
</table>

## 必需函数 ⚠️

如果执行器不支持以下函数，Sigma Spy 将提示：

| 必需              | 可选                                                        |
| --------------- | --------------------------------------------------------- |
| hookmetamethod  | getcustomasset *(用于 True ImGui 主题，可选)*                    |
| hookfunction    | Comm library (`get_comm_channel`, `create_comm_channel`) *(可选)* |
| getrawmetatable |                                                           |
| setreadonly     |                                                           |
| File library    |                                                           |
| getconnections  |                                                           |
| newcclosure     |                                                           |

## 使用的库

* [ReGui (Depso)](https://github.com/depthso/Dear-ReGui/tree/main)
* [Roblox-Parser (Depso)](https://github.com/depthso/Roblox-parser)

---
