# PartyTargetWatch · 队友目标

独立的《魔兽世界》正式服插件，用可移动窗口显示自己及小队、团队成员**当前选中的目标**。界面与命令提示为简体中文。

当前版本：`0.5.0`，面向正式服 `12.1.0`，TOC 接口版本 `120100`。根据大秘境实测反馈，本版移除全部焦点和聊天通报功能，专注当前目标监控。

## 功能

- 每行显示“成员 → 当前目标”及目标的团队标记；离线成员显示“离线”。
- 单人显示自己，小队最多 5 人，团队最多 40 人；超过 20 人时分两列。
- 可见窗口大约每 0.2 秒刷新；隐藏时停止目标刷新。
- 拖动标题调整位置，支持锁定、显示/隐藏、居中和恢复默认。
- 整体大小可调为 60%–200%，可输入 X/Y 位置偏移。
- 背景不透明度可设为 0–1，默认 0.88；0 为全透明，文字和图标保持可见。
- 按野外、休息区、地下城（含大秘境）、团队副本、场景战役、战场和竞技场选择显示。
- 示例预览显示 5 行数据，方便调整布局；预览忽略场景筛选，不保存为实时数据。
- 窗口位置、大小、锁定、透明度与场景设置保存在 `PartyTargetWatchDB`。

窗口展示游戏 API 允许显示的目标信息。“无目标 / 不可见”可能表示没有选择目标，也可能表示暂时无法查询。选中目标本身不能证明成员正在攻击、治疗或施法。插件不自动选取目标或执行战斗操作。

## 设置入口与命令

小地图按钮左键打开设置；也可从 `Esc → 选项/设置 → 插件 → PartyTargetWatch 队友目标` 点击“打开设置”。按钮允许 EUI 等小地图收纳插件调整其父级和布局，实机收纳效果仍待验证。

| 命令 | 用途 |
| --- | --- |
| `/ptw settings` 或 `/ptw config` | 打开设置 |
| `/ptw` 或 `/ptw show` | 显示实时监控 |
| `/ptw hide` | 隐藏窗口 |
| `/ptw unlock` / `/ptw lock` | 解锁拖动 / 锁定 |
| `/ptw test` | 开关示例预览 |
| `/ptw scale 1` | 设置大小，范围 0.6–2 |
| `/ptw reset` | 恢复默认设置 |
| `/ptw help` | 查看命令 |

## 安装与升级

1. 下载或生成 `PartyTargetWatch-0.5.0.zip`。
2. 将 ZIP 内的 `PartyTargetWatch` 文件夹放入正式服的 `Interface/AddOns`，确保 `PartyTargetWatch.toc` 位于该文件夹内。
3. 升级时先将旧 `PartyTargetWatch` 文件夹备份到 AddOns 外，再放入新文件夹，避免旧模块残留。只替换本插件目录，不删除 `WTF`。
4. 在游戏中启用插件并重载界面；若客户端尚未发现新安装的插件，重新启动游戏。

0.5.0 不再包含 `Communication.lua` 或 `Bindings.xml`，不再提供焦点列、聊天接收、格式编辑器或 `/ptw formats`。首次载入会清除旧 `shareFocus`、`showFocus`、`acceptFocusCalls`、`declarationFormats`，保留其他设置。

## 开发与验证

```text
python -m pip install -r requirements-dev.txt
python tests/run_tests.py
python -m unittest discover -s tests -p test_delivery.py -v
python tools/package.py
```

发行包只包含插件运行文件和 README、LICENSE、CHANGELOG，不包含测试、备份或本地验证报告。开发安装工具 `tools/install.py --addons-dir <正式服 Interface/AddOns 路径>` 会先备份已有安装，再更新文件并清理已退役模块。

验证记录见 [validation/TESTING.md](validation/TESTING.md)。离线测试通过不等同于实际游戏、大秘境或界面渲染已经验证。CurseForge 资料仍处于准备状态，尚未提交或发布。

源码：[GitHub](https://github.com/hiltay/PartyTargetWatch) · 问题反馈：[Issues](https://github.com/hiltay/PartyTargetWatch/issues) · 许可证：MIT。
