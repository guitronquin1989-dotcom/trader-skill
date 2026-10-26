# Sem agente nenhum: trader-skill direto no Terminal do Mac

Sim, roda sem Claude Code e sem OpenCode. As 11 skills são, no fundo,
duas coisas: um texto de método (`SKILL.md`, feito para um agente ler)
e uma ferramenta em Python puro por pasta. As ferramentas não sabem
nem ligam quem as chamou. Sem agente, **você** faz o papel dele: roda
os comandos na ordem, lê as saídas e os links, decide e, se for o
caso, digita a ordem no app da corretora com as próprias mãos.

Para não decorar 11 caminhos de script, este repo traz o `trader.sh`,
um atalho de terminal em português. Não precisa instalar skill em
lugar nenhum: o próprio clone serve.

## Instalação guiada no Mac (uma vez)

```bash
# 1. baixe o codigo
git clone -b arena/23cdc45d-trader-skill https://github.com/guitronquin1989-dotcom/trader-skill.git ~/trader-skill
cd ~/trader-skill

# 2. instale SOMENTE o modo Terminal
bash instalar-terminal-mac.sh --checar
```

O instalador pergunta seu nome, email e orçamento de teste, cria
`~/trader-projeto/trader/config.json` sempre com `"paper": true`,
cria o comando global `trader` e testa as fontes ao vivo. Ele não
instala nem copia nada para Claude ou OpenCode.

Feche e abra o Terminal ao final. Depois:

```bash
cd ~/trader-projeto
trader ajuda
trader relogio
trader manha
```

Se o primeiro `git` ou `python3` abrir a janela da Apple oferecendo
as Command Line Tools, aceite, espere a instalação terminar e rode o
comando de novo. Sem o atalho global, o caminho `bash ~/trader-skill/trader.sh ...`
continua funcionando.

Requer só Python 3.8+ (`python3 --version`). Nada de pip install.

## O mapa: skill vira comando

| skill (com agente) | no terminal | o que faz |
| --- | --- | --- |
| trader-copycat | `trader.sh achar buffett` depois `trader.sh copiar 1067983 --top 5` | 13F da SEC vira `trader/targets.json` |
| trader-news | `trader.sh noticias` | manchetes Yahoo + 8-Ks da SEC dos seus tickers |
| trader-pelosi | `trader.sh pelosi` | PTRs novos da pelosi (Congresso) |
| trader-analyst | `trader.sh analista AAPL KO` | trimestrais direto do XBRL da SEC |
| trader-screener | `trader.sh filtrar` | suas regras sobre `trader/metrics.json` |
| trader-alerts | `trader.sh relogio`, `trader.sh precos`, `trader.sh alertas` | NYSE aberta?, cotações, seus alvos |
| trader-budget | `trader.sh orcamento 5000` | propostas em `trader/orders.json` |
| trader-risk | `trader.sh risco` | PASS/BLOCK por ordem contra seu config |
| trader-broker | `trader.sh tickets` | os tickets para você digitar na corretora |
| trader-rebalance | `trader.sh rebalancear 5` | desvio em relação ao alvo |
| trader-tax | `trader.sh impostos` | lotes, ganhos, perdas |

Atalhos: `trader.sh manha` (relógio + preços + notícias + congresso),
`trader.sh fluxo 5000` (preços, orçamento, risco, tickets) e
`trader.sh menu` (menu numerado). Todos aceitam os argumentos extras
da ferramenta original; e o caminho cru continua valendo, ex.:
`python3 ~/trader-skill/trader-news/news.py --tickers AAPL --hours 24`.

## Um dia típico, só no terminal

```bash
cd ~/trader-projeto
trader manha
# leia os links que importam (8-K manda mais que manchete)

trader fluxo 5000
# confira cada PASS/BLOCK com calma; BLOCK nao se discute, se corrige
```

Exemplo de saída do `fluxo` com conta zerada (a mesma demo do repo):
AAPL US$ 1.250, AXP US$ 1.119, GOOGL US$ 823, KO US$ 708, BAC
US$ 600, os cinco PASS, US$ 500 de buffer em caixa e cinco tickets
READY. **Nada foi comprado**: ticket é um papelzinho bem feito.

## E a ordem de verdade, sem agente?

O `ticket.py` nunca fala com corretora, com ou sem agente. No modo
terminal a execução é 100% manual, o que muita gente prefere:

1. `trader.sh tickets`: escolha **uma** ordem READY.
2. Abra o app/site da sua corretora (**conta paper** nas fases de
   teste) e digite exatamente o que o ticket diz: símbolo, lado,
   valor (notional) ou quantidade, mercado, validade do dia.
3. Enviou e executou? Registre para o histórico e para o imposto:
   `bash ~/trader-skill/trader.sh ticket result --index 1 --status placed --broker-id <id da corretora>`
   e, com o preço executado,
   `bash ~/trader-skill/trader.sh ticket fill --symbol AAPL --side buy --qty 3.6628 --price 341.27`
   (isso alimenta `trader/portfolio.json`, que risk, tax e rebalance leem).
4. Não enviou? Então não registre nada. Ordem nova ou editada passa
   pelo `risco` de novo, sempre.

As fases do `RODAR-LOCAL.md` valem iguais aqui: leitura ao vivo,
paper por semanas com checklist, e dinheiro real só no fim, mínimo,
com os limites apertados. A diferença é que, sem MCP de corretora,
nem existe botão automático para apertar sem querer.

## O que você perde sem um agente (seja honesto consigo)

- **Síntese:** ninguém lê o 8-K e resume "o que muda para você". Você
  clica nos links e lê. As ferramentas mostram os números e as tags.
- **Encadeamento automático:** ninguém percebe que falta preço ou
  que o targets está velho. A ordem dos comandos é sua (o `fluxo` e o
  `manha` cobrem o caminho feliz).
- **Linguagem natural:** "copia o Ackman" vira `achar ackman` e
  `copiar 1336528 --top 5`. Menos mágico, mais explícito.
- **Vigília agendada do chat:** sem `/loop`. Se quiser o briefing
  sozinho, agende a leitura (nunca ordens) no macOS, ex. no crontab:
  `30 8 * * 1-5 cd ~/trader-projeto && bash ~/trader-skill/trader.sh manha >> ~/trader-projeto/manha.log 2>&1`

O que você ganha: zero assinatura de agente, zero chave de API de
modelo, tudo auditável no seu terminal e nenhum software entre você
e o botão de comprar além da própria corretora.

## Se travar

- `trader.sh ajuda` lista tudo; cada ferramenta tem `--help` próprio.
- Erro de User-Agent: falta o `sec_user_agent` no config (Fase 0).
- Preço faltando no risk/rebalance: rode `trader.sh precos` antes.
- BLOCK sem entender: a mensagem diz a regra e o número; não afrouxe
  limite no impulso, leia a seção de checks em `trader-risk/SKILL.md`.
- Os `SKILL.md` continuam sendo a documentação do método: mesmo sem
  agente, vale lê-los como manual (as regras de segurança estão lá).

Isto não é consultoria financeira. Paper primeiro, sempre. Guias:
`RODAR-LOCAL.md`, `COMECE-AQUI-MAC.md`, `OPENCODE.md`.
