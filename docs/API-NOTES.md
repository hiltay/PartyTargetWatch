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

`C_ChatInfo.SendChatMessage` 标有 HasRestrictions、RestrictedForMacroChatMessages，secret 参数仅允许 untainted 执行。用户点击或按键不会使 addon 获得读取并序列化受保护目标名称用于发送的权限。游戏原生宏自身的占位符展开与 addon 调用发送接口是不同路径，见下方 0.4.0 记录。[ChatInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua)

WoW addon 的受支持 Lua API 没有任意 HTTP/socket 客户端接口。暴雪 Browser API 的 UI/事件也不是任意网络传输接口；公开 Battle.net Web API 不是当前客户端的队友焦点/secret 数据读取接口。自建外部服务不能让 addon 序列化不能读取的数据，不能作为本功能解除限制的方案。本项目只使用游戏允许的公开信息与通信 API；没有设计外部桥接。[受支持 API 清单](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/Blizzard_APIDocumentationGenerated.toc)、[BrowserDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/BrowserDocumentation.lua)

## 显示场景与验证边界

`IsResting()` 是普通 bool，适合 UI 明确标注“主城/旅店休息区”的开关；它不是精确的“只在城市”判定。本次未找到可替代它的通用 City API。副本类型应优先于休息区分类。[PlayerScriptDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/PlayerScriptDocumentation.lua)

本记录确认的是接口签名、secret 元数据、暴雪 UI 用法与官方公告，不是游戏内验收。Lua mock 无法模拟真实 secret、taint、服务器限流或对方客户端。发布前应人工核验：两个客户端的公开焦点共享与聊天声明；副本/M+整段限制及恢复；标记设置/取消；长中文名称；掉线/离组/重载后的缓存失效。

## 0.4.1：接收通报与可选同步的界面区分

本版不调整 API 读取、聊天解析、同步协议或限制判断。设置中的“焦点与通报”依次提供“显示焦点 / 通报列”“接收队友的焦点通报”和“插件间焦点同步（可选）”，格式入口为“接收格式…”。聊天方案只需前两项，发言者无需本插件；可选同步仍要求双方安装启用且游戏允许。升级保留现有保存开关，不强制启用接收或关闭同步。

主列与底部文字强调接收记录：列名“焦点 / 通报”，底部“黄色：队友最近一次通报”。接收开启、同步关闭且无记录时显示“等待通报”。黄色记录来自最近一次公开通报，换焦点后需再次通报，5 分钟有效；组员的“取消打断”消息清除其本人记录。接收格式以 `%name` 匹配已展开的名称，SeUI 原生发送宏仍用 `%f`。这些文字不改变数据来源或记录生命周期，也不把声明当作实时焦点。新版界面仍待用户 `/reload` 后确认。

## 0.4.0：原生宏名称声明

本版新增接收模板 `PTW焦点：%name`，从游戏允许读取的聊天正文中提取名称，不从受保护标记反查怪物。接收方仍检查正文、发言者、当前组员身份与整句格式；秘密值消息不会进入解析。`%name` 与 `%mark` 各至多一个且至少存在其一；仅名称模板需有固定文字，`%name` 与 `%text` 不得相邻。清理后的名称至多 96 字节，拒绝未展开的 `%f`、`%t`；同模板存在不同名称或标记的解释时拒绝消息。

供玩家手动创建、按下的原生宏示例为：

```text
/stopmacro [@focus,noexists]
/p PTW焦点：%f
```

用户于 2026-09-25 现场确认 `/p PTW焦点：%f` 展开为焦点怪物名称。这是本机对原生聊天展开的观察，不证明插件接收端在同一场景中得到公开文字，也不证明战斗、大秘境、其他客户端或完整两行宏均已验证。本次没有找到暴雪当前公开 Lua 实现或正式规范对 `%f` 的独立说明，因此不将用户观察扩大为所有场景保证。

0.4.0 安装后，用户确认插件接收并显示了名称；截图显示名称前带有错误的 `rt4` 文字。修正路径只处理公开聊天名称开头的 `{rt1}`–`{rt8}`，将其提取为图标标记，再显示剩余名称；若与模板显式 `%mark` 冲突则拒绝声明。尚未确定该前缀由用户宏还是游戏展开产生，不声称原生 `%f` 自动添加标记。该修正未读取 `GetRaidTargetIndex`，不是受保护标记反查。修正版已重新打包并在备份首轮 0.4.0 后安装，其他插件保持不变；用户第二轮执行 `/reload` 并发送原生焦点名称消息后确认“已正常显示图标和名字”。这验证了本机该消息的接收与标记图标、纯怪物名称显示，不证明跨客户端、完整两行宏、战斗或大秘境效果，也不能据此认定其他插件的通报格式支持 `%f`。具体包摘要与安装校验见 [测试记录](../validation/TESTING.md)。

暴雪 [2026 年 3 月宏聊天公告](https://us.forums.blizzard.com/en/wow/t/macro-changes-now-live-target-markers-and-chat-messages/2261956/1)说明原生宏仍可发队伍、团队、团队警告消息，遭遇战期间另有组员位置和短时连续发送限制。原生宏可发送不等于 addon 可解析：`CHAT_MSG_PARTY` 等事件的正文可能受保护，发送与接收限制需分别看待。[ChatInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua)

本版的黄色名称是发言者当时的声明，不验证真实焦点、不区别同名怪物，也不在对方换焦点时自动更新。没有实现手动标记映射、姓名板反查或普通聊天自动发送。已有保存模板保持不变，“加入名称格式”只改草稿，用户保存后生效。

### SeUI 1.8.4 的现有焦点操作

另行只读核查本机 SeUI 1.8.4 的 `Focus/Core.lua`。`NS:GetMacroText(unit)` 将原生 `/focus`、可选 `/tm` 和 `/p` 依次拼为安全按钮的宏内容；喊话文字只清理换行并替换 `%mark`，不会删除或解释 `%f`。因此可将 SeUI 喊话设为 `我的焦点打断是 {rt%mark} %f`，接收模板对应 `我的焦点打断是 {rt%mark} %name`；原来的 SeUI 设置焦点操作同时触发声明，不需要另设通报操作。也支持 `PTW焦点：%f` / `PTW焦点：%name` 这一对，前缀不是协议保留字。

该版本仅在 `announceFocus` 开启且 `selectedMarker > 0` 时拼入喊话；`SaveAndApply` 在战斗中推迟更新安全按钮。`%mark` 来自面板所选标记，不查询目标实际标记，因此“不覆盖已有标记”可能导致标记声明与实际标记不同。接收器仍拒绝显式标记与名称前置标记冲突的消息。用户随后确认以上自定义格式联动成功，补充了本机实际使用证据；跨客户端、战斗与大秘境完整流程未确认，不能推广为任意插件事件发送路径均可展开 `%f`。开发工具没有修改 SeUI 源码或配置。

接收器按公开聊天正文及模板识别，不依赖发送插件名称。因此其他插件只要能发送包含实际焦点名称的可读组队聊天，也可配置对应模板；其发送端占位符须以具体实现为准。打断成功事件里的受击目标不等同于焦点，不能仅因为能捕获名称就将其视作焦点声明。

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
