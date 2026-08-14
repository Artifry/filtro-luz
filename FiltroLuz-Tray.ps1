# FiltroLuz-Tray.ps1
# Icone na area de notificacao (ao lado do relogio).
# Clique esquerdo = liga/desliga o filtro de luz azul. Sem horario, sem automatismo.
# Clique direito  = menu com intensidade, iniciar com Windows e sair.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

. (Join-Path $PSScriptRoot "GammaLib.ps1")

# ------------------------------------------------------------------- Estado
$script:ConfigDir    = Join-Path $env:APPDATA "FiltroLuz"
$script:ConfigFile   = Join-Path $script:ConfigDir "config.json"
$script:LauncherPath = Join-Path $PSScriptRoot "Filtro Luz.vbs"
$script:RunKey       = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$script:RunName      = "FiltroLuz"

$script:Enabled   = $false
$script:Intensity = 60

function Load-Config {
    if (Test-Path $script:ConfigFile) {
        try {
            $c = Get-Content $script:ConfigFile -Raw | ConvertFrom-Json
            if ($null -ne $c.Intensity) { $script:Intensity = [int]$c.Intensity }
            if ($null -ne $c.Enabled)   { $script:Enabled   = [bool]$c.Enabled }
        } catch { }   # config corrompida: segue com os padroes
    }
}

function Save-Config {
    if (-not (Test-Path $script:ConfigDir)) {
        New-Item -ItemType Directory -Path $script:ConfigDir -Force | Out-Null
    }
    [pscustomobject]@{ Enabled = $script:Enabled; Intensity = $script:Intensity } |
        ConvertTo-Json | Set-Content -Path $script:ConfigFile -Encoding utf8
}

# -------------------------------------------------------------------- Icone
function New-DotIcon {
    param([System.Drawing.Color]$Color)

    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    $brush = New-Object System.Drawing.SolidBrush $Color
    $g.FillEllipse($brush, 2, 2, 28, 28)
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(210, 20, 20, 20)), 2
    $g.DrawEllipse($pen, 2, 2, 28, 28)

    $brush.Dispose(); $pen.Dispose(); $g.Dispose()

    $handle = $bmp.GetHicon()
    $icon   = [System.Drawing.Icon]::FromHandle($handle).Clone()
    [GammaCtl]::DestroyIcon($handle) | Out-Null
    $bmp.Dispose()
    return $icon
}

$script:IconOn  = New-DotIcon ([System.Drawing.Color]::FromArgb(255, 158, 45))   # ambar = filtrando
$script:IconOff = New-DotIcon ([System.Drawing.Color]::FromArgb(110, 170, 255))  # azul  = sem filtro

# ------------------------------------------------------------------- Bandeja
$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Visible = $true

function Update-Tray {
    if ($script:Enabled) {
        $notify.Icon = $script:IconOn
        $notify.Text = "Filtro de luz azul: LIGADO ($($script:Intensity)%)"
    } else {
        $notify.Icon = $script:IconOff
        $notify.Text = "Filtro de luz azul: desligado"
    }
}

function Toggle-Filter {
    $script:Enabled = -not $script:Enabled
    $applied = Set-BlueLightFilter -On $script:Enabled -Level $script:Intensity

    if ($applied -lt 1) {
        # Nenhum monitor aceitou: reverte para o icone nao mentir sobre o estado.
        $script:Enabled = -not $script:Enabled
        $notify.BalloonTipTitle = "Nao foi possivel aplicar o filtro"
        $notify.BalloonTipText  = "Nenhum monitor aceitou a alteracao de gamma."
        $notify.ShowBalloonTip(6000)
    }

    Update-Tray
    Save-Config
}

# --------------------------------------------------------------------- Menu
$menu = New-Object System.Windows.Forms.ContextMenuStrip

$itemToggle = $menu.Items.Add("Ligar / desligar")
$itemToggle.add_Click({ Toggle-Filter })

$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$levelMenu = New-Object System.Windows.Forms.ToolStripMenuItem "Intensidade"
$menu.Items.Add($levelMenu) | Out-Null

$script:LevelItems = @()
foreach ($level in 20, 40, 60, 80, 100) {
    $item = New-Object System.Windows.Forms.ToolStripMenuItem "$level%"
    $item.Tag = $level
    $item.add_Click({
        $script:Intensity = [int]$this.Tag
        foreach ($li in $script:LevelItems) { $li.Checked = ([int]$li.Tag -eq $script:Intensity) }
        if ($script:Enabled) { Set-BlueLightFilter -On $true -Level $script:Intensity | Out-Null }
        Update-Tray
        Save-Config
    })
    $levelMenu.DropDownItems.Add($item) | Out-Null
    $script:LevelItems += $item
}

$itemStartup = New-Object System.Windows.Forms.ToolStripMenuItem "Iniciar com o Windows"
$itemStartup.add_Click({
    $existing = Get-ItemProperty $script:RunKey -Name $script:RunName -ErrorAction SilentlyContinue
    if ($existing) {
        Remove-ItemProperty -Path $script:RunKey -Name $script:RunName -ErrorAction SilentlyContinue
        $this.Checked = $false
    } else {
        Set-ItemProperty -Path $script:RunKey -Name $script:RunName -Value ("wscript.exe `"$($script:LauncherPath)`"")
        $this.Checked = $true
    }
})
$menu.Items.Add($itemStartup) | Out-Null

$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$itemExit = $menu.Items.Add("Sair (restaura as cores)")
$itemExit.add_Click({
    Set-BlueLightFilter -On $false -Level 0 | Out-Null
    $notify.Visible = $false
    $notify.Dispose()
    [System.Windows.Forms.Application]::Exit()
})

$notify.ContextMenuStrip = $menu

# Clique esquerdo simples alterna; o direito abre o menu (comportamento padrao).
$notify.add_MouseClick({
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Toggle-Filter }
})

# Sincroniza as marcacoes do menu com o estado atual, ao abrir.
$menu.add_Opening({
    foreach ($li in $script:LevelItems) { $li.Checked = ([int]$li.Tag -eq $script:Intensity) }
    $itemStartup.Checked = [bool](Get-ItemProperty $script:RunKey -Name $script:RunName -ErrorAction SilentlyContinue)
})

# ------------------------------------------------------------------- Inicio
Load-Config

# O f.lux tambem controla o gamma; os dois juntos brigam pelo mesmo recurso.
if (Get-Process flux -ErrorAction SilentlyContinue) {
    $notify.BalloonTipTitle = "f.lux esta rodando"
    $notify.BalloonTipText  = "Feche o f.lux, senao ele sobrescreve este filtro."
    $notify.ShowBalloonTip(6000)
}

Set-BlueLightFilter -On $script:Enabled -Level $script:Intensity | Out-Null
Update-Tray

# Se o processo morrer sem passar pelo menu Sair, devolve as cores originais.
$null = Register-EngineEvent PowerShell.Exiting -Action {
    Set-BlueLightFilter -On $false -Level 0 | Out-Null
}

[System.Windows.Forms.Application]::Run((New-Object System.Windows.Forms.ApplicationContext))
