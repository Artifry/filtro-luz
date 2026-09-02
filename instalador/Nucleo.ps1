# Nucleo.ps1 - funções compartilhadas pelo instalador e pelo desinstalador do Filtro Luz.
# Não faz nada sozinho: apenas define as funções.

$script:AppNome    = "Filtro Luz"
$script:AppVersao  = "1.0.0"
$script:RunKey     = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$script:RunName    = "FiltroLuz"
$script:ConfigDir  = Join-Path $env:APPDATA "FiltroLuz"

# Arquivos que compõem o programa. O .ico entra junto para o atalho não depender do kit.
$script:Arquivos = @(
    "GammaLib.ps1",
    "FiltroLuz-Tray.ps1",
    "FiltroLuz.ps1",
    "Filtro Luz.vbs",
    "diag.ps1",
    "Filtro Luz.ico"
)

# Desenha a logo do programa (disco bicolor) no tamanho pedido.
# É preciso desenhar em vez de usar o .ico: o .NET Framework devolve imagem
# corrompida em Icon.ToBitmap() quando o .ico traz PNG embutido.
function New-LogoBitmap {
    param([int]$Tamanho = 48)

    Add-Type -AssemblyName System.Drawing

    $bmp = New-Object System.Drawing.Bitmap $Tamanho, $Tamanho
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    $m = [math]::Max(1, [int]($Tamanho * 0.06))
    $d = $Tamanho - (2 * $m)

    $bAzul  = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 42, 120, 214))
    $bAmbar = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 240, 160, 32))
    $g.FillPie($bAzul,  $m, $m, $d, $d, 90, 180)
    $g.FillPie($bAmbar, $m, $m, $d, $d, 270, 180)

    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(230, 24, 32, 44)), ([math]::Max(1.0, $Tamanho * 0.055))
    $g.DrawEllipse($pen, $m, $m, $d, $d)

    $bAzul.Dispose(); $bAmbar.Dispose(); $pen.Dispose(); $g.Dispose()
    return $bmp
}

# Pasta sugerida: dentro do perfil do usuário, que não exige administrador.
function Get-DestinoPadrao {
    return (Join-Path $env:LOCALAPPDATA "Programs\$script:AppNome")
}

# Lê a instalação atual pela entrada de boot; se não houver, tenta o destino padrão.
function Get-CurrentInstall {
    $valor = (Get-ItemProperty -Path $script:RunKey -Name $script:RunName -ErrorAction SilentlyContinue).$script:RunName
    if ($valor) {
        # O valor tem a forma: wscript.exe "C:\caminho\Filtro Luz.vbs"
        $m = [regex]::Match($valor, '"([^"]+\.vbs)"')
        if ($m.Success) {
            $pasta = Split-Path -Parent $m.Groups[1].Value
            if (Test-Path -LiteralPath $pasta) { return $pasta }
        }
    }
    $padrao = Get-DestinoPadrao
    if (Test-Path -LiteralPath (Join-Path $padrao "FiltroLuz-Tray.ps1")) { return $padrao }
    return $null
}

# Encerra qualquer instância do filtro que esteja rodando (de qualquer pasta).
# Retorna quantos processos foram encerrados.
function Stop-FilterInstance {
    $alvos = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='wscript.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and ($_.CommandLine -like '*FiltroLuz-Tray.ps1*' -or $_.CommandLine -like '*Filtro Luz.vbs*') })

    $mortos = 0
    foreach ($p in $alvos) {
        # Não encerrar o próprio processo que está rodando o instalador.
        if ($p.ProcessId -eq $PID) { continue }
        try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop; $mortos++ } catch { }
    }
    if ($mortos -gt 0) { Start-Sleep -Milliseconds 700 }
    return $mortos
}

# Devolve as cores originais da tela.
# Necessário porque encerrar o tray à força pode não disparar a restauração dele,
# e a tela ficaria presa no tom alaranjado depois da instalação.
function Restore-Gamma {
    param([string]$PastaComGammaLib)

    $lib = Join-Path $PastaComGammaLib "GammaLib.ps1"
    if (-not (Test-Path -LiteralPath $lib)) { return $false }
    try {
        . $lib
        Set-BlueLightFilter -On $false -Level 0 | Out-Null
        return $true
    } catch { return $false }
}

# Cria um atalho .lnk que abre o filtro sem janela de console.
function New-AppShortcut {
    param(
        [Parameter(Mandatory=$true)][string]$Caminho,   # .lnk de destino
        [Parameter(Mandatory=$true)][string]$PastaApp
    )

    $vbs = Join-Path $PastaApp "$script:AppNome.vbs"
    $ico = Join-Path $PastaApp "$script:AppNome.ico"

    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($Caminho)
    $lnk.TargetPath       = Join-Path $env:WINDIR "System32\wscript.exe"
    $lnk.Arguments        = '"' + $vbs + '"'
    $lnk.WorkingDirectory = $PastaApp
    $lnk.Description      = "Filtro de luz azul (ícone na bandeja do sistema)"
    if (Test-Path -LiteralPath $ico) { $lnk.IconLocation = $ico }
    $lnk.Save()
    return (Test-Path -LiteralPath $Caminho)
}

function Get-CaminhoAtalhoDesktop { return (Join-Path ([Environment]::GetFolderPath('Desktop')) "$script:AppNome.lnk") }
function Get-CaminhoAtalhoMenu    { return (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$script:AppNome.lnk") }

# Confere se dá para escrever na pasta escolhida, antes de começar a copiar.
# Retorna $null se estiver tudo bem, ou o texto do problema.
function Test-DestinoGravavel {
    param([Parameter(Mandatory=$true)][string]$Destino)

    try {
        if (-not (Test-Path -LiteralPath $Destino)) {
            New-Item -ItemType Directory -Path $Destino -Force -ErrorAction Stop | Out-Null
        }
        $teste = Join-Path $Destino ".escrita-teste"
        Set-Content -LiteralPath $teste -Value "ok" -ErrorAction Stop
        Remove-Item -LiteralPath $teste -Force -ErrorAction SilentlyContinue
        return $null
    } catch {
        return "Sem permissão para escrever em:`r`n$Destino`r`n`r`nEscolha uma pasta dentro da sua conta de usuário (a sugerida funciona sempre) ou execute o instalador como administrador."
    }
}

# Instalação propriamente dita. Recebe a pasta do kit (onde está a subpasta 'programa').
# Retorna um objeto com Ok, Passos (o que foi feito) e Erro.
function Install-App {
    param(
        [Parameter(Mandatory=$true)][string]$PastaKit,
        [Parameter(Mandatory=$true)][string]$Destino,
        [bool]$IniciarComWindows = $true,
        [bool]$AtalhoDesktop     = $true,
        [bool]$AtalhoMenu        = $true,
        [bool]$AbrirAgora        = $true
    )

    $passos = New-Object System.Collections.ArrayList
    $origem = Join-Path $PastaKit "programa"

    if (-not (Test-Path -LiteralPath $origem)) {
        return [pscustomobject]@{ Ok=$false; Passos=$passos; Erro="Kit incompleto: não encontrei a subpasta 'programa' em`r`n$PastaKit" }
    }
    foreach ($a in $script:Arquivos) {
        if (-not (Test-Path -LiteralPath (Join-Path $origem $a))) {
            return [pscustomobject]@{ Ok=$false; Passos=$passos; Erro="Kit incompleto: falta o arquivo '$a' na pasta 'programa'." }
        }
    }

    $problema = Test-DestinoGravavel -Destino $Destino
    if ($problema) { return [pscustomobject]@{ Ok=$false; Passos=$passos; Erro=$problema } }

    # Instalar em cima da própria pasta do kit copiaria arquivo sobre si mesmo.
    if ([System.IO.Path]::GetFullPath($origem).TrimEnd('\') -eq [System.IO.Path]::GetFullPath($Destino).TrimEnd('\')) {
        return [pscustomobject]@{ Ok=$false; Passos=$passos; Erro="Escolha uma pasta diferente da pasta 'programa' do próprio kit." }
    }

    # 1. Encerrar o que estiver rodando e devolver as cores da tela.
    $mortos = Stop-FilterInstance
    if ($mortos -gt 0) {
        [void]$passos.Add("Encerrei a versão que estava em execução ($mortos processo(s)).")
        if (Restore-Gamma -PastaComGammaLib $origem) { [void]$passos.Add("Devolvi as cores originais da tela.") }
    }

    # 2. Copiar o programa.
    try {
        foreach ($a in $script:Arquivos) {
            Copy-Item -LiteralPath (Join-Path $origem $a) -Destination $Destino -Force -ErrorAction Stop
        }
        [void]$passos.Add("Copiei o programa para: $Destino")
    } catch {
        return [pscustomobject]@{ Ok=$false; Passos=$passos; Erro="Falhou ao copiar os arquivos:`r`n$($_.Exception.Message)" }
    }

    # 3. Início automático com o Windows.
    try {
        if ($IniciarComWindows) {
            $vbs = Join-Path $Destino "$script:AppNome.vbs"
            Set-ItemProperty -Path $script:RunKey -Name $script:RunName -Value ('wscript.exe "' + $vbs + '"') -ErrorAction Stop
            [void]$passos.Add("Registrei para abrir junto com o Windows.")
        } else {
            Remove-ItemProperty -Path $script:RunKey -Name $script:RunName -ErrorAction SilentlyContinue
            [void]$passos.Add("Não vai abrir junto com o Windows (pode ligar depois no menu do ícone).")
        }
    } catch {
        [void]$passos.Add("Aviso: não consegui mexer no início automático ($($_.Exception.Message)).")
    }

    # 4. Atalhos.
    if ($AtalhoDesktop) {
        if (New-AppShortcut -Caminho (Get-CaminhoAtalhoDesktop) -PastaApp $Destino) { [void]$passos.Add("Criei o atalho na Área de Trabalho.") }
    } else {
        Remove-Item -LiteralPath (Get-CaminhoAtalhoDesktop) -Force -ErrorAction SilentlyContinue
    }
    if ($AtalhoMenu) {
        if (New-AppShortcut -Caminho (Get-CaminhoAtalhoMenu) -PastaApp $Destino) { [void]$passos.Add("Criei o atalho no Menu Iniciar.") }
    } else {
        Remove-Item -LiteralPath (Get-CaminhoAtalhoMenu) -Force -ErrorAction SilentlyContinue
    }

    # 5. Abrir agora.
    if ($AbrirAgora) {
        try {
            Start-Process -FilePath (Join-Path $env:WINDIR "System32\wscript.exe") -ArgumentList ('"' + (Join-Path $Destino "$script:AppNome.vbs") + '"') -ErrorAction Stop
            Start-Sleep -Seconds 3
            # Confere no destino certo: se houver outra cópia rodando de outra pasta,
            # o teste genérico daria falso positivo.
            $vivo = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
                Where-Object { $_.CommandLine -like "*$Destino*FiltroLuz-Tray.ps1*" })
            if ($vivo.Count -gt 0) { [void]$passos.Add("O programa está rodando (ícone na bandeja, ao lado do relógio).") }
            else { [void]$passos.Add("Aviso: mandei abrir, mas não confirmei o processo. Use o atalho para abrir.") }
        } catch {
            [void]$passos.Add("Aviso: não consegui abrir agora ($($_.Exception.Message)). Use o atalho.")
        }
    }

    return [pscustomobject]@{ Ok=$true; Passos=$passos; Erro=$null }
}

# Remoção. ApagarConfig também remove a intensidade salva em %APPDATA%\FiltroLuz.
function Uninstall-App {
    param(
        [string]$Destino,
        [bool]$ApagarConfig = $false,
        [string]$PastaComGammaLib
    )

    $passos = New-Object System.Collections.ArrayList

    $mortos = Stop-FilterInstance
    if ($mortos -gt 0) { [void]$passos.Add("Encerrei o programa ($mortos processo(s)).") }

    $libDir = if ($PastaComGammaLib) { $PastaComGammaLib } else { $Destino }
    if ($libDir -and (Restore-Gamma -PastaComGammaLib $libDir)) { [void]$passos.Add("Devolvi as cores originais da tela.") }

    if (Get-ItemProperty -Path $script:RunKey -Name $script:RunName -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $script:RunKey -Name $script:RunName -ErrorAction SilentlyContinue
        [void]$passos.Add("Removi do início automático do Windows.")
    }

    foreach ($lnk in @((Get-CaminhoAtalhoDesktop), (Get-CaminhoAtalhoMenu))) {
        if (Test-Path -LiteralPath $lnk) {
            Remove-Item -LiteralPath $lnk -Force -ErrorAction SilentlyContinue
            [void]$passos.Add("Removi o atalho: $lnk")
        }
    }

    if ($Destino -and (Test-Path -LiteralPath $Destino)) {
        try {
            # Apaga só os arquivos do programa; a pasta sai apenas se ficar vazia,
            # para nunca levar embora arquivo que não é nosso.
            foreach ($a in $script:Arquivos) {
                Remove-Item -LiteralPath (Join-Path $Destino $a) -Force -ErrorAction SilentlyContinue
            }
            Remove-Item -LiteralPath (Join-Path $Destino "README.md") -Force -ErrorAction SilentlyContinue
            $restante = @(Get-ChildItem -LiteralPath $Destino -Force -ErrorAction SilentlyContinue)
            if ($restante.Count -eq 0) {
                Remove-Item -LiteralPath $Destino -Force -ErrorAction SilentlyContinue
                [void]$passos.Add("Apaguei a pasta do programa: $Destino")
            } else {
                [void]$passos.Add("Apaguei os arquivos do programa. A pasta continua lá porque tem outros arquivos dentro: $Destino")
            }
        } catch {
            [void]$passos.Add("Aviso: não consegui apagar tudo em $Destino ($($_.Exception.Message)).")
        }
    }

    if ($ApagarConfig -and (Test-Path -LiteralPath $script:ConfigDir)) {
        Remove-Item -LiteralPath $script:ConfigDir -Recurse -Force -ErrorAction SilentlyContinue
        [void]$passos.Add("Apaguei a configuração salva (intensidade e estado).")
    }

    return [pscustomobject]@{ Ok=$true; Passos=$passos; Erro=$null }
}
