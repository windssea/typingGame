# Cloudflare Pages + R2 发布

线上入口：<https://typinggame-cl5.pages.dev>。Pages 项目名为 `typinggame`，实际分配域名为 `typinggame-cl5.pages.dev`。2026-10-19 已完成实际发布和公网浏览器启动验证。

## 资源分工

Pages 保存 HTML、Godot JavaScript、图标和音频 worklet。R2 的 `typinggame-assets` 桶保存带内容哈希的 WASM 和 PCK；只上传可公开的游戏构建产物。源代码、开发插件、存档和凭据不上传到桶。

原始 WASM 39,514,754 字节，gzip 后 10,054,758 字节；PCK 32,568,536 字节，gzip 后 32,313,589 字节。R2 对象分别设置 `application/wasm` / `application/octet-stream`、`Content-Encoding: gzip` 和一年 immutable 缓存。哈希以解压后的实际内容计算。

页面中的 fetch 适配只将 `index.wasm` 与 `index.pck` 指向 R2，保留 Godot 本地虚拟文件名及同源 worklet 路径。R2 CORS 允许正式 Pages 域名与本机 8765 端口，GET/HEAD 请求；浏览器不会向 R2 发送凭据。

## 后续更新

使用现有 Wrangler 登录状态，不在仓库保存令牌。先导出，再生成一个新的版本目录：

```powershell
.\tools\export-web.ps1
python tools/prepare-cloudflare.py --asset-base-url https://pub-2fecf2e531bd4f9c8e3af7e52c6caf06.r2.dev --project typinggame --page-origin https://typinggame-cl5.pages.dev --out build/cloudflare-next
.\tools\deploy-cloudflare.ps1 -Package build/cloudflare-next
```

打包器拒绝覆盖非空 Pages 输出目录；每次更新更换 `--out`。`manifest.json` 记录对象哈希、压缩前后尺寸、MIME 和本机上传路径。发布脚本先上传 R2 并配置 CORS，成功后才发布 Pages。无需重新创建项目或桶。

不同内容使用不同对象名，可让旧页面继续加载原版本。只修改 Pages 壳时，可以直接运行 `npx --yes wrangler pages deploy <包目录>/pages --project-name typinggame --branch main`。恢复旧版本时重新发布对应的 Pages 壳即可，需保留它引用的 R2 对象。

默认只开放正式站点的 CORS。若使用临时部署预览地址，需要将其精确 origin 加入桶 CORS，或直接通过正式地址验证。首次加载约 42.4 MB 压缩资源，之后资源使用浏览器缓存；当前未启用 PWA 离线模式。

当前使用 R2 的公开 `r2.dev` 地址完成上线验证。面向大量用户长期运营时，应为 R2 配置自定义资源域名；官方将 `r2.dev` 定位为开发用途并限制速率，见 [R2 公开桶说明](https://developers.cloudflare.com/r2/buckets/public-buckets/)。Pages 的单文件限制见 [官方限制说明](https://developers.cloudflare.com/pages/platform/limits/)。

## 存档边界

R2 此处只用于发布文件。玩家存档仍保存在当前浏览器、当前站点的 IndexedDB，可在学习档案导出/导入 JSON，不包含跨设备云同步。从 localhost 切换到正式域名时，请先在旧站导出，再在新站导入。
