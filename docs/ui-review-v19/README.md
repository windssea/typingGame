# 原生特效验证记录

- `regression-tests.json`：18 套原有回归，30,886 项通过。
- `v19-engine-tests-final.log`：13 个玩法原生节点、事件、暂停和减少动态，148 项通过。
- `v19-render-tests-final.log` / `v19-render-validation.json`：真实渲染器 12 项像素断言通过。气球、城堡、潜艇的单词区域变化像素均为 0；外围冲击波和背景局部光照均有可测像素变化。
- `v19-performance-after.json`：AMD Ryzen AI 9 HX 370 / Radeon 890M、1280×800、Compatibility。本轮额外每 15 帧触发重击；13 玩法帧耗时 P95 为 9.295–13.658 ms，纹理峰值约 246.2 MiB。此数据不是所有设备的性能承诺，也不是与 1.8 完全同负载的对比。
- `v19-*-native-fx.png`：原生特效压力夹具截图，包含人为密集触发的反馈，不代表普通游玩总是显示这么多粒子。
- `public-*.jpg` / `public-validation.json`：生产域名 `typing.nanokid.win`，独立 QA 存档，使用真实键盘和鼠标。流星 1 次物理发射与命中；城堡建塔、开波、命中和塔位粒子；气球爆破；潜艇 3 次鱼雷命中与 F3 技能。浏览器控制台未发现错误或警告，暂停后原生反馈时钟保持不变。

复现原生检查：

```powershell
godot --headless --path . --script tests/engine_vfx_tests.gd
godot --path . --script tests/engine_vfx_tests.gd -- --ui-capture
godot --path . --script tests/vfx_render_tests.gd
godot --path . --script tests/art_runtime_profile.gd -- --after --v19
```

截图和性能采样需要真实渲染器。采样期间应保持 Godot 窗口不失焦，不同时运行其他原生截图任务。
