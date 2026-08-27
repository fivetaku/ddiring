[English](README.md) | [한국어](README.ko.md) | 中文 | [日本語](README.ja.md) | [Español](README.es.md)

# ddiring

<p align="center">
  <img src="assets/ddiring-hero-01.png" alt="ddiring" width="320">
</p>

> 不只是"任务完成"——告诉你**是哪个会话**完成了的通知。

在 iTerm、Cursor 和会话管理器里同时跑着 5–10 个 Claude Code 会话时,一条干巴巴的"任务完成"横幅毫无用处——你还是得一个个窗口去找。ddiring("띠링"——韩语里的"叮!")让每条通知一眼回答三个问题: **哪个项目文件夹**(标题)、会话在**哪个终端/应用**里(副标题)、**你让它干了什么**(正文——最后一条提示词的 70 字摘要)。在 macOS 上安装 `terminal-notifier` 后,点击通知可直接跳转到那个应用。

[快速开始](#快速开始) • [为什么选-ddiring](#为什么选-ddiring) • [工作原理](#工作原理) • [主要功能](#主要功能) • [命令](#命令) • [环境要求](#环境要求)

---

## 快速开始

### 1. 添加插件市场

```
/plugin marketplace add https://github.com/fivetaku/gptaku_plugins.git
```

### 2. 安装

```
/plugin install ddiring
```

### 3. 重启 Claude Code

(钩子和命令在重启后才会注册。)

### 4. 使用

无需任何操作——现在每个会话完成时都会"叮"一声:

- **✅ my-app** / *iTerm* / "修复不稳定的认证测试并重跑 CI" —— iTerm 里的那个任务完成了
- **⏸️ blog** / *Cursor* / "等待权限" —— 有个会话在等你
- 点击通知(macOS + `terminal-notifier`)即可聚焦到那个应用

如需点击聚焦(可选):

```bash
brew install terminal-notifier
```

## 为什么选 ddiring

多会话工作有个反复出现的小痛点: *有什么*完成了,但默认通知不会告诉你是什么、在哪里。会话 ID 也没用——你不可能把 `a3f9c2` 对应到"我在 Warp 里跑的那个重构"。ddiring 展示的是人真正认得出的三样东西: 文件夹名、应用名,以及你自己敲的最后一条提示词。

## 工作原理

会话结束响应时触发 `Stop` 钩子(权限/输入等待则由 `Notification` 钩子以 ⏸️ 显示)。脚本会:

1. 读取 transcript 尾部(先 200KB,找不到则扩展到最多 2MB)提取你最后一条**真正的**提示词——跳过工具结果、系统标签和中断标记;
2. 通过进程环境识别宿主应用——macOS 用 `__CFBundleIdentifier`,Windows 用环境变量探测(`TERM_PROGRAM` → `WT_SESSION` → `ConEmuPID`,最内层优先以避免继承变量的误判);
3. 发出通知: macOS 用 `terminal-notifier`(可点击)或 `osascript`,Windows 用 PowerShell 5.1 WinRT toast。

由于钩子是通过文件执行脚本的,映射修改会**立即对已运行的会话生效**——无需重启。

## 主要功能

- **30+ 应用映射,经调研实测验证**(本地 `Info.plist`、Homebrew cask 定义、上游仓库配置): Terminal, iTerm2, VS Code (+Insiders), VSCodium, Cursor, Windsurf (Devin), Antigravity, Warp, Ghostty, Alacritty, kitty, WezTerm, Tabby, Hyper, Zed, JetBrains, Rio, Termius, Wave, Positron, Kiro, Trae, Xcode——以及 Claude Code 会话管理器: Paseo, cmux, Conductor, Orca, Sculptor, Superset, Crystal, Waku, Jean, Fletch, Constellagent, GraphCode, Clave, Xum。
- **tmux/Zellij 透传** —— 没有单独的检测逻辑,依赖继承的宿主环境变量显示(如果 tmux 服务器后来从别的应用 attach,可能显示最初的宿主)。
- **默认安静** —— 音量 0.2 的轻柔完成音,可通过环境变量静音/调整。
- **Windows 支持(实验性)** —— Git Bash 钩子路径下的 PowerShell toast。toast 本身无需额外安装,但提示词提取需要 Python 3(没有则显示通用文案)。仅显示,尚未在真机验证——欢迎反馈。
- **未知应用优雅降级** —— 回退显示 `TERM_PROGRAM` 或原始 bundle ID;加一行即可补映射。
- **验证「是否显示」而非「是否发送」的自检** —— 通知发送成功后仍可能被 macOS 拦下不显示（屏幕共享或镜像中、专注模式、未授予通知权限），结果只有声音没有横幅,看起来像插件坏了。`/ddiring 诊断` 会发一条测试通知并读取系统自身的判定,告诉你它是否真的显示过,没有的话原因是什么。首次使用时自动运行一次。

## 命令

| 命令 | 作用 |
|---|---|
| `/ddiring` | 显示当前状态(环境变量配置、是否安装 `terminal-notifier`、检测到的终端) |
| `/ddiring test` | 用本会话的 transcript 发一条测试通知 |
| `/ddiring 诊断` | 诊断通知已发送却不显示的原因（屏幕共享/镜像、专注模式、权限） |
| `/ddiring volume 0.1` / `mute` | 调整音量 / 静音 |

### 配置

写入 Claude 设置文件的 `"env"` 块,对新启动的会话生效:

| 变量 | 默认值 | 含义 |
|---|---|---|
| `DDIRING_SILENT` | `0` | `1` = 只显示横幅不出声 (macOS) |
| `DDIRING_VOLUME` | `0.2` | 0.0–1.0 (macOS) |
| `DDIRING_SOUND` | `Glass.aiff` | 任意 `/System/Library/Sounds/*.aiff` (macOS) |
| `DDIRING_HIDE_BODY` | `0` | `1` = 隐藏正文(锁屏/共享屏幕隐私) |

> 注意: 通知正文会保留在系统通知中心和锁屏上——如果你的提示词包含敏感内容,请设置 `DDIRING_HIDE_BODY=1`。首次运行 `/ddiring` 还会安装 gptaku 插件共用的更新提醒钩子。

## 环境要求

- macOS(完整支持)或 Windows + Git Bash(实验性);其他系统静默跳过
- `python3`(macOS 自带)—— 用于解析 transcript
- 可选: `terminal-notifier` 用于点击聚焦(macOS)

## 许可证

[MIT](./LICENSE) —— 另见 [DISCLAIMER.md](./DISCLAIMER.md)。
