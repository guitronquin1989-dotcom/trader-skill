#!/usr/bin/env bash
# trader-skill: instalador para Mac (dois cliques no Finder)
#
# Como usar: clique com o botao direito neste arquivo > Abrir.
# (O macOS pede essa confirmacao na primeira vez, porque o arquivo veio da Internet).
# Se der "permissao negada", rode no Terminal: chmod +x instalar-mac.command
#
# O que ele faz:
#   1. Confere git, Python 3.8+ e Claude Code (oferece instalar o Claude Code, com o seu sim)
#   2. Instala as 11 skills em ~/.claude/skills/ rodando o install.sh (com a demo)
#   3. Oferece criar ~/trader-projeto com o seu trader/config.json (nome/email p/ a SEC)
# Nada e instalado com sudo. Nenhuma ordem e enviada. Paper trading continua o padrao.
#
# Modo nao interativo (testes): TRADER_NONINTERACTIVE=1 ./instalar-mac.command
#   Variaveis opcionais: TRADER_INIT_PROJECT=1 TRADER_USER_NAME="..." \
#                        TRADER_USER_EMAIL="..." TRADER_BUDGET=5000
set -u

REPO_URL="${TRADER_SKILL_REPO:-https://github.com/guitronquin1989-dotcom/trader-skill.git}"
REPO_BRANCH="${TRADER_SKILL_BRANCH:-arena/23cdc45d-trader-skill}"
PROJECT_DIR="${TRADER_PROJECT_DIR:-$HOME/trader-projeto}"
cd "$(dirname "$0")" || exit 1
HERE="$(pwd)"

INTERACTIVE=1
[ -t 0 ] || INTERACTIVE=0
[ "${TRADER_NONINTERACTIVE:-0}" = "1" ] && INTERACTIVE=0

pausa_e_sai() {
  code="${1:-0}"
  if [ "$INTERACTIVE" = "1" ]; then
    echo
    printf "Pressione Enter para fechar esta janela... "
    read -r _ || true
  fi
  exit "$code"
}
erro() {
  echo "ERRO: $*" >&2
  pausa_e_sai 1
}
pergunta() {
  # $1 = texto, $2 = padrao (S ou N). Retorna 0 para sim. sem terminal: usa o padrao.
  if [ "$INTERACTIVE" != "1" ]; then [ "$2" = "S" ]; return; fi
  printf "%s [%s] " "$1" "$2"
  read -r resp || resp=""
  resp="$(printf '%s' "$resp" | tr 'SN' 'sn' | cut -c1)"
  [ -z "$resp" ] && resp="$(printf '%s' "$2" | tr 'SN' 'sn')"
  [ "$resp" = "s" ]
}

echo "== trader-skill no Mac =="
if [ "$(uname -s)" != "Darwin" ]; then
  echo "Aviso: isto nao parece um Mac (uname: $(uname -s)). Continuando mesmo assim..."
else
  sw_vers 2>/dev/null | head -n 2 || true
fi

# --- 1) Codigo-fonte: ao lado deste arquivo, ou baixa do GitHub ---------------
if [ ! -f "$HERE/trader-copycat/SKILL.md" ] || [ ! -f "$HERE/install.sh" ]; then
  echo "As skills nao estao ao lado deste instalador. Vou baixar do GitHub..."
  command -v git >/dev/null 2>&1 || erro "git nao encontrado. Rode 'xcode-select --install', espere terminar e abra este arquivo de novo."
  DEST_CLONE="$HOME/trader-skill"
  if [ -f "$DEST_CLONE/trader-copycat/SKILL.md" ]; then
    echo "Ja existe $DEST_CLONE, usando ele."
  else
    git clone -b "$REPO_BRANCH" "$REPO_URL" "$DEST_CLONE" || erro "Falha ao clonar $REPO_URL (confira a internet)."
  fi
  HERE="$DEST_CLONE"
  cd "$HERE" || erro "Nao consegui entrar em $HERE"
fi
echo "Fonte: $HERE"

# --- 2) Python 3.8+ ------------------------------------------------------------
# Num Mac recem-formatado, o primeiro 'python3' pode abrir a janela das
# ferramentas de desenvolvedor da Apple: aceite, espere e rode de novo.
if ! command -v python3 >/dev/null 2>&1; then
  erro "python3 nao encontrado. Instale com 'xcode-select --install' ou 'brew install python' (ou em https://www.python.org/downloads/) e rode de novo."
fi
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' \
  || erro "Precisa de Python 3.8+. Instale com 'brew install python' e rode de novo."
echo "Python OK: $(python3 --version 2>&1)"

# --- 3) Claude Code --------------------------------------------------------------
if command -v claude >/dev/null 2>&1; then
  echo "Claude Code OK: $(claude --version 2>/dev/null | head -n 1)"
else
  echo "Claude Code (comando 'claude') nao encontrado neste Mac."
  echo "Instalacao oficial (macOS 13+):  curl -fsSL https://claude.ai/install.sh | bash"
  echo "Alternativa com Homebrew:        brew install --cask claude-code"
  if pergunta "Instalar o Claude Code agora pelo instalador oficial da Anthropic?" "N"; then
    curl -fsSL https://claude.ai/install.sh | bash || erro "O instalador do Claude Code falhou. Veja https://code.claude.com/docs/en/setup"
    echo "Claude Code instalado. No fim, feche e abra o Terminal e rode 'claude' para entrar na sua conta."
  else
    echo "Sem problemas: instalo as skills agora e voce instala o Claude Code depois."
  fi
fi

# --- 4) As 11 skills ---------------------------------------------------------------
echo
echo "Instalando as 11 skills (com os testes e a demo)..."
bash "$HERE/install.sh" --demo || erro "O install.sh falhou. Leia as mensagens acima."

# --- 5) Projeto pronto para usar (opcional) ---------------------------------------
INIT="${TRADER_INIT_PROJECT:-}"
if [ -z "$INIT" ]; then
  if pergunta "Criar um projeto pronto em $PROJECT_DIR com sua configuracao?" "S"; then INIT=1; else INIT=0; fi
fi
if [ "$INIT" = "1" ]; then
  NOME="${TRADER_USER_NAME:-}"; EMAIL="${TRADER_USER_EMAIL:-}"; ORC="${TRADER_BUDGET:-}"
  if [ "$INTERACTIVE" = "1" ]; then
    printf "Seu nome (a SEC exige nome e email para baixar os dados): "; read -r NOME || NOME=""
    printf "Seu email: "; read -r EMAIL || EMAIL=""
    printf "Seu orcamento em dolares [5000]: "; read -r ORC || ORC=""
  fi
  [ -z "$ORC" ] && ORC="5000"
  mkdir -p "$PROJECT_DIR/trader"
  if [ -f "$PROJECT_DIR/trader/config.json" ]; then
    echo "Ja existe $PROJECT_DIR/trader/config.json, nao vou mexer nele."
  elif [ -n "$NOME" ] && printf '%s' "$EMAIL" | grep -q '@'; then
    NOME="$NOME" EMAIL="$EMAIL" ORC="$ORC" EXEMPLO="$HERE/trader-budget/config.example.json" \
    SAIDA="$PROJECT_DIR/trader/config.json" python3 - <<'PYEOF' || erro "Falha ao criar o config.json."
import json, os
cfg = json.load(open(os.environ["EXEMPLO"]))
cfg["sec_user_agent"] = f'{os.environ["NOME"]} {os.environ["EMAIL"]}'
try:
    cfg["budget"] = int(os.environ["ORC"])
except ValueError:
    cfg["budget"] = 5000
cfg["paper"] = True
json.dump(cfg, open(os.environ["SAIDA"], "w"), indent=2, ensure_ascii=False)
print("Criado:", os.environ["SAIDA"], "(paper: true, budget:", cfg["budget"], ")")
PYEOF
  else
    echo "Nome/email nao informados (ou email sem @): pulando o config."
    echo "Voce pode criar depois copiando trader-budget/config.example.json para $PROJECT_DIR/trader/config.json"
  fi
fi

cat <<FIM

PRONTO. Para usar de verdade, neste Mac:
1. Feche e abra esta janela do Terminal (ou abra um Terminal novo).
2. Entre no projeto e abra o Claude Code:
     cd "$PROJECT_DIR"
     claude
   (Na primeira vez o Claude pede para voce entrar na sua conta.)
3. Dentro do Claude, digite:
     /trader-copycat
     copy Berkshire top 5
   Depois: /trader-budget  ->  /trader-risk  ->  /trader-broker
4. Nenhuma ordem e enviada sem voce digitar yes para aquela ordem. Fique no paper.

Guia curto so do Mac: COMECE-AQUI-MAC.md | Guia completo: INSTALACAO.md
FIM
pausa_e_sai 0
