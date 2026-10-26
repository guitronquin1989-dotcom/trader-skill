#!/usr/bin/env bash
# instalar-terminal-mac.sh: instala o modo Terminal do trader-skill no Mac.
#
# Este modo NAO usa Claude Code, Claude Desktop nem OpenCode.
# Ele apenas:
#   1. usa este clone como instalacao (ou baixa o repo se o script estiver sozinho)
#   2. cria ~/trader-projeto/trader/config.json em modo paper, se nao existir
#   3. cria o comando "trader" em ~/.local/bin e coloca essa pasta no PATH do zsh
#   4. faz um smoke test local sem enviar ordem nenhuma
#
# Uso:
#   bash instalar-terminal-mac.sh
#   bash instalar-terminal-mac.sh --checar      # ao final, testa as fontes ao vivo
#   bash instalar-terminal-mac.sh --sem-atalho  # nao cria ~/.local/bin/trader
#   bash instalar-terminal-mac.sh --projeto ~/outro-projeto
#
# Teste automatizado/nao interativo:
#   TRADER_NONINTERACTIVE=1 TRADER_USER_NAME="Nome" \
#   TRADER_USER_EMAIL="voce@exemplo.com" TRADER_BUDGET=5000 \
#   bash instalar-terminal-mac.sh
set -u

REPO_URL="${TRADER_SKILL_REPO:-https://github.com/guitronquin1989-dotcom/trader-skill.git}"
REPO_BRANCH="${TRADER_SKILL_BRANCH:-arena/23cdc45d-trader-skill}"
PROJECT_DIR="${TRADER_PROJECT_DIR:-$HOME/trader-projeto}"
BIN_DIR="${TRADER_BIN_DIR:-$HOME/.local/bin}"
CREATE_SHORTCUT=1
RUN_CHECK=0
INTERACTIVE=1
[ -t 0 ] || INTERACTIVE=0
[ "${TRADER_NONINTERACTIVE:-0}" = "1" ] && INTERACTIVE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --checar) RUN_CHECK=1 ;;
    --sem-atalho) CREATE_SHORTCUT=0 ;;
    --projeto)
      shift
      [ "$#" -gt 0 ] || { echo "ERRO: --projeto precisa de um caminho" >&2; exit 2; }
      PROJECT_DIR="$1"
      ;;
    --projeto=*) PROJECT_DIR="${1#--projeto=}" ;;
    -h|--help)
      sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Opcao desconhecida: $1" >&2; exit 2 ;;
  esac
  shift
done

erro() { echo "ERRO: $*" >&2; exit 1; }
perguntar() {
  valor_padrao="$2"
  if [ "$INTERACTIVE" != "1" ]; then
    printf '%s' "$valor_padrao"
    return
  fi
  printf '%s' "$1" >&2
  read -r resposta || resposta=""
  [ -n "$resposta" ] || resposta="$valor_padrao"
  printf '%s' "$resposta"
}

echo "== trader-skill no Mac, somente pelo Terminal =="
echo "Sem Claude Code, sem OpenCode e sem chave de modelo."
if [ "$(uname -s)" = "Darwin" ]; then
  echo "macOS detectado."
else
  echo "Aviso: este sistema nao parece macOS ($(uname -s)); continuando mesmo assim."
fi

# Localiza o Python.
PY=""
for cand in python3 python; do
  if command -v "$cand" >/dev/null 2>&1; then PY="$cand"; break; fi
done
[ -n "$PY" ] || erro "Python nao encontrado. No Mac, aceite as Command Line Tools se a Apple oferecer, ou use: brew install python"
$PY -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 8) else 1)' \
  || erro "Precisa de Python 3.8 ou mais novo."
echo "Python OK: $($PY --version 2>&1)"

# Localiza ou baixa o codigo.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR="$(pwd)"
SRC=""
if [ -f "$SCRIPT_DIR/trader.sh" ] && [ -f "$SCRIPT_DIR/trader-copycat/edgar13f.py" ]; then
  SRC="$SCRIPT_DIR"
elif [ -f "$HOME/trader-skill/trader.sh" ]; then
  SRC="$HOME/trader-skill"
  echo "Usando clone existente: $SRC"
else
  command -v git >/dev/null 2>&1 || erro "git nao encontrado. Rode 'xcode-select --install', espere terminar e tente novamente."
  git clone -b "$REPO_BRANCH" "$REPO_URL" "$HOME/trader-skill" || erro "Nao consegui baixar o repositorio."
  SRC="$HOME/trader-skill"
fi
chmod +x "$SRC/trader.sh" "$SRC/checar-ambiente.sh" 2>/dev/null || true
echo "Codigo: $SRC"

# Cria o projeto e a configuracao inicial.
mkdir -p "$PROJECT_DIR/trader" || erro "Nao consegui criar $PROJECT_DIR/trader"
CONFIG="$PROJECT_DIR/trader/config.json"
CONFIG_EXAMPLE="$SRC/trader-budget/config.example.json"

if [ -f "$CONFIG" ]; then
  echo "Config existente preservado: $CONFIG"
  PAPER=$($PY -c "import json; print(json.load(open('$CONFIG')).get('paper'))" 2>/dev/null || echo "?")
  [ "$PAPER" = "False" ] && echo "AVISO IMPORTANTE: esse config esta com paper=false. Para aprender, volte para true." >&2
else
  [ -f "$CONFIG_EXAMPLE" ] || erro "Exemplo de config nao encontrado: $CONFIG_EXAMPLE"

  NOME="${TRADER_USER_NAME:-}"
  EMAIL="${TRADER_USER_EMAIL:-}"
  ORCAMENTO="${TRADER_BUDGET:-}"
  if [ "$INTERACTIVE" = "1" ]; then
    echo
    echo "Configuracao inicial (fica somente neste Mac):"
    NOME=$(perguntar "Seu nome, para identificar as consultas na SEC: " "$NOME")
    EMAIL=$(perguntar "Seu email, para identificar as consultas na SEC: " "$EMAIL")
    ORCAMENTO=$(perguntar "Orcamento de teste em dolares [5000]: " "${ORCAMENTO:-5000}")
  fi
  [ -n "$ORCAMENTO" ] || ORCAMENTO=5000

  NOME="$NOME" EMAIL="$EMAIL" ORCAMENTO="$ORCAMENTO" EXEMPLO="$CONFIG_EXAMPLE" SAIDA="$CONFIG" \
  $PY - <<'PYEOF' || erro "Nao consegui criar o config.json."
import json
import os

cfg = json.load(open(os.environ["EXEMPLO"], encoding="utf-8"))
nome = os.environ.get("NOME", "").strip()
email = os.environ.get("EMAIL", "").strip()
if nome and "@" in email:
    cfg["sec_user_agent"] = f"{nome} {email}"
try:
    cfg["budget"] = int(os.environ.get("ORCAMENTO", "5000"))
except ValueError:
    cfg["budget"] = 5000
cfg["paper"] = True
with open(os.environ["SAIDA"], "w", encoding="utf-8") as fh:
    json.dump(cfg, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
print(f"Criado: {os.environ['SAIDA']} (paper=true, budget={cfg['budget']})")
if cfg.get("sec_user_agent") == "Your Name you@example.com":
    print("AVISO: edite sec_user_agent com seu nome e email antes das consultas na SEC.")
PYEOF
fi

# Cria o comando global "trader" para novas janelas do Terminal.
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
if [ "$CREATE_SHORTCUT" = "1" ]; then
  mkdir -p "$BIN_DIR" || erro "Nao consegui criar $BIN_DIR"
  SHORTCUT="$BIN_DIR/trader"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf 'exec bash "%s/trader.sh" "$@"\n' "$SRC"
  } > "$SHORTCUT" || erro "Nao consegui criar o comando trader."
  chmod +x "$SHORTCUT" || erro "Nao consegui tornar o comando trader executavel."
  echo "Comando criado: $SHORTCUT"

  # No Mac, o shell padrao e zsh. Adiciona a pasta ao PATH uma unica vez.
  ZSHRC="$HOME/.zshrc"
  touch "$ZSHRC" || true
  if [ -f "$ZSHRC" ] && ! grep -Fq "$PATH_LINE" "$ZSHRC"; then
    printf '\n# trader-skill (modo Terminal)\n%s\n' "$PATH_LINE" >> "$ZSHRC"
    echo "PATH adicionado em: $ZSHRC"
  fi
  export PATH="$BIN_DIR:$PATH"
  TRADER_CMD="$SHORTCUT"
else
  TRADER_CMD="bash $SRC/trader.sh"
fi

# Smoke test local: nao usa corretora e nao cria ordens.
echo
echo "Teste rapido dentro do projeto..."
if [ "$CREATE_SHORTCUT" = "1" ]; then
  (cd "$PROJECT_DIR" && "$BIN_DIR/trader" ajuda >/dev/null) || erro "O comando trader nao respondeu no smoke test."
else
  (cd "$PROJECT_DIR" && bash "$SRC/trader.sh" ajuda >/dev/null) || erro "O trader.sh nao respondeu no smoke test."
fi
echo "Smoke test OK."

if [ "$RUN_CHECK" = "1" ]; then
  echo
  echo "Checando as fontes ao vivo (somente leitura)..."
  (cd "$PROJECT_DIR" && bash "$SRC/checar-ambiente.sh" --full) || {
    echo "A instalacao terminou, mas a checagem ao vivo encontrou falhas. Veja as mensagens acima." >&2
    exit 1
  }
fi

cat <<EOF

Instalacao concluida.

Feche e abra o Terminal. Depois rode:

  cd "$PROJECT_DIR"
  trader ajuda
  trader relogio
  trader manha

Para copiar a Berkshire como primeiro teste:

  trader achar buffett
  trader copiar 1067983 --top 5
  trader fluxo

O fluxo apenas gera propostas e tickets. Nada e comprado automaticamente.
Continue em paper e siga as fases de RODAR-LOCAL.md.
EOF
