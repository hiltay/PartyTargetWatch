# PartyTargetWatch

An independent WoW Retail addon that displays group members and their selected targets, with customizable chat declaration monitoring and optional focus information. **The in-game interface is currently Simplified Chinese.**

## Features and use

- Solo, party and raid rosters up to 40 members, with two columns above 20 members.
- Target raid markers, a movable and lockable window, 60%–200% scaling, and sample preview.
- Background opacity from 0 to 1, default 0.88. Zero hides background, border and row fills while keeping text and icons visible.
- Visibility settings for the open world, resting areas, dungeons (including Mythic+), raids, scenarios, battlegrounds and arenas. Instance type takes priority; preview ignores scene filters.

Use `/ptw` to show the window, `/ptw settings` for settings, `/ptw formats` for declaration templates, `/ptw test` for preview, and `/ptw help` for commands. `/partytargetwatch` is an alias. Install the addon folder in the Retail client's `Interface/AddOns` folder.

Target selection does not prove who someone is attacking, healing or casting at; the addon does not select targets or perform combat actions automatically.

Version 0.3.1 removes outgoing target calls, their button, row-click action, commands, key binding and dedicated diagnostics. Protected target names may be displayed by the game UI while remaining unavailable for constructing chat messages, even outside combat. Monitoring already-sent public chat declarations remains available.

## Three optional focus controls

All three switches are **off by default**:

- **Show focus column:** controls only whether the column is visible.
- **Share focus:** sends your own publicly readable focus and accepts compatible snapshots from current group members. Both sides must install the addon and enable sharing. Snapshots expire after 12 seconds without an update.
- **Record chat interrupt declarations:** independently records explicit statements from current group members. The speaker does not need the addon.

Hiding the column or window does not turn off sharing or declaration recording. Disable their individual switches to stop them. Received focus data and declarations are not saved between sessions.

Only complete messages in party, raid and instance-group chat are considered. Open **通报格式…** in settings or use `/ptw formats` to edit incoming declaration templates. Templates recognize incoming messages; they do not generate or send calls. Defaults:

```text
我打断%mark
我的焦点打断是 {rt%mark}
```

Use one template per line, up to 20 nonempty templates, 255 bytes per template and 8192 bytes total input. Blank lines are ignored; surrounding spaces and tabs are trimmed. Each template requires exactly one `%mark` and permits up to two `%text` placeholders, each matching nonempty text. `%mark` accepts the eight Chinese marker names, digits 1–8 or `{rt1}`–`{rt8}`; `{rt%mark}` matches the canonical `{rtN}` form. All other content is literal, including punctuation and pipes. Unknown named placeholders are rejected.

Templates are tried in saved order, with a full-message match. If one template can identify different markers in the same message, the message is rejected. The sample tester uses the current draft without sending chat or recording an assignment. **Save** applies the draft, clears old declarations and persists the templates; closing without saving leaves the active configuration unchanged. An empty saved list stops new declarations. The fixed phrase `取消打断` still cancels the speaker's declaration while recording is enabled.

Declarations appear in yellow as **约定 (declared assignment)**, expire after 300 seconds, and clear on leaving the group, changing scenes or disabling recording. They do not establish anyone's real focus. A readable automatic focus takes priority. During local chat lockdown, automatic snapshots are hidden; existing public declarations may remain until expiry.

A marker-only declaration is displayed as that marker, not resolved to a monster name. Unit marker values may be protected and unavailable for matching. Showing a name for an already-known target does not provide a marker-to-name lookup.

## 0.3.1 Beta: limitations and testing

Targets Retail **12.1.0 / TOC 120100**. Version 0.3.1 passed 64 Lua mock scenarios (36 UI, 28 communication) and seven delivery tests; one symbolic-link test was skipped because Windows denied that privilege. This release has **not been loaded and validated in game**. Updating installed files and observations of earlier versions do not validate this release. Editor scrolling/input, opacity, cross-client delivery and saved settings still require live verification. CurseForge materials are prepared; this is not a claim of publication or approval.

Game restrictions can cover an entire active Mythic+ run, not just combat. Secret values are never serialized for transmission. Ordinary chat or external services cannot recover restricted real focus data; this addon uses no external bridge. A successful chat API call is not a delivery receipt. Complete compatibility or error-free operation is not established.

When upgrading manually from an older version, back up the old addon folder outside `AddOns`, then replace it with the complete new folder so the retired `Bindings.xml` is removed. Keep `WTF` SavedVariables to retain settings. [API sources and verification boundaries](https://github.com/hiltay/PartyTargetWatch/blob/main/docs/API-NOTES.md).

Report problems using the issue link below, with the addon/game version and reproduction steps. Remove personal information from logs or screenshots before sharing.

---

## 简体中文

PartyTargetWatch（队友目标）是《魔兽世界》正式服的独立插件，显示成员当前选中的目标，提供自定义聊天声明监控和可选焦点信息。**游戏内界面目前为简体中文。**

### 功能与使用

- 支持单人、小队和最多 40 人团队；超过 20 人使用双列。
- 显示目标团队标记，支持拖动、锁定、60%–200% 缩放和示例预览。
- 背景不透明度 `0`–`1`，默认 `0.88`；`0` 时背景、边框与行底色透明，文字和图标保持可见。
- 可按野外、主城/旅店休息区、地下城（含大秘境）、团本、场景战役、战场和竞技场选择显示；副本类型优先，预览忽略场景筛选。

`/ptw` 显示窗口，`/ptw settings` 打开设置，`/ptw formats` 编辑声明格式，`/ptw test` 切换预览，`/ptw help` 查看命令。`/partytargetwatch` 为等价命令。插件文件夹安装到正式服 `Interface/AddOns` 中。

选中目标不等于正在攻击、治疗或施法；插件不自动选目标或执行战斗操作。

0.3.1 已移除主动目标通报及其按钮、成员行点击、命令、快捷键和专用诊断。目标名称受保护时，即使游戏界面能显示它，也不能读取并拼接为聊天文字，脱战不保证解除限制。接收已经发送的公开聊天声明仍然保留。

### 三个焦点开关

三个开关**默认均关闭**：

- **显示队友焦点列**：只控制列是否显示。
- **启用焦点共享**：双方均需安装并启用，各自发送公开可读的自身焦点；12 秒未更新即过期。
- **记录聊天中的打断声明**：独立记录当前组员明确发出的约定，声明者无需安装插件。

隐藏窗口或列不会停止共享或声明记录，请取消相应开关。接收的焦点和声明不会跨会话保存。

只接受队伍、团队和副本队伍聊天中的完整消息。设置中点击“通报格式…”或输入 `/ptw formats` 编辑接收声明的识别规则，不会生成或发送通报。默认两条模板为 `我打断%mark` 和 `我的焦点打断是 {rt%mark}`。

每行一个模板，最多 20 条有效模板、每条 255 字节、总输入 8192 字节；忽略空白行并去除两端空格和制表符。每条必须恰含一个 `%mark`，最多两个匹配非空文字的 `%text`。`%mark` 接受八种中文标记名、`1`–`8` 或 `{rt1}`–`{rt8}`；`{rt%mark}` 匹配完整 `{rtN}`。其他内容包括标点、竖线均按字面处理，未知命名占位符会被拒绝。

按有效模板顺序匹配整句；同一模板若能匹配不同标记则拒绝消息。样本测试使用当前草稿，不发送聊天或生成声明。点击“保存”才生效并清空旧声明，保存的模板支持重载保留；关闭而未保存不改当前配置。保存空列表停止新记录，但启用记录时固定“取消打断”仍可清除本人声明。

声明显示为黄色**“约定”**，300 秒过期，离组、换场景或关闭记录时清除，不能证明队友真的设置了该焦点。可读的自动焦点优先；本地聊天锁定隐藏自动缓存，但已有公开声明可保留至过期。

只有标记的声明显示对应标记，不反查怪物名称。单位的标记值可能受保护，不能用于匹配；已知目标的名称能够显示，不代表可以从标记反查名称。

### 0.3.1 测试版的范围与限制

面向正式服 **12.1.0 / TOC 120100**。64 个 Lua mock 场景通过（36 UI、28 通信），交付测试 7 通过、1 因 Windows 符号链接权限跳过。**本版尚未在游戏中加载验收**；安装文件更新或历史版本观察不能替代本版验收。编辑器滚动/输入、不透明度、跨客户端送达与设置保存仍待实测。CurseForge 资料仅准备就绪，不代表已提交、发布或审核通过。

大秘境等限制可能覆盖整段活动，而不只是战斗。秘密值不进入通信；普通聊天和外部服务也不能恢复受限的真实焦点，本项目不提供外部桥接。发送 API 调用成功不代表已送达，不承诺所有场景完全兼容或完全无错误。

从旧版手动升级时，请把旧插件目录备份到 `AddOns` 之外，再用新版完整目录替换，确保废弃的 `Bindings.xml` 不再残留。保留 `WTF` 中的 SavedVariables 即可保留设置。[接口依据与验证边界](https://github.com/hiltay/PartyTargetWatch/blob/main/docs/API-NOTES.md)。

反馈请提供插件/游戏版本及复现步骤，分享日志或截图前移除私人信息。

[Source / 源代码](https://github.com/hiltay/PartyTargetWatch) · [Issues / 问题反馈](https://github.com/hiltay/PartyTargetWatch/issues) · [MIT License / 许可证](https://github.com/hiltay/PartyTargetWatch/blob/main/LICENSE)
