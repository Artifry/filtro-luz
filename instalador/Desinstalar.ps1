# Desinstalar.ps1 - remove o Filtro Luz do computador.
# Encerra o programa, devolve as cores da tela, tira do início automático,
# apaga os atalhos e os arquivos do programa. A configuração (intensidade
# salva) só sai se você pedir.
param(
    [switch]$Silencioso,
    [string]$Destino,
    [bool]$ApagarConfig = $false
)

$ErrorActionPreference = 'Continue'
$PastaKit = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "Nucleo.ps1")

$origem = Join-Path $PastaKit "programa"   # GammaLib do kit, para restaurar as cores
if (-not $Destino) { $Destino = Get-CurrentInstall }

if (-not $Destino) {
    $aviso = "Não encontrei o $AppNome instalado neste computador."
    if ($Silencioso) { Write-Output $aviso; exit 0 }
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show($aviso, "Desinstalar $AppNome", 'OK', 'Information') | Out-Null
    exit 0
}

if ($Silencioso) {
    $r = Uninstall-App -Destino $Destino -ApagarConfig $ApagarConfig -PastaComGammaLib $origem
    Write-Output "Desinstalacao concluida."
    $r.Passos | ForEach-Object { Write-Output "  - $_" }
    exit 0
}

Add-Type -AssemblyName System.Windows.Forms

$pergunta = "Remover o $AppNome deste computador?`r`n`r`nPasta instalada:`r`n$Destino`r`n`r`nAs cores da tela voltam ao normal na hora."
if ([System.Windows.Forms.MessageBox]::Show($pergunta, "Desinstalar $AppNome", 'YesNo', 'Question') -ne [System.Windows.Forms.DialogResult]::Yes) {
    exit 0
}

$apagaCfg = ([System.Windows.Forms.MessageBox]::Show(
    "Apagar também a configuração salva (a intensidade e se estava ligado)?`r`n`r`nResponda Não se pretende reinstalar e quer manter os ajustes.",
    "Desinstalar $AppNome", 'YesNo', 'Question') -eq [System.Windows.Forms.DialogResult]::Yes)

$r = Uninstall-App -Destino $Destino -ApagarConfig $apagaCfg -PastaComGammaLib $origem
$msg = "O $AppNome foi removido.`r`n`r`n" + (($r.Passos | ForEach-Object { "- $_" }) -join "`r`n")
[System.Windows.Forms.MessageBox]::Show($msg, "Desinstalar $AppNome", 'OK', 'Information') | Out-Null
