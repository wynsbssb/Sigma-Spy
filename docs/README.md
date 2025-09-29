
---

# Sigma-Spy

一个完整的远程监控工具，配备强大的解析器，可捕获进出远程的数据，并支持 Actor 功能！

## 社交 💬

* [Sigma Spy 展示（YouTube）](https://www.youtube.com/watch?v=Q4VrpE1UfHg)
* [Discord](https://discord.gg/s9ngmUDWgb)

## 加载代码

```lua
--// Sigma Spy @depso
loadstring(game:HttpGet("https://raw.githubusercontent.com/wynsbssb/Sigma-Spy/refs/heads/main/Main.lua"))()
```

## 注意事项 🔔

* Sigma Spy 可能存在 bug，请通过在 Github 上[提交 issue](https://github.com/depthso/Sigma-Spy/issues)报告任何问题
* 如果有建议，请在[讨论区](https://github.com/depthso/Sigma-Spy/discussions)发布
* 如果你的执行器的通信库（get_comm_channel, create_comm_channel）出现问题，请在 Sigma Spy/Config.lua 中启用 `ForceUseCustomComm`，该文件位于你运行后的执行器工作区文件夹中
* 截至 2025/11/06，推荐使用 AWP 和 Zenith 执行器

## 功能 ⚡

Sigma Spy 拥有众多功能，包括但不限于：

| 功能                               | 描述                                 |
| -------------------------------- | ---------------------------------- |
| **Actors** 支持                    | 可通过 **快捷键** 切换选项                   |
| **__index** 和 __namecall 支持      | 可将日志 **导出到文件**                     |
| **反编译** 大型脚本                     | 日志标题支持参数值                          |
| 阻止远程触发                           | 支持多种数据类型                           |
| **伪造** 返回值 *(Return spoofs.lua)* | 可记录客户端接收事件 *(如 **OnClientEvent**)* |
| 解析器支持变量压缩                        | 可选择远程堆叠（“分组”）                      |
| 支持移动设备                           | 弹出式编辑器                             |

## 截图 🖼️

<table>
	<tr>
		<td>
			<img src="/docs/images/Basic.png">
		</td>
		<td>
			<img src="/docs/images/DecompileConnection.png">
			弹出式反编译与连接查看器
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
    <td>强制 Sigma Spy 使用内置通信库，如果执行器不支持通信库，将自动启用</td>
  </tr>
  <tr>
    <td><b>ForceKonstantDecompiler</b></td>
    <td>强制使用 Konstant 反编译脚本。如果执行器不支持 `decompile`，将自动启用</td>
  </tr>
  <tr>
    <td><b>NoFunctionPatching</b></td>
    <td>禁用对执行器中可能存在漏洞函数的补丁</td>
  </tr>
  <tr>
    <td><b>ReplaceMetaCallFunc</b></td>
    <td>使用 getrawmetatable 替换 meta 调用函数，而不是使用 hookmetamethod</td>
  </tr>
  <tr>
    <td><b>NoReceiveHooking</b></td>
    <td>禁用对回调函数（如 .OnClientInvoke）的挂钩</td>
  </tr>
  <tr>
    <td><b>VariableNames</b></td>
    <td>如果解析器生成的变量不可用，可使用自定义变量名</td>
  </tr>
</table>

## 必需函数 ⚠️

如果你的执行器不支持必需函数，Sigma Spy 会提示你。
执行器必须支持以下函数才能运行：

| 必需              | 可选                                                 |
| --------------- | -------------------------------------------------- |
| hookmetamethod  | getcustomasset *(True ImGui 主题可选)*                 |
| hookfunction    | 通信库 (get_comm_channel, create_comm_channel) *(可选)* |
| getrawmetatable |                                                    |
| setreadonly     |                                                    |
| 文件库             |                                                    |
| getconnections  |                                                    |
| newcclosure     |                                                    |

## 使用的库

* [ReGui (Depso)](https://github.com/depthso/Dear-ReGui/tree/main)
* [Roblox-Parser (Depso)](https://github.com/depthso/Roblox-parser)

---
