# PartyTargetWatch

An independent WoW Retail addon that displays group members and their selected targets, with manual target calls and optional focus information. **The in-game interface is currently Simplified Chinese.**

## Features and use

- Solo, party and raid rosters up to 40 members, with two columns above 20 members.
- Target raid markers, a movable and lockable window, 60%–200% scaling, and sample preview.
- Background opacity from 0 to 1, default 0.88. Zero hides background, border and row fills while keeping text and icons visible.
- Visibility settings for the open world, resting areas, dungeons (including Mythic+), raids, scenarios, battlegrounds and arenas. Instance type takes priority; preview ignores scene filters.
- A target-call button, clickable member rows, `/ptw announce`, and an optional key binding assigned by you in the game's key-binding settings. No keys are assigned automatically.

Use `/ptw` to show the window, `/ptw settings` for settings, `/ptw formats` for declaration templates, `/ptw test` for preview, and `/ptw help` for commands. `/partytargetwatch` is an alias. Install the addon folder in the Retail client's `Interface/AddOns` folder.

Manual calls use instance chat, raid chat, or party chat, in that order. They require a group, readable public data, and at least three seconds between calls. Preview cannot send calls. Target selection does not prove who someone is attacking, healing or casting at; the addon does not select targets or perform combat actions automatically.

Failed calls distinguish chat lockdown from protected target or member data. `/ptw status` reports only public status flags locally, without real names or outgoing messages. Leaving combat does not guarantee that NPC names or chat become available. Version 0.3.0 fixes brief false blocks caused by unrelated restriction events; it does not claim to remove all follower-dungeon restrictions.

## Three optional focus controls

All three switches are **off by default**:

- **Show focus column:** controls only whether the column is visible.
- **Share focus:** sends your own publicly readable focus and accepts compatible snapshots from current group members. Both sides must install the addon and enable sharing. Snapshots expire after 12 seconds without an update.
- **Record chat interrupt declarations:** independently records explicit statements from current group members. The speaker does not need the addon.

Hiding the column or window does not turn off sharing or declaration recording. Disable their individual switches to stop them. Received focus data and declarations are not saved between sessions.

Only complete messages in party, raid and instance-group chat are considered. Open **通报格式…** in settings or use `/ptw formats` to edit incoming declaration templates. This changes recognition rules, not the outgoing target-call message. Defaults:

```text
我打断%mark
我的焦点打断是 {rt%mark}
```

Use one template per line, up to 20 nonempty templates, 255 bytes per template and 8192 bytes total input. Blank lines are ignored; surrounding spaces and tabs are trimmed. Each template requires exactly one `%mark` and permits up to two `%text` placeholders, each matching nonempty text. `%mark` accepts the eight Chinese marker names, digits 1–8 or `{rt1}`–`{rt8}`; `{rt%mark}` matches the canonical `{rtN}` form. All other content is literal, including punctuation and pipes. Unknown named placeholders are rejected.

Templates are tried in saved order, with a full-message match. If one template can identify different markers in the same message, the message is rejected. The sample tester uses the current draft without sending chat or recording an assignment. **Save** applies the draft, clears old declarations and persists the templates; closing without saving leaves the active configuration unchanged. An empty saved list stops new declarations. The fixed phrase `取消打断` still cancels the speaker's declaration while recording is enabled.

Declarations appear in yellow as **约定 (declared assignment)**, expire after 300 seconds, and clear on leaving the group, changing scenes or disabling recording. They do not establish anyone's real focus. A readable automatic focus takes priority. During local chat lockdown, automatic snapshots are hidden; existing public declarations may remain until expiry.

## 0.3.0 Beta: limitations and testing

Targets Retail **12.1.0 / TOC 120100**. Version 0.3.0 passed 69 Lua mock scenarios (37 UI, 32 communication) and seven delivery tests; one symbolic-link test was skipped because Windows denied that privilege. New features have **not been loaded and validated in game**. Updating installed files and observations of earlier versions do not validate this release. Editor scrolling/input, opacity, follower-dungeon diagnostics, cross-client delivery and saved settings still require live verification. CurseForge materials are prepared; this is not a claim of publication or approval.

Game restrictions can cover an entire active Mythic+ run, not just combat. Secret values are never serialized for transmission. Ordinary chat or external services cannot recover restricted real focus data; this addon uses no external bridge. A successful chat API call is not a delivery receipt. Complete compatibility or error-free operation is not established.

As a separate manual option, you can create a native game macro `/p 请集火 %t` and press it yourself. Blizzard documents native target substitution and permits group macro chat subject to current rules. This exact 12.1.0 follower-dungeon case has not been tested, and native macros do not grant addon code permission to serialize secret names. [API sources and verification boundaries](https://github.com/hiltay/PartyTargetWatch/blob/main/docs/API-NOTES.md).

Report problems using the issue link below, with the addon/game version and reproduction steps. Remove personal information from logs or screenshots before sharing.

---

## 简体中文

PartyTargetWatch（队友目标）是《魔兽世界》正式服的独立插件，显示成员当前选中的目标，提供手动目标通报和可选焦点信息。**游戏内界面目前为简体中文。**

### 功能与使用

- 支持单人、小队和最多 40 人团队；超过 20 人使用双列。
- 显示目标团队标记，支持拖动、锁定、60%–200% 缩放和示例预览。
- 背景不透明度 `0`–`1`，默认 `0.88`；`0` 时背景、边框与行底色透明，文字和图标保持可见。
- 可按野外、主城/旅店休息区、地下城（含大秘境）、团本、场景战役、战场和竞技场选择显示；副本类型优先，预览忽略场景筛选。
- 点击“通报目标”、成员行或输入 `/ptw announce` 可通报目标；也可在游戏按键设置中自行绑定。插件不自动分配或覆盖按键。

`/ptw` 显示窗口，`/ptw settings` 打开设置，`/ptw formats` 编辑声明格式，`/ptw test` 切换预览，`/ptw help` 查看命令。`/partytargetwatch` 为等价命令。插件文件夹安装到正式服 `Interface/AddOns` 中。

通报依次选择副本队伍、团队、小队频道；需已组队且信息公开可读，至少间隔 3 秒，预览时不能发送。选中目标不等于正在攻击、治疗或施法；插件不自动选目标或执行战斗操作。

拒发提示区分聊天锁定、目标信息受保护和成员信息受保护。`/ptw status` 仅在本地显示公开状态，不输出真实名称、不发送消息。脱战不保证名称或聊天恢复可用；0.3.0 修复了无关限制事件造成的短暂误拦截，没有宣称解决全部追随者地下城限制。

### 三个焦点开关

三个开关**默认均关闭**：

- **显示队友焦点列**：只控制列是否显示。
- **启用焦点共享**：双方均需安装并启用，各自发送公开可读的自身焦点；12 秒未更新即过期。
- **记录聊天中的打断声明**：独立记录当前组员明确发出的约定，声明者无需安装插件。

隐藏窗口或列不会停止共享或声明记录，请取消相应开关。接收的焦点和声明不会跨会话保存。

只接受队伍、团队和副本队伍聊天中的完整消息。设置中点击“通报格式…”或输入 `/ptw formats` 编辑接收声明的识别规则，不改变“通报目标”发出的文字。默认两条模板为 `我打断%mark` 和 `我的焦点打断是 {rt%mark}`。

每行一个模板，最多 20 条有效模板、每条 255 字节、总输入 8192 字节；忽略空白行并去除两端空格和制表符。每条必须恰含一个 `%mark`，最多两个匹配非空文字的 `%text`。`%mark` 接受八种中文标记名、`1`–`8` 或 `{rt1}`–`{rt8}`；`{rt%mark}` 匹配完整 `{rtN}`。其他内容包括标点、竖线均按字面处理，未知命名占位符会被拒绝。

按有效模板顺序匹配整句；同一模板若能匹配不同标记则拒绝消息。样本测试使用当前草稿，不发送聊天或生成声明。点击“保存”才生效并清空旧声明，保存的模板支持重载保留；关闭而未保存不改当前配置。保存空列表停止新记录，但启用记录时固定“取消打断”仍可清除本人声明。

声明显示为黄色**“约定”**，300 秒过期，离组、换场景或关闭记录时清除，不能证明队友真的设置了该焦点。可读的自动焦点优先；本地聊天锁定隐藏自动缓存，但已有公开声明可保留至过期。

### 0.3.0 测试版的范围与限制

面向正式服 **12.1.0 / TOC 120100**。69 个 Lua mock 场景通过（37 UI、32 通信），交付测试 7 通过、1 因 Windows 符号链接权限跳过。**新增功能尚未在游戏中加载验证**；安装文件更新或历史版本观察不能替代本版验收。编辑器滚动/输入、不透明度、追随者诊断、跨客户端送达与设置保存仍待实测。CurseForge 资料仅准备就绪，不代表已提交、发布或审核通过。

大秘境等限制可能覆盖整段活动，而不只是战斗。秘密值不进入通信；普通聊天和外部服务也不能恢复受限的真实焦点，本项目不提供外部桥接。发送 API 调用成功不代表已送达，不承诺所有场景完全兼容或完全无错误。

可选手动方案是自行创建原生宏 `/p 请集火 %t` 并亲自按下；游戏负责目标名称替换，仍须遵守宏聊天规则。本次尚未验证 12.1.0 追随者场景效果，也不把用户宏当作插件读取秘密名称后发送的豁免。[接口依据与验证边界](https://github.com/hiltay/PartyTargetWatch/blob/main/docs/API-NOTES.md)。

反馈请提供插件/游戏版本及复现步骤，分享日志或截图前移除私人信息。

[Source / 源代码](https://github.com/hiltay/PartyTargetWatch) · [Issues / 问题反馈](https://github.com/hiltay/PartyTargetWatch/issues) · [MIT License / 许可证](https://github.com/hiltay/PartyTargetWatch/blob/main/LICENSE)
