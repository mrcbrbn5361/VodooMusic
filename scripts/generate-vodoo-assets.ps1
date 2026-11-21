param(
  [string]$Source = (Join-Path $PSScriptRoot '..\desktop\assets\vodoo-logo.png')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$sourcePath = (Resolve-Path -LiteralPath $Source).Path
$assetsDir = Split-Path -Parent $sourcePath
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $sourcePath))
$src = [System.Drawing.Image]::FromFile($sourcePath)

$palette = @{
  bg      = [System.Drawing.ColorTranslator]::FromHtml('#050303')
  shadow  = [System.Drawing.ColorTranslator]::FromHtml('#190605')
  deep    = [System.Drawing.ColorTranslator]::FromHtml('#4B090B')
  darkRed = [System.Drawing.ColorTranslator]::FromHtml('#8B1014')
  red     = [System.Drawing.ColorTranslator]::FromHtml('#C51D20')
  fire    = [System.Drawing.ColorTranslator]::FromHtml('#F04435')
  orange  = [System.Drawing.ColorTranslator]::FromHtml('#D66A36')
  bronze  = [System.Drawing.ColorTranslator]::FromHtml('#75452F')
  aged    = [System.Drawing.ColorTranslator]::FromHtml('#B68A65')
  cream   = [System.Drawing.ColorTranslator]::FromHtml('#E8C6A3')
}

function New-ResizedBitmap {
  param([System.Drawing.Image]$Image, [int]$Width, [int]$Height)
  $bmp = New-Object System.Drawing.Bitmap($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.Clear([System.Drawing.Color]::Transparent)
  $g.DrawImage($Image, (New-Object System.Drawing.Rectangle(0, 0, $Width, $Height)))
  $g.Dispose()
  return $bmp
}

function Get-PngBytes {
  param([System.Drawing.Bitmap]$Bitmap)
  $ms = New-Object System.IO.MemoryStream
  $Bitmap.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
  $bytes = $ms.ToArray()
  $ms.Dispose()
  return ,$bytes
}

function Get-DibBytes {
  param([System.Drawing.Bitmap]$Bitmap)
  $w = $Bitmap.Width
  $h = $Bitmap.Height
  $ms = New-Object System.IO.MemoryStream
  $bw = New-Object System.IO.BinaryWriter($ms)
  $bw.Write([uint32]40)
  $bw.Write([int32]$w)
  $bw.Write([int32]($h * 2))
  $bw.Write([uint16]1)
  $bw.Write([uint16]32)
  $bw.Write([uint32]0)
  $bw.Write([uint32]($w * $h * 4))
  $bw.Write([int32]0)
  $bw.Write([int32]0)
  $bw.Write([uint32]0)
  $bw.Write([uint32]0)
  for ($y = $h - 1; $y -ge 0; $y--) {
    for ($x = 0; $x -lt $w; $x++) {
      $c = $Bitmap.GetPixel($x, $y)
      $bw.Write([byte]$c.B)
      $bw.Write([byte]$c.G)
      $bw.Write([byte]$c.R)
      $bw.Write([byte]$c.A)
    }
  }
  $maskRow = [int]([math]::Ceiling($w / 32.0) * 4)
  $zeros = New-Object byte[] $maskRow
  for ($y = 0; $y -lt $h; $y++) { $bw.Write($zeros) }
  $bw.Flush()
  $bytes = $ms.ToArray()
  $bw.Dispose()
  $ms.Dispose()
  return ,$bytes
}

function Save-IconFile {
  param([System.Drawing.Image]$Image, [string]$Path)
  $sizes = @(16, 24, 32, 48, 64, 128, 256)
  $entries = @()
  foreach ($size in $sizes) {
    $bmp = New-ResizedBitmap $Image $size $size
    if ($size -le 64) {
      $data = Get-DibBytes $bmp
    } else {
      $data = Get-PngBytes $bmp
    }
    $bmp.Dispose()
    $entries += [pscustomobject]@{ Size = $size; Data = $data }
  }

  $out = New-Object System.IO.MemoryStream
  $bw = New-Object System.IO.BinaryWriter($out)
  $bw.Write([uint16]0)
  $bw.Write([uint16]1)
  $bw.Write([uint16]$entries.Count)
  $offset = 6 + (16 * $entries.Count)
  foreach ($entry in $entries) {
    $dim = if ($entry.Size -ge 256) { 0 } else { $entry.Size }
    $bw.Write([byte]$dim)
    $bw.Write([byte]$dim)
    $bw.Write([byte]0)
    $bw.Write([byte]0)
    $bw.Write([uint16]1)
    $bw.Write([uint16]32)
    $bw.Write([uint32]$entry.Data.Length)
    $bw.Write([uint32]$offset)
    $offset += $entry.Data.Length
  }
  foreach ($entry in $entries) { $bw.Write($entry.Data) }
  $bw.Flush()
  [System.IO.File]::WriteAllBytes($Path, $out.ToArray())
  $bw.Dispose()
  $out.Dispose()
}

function New-Sidebar {
  param(
    [System.Drawing.Image]$Image,
    [string]$Path,
    [string]$Title,
    [string]$Subtitle
  )
  $w = 164
  $h = 314
  $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

  $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
  $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $palette.bg, $palette.shadow, 90.0)
  $g.FillRectangle($bgBrush, $rect)
  $bgBrush.Dispose()

  $glowRect = New-Object System.Drawing.Rectangle(-60, 10, 284, 284)
  $glowPath = New-Object System.Drawing.Drawing2D.GraphicsPath
  $glowPath.AddEllipse($glowRect)
  $glowBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush($glowPath)
  $glowBrush.CenterColor = [System.Drawing.Color]::FromArgb(120, $palette.deep)
  $glowBrush.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $palette.bg))
  $g.FillPath($glowBrush, $glowPath)
  $glowBrush.Dispose()
  $glowPath.Dispose()

  $logo = New-ResizedBitmap $Image 104 104
  $g.DrawImage($logo, 30, 46, 104, 104)
  $logo.Dispose()

  $titleFont = New-Object System.Drawing.Font('Segoe UI', 17, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $subFont = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $tagFont = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $titleBrush = New-Object System.Drawing.SolidBrush($palette.cream)
  $subBrush = New-Object System.Drawing.SolidBrush($palette.aged)
  $tagBrush = New-Object System.Drawing.SolidBrush($palette.bronze)
  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = [System.Drawing.StringAlignment]::Center

  $g.DrawString($Title, $titleFont, $titleBrush, (New-Object System.Drawing.RectangleF(0, 170, $w, 26)), $fmt)
  $g.DrawString($Subtitle, $subFont, $subBrush, (New-Object System.Drawing.RectangleF(0, 196, $w, 18)), $fmt)

  $linePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(150, $palette.red), 1)
  $g.DrawLine($linePen, 46, 226, 118, 226)
  $linePen.Dispose()

  $g.DrawString('PREMIUM SOUND', $tagFont, $tagBrush, (New-Object System.Drawing.RectangleF(0, 238, $w, 14)), $fmt)
  $g.DrawString('EXPERIENCE', $tagFont, $tagBrush, (New-Object System.Drawing.RectangleF(0, 250, $w, 14)), $fmt)

  $titleFont.Dispose(); $subFont.Dispose(); $tagFont.Dispose()
  $titleBrush.Dispose(); $subBrush.Dispose(); $tagBrush.Dispose(); $fmt.Dispose()
  $g.Dispose()
  $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Bmp)
  $bmp.Dispose()
}

function New-Header {
  param([System.Drawing.Image]$Image, [string]$Path)
  $w = 150
  $h = 57
  $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

  $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
  $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $palette.shadow, $palette.bg, 0.0)
  $g.FillRectangle($bgBrush, $rect)
  $bgBrush.Dispose()

  $logo = New-ResizedBitmap $Image 42 42
  $g.DrawImage($logo, 6, 7, 42, 42)
  $logo.Dispose()

  $titleFont = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $subFont = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $titleBrush = New-Object System.Drawing.SolidBrush($palette.cream)
  $subBrush = New-Object System.Drawing.SolidBrush($palette.aged)
  $g.DrawString('VODOO', $titleFont, $titleBrush, 54, 12)
  $g.DrawString('MUSIC', $subFont, $subBrush, 56, 33)

  $linePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200, $palette.red), 2)
  $g.DrawLine($linePen, 0, $h - 2, $w, $h - 2)
  $linePen.Dispose()

  $titleFont.Dispose(); $subFont.Dispose(); $titleBrush.Dispose(); $subBrush.Dispose()
  $g.Dispose()
  $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Bmp)
  $bmp.Dispose()
}

$icon512 = New-ResizedBitmap $src 512 512
$icon512.Save((Join-Path $assetsDir 'icon.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$icon512.Save((Join-Path $assetsDir 'logo.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$icon512.Dispose()

Save-IconFile $src (Join-Path $assetsDir 'icon.ico')
New-Header $src (Join-Path $assetsDir 'installerHeader.bmp')
New-Sidebar $src (Join-Path $assetsDir 'installerSidebar.bmp') 'VODOO' 'MUSIC'
New-Sidebar $src (Join-Path $assetsDir 'uninstallerSidebar.bmp') 'VODOO' 'UNINSTALL'

$rendererPublic = Join-Path $repoRoot 'desktop\src\renderer\public'
$websitePublic = Join-Path $repoRoot 'website\public'
foreach ($dir in @($rendererPublic, $websitePublic)) {
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

$rIcon = New-ResizedBitmap $src 512 512
$rIcon.Save((Join-Path $rendererPublic 'icon.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$rIcon.Save((Join-Path $rendererPublic 'logo.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$rIcon.Dispose()
Save-IconFile $src (Join-Path $rendererPublic 'icon.ico')

$wLogo = New-ResizedBitmap $src 512 512
$wLogo.Save((Join-Path $websitePublic 'logo.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$wLogo.Dispose()

$src.Dispose()
Write-Host 'Vodoo assets generated.'
