# PartyTargetWatch

See who your group members currently have selected in a compact, movable window. PartyTargetWatch is an independent addon for World of Warcraft Retail. When playing solo, it shows your own selected target.

**The in-game interface is currently in Simplified Chinese.** Slash commands use English keywords.

## Features

- Displays each member's name next to their currently selected target.
- Supports solo play, parties, and raids of up to 40 members; larger rosters use two columns.
- Refreshes the visible display approximately every 0.2 seconds.
- Includes a draggable title, position locking, a separate settings window, and 60%–200% scaling.
- Offers a clearly labeled sample preview for adjusting the layout while solo.
- Stores the window's position, scale, visibility, and lock setting.

The display uses information available through the game API. An unavailable target may mean that no target is selected or that the client cannot currently provide that target's information. A selected target does not establish who a member is attacking, healing, or casting at. The addon displays information and does not automatically select targets or perform combat actions.

## Getting started

Install the `PartyTargetWatch` folder inside your Retail client's `Interface/AddOns` folder, enable the addon, then enter the game.

- `/ptw` — show the live display.
- `/ptw settings` — open settings.
- `/ptw test` — toggle the sample preview.
- `/ptw unlock` or `/ptw lock` — change position locking.
- `/ptw scale 1` — set the scale; accepted range is `0.6` to `2`.
- `/ptw hide` — hide the display.
- `/ptw reset` — restore this addon's default display settings.
- `/ptw help` — show command help.

`/partytargetwatch` is an alias for `/ptw`.

## Version 0.1.0 — Beta

Targets Retail **12.1.0**, with TOC interface version **120100**. Live testing has confirmed loading after `/reload`, opening settings, toggling the sample preview, changing scale from 100% to 110% and back, and updating the player's own selected-target name.

**Party, raid, combat, and saved-setting persistence have not yet been tested in the live client.** Offline tests cover additional behavior, but do not reproduce all game restrictions. This first beta does not claim complete compatibility or error-free behavior in every situation.

Please report problems using the issue tracker linked below, including the addon version, game version, and steps to reproduce them. Remove personal information from any logs or screenshots before sharing.

---

## 简体中文

PartyTargetWatch（队友目标）是《魔兽世界》正式服的独立插件，在一个可移动的小窗口中显示“成员 → 当前选中的目标”。单人时显示自己的目标。

**游戏内界面目前为简体中文，命令使用英文关键词。**

### 功能

- 显示成员名字与其当前选中的目标。
- 支持单人、小队与最多 40 名团队成员；超过 20 人时使用双列。
- 可见窗口约每 0.2 秒刷新。
- 支持拖动标题、锁定位置、独立设置窗口及 60%–200% 缩放。
- 提供明确标注的示例预览，方便未组队时调整布局。
- 保存窗口的位置、缩放、显示状态与锁定设置。

目标信息取决于游戏 API 当前允许查询的内容。“无目标 / 不可见”可能表示没有选择目标，也可能表示客户端暂时无法提供该目标的信息。选中目标不代表正在攻击、治疗或对其施法。插件只显示信息，不自动选中目标或执行战斗操作。

### 使用方法

将 `PartyTargetWatch` 文件夹安装到正式服客户端的 `Interface/AddOns` 中，启用插件后进入游戏。

- `/ptw`：显示实时窗口。
- `/ptw settings`：打开设置。
- `/ptw test`：开启或关闭示例预览。
- `/ptw unlock` / `/ptw lock`：解锁或锁定位置。
- `/ptw scale 1`：设置缩放，有效范围为 `0.6` 到 `2`。
- `/ptw hide`：隐藏窗口。
- `/ptw reset`：恢复本插件的默认显示设置。
- `/ptw help`：显示命令帮助。

`/partytargetwatch` 与 `/ptw` 等价。

### 0.1.0 测试版的验证范围

面向正式服 **12.1.0**，TOC 接口版本为 **120100**。已实机确认：`/reload` 后加载、打开设置、切换示例预览、100% → 110% → 100% 缩放，以及自身当前目标名称实时更新。

**多人小队、团本、战斗和设置持久化尚未实机验证。** 离线测试覆盖了部分其他行为，但不能模拟游戏中的全部限制。本首个测试版不承诺所有场景完全兼容或完全无错误。

问题可通过文末的反馈链接提交，请提供插件版本、游戏版本与复现步骤。分享日志或截图前请移除私人信息。

[Source / 源代码](https://github.com/hiltay/PartyTargetWatch) · [Issues / 问题反馈](https://github.com/hiltay/PartyTargetWatch/issues) · [MIT License / 许可证](https://github.com/hiltay/PartyTargetWatch/blob/main/LICENSE)
