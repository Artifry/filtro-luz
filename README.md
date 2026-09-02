# Filtro Luz

Filtro de luz azul para Windows, em **PowerShell puro** — sem dependências, sem serviço em segundo plano e sem nada compilado (o instalador também é PowerShell).

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

## Instalação

### Instalador único (.exe)

Requer o [Inno Setup 6](https://jrsoftware.org/isinfo.php) para gerar:

```powershell
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" instalador\FiltroLuz.iss
```

Sai `dist\Filtro Luz_Setup_v1.0.0.exe` — um arquivo só, para levar a qualquer PC com
Windows. Está em português, **não pede administrador** (instala na pasta do usuário, e a
pasta é editável na tela), cria os atalhos, registra o início automático se você marcar, e
aparece em "Programas e Recursos" com desinstalador próprio, que também devolve as cores da
tela. Para automatizar em vários computadores:

```powershell
& ".\dist\Filtro Luz_Setup_v1.0.0.exe" /VERYSILENT /TASKS=desktopicon,startupicon
```

### Kit portátil (sem .exe)

Não precisa de nada instalado além do Windows. Monte o kit e rode o instalador de dentro dele:

```powershell
.\Montar-Kit.ps1                   # gera "Kit Filtro Luz" na Área de Trabalho
.\Montar-Kit.ps1 -Destino "E:\"    # ou direto num pendrive
.\Montar-Kit.ps1 -Zip              # com um .zip pronto para enviar
```

No kit, dois cliques em `Instalar Filtro Luz.bat`. O instalador deixa escolher a pasta,
cria os atalhos com ícone, registra o início automático e abre o programa — tudo dentro da
conta do usuário, sem pedir administrador. `Desinstalar Filtro Luz.bat` desfaz tudo e
devolve as cores da tela.

Para instalar em vários computadores, sem janela:

```powershell
.\instalador\Instalar.ps1 -Silencioso -Destino "C:\Caminho\Filtro Luz"
.\instalador\Desinstalar.ps1 -Silencioso
```

Instale **fora da pasta do repositório**: o início automático guarda o caminho absoluto,
então trocar de branch ou renomear a pasta quebraria o boot em silêncio.

Também dá para usar sem instalar nada — é só rodar da pasta do projeto:

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
| `Montar-Kit.ps1` | Monta o kit de instalação portátil |
| `instalador/FiltroLuz.iss` | Script do Inno Setup que gera o instalador único (`.exe`) |
| `instalador/Encerrar.ps1` | Encerra o filtro e devolve as cores; usado pelo Setup e pela remoção |
| `instalador/` (resto) | Instalador/desinstalador em WinForms, gerador do ícone e o `LEIA-ME.txt` |

Nem o `.exe` nem o kit são versionados: os dois são gerados a partir destes arquivos, para
não existirem cópias dos mesmos scripts para manter em paralelo.

## Detalhes técnicos

O ajuste usa `SetDeviceGammaRamp` da `gdi32.dll` via P/Invoke.

Um detalhe importante: usar `GetDC(NULL)` (o DC genérico da tela inteira) **falha com erro 87 em drivers Intel Xe**. A solução implementada é criar um DC por monitor com `CreateDC("\\.\DISPLAYn", ...)`, que funciona de forma consistente. Se for refatorar, não volte para o `GetDC(NULL)` sem entender esse bug.

## Limitações conhecidas

- **Windows apenas** — usa APIs GDI.
- **Conflito com f.lux** — os dois disputam a mesma rampa de gamma e um sobrescreve o outro silenciosamente. A bandeja detecta e avisa, mas não impede.
- **Sem agendamento por horário** — o controle é manual por design; não liga sozinho ao anoitecer.
- **O início automático grava o caminho absoluto** — mover ou renomear a pasta quebra o boot até reconfigurar.
- **Encerrar o processo à força deixa a tela filtrada** — matar o tray pelo Gerenciador de Tarefas não dispara a restauração das cores. Abrir de novo e usar "Sair (restaura as cores)" resolve; o instalador e o desinstalador já restauram sozinhos.
- **Nada impede duas cópias rodando** — as duas disputam a mesma rampa de gamma.

## Licença

Sem licença definida ainda. Enquanto isso, todos os direitos reservados ao autor.
