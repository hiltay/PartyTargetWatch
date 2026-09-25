## 0.5.0 — Beta

- Removed all focus features after user-reported Mythic+ failure: the focus column, local focus reads, chat listeners and parsers, announcement cache, format editor and related settings entries.
- Retained current-target names, raid markers, opacity, scene filters, positioning, scale and preview. The minimap button keeps left-click settings access.
- Clear retired focus preferences on load while preserving other settings. The development installer backs up and removes the retired Communication.lua module during upgrades.
- 27 Lua scenarios and 7 delivery checks passed; 1 symbolic-link check was skipped for missing Windows privileges. This release has not been verified in-game. CurseForge materials remain prepared, not submitted or published.

## 0.5.0 — 测试版

- 根据用户大秘境测试失败反馈，移除焦点列、本机焦点读取、聊天监听与解析、通报缓存、自定义格式编辑器及相关设置入口。
- 保留当前目标名称、团队标记、透明度、场景筛选、位置、大小与预览；小地图按钮保留左键打开设置。
- 载入时清除退役焦点配置，保留其他设置；开发安装工具会先备份再清理旧 Communication.lua。
- 27 个 Lua 场景与 7 项交付检查通过，1 项因 Windows 符号链接权限跳过。本版未实机验证；CurseForge 资料仍为 prepared，未提交或发布。

以下为历史版本记录，其中已删除的功能不适用于 0.5.0。

---

## 0.4.3 — Beta

- Reduced incoming defaults to exactly `我打断%mark` and `我的焦点打断是 {rt%mark} %name`. New installs can receive the matching SeUI name-and-marker announcement without adding a template; other custom formats remain supported.
- These two defaults apply to new installs, invalid-configuration fallback and restoring built-in formats. Upgrades preserve saved custom or empty lists without automatic replacement.

This release changes defaults only. Offline checks are recorded in `validation/TESTING.md`; the minimap and native-settings entry points still await in-game verification. CurseForge materials remain prepared, not submitted or published.

## 0.4.3 — 测试版

- 默认接收格式仅保留 `我打断%mark` 和 `我的焦点打断是 {rt%mark} %name` 两条；新安装无需手加即可接收对应的 SeUI 名称与标记通报，其他格式仍可自定义。
- 新安装、无效配置回退和恢复内置格式使用这两条；升级保留已保存的自定义模板及空列表，不自动替换或覆盖。

本版仅调整默认格式。离线检查见 `validation/TESTING.md`；小地图按钮和原生设置入口仍待实机确认。CurseForge 资料仍为 prepared，尚未提交或发布。

---

## 0.4.2 — Beta

- Added a dependency-free minimap button: left-click settings and right-click incoming formats, compatible with the inspected local EUI collection rules.
- Added a native **Settings → AddOns → PartyTargetWatch 队友目标** category linking to the existing settings and format panels. These entries were absent because earlier versions had not created them, unrelated to game restrictions or CurseForge listing.
- Added `Integration.lua`, bringing the release to eight files. Minimap collection and the native settings category await an in-game reload check.

- Removed addon-to-addon focus synchronization, its setting, prefix registration, message send/receive paths, handshake, heartbeat and remote snapshots. The old focus protocol is no longer handled.
- Retained target monitoring, incoming public chat announcements and read-only display of the local player's public focus. PartyTargetWatch sends no normal chat.
- Kept two controls: **显示焦点 / 通报列** and **接收队友的焦点通报**. Disabled reception shows **未开启接收**; enabled reception without a record shows **等待通报**.
- Migration removes the old `shareFocus` field while preserving other switches, templates, position and opacity. Name/marker parsing, the five-minute expiry and `取消打断` remain unchanged.

Version 0.4.2 awaits in-game verification; current offline results are recorded in `validation/TESTING.md`. CurseForge materials remain prepared, not submitted or published. Synchronization described below belongs to historical versions only.

## 0.4.2 — 测试版

- 新增无需第三方库的小地图按钮：左键打开设置，右键编辑接收格式，符合已核查的本机 EUI 收纳规则。
- 新增原生“设置 → 插件 → PartyTargetWatch 队友目标”分类，打开现有设置与接收格式面板。旧版没有创建这些入口，与游戏限制或 CurseForge 收录无关。
- 新增 `Integration.lua`，发行包共 8 个文件；小地图收纳及原生设置入口待 `/reload` 后实机确认。

- 删除插件间焦点同步及其设置、前缀注册、消息发送/接收、握手、保活与远端缓存，不再处理旧焦点协议。
- 保留目标监控、公开聊天通报接收和本机公开焦点只读显示；本插件不发送普通聊天。
- 设置仅保留“显示焦点 / 通报列”和“接收队友的焦点通报”。关闭接收显示“未开启接收”，开启且无记录显示“等待通报”。
- 升级清除旧 `shareFocus` 字段，其他开关、模板、位置与透明度保留。名称/标记解析、5 分钟有效期和“取消打断”不变。

0.4.2 尚待实机确认，当前离线结果见 `validation/TESTING.md`。CurseForge 资料为 prepared，尚未提交或发布。下列同步说明仅为旧版历史记录。

---

## 0.4.1 — Beta

- Reorganized **焦点与通报** settings: show the focus/announcement column, receive teammates' announcements, then optional addon focus synchronization. Saved switch states are preserved.
- Renamed the template entry **接收格式…** and clarified the receiving workflow. Chat needs only the first two controls; senders do not need PartyTargetWatch. SeUI sends `%f`, while incoming templates capture `%name`.
- Renamed the main column **焦点 / 通报**, identified yellow text as the latest teammate announcement and added **等待通报** when receiving is enabled, synchronization is off and no record is available.
- Retained five-minute announcement records, the `取消打断` cancellation message and optional game-permitted synchronization. Changing focus requires a new announcement; chat parsing and the synchronization protocol are unchanged.

This release changes UI and explanations. Its new UI awaits an in-game reload check; 0.4.0 name/icon and SeUI workflow confirmations remain historical evidence. CurseForge materials remain prepared, not submitted or published.

## 0.4.1 — 测试版

- “焦点与通报”设置依次显示“显示焦点 / 通报列”“接收队友的焦点通报”“插件间焦点同步（可选）”，保留已有开关状态。
- 格式入口改为“接收格式…”，说明聊天方案只需前两项，发送方无需本插件；SeUI 发送端用 `%f`，接收模板用 `%name`。
- 主窗口列名改为“焦点 / 通报”，底部注明黄色内容是队友最近一次通报；接收开启、同步关闭且无记录时显示“等待通报”。
- 保留 5 分钟通报有效期、“取消打断”清除本人记录，以及游戏允许时的可选同步；换焦点需重新通报，聊天解析与同步协议不变。

本版调整界面与说明，新界面待 `/reload` 后实机确认；0.4.0 名称、图标及 SeUI 联动成功反馈保留为历史记录。CurseForge 资料为 prepared，尚未提交或发布。

---

## 0.4.0 — Beta

- Added `%name` capture for incoming public chat. Name-only and name-plus-marker declarations display the declared name in yellow; marker-only templates remain supported. A declaration is a snapshot, not verified current focus.
- Templates allow at most one `%name`, one `%mark` and two nonempty `%text` wildcards, with a name or marker required. Name-only templates need literal text, name/text wildcards cannot be adjacent, and cleaned names are limited to 96 bytes. Unexpanded `%f`/`%t`, secret messages and ambiguous captures are rejected.
- Leading `{rtN}` tokens in captured names become marker icons instead of leftover `rtN` text; conflicts with explicit `%mark` reject the message. This uses public chat text, not protected unit markers.
- Added the default `PTW焦点：%name` template while preserving saved user templates. **加入名称格式** appends it to the draft; **保存格式** applies it.
- Documented a manually pressed native macro: `/stopmacro [@focus,noexists]` followed by `/p PTW焦点：%f`. No addon-driven normal-chat sending, target-call button or key binding was restored.

76 Lua mock scenarios passed (39 UI, 37 communication); delivery: 7 passed, 1 skipped for Windows symbolic-link privilege. The user confirmed native `%f` expansion and initial addon name receipt/display. After the leading-marker correction, the user confirmed that both the icon and clean monster name display correctly. The complete two-line macro, cross-client delivery and combat/Mythic+ behavior remain unverified in game. CurseForge materials remain prepared, not submitted or published.

## 0.4.0 — 测试版

- 新增 `%name` 公开聊天名称捕获；名称声明及名称加标记声明显示黄色名称，只有标记的旧模板继续保留。声明是当时的记录，不验证当前真实焦点。
- 每条模板最多一个 `%name`、一个 `%mark` 和两个非空 `%text`，至少包含名称或标记。只有名称的模板需有固定文字，名称/通配文字不可相邻，清理后名称最多 96 字节；拒绝未展开 `%f`/`%t`、受保护消息和歧义。
- 名称前置 `{rtN}` 提取为标记图标，避免残留 `rtN` 文字；与显式 `%mark` 冲突时拒绝消息。只使用公开聊天文字，不读取受保护单位标记。
- 新增默认 `PTW焦点：%name`，保留用户已保存模板。“加入名称格式”只追加到草稿，“保存格式”后才生效。
- 提供玩家手动按下的原生宏：`/stopmacro [@focus,noexists]` 后接 `/p PTW焦点：%f`。不恢复插件主动普通聊天发送、通报按钮或快捷键。

76 个 Lua mock 通过（39 UI、37 通信）；交付检查 7 通过、1 因 Windows 符号链接权限跳过。用户已确认原生 `%f` 展开及首轮插件接收/显示名称；前置标记修正后，用户第二轮确认图标和纯怪物名称均正常显示。完整两行宏、跨客户端及战斗/大秘境效果仍待实机验证。CurseForge 资料为 prepared，尚未提交或发布。

---

## 0.3.1 — Beta

- Removed outgoing target calls and their button, member-row click action, commands, key binding and dedicated diagnostics. Protected names can be unavailable for composing chat even outside combat.
- Retained selected-target and raid-marker monitoring, customizable incoming chat declarations, background opacity and default-off public focus sharing. Declarations remain assignments rather than verified current focus.
- Removed `Bindings.xml` from the seven-file release. The local installer verifies a full backup before removing that retired file; other addons and SavedVariables are preserved.

64 Lua mock scenarios passed (36 UI, 28 communication); delivery checks: 7 passed, 1 skipped for Windows symbolic-link privilege. This release has not been validated in game. CurseForge materials remain prepared, not submitted or published.

## 0.3.1 — 测试版

- 删除主动目标通报及其按钮、成员行点击、命令、快捷键与专用诊断。目标名称受保护时，脱战也不保证可以拼接为聊天文字。
- 保留目标与标记监控、自定义聊天声明模板、背景不透明度和默认关闭的公开焦点共享。声明仍只是约定，不代表已验证的当前真实焦点。
- 发行包共 7 个文件，不再包含 `Bindings.xml`；本地安装器完整校验备份后移除该废弃文件，保留其他插件和 SavedVariables。

64 个 Lua mock 通过（36 UI、28 通信）；交付检查 7 通过、1 因 Windows 符号链接权限跳过。本版尚未实机验收。CurseForge 资料仍为 prepared，尚未提交或发布。

---

## 0.3.0 — Beta

- Added a multiline declaration-template editor through **通报格式…** in settings or `/ptw formats`, with local draft sample tests that send no messages. Saving applies templates, clears old declarations and persists configuration.
- Supports up to 20 templates, 255 bytes each and 8192 bytes total input. Each requires one `%mark` and permits up to two nonempty `%text` wildcards; all other text is literal. Full-message matching follows template order and rejects unknown placeholders or ambiguous marker matches within a template.
- Defaults: `我打断%mark` and `我的焦点打断是 {rt%mark}`. Blank lines are ignored; saving an empty list stops new records, while the fixed cancellation phrase still works.
- Added background-only opacity from 0 to 1, default 0.88. Text and icons remain visible at zero.
- Added specific chat/target/member restriction messages and `/ptw status` for local public diagnostics without real names or outgoing messages.
- Fixed brief false chat blocks from unrelated restriction events. Actual game restrictions remain; follower-dungeon calls are not claimed universally fixed.

69 Lua mock scenarios passed (37 UI, 32 communication); delivery checks: 7 passed, 1 skipped for Windows symbolic-link privilege. New features have not been loaded and validated in game. Updating installed files is not live verification. CurseForge materials remain prepared, not submitted or published.

## 0.3.0 — 测试版

- 新增多行声明模板编辑器：设置中的“通报格式…”或 `/ptw formats`；草稿样本测试不发送消息，保存才生效、清空旧声明并持久化。
- 最多 20 条、每条 255 字节、总输入 8192 字节；恰好一个 `%mark`，最多两个非空 `%text`，其余字面整句匹配。按有效模板顺序识别，拒绝未知占位符和单模板内的标记歧义。
- 默认 `我打断%mark` 与 `我的焦点打断是 {rt%mark}`；忽略空白行，保存空列表停止新记录，固定取消语句仍有效。
- 新增背景不透明度 `0`–`1`，默认 `0.88`；仅影响背景、边框与行底色，不影响文字和图标。
- 细分聊天锁定、目标/成员信息受保护提示，新增 `/ptw status` 本地公开诊断，不输出真实名称或发送消息。
- 修复无关限制事件造成的短暂聊天误拦截；保留游戏真实限制，不宣称解决所有追随者通报问题。

69 个 Lua mock 通过（37 UI、32 通信）；交付检查 7 通过、1 因 Windows 符号链接权限跳过。新增功能尚未在游戏中加载验证，更新安装文件不等于实机通过。CurseForge 资料仍为 prepared，尚未提交或发布。

---

## 0.2.0 — Beta (historical)

- Added target raid markers and per-scene visibility controls.
- Added manual target calls through a button, member rows, `/ptw announce`, and a user-assigned key binding; calls are throttled and require public data and a group.
- Added three independent, default-off controls: focus column, optional focus sharing, and chat declaration recording.
- Added roster-validated public focus snapshots with a 12-second expiry and explicit unavailable/restricted/disabled states.
- Added strict Chinese interrupt declarations for eight raid markers, a cancellation phrase, and a 300-second expiry. Declared assignments are clearly labeled; readable automatic focus has priority.
- Added separate communication/settings modules and `Bindings.xml` to the release package. Secret values are never transmitted; no external service bypass is provided.

Version 0.2.0 has passed offline mock and delivery checks only. Its new features have not been live-tested. Version 0.1.0's historical solo checks do not validate this version; group/raid play, combat restrictions, cross-client delivery and in-game persistence remain unverified.

---

## 0.2.0 — 测试版（历史）

- 新增目标团队标记和按场景显示筛选。
- 新增按钮、成员行、`/ptw announce` 及用户自行绑定按键的手动目标通报；需组队、公开可读信息并受节流限制。
- 新增默认关闭且独立的焦点列、焦点共享、聊天声明记录三个开关。
- 共享仅采用当前组员的公开焦点快照，12 秒过期，明确区分不可用、受限和关闭状态。
- 严格识别八种标记的中文打断声明与取消消息，300 秒过期，标注为“约定”；可读自动焦点优先。
- 发行包新增独立通信/设置模块与 `Bindings.xml`；不传输秘密值，不提供外部服务绕过。

本版仅完成离线 mock 与交付检查，新增功能未实机验证。0.1.0 的历史单人实测不代表本版通过；小队/团本、战斗限制、跨客户端送达与游戏内持久化仍待验证。
