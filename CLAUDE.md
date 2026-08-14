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
- Sem dependências externas, sem internet, sem instalador.

## Arquivos-chave
- `GammaLib.ps1` → núcleo/biblioteca: classe `GammaCtl`, `Get-DisplayDevices`, `Set-BlueLightFilter -On -Level`.
- `FiltroLuz-Tray.ps1` → app principal (bandeja/system tray), o que roda no dia a dia.
- `FiltroLuz.ps1` → versão CLI, sem bandeja (`-Intensidade N` / `-Desligar`).
- `Filtro Luz.vbs` → lançador silencioso (sem janela de console), usado no boot.
- `diag.ps1` → ferramenta de diagnóstico para falhas de `SetDeviceGammaRamp` por monitor.
- `%APPDATA%\FiltroLuz\config.json` → estado persistido (`Enabled`, `Intensity`).

## Estado atual
Funciona e está em uso real (verificado em 2026-08-14): tray rodando, registrado no boot,
config persistida, múltiplos monitores detectados e aplicando gamma sem erro. Falta:
agendamento automático por horário (intencional, não é bug) e instalador/empacotamento
(hoje é só copiar a pasta e rodar o `.vbs`).

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
- A confirmar: se `Stop-Process -Force` no PID do tray pode não disparar o evento
  `PowerShell.Exiting` e deixar a tela "presa" no filtro (sem caso conhecido registrado).

## Próximos passos
- Agendamento automático por horário (ex.: ligar sozinho ao anoitecer) — hoje é manual por design.
- Instalador/empacotamento formal (hoje é só copiar a pasta).
- Atalho de teclado global.
- Definir uma licença para o projeto.

## Git
Repositório público. Branch `main`.

## Regras de trabalho
- Responder sempre em **pt-BR**. Comentários de código em pt-BR, identificadores em inglês.
- Não usar emojis em UI/software.
- Avisar sobre riscos e trade-offs antes de agir; admitir incerteza em vez de chutar.
- Testar/validar antes de dizer que está pronto.
- **Repositório PÚBLICO:** nunca commitar dado pessoal, credencial, caminho interno de máquina ou informação de cliente/empresa.
- Terminar cada mensagem com um "📌 Resumo" breve.
