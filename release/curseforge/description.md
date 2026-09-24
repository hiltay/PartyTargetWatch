# PartyTargetWatch

An independent WoW Retail addon that displays group members and their selected targets, with manual target calls and optional focus information. **The in-game interface is currently Simplified Chinese.**

## Features and use

- Solo, party and raid rosters up to 40 members, with two columns above 20 members.
- Target raid markers, a movable and lockable window, 60%–200% scaling, and sample preview.
- Visibility settings for the open world, resting areas, dungeons (including Mythic+), raids, scenarios, battlegrounds and arenas. Instance type takes priority; preview ignores scene filters.
- A target-call button, clickable member rows, `/ptw announce`, and an optional key binding assigned by you in the game's key-binding settings. No keys are assigned automatically.

Use `/ptw` to show the window, `/ptw settings` for settings, `/ptw test` for preview, and `/ptw help` for commands. `/partytargetwatch` is an alias. Install the addon folder in the Retail client's `Interface/AddOns` folder.

Manual calls use instance chat, raid chat, or party chat, in that order. They require a group, readable public data, and at least three seconds between calls. Preview cannot send calls. Target selection does not prove who someone is attacking, healing or casting at; the addon does not select targets or perform combat actions automatically.

## Three optional focus controls

All three switches are **off by default**:

- **Show focus column:** controls only whether the column is visible.
- **Share focus:** sends your own publicly readable focus and accepts compatible snapshots from current group members. Both sides must install the addon and enable sharing. Snapshots expire after 12 seconds without an update.
- **Record chat interrupt declarations:** independently records explicit statements from current group members. The speaker does not need the addon.

Hiding the column or window does not turn off sharing or declaration recording. Disable their individual switches to stop them. Received focus data and declarations are not saved between sessions.

Declarations must be the complete message `我打断` followed by exactly one of `星星`, `圆圈`, `菱形`, `三角`, `月亮`, `方块`, `叉叉`, or `骷髅`; the canonical forms `我打断{rt1}` through `我打断{rt8}` are also accepted. `取消打断` cancels the speaker's declaration. Extra wording, line breaks and casual mentions are ignored. Only party, raid and instance-group chat is considered.

Declarations appear in yellow as **约定 (declared assignment)**, expire after 300 seconds, and clear on leaving the group, changing scenes or disabling recording. They do not establish anyone's real focus. A readable automatic focus takes priority. During local chat lockdown, automatic snapshots are hidden; existing public declarations may remain until expiry.

## 0.2.0 Beta: limitations and testing

Targets Retail **12.1.0 / TOC 120100**. Version 0.2.0 has passed offline mock tests, but its new features have **not been tested in the live game**. Earlier solo checks of version 0.1.0 do not validate this version. Group play, combat restrictions, cross-client delivery and in-game setting persistence still require live verification.

Game restrictions can cover an entire active Mythic+ run, not just combat. Secret values are never serialized for transmission. Ordinary chat or external services cannot recover restricted real focus data; this addon uses no external bridge. A successful chat API call is not a delivery receipt. Complete compatibility or error-free operation is not established.

Report problems using the issue link below, with the addon/game version and reproduction steps. Remove personal information from logs or screenshots before sharing.

---

## 简体中文

PartyTargetWatch（队友目标）是《魔兽世界》正式服的独立插件，显示成员当前选中的目标，提供手动目标通报和可选焦点信息。**游戏内界面目前为简体中文。**

### 功能与使用

- 支持单人、小队和最多 40 人团队；超过 20 人使用双列。
- 显示目标团队标记，支持拖动、锁定、60%–200% 缩放和示例预览。
- 可按野外、主城/旅店休息区、地下城（含大秘境）、团本、场景战役、战场和竞技场选择显示；副本类型优先，预览忽略场景筛选。
- 点击“通报目标”、成员行或输入 `/ptw announce` 可通报目标；也可在游戏按键设置中自行绑定。插件不自动分配或覆盖按键。

`/ptw` 显示窗口，`/ptw settings` 打开设置，`/ptw test` 切换预览，`/ptw help` 查看命令。`/partytargetwatch` 为等价命令。插件文件夹安装到正式服 `Interface/AddOns` 中。

通报依次选择副本队伍、团队、小队频道；需已组队且信息公开可读，至少间隔 3 秒，预览时不能发送。选中目标不等于正在攻击、治疗或施法；插件不自动选目标或执行战斗操作。

### 三个焦点开关

三个开关**默认均关闭**：

- **显示队友焦点列**：只控制列是否显示。
- **启用焦点共享**：双方均需安装并启用，各自发送公开可读的自身焦点；12 秒未更新即过期。
- **记录聊天中的打断声明**：独立记录当前组员明确发出的约定，声明者无需安装插件。

隐藏窗口或列不会停止共享或声明记录，请取消相应开关。接收的焦点和声明不会跨会话保存。

只接受队伍、团队和副本队伍聊天中的完整消息：“我打断”加“星星、圆圈、菱形、三角、月亮、方块、叉叉、骷髅”之一，或 `我打断{rt1}` 至 `我打断{rt8}`。“取消打断”清除本人声明；额外前后文、换行与任意提及不算声明。

声明显示为黄色**“约定”**，300 秒过期，离组、换场景或关闭记录时清除，不能证明队友真的设置了该焦点。可读的自动焦点优先；本地聊天锁定隐藏自动缓存，但已有公开声明可保留至过期。

### 0.2.0 测试版的范围与限制

面向正式服 **12.1.0 / TOC 120100**。本版通过了离线 mock 测试，**新增功能尚未实机验证**；0.1.0 的单人历史实测不能作为本版验证。多人、战斗限制、跨客户端送达与游戏内设置持久化仍待实测。

大秘境等限制可能覆盖整段活动，而不只是战斗。秘密值不进入通信；普通聊天和外部服务也不能恢复受限的真实焦点，本项目不提供外部桥接。发送 API 调用成功不代表已送达，不承诺所有场景完全兼容或完全无错误。

反馈请提供插件/游戏版本及复现步骤，分享日志或截图前移除私人信息。

[Source / 源代码](https://github.com/hiltay/PartyTargetWatch) · [Issues / 问题反馈](https://github.com/hiltay/PartyTargetWatch/issues) · [MIT License / 许可证](https://github.com/hiltay/PartyTargetWatch/blob/main/LICENSE)
