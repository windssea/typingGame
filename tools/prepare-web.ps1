param([string]$Path = (Join-Path (Split-Path -Parent $PSScriptRoot) 'build/web/index.html'))
$html = [IO.File]::ReadAllText($Path)
$head = @'
<style>
body { background:#f4f9fd; color:#2d405b; }
#status { background:#f4f9fd; }
#status-progress { accent-color:#416db4; height:12px; border-radius:8px; }
#loading-caption { position:absolute; bottom:16%; color:#416db4; font:600 20px system-ui,sans-serif; }
#status-notice { background:#fff4dd; color:#5b4327; border-color:#e9c88d; }
</style>
<script>
addEventListener('keydown',function(event){
 if(document.activeElement?.id==='canvas' && ['F1','F2','F3','Tab',' '].includes(event.key)) event.preventDefault();
});
</script>
'@
$html = $html.Replace('<html lang="en">','<html lang="zh-CN">').Replace('</head>',$head + "`n</head>")
$html = [regex]::Replace($html,'<title>.*?</title>','<title>指尖挑战 · 打字训练与冒险</title>')
$html = $html.Replace('<progress id="status-progress"></progress>','<div id="loading-caption">指尖挑战正在准备，让每次输入都有回应…</div><progress id="status-progress"></progress>')
[IO.File]::WriteAllText($Path,$html,[Text.UTF8Encoding]::new($false))
