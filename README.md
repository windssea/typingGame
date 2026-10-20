# 指尖挑战

Godot 2D 打字学习与挑战游戏，当前版本 1.7。中文引导，英文键盘训练，面向实体键盘与桌面浏览器。

**在线游玩：[打开指尖挑战](https://typing.nanokid.win)**（[备用地址](https://typinggame-cl5.pages.dev)）。Pages 已发布，WASM/PCK 由 R2 提供；存档保存在当前浏览器。

**本机运行：** 运行 `tools/export-web.ps1` 与 `tools/serve-web.ps1`，访问 [Godot 网页可玩版](http://127.0.0.1:8765/build/web/index.html)。这是实际执行游戏规则的 Godot/Wasm 程序，支持十种玩法、真实输入、胜负结算和浏览器存档。完整入口与操作见 [可玩版说明](docs/PLAYABLE_WEB.md)。

主入口只保留 **打字训练 / 打字挑战**。首页直接进入推荐训练，训练每六次命中给予阶段奖励；任务牌说明胜负条件，完整输入目标留在场景中，底部只保留下一键、手指、词义与技能。五款动作任务用 F3 释放实际改变战局的能力，包含减速、补盾、干扰赛车与格挡。设计与机制见 [0.8 学习与行动](docs/ADVENTURE_V08.md)。

地鼠、UFO驾驶员、玩家赛车、哥布林、疾行兽、盾卫、萨满、爆破兵与 Boss 已接入本机 Grok Build 生成的动作；保留拳手与守卫动画。每个场景只载入当前所需动作，暂停冻结，减少动态显示固定帧。详细来源、运行片段与边界见 [动画生产流程](docs/design-v2/ANIMATION_PIPELINE.md)。

1.0 重整大厅、课程、任务卡、HUD 与结算，删除重复小字，把完整规则收进 F1；增加原创分层音乐、逐键与分模式音效及独立音量设置。实际变化和验收边界见 [1.0 复核记录](docs/PRODUCT_REVIEW_V10.md)。

1.1 放大完整输入词与下一键，词牌统一避让角色与其他词牌，保持在特效上方；26组高清原生动画、Image Gen新教练与Grok真实动作、分模式粒子、微动背景及线条清理见 [1.1 更新](docs/POLISH_V11.md)。

1.2 将白色网页式卡片改为场景入口和彩色训练牌，设置页使用训练营背景与动画教练；以容器重排顶部、课程、任务和对话框，修复按钮伸展、输入栏裁切与嵌套帮助焦点，详见 [1.2 游戏 UI](docs/GAME_UI_V12.md)。

1.3 将基础训练改为可玩的“星桥快跑”：正确输入修桥、机器人跑跳过桥、点亮三座星灯；移除重复底栏与常驻指法面板，放大所有玩法的输入目标，详见 [1.3 学习与场景互动](docs/BRIDGE_ADVENTURE_V13.md)。

1.4 完整审阅26个页面与状态，接入生成的彩绘面板和暖金按钮，统一交互状态；扩展游戏场景，移除常驻指法侧栏与重复词牌，重排城堡指挥操作。逐页问题、实际截图、检查结果与边界见 [1.4 UI审阅](docs/UI_AUDIT_V14.md)。

1.5 分级优化十种玩法的反馈：轻击收敛、重击强调；拳击接触与回弹、落桥压缩、气球破裂缓出、较温和的错误音和连击音高。减少动态时取消震屏与移动粒子；原始输入与游戏计时不因演出暂停。详见 [1.5 手感记录](docs/GAME_FEEL_V15.md)。

1.6 为拳手、外星飞船与城堡敌人加入可读的行动状态：蓄力破招、格挡反击、俯冲拦截、治疗打断、拆弹与侧翼进攻。动作预警直接放在角色旁，F1 收纳完整规则。机制、验证和边界见 [1.6 敌人行动](docs/ENEMY_TACTICS_V16.md)。

1.7 审查十种玩法素材，内置Image Gen新增三种防御塔、独立主堡、基座与战场底图；修正接地和前后遮挡、让法术从实际塔头发出，取消极速训练的大覆盖面板并将输入接入场内跑道。素材、完整提示词、实机截图及性能边界见 [1.7 美术精修](docs/ART_POLISH_V17.md)。

709 个核心训练词、24 个生活主题、48 条原创短句已接入十种任务；逐键充能、动作与文字提示同步。详细范围、素材来源与边界见 [0.9 更新](docs/POLISH_V09.md)。

## 先阅读

- [本机 Grok Build 动画流程与已生成守卫样片](docs/design-v2/ANIMATION_PIPELINE.md)：Godot打开 `scenes/animation_preview.tscn` 按F6；Space暂停，R减少动态。

- [完整游戏设计：课程、小游戏规划、技术框架与路线图](docs/GAME_DESIGN.md)
- [城堡模式：操作、敌人、Boss、建塔与升级](docs/CASTLE_MODE.md)
- [新小游戏与指法教练：玩法、规则、教学入口](docs/ARCADE_AND_FINGERS.md)
- [验证记录与已知限制](docs/VALIDATION.md)

## 当前可玩

产品入口分为两条：**打字训练 → 推荐短任务 / 选择课程任务 → 掌握后继续下一课**，以及 **打字挑战 → 选难度与任务 → 按明确条件取胜**。基础课程先练 F/J，再练少量键位和连续按键组合，第 6 课开始真正的单词输入；每种任务对接当前课程内容。首页Enter直接进入推荐任务，课程页可选择其他训练场景。

1. 指尖发射站：无压力完成 18 个目标，显示键位提示。
2. 泡泡啵啵乐：四个可选目标，不限时，点亮 18 个泡泡。
3. 流星拦截队：守住 90 秒，漏掉 5 个目标失败。
4. 极速 60 秒：60 秒连续目标，挑战速度与准确率。
5. 魔法城堡战：六波战役、五类普通怪、两场 Boss、三类元素塔、三级塔升级、城堡强化与修复、输入充能、技能特效和可关闭音效。
6. 气球蹦蹦节：输入击破上升气球，按紧急程度选择目标。
7. 星际闪电战：激光迎击外星舰，三连击恢复护盾。
8. 地鼠敲敲乐：六洞随机探头，输入挥锤命中；训练漏掉不扣血。
9. 疾速拉力赛：输入推进，三连击增加推进距离；挑战抢先冲线。
10. 连击小拳王：输入重拳打断对手蓄力，四次命中击倒一位对手。

支持 10 节课程、10 款小游戏、8 种挑战、训练/挑战成绩隔离、五档训练速度与三档挑战难度、本地存档、易错键与 JSON 备份导入导出。课程页提供「先学手指摆放」；游戏内有虚拟键盘、手型和当前手指提示，涵盖 Shift/空格/标点。城堡通过「指法图示」暂停查看。不提供玩法图鉴或第三条合集入口；无强制课程锁定。

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
