# Rodar local no seu Mac: ao vivo, testes, e só depois dinheiro real

Este é o roteiro completo para sair do sandbox e rodar na sua máquina,
com internet de verdade. A ordem das fases não é burocracia: cada fase
prova uma coisa antes de você arriscar a próxima.

- **Fase 1 (leitura ao vivo):** notícias, SEC, preços. Zero corretora.
- **Fase 2 (paper de ponta a ponta):** conta de mentira na corretora,
  fluxo inteiro, incluindo errar de propósito para ver as travas.
- **Fase 3 (dinheiro real):** só depois do checklist, começando mínimo.

Isto é ferramenta e educação, **não é consultoria financeira**. Nada
aqui promete retorno, copiar investidor não copia resultado, e você
pode perder dinheiro, inclusive tudo o que colocar. Só avance para a
Fase 3 com dinheiro cuja perda total não muda sua vida, e considere
falar com um profissional habilitado (inclusive sobre impostos no seu
país de residência fiscal).

## Fase 0: base instalada (15 min)

Siga `COMECE-AQUI-MAC.md` (Claude Code) ou `OPENCODE.md` (OpenCode).
Sem agente nenhum também dá: `TERMINAL.md` roda tudo pelo terminal
com o `trader.sh` (instalador próprio: `instalar-terminal-mac.sh`),
e a "corretora" da Fase 2 vira você digitando os tickets no app
dela (o resto das fases não muda).
Para a fase de corretora, o desenho de segurança deste pacote foi
feito para o caminho Claude (três portões: PASS do risk, seu `yes` no
chat e o cartão Allow once/Deny com a ferramenta em "Needs approval").
No OpenCode as Fases 1 e 2 funcionam igual; conectar corretora nele é
configuração manual própria, então o roteiro de corretora abaixo usa
Claude Desktop/Code, como a skill `trader-broker` descreve.

Crie seu projeto e config (uma vez):

```bash
mkdir -p ~/trader-projeto/trader
cp ~/trader-skill/trader-budget/config.example.json ~/trader-projeto/trader/config.json
open -e ~/trader-projeto/trader/config.json
```

Ajuste: seu `budget` de teste, `"paper": true` (não toque nisso até a
Fase 3) e `"sec_user_agent": "Seu Nome voce@exemplo.com"` com seus
dados reais. Sem esse User-Agent, a SEC recusa as chamadas.

## Fase 1: leitura ao vivo (fique aqui pelo menos 1 a 2 semanas)

Primeiro, o verificador somente-leitura:

```bash
cd ~/trader-projeto
bash ~/trader-skill/checar-ambiente.sh --full
```

Ele confere Python, skills, config e o acesso às fontes públicas
(SEC EDGAR, Yahoo RSS de notícias, Yahoo/Stooq de preços) e roda
`clock`, `quote` e `news` sem gravar ordem nenhuma. Tem que terminar
sem FALHAs. Depois, a rotina diária dentro do Claude/OpenCode (sempre
a partir de `~/trader-projeto`):

1. **Copiar um investidor (dados reais da SEC):** `/trader-copycat`
   com "copy Berkshire top 5". Isto baixa o 13F mais recente e grava
   `trader/targets.json`. Lembre: 13F é foto do fim do trimestre.
2. **Notícias de tudo que você acompanha:** `/trader-news`. Fontes:
   RSS de manchetes do Yahoo por ticker + 8-Ks da SEC por empresa.
   "Todas as notícias" aqui significa: todos os tickers do seu
   `portfolio.json` ou `targets.json` (ou os que você passar, ex.:
   `--tickers AAPL MSFT NVDA`). Manchete é pista, não fato: abra a
   matéria ou o filing; se divergirem, vale o filing. Para vigiar
   durante o pregão, a própria skill sugere `/loop 30m /trader-news`
   ou uma tarefa agendada de manhã.
3. **Congresso:** `/trader-pelosi` (divulgações públicas, com atraso
   legal de até 45 dias).
4. **Resultados e seleção:** `/trader-analyst` nos seus tickers e
   `/trader-screener` com as suas regras.
5. **Preços frescos:** `/trader-alerts` (`quote --holdings --write`
   atualiza `trader/prices.json`; cotações gratuitas são atrasadas e
   o Yahoo é fonte não oficial: confira na corretora o que importar).
6. **Simule o dinheiro:** `/trader-budget` e `/trader-risk` sobre os
   dados reais. Nesta fase, pare no ticket do `/trader-broker`.

Saída da Fase 1: você sabe de onde vem cada número, já viu notícia
ruim e boa sem apertar botão nenhum, e o `checar-ambiente.sh` passa.

## Fase 2: paper de ponta a ponta (mínimo: vários ciclos completos)

Agora sim corretora, mas de mentira. Resumo fiel do `trader-broker`:

1. Crie a conta na Alpaca e gere **chaves de paper trading** (são
   chaves separadas das reais). Confirme antes se a corretora aceita
   residentes no seu país e quais são suas obrigações fiscais locais
   sobre investimento no exterior. A alternativa coberta pela skill
   é a Interactive Brokers (conector verificado; as ordens vão para
   sua aprovação dentro da IBKR; use `"broker": "ibkr"` e, se ela
   pedir quantidade de ações, `--whole-shares`).
2. Instale o `uv` (docs.astral.sh/uv). No Claude Desktop: Settings >
   Developer > Edit Config (no Mac, `~/Library/Application Support/Claude/claude_desktop_config.json`)
   e cole o bloco de `trader-broker/claude_desktop_config.example.json`,
   digitando **suas chaves paper nesse arquivo, e em nenhum outro
   lugar**. Chave nunca vai no chat: se colar uma sem querer, apague
   a mensagem e gere chaves novas. Reinicie o Claude Desktop. No
   Claude Code, mantenha a ferramenta de ordem em "ask" no
   `.claude/settings.json`, nunca em "allow".
3. Permissões das ferramentas (Customize > Connectors > alpaca):
   - `place_stock_order` e tudo que coloca/altera/cancela/fecha:
     **Needs approval**, nunca "Always allow";
   - opções, cripto, `close_all_positions`, `cancel_all_orders`,
     `exercise_options_position`: **Blocked**;
   - leitura (`get_account_info`, `get_all_positions`, snapshots):
     pode deixar livre.
4. Pergunte as informações da conta (só leitura) e confirme **no
   painel da Alpaca** que é a conta paper.
5. Rode ciclos completos: copycat, alerts (preços), budget, risk,
   broker (approve, result, fill). Teste também o caminho do não:
   aperte Deny uma vez, force um BLOCK (ex.: ordem acima do seu
   `max_order_usd`), e confira que ordem negada/falhada não é
   reenviada sem novo risk e novo `yes`. Depois exercite
   `/trader-rebalance` e `/trader-tax` sobre os fills paper e
   reconcilie `trader/portfolio.json` com o painel da corretora.

### Checklist de saída da Fase 2 (tudo "sim", por escrito)

- [ ] `checar-ambiente.sh` sem FALHAs e briefing de notícias diário rodando
- [ ] Pelo menos 4 semanas e vários ciclos paper completos, com diário
- [ ] Vi PASS, BLOCK, Deny e um erro, e sei explicar cada um
- [ ] Posições e caixa no `portfolio.json` batem com o painel paper
- [ ] Sei exatamente quais são meus limites e por que (não os do exemplo)
- [ ] Nenhuma chave em chat, print ou git; backup da pasta `trader/`
- [ ] Estratégia, horizonte e perda máxima aceitável escritos por mim
- [ ] Impostos e obrigações do meu país revisados com um profissional

## Fase 3: dinheiro real (sua decisão, suas mãos, valor mínimo)

Nenhuma skill vira esta chave por você: a `trader-broker` nunca troca
paper por live. Quem troca é você, digitando nos arquivos:

1. Gere **chaves live** (separadas das paper) e coloque-as onde as
   paper estavam, só no arquivo de config do Claude Desktop.
2. Nesse mesmo bloco: `"ALPACA_PAPER_TRADE": "false"`.
3. No `trader/config.json`: `"paper": false`, e limites de iniciante
   bem mais apertados que os do paper. Exemplo conservador (ajuste os
   valores à sua realidade; `budget` tem que refletir a conta real,
   senão o risk calcula sobre uma conta imaginária):

```json
{
  "budget": 1000,
  "cash_buffer_pct": 20,
  "max_position_pct": 15,
  "max_order_usd": 150,
  "min_order_usd": 25,
  "max_orders_per_day": 2,
  "fractional": true,
  "broker": "alpaca",
  "paper": false,
  "blocked": [],
  "allow_options": false,
  "allow_margin": false,
  "allow_short": false,
  "sec_user_agent": "Seu Nome voce@exemplo.com"
}
```

4. Reinicie tudo, peça as informações da conta (só leitura) e confirme
   que agora é a conta **live**, com o saldo que você depositou. O
   `trader-risk` vai avisar "LIVE account" em toda checagem: esse
   aviso é para ser lido, não ignorado.
5. Primeira ordem real = **uma só, a menor possível**, em horário de
   pregão, seguindo budget, risk, ticket, seu `yes`, Allow once.
   Confira o fill no painel, registre com `ticket.py fill`,
   reconcilie o `portfolio.json` e **pare por esse dia**.
6. Só aumente limites depois de semanas sem surpresas, um limite por
   vez, editando o config você mesmo. Ordem a partir de tarefa
   agendada ou em segundo plano: nunca (não tem ninguém para dizer
   `yes`).

### Botão de emergência (saiba antes de precisar)

- No Claude: mude as ferramentas de ordem para **Blocked**.
- No config: volte `"paper": true` (as propostas deixam de mirar a
  conta real) e, se preciso, baixe `max_orders_per_day` para 0.
- Na corretora: revogue as chaves de API no painel. Qualquer
  cancelamento ou encerramento urgente, faça pela interface da
  própria corretora, não pedindo para a skill "fechar tudo".

## Rotina diária sugerida (depois de tudo no ar)

1. Manhã: `/trader-news` + `/trader-pelosi` + `alerts.py clock`.
2. Antes de qualquer proposta: atualizar preços, budget/rebalance,
   **risk sempre**, broker um ticket por vez.
3. Depois de cada fill: registrar, reconciliar com o painel, anotar
   o porquê no seu diário.
4. Semanal: `/trader-tax` (lotes e wash sales) e revisão dos limites.
5. Trimestral: novo 13F no `/trader-copycat` e rebalanceamento.

Travou em qualquer fase, traga a saída do comando (sem chaves!) para a
conversa que a gente depura junto. Guias: `COMECE-AQUI-MAC.md`,
`OPENCODE.md`, `INSTALACAO.md`.
