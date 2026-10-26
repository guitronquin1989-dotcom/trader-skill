# trader-skill: instalação e primeira execução (português)

Este repositório é um pacote de **11 skills do Claude** (pastas `trader-*`,
cada uma com um `SKILL.md` e uma ferramenta em Python puro). Não é um site
nem um servidor: "instalar e rodar" significa copiar essas 11 pastas para
onde o Claude Code procura skills e depois chamar, por exemplo,
`/trader-copycat` no chat. Não precisa de `pip install` (só a biblioteca
padrão do Python 3.8+), não precisa de chave de API e, por padrão, tudo é
**paper trading** (dinheiro de mentira). Nenhuma ordem é enviada sem você
digitar `yes` para aquela ordem exata.

> Aviso rápido sobre o ambiente Arena: o assistente roda numa máquina
> isolada na nuvem, não no seu computador. Ele instalou e testou tudo lá
> dentro (veja `demo/DEMO-LOG.txt`), mas o último clique, o de instalar na
> **sua** máquina, precisa ser seu. Este guia faz isso em 1 comando.

## O que você precisa

1. **Claude Code** instalado (é onde as skills `/trader-*` aparecem).
   Sem Claude Code, veja a seção "Sem Claude Code" no fim.
2. **Python 3.8 ou mais novo** no PATH (`python3 --version` no Mac/Linux,
   `python --version` no Windows).
3. Uma pasta de projeto onde a pasta `trader/` vai morar (é lá que as
   skills gravam `targets.json`, `orders.json` etc.). Pode ser qualquer
   pasta, inclusive uma vazia só para isso.

## Opção A (recomendada): 1 comando com o instalador deste repo

Primeiro baixe o repo, se ainda não baixou:

```bash
git clone https://github.com/Jakeschincariol/trader-skill.git
cd trader-skill
```

### Mac / Linux

```bash
chmod +x install.sh
./install.sh            # instala em ~/.claude/skills/ e roda os 175 testes
./install.sh --demo     # idem, e ainda roda a demo offline (Berkshire, US$ 5.000)
./install.sh --project  # instala só neste projeto, em ./.claude/skills/
```

### Windows (PowerShell)

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Demo
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Project
```

Ou dê dois cliques em `install.bat` (ele chama o `install.ps1`).

O instalador: confere o Python, copia as 11 pastas `trader-*` para
`~/.claude/skills/` (Windows: `%USERPROFILE%\.claude\skills\`), faz backup
de uma instalação anterior se existir, roda os testes offline e um smoke
test com a cópia instalada (`trader-alerts clock` e
`trader-copycat find buffett`). Sem `sudo`, sem `pip install`.

## Opção B: plugin oficial do Claude Code (2 comandos)

Dentro do Claude Code:

```text
/plugin marketplace add Jakeschincariol/trader-skill
/plugin install trader-skill@trader-skill
```

Instalado assim, os comandos ganham prefixo: `/trader-skill:trader-copycat`
e assim por diante. Se você quer o nome curto (`/trader-copycat`), use a
Opção A ou a C.

## Opção C: manual (é literalmente copiar pastas)

```bash
# Mac / Linux: global
cp -r trader-skill/trader-* ~/.claude/skills/
# Mac / Linux: só neste projeto
cp -r trader-skill/trader-* /caminho/do/seu/projeto/.claude/skills/
```

```powershell
# Windows: global
Copy-Item -Recurse trader-skill\trader-* $HOME\.claude\skills\
```

## Depois de instalar: configuração obrigatória (1 minuto)

1. **Feche e abra o Claude Code de novo.** Ele só descobre skills novas
   ao iniciar.
2. No seu projeto, crie `trader/config.json` copiando
   `trader-budget/config.example.json` e ajuste:

   ```json
   {
     "budget": 5000,
     "cash_buffer_pct": 10,
     "max_position_pct": 25,
     "paper": true,
     "sec_user_agent": "Seu Nome voce@exemplo.com"
   }
   ```

   A linha `sec_user_agent` é exigência da SEC (o órgão americano que
   publica os dados): todo programa precisa se identificar com nome e
   email. Use o seu de verdade, só nesse arquivo local (ou na variável
   de ambiente `SEC_USER_AGENT`). Sem isso, as ferramentas que falam com
   a SEC (`copycat`, `analyst`, `news`, `pelosi`) recusam rodar e avisam.
   Mantenha `"paper": true` até entender bem o fluxo.

## Primeira execução (o exemplo do README, passo a passo)

No chat do Claude Code, dentro do seu projeto:

1. `/trader-copycat` com algo como "copy Berkshire top 5".
   Ele lê o 13F mais recente da Berkshire Hathaway na SEC, monta os
   pesos e grava `trader/targets.json`. Atenção: 13F é foto do fim do
   trimestre, publicada até 45 dias depois. A skill sempre diz a data.
2. `/trader-budget` com o seu orçamento.
   Com US$ 5.000, buffer de caixa de 10% e teto de 25% por ação, ele
   propõe: AAPL US$ 1.250 (no teto), AXP US$ 1.119, GOOGL US$ 823,
   KO US$ 708, BAC US$ 600, US$ 500 em caixa. Grava `trader/orders.json`
   como **proposta**. Nada foi comprado.
3. `/trader-risk` confere cada proposta contra os seus limites e
   responde PASS ou BLOCK, com o motivo.
4. `/trader-broker` mostra um ticket por vez ("Buy $1,250 of AAPL,
   market, day"). Só depois do seu `yes` para **aquela** ordem, e só se
   você tiver conectado uma corretora (o servidor MCP da Alpaca, em
   conta paper por padrão; veja `trader-broker/SKILL.md` e
   `trader-broker/claude_desktop_config.example.json`), é que algo sai
   da sua máquina. Sem corretora conectada, o fluxo para no ticket, e
   isso é ótimo para aprender.

Atalhos do dia a dia: `/trader-news` (manchetes e 8-Ks das suas ações),
`/trader-pelosi` (negócios divulgados por membros do Congresso dos EUA),
`/trader-alerts` (alvos de preço e o sino de abertura da NYSE),
`/trader-analyst` (resultados trimestrais direto da SEC),
`/trader-screener` (suas regras de seleção), `/trader-tax` (lotes,
ganhos, colheita de prejuízos), `/trader-rebalance` (voltar aos pesos
alvo quando a carteira desvia).

### Sem o Claude, direto no terminal (as ferramentas são scripts comuns)

```bash
python3 ~/.claude/skills/trader-copycat/edgar13f.py find buffett
python3 ~/.claude/skills/trader-copycat/edgar13f.py --help
python3 ~/.claude/skills/trader-analyst/facts.py AAPL
python3 ~/.claude/skills/trader-alerts/alerts.py clock
python3 ~/.claude/skills/trader-pelosi/ptr.py index --member pelosi
python3 ~/.claude/skills/trader-budget/size.py --budget 5000 --write
python3 ~/.claude/skills/trader-risk/check.py
python3 ~/.claude/skills/trader-broker/ticket.py show
```

No Windows, troque `python3` por `python` e as barras por `\`.

Para reproduzir a demo offline que foi rodada no Arena, veja
`demo/README.md` e o log completo em `demo/DEMO-LOG.txt`.

## Sem Claude Code

Cole o conteúdo de qualquer `SKILL.md` no topo de uma conversa (por
exemplo, no Claude Desktop ou no chat web): a skill vira um "modo" e o
método funciona, mas você perde as ferramentas em Python (quem baixa os
dados da SEC é o script, não o chat). Para dados de verdade, rode os
scripts no terminal como acima e cole a saída na conversa.

## Problemas comuns

- **A skill não aparece no Claude Code.** Você reiniciou o Claude Code
  depois de instalar? Confira se as pastas estão em `~/.claude/skills/`
  (uma pasta por skill, cada uma com `SKILL.md` dentro, sem uma pasta
  `trader-skill` extra no meio do caminho). Instalou como plugin? O
  nome vira `/trader-skill:trader-copycat`.
- **`python3: command not found` / Python não encontrado.** Instale em
  https://www.python.org/downloads/ (no Windows, marque "Add python.exe
  to PATH") e abra um terminal novo.
- **Windows: "o script não pode ser carregado" (ExecutionPolicy).** Rode
  com o comando da Opção A (`-ExecutionPolicy Bypass -File ...`), que
  libera só aquele processo, ou use o `install.bat`.
- **Erro pedindo User-Agent da SEC.** Falta o passo 2 da configuração:
  defina `sec_user_agent` em `trader/config.json` ou a variável
  `SEC_USER_AGENT`, com seu nome e email reais.
- **Os dados "ao vivo" falham atrás de firewall/VPN.** As fontes são
  públicas e gratuitas (SEC EDGAR, Câmara dos EUA, RSS de notícias,
  endpoint de gráficos do Yahoo, que é não oficial e pode mudar).
  Confira qualquer número importante na sua corretora antes de agir.
- **Quero desinstalar.** Apague as 11 pastas `trader-*` de
  `~/.claude/skills/` (ou de `.claude/skills/` do projeto) e a pasta
  `trader/` do seu projeto, se não quiser mais os arquivos gerados.

## Segurança e letras miúdas (leia, é curto)

- **Não é consultoria financeira.** É software que lê dados públicos e
  faz contas. Copiar um investidor não copia o resultado dele. Você
  pode perder dinheiro. Em caso de dúvida, fale com um profissional
  habilitado. O mesmo vale para impostos: `/trader-tax` faz a aritmética,
  não dá parecer tributário.
- **Nenhuma ordem sem o seu sim.** Só `/trader-broker` pode levar a uma
  ordem, depois que `/trader-risk` aprovar aquela ordem exata e você
  digitar `yes`. Na corretora, deixe a ferramenta de ordens como "Needs
  approval" (nunca "Always allow"), para o cartão "Allow once / Deny"
  do Claude ser uma segunda trava.
- **Paper primeiro.** `"paper": true` é o padrão. Chaves de corretora
  ficam em variáveis de ambiente, nunca no chat nem em arquivo do repo.
- **13F é velho e parcial:** só posições compradas em ações listadas nos
  EUA, foto do fim do trimestre. **Congresso:** as divulgações são
  públicas por lei (STOCK Act), com valores em faixas e atraso de até
  45 dias. Nada aqui é informação privilegiada.

## Verificação rápida de que está tudo de pé

```bash
python3 -m unittest discover -s tests -v   # dentro do repo: 175 testes offline
python3 ~/.claude/skills/trader-alerts/alerts.py clock
python3 ~/.claude/skills/trader-copycat/edgar13f.py find buffett
```

Se os três comandos acima funcionam, a instalação está pronta. Bom uso,
com calma e em modo paper.
