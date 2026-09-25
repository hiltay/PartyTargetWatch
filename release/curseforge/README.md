# CurseForge 发布资料

这些文件用于准备 PartyTargetWatch 0.4.1 的 CurseForge 项目页与版本说明。

**当前状态：资料已准备，尚未提交到 CurseForge；没有已发布或已审核通过的项目链接。** 本目录不属于插件运行文件，也不进入现有发行 ZIP。

## 文件对应

| 文件 | 用途 |
| --- | --- |
| `summary.txt` | 英文一句话简介 |
| `description.md` | 项目详细说明；英文在前，简体中文在后 |
| `changelog.md` | 0.4.1 更新说明；英文在前，简体中文在后；保留 0.4.0 及更早历史 |
| `metadata.json` | 填写项目及版本字段时使用的事实清单 |
| `icon.png` | 主上传图标，精确 400×400 PNG |
| `icon-512.png` | 保留的 512×512 PNG 图标版本 |
| `icon.svg` | 可编辑的原创矢量图标源文件 |

图标使用原创的队员、箭头和目标几何符号，采用项目的 MIT 许可证，不含魔兽世界、CurseForge 或其他插件的图案。

## 人工提交步骤

1. 登录 [CurseForge 作者后台](https://authors.curseforge.com/)，创建 World of Warcraft 插件项目，名称填写 `PartyTargetWatch`。
2. 将 `summary.txt` 填入简介，将 `description.md` 填入详细说明。确认预览中英文位于中文之前，段落、命令和链接显示正常。
3. 上传 `icon.png` 作为项目图标，许可证选择 MIT；源码链接使用 `https://github.com/hiltay/PartyTargetWatch`，问题反馈链接使用 `https://github.com/hiltay/PartyTargetWatch/issues`。其他必填字段按当前后台要求填写。
4. 上传相对本目录的 `../../dist/PartyTargetWatch-0.4.1.zip` 作为版本文件，选择 Retail、游戏版本 `12.1.0`，版本类型选择 **Beta**，更新说明使用 `changelog.md`。
5. 提交前核对预览与字段：游戏内 UI 为简体中文；0.4.1 整理焦点与通报设置和说明，新界面仍待 `/reload` 后实机确认，当前离线检查以 `validation/TESTING.md` 为准。0.4.0 历史结果为 76 个 Lua mock 通过（39 UI、37 通信）及交付测试 7 通过、1 跳过，并有本机名称、图标和 SeUI 联动成功反馈。跨客户端与战斗/M+效果未验证。ZIP 应包含 7 个文件且没有 `Bindings.xml`。
6. 如表单要求接受作者条款，请由账号持有人自行审阅后决定是否同意。
7. 提交后以后台显示的实际状态为准，记录项目链接与审核结果；若显示“待审核”，只记录已提交待审核，不标记为已公开发布。

上传的是发行 ZIP。源码、测试依赖、本地安装报告、备份及此发布资料目录不应代替发行 ZIP 上传为插件版本文件。
