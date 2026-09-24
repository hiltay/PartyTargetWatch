# 测试记录

## 环境与范围

- 开发目标：国服正式服 12.1.0；本机客户端安装信息为 12.1.0.69933。
- 本地 Lua 语法和行为测试使用 Lua 5.1（Python Lupa 2.6 的 lua51 运行时）。
- 插件完全独立，仅使用暴雪 API 和界面模板，无第三方运行库。
- 不读取或改写其他插件的 SavedVariables，不注册全局界面钩子，不修改按键、图形设置、分辨率、UIParent 缩放。
- 用户报告游戏底部显示异常后，已暂停 Computer Use 的游戏操作。插件的游戏内实际运行尚未验证；模拟测试不能证明游戏引擎的受限值和渲染行为。

## 2026-09-25 本地验证结果

- Lua 5.1 语法检查通过，10 个行为场景全部通过：初始化隔离、单人显示、小队目标切换和清空、事件缺失时轮询、离线与 API 失败、40 人双列与退队、示例模式退出、隐藏与重显、位置与缩放持久化、错误配置恢复、名称透传及设置面板操作（部分场景包含多项断言）。
- 交付工具的 7 项测试中 6 项通过；1 项因当前 Windows 无创建符号链接权限跳过。已验证首次安装、更新前备份、其他插件和 SavedVariables 保持、错误目标路径拒绝、硬链接拒绝、TOC 越界/缺漏检查、ZIP 结构和确定性。
- 已安装独立 PartyTargetWatch 目录。真实安装前后，7,203 个其他插件文件的路径清单和 SHA256 一致。详细本机路径与清单保存在被 Git 忽略的 `validation/local-install.json` 中。
- 没有进行游戏内重载、组队和战斗测试，不能将上述模拟测试称为实机验证。公开发布前请完成下方验收。

## API 依据

- [暴雪 Unit API 生成文档镜像](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)：使用已知的队伍单位 token 查询名称，不使用名称或 GUID 进行排序、拼接或建立索引。
- [暴雪 FontString API 生成文档镜像](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua)：`SetText` 可接收受限名称用于展示。本地模拟测试只验证不处理名称的代码路径，不能仿真客户端的完整受限值机制。

## 游戏内验收步骤

1. 启用 PartyTargetWatch 后登录游戏；若新增插件未被识别，退出客户端后重新打开。
2. 单人时应直接看到“队友目标”窗口；选中与清空目标，检查自己的那一行。
3. 组队后请另一名队员切换目标、清空目标，确认对应行随游戏 API 提供的数据变化；检查队员离线、入队、退队。
4. 在战斗中检查名称是否仍能显示，并查看是否产生 PartyTargetWatch 的 Lua 错误。
5. 点击“设置”，调整整体大小和 X/Y 偏移；测试拖动标题、锁定、隐藏、显示、窗口居中。
6. 点击预览应明显标注“示例预览”；结束预览后必须恢复真实单位数据。
7. 执行 `/reload`，检查位置、大小、锁定和隐藏设置保存，示例预览默认结束。
8. 如用于团队，检查 21–40 名成员的双列布局。

范围说明：“当前选中的目标”不等于正在攻击的目标。目标单位不可见、超出客户端可用范围，或游戏限制 API 时，插件不能凭空恢复目标信息。
