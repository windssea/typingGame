param(
    [string]$Engine = 'D:\dev\windssea\game\godot4.7.2\Godot_v4.7.2-stable_win64_console.exe',
    [string]$Python = 'python',
    [switch]$Monolithic
)
$projectPath = Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Force -Path (Join-Path $projectPath 'build/web') | Out-Null
& $Engine --headless --path $projectPath --export-release Web (Join-Path $projectPath 'build/web/index.html')
if ($LASTEXITCODE -ne 0) { throw 'Web export failed. Install the export templates matching your exact Godot version.' }
& (Join-Path $PSScriptRoot 'prepare-web.ps1')
if (-not $Monolithic) {
    & $Python (Join-Path $PSScriptRoot 'split-web-packs.py') --source (Join-Path $projectPath 'build/web') --out (Join-Path $projectPath 'build/web-streamed') --engine $Engine
    if ($LASTEXITCODE -ne 0) { throw 'Content pack splitting failed.' }
    Write-Output 'Export complete: build/web-streamed. Package with prepare-cloudflare.py --source build/web-streamed.'
} else {
    Write-Output 'Monolithic export: build/web. Serve over HTTP(S), not file://.'
}
