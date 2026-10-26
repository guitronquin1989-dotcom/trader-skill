#!/usr/bin/env bash
# checar-ambiente.sh: seu Mac esta pronto para rodar o trader-skill AO VIVO?
#
# Uso (dentro da pasta do seu projeto, ex.: ~/trader-projeto):
#   bash ~/trader-skill/checar-ambiente.sh
#   bash ~/trader-skill/checar-ambiente.sh --full     # + analyst AAPL ao vivo
#   SKILLS_DIR=~/.config/opencode/skills bash checar-ambiente.sh
#
# SOMENTE LEITURA: nao chama size/check/ticket, nao le chave de corretora,
# nao cria ordem nenhuma. So confere Python, skills, config e rede (SEC/Yahoo).
set -u

FULL=0
[ "${1:-}" = "--full" ] && FULL=1
FALHAS=0
ok()   { echo "  OK    $*"; }
aviso(){ echo "  AVISO $*"; }
falha(){ echo "  FALHA $*"; FALHAS=$((FALHAS + 1)); }

echo "== checar-ambiente (somente leitura) =="
echo "Projeto: $(pwd)"

# --- Python -------------------------------------------------------------------
if command -v python3 >/dev/null 2>&1; then ok "python3: $(python3 --version 2>&1)"; PY=python3
elif command -v python >/dev/null 2>&1; then ok "python: $(python --version 2>&1)"; PY=python
else falha "Python nao encontrado"; PY=""; fi

# --- Skills ---------------------------------------------------------------------
SKILLS_DIR="${SKILLS_DIR:-}"
if [ -z "$SKILLS_DIR" ]; then
  for c in "$HOME/.claude/skills" "$HOME/.config/opencode/skills" ".claude/skills" ".opencode/skills"; do
    [ -f "$c/trader-copycat/SKILL.md" ] && SKILLS_DIR="$c" && break
  done
fi
if [ -n "$SKILLS_DIR" ] && [ -d "$SKILLS_DIR" ]; then
  N=$(ls -d "$SKILLS_DIR"/trader-*/ 2>/dev/null | wc -l | tr -d ' ')
  ok "skills em $SKILLS_DIR ($N pastas trader-*)"
  [ "$N" = "11" ] || aviso "esperava 11 pastas, achei $N"
else
  falha "skills nao encontradas (rode ./install.sh ou ./install.sh --opencode)"
fi
command -v claude >/dev/null 2>&1 && ok "Claude Code: $(claude --version 2>/dev/null | head -n 1)" || aviso "comando 'claude' nao encontrado (ok se voce usa OpenCode)"
command -v opencode >/dev/null 2>&1 && ok "OpenCode: $(opencode --version 2>/dev/null | head -n 1)" || aviso "comando 'opencode' nao encontrado (ok se voce usa Claude)"

# --- Config do projeto -----------------------------------------------------------
UA=""
if [ -f trader/config.json ]; then
  ok "trader/config.json existe"
  if [ -n "$PY" ]; then
    $PY - <<'PYEOF' || echo "  FALHA trader/config.json invalido"
import json, sys
try:
    c = json.load(open("trader/config.json"))
except Exception as e:
    print(f"  FALHA config ilegivel: {e}"); sys.exit(1)
paper = c.get("paper")
print(f"  {'OK  ' if paper is True else 'AVISO'} paper = {paper}" + ("" if paper is True else "  <-- CONTA REAL ARMADA no config"))
ua = (c.get("sec_user_agent") or "").strip()
if ua and ua != "Your Name you@example.com" and "@" in ua:
    print("  OK    sec_user_agent definido")
else:
    print("  AVISO sec_user_agent ausente ou ainda e o exemplo (a SEC vai recusar)")
print(f"  info  budget={c.get('budget')} max_order_usd={c.get('max_order_usd')} max_orders_per_day={c.get('max_orders_per_day')} broker={c.get('broker')}")
open("/tmp/.trader-ua", "w").write(ua)
PYEOF
    UA="$(cat /tmp/.trader-ua 2>/dev/null)"; rm -f /tmp/.trader-ua
  fi
else
  aviso "sem trader/config.json aqui (copie de trader-budget/config.example.json)"
fi
[ -n "${SEC_USER_AGENT:-}" ] && UA="$SEC_USER_AGENT" && ok "SEC_USER_AGENT definido no ambiente"
[ -z "$UA" ] && UA="trader-skill check (sem user agent configurado)"

# --- Rede: as fontes ao vivo -------------------------------------------------------
echo "Rede (fontes publicas, sem chave):"
probe() { # $1 rotulo, $2 url, $3 user-agent opcional
  code=$(curl -sS -m 10 ${3:+-A "$3"} -o /dev/null -w "%{http_code}" "$2" 2>/dev/null)
  [ -z "$code" ] && code="000"
  case "$code" in 2*|3*) ok "$1 (HTTP $code)";; *) falha "$1 (HTTP $code) - sem rede/firewall? confira e tente de novo";; esac
}
probe "SEC EDGAR (dados)" "https://data.sec.gov/submissions/CIK0000320193.json" "$UA"
probe "Yahoo RSS (noticias)" "https://feeds.finance.yahoo.com/rss/2.0/headline?s=AAPL&region=US&lang=en-US"
probe "Yahoo chart (precos)" "https://query1.finance.yahoo.com/v8/finance/chart/AAPL?range=1d&interval=1d"
probe "Stooq CSV (precos alt.)" "https://stooq.com/q/l/?s=aapl.us&i=d"

# --- Ferramentas ao vivo, somente leitura -------------------------------------------
if [ -n "$SKILLS_DIR" ] && [ -n "$PY" ]; then
  echo "Ferramentas (somente leitura):"
  $PY "$SKILLS_DIR/trader-alerts/alerts.py" clock; rc=$?
  [ $rc -le 1 ] && ok "trader-alerts clock respondeu (exit $rc; 1 = NYSE fechada)" || falha "trader-alerts clock falhou (exit $rc)"
  if $PY "$SKILLS_DIR/trader-alerts/alerts.py" quote AAPL >/tmp/.trader-quote 2>&1; then
    ok "trader-alerts quote AAPL: $(head -n 2 /tmp/.trader-quote | tr '\n' ' ')"
  else
    falha "trader-alerts quote AAPL falhou: $(head -n 2 /tmp/.trader-quote | tr '\n' ' ')"
  fi
  rm -f /tmp/.trader-quote
  echo "  info  noticias (dry-run, nao grava estado):"
  $PY "$SKILLS_DIR/trader-news/news.py" --tickers AAPL --hours 48 --dry-run 2>&1 | head -n 6 || true
  if [ "$FULL" = "1" ]; then
    echo "  info  analyst AAPL (SEC ao vivo, pode demorar):"
    $PY "$SKILLS_DIR/trader-analyst/facts.py" AAPL 2>&1 | head -n 12 || aviso "analyst falhou (User-Agent da SEC?)"
  fi
fi

echo
if [ "$FALHAS" -eq 0 ]; then
  echo "RESULTADO: ambiente pronto para a Fase 1 (leitura ao vivo). Veja RODAR-LOCAL.md"
else
  echo "RESULTADO: $FALHAS falha(s). Corrija acima antes de qualquer teste com corretora."
fi
echo "Lembrete: isto nao testa corretora nem coloca ordem. Paper primeiro, sempre."
exit "$FALHAS"
