# Retail 12.1.0 API 核查记录

核查日期：2026-09-25。以下 API 证据锁定 Gethe 镜像的 `12.1.0` 标签；镜像内容是暴雪随客户端提供的 API 生成文档和 UI 源码。研究未读取或参考 TheOddTargeter。

## 目标名称与标记

- `UnitName` 使用 `SecretWhenUnitNameIdentityRestricted`，名称可能是 secret，不能据名称做排序、匹配、相等缓存或通信序列化。`UnitExists`、`UnitIsConnected` 没有 secret-return 标记；以自建的普通 unit token 查询，检测不到目标时清空旧名称。`UnitName` 对不存在/尚未加载单位的具体占位行为不由生成签名保证，因此不依赖比较 `UNKNOWNOBJECT` 判断目标存在。[UnitDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- 身份限制考虑 compound token 的整条链；不能因为 `party1` 是公开队友，就认为 `party1target` 的敌人名字公开。12.1 的名字 predicate 另有 PvP 玩家例外。不要用“是否战斗”自行代替这些规则。[SecretPredicatesDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicatesDocumentation.lua)
- 名称可直接传给 `FontString:SetText` / `SetFormattedText`；这些方法允许 tainted addon 传入 secret，并将 Text aspect 标为 secret。固定列宽，避免通过 `GetText` 或文字尺寸回读、识别名称。[SimpleFontStringAPIDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua)
- `GetRaidTargetIndex` 标记为 `SecretReturns = true`，返回类型为可空 `luaIndex`。不能默认它在脱战时公开，也不能用它拼贴图路径、当表下标、比较范围、计算 UV 或生成 `{rtN}` 通报文字。[RaidMarkersDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/RaidMarkersDocumentation.lua)
- 显示路径是固定 `Interface\\TargetingFrame\\UI-RaidTargetingIcons` 纹理，原样调用 `Texture:SetSpriteSheetCell(index, 4, 4)`。该 C API 的 cell 参数允许 secret，而行列数必须公开；暴雪自己的 `SetRaidTargetIconTexture` 正是这个 4×4 调用。先隐藏旧图，空值/失败保持隐藏，成功再显示。不需要解密标记。[Texture API](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua)、[TargetFrame.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_UnitFrame/Mainline/TargetFrame.lua)

`type(index) == "number"` 只检查类型，并不读取标记编号。关于 `type(secret)` 仍返回真实 Lua 类型的直接文字说明可见[社区技术参考](https://warcraft.wiki.gg/wiki/Secret_aspects)。这不是暴雪官方声明；本次没有找到生成文档中 Lua builtin `type` 的独立条目，也没有在真实 12.1.0 客户端重现该行为。原生显示调用应保留失败时清空的保护，并在客户端验证有标记、无标记及解除标记三种情况。

## 显示场景与验证边界

`IsResting()` 是普通 bool，适合 UI 明确标注“主城/旅店休息区”的开关；它不是精确的“只在城市”判定。本次未找到可替代它的通用 City API。副本类型应优先于休息区分类。[PlayerScriptDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/PlayerScriptDocumentation.lua)

本记录记录既有接口核查，不是游戏内验收。Lua mock 无法模拟真实 secret、taint 或对方客户端。当前版本仍需在游戏中核验副本/M+内的当前目标显示、标记设置/取消、长中文名称、掉线/离组后的显示，以及重载后的窗口设置保留。

## 0.5.0：当前实现范围

用户在大秘境实测后报告焦点方案不可用。本版删除整个通信模块、聊天解析、名称模板、焦点列和相关入口；不读取 `focus` 单元、不注册聊天或焦点事件、不发送聊天或插件消息。历史方案及验证结果保留在 Git 历史、CHANGELOG 和 validation/TESTING.md，不作为现行使用指南。

当前目标继续使用 `target`、`partyNtarget`、`raidNtarget`；名称和标记的 secret 值只传给上述支持的 UI 显示接口，显示路径未因删除焦点功能而改变。

`Settings.lua` 中的 `ClearFocus`、`SetAutoFocus` 只控制位置输入框的键盘输入焦点，与游戏焦点单位无关。初始化对四个旧配置字段赋 nil 仅用于升级清理，不保留旧功能开关。

小地图按钮与原生设置入口由 `Integration.lua` 创建。原生分类使用 `Settings.RegisterCanvasLayoutCategory` 和 `Settings.RegisterAddOnCategory`；小地图按钮只保留左键打开设置，允许收纳插件重新设置父级、位置和尺寸。
