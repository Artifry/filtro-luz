# Gera o ícone do Filtro Luz: disco bicolor (azul da luz crua / âmbar da luz filtrada).
# Escreve um .ico com varias resolucoes, cada uma como PNG embutido.
param([Parameter(Mandatory=$true)][string]$Saida)

Add-Type -AssemblyName System.Drawing

$azul  = [System.Drawing.Color]::FromArgb(255, 42, 120, 214)   # #2a78d6
$ambar = [System.Drawing.Color]::FromArgb(255, 240, 160, 32)   # tom quente do filtro
$borda = [System.Drawing.Color]::FromArgb(230, 24, 32, 44)

function New-Png {
    param([int]$Tamanho)

    $bmp = New-Object System.Drawing.Bitmap $Tamanho, $Tamanho
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    # Margem proporcional para o disco nao encostar na borda do icone.
    $m = [math]::Max(1, [int]($Tamanho * 0.06))
    $d = $Tamanho - (2 * $m)

    # Metade esquerda azul (luz crua), metade direita ambar (luz filtrada).
    $bAzul  = New-Object System.Drawing.SolidBrush $azul
    $bAmbar = New-Object System.Drawing.SolidBrush $ambar
    $g.FillPie($bAzul,  $m, $m, $d, $d, 90, 180)
    $g.FillPie($bAmbar, $m, $m, $d, $d, 270, 180)

    # Contorno escuro: da definicao mesmo em 16 px.
    $lp = [math]::Max(1.0, $Tamanho * 0.055)
    $pen = New-Object System.Drawing.Pen $borda, $lp
    $g.DrawEllipse($pen, $m, $m, $d, $d)

    $bAzul.Dispose(); $bAmbar.Dispose(); $pen.Dispose(); $g.Dispose()

    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    return $ms.ToArray()
}

$tamanhos = @(16, 24, 32, 48, 64, 128, 256)
$imagens  = @()
foreach ($t in $tamanhos) { $imagens += ,@($t, (New-Png -Tamanho $t)) }

$fs = [System.IO.File]::Create($Saida)
$bw = New-Object System.IO.BinaryWriter $fs

# ICONDIR: reservado, tipo 1 (icone), quantidade de imagens.
$bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$imagens.Count)

# Cada ICONDIRENTRY tem 16 bytes; os dados vem depois de todas as entradas.
$offset = 6 + (16 * $imagens.Count)
foreach ($img in $imagens) {
    $t = [int]$img[0]; $bytes = [byte[]]$img[1]
    # 256 px se escreve como 0 no campo de 1 byte.
    $bw.Write([byte]($(if ($t -ge 256) { 0 } else { $t })))
    $bw.Write([byte]($(if ($t -ge 256) { 0 } else { $t })))
    $bw.Write([byte]0)              # paleta: 0 = sem paleta
    $bw.Write([byte]0)              # reservado
    $bw.Write([UInt16]1)            # planos
    $bw.Write([UInt16]32)           # bits por pixel
    $bw.Write([UInt32]$bytes.Length)
    $bw.Write([UInt32]$offset)
    $offset += $bytes.Length
}
foreach ($img in $imagens) { $bw.Write([byte[]]$img[1]) }

$bw.Flush(); $bw.Close(); $fs.Close()
Write-Output ("Icone gerado: {0} ({1} bytes, {2} resolucoes)" -f $Saida, (Get-Item -LiteralPath $Saida).Length, $imagens.Count)
