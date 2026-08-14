# FiltroLuz.ps1 - versao de linha de comando (util para atalhos e testes).
# Uso:
#   .\FiltroLuz.ps1 -Intensidade 70     # 0 = sem filtro, 100 = filtro maximo
#   .\FiltroLuz.ps1 -Desligar           # volta as cores originais

param(
    [ValidateRange(0, 100)][int]$Intensidade = 60,
    [switch]$Desligar
)

. (Join-Path $PSScriptRoot "GammaLib.ps1")

if ($Desligar) { $Intensidade = 0 }

$applied = Set-BlueLightFilter -On ($Intensidade -gt 0) -Level $Intensidade
$total   = (Get-DisplayDevices).Count

if ($applied -lt 1) {
    Write-Output "FALHOU: nenhum dos $total monitor(es) aceitou a alteracao de gamma."
} elseif ($Intensidade -eq 0) {
    Write-Output "Filtro DESLIGADO - cores originais restauradas em $applied de $total monitor(es)."
} else {
    Write-Output "Filtro LIGADO em $Intensidade% - aplicado em $applied de $total monitor(es)."
}
