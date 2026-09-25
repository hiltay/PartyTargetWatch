# PartyTargetWatch

An independent WoW Retail addon showing group members and their selected targets, with customizable focus-name and marker announcements received from public group chat. **The in-game interface is Simplified Chinese.**

## Features

- Solo, party and raid rosters up to 40 members; two columns above 20 members.
- Target raid markers, a movable and lockable window, 60%–200% scaling, sample preview and scene visibility settings.
- Background opacity from 0 to 1, default 0.88. Zero keeps text and icons visible while making the background, border and row fills transparent.
- Independent controls for the focus/announcement column, incoming announcements and optional addon-to-addon focus synchronization. All default off; updates preserve saved choices.

Use `/ptw` to show the window, `/ptw settings` for settings, `/ptw formats` for incoming templates and `/ptw help` for commands. Install the addon folder in Retail's `Interface/AddOns` folder.

## Receive teammates' focus announcements

Under **焦点与通报**, enable **显示焦点 / 通报列** and **接收队友的焦点通报**. These two controls are sufficient for chat announcements. The sender does not need PartyTargetWatch, and **插件间焦点同步（可选）** can remain off. Open **接收格式…** to configure matching templates.

Teammates using SeUI 1.8.4 can configure their existing quick-focus announcement once:

```text
我的焦点打断是 {rt%mark} %f
```

Save this matching incoming template in PartyTargetWatch:

```text
我的焦点打断是 {rt%mark} %name
```

Their usual SeUI focus action then includes the announcement, without another chat message or announcement key. Keep SeUI's focus party announcement enabled and select a nonempty marker; changes made during combat apply after combat. `%f` is the native sending macro's focus placeholder; `%name` captures the already-expanded name on the receiving side. The prefix is customizable.

SeUI's `%mark` is the marker selected in its settings. With existing-marker protection enabled, it can differ from the monster's existing marker. Conflicting explicit and name-prefix markers are rejected. The alternative pair `PTW焦点：%f` / `PTW焦点：%name` avoids an explicit configured marker. Other announcement addons may use different sending placeholders: their actual message must contain a focus name, not a literal `%f` or merely the target of a successful interrupt.

The **焦点 / 通报** column shows yellow names or assignments from the latest received announcement. Changing focus requires a new announcement. Records expire after five minutes; a group member can send `取消打断` to clear their own record. **等待通报** means receiving is enabled, synchronization is off and no usable record is available. Yellow records do not verify current focus or distinguish same-name enemies.

Optional focus synchronization still requires both clients to install and enable it, with the game allowing readable data and communication. Readable automatic focus takes priority; remote snapshots expire after 12 seconds. Hiding the window or column does not disable reception or synchronization.

## Incoming templates

New-install defaults:

```text
我打断%mark
我的焦点打断是 {rt%mark}
PTW焦点：%name
```

- One template per line: up to 20 nonempty templates, 255 bytes each and 8192 bytes total. Blank lines and surrounding spaces/tabs are ignored.
- Each template requires `%mark` or `%name`, or both, with at most one of each. Up to two nonempty `%text` wildcards are allowed.
- `%mark` accepts the eight Chinese marker names, digits 1–8 or `{rt1}`–`{rt8}`. `{rt%mark}` matches a full `{rtN}` token.
- `%name` captures a nonempty name, up to 96 bytes after cleaning. A leading `{rt1}`–`{rt8}` becomes a marker icon; a conflict with explicit `%mark` rejects the message. Name-only templates need fixed text. `%name` and `%text` cannot be adjacent. Unexpanded `%f` and `%t` are rejected as names.
- Other text is literal. Full-message matching follows template order and rejects ambiguous captures and unknown placeholders.
- Draft tests send no chat and record no announcements. **保存格式** applies the draft and clears old records. Existing templates are preserved on upgrade; **加入名称格式** appends `PTW焦点：%name` to the draft only. Saving an empty list stops new records; cancellation remains available while reception is enabled.

Only current members' public party, raid and instance-group messages are eligible. Records also clear when leaving the group, changing scenes or disabling reception. Marker-only declarations retain the yellow **约定：marker** display; they are not resolved to monster names. Protected messages are ignored. The addon does not select targets, perform combat actions, send ordinary target-call chat or bypass game restrictions.

## 0.4.1 Beta and verification

Targets Retail **12.1.0 / TOC 120100**. Version 0.4.1 updates settings, status text and explanations without changing chat parsing or synchronization. Its new UI awaits an in-game reload check. Version 0.4.1 passed 76 Lua mock scenarios (39 UI, 37 communication) and seven delivery tests, with one Windows symbolic-link privilege skip. The user confirmed 0.4.0 name/icon display and the SeUI custom-format workflow locally. Cross-client and combat/Mythic+ behavior remain unverified.

For manual upgrades, back up the old addon folder outside `AddOns`, then replace it with the complete new folder so retired `Bindings.xml` is removed. Preserve `WTF` SavedVariables to retain settings. CurseForge materials remain prepared, not submitted or published. [API sources and verification boundaries](https://github.com/hiltay/PartyTargetWatch/blob/main/docs/API-NOTES.md).

---

## 简体中文

PartyTargetWatch（队友目标）显示成员当前选中的目标，并从公开组队聊天中接收焦点名称或标记。游戏内界面为简体中文。支持最多 40 人团队、目标标记、拖动锁定、60%–200% 缩放、预览和场景筛选；背景不透明度可设为 0–1，设为 0 时文字与图标仍可见。

`/ptw` 显示窗口，`/ptw settings` 打开设置，`/ptw formats` 编辑接收格式。

### 复用队友已有的焦点喊话

在“焦点与通报”中开启“显示焦点 / 通报列”和“接收队友的焦点通报”即可。发送方无需安装本插件，也无需开启“插件间焦点同步（可选）”。点击“接收格式…”设置识别模板。

使用 SeUI 1.8.4 的队友将快速焦点喊话配置为：

```text
我的焦点打断是 {rt%mark} %f
```

接收方保存以下模板：

```text
我的焦点打断是 {rt%mark} %name
```

每名队友只需配置一次，以后原来的 SeUI 设置焦点操作会同时喊话，无需另打字或另按通报键。保留 SeUI 的“焦点时小队喊话”勾选，选择非“无”的标记；战斗中修改设置要等脱战后应用。发送端原生宏用 `%f`，接收模板用 `%name`；整句前缀可以自定义。

SeUI 的 `%mark` 是面板选中的标记；“不覆盖已有标记”可能使它与怪物已有标记不同。显式标记与名称前缀标记冲突时，本插件拒绝该消息。也可配对使用 `PTW焦点：%f` 与 `PTW焦点：%name`，不显式填写所选标记。其他插件需按其实际占位符配置，保证发出的消息含有焦点名称；打断成功时的受击目标不等于焦点。

“焦点 / 通报”列的黄色名称或标记来自队友最近一次通报，换焦点后需再次通报，记录有效 5 分钟。队友在组队频道发送“取消打断”清除自己的记录。接收开启、同步关闭且无可用记录时显示“等待通报”。这些记录不能确认实时焦点，也不能区分同名怪物。

### 接收格式与可选同步

每行一个模板，最多 20 条、每条 255 字节、总输入 8192 字节。每条至少含 `%name` 或 `%mark` 之一，二者各最多一个，另可含最多两个非空 `%text`。`%mark` 接受中文标记名、数字 1–8 或 `{rtN}`；`%name` 捕获清理后最多 96 字节的非空名称，前置 `{rtN}` 提取为图标。只有名称的模板必须含固定文字，名称与 `%text` 之间也需要固定分隔；未展开 `%f`/`%t` 不作为名称接受。其余内容按字面整句匹配，拒绝歧义和未知占位符。

样本测试只检查草稿，不发消息；“保存格式”使其生效并清除旧记录。“加入名称格式”只在草稿追加 `PTW焦点：%name`。升级保留已有模板，保存空列表停止新记录，接收开启时固定取消语句仍有效。

三个开关独立、默认关闭，升级保留已保存选择。可选插件间同步需要双方安装启用，且游戏允许读取与通信；远端快照 12 秒过期，可读自动焦点优先。隐藏窗口或列不关闭接收与同步。只接收当前组员的小队、团队和副本队伍公开消息，离组、换场景或关闭接收时清除记录；只含标记时保留黄色“约定：三角”等显示，不反查名称。受保护消息会被忽略，不提供解除游戏限制的外部通信方案。

### 0.4.1 测试版

面向正式服 **12.1.0 / TOC 120100**。本版调整设置、状态文字与说明，聊天解析与同步协议不变；新界面仍待 `/reload` 后实机确认。0.4.1 有 76 个 Lua mock 通过（39 UI、37 通信），交付测试 7 通过、1 因 Windows 符号链接权限跳过；0.4.0 已有用户确认的名称、图标显示与 SeUI 自定义格式联动。跨客户端、战斗与大秘境完整流程仍未验证。

手动升级时先将旧插件目录备份到 `AddOns` 之外，再用完整新目录替换，移除废弃的 `Bindings.xml`；保留 `WTF` SavedVariables 即可保留设置。CurseForge 资料仍为 prepared，尚未提交或发布。

[Source / 源代码](https://github.com/hiltay/PartyTargetWatch) · [Issues / 问题反馈](https://github.com/hiltay/PartyTargetWatch/issues) · [MIT License / 许可证](https://github.com/hiltay/PartyTargetWatch/blob/main/LICENSE)
