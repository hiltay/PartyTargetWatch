# PartyTargetWatch

PartyTargetWatch displays your own and your group members' current targets in a movable window. The in-game interface and command messages are in Simplified Chinese.

## Features

- Current target names and raid marker icons for solo play, parties and raids of up to 40 members.
- Two columns for groups larger than 20 members, with offline and unavailable-target states.
- Adjustable position, scale (60%–200%), background opacity, locking and visibility.
- Separate visibility options for outdoor areas, resting areas, dungeons, raids, scenarios, battlegrounds and arenas.
- A sample preview for adjusting the window without a group.
- Settings access through `/ptw settings`, the minimap button's left click, or the game's Settings → AddOns category.

Version 0.5.0 removes all focus and chat-announcement features following user feedback from Mythic+ testing. It retains current-target monitoring. The addon does not select targets or perform combat actions.

For a clean upgrade, back up the old PartyTargetWatch folder outside AddOns and replace it with the folder in the new ZIP. Keep WTF/SavedVariables to preserve window preferences; retired focus settings are removed on load. The release contains seven files and no Communication.lua or Bindings.xml.

The addon displays information permitted by the game APIs. Current target selection does not prove that a member is attacking, healing or casting. Offline tests do not establish live-game or Mythic+ behavior for this release.

[Source code](https://github.com/hiltay/PartyTargetWatch) · [Report issues](https://github.com/hiltay/PartyTargetWatch/issues) · MIT License.

---

# PartyTargetWatch · 队友目标

用可移动窗口显示自己及小队、团队成员当前选中的目标，游戏内界面与提示为简体中文。

- 显示当前目标名称与团队标记，支持单人、小队和最多 40 人团队；超过 20 人分两列。
- 支持位置、60%–200% 大小、背景透明度、锁定和显示/隐藏设置。
- 可分别选择野外、休息区、地下城、团队副本、场景战役、战场和竞技场是否显示。
- 提供示例预览；通过 `/ptw settings`、小地图按钮左键或游戏“设置 → 插件”打开设置。

0.5.0 根据大秘境实测反馈移除全部焦点与聊天通报功能，保留当前目标监控。升级时将旧插件目录备份到 AddOns 外，再放入新版目录；保留 WTF 即可保留窗口偏好，旧焦点设置会在载入时清理。

插件展示游戏 API 允许显示的信息，不自动选取目标或执行战斗操作。离线测试不代表本版已通过实机或大秘境验证。
