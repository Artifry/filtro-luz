# Instalar.ps1 - instalador do Filtro Luz.
# Sem parametros: abre a janela. Com -Silencioso: instala sem interface (util para testar
# ou para instalar em varios PCs por script).
param(
    [switch]$Silencioso,
    [string]$Destino,
    [bool]$IniciarComWindows = $true,
    [bool]$AtalhoDesktop     = $true,
    [bool]$AtalhoMenu        = $true,
    [bool]$AbrirAgora        = $true
)

$ErrorActionPreference = 'Stop'
$PastaKit = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $PSScriptRoot "Nucleo.ps1")

if (-not $Destino) { $Destino = Get-DestinoPadrao }

# ------------------------------------------------------------- Modo silencioso
if ($Silencioso) {
    $r = Install-App -PastaKit $PastaKit -Destino $Destino `
            -IniciarComWindows $IniciarComWindows -AtalhoDesktop $AtalhoDesktop `
            -AtalhoMenu $AtalhoMenu -AbrirAgora $AbrirAgora
    if ($r.Ok) {
        Write-Output "Instalacao concluida."
        $r.Passos | ForEach-Object { Write-Output "  - $_" }
        exit 0
    } else {
        Write-Output "FALHOU: $($r.Erro)"
        $r.Passos | ForEach-Object { Write-Output "  - $_" }
        exit 1
    }
}

# ------------------------------------------------------------------- Interface
# Na janela, um erro solto nao pode derrubar o instalador: cada acao ja trata o seu.
$ErrorActionPreference = 'Continue'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$AZUL     = [System.Drawing.Color]::FromArgb(42, 120, 214)   # #2a78d6 oficial
$AZUL_ESC = [System.Drawing.Color]::FromArgb(32, 96, 176)
$FUNDO    = [System.Drawing.Color]::FromArgb(247, 248, 250)
$TEXTO    = [System.Drawing.Color]::FromArgb(32, 36, 44)
$CINZA    = [System.Drawing.Color]::FromArgb(110, 118, 130)

$form = New-Object System.Windows.Forms.Form
$form.Text            = "Instalar $AppNome"
$form.ClientSize      = New-Object System.Drawing.Size(560, 430)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox     = $false
$form.StartPosition   = 'CenterScreen'
$form.BackColor       = $FUNDO
$form.Font            = New-Object System.Drawing.Font("Segoe UI", 9)
$icoKit = Join-Path $PastaKit "programa\$AppNome.ico"
if (Test-Path -LiteralPath $icoKit) { $form.Icon = New-Object System.Drawing.Icon($icoKit) }

# Dicas de mouse com 1,5 s de atraso: a explicação vai na dica, não solta na tela.
$tip = New-Object System.Windows.Forms.ToolTip
$tip.InitialDelay = 1500
$tip.ReshowDelay  = 1500
$tip.AutoPopDelay = 12000

# --- Faixa superior
$faixa = New-Object System.Windows.Forms.Panel
$faixa.Size      = New-Object System.Drawing.Size(560, 76)
$faixa.Location  = New-Object System.Drawing.Point(0, 0)
$faixa.BackColor = $AZUL
$form.Controls.Add($faixa)

$logo = New-Object System.Windows.Forms.PictureBox
$logo.Image     = New-LogoBitmap -Tamanho 48
$logo.Size      = New-Object System.Drawing.Size(48, 48)
$logo.Location  = New-Object System.Drawing.Point(20, 14)
$logo.BackColor = [System.Drawing.Color]::Transparent
$faixa.Controls.Add($logo)

$titulo = New-Object System.Windows.Forms.Label
$titulo.Text      = $AppNome
$titulo.Font      = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$titulo.ForeColor = [System.Drawing.Color]::White
$titulo.BackColor = [System.Drawing.Color]::Transparent
$titulo.Location  = New-Object System.Drawing.Point(80, 14)
$titulo.AutoSize  = $true
$faixa.Controls.Add($titulo)

$sub = New-Object System.Windows.Forms.Label
$sub.Text      = "Filtro de luz azul para Windows"
$sub.ForeColor = [System.Drawing.Color]::FromArgb(225, 236, 250)
$sub.BackColor = [System.Drawing.Color]::Transparent
$sub.Location  = New-Object System.Drawing.Point(82, 45)
$sub.AutoSize  = $true
$faixa.Controls.Add($sub)

# --- Pasta de instalacao
$lblPasta = New-Object System.Windows.Forms.Label
$lblPasta.Text     = "Instalar em"
$lblPasta.Location = New-Object System.Drawing.Point(24, 100)
$lblPasta.AutoSize = $true
$lblPasta.ForeColor = $TEXTO
$form.Controls.Add($lblPasta)

$txtPasta = New-Object System.Windows.Forms.TextBox
$txtPasta.Text     = $Destino
$txtPasta.Location = New-Object System.Drawing.Point(24, 122)
$txtPasta.Size     = New-Object System.Drawing.Size(410, 24)
$form.Controls.Add($txtPasta)
$tip.SetToolTip($txtPasta, "Pasta onde o programa vai ficar. A sugerida fica dentro da sua conta de usuário e não pede permissão de administrador. Se escolher Program Files, será preciso executar o instalador como administrador.")

$btnProcurar = New-Object System.Windows.Forms.Button
$btnProcurar.Text     = "Procurar"
$btnProcurar.Location = New-Object System.Drawing.Point(442, 121)
$btnProcurar.Size     = New-Object System.Drawing.Size(94, 26)
$btnProcurar.FlatStyle = 'System'
$form.Controls.Add($btnProcurar)
$tip.SetToolTip($btnProcurar, "Escolher a pasta pelo navegador de pastas do Windows.")

$btnProcurar.add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Escolha a pasta de instalação do $AppNome"
    if (Test-Path -LiteralPath $txtPasta.Text) { $dlg.SelectedPath = $txtPasta.Text }
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        # Se a pasta escolhida ja for a do app, respeita; senao cria uma subpasta com o nome.
        $p = $dlg.SelectedPath
        if ((Split-Path -Leaf $p) -ne $AppNome) { $p = Join-Path $p $AppNome }
        $txtPasta.Text = $p
    }
})

# --- Opcoes
$grupo = New-Object System.Windows.Forms.GroupBox
$grupo.Text     = "Opções"
$grupo.Location = New-Object System.Drawing.Point(24, 162)
$grupo.Size     = New-Object System.Drawing.Size(512, 132)
$grupo.ForeColor = $TEXTO
$form.Controls.Add($grupo)

$chkBoot = New-Object System.Windows.Forms.CheckBox
$chkBoot.Text     = "Abrir junto com o Windows"
$chkBoot.Location = New-Object System.Drawing.Point(16, 26)
$chkBoot.Size     = New-Object System.Drawing.Size(480, 22)
$chkBoot.Checked  = $IniciarComWindows
$grupo.Controls.Add($chkBoot)
$tip.SetToolTip($chkBoot, "Registra o programa para subir sozinho quando você liga o computador, já com a última intensidade usada. Dá para ligar e desligar depois, no menu do ícone da bandeja.")

$chkDesk = New-Object System.Windows.Forms.CheckBox
$chkDesk.Text     = "Criar atalho na Área de Trabalho"
$chkDesk.Location = New-Object System.Drawing.Point(16, 52)
$chkDesk.Size     = New-Object System.Drawing.Size(480, 22)
$chkDesk.Checked  = $AtalhoDesktop
$grupo.Controls.Add($chkDesk)
$tip.SetToolTip($chkDesk, "Coloca um atalho na Área de Trabalho para abrir o filtro quando ele estiver fechado.")

$chkMenu = New-Object System.Windows.Forms.CheckBox
$chkMenu.Text     = "Criar atalho no Menu Iniciar"
$chkMenu.Location = New-Object System.Drawing.Point(16, 78)
$chkMenu.Size     = New-Object System.Drawing.Size(480, 22)
$chkMenu.Checked  = $AtalhoMenu
$grupo.Controls.Add($chkMenu)
$tip.SetToolTip($chkMenu, "Faz o programa aparecer na busca do Menu Iniciar.")

$chkAbrir = New-Object System.Windows.Forms.CheckBox
$chkAbrir.Text     = "Abrir o programa ao terminar"
$chkAbrir.Location = New-Object System.Drawing.Point(16, 104)
$chkAbrir.Size     = New-Object System.Drawing.Size(480, 22)
$chkAbrir.Checked  = $AbrirAgora
$grupo.Controls.Add($chkAbrir)
$tip.SetToolTip($chkAbrir, "Abre o filtro assim que a instalação acabar, sem precisar reiniciar o computador.")

# --- Status
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location  = New-Object System.Drawing.Point(24, 302)
$lblStatus.Size      = New-Object System.Drawing.Size(512, 40)
$lblStatus.ForeColor = $CINZA
$form.Controls.Add($lblStatus)

# Avisa desde o inicio se ja houver uma instalacao no computador.
$atual = Get-CurrentInstall
if ($atual) {
    $lblStatus.Text = "Já existe uma instalação em: $atual"
    $txtPasta.Text  = $atual
}

# --- Rodapé com a versão, sempre visível
$rodape = New-Object System.Windows.Forms.Label
$rodape.Text      = "$AppNome v$AppVersao"
$rodape.Location  = New-Object System.Drawing.Point(24, 396)
$rodape.AutoSize  = $true
$rodape.ForeColor = $CINZA
$form.Controls.Add($rodape)

# --- Botoes
$btnInstalar = New-Object System.Windows.Forms.Button
$btnInstalar.Text      = "Instalar"
$btnInstalar.Location  = New-Object System.Drawing.Point(346, 386)
$btnInstalar.Size      = New-Object System.Drawing.Size(102, 32)
$btnInstalar.BackColor = $AZUL
$btnInstalar.ForeColor = [System.Drawing.Color]::White
$btnInstalar.FlatStyle = 'Flat'
$btnInstalar.FlatAppearance.BorderSize = 0
$btnInstalar.FlatAppearance.MouseOverBackColor = $AZUL_ESC
$form.Controls.Add($btnInstalar)
$form.AcceptButton = $btnInstalar

$btnFechar = New-Object System.Windows.Forms.Button
$btnFechar.Text     = "Fechar"
$btnFechar.Location = New-Object System.Drawing.Point(456, 386)
$btnFechar.Size     = New-Object System.Drawing.Size(80, 32)
$btnFechar.FlatStyle = 'System'
$form.Controls.Add($btnFechar)
$form.CancelButton = $btnFechar
$btnFechar.add_Click({ $form.Close() })

$btnInstalar.add_Click({
    $destinoEscolhido = $txtPasta.Text.Trim()
    if (-not $destinoEscolhido) {
        [System.Windows.Forms.MessageBox]::Show("Informe a pasta de instalação.", "Instalar $AppNome", 'OK', 'Warning') | Out-Null
        return
    }

    $btnInstalar.Enabled = $false
    $btnProcurar.Enabled = $false
    $lblStatus.Text = "Instalando..."
    $form.Refresh()

    $r = Install-App -PastaKit $PastaKit -Destino $destinoEscolhido `
            -IniciarComWindows $chkBoot.Checked -AtalhoDesktop $chkDesk.Checked `
            -AtalhoMenu $chkMenu.Checked -AbrirAgora $chkAbrir.Checked

    if ($r.Ok) {
        $lblStatus.Text = "Instalado."
        $msg = "Pronto. O $AppNome foi instalado.`r`n`r`n" + (($r.Passos | ForEach-Object { "- $_" }) -join "`r`n")
        if ($chkAbrir.Checked) { $msg += "`r`n`r`nO controle é o ícone redondo na bandeja, ao lado do relógio: clique esquerdo liga e desliga, clique direito abre o menu de intensidade." }
        [System.Windows.Forms.MessageBox]::Show($msg, "Instalar $AppNome", 'OK', 'Information') | Out-Null
        $form.Close()
    } else {
        $lblStatus.Text = "Não foi possível instalar."
        [System.Windows.Forms.MessageBox]::Show($r.Erro, "Instalar $AppNome", 'OK', 'Error') | Out-Null
        $btnInstalar.Enabled = $true
        $btnProcurar.Enabled = $true
    }
})

[void]$form.ShowDialog()
