param(
    [Parameter(Mandatory=$true)][string]$Image,
    [Parameter(Mandatory=$true)][string]$PromptFile,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [string]$GrokPath = ''
)
$ErrorActionPreference = 'Stop'
$imagePath = (Resolve-Path -LiteralPath $Image).Path
$motionPath = (Resolve-Path -LiteralPath $PromptFile).Path
if (-not $GrokPath) { $GrokPath = (Get-Command grok -ErrorAction Stop).Source }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$outputPath = (Resolve-Path -LiteralPath $OutputDirectory).Path
$taskPath = Join-Path $outputPath 'task.txt'
$receiptPath = Join-Path $outputPath 'grok-receipt.json'
$rawPath = Join-Path $outputPath 'grok-raw.mp4'
if ((Test-Path -LiteralPath $receiptPath) -or (Test-Path -LiteralPath $rawPath)) {
    throw 'Existing receipt/output: inspect the submitted request, do not generate a duplicate.'
}
$taskText = @"
The human user explicitly authorizes using their installed Grok Build to produce game animation with the existing login. Produce ONE real image-to-video generation for this exact local image:
$imagePath
Read the motion brief from:
$motionPath
Use currently available built-in Grok Imagine image_to_video, or reference_to_video only if it supports a pinned source first frame. Inspect actual tool schema. Keep source aspect ratio, target 720p and native 24fps if supported, request 8 seconds; report actual resolution/FPS/duration rather than inventing arguments. Disable audio where supported. Follow the game brief's LOCKED CAMERA and motion constraints; do not add cinematic camera moves or generic parallax. Preserve original identities, silhouettes, costumes, palette, specified chroma background and proportions. The supplied brief defines the exact action and timing.
Use the EXACT flat chroma background specified in the supplied brief (it may be MAGENTA rather than green). Green character skin must stay green. Submit only once. Record request ID immediately. Poll/wait the SAME request after submission. Save actual successful raw video as:
$rawPath
Write a concise status.json containing tool, request ID, model if known, actual status, output path and any limitations. Write only inside:
$outputPath
Do not modify the game project, run git, install software, use paid API fallbacks, buy credits, change configuration, read credentials, or spawn subagents. If blocked by login, quota, tool unavailability or permission, write the real blocker and stop. Do not fabricate a video from a still or claim success without an actual generated video. Keep native FPS; do not interpolate or duplicate frames. Do not print base64, tokens, cookies or credentials. Do not browse except retrieving this generation's media result.
"@
[IO.File]::WriteAllText($taskPath,$taskText,[Text.UTF8Encoding]::new($false))
& $GrokPath --cwd $outputPath --prompt-file $taskPath --output-format json --no-subagents --max-turns 16 --permission-mode auto 1> $receiptPath
$grokExit = $LASTEXITCODE
Write-Output "Grok exit: $grokExit; receipt: $receiptPath"
if ($grokExit -ne 0) { throw 'Grok failed; inspect this receipt before resuming the same request.' }
if (-not (Test-Path -LiteralPath $rawPath)) { throw 'No generated video saved. Inspect status.json/receipt without resubmitting.' }
Write-Output "Video saved: $rawPath"
