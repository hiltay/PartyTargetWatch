# PartyTargetWatch

An independent WoW Retail addon that displays group members and their selected targets, with customizable focus-name or marker declarations from public chat. **The in-game interface is Simplified Chinese.**

## Features

- Solo, party and raid rosters up to 40 members; two columns above 20 members.
- Target raid markers, movable and lockable window, 60%–200% scaling, sample preview and scene visibility settings.
- Background opacity from 0 to 1, default 0.88. Zero makes background, border and row fills transparent while retaining text and icons.
- Three independent, default-off controls: show the focus column, share publicly readable focus snapshots, and record chat declarations. Sharing requires compatible addons on both clients; chat speakers do not need the addon.

Use `/ptw` to show the window, `/ptw settings` for settings, `/ptw formats` for declaration templates, and `/ptw help` for commands. `/partytargetwatch` is an alias. Install the addon folder in Retail's `Interface/AddOns` folder.

Target selection does not prove someone is attacking, healing or casting at that target. The addon does not choose targets or perform combat actions automatically. Outgoing normal-chat target calls removed in 0.3.1 remain absent; optional public-focus addon communication is unchanged.

## Display focus names from chat

A player can create and manually press this native game macro:

```text
/stopmacro [@focus,noexists]
/p PTW焦点：%f
```

The macro leaves the current target unchanged. On the receiving client, enable **显示队友焦点列** and **记录聊天中的打断声明**. In `/ptw formats`, save this incoming template:

```text
PTW焦点：%name
```

An expanded public message such as `PTW焦点：Monster Name` can then display **Monster Name** in yellow. Each teammate must send their own declaration. Use `%f` in the game macro and `%name` in the addon template.

Existing saved templates are preserved on upgrade. The **加入名称格式** button appends the new template to the editor draft; click **保存格式** to apply it. Closing without saving leaves the active configuration unchanged.

The user has confirmed native `%f` expansion and initial addon name receipt/display. A screenshot exposed a leading `rt4` text artifact; the fix extracts a leading `{rtN}` into a marker icon. That correction, the complete two-line macro, cross-client delivery and combat/Mythic+ behavior still require live verification. Native chat delivery does not guarantee that an addon receives readable text. Protected messages are ignored.

## Template rules

New-install defaults:

```text
我打断%mark
我的焦点打断是 {rt%mark}
PTW焦点：%name
```

Use one template per line, up to 20 nonempty templates, 255 bytes each and 8192 bytes total. Blank lines are ignored and surrounding spaces/tabs are trimmed.

- Each template requires `%mark` or `%name`, or both, with at most one of each. Up to two nonempty `%text` wildcards are allowed.
- `%mark` accepts the eight Chinese marker names, digits 1–8 or `{rt1}`–`{rt8}`. `{rt%mark}` matches the full `{rtN}` form.
- `%name` captures a nonempty name, up to 96 bytes after cleaning. A leading `{rt1}`–`{rt8}` is extracted as a marker icon; a conflict with an explicit `%mark` rejects the declaration. Name-only templates require fixed literal text; `%name` alone is rejected. `%name` and `%text` may not be adjacent. Unexpanded `%f`/`%t` are rejected as names.
- Other text is literal, including punctuation and pipes. Templates match the entire message in configured order; ambiguous name/marker captures and unknown named placeholders are rejected.
- Sample testing uses the draft without sending chat or recording declarations. Saving applies templates, clears old declarations and persists configuration. An empty saved list stops new records; the fixed cancellation phrase `取消打断` still works while recording is enabled.

Only messages from current group members in party, raid or instance-group chat are eligible. Names from declarations appear in yellow; marker-only declarations retain the yellow **约定：marker** label. Declarations expire after 300 seconds and clear on leaving the group, changing scenes or disabling recording. They describe a stated assignment, not a verified current focus, and cannot distinguish individual enemies with the same name. Readable automatic focus takes priority; its snapshots expire after 12 seconds. Hiding the window/column does not disable recording or sharing.

Marker-only messages are not resolved to monster names. The name-display feature uses names already present in public chat, not a marker lookup. Game restrictions can span an entire Mythic+ run. Secret values are never serialized for transmission, and no external communication bridge is provided.

## 0.4.0 Beta and verification

Targets Retail **12.1.0 / TOC 120100**. Offline checks passed: **76 Lua mock scenarios (39 UI, 37 communication)** and seven delivery tests; one delivery test was skipped for Windows symbolic-link privilege. Initial name receipt/display was user-confirmed; the subsequent leading-marker correction still needs live verification. Offline tests cannot establish real secret-value behavior, server delivery or complete compatibility.

For a manual upgrade, back up the old addon folder outside `AddOns`, then replace it with the complete new folder so retired `Bindings.xml` is removed. Preserve `WTF` SavedVariables to keep settings. CurseForge materials remain prepared, not submitted or published. [API sources and verification boundaries](https://github.com/hiltay/PartyTargetWatch/blob/main/docs/API-NOTES.md).

---

## 简体中文

PartyTargetWatch（队友目标）是独立的《魔兽世界》正式服插件，显示成员当前选中的目标，并从公开聊天声明中提取焦点名称或标记。**游戏内界面为简体中文。**

支持单人、小队和最多 40 人团队，超过 20 人使用双列；支持目标标记、拖动、锁定、60%–200% 缩放、示例预览和场景筛选。背景不透明度为 0–1，默认 0.88；设为 0 可让背景、边框和行底色透明，文字与图标保持可见。

`/ptw` 显示窗口，`/ptw settings` 打开设置，`/ptw formats` 编辑声明模板，`/ptw help` 查看命令。`/partytargetwatch` 为等价命令。

### 显示队友声明的焦点名称

发送方在游戏宏界面创建并手动按下：

```text
/stopmacro [@focus,noexists]
/p PTW焦点：%f
```

宏不改变当前目标。接收方开启“显示队友焦点列”和“记录聊天中的打断声明”，在 `/ptw formats` 保存 `PTW焦点：%name`。收到含有实际名称的公开消息后，插件可用黄色显示声明的怪物名称。发送方无需安装本插件，每名队友自行发送自己的声明；宏用 `%f`，识别模板用 `%name`。

升级会保留原有保存格式。点击“加入名称格式”将新模板追加到草稿，再点击“保存格式”才生效；关闭未保存的草稿不会覆盖配置。

用户已在本机确认 `%f` 展开及插件接收/显示名称；截图发现的 `rt4` 前缀文字已改为提取标记图标，修正后的显示仍待复验。完整两行宏、跨客户端送达及战斗/大秘境效果仍待实测。原生宏发得出来，不保证插件当时能读取消息；受保护的聊天正文或发言者会被忽略。

### 格式与状态

默认模板为 `我打断%mark`、`我的焦点打断是 {rt%mark}` 和 `PTW焦点：%name`。每行一个，最多 20 条有效模板，每条 255 字节，总输入 8192 字节；忽略空白行和两端空格/制表符。

- 每条至少含 `%mark` 或 `%name` 之一，二者各最多一个，另可含最多两个非空 `%text`。
- `%mark` 接受中文标记名、数字 1–8 或 `{rt1}`–`{rt8}`；`{rt%mark}` 匹配完整标记文字。
- `%name` 提取非空名称，清理后最多 96 字节。名称前置 `{rt1}`–`{rt8}` 提取为标记图标，剩余文字作为名称；与显式 `%mark` 冲突时拒绝声明。只有名称而无标记的模板需含固定文字，不能只写 `%name`；它与 `%text` 之间也需固定文字分隔。未展开的 `%f`、`%t` 不作为怪物名接受。
- 其余文字按字面整句匹配，按模板顺序尝试；拒绝歧义和未知占位符。样本测试只测草稿，不发消息、不记录声明。
- 保存才生效并清除旧声明；保存空列表停止新声明识别，固定“取消打断”仍可清除本人声明。

只接受当前组员在小队、团队和副本队伍频道中的声明。携带名称时显示黄色名称，只有标记时继续显示黄色“约定：三角”等文字；300 秒过期，离组、换场景或关闭记录时清除。它只代表当时的声明，不能验证实时真实焦点，也不能区分同名的不同怪物。只含标记的消息仍不反查名称。

焦点列、公开焦点共享、聊天声明记录三个开关独立，默认关闭；隐藏窗口/列不关闭共享或记录。公开焦点共享需双方安装并启用，快照 12 秒过期；可读的自动焦点优先于声明。接收数据不跨会话保存。

0.3.1 删除的主动普通聊天通报、按钮和快捷键不恢复。插件不自动选目标或执行战斗操作；仅使用允许的公开数据与通信，不发送秘密值或使用外部桥接。

### 0.4.0 测试版

面向正式服 **12.1.0 / TOC 120100**。76 个 Lua mock 场景通过（39 UI、37 通信），交付测试 7 通过、1 因 Windows 符号链接权限跳过。**首轮名称接收/显示已由用户确认，前置标记修正仍待复验**；模拟测试不代表真实受保护值、服务器送达或所有场景兼容。

手动升级时把旧插件目录备份到 `AddOns` 之外，再用新版完整目录替换以移除废弃的 `Bindings.xml`；保留 `WTF` 中的 SavedVariables 即可保留设置。CurseForge 资料仍为 prepared，尚未提交或发布。[接口依据与验证边界](https://github.com/hiltay/PartyTargetWatch/blob/main/docs/API-NOTES.md)。

[Source / 源代码](https://github.com/hiltay/PartyTargetWatch) · [Issues / 问题反馈](https://github.com/hiltay/PartyTargetWatch/issues) · [MIT License / 许可证](https://github.com/hiltay/PartyTargetWatch/blob/main/LICENSE)
