param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

$excludeDirs = @('node_modules', 'dist', 'release', '.git', '.astro', '.vercel')
$excludeFiles = @('apply-vodoo-rebrand.ps1', 'apply-vodoo-theme.ps1', 'generate-vodoo-assets.ps1')
$binaryExt = @('.png', '.ico', '.bmp', '.jpg', '.jpeg', '.gif', '.webp', '.woff', '.woff2', '.ttf', '.otf', '.eot', '.zip', '.7z', '.rar', '.exe', '.dll', '.node', '.pdf', '.mp3', '.mp4', '.icns', '.dmg', '.asar', '.pak', '.bin')

$replacements = @(
  [pscustomobject]@{ From = 'LupinMusic'; To = 'VodoMusic' },
  [pscustomobject]@{ From = 'lupinmusic'; To = 'vodoomusic' },
  [pscustomobject]@{ From = 'LUPIN';      To = 'VODOO' },
  [pscustomobject]@{ From = 'Lupin';      To = 'Vodoo' },
  [pscustomobject]@{ From = 'lupin';      To = 'vodoo' }
)

$utf8 = New-Object System.Text.UTF8Encoding($false)
$changed = New-Object System.Collections.Generic.List[string]

$files = Get-ChildItem -LiteralPath $Root -Recurse -File -Force | Where-Object {
  $rel = $_.FullName.Substring($Root.Length).TrimStart('\')
  $parts = $rel -split '\\'
  foreach ($part in $parts) {
    if ($excludeDirs -contains $part) { return $false }
  }
  if ($excludeFiles -contains $_.Name) { return $false }
  if ($binaryExt -contains $_.Extension.ToLowerInvariant()) { return $false }
  if ($_.Length -gt 4MB) { return $false }
  return $true
}

foreach ($file in $files) {
  $text = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
  $original = $text
  foreach ($pair in $replacements) {
    $text = $text.Replace($pair.From, $pair.To)
  }
  if ($text -ne $original) {
    [System.IO.File]::WriteAllText($file.FullName, $text, $utf8)
    $changed.Add($file.FullName.Substring($Root.Length).TrimStart('\'))
  }
}

Write-Host "Rebranded files: $($changed.Count)"
$changed | ForEach-Object { Write-Host "  $_" }
