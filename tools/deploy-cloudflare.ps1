param(
    [Parameter(Mandatory=$true)][string]$Package,
    [string]$BucketName = 'typinggame-assets'
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $Package).Path
$manifest = Get-Content -LiteralPath (Join-Path $root 'manifest.json') -Raw | ConvertFrom-Json
foreach ($item in $manifest.objects) {
    & npx --yes wrangler r2 object put "$BucketName/$($item.key)" --file $item.file --content-type $item.content_type --content-encoding $item.content_encoding --cache-control $item.cache_control --remote
    if ($LASTEXITCODE -ne 0) { throw "R2 upload failed for $($item.key); Pages was not deployed." }
}
& npx --yes wrangler r2 bucket cors set $BucketName --file (Join-Path $root 'cors.json')
if ($LASTEXITCODE -ne 0) { throw 'R2 CORS configuration failed; Pages was not deployed.' }
& npx --yes wrangler pages deploy $manifest.pages_directory --project-name $manifest.project --branch main
if ($LASTEXITCODE -ne 0) { throw 'Pages deployment failed. R2 assets remain versioned and can be reused.' }
