param([int]$Port = 8765, [string]$Python = '')
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $projectPath 'build/web/index.html'))) { throw 'Export the game first: ./tools/export-web.ps1' }
if (-not $Python) {
    $bundled = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
    $Python = if (Test-Path $bundled) { $bundled } else { 'python' }
}
Write-Output "Open http://127.0.0.1:$Port/build/web/index.html and keep this terminal running."
& $Python -m http.server $Port --bind 127.0.0.1 --directory $projectPath
