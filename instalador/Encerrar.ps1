# Encerrar.ps1 - encerra o Filtro Luz e devolve as cores originais da tela.
#
# Usado pelo Setup antes de substituir os arquivos e pelo desinstalador antes de
# apagá-los. Precisa restaurar o gamma explicitamente: matar o processo à força
# não dispara o PowerShell.Exiting do tray, e a tela ficaria presa no filtro.
#
# Procura o GammaLib.ps1 na própria pasta, então funciona tanto rodando de {app}
# quanto da pasta temporária do Setup.

$ErrorActionPreference = 'Continue'

# ATENÇÃO: identificar o tray por "a linha de comando menciona FiltroLuz-Tray.ps1"
# mata processo inocente — qualquer janela de PowerShell onde alguém digitou o nome
# do arquivo entra na conta, inclusive o script que faz a busca. Por isso o teste
# é estrutural: precisa ser o interpretador certo executando o nosso arquivo.
function Test-EhTrayDoFiltro {
    param($Processo)

    if (-not $Processo.CommandLine) { return $false }
    $exe = [System.IO.Path]::GetFileName(($Processo.Name))

    if ($exe -ieq 'powershell.exe') {
        # Tem de ser -File apontando para o nosso script, não uma menção qualquer.
        return ($Processo.CommandLine -imatch '-File\s+"?[^"]*[\\/]FiltroLuz-Tray\.ps1"?')
    }
    if ($exe -ieq 'wscript.exe') {
        # O lançador é chamado como: wscript.exe "<pasta>\Filtro Luz.vbs"
        return ($Processo.CommandLine -imatch '"[^"]*[\\/]Filtro Luz\.vbs"\s*$' -or
                $Processo.CommandLine -imatch '[\\/]Filtro Luz\.vbs\s*$')
    }
    return $false
}

$alvos = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='wscript.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessId -ne $PID -and (Test-EhTrayDoFiltro $_) })

$mortos = 0
foreach ($p in $alvos) {
    try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop; $mortos++ } catch { }
}
if ($mortos -gt 0) { Start-Sleep -Milliseconds 700 }

$lib = Join-Path $PSScriptRoot "GammaLib.ps1"
if (Test-Path -LiteralPath $lib) {
    try {
        . $lib
        Set-BlueLightFilter -On $false -Level 0 | Out-Null
    } catch { }
}

Write-Output "Encerrados: $mortos"
exit 0
