; FiltroLuz.iss - gera o instalador unico (.exe) do Filtro Luz.
;
; Compilar:
;   & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" instalador\FiltroLuz.iss
;
; O .exe sai em dist\ (fora do versionamento). Para mudar a pasta de saida:
;   ISCC.exe /DOutDir="C:\algum\lugar" instalador\FiltroLuz.iss
;
; Instala sem exigir administrador (vai para a pasta do usuario por padrao), mas
; permite escolher outra pasta e, se quiser, instalar como administrador.

#define AppNome    "Filtro Luz"
#define AppVersao  "1.0.0"
#define AppSite    "https://github.com/Artifry/filtro-luz"
#define Lancador   "Filtro Luz.vbs"

#ifndef OutDir
  #define OutDir "..\dist"
#endif

[Setup]
; Este AppId identifica o programa para atualizacoes e desinstalacao: NUNCA mudar.
AppId={{EA059E9B-BBF9-46C0-BD10-1ED5DAEEE63C}
AppName={#AppNome}
AppVersion={#AppVersao}
AppVerName={#AppNome} {#AppVersao}
AppPublisherURL={#AppSite}
AppSupportURL={#AppSite}
VersionInfoVersion={#AppVersao}
VersionInfoDescription=Filtro de luz azul para Windows

DefaultDirName={autopf}\{#AppNome}
DefaultGroupName={#AppNome}
DisableProgramGroupPage=yes
AllowNoIcons=yes

; A pasta e a chave de inicio automatico ficam na conta do usuario, entao nao
; e preciso administrador.
; ATENCAO: nao usar "PrivilegesRequiredOverridesAllowed=dialog" aqui. Esse modo
; mostra a tela "Selecione o Modo de Instalacao" ANTES de tudo e ela aparece
; mesmo com /VERYSILENT, travando qualquer instalacao automatizada. Com
; "commandline", quem quiser instalar para todos os usuarios passa /ALLUSERS.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline

OutputDir={#OutDir}
OutputBaseFilename={#AppNome}_Setup_v{#AppVersao}
SetupIconFile=Filtro Luz.ico
UninstallDisplayIcon={app}\Filtro Luz.ico
UninstallDisplayName={#AppNome} {#AppVersao}

Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
LicenseFile=
InfoBeforeFile=
ArchitecturesInstallIn64BitMode=

[Languages]
Name: "brazilian"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon";  Description: "Criar atalho na Área de Trabalho"; GroupDescription: "Atalhos:"
Name: "startupicon";  Description: "Abrir o {#AppNome} junto com o Windows"; GroupDescription: "Início automático:"

[Files]
Source: "..\GammaLib.ps1";        DestDir: "{app}"; Flags: ignoreversion
Source: "..\FiltroLuz-Tray.ps1";  DestDir: "{app}"; Flags: ignoreversion
Source: "..\FiltroLuz.ps1";       DestDir: "{app}"; Flags: ignoreversion
Source: "..\Filtro Luz.vbs";      DestDir: "{app}"; Flags: ignoreversion
Source: "..\diag.ps1";            DestDir: "{app}"; Flags: ignoreversion
Source: "Filtro Luz.ico";         DestDir: "{app}"; Flags: ignoreversion
Source: "Encerrar.ps1";           DestDir: "{app}"; Flags: ignoreversion
Source: "LEIA-ME.txt";            DestDir: "{app}"; Flags: ignoreversion isreadme

; Copias temporarias, usadas para encerrar a versao anterior antes de sobrescrever.
Source: "Encerrar.ps1";           DestDir: "{tmp}"; Flags: dontcopy
Source: "..\GammaLib.ps1";        DestDir: "{tmp}"; Flags: dontcopy

[Icons]
Name: "{group}\{#AppNome}";            Filename: "{sys}\wscript.exe"; Parameters: """{app}\{#Lancador}"""; WorkingDir: "{app}"; IconFilename: "{app}\Filtro Luz.ico"; Comment: "Filtro de luz azul (ícone na bandeja do sistema)"
Name: "{group}\Diagnóstico de monitores"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\diag.ps1"""; WorkingDir: "{app}"; IconFilename: "{app}\Filtro Luz.ico"; Comment: "Verifica qual monitor aceita o ajuste de gamma"
Name: "{autodesktop}\{#AppNome}";      Filename: "{sys}\wscript.exe"; Parameters: """{app}\{#Lancador}"""; WorkingDir: "{app}"; IconFilename: "{app}\Filtro Luz.ico"; Comment: "Filtro de luz azul (ícone na bandeja do sistema)"; Tasks: desktopicon

[Registry]
; Inicio automatico na conta do usuario. Guarda o caminho absoluto do lancador,
; por isso o Setup regrava a chave a cada instalacao.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "FiltroLuz"; ValueData: "wscript.exe ""{app}\{#Lancador}"""; Flags: uninsdeletevalue; Tasks: startupicon
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: none;   ValueName: "FiltroLuz"; Flags: deletevalue uninsdeletevalue; Tasks: not startupicon

[Run]
Filename: "{sys}\wscript.exe"; Parameters: """{app}\{#Lancador}"""; WorkingDir: "{app}"; Description: "Abrir o {#AppNome} agora"; Flags: postinstall nowait skipifsilent

[UninstallRun]
; Antes de apagar os arquivos: encerra o programa e devolve as cores da tela.
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\Encerrar.ps1"""; RunOnceId: "EncerrarFiltroLuz"; Flags: runhidden

[UninstallDelete]
; A configuracao em %APPDATA% e do usuario e nao e apagada: se ele reinstalar,
; a intensidade dele volta. Para apagar, remover a pasta FiltroLuz manualmente.
Type: files; Name: "{app}\Filtro Luz.ico"

[Code]
{ Encerra a versao que estiver rodando antes de substituir os arquivos.
  Sem isso, a copia antiga continuaria no ar e brigaria com a nova pela mesma
  rampa de gamma. }
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Codigo: Integer;
begin
  Result := '';
  ExtractTemporaryFile('Encerrar.ps1');
  ExtractTemporaryFile('GammaLib.ps1');
  Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
       ExpandConstant('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{tmp}\Encerrar.ps1"'),
       '', SW_HIDE, ewWaitUntilTerminated, Codigo);
end;
