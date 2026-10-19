# 五世界视觉与交互设计 v2 · 交付入口

2026-10-19。本目录是阅读四份输入文档后的设计重定义，状态为可评审基线。

当前默认外观为 **v2.1 轻松浅色方案**：已按用户反馈减轻边框、阴影与按钮厚度，改用浅天蓝、暖白和柔和主题色。参见[界面减重说明](UI_LIGHTENING.md)。

## 直接体验

**现在可以直接打开 [Godot 可玩游戏](http://127.0.0.1:8765/build/web/index.html)。** 先运行项目根目录的 `tools/serve-web.ps1`；构建与真实玩法见 [0.6 网页可玩版](../PLAYABLE_WEB.md)。下文只描述设计演示。

双击 `index.html`，无需安装依赖或联网。界面支持方向键、Tab/Shift+Tab、Enter与Esc；游戏中F1指法、F2音效状态示例；城堡准备中1–4、Q/W/E、U、A/S/D、R、N均可试用。

世界大厅 → 继续本课 → 玩法 → 开局 → 键入 → 暂停/指法 → 结算。底部“设计组件”可对照五皮肤和六状态。原型的战斗、成绩、金币为演示，不是Godot游戏导出，也不改正式游戏存档。

## 阅读顺序

1. [完整设计系统](DESIGN_SYSTEM.md)：输入解读、品牌、母风格、五世界、十玩法、UI、材质、光影与动效。
2. [交互规范](INTERACTION_SPEC.md)：页面、焦点、键盘上下文、教学、存档和异常状态。
3. [生产迁移计划](PRODUCTION_PLAN.md)：旧资产审计、五套最小基准包、切片、技术约定、Godot结构与验收。
4. [项目解析Tokens](tokens.resolved.json)：继承输入JSON，单独记录本项目覆盖；没有修改输入文件。
5. [验收记录](VALIDATION.md)：自动检查与人工看图范围。
6. [Grok动画生产流程](ANIMATION_PIPELINE.md)：本机调用、十玩法动作清单、首个守卫样片与Godot预览。

美术样张保存在 `../../assets/design-v2/`，内置 Image Gen 生成，完整提示词及来源记录在该目录 `provenance.json`。两张均为概念样张，未标为生产就绪的逐帧角色或图集。

## 维护

修改源Tokens后，运行 `tools/design-v2/resolve_tokens.py` 更新解析JSON、对比度报告和无网络预览用的 `tokens.js`。原型不通过fetch读取本地文件，因此file协议也能打开。

原型行为验证工具：`tools/design-v2/check_prototype.cjs`；使用本机独立无头Edge环境，不连接用户浏览器配置。截图与机器报告输出到 `build/design-v2/`。该脚本的Node依赖路径为当前工作站配置，换设备需调整路径。
