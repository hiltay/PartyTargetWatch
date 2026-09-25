## 0.4.0 — Beta

- Added `%name` capture for incoming public chat. Name-only and name-plus-marker declarations display the declared name in yellow; marker-only templates remain supported. A declaration is a snapshot, not verified current focus.
- Templates allow at most one `%name`, one `%mark` and two nonempty `%text` wildcards, with a name or marker required. Name-only templates need literal text, name/text wildcards cannot be adjacent, and cleaned names are limited to 96 bytes. Unexpanded `%f`/`%t`, secret messages and ambiguous captures are rejected.
- Leading `{rtN}` tokens in captured names become marker icons instead of leftover `rtN` text; conflicts with explicit `%mark` reject the message. This uses public chat text, not protected unit markers.
- Added the default `PTW焦点：%name` template while preserving saved user templates. **加入名称格式** appends it to the draft; **保存格式** applies it.
- Documented a manually pressed native macro: `/stopmacro [@focus,noexists]` followed by `/p PTW焦点：%f`. No addon-driven normal-chat sending, target-call button or key binding was restored.

76 Lua mock scenarios passed (39 UI, 37 communication); delivery: 7 passed, 1 skipped for Windows symbolic-link privilege. The user confirmed native `%f` expansion and initial addon name receipt/display. The subsequent leading-marker correction, complete two-line macro, cross-client delivery and combat/Mythic+ behavior remain unverified in game. CurseForge materials remain prepared, not submitted or published.

## 0.4.0 — 测试版

- 新增 `%name` 公开聊天名称捕获；名称声明及名称加标记声明显示黄色名称，只有标记的旧模板继续保留。声明是当时的记录，不验证当前真实焦点。
- 每条模板最多一个 `%name`、一个 `%mark` 和两个非空 `%text`，至少包含名称或标记。只有名称的模板需有固定文字，名称/通配文字不可相邻，清理后名称最多 96 字节；拒绝未展开 `%f`/`%t`、受保护消息和歧义。
- 名称前置 `{rtN}` 提取为标记图标，避免残留 `rtN` 文字；与显式 `%mark` 冲突时拒绝消息。只使用公开聊天文字，不读取受保护单位标记。
- 新增默认 `PTW焦点：%name`，保留用户已保存模板。“加入名称格式”只追加到草稿，“保存格式”后才生效。
- 提供玩家手动按下的原生宏：`/stopmacro [@focus,noexists]` 后接 `/p PTW焦点：%f`。不恢复插件主动普通聊天发送、通报按钮或快捷键。

76 个 Lua mock 通过（39 UI、37 通信）；交付检查 7 通过、1 因 Windows 符号链接权限跳过。用户已确认原生 `%f` 展开及首轮插件接收/显示名称；前置标记修正、完整两行宏、跨客户端及战斗/大秘境效果仍待实机验证。CurseForge 资料为 prepared，尚未提交或发布。

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
