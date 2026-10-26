#!/usr/bin/env bash
# Instalador do trader-skill - Mac / Linux
#
# Uso:
#   ./install.sh            instala as 11 skills em ~/.claude/skills/  (global, recomendado)
#   ./install.sh --project  instala em ./.claude/skills/               (só neste projeto)
#   ./install.sh --demo     depois de instalar, roda a demo offline (Berkshire top 5, US$ 5.000)
#   ./install.sh --no-test  pula a suíte de testes
#
# Sem sudo. Sem pip install (tudo é biblioteca padrão do Python 3.8+).
# Nada aqui envia ordem para corretora. Paper trading é o padrão.
set -euo pipefail

REPO_URL="${TRADER_SKILL_REPO:-https://github.com/Jakeschincariol/trader-skill.git}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${HOME}/.claude/skills"
RUN_DEMO=0
RUN_TESTS=1

for arg in "$@"; do
  case "$arg" in
    --project) DEST="${SCRIPT_DIR}/.claude/skills" ;;
    --global)  DEST="${HOME}/.claude/skills" ;;
    --demo)    RUN_DEMO=1 ;;
    --no-test) RUN_TESTS=0 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Opção desconhecida: $arg (use --project, --demo ou --no-test)" >&2; exit 2 ;;
  esac
done
# CLAUDE_SKILLS_DIR tem prioridade, se definida
DEST="${CLAUDE_SKILLS_DIR:-$DEST}"

echo "== trader-skill - instalador (Mac/Linux) =="

# --- 1) Python 3.8+ ---------------------------------------------------------
PY=""
for cand in python3 python; do
  if command -v "$cand" >/dev/null 2>&1; then PY="$cand"; break; fi
done
if [ -z "$PY" ]; then
  echo "ERRO: Python não encontrado. Instale o Python 3.8+:" >&2
  echo "  Mac:   brew install python   (ou https://www.python.org/downloads/)" >&2
  echo "  Linux: sudo apt install python3" >&2
  exit 1
fi
"$PY" - <<'PYEOF'
import sys
if sys.version_info < (3, 8):
    raise SystemExit(f"ERRO: precisa de Python 3.8+, encontrado {sys.version.split()[0]}")
print(f"Python OK: {sys.version.split()[0]}")
PYEOF

# --- 2) Fonte: este clone, ou baixa do GitHub -------------------------------
SRC="$SCRIPT_DIR"
if [ ! -f "$SRC/trader-copycat/SKILL.md" ]; then
  command -v git >/dev/null 2>&1 || { echo "ERRO: git não encontrado e as skills não estão ao lado deste script." >&2; exit 1; }
  TMP="$(mktemp -d)"
  echo "Clonando $REPO_URL ..."
  git clone --depth 1 "$REPO_URL" "$TMP/trader-skill"
  SRC="$TMP/trader-skill"
fi
echo "Fonte: $SRC"

# --- 3) Copia as 11 skills (com backup do que já existia) -------------------
mkdir -p "$DEST"
COUNT=0
for d in "$SRC"/trader-*/; do
  name="$(basename "$d")"
  [ -f "$d/SKILL.md" ] || continue
  if [ -e "$DEST/$name" ]; then
    BK="$DEST/.backup-$(date +%Y%m%d-%H%M%S)/$name"
    mkdir -p "$(dirname "$BK")"
    cp -r "$DEST/$name" "$BK"
    rm -rf "$DEST/$name"
    echo "  backup de $name anterior -> $BK"
  fi
  cp -r "$d" "$DEST/$name"
  # nunca copia lixo de compilação
  find "$DEST/$name" -name __pycache__ -type d -prune -exec rm -rf {} + 2>/dev/null || true
  echo "  instalada: /$name"
  COUNT=$((COUNT + 1))
done
[ "$COUNT" -eq 11 ] || { echo "ERRO: esperava 11 skills, instalou $COUNT" >&2; exit 1; }
echo "11 skills instaladas em: $DEST"

# --- 4) Verificação ---------------------------------------------------------
if [ "$RUN_TESTS" -eq 1 ] && [ -d "$SRC/tests" ]; then
  echo
  echo "Rodando os testes offline (175 testes, poucos segundos)..."
  (cd "$SRC" && "$PY" -m unittest discover -s tests 2>&1 | tail -n 4)
fi
echo
echo "Smoke test (usa a cópia INSTALADA, não a do repo):"
# clock sai com codigo 1 quando a NYSE esta fechada: isso e sucesso, nao erro
"$PY" "$DEST/trader-alerts/alerts.py" clock || true
"$PY" "$DEST/trader-copycat/edgar13f.py" find buffett

# --- 5) Demo opcional -------------------------------------------------------
if [ "$RUN_DEMO" -eq 1 ]; then
  echo
  echo "== DEMO offline: copiar Berkshire top 5 com US\$ 5.000 (nada é enviado) =="
  mkdir -p "$SCRIPT_DIR/demo/trader"
  cp "$SRC/trader-budget/config.example.json"  "$SCRIPT_DIR/demo/trader/config.json"
  cp "$SRC/trader-copycat/targets.example.json" "$SCRIPT_DIR/demo/trader/targets.json"
  cp "$SRC/tests/fixtures/trader-rebalance/prices.json" "$SCRIPT_DIR/demo/trader/prices.json"
  (
    cd "$SCRIPT_DIR/demo"
    "$PY" "$DEST/trader-budget/size.py" --budget 5000 --write
    "$PY" "$DEST/trader-risk/check.py"
    # head fecha o pipe (SIGPIPE no Python): || true para nao abortar com pipefail
    "$PY" "$DEST/trader-broker/ticket.py" show | head -n 25 || true
  )
  echo "Demo escrita em: $SCRIPT_DIR/demo/trader/ (orders.json etc.)"
fi

cat <<EOF

✅ PRONTO. Próximos passos:
1. Feche e abra de novo o Claude Code (ele só descobre skills novas ao iniciar).
2. No projeto onde você quer investir, crie trader/config.json a partir de
   trader-budget/config.example.json e troque:
     "sec_user_agent": "Seu Nome voce@exemplo.com"   <- a SEC exige nome+email
   (ou: export SEC_USER_AGENT="Seu Nome voce@exemplo.com")
   Mantenha "paper": true.
3. No Claude Code, teste:   /trader-copycat copy Berkshire top 5
   Depois:                  /trader-budget (seu orçamento) -> /trader-risk -> /trader-broker
   NENHUMA ordem é enviada sem você digitar yes para aquela ordem exata.

Guia completo em português: INSTALACAO.md
Desinstalar: apague as pastas trader-* de $DEST
EOF
