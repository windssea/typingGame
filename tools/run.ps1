param([switch]$Editor)
$enginePath = 'D:\dev\windssea\game\godot4.7.2\Godot_v4.7.2-stable_win64.exe'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $enginePath)) { throw "Godot not found: $enginePath" }
$engineArgs = @('--path', ('"' + $projectPath + '"'))
if ($Editor) { $engineArgs += '--editor' }
Start-Process -FilePath $enginePath -ArgumentList $engineArgs -WindowStyle Hidden
