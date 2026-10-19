$projectPath = Split-Path -Parent $PSScriptRoot
$addonSource = 'D:\dev\windssea\game\GodotAIProject\addons\godot_ai'
$addonTarget = Join-Path $projectPath 'addons/godot_ai'
if (-not (Test-Path -LiteralPath $addonSource)) { throw 'Existing Godot MCP addon not found.' }
if (-not (Test-Path -LiteralPath $addonTarget)) {
    New-Item -ItemType Directory -Force -Path (Join-Path $projectPath 'addons') | Out-Null
    Copy-Item -LiteralPath $addonSource -Destination $addonTarget -Recurse
}
$configPath = Join-Path $projectPath 'project.godot'
$configText = Get-Content -LiteralPath $configPath -Raw
if ($configText -notmatch '\[editor_plugins\]') {
    Add-Content -LiteralPath $configPath -Value "`n[editor_plugins]`nenabled=PackedStringArray(`"res://addons/godot_ai/plugin.cfg`")`n"
}
Write-Output 'Godot MCP addon is enabled for this project. Open the editor to connect.'
