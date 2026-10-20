param([string]$Path = (Join-Path (Split-Path -Parent $PSScriptRoot) 'build/web/index.html'))
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $projectRoot 'web'
$destination = Split-Path -Parent $Path
$html = [IO.File]::ReadAllText($Path)
$head = @'
<!-- keybound-loader-head:start -->
<link rel="preload" as="image" href="loading-scene-v191.webp">
<link rel="preload" as="image" href="loading-robot-pose-v191.webp">
<link rel="preload" as="image" href="loading-knight-pose-v191.webp">
<link rel="stylesheet" href="loading-v191.css">
<script src="loading-v191.js" defer></script>
<!-- keybound-loader-head:end -->
'@
$markup = "<!-- keybound-loader-body:start -->`n" + [IO.File]::ReadAllText((Join-Path $sourceRoot 'loading-markup.html')) + "`n<!-- keybound-loader-body:end -->"
# Migrate the old injected shell and make subsequent preparations idempotent.
$html = [regex]::Replace($html,'(?s)<style>\s*body \{ background:#f4f9fd;.*?</script>\s*','')
$html = [regex]::Replace($html,'(?s)<!-- keybound-loader-head:start -->.*?<!-- keybound-loader-head:end -->\s*','')
$html = $html.Replace('<html lang="en">','<html lang="zh-CN">').Replace('</head>',$head + "`n</head>")
$html = [regex]::Replace($html,'<title>.*?</title>','<title>指尖挑战 · 打字训练与冒险</title>')
if ($html.Contains('<!-- keybound-loader-body:start -->')) {
    $html = [regex]::Replace($html,'(?s)<!-- keybound-loader-body:start -->.*?<!-- keybound-loader-body:end -->',[Text.RegularExpressions.MatchEvaluator]{ param($match) $markup })
} else {
    $pattern = '(?s)<div id="status">.*?<div id="status-notice"></div>\s*</div>'
    if (-not [regex]::IsMatch($html,$pattern)) { throw 'Unrecognized Godot loading markup; source was not overwritten.' }
    $html = [regex]::Replace($html,$pattern,[Text.RegularExpressions.MatchEvaluator]{ param($match) $markup })
}
[IO.File]::WriteAllText($Path,$html,[Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $sourceRoot 'loading.css') -Destination (Join-Path $destination 'loading-v191.css') -Force
Copy-Item -LiteralPath (Join-Path $sourceRoot 'loading.js') -Destination (Join-Path $destination 'loading-v191.js') -Force
Get-ChildItem -LiteralPath $sourceRoot -Filter '*.webp' | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $destination -Force }
