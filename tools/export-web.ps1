param([string]$Engine = 'D:\dev\windssea\game\godot4.7.2\Godot_v4.7.2-stable_win64_console.exe')
$projectPath = Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Force -Path (Join-Path $projectPath 'build/web') | Out-Null
& $Engine --headless --path $projectPath --export-release Web (Join-Path $projectPath 'build/web/index.html')
if ($LASTEXITCODE -ne 0) { throw 'Web export failed. Install the export templates matching your exact Godot version.' }
Write-Output 'Export complete: build/web. Serve over HTTP(S), not file://.'
