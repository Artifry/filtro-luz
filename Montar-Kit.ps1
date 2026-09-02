# Montar-Kit.ps1 - monta o kit de instalação portátil do Filtro Luz.
#
# O kit não fica versionado: ele é gerado a partir deste repositório, para não
# haver duas cópias dos mesmos scripts para manter. Por padrão o kit vai para a
# Área de Trabalho; use -Destino para escolher outro lugar (um pendrive, por
# exemplo).
#
#   .\Montar-Kit.ps1
#   .\Montar-Kit.ps1 -Destino "E:\"
param(
    [string]$Destino,
    [switch]$Zip
)

$ErrorActionPreference = 'Stop'

$NomeKit = "Kit Filtro Luz"
if (-not $Destino) { $Destino = [Environment]::GetFolderPath('Desktop') }
$kit = Join-Path $Destino $NomeKit

# Arquivos do programa (raiz do repositório) e do instalador.
$doPrograma   = @("GammaLib.ps1", "FiltroLuz-Tray.ps1", "FiltroLuz.ps1", "Filtro Luz.vbs", "diag.ps1")
$doInstalador = @("Nucleo.ps1", "Instalar.ps1", "Desinstalar.ps1")

foreach ($d in @($kit, "$kit\programa", "$kit\instalador")) {
    New-Item -ItemType Directory -Path $d -Force | Out-Null
}

foreach ($a in $doPrograma) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $a) -Destination "$kit\programa" -Force
}
foreach ($a in $doInstalador) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "instalador\$a") -Destination "$kit\instalador" -Force
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "instalador\LEIA-ME.txt") -Destination $kit -Force

# O ícone vai junto do programa: o atalho aponta para ele na pasta instalada,
# então não pode depender do kit continuar existindo.
$ico = Join-Path $PSScriptRoot "instalador\Filtro Luz.ico"
if (-not (Test-Path -LiteralPath $ico)) {
    & (Join-Path $PSScriptRoot "instalador\Gerar-Icone.ps1") -Saida $ico | Out-Null
}
Copy-Item -LiteralPath $ico -Destination "$kit\programa" -Force

# Lançadores de duplo clique. Gerados aqui, em ASCII com fim de linha do Windows:
# acento em .bat depende da página de código do console e sairia errado.
$bats = @{
    "Instalar Filtro Luz.bat" = @(
        '@echo off',
        'rem Abre o instalador do Filtro Luz (janela grafica). Nao precisa de administrador',
        'rem para instalar dentro da sua conta de usuario.',
        'start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0instalador\Instalar.ps1"'
    )
    "Desinstalar Filtro Luz.bat" = @(
        '@echo off',
        'rem Remove o Filtro Luz deste computador e devolve as cores da tela.',
        'start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0instalador\Desinstalar.ps1"'
    )
}
foreach ($nome in $bats.Keys) {
    Set-Content -LiteralPath (Join-Path $kit $nome) -Value $bats[$nome] -Encoding ascii
}

# Os .ps1 precisam de UTF-8 COM BOM: sem BOM, o PowerShell 5.1 estraga os acentos.
foreach ($f in (Get-ChildItem -LiteralPath "$kit\instalador" -Filter *.ps1)) {
    $texto = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText($f.FullName, $texto, (New-Object System.Text.UTF8Encoding($true)))
}

$tamanho = (Get-ChildItem -LiteralPath $kit -Recurse -File | Measure-Object -Property Length -Sum).Sum
Write-Output ("Kit montado em: {0} ({1:N0} KB)" -f $kit, ($tamanho / 1KB))

if ($Zip) {
    $zip = "$kit.zip"
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
    Compress-Archive -Path "$kit\*" -DestinationPath $zip
    Write-Output ("Compactado: {0} ({1:N0} KB)" -f $zip, ((Get-Item -LiteralPath $zip).Length / 1KB))
}
