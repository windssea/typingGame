# 键境 · Keybound

Godot 2D 打字训练游戏集合，当前版本 0.7。中文引导，英文键盘训练，面向实体键盘与桌面浏览器。

**在线游玩：[打开键境](https://typinggame-cl5.pages.dev)**。Pages 已发布，WASM/PCK 由 R2 提供；存档保存在当前浏览器。

**本机运行：** 运行 `tools/export-web.ps1` 与 `tools/serve-web.ps1`，访问 [Godot 网页可玩版](http://127.0.0.1:8765/build/web/index.html)。这是实际执行游戏规则的 Godot/Wasm 程序，支持十种玩法、真实输入、胜负结算和浏览器存档。完整入口与操作见 [可玩版说明](docs/PLAYABLE_WEB.md)。

五世界大厅已接入游戏，气球、外星舰、地鼠、赛车、格斗和城堡使用独立角色贴图。城堡包含六类敌人、三种元素塔及本机 Grok 生成的守卫待机动画；格斗已接入两位拳手的待机与出拳。Heroic Toy-Stylized 的完整视觉和场景动画仍在逐步迁移，未宣称所有角色动作已制作完成。旧设计地址通过 HTTP 打开时会进入本机可玩版；保留 `?design=1` 可查看归档原型。

0.4 将全套界面更新为面向儿童的明亮游乐园风格：浅色背景、彩色圆角卡片、F/J 键帽小伙伴、统一浅色指法教练，以及晴空、花园、淡紫太空和阳光森林等游戏配色。主题定义在 `scripts/play_theme.gd`，插画在 `scripts/playful_art.gd`。

0.7 增加五档训练速度、三档挑战、原生 24 fps 拳手动画、分层粒子和新 HUD，支持减少动态效果。见 [动效与难度](docs/MOTION_AND_DIFFICULTY.md)、[Cloudflare 发布与更新](docs/CLOUDFLARE_DEPLOY.md)。

## 先阅读

- [本机 Grok Build 动画流程与已生成守卫样片](docs/design-v2/ANIMATION_PIPELINE.md)：Godot打开 `scenes/animation_preview.tscn` 按F6；Space暂停，R减少动态。

- [完整游戏设计：课程、小游戏规划、技术框架与路线图](docs/GAME_DESIGN.md)
- [城堡模式：操作、敌人、Boss、建塔与升级](docs/CASTLE_MODE.md)
- [新小游戏与指法教练：玩法、规则、教学入口](docs/ARCADE_AND_FINGERS.md)
- [验证记录与已知限制](docs/VALIDATION.md)

## 当前可玩

产品入口分为两条：**打字训练 → 选课程 → 选小游戏**，以及 **打字挑战 → 选挑战玩法**。基础课程先练 F/J，再练少量键位和连续按键组合，第 6 课开始真正的单词输入；每种玩法都可对接课程内容。

1. 星火练习场：无压力完成 18 个目标，显示键位提示。
2. 字母泡泡：四个可选目标，不限时，点亮 18 个泡泡。
3. 字母陨落：守住 90 秒，漏掉 5 个目标失败。
4. 一分钟冲刺：60 秒连续目标，挑战速度与准确率。
5. 守护键之城：六波战役、五类普通怪、两场 Boss、三类元素塔、三级塔升级、城堡强化与修复、输入充能、技能特效和可关闭音效。
6. 气球猎手：输入击破上升气球，按紧急程度选择目标。
7. 外星攻防战：激光迎击外星舰，三连击恢复护盾。
8. 打字打地鼠：六洞随机探头，输入挥锤命中；训练漏掉不扣血。
9. 键盘拉力赛：输入推进，三连击增加推进距离；挑战抢先冲线。
10. 指尖格斗馆：输入重拳打断对手蓄力，四次命中击倒一位对手。

支持 10 节课程、10 款小游戏、8 种挑战、训练/挑战成绩隔离、五档训练速度与三档挑战难度、本地存档、易错键与 JSON 备份导入导出。课程页新增「先学手指摆放」；游戏内有虚拟键盘、手型和当前手指提示，涵盖 Shift/空格/标点。城堡通过「指法图示」暂停查看。其余图鉴玩法仍为规划；无强制课程锁定。

## 启动

使用 `D:\dev\windssea\game\godot4.7.2\Godot_v4.7.2-stable_win64.exe` 打开本目录 `project.godot`，按 F6/F5 运行。也可在 PowerShell 执行：

```powershell
.\tools\run.ps1
.\tools\run.ps1 -Editor
```

切换到英文输入法。输入目标文本自动施法，退格撤回一位，Tab 放弃当前锁定，Esc 暂停。窗口失焦自动暂停。课程页可以切换课程与节奏。城堡首先进入建设阶段，选择基座和塔型后，点击「开始第 1 波」；建设、升级和修复均在波间进行。

当前项目已复制并启用现有 Godot AI 4.3.0 插件，编辑器打开后可以通过 MCP 操作。`tools/enable-mcp.ps1` 可从原安装位置恢复缺失的插件。插件按其自带 LICENSE 分发，导出时剥离调试 helper；不要将开发用 MCP 服务暴露到公网。

## 验证

```powershell
& 'D:\dev\windssea\game\godot4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --editor --import --quit
& 'D:\dev\windssea\game\godot4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_runner.gd
& 'D:\dev\windssea\game\godot4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/castle_tests.gd
& 'D:\dev\windssea\game\godot4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/arcade_tests.gd
& 'D:\dev\windssea\game\godot4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . --script tests/ui_smoke.gd -- --ui-capture
& 'D:\dev\windssea\game\godot4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . --script tests/arcade_ui.gd -- --ui-capture
```

## 网页导出

先安装与引擎完全匹配的导出模板，再运行：

```powershell
.\tools\export-web.ps1
.\tools\serve-web.ps1
```

本机已安装匹配的 4.7.2 Web 导出模板，并实际导出、运行和测试浏览器版本。缺模板时，可运行 `tools/install-web-templates.py` 安装官方包内 Web 文件。将 `build/web/` 完整上传到静态站点，通过 HTTP(S) 访问；预设使用 Compatibility 与单线程。公网入口为 <https://typinggame-cl5.pages.dev>。Cloudflare 采用 Pages 页面壳 + R2 版本化大文件，见 [部署说明](docs/CLOUDFLARE_DEPLOY.md)。

## 存档

桌面：Godot `user://profile.json`，通常位于 `%APPDATA%\Godot\app_userdata\键境 · Keybound\`。网页：当前站点的浏览器存储。学习档案页面可导出 JSON，并粘贴 JSON 恢复。当前保存课程/成绩/偏好，不恢复半局战斗，不含跨设备云同步。

## 字体与素材

字体源为 Google Fonts Noto Sans SC，SIL Open Font License，见 `assets/OFL-NotoSansSC.txt`。`assets/ui-font.ttf` 为 UI 字符子集。新增中文 UI 文案后运行 `tools/subset_font.py` 重建（需 Python `fonttools` 和原始字体）。实际游戏组合 Image Gen 背景/角色/塔贴图与程序绘制技能特效；生成提示词和来源记录在素材旁的 provenance JSON 及 manifest 中。六种原创音效由 `tools/generate_audio.py` 生成。
