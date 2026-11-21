param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

$excludeDirs = @('node_modules', 'dist', 'release', '.git', '.astro', '.vercel')
$excludeFiles = @('apply-vodoo-rebrand.ps1', 'apply-vodoo-theme.ps1', 'generate-vodoo-assets.ps1')
$binaryExt = @('.png', '.ico', '.bmp', '.jpg', '.jpeg', '.gif', '.webp', '.woff', '.woff2', '.ttf', '.otf', '.eot', '.zip', '.7z', '.rar', '.exe', '.dll', '.node', '.pdf', '.mp3', '.mp4', '.icns', '.dmg', '.asar', '.pak', '.bin')

$hexMap = @{
  '#fff'      = '#E8C6A3'
  '#ffffff'   = '#E8C6A3'
  '#f1f5f9'   = '#E8C6A3'
  '#f3e8ff'   = '#E8C6A3'
  '#f5d0fe'   = '#E8C6A3'
  '#fca5a5'   = '#E8C6A3'
  '#fda4af'   = '#D66A36'
  '#090214'   = '#050303'
  '#07010e'   = '#050303'
  '#05010c'   = '#050303'
  '#04010a'   = '#050303'
  '#100424'   = '#190605'
  '#0a0416'   = '#190605'
  '#0d0618'   = '#190605'
  '#140522'   = '#190605'
  '#17072a'   = '#190605'
  '#130626'   = '#190605'
  '#1b0a33'   = '#4B090B'
  '#290d4f'   = '#4B090B'
  '#4c1d95'   = '#4B090B'
  '#6b21a8'   = '#8B1014'
  '#7c3aed'   = '#8B1014'
  '#8b5cf6'   = '#D66A36'
  '#a855f7'   = '#D66A36'
  '#c084fc'   = '#B68A65'
  '#d946ef'   = '#C51D20'
  '#e879f9'   = '#F04435'
  '#9333ea'   = '#B68A65'
  '#d8b4fe'   = '#B68A65'
  '#ec4899'   = '#C51D20'
  '#f43f5e'   = '#F04435'
  '#e11d48'   = '#C51D20'
  '#10b981'   = '#B68A65'
}

$rgbaMap = @(
  @{ From = '236,72,153';   To = '197,29,32' },
  @{ From = '168,85,247';   To = '214,106,54' },
  @{ From = '139,92,246';   To = '139,16,20' },
  @{ From = '147,51,234';   To = '182,138,101' },
  @{ From = '216,180,254';  To = '182,138,101' },
  @{ From = '244,63,94';    To = '240,68,53' },
  @{ From = '124,58,237';   To = '139,16,20' },
  @{ From = '239,68,68';    To = '240,68,53' },
  @{ From = '9,2,20';       To = '5,3,3' },
  @{ From = '19,6,38';      To = '25,6,5' },
  @{ From = '27,10,51';     To = '75,9,11' },
  @{ From = '15,4,30';      To = '10,3,3' },
  @{ From = '36,12,66';     To = '75,9,11' },
  @{ From = '22,7,40';      To = '25,6,5' },
  @{ From = '24,8,44';      To = '25,6,5' },
  @{ From = '18,6,36';      To = '10,3,3' },
  @{ From = '14,4,28';      To = '10,3,3' },
  @{ From = '16,5,32';      To = '10,3,3' },
  @{ From = '26,10,48';     To = '25,6,5' },
  @{ From = '43,16,80';     To = '75,9,11' },
  @{ From = '38,12,58';     To = '75,9,11' },
  @{ From = '24,7,48';      To = '25,6,5' },
  @{ From = '18,5,30';      To = '10,3,3' },
  @{ From = '14,5,28';      To = '10,3,3' },
  @{ From = '4,1,10';       To = '5,3,3' },
  @{ From = '255,255,255';  To = '232,198,163' }
)

$tokenMap = @(
  @{ From = '--accent-pink';   To = '--accent-red' },
  @{ From = '--accent-purple'; To = '--accent-ember' },
  @{ From = '--accent-violet'; To = '--accent-bronze' }
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

  foreach ($pair in $rgbaMap) {
    $pattern = 'rgba\(\s*' + ($pair.From -replace ',', '\s*,\s*') + '\s*,'
    $replacement = 'rgba(' + $pair.To + ','
    $text = [regex]::Replace($text, $pattern, $replacement)
  }

  $text = [regex]::Replace($text, '#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b', {
    param($m)
    $key = $m.Value.ToLowerInvariant()
    if ($hexMap.ContainsKey($key)) { return $hexMap[$key] }
    return $m.Value
  })

  foreach ($pair in $tokenMap) {
    $text = $text.Replace($pair.From, $pair.To)
  }

  if ($text -ne $original) {
    [System.IO.File]::WriteAllText($file.FullName, $text, $utf8)
    $changed.Add($file.FullName.Substring($Root.Length).TrimStart('\'))
  }
}

Write-Host "Themed files: $($changed.Count)"
$changed | ForEach-Object { Write-Host "  $_" }
