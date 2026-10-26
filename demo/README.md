# Demo offline (rodada de verdade, log em DEMO-LOG.txt)

Esta pasta é um projeto de exemplo já preenchido e executado com as
skills **instaladas** (de `~/.claude/skills/`), não com os scripts do
repo. É o exemplo do README: copiar o top 5 da Berkshire Hathaway
(13F do Q2 2026, período 2026-06-30, protocolado em 2026-08-14) com
US$ 5.000, buffer de caixa de 10% e teto de 25% por ação.

Nada aqui é ordem de verdade: `size.py`, `check.py` e `ticket.py` só
escrevem arquivos locais em `trader/` e mostram tickets. Conta paper.

## O que tem em trader/

| arquivo | de onde veio | o que é |
| --- | --- | --- |
| `config.json` | `trader-budget/config.example.json` | orçamento, tetos, `paper: true` |
| `targets.json` | `trader-copycat/targets.example.json` | saída real do 13F (pesos top 5) |
| `prices.json` | fixture de testes (fechamento 2026-10-13) | preços usados nas contas |
| `orders.json` | **gerado** por `size.py --write` | 5 propostas de compra |
| `state/risk.json` | **gerado** por `check.py` | vereditos PASS/BLOCK |
| `metrics.json`, `rules.json` | exemplos de analyst/screener | entrada do screener |
| `alerts.json` | `trader-alerts/alerts.example.json` | regras de alerta de exemplo |
| `portfolio-tax-example.json` | `trader-tax/portfolio.example.json` | lotes do exemplo de tax/rebalance |

## Resultado (resumo do DEMO-LOG.txt)

- budget: AAPL US$ 1.250 (teto de 25%), AXP US$ 1.119, GOOGL US$ 823,
  KO US$ 708, BAC US$ 600; US$ 500 em caixa, US$ 0 parado.
- risk: 5 PASS, 0 BLOCK (conta paper nova de US$ 5.000).
- broker: 5 tickets READY, cada um esperando um `yes` separado.
- alerts: relógio da NYSE funcionando (2026-10-26, antes da abertura).
- screener: 2 de 5 passam nas regras do exemplo (GOOGL e KO).
- tax/rebalance: ganhos zerados no dia da compra; desvio dentro da
  banda de 5 pontos, nenhum trade proposto.
- apêndice: analyst (AAPL via XBRL da SEC), pelosi (parse de PTR real)
  e news (manchetes) rodando sobre fixtures reais, sem rede.

## Como rodar de novo na sua máquina

Dentro desta pasta `demo/` (depois de instalar com `../install.sh` ou
`../install.ps1`):

```bash
python3 ~/.claude/skills/trader-budget/size.py --budget 5000 --write
python3 ~/.claude/skills/trader-risk/check.py
python3 ~/.claude/skills/trader-broker/ticket.py show
python3 ~/.claude/skills/trader-alerts/alerts.py clock
python3 ~/.claude/skills/trader-screener/screen.py trader/metrics.json --rules trader/rules.json --prices trader/prices.json
```

No Windows, troque `python3` por `python` e `/` por `\`.

Os preços em `prices.json` são de 2026-10-13 (fixture). Com rede, o
`/trader-alerts` atualiza preços de verdade e o `/trader-copycat` baixa
o 13F mais recente direto da SEC. Veja o guia completo em
`../INSTALACAO.md`.
