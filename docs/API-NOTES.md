# Retail 12.1.0 API 核查记录

核查日期：2026-09-25。以下 API 证据锁定 Gethe 镜像的 `12.1.0` 标签；镜像内容是暴雪随客户端提供的 API 生成文档和 UI 源码。研究未读取或参考 TheOddTargeter。

## 目标名称与标记

- `UnitName` 使用 `SecretWhenUnitNameIdentityRestricted`，名称可能是 secret，不能据名称做排序、匹配、相等缓存或通信序列化。`UnitExists`、`UnitIsConnected` 没有 secret-return 标记；以自建的普通 unit token 查询，检测不到目标时清空旧名称。`UnitName` 对不存在/尚未加载单位的具体占位行为不由生成签名保证，因此不依赖比较 `UNKNOWNOBJECT` 判断目标存在。[UnitDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- 身份限制考虑 compound token 的整条链；不能因为 `party1` 是公开队友，就认为 `party1target` 的敌人名字公开。12.1 的名字 predicate 另有 PvP 玩家例外。不要用“是否战斗”自行代替这些规则。[SecretPredicatesDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicatesDocumentation.lua)
- 名称可直接传给 `FontString:SetText` / `SetFormattedText`；这些方法允许 tainted addon 传入 secret，并将 Text aspect 标为 secret。固定列宽，避免通过 `GetText` 或文字尺寸回读、识别名称。[SimpleFontStringAPIDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua)
- `GetRaidTargetIndex` 标记为 `SecretReturns = true`，返回类型为可空 `luaIndex`。不能默认它在脱战时公开，也不能用它拼贴图路径、当表下标、比较范围、计算 UV 或生成 `{rtN}` 通报文字。[RaidMarkersDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/RaidMarkersDocumentation.lua)
- 显示路径是固定 `Interface\\TargetingFrame\\UI-RaidTargetingIcons` 纹理，原样调用 `Texture:SetSpriteSheetCell(index, 4, 4)`。该 C API 的 cell 参数允许 secret，而行列数必须公开；暴雪自己的 `SetRaidTargetIconTexture` 正是这个 4×4 调用。先隐藏旧图，空值/失败保持隐藏，成功再显示。不需要解密标记。[Texture API](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua)、[TargetFrame.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_UnitFrame/Mainline/TargetFrame.lua)

`type(index) == "number"` 只检查类型，并不读取标记编号。关于 `type(secret)` 仍返回真实 Lua 类型的直接文字说明可见[社区技术参考](https://warcraft.wiki.gg/wiki/Secret_aspects)。这不是暴雪官方声明；本次没有找到生成文档中 Lua builtin `type` 的独立条目，也没有在真实 12.1.0 客户端重现该行为。原生显示调用应保留失败时清空的保护，并在客户端验证有标记、无标记及解除标记三种情况。

## 队友焦点与通信

可用的本地焦点是 `focus`，其变化事件为 `PLAYER_FOCUS_CHANGED`。生成的 UnitTokenType 列出 Focus、FocusTarget 及 Party 单位，没有可据此使用的“队友焦点”接口。本次未取得原生 token parser 的实现，也未在客户端实测 `party1focus`；因此**不把 `party1focus` 当作受支持接口**。共享功能由各客户端读取自己的 `focus`，仅在值公开、通信允许时发送；对方必须安装并启用兼容协议。[UnitSharedDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitSharedDocumentation.lua)、[UnitDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)

- `C_ChatInfo.SendAddonMessage` 的 `SecretArguments` 为 `NotAllowed`。`pcall`、字符串格式化、转存变量、换传输渠道均不会使 secret 变成可发送的普通数据。
- 注册前缀、发送消息都返回枚举，不是布尔值。注册：Success=0，DuplicatePrefix=1，InvalidPrefix=2，MaxPrefixes=3。发送成功为0，节流为3/8，AddOnMessageLockdown=11，TargetOffline=12。不要把 Lua 中为真的数值0错误理解为失败。
- `CHAT_MSG_ADDON` 依次提供 prefix、text、channel、sender、target 等参数。处理前先做 secret 检查，再检查类型、长度、协议版本及 sender 是否为当前组员；不把消息声称的玩家名当身份凭据。
- 查询 `C_ChatInfo.InChatMessagingLockdown()`，并考虑 `AreOutgoingAddonChatMessagesRestricted()`。后者的文档强调发送和接收权限独立、服务器规则可能不同；调用未报 Lua 错误不等于已送达。

上述通信签名与枚举来源：[ChatInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua)、[ChatConstantsDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatConstantsDocumentation.lua)。

通信锁定不等于普通战斗：ChallengeMode 指尚未完成的活动大秘境，PvPMatch 指尚未结束的比赛；Chat 是单独的限制类型。限制期间停止发送、停止采用远端数据并清理/失效缓存；恢复后重新请求。`ADDON_RESTRICTION_STATE_CHANGED(type, state)` 在限制开启前、解除后派发；派发期间 `IsAddOnRestrictionActive` 总返回 false。应使用 payload，或下一帧再查询，不能在该事件内短暂误判为解锁。[RestrictedActionsConstantsDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsConstantsDocumentation.lua)、[RestrictedActionsDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsDocumentation.lua)

普通队伍聊天里的公开声明只能标成“约定/声明记录”，不能当作当前实际焦点。消息在受限阶段可能不可读；不能通过读取普通聊天恢复 addon comms 被禁止的信息。无数据、未共享、超时、离线、通信受限应与“无焦点”分开。

## 主动通报移除与外部服务

0.3.1 已删除读取目标并向普通聊天发送通报的路径及其 UI、命令、快捷键和专用诊断。目标监控、接收公开聊天声明、默认关闭的公开焦点插件通信仍保留。

`C_ChatInfo.SendChatMessage` 标有 HasRestrictions、RestrictedForMacroChatMessages，secret 参数仅允许 untainted 执行。用户点击或按键不会使 addon 获得读取、拼接或序列化受保护目标名称的权限。[ChatInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua)

WoW addon 的受支持 Lua API 没有任意 HTTP/socket 客户端接口。暴雪 Browser API 的 UI/事件也不是任意网络传输接口；公开 Battle.net Web API 不是当前客户端的队友焦点/secret 数据读取接口。自建外部服务不能让 addon 序列化不能读取的数据，不能作为本功能解除限制的方案。本项目只使用游戏允许的公开信息与通信 API；没有设计外部桥接。[受支持 API 清单](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/Blizzard_APIDocumentationGenerated.toc)、[BrowserDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/BrowserDocumentation.lua)

## 显示场景与验证边界

`IsResting()` 是普通 bool，适合 UI 明确标注“主城/旅店休息区”的开关；它不是精确的“只在城市”判定。本次未找到可替代它的通用 City API。副本类型应优先于休息区分类。[PlayerScriptDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/PlayerScriptDocumentation.lua)

本记录确认的是接口签名、secret 元数据、暴雪 UI 用法与官方公告，不是游戏内验收。Lua mock 无法模拟真实 secret、taint、服务器限流或对方客户端。发布前应人工核验：两个客户端的公开焦点共享与聊天声明；副本/M+整段限制及恢复；标记设置/取消；长中文名称；掉线/离组/重载后的缓存失效。

## 0.3.1：追随者场景反馈与移除范围

用户反馈追随者地下城脱战后仍有通报受限提示，随后报告 0.3.0 的具体提示为“目标信息受保护；即使界面能显示名称，也不能读取或拼接为聊天文字”。这说明该次发送路径被目标信息检查拦截。没有取得完整 `/ptw status` 输出，不据此推断同一时刻的聊天锁定状态，也不推断所有追随者 NPC 或所有消息均受限。0.3.1 移除这个主动发送功能及独立的 `Bindings.xml`，安装升级时清理旧绑定文件。

接收队友已经发送的公开聊天声明不需要读取目标名称，因此保留模板编辑与匹配。声明只是当时的约定，不验证对方真实焦点；消息本身受保护或不可读时不能识别。

只含标记的声明不能可靠地转换为怪物名称。`GetRaidTargetIndex` 的签名使用无条件的 `SecretReturns = true`，未承诺脱战后可读取编号；遍历目标或姓名板再比较标记编号的方案因而不能保证可用。已知单位的 `UnitName` 可直接传给允许秘密值的文字控件，这只提供显示能力，不能据此把受保护标记与名称建立可查询映射。0.3.1 没有加入标记反查名称或名称占位符。[RaidMarkersDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/RaidMarkersDocumentation.lua)、[SimpleFontStringAPIDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua)

`InChatMessagingLockdown` 的生成说明只承诺查询聊天 API 的安全限制。对应 secret predicate 列出 Encounter、ChallengeMode、PvPMatch 和通信受限地图，没有将普通 Combat 单独列入；不能把它简化成“所有副本”或“所有战斗”，也不能用脱战状态证明已解除限制。`UnitName` 的身份 predicate 则未将战斗作为必要前提；compound token 的整条链参与判断。元数据不足以进一步证明“追随者副本的每个 NPC 在整段副本中始终保密”。应分别检查 `partyN` 成员和 `partyNtarget` 目标的实际返回值。[ChatInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua)、[SecretPredicatesDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicatesDocumentation.lua)

`C_Secrets.ShouldUnitIdentityBeSecret(unit)` 提供公开 bool，可用于进一步人工诊断身份规则；但 `UnitName` 的 PvP 玩家例外使它不能完全代替对实际返回值的 `issecretvalue` 检查。[SecretPredicateAPIDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicateAPIDocumentation.lua)

0.3.0 将临时限制标志限定为 `Enum.AddOnRestrictionType.Chat`（5）：Activating（1）或 Active（2）设置，Inactive（0）清除；不再因任意 Combat/Map 事件就暂时认定聊天锁定。下一帧仍查询实际聊天状态。`C_RestrictedActions.IsAddOnRestrictionActive` 在限制事件派发期间总返回 false，文档也没有承诺它与 `InChatMessagingLockdown` 完全等价，因此不能直接替换后者。该修复只处理无关事件引发的短暂误拦截，不解除游戏本身的限制。[状态枚举](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsConstantsDocumentation.lua)、[限制查询与事件](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsDocumentation.lua)

暴雪的[追随者地下城介绍](https://worldofwarcraft.blizzard.com/en-us/news/24054790)确认 NPC 会加入队伍补齐成员，但没有说明其名称秘密值或插件聊天的特别豁免。该文档不能证明存在追随者专有的全面聊天禁令。

## 0.3.0：多行模板编辑器的原生依据

12.1.0 的[暴雪宏编辑器 XML](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_MacroUI/Blizzard_MacroUI.xml)将多行 EditBox 作为 ScrollChild，初始大小与视口相同；通过 `ScrollingEdit_OnCursorChanged`、`ScrollingEdit_OnTextChanged` 和 `ScrollingEdit_OnUpdate` 处理光标与滚动，没有按文本手动增高的逻辑。公共 [InputBoxTemplates.xml](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml)中的 `InputScrollFrameTemplate` 同样使用仅顶部定位的多行 EditBox；[对应 Lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.lua)设置宽度，并在滚动范围可用时更新光标位置。由这些原生用法可知，初始 `SetSize` 本身不应被视作阻止多行自然增高；但底部锚点锁高、即时布局时序及鼠标选区仍需在客户端检查。

`SetMultiLine`、`SetMaxBytes`、`SetMaxLetters`、`SetTextInsets`、`SetAltArrowKeyMode` 均在当前 [EditBox API](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua)中。`SetTextInsets` 仅设置留白；字符/字节限制不负责禁用 markup。`SetAltArrowKeyMode(false)` 用于普通方向键光标操作，不处理转义。生成文档未提供 EditBox 的 `SetIgnoreMarkup`。

编辑器的原文与 UI 竖线表示应分开处理，并验证成对转换后仍保留单个及连续竖线；暴雪 [AccountLogin.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_GlueXML/Mainline/AccountLogin.lua)也对 EditBox 读取结果执行 `||` 到 `|` 的转换。模板限制按还原后的原文字节校验，不能拿 `SetMaxLetters` 代替 8192 字节总限制。`{rt%mark}` 应保留为编辑文字，不调用聊天图标替换函数。源码对照与离线转换测试均不能证明真实客户端的输入、粘贴、长行换行及滚动效果已通过。
