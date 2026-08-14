# Filtro Luz

Filtro de luz azul para Windows, em **PowerShell puro** — sem instalador, sem dependências, sem serviço em segundo plano.

## O que faz

Reduz a componente azul da tela ajustando a rampa de gamma da placa de vídeo, no estilo do f.lux ou do "Luz noturna" do Windows. Roda como um ícone na bandeja do sistema, com controle manual de intensidade e estado que sobrevive a reinícios.

Funciona onde a Luz Noturna do Windows às vezes não funciona: monitores externos, drivers que ignoram a configuração do sistema, ou máquinas onde o recurso está desabilitado por política.

## Características

- **PowerShell puro** — nenhuma dependência externa, nenhum executável para instalar.
- **Multi-monitor** — aplica em todos os monitores detectados, um a um.
- **Ícone na bandeja** — liga/desliga e ajusta intensidade com um clique.
- **Estado persistido** — reabre com a última configuração usada.
- **Início automático opcional** — registra no boot só se você pedir.
- **Modo CLI** — dá para usar em script, sem bandeja.
- **Ferramenta de diagnóstico** inclusa, para quando um monitor específico recusa o ajuste de gamma.

## Requisitos

- Windows com PowerShell 5.1 (o que já vem no sistema — não precisa do PowerShell 7)
- Nenhuma dependência adicional

## Uso

```powershell
# Uso diário: bandeja, sem janela de console
.\Filtro Luz.vbs

# CLI, sem bandeja
.\FiltroLuz.ps1 -Intensidade 70
.\FiltroLuz.ps1 -Desligar

# Diagnóstico, quando algum monitor não aceita o ajuste
.\diag.ps1
```

A configuração fica em `%APPDATA%\FiltroLuz\config.json`.

## Estrutura

| Arquivo | Papel |
|---|---|
| `GammaLib.ps1` | Núcleo: classe `GammaCtl`, `Get-DisplayDevices`, `Set-BlueLightFilter` |
| `FiltroLuz-Tray.ps1` | Aplicação principal, ícone na bandeja |
| `FiltroLuz.ps1` | Versão CLI, sem interface |
| `Filtro Luz.vbs` | Lançador silencioso (sem console piscando) |
| `diag.ps1` | Diagnóstico de falha de gamma por monitor |

## Detalhes técnicos

O ajuste usa `SetDeviceGammaRamp` da `gdi32.dll` via P/Invoke.

Um detalhe importante: usar `GetDC(NULL)` (o DC genérico da tela inteira) **falha com erro 87 em drivers Intel Xe**. A solução implementada é criar um DC por monitor com `CreateDC("\\.\DISPLAYn", ...)`, que funciona de forma consistente. Se for refatorar, não volte para o `GetDC(NULL)` sem entender esse bug.

## Limitações conhecidas

- **Windows apenas** — usa APIs GDI.
- **Conflito com f.lux** — os dois disputam a mesma rampa de gamma e um sobrescreve o outro silenciosamente. A bandeja detecta e avisa, mas não impede.
- **Sem agendamento por horário** — o controle é manual por design; não liga sozinho ao anoitecer.
- **O início automático grava o caminho absoluto** — mover ou renomear a pasta quebra o boot até reconfigurar.

## Licença

Sem licença definida ainda. Enquanto isso, todos os direitos reservados ao autor.
