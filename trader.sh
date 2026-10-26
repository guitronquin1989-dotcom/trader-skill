#!/usr/bin/env bash
# trader.sh: o trader-skill SEM Claude Code e SEM OpenCode, direto no Terminal.
#
# Uso (de dentro da pasta do seu projeto, ex.: ~/trader-projeto):
#   bash ~/trader-skill/trader.sh ajuda
#   bash ~/trader-skill/trader.sh manha          # relogio + precos + noticias + congresso
#   bash ~/trader-skill/trader.sh fluxo 5000     # precos -> orcamento -> risco -> tickets
#   bash ~/trader-skill/trader.sh menu           # menu interativo
#
# As ferramentas sao scripts Python comuns (biblioteca padrao). Sem um agente,
# quem le as saidas, decide e encadeia os passos e voce. NADA aqui envia ordem:
# no fim voce recebe tickets para digitar voce mesmo no app/site da corretora.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Onde estao as pastas trader-*? (o clone ja serve: nao precisa instalar nada)
SK="${SKILLS_DIR:-}"
if [ -z "$SK" ]; then
  for c in "$SCRIPT_DIR" "$HOME/.claude/skills" "$HOME/.config/opencode/skills" ".claude/skills" ".opencode/skills"; do
    [ -f "$c/trader-copycat/edgar13f.py" ] && SK="$c" && break
  done
fi
if [ -z "$SK" ] || [ ! -f "$SK/trader-copycat/edgar13f.py" ]; then
  echo "ERRO: nao achei as skills (trader-*). Rode de dentro do clone ou instale com ./install.sh" >&2
  exit 1
fi

PY=""
for cand in python3 python; do command -v "$cand" >/dev/null 2>&1 && PY="$cand" && break; done
[ -n "$PY" ] || { echo "ERRO: Python nao encontrado (precisa 3.8+)" >&2; exit 1; }

# Avisa se o projeto esta armado para conta real (nunca bloqueia)
if [ -f trader/config.json ]; then
  PAPER=$($PY -c "import json;print(json.load(open('trader/config.json')).get('paper'))" 2>/dev/null || echo "?")
  [ "$PAPER" = "False" ] && echo "!! ATENCAO: trader/config.json tem paper=false (conta REAL nas propostas) !!" >&2
fi

titulo() { echo; echo "===== $* ====="; }

cmd_relogio()   { $PY "$SK/trader-alerts/alerts.py" clock "$@"; return 0; }
cmd_precos() {
  if [ "$#" -gt 0 ]; then $PY "$SK/trader-alerts/alerts.py" quote "$@";
  else $PY "$SK/trader-alerts/alerts.py" quote --holdings --write; fi
}
cmd_noticias() {
  if [ "$#" -gt 0 ]; then $PY "$SK/trader-news/news.py" --tickers "$@" --hours "${HORAS:-24}";
  else $PY "$SK/trader-news/news.py" --hours "${HORAS:-24}"; fi
  return 0; # exit 1 da ferramenta = nada de novo, nao e erro
}
cmd_pelosi()    { $PY "$SK/trader-pelosi/ptr.py" new --member pelosi "$@"; return 0; }
cmd_achar()     { $PY "$SK/trader-copycat/edgar13f.py" find "$@"; }
cmd_copiar()    { $PY "$SK/trader-copycat/edgar13f.py" copy "$@"; }
cmd_posicoes()  { $PY "$SK/trader-copycat/edgar13f.py" holdings "$@"; }
cmd_analista()  { $PY "$SK/trader-analyst/facts.py" "$@"; }
cmd_filtrar()   {
  if [ "$#" -gt 0 ]; then $PY "$SK/trader-screener/screen.py" "$@";
  else $PY "$SK/trader-screener/screen.py" trader/metrics.json --rules trader/rules.json --prices trader/prices.json; fi
}
cmd_orcamento() {
  if [ "$#" -gt 0 ]; then $PY "$SK/trader-budget/size.py" --budget "$1" --write;
  else $PY "$SK/trader-budget/size.py" --write; fi
}
cmd_risco()     { $PY "$SK/trader-risk/check.py" "$@"; }
cmd_tickets()   { $PY "$SK/trader-broker/ticket.py" show; }
cmd_ticket()    { $PY "$SK/trader-broker/ticket.py" "$@"; }
cmd_rebalancear(){ $PY "$SK/trader-rebalance/rebalance.py" --band "${1:-5}"; }
cmd_impostos()  { $PY "$SK/trader-tax/lots.py" report "$@"; }
cmd_alertas()   { $PY "$SK/trader-alerts/alerts.py" check "$@"; return 0; }

cmd_manha() {
  titulo "NYSE";        cmd_relogio
  titulo "PRECOS";      cmd_precos "$@" || echo "(precos falharam: rede?)"
  titulo "NOTICIAS";    cmd_noticias
  titulo "CONGRESSO";   cmd_pelosi
  echo; echo "Rotina da manha pronta. Manchete e pista: abra os links antes de concluir qualquer coisa."
}

cmd_fluxo() {
  VALOR="${1:-}"
  titulo "1/4 PRECOS FRESCOS"; cmd_precos || echo "(sem precos novos: seguindo com o trader/prices.json atual)"
  titulo "2/4 ORCAMENTO (propostas em trader/orders.json)"
  if [ -n "$VALOR" ]; then cmd_orcamento "$VALOR" || return 1; else cmd_orcamento || return 1; fi
  titulo "3/4 RISCO (PASS = pode mostrar, nao e recomendacao)"
  cmd_risco || echo "(houve BLOCK: veja os motivos acima; ticket bloqueado nao se envia)"
  titulo "4/4 TICKETS (nada foi enviado)"
  cmd_tickets || true
  echo; echo "Fim do fluxo. Para 'executar' sem agente: digite a ordem VOCE no app/site da"
  echo "corretora (paper!), depois registre com: trader.sh ticket result/fill (veja TERMINAL.md)."
}

ajuda() {
cat <<'EOF'
trader.sh: trader-skill direto no Terminal, sem Claude Code e sem OpenCode

Uso: bash trader.sh <comando> [argumentos]   (de dentro do seu projeto)

Leitura e dados (ao vivo no seu Mac):
  relogio                 a NYSE esta aberta?
  precos [AAPL KO ...]    cotacoes (sem tickers: sua carteira, grava trader/prices.json)
  noticias [AAPL ...]     manchetes + 8-Ks da SEC (sem tickers: portfolio/targets)
  pelosi                  PTRs novos da pelosi no Congresso
  achar <nome>            acha o CIK de um investidor/fundo (ex.: achar buffett)
  posicoes <CIK>          as posicoes do 13F mais recente
  copiar <CIK> --top N    grava trader/targets.json copiando o investidor
  analista AAPL [KO ...]  resultados trimestrais direto da SEC
  filtrar                 screener com trader/metrics.json + trader/rules.json
  alertas                 checa suas regras em trader/alerts.json (se houver)

Propostas (nada e enviado):
  orcamento [valor]       dimensiona e grava trader/orders.json (propostas)
  risco                   PASS/BLOCK por ordem, contra o seu config
  tickets                 mostra os tickets READY ou nem tanto
  ticket <args...>        approve / decline / result / fill / log (registro manual)
  rebalancear [banda]     desvio vs. alvo (padrao: banda 5)
  impostos                relatorio de lotes, ganhos e perdas

Atalhos:
  manha                   relogio + precos + noticias + congresso
  fluxo [valor]           precos -> orcamento -> risco -> tickets
  menu                    menu interativo
  ajuda                   esta tela

Sem corretora conectada e sem agente, ordem so existe se VOCE digita-la
no app/site da corretora. Paper primeiro. Guia completo: TERMINAL.md
EOF
}

menu() {
  [ -t 0 ] || { ajuda; return 0; }
  while true; do
    echo; echo "--- trader.sh (projeto: $(pwd)) ---"
    echo " 1 manha        2 noticias      3 precos        4 relogio"
    echo " 5 pelosi       6 achar/copiar  7 analista      8 filtrar"
    echo " 9 fluxo       10 risco        11 tickets      12 impostos"
    printf "Escolha [1-12, q=sair]: "; read -r op || break
    case "$op" in
      1) cmd_manha ;;
      2) printf "Tickers (vazio = carteira): "; read -r t; cmd_noticias $t ;;
      3) printf "Tickers (vazio = carteira): "; read -r t; cmd_precos $t ;;
      4) cmd_relogio ;;
      5) cmd_pelosi ;;
      6) printf "Nome p/ achar o CIK: "; read -r n; cmd_achar "$n"
         printf "Copiar qual CIK? (vazio pula): "; read -r c
         [ -n "$c" ] && { printf "top quantos? [5]: "; read -r top; cmd_copiar "$c" --top "${top:-5}"; } ;;
      7) printf "Tickers: "; read -r t; cmd_analista $t ;;
      8) cmd_filtrar ;;
      9) printf "Orcamento (vazio = config): "; read -r v; cmd_fluxo "$v" ;;
      10) cmd_risco ;;
      11) cmd_tickets ;;
      12) cmd_impostos ;;
      q|Q|"") break ;;
      *) echo "opcao invalida" ;;
    esac
  done
}

COMANDO="${1:-ajuda}"; shift 2>/dev/null || true
case "$COMANDO" in
  ajuda|help|-h|--help) ajuda ;;
  menu) menu ;;
  relogio|clock) cmd_relogio "$@" ;;
  precos|quote|precos) cmd_precos "$@" ;;
  noticias|news) cmd_noticias "$@" ;;
  pelosi|congresso) cmd_pelosi "$@" ;;
  achar|find) cmd_achar "$@" ;;
  copiar|copy) cmd_copiar "$@" ;;
  posicoes|holdings) cmd_posicoes "$@" ;;
  analista|analyst) cmd_analista "$@" ;;
  filtrar|screen|screener) cmd_filtrar "$@" ;;
  orcamento|budget|tamanho) cmd_orcamento "$@" ;;
  risco|risk) cmd_risco "$@" ;;
  tickets|broker) cmd_tickets ;;
  ticket) cmd_ticket "$@" ;;
  rebalancear|rebalance) cmd_rebalancear "$@" ;;
  impostos|tax|lotes) cmd_impostos "$@" ;;
  alertas|alerts) cmd_alertas "$@" ;;
  manha|rotina|morning) cmd_manha "$@" ;;
  fluxo|pipeline) cmd_fluxo "$@" ;;
  *) echo "Comando desconhecido: $COMANDO" >&2; ajuda >&2; exit 2 ;;
esac
