param([string]$Path = (Join-Path (Split-Path -Parent $PSScriptRoot) 'build/web/index.html'))
$html = [IO.File]::ReadAllText($Path)
$head = @'
<style>
body { background:#f4f9fd; color:#2d405b; }
#status { background:#f4f9fd; }
#status-progress { accent-color:#416db4; height:12px; border-radius:8px; }
#loading-caption { position:absolute; bottom:16%; color:#416db4; font:600 20px system-ui,sans-serif; }
#status-notice { background:#fff4dd; color:#5b4327; border-color:#e9c88d; }
#status { background:linear-gradient(180deg,rgba(16,54,70,.10),rgba(16,54,70,.46)),url('./loading-scene.png') center/cover; }
#status-splash { display:none; }
#status::before { content:'指尖挑战'; position:absolute; top:23%; left:0; width:100%; text-align:center; font:800 clamp(42px,7vw,88px) system-ui,sans-serif; color:#fff4cf; text-shadow:0 4px 0 #24566b,0 8px 22px rgba(8,40,60,.3); }
#loading-caption { bottom:25%; left:0; width:100%; text-align:center; color:#fff7df; font-size:24px; text-shadow:0 2px 8px #244d59; }
#status-progress { position:absolute; top:79%; left:35%; width:30%; height:10px; }
</style>
<script>
// The engine retains its old internal application name for save compatibility.
// Keep the public tab title on the current brand when the runtime starts.
const publicTitle = '指尖挑战 · 打字训练与冒险';
new MutationObserver(() => {
 if(document.title!==publicTitle) document.title=publicTitle;
}).observe(document.querySelector('title'),{childList:true,subtree:true,characterData:true});
addEventListener('keydown',function(event){
 if(document.activeElement?.id==='canvas' && ['F1','F2','F3','Tab',' '].includes(event.key)) event.preventDefault();
});
</script>
'@
$html = $html.Replace('<html lang="en">','<html lang="zh-CN">').Replace('</head>',$head + "`n</head>")
$html = [regex]::Replace($html,'<title>.*?</title>','<title>指尖挑战 · 打字训练与冒险</title>')
$html = $html.Replace('<progress id="status-progress"></progress>','<div id="loading-caption">正在准备冒险…</div><progress id="status-progress"></progress>')
[IO.File]::WriteAllText($Path,$html,[Text.UTF8Encoding]::new($false))
$loadingSource = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets/generated/academy-lobby-v10.png'
Copy-Item -LiteralPath $loadingSource -Destination (Join-Path (Split-Path -Parent $Path) 'loading-scene.png') -Force
