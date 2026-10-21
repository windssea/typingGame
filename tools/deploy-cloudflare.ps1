param(
    [Parameter(Mandatory=$true)][string]$Package,
    [string]$BucketName = 'typinggame-assets',
    [switch]$ReuseEngine,
    [switch]$AssetsOnly
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $Package).Path
$manifest = Get-Content -LiteralPath (Join-Path $root 'manifest.json') -Raw | ConvertFrom-Json
foreach ($item in $manifest.objects) {
    if ($ReuseEngine -and $item.content_type -eq 'application/wasm') {
        $engineResponse = Invoke-WebRequest -Method Head -Uri "$($manifest.asset_base_url)/$($item.key)"
        if ($engineResponse.StatusCode -ne 200) { throw 'Expected versioned engine does not exist on R2.' }
        Write-Output "Reusing existing engine: $($item.key)"
        continue
    }
    & npx --yes wrangler r2 object put "$BucketName/$($item.key)" --file $item.file --content-type $item.content_type --content-encoding $item.content_encoding --cache-control $item.cache_control --remote
    if ($LASTEXITCODE -ne 0) { throw "R2 upload failed for $($item.key); Pages was not deployed." }
}
$policyPath = Join-Path $PSScriptRoot '../config/cloudflare-cors.json'
$corsPolicy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
$packagePolicy = Get-Content -LiteralPath (Join-Path $root 'cors.json') -Raw | ConvertFrom-Json
# Old release packages must not remove a custom domain added after their creation.
$corsPolicy.rules[0].allowed.origins = @(@($corsPolicy.rules[0].allowed.origins) + @($packagePolicy.rules[0].allowed.origins) | Select-Object -Unique)
$effectiveCorsPath = Join-Path $root 'cors.effective.json'
$corsPolicy | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $effectiveCorsPath -Encoding utf8NoBOM
& npx --yes wrangler r2 bucket cors set $BucketName --file $effectiveCorsPath
if ($LASTEXITCODE -ne 0) { throw 'R2 CORS configuration failed; Pages was not deployed.' }
if ($AssetsOnly) {
    Write-Output 'Versioned assets uploaded. The current Pages deployment is unchanged.'
    return
}
& npx --yes wrangler pages deploy $manifest.pages_directory --project-name $manifest.project --branch main
if ($LASTEXITCODE -ne 0) { throw 'Pages deployment failed. R2 assets remain versioned and can be reused.' }
