# Filtro Luz

> **Diretório:** raiz deste repositório
> **Repositório público** — ver `README.md` para a visão geral de uso.

## O que é este projeto
Filtro de luz azul para Windows (tipo f.lux/Night Light), feito em PowerShell puro
usando `SetDeviceGammaRamp` do `gdi32.dll` via P/Invoke. Roda como ícone na bandeja do
sistema, controle 100% manual (sem agendamento por horário), com estado persistido entre
reinícios do PC.

## Stack
- Windows PowerShell 5.1 (clássico, não PowerShell 7/Core).
- .NET Framework via `Add-Type` (`System.Windows.Forms`, `System.Drawing`).
- P/Invoke direto em `gdi32.dll`/`user32.dll` (`SetDeviceGammaRamp`, `CreateDC`, `DeleteDC`, `DestroyIcon`).
- Sem dependências externas e sem internet. O instalador também é PowerShell puro
  (WinForms), não há Inno Setup nem executável compilado.

## Arquivos-chave
- `GammaLib.ps1` → núcleo/biblioteca: classe `GammaCtl`, `Get-DisplayDevices`, `Set-BlueLightFilter -On -Level`.
- `FiltroLuz-Tray.ps1` → app principal (bandeja/system tray), o que roda no dia a dia.
- `FiltroLuz.ps1` → versão CLI, sem bandeja (`-Intensidade N` / `-Desligar`).
- `Filtro Luz.vbs` → lançador silencioso (sem janela de console), usado no boot.
- `diag.ps1` → ferramenta de diagnóstico para falhas de `SetDeviceGammaRamp` por monitor.
- `%APPDATA%\FiltroLuz\config.json` → estado persistido (`Enabled`, `Intensity`).
- `Montar-Kit.ps1` → monta o kit de instalação portátil (o kit não é versionado, é gerado).
- `instalador\Nucleo.ps1` → funções compartilhadas: `Install-App`, `Uninstall-App`,
  `Stop-FilterInstance`, `Restore-Gamma`, `New-AppShortcut`, `New-LogoBitmap`.
- `instalador\Instalar.ps1` → janela do instalador (WinForms); aceita `-Silencioso -Destino`.
- `instalador\Desinstalar.ps1` → remoção; aceita `-Silencioso -ApagarConfig`.
- `instalador\Gerar-Icone.ps1` → gera o `Filtro Luz.ico` (multi-resolução, PNG embutido).
- `instalador\LEIA-ME.txt` → documentação do usuário final, copiada para a raiz do kit.

## Estado atual
Funciona e está em uso real (verificado em 2026-09-02): tray rodando, registrado no boot,
config persistida, dois monitores aplicando gamma sem erro (medido via
`GetDeviceGammaRamp`: com intensidade 60, verde a 80,8% e azul a 62,8% do vermelho, como
manda a fórmula do `GammaLib`).

O kit de instalação portátil está pronto e testado de ponta a ponta (instalar em pasta
escolhida, reinstalar por cima, desinstalar, restaurar cores). Falta apenas o agendamento
automático por horário — que é intencional, não é bug.

Instalação recomendada: **fora do repositório**. O boot grava caminho absoluto, então
apontar a chave `Run` para a pasta do repo faz um `git checkout` ou uma renomeação de
pasta quebrar o início automático em silêncio.

## Como rodar
```powershell
# Uso diário (bandeja, sem console visível)
.\Filtro Luz.vbs

# CLI, sem bandeja, útil para testar
.\FiltroLuz.ps1 -Intensidade 70
.\FiltroLuz.ps1 -Desligar

# Diagnóstico de falha de gamma por monitor
.\diag.ps1
```

## Armadilhas (não repita esses erros)
- `GetDC(NULL)` (DC genérico de tela cheia) falha com **erro 87** em drivers Intel Xe. A
  correção já aplicada é `CreateDC("\\.\DISPLAYn", ...)` por nome de monitor — não reverter
  essa abordagem sem entender o bug que ela resolve.
- f.lux e este filtro brigam pela mesma rampa de gamma da placa de vídeo (sobrescrita
  silenciosa, sem erro). O tray detecta e avisa, mas não impede a execução simultânea.
- Em `Toggle-Filter`, se `Set-BlueLightFilter` retornar 0 monitores aplicados, o código
  desfaz a mudança de `$script:Enabled` para o ícone não "mentir" sobre o estado — manter
  essa lógica em qualquer refatoração do toggle.
- A entrada de boot (`HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\FiltroLuz`) grava
  o **caminho absoluto** do `.vbs`. Mover/renomear a pasta quebra o boot automático até
  refazer o clique em "Iniciar com o Windows" ou editar a chave manualmente.
- **CONFIRMADO em 2026-09-02:** `Stop-Process -Force` no PID do tray **não** dispara o
  evento `PowerShell.Exiting`, e a tela fica presa no filtro. Medido: depois do kill, a
  rampa continuava em 80,8%/62,8% sem ninguém para restaurar. Por isso o instalador e o
  desinstalador chamam `Restore-Gamma` explicitamente depois de encerrar o processo —
  qualquer código que mate o tray tem a obrigação de fazer o mesmo.
- `Icon.ToBitmap()` do .NET Framework devolve **imagem corrompida** (ruído colorido) quando
  o `.ico` traz PNG embutido, que é o caso do nosso ícone. Na UI, desenhar a logo por GDI+
  em runtime (`New-LogoBitmap`) em vez de converter o `.ico`. Em `$form.Icon` o `.ico`
  funciona normalmente; o problema é só a conversão para bitmap.
- `.ps1` gravado **sem BOM** faz o PowerShell 5.1 estragar todos os acentos da interface
  ("Opções" virou "OpÃ§Ãµes"). Gravar sempre como UTF-8 **com** BOM — o `Montar-Kit.ps1` já
  reescreve os scripts do kit garantindo isso. Nos `.bat`, ao contrário, não usar acento
  nenhum: depende da página de código do console.
- **Nunca identificar o tray por menção na linha de comando.** `CommandLine -like
  '*FiltroLuz-Tray.ps1*'` casa com qualquer processo que apenas *cite* o nome — o próprio
  script que faz a busca, uma janela de PowerShell do usuário, outro instalador. Isso já
  matou um processo alheio durante os testes de 2026-09-02. O teste tem de ser estrutural,
  e é o que `Test-EhTrayDoFiltro` (em `Nucleo.ps1` e `Encerrar.ps1`) faz: `powershell.exe`
  com `-File` apontando para `FiltroLuz-Tray.ps1`, ou `wscript.exe` terminando em
  `Filtro Luz.vbs`. Proteger com `$PID` não basta: o processo alheio não é o próprio.
- No `.iss`, **não** usar `PrivilegesRequiredOverridesAllowed=dialog`: essa opção mostra a
  tela "Selecione o Modo de Instalação" antes de tudo, e ela aparece **mesmo com
  `/VERYSILENT`**, travando qualquer instalação automatizada (o Setup fica parado esperando
  clique, sem nem criar o log). Com `commandline`, quem precisar instala com `/ALLUSERS`.
- Não criar `.lnk` dentro do kit portátil: atalho guarda caminho absoluto e quebra assim que
  o kit muda de pasta ou vai para um pendrive. Os lançadores do kit são `.bat` com `%~dp0`.

## Como gerar o instalador (.exe)
Requer o Inno Setup 6 instalado (`ISCC.exe`). O `.exe` sai em `dist\`, que não é versionado.
```powershell
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" instalador\FiltroLuz.iss
```
Gera `Filtro Luz_Setup_v1.0.0.exe`: instalador único, em português, que não pede
administrador (vai para `%LOCALAPPDATA%\Programs\Filtro Luz` por padrão, com a pasta
editável na tela), cria os atalhos, registra o início automático e aparece em Programas e
Recursos com desinstalador próprio. Instalação/remoção sem interface:
```powershell
& ".\dist\Filtro Luz_Setup_v1.0.0.exe" /VERYSILENT /TASKS=desktopicon,startupicon
& "$env:LOCALAPPDATA\Programs\Filtro Luz\unins000.exe" /VERYSILENT
```
Ao mudar a versão, atualizar `#define AppVersao` no `.iss` (o `AppId` é fixo e nunca muda,
é ele que o Windows usa para reconhecer que é o mesmo programa).

## Como montar o kit de instalação (alternativa sem .exe)
Útil em máquina sem Inno Setup, ou para levar em pendrive.
```powershell
.\Montar-Kit.ps1                      # kit na Área de Trabalho
.\Montar-Kit.ps1 -Destino "E:\"       # kit num pendrive
.\Montar-Kit.ps1 -Zip                 # kit + .zip para enviar
```
O kit sai com `Instalar Filtro Luz.bat`, `Desinstalar Filtro Luz.bat`, `LEIA-ME.txt`,
`programa\` (o app + o `.ico`) e `instalador\`. Instalar sem janela, útil em vários PCs:
```powershell
.\instalador\Instalar.ps1 -Silencioso -Destino "C:\Caminho\Filtro Luz"
```

## Próximos passos
- Agendamento automático por horário (ex.: ligar sozinho ao anoitecer) — hoje é manual por design.
- Atalho de teclado global.
- Definir uma licença para o projeto.
- Mostrar a versão dentro do app (hoje ela aparece só no instalador e no `LEIA-ME.txt`);
  um item desabilitado no topo do menu do tray resolveria.
- Trava de instância única no tray: hoje nada impede duas cópias rodando e brigando pela
  mesma rampa de gamma.

## Git
Repositório público. Branch `main`.

## Regras de trabalho
- Responder sempre em **pt-BR**. Comentários de código em pt-BR, identificadores em inglês.
- Não usar emojis em UI/software.
- Avisar sobre riscos e trade-offs antes de agir; admitir incerteza em vez de chutar.
- Testar/validar antes de dizer que está pronto.
- **Repositório PÚBLICO:** nunca commitar dado pessoal, credencial, caminho interno de máquina ou informação de cliente/empresa.
- Terminar cada mensagem com um "📌 Resumo" breve.
