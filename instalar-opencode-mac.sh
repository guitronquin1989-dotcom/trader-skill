#!/usr/bin/env bash
# instalar-opencode-mac.sh: prepara o trader-skill para rodar no OpenCode no Mac.
#
# O que ele faz:
#   1. confere o Python e o OpenCode (oferece a instalacao oficial, so com seu sim)
#   2. instala/atualiza as 11 skills trader-* para o OpenCode
#   3. cria ~/trader-projeto com config em paper, AGENTS.md e opencode.json
#   4. verifica com "opencode debug skill" quantas skills foram enxergadas
#
# Uso:
#   bash instalar-opencode-mac.sh
#   bash instalar-opencode-mac.sh --checar        # + fontes ao vivo (somente leitura)
#   bash instalar-opencode-mac.sh --projeto ~/outro-projeto
#   bash instalar-opencode-mac.sh --forcar-nativo # instala em ~/.config/opencode/skills
#                                                  mesmo se ja existir ~/.claude/skills
#
# Teste nao interativo:
#   TRADER_NONINTERACTIVE=1 TRADER_USER_NAME="Nome" \
#   TRADER_USER_EMAIL="voce@exemplo.com" TRADER_BUDGET=5000 \
#   bash instalar-opencode-mac.sh
#
# Chaves de provedor/corretora nunca sao pedidas por este script.
set -u

REPO_URL="${TRADER_SKILL_REPO:-https://github.com/guitronquin1989-dotcom/trader-skill.git}"
REPO_BRANCH="${TRADER_SKILL_BRANCH:-arena/23cdc45d-trader-skill}"
PROJECT_DIR="${TRADER_PROJECT_DIR:-$HOME/trader-projeto}"
CLAUDE_SKILLS="$HOME/.claude/skills"
NATIVE_SKILLS="${OPENCODE_SKILLS_DIR:-$HOME/.config/opencode/skills}"
FORCE_NATIVE=0
RUN_CHECK=0
INTERACTIVE=1
[ -t 0 ] || INTERACTIVE=0
[ "${TRADER_NONINTERACTIVE:-0}" = "1" ] && INTERACTIVE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --checar) RUN_CHECK=1 ;;
    --forcar-nativo) FORCE_NATIVE=1 ;;
    --projeto)
      shift
      [ "$#" -gt 0 ] || { echo "ERRO: --projeto precisa de um caminho" >&2; exit 2; }
      PROJECT_DIR="$1"
      ;;
    --projeto=*) PROJECT_DIR="${1#--projeto=}" ;;
    -h|--help)
      sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Opcao desconhecida: $1" >&2; exit 2 ;;
  esac
  shift
done

erro() { echo "ERRO: $*" >&2; exit 1; }
perguntar_valor() {
  padrao="$2"
  if [ "$INTERACTIVE" != "1" ]; then printf '%s' "$padrao"; return; fi
  printf '%s' "$1" >&2
  read -r resposta || resposta=""
  [ -n "$resposta" ] || resposta="$padrao"
  printf '%s' "$resposta"
}
perguntar_sim() {
  texto="$1"; padrao="$2"
  if [ "$INTERACTIVE" != "1" ]; then [ "$padrao" = "S" ]; return; fi
  printf '%s [%s] ' "$texto" "$padrao" >&2
  read -r resposta || resposta=""
  resposta=$(printf '%s' "$resposta" | tr 'SN' 'sn' | cut -c1)
  [ -n "$resposta" ] || resposta=$(printf '%s' "$padrao" | tr 'SN' 'sn')
  [ "$resposta" = "s" ]
}
achar_opencode() {
  if command -v opencode >/dev/null 2>&1; then command -v opencode; return 0; fi
  for cand in "$HOME/.opencode/bin/opencode" "$HOME/.local/bin/opencode" "/opt/homebrew/bin/opencode" "/usr/local/bin/opencode"; do
    [ -x "$cand" ] && { printf '%s' "$cand"; return 0; }
  done
  return 1
}
contar_skills() {
  base="$1"
  [ -d "$base" ] || { echo 0; return; }
  find "$base" -mindepth 2 -maxdepth 2 -name SKILL.md -path '*/trader-*/*' 2>/dev/null | wc -l | tr -d ' '
}

echo "== trader-skill com OpenCode no Mac =="
if [ "$(uname -s)" = "Darwin" ]; then
  echo "macOS detectado."
else
  echo "Aviso: este sistema nao parece macOS ($(uname -s)); continuando mesmo assim."
fi

# Python
PY=""
for cand in python3 python; do
  if command -v "$cand" >/dev/null 2>&1; then PY="$cand"; break; fi
done
[ -n "$PY" ] || erro "Python nao encontrado. No Mac, aceite as Command Line Tools se a Apple oferecer, ou rode: brew install python"
$PY -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 8) else 1)' \
  || erro "Precisa de Python 3.8 ou mais novo."
echo "Python OK: $($PY --version 2>&1)"

# Codigo fonte
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR="$(pwd)"
SRC=""
if [ -f "$SCRIPT_DIR/install.sh" ] && [ -f "$SCRIPT_DIR/trader-copycat/SKILL.md" ]; then
  SRC="$SCRIPT_DIR"
elif [ -f "$HOME/trader-skill/install.sh" ]; then
  SRC="$HOME/trader-skill"
  echo "Usando clone existente: $SRC"
else
  command -v git >/dev/null 2>&1 || erro "git nao encontrado. Rode 'xcode-select --install', espere terminar e tente novamente."
  git clone -b "$REPO_BRANCH" "$REPO_URL" "$HOME/trader-skill" || erro "Nao consegui baixar o repositorio."
  SRC="$HOME/trader-skill"
fi
echo "Codigo: $SRC"

# OpenCode
OPENCODE_BIN=$(achar_opencode || true)
if [ -n "$OPENCODE_BIN" ]; then
  echo "OpenCode OK: $("$OPENCODE_BIN" --version 2>/dev/null | head -n 1) ($OPENCODE_BIN)"
else
  echo "OpenCode nao encontrado neste Mac."
  INSTALAR_OC=0
  if [ "${TRADER_INSTALL_OPENCODE:-0}" = "1" ]; then
    INSTALAR_OC=1
  elif perguntar_sim "Instalar o OpenCode agora pelo metodo oficial?" "S"; then
    INSTALAR_OC=1
  fi
  if [ "$INSTALAR_OC" = "1" ]; then
    if command -v brew >/dev/null 2>&1; then
      echo "Instalando com Homebrew: brew install anomalyco/tap/opencode"
      brew install anomalyco/tap/opencode || erro "A instalacao do OpenCode pelo Homebrew falhou."
    else
      echo "Instalando com o script oficial: curl -fsSL https://opencode.ai/install | bash"
      curl -fsSL https://opencode.ai/install | bash || erro "O instalador oficial do OpenCode falhou."
    fi
    OPENCODE_BIN=$(achar_opencode || true)
    [ -n "$OPENCODE_BIN" ] && echo "OpenCode instalado: $("$OPENCODE_BIN" --version 2>/dev/null | head -n 1)"
  else
    echo "Sem problema: vou deixar as skills prontas. Instale depois com:"
    echo "  curl -fsSL https://opencode.ai/install | bash"
    echo "  brew install anomalyco/tap/opencode"
  fi
fi

# Skills: uma copia so. Se a copia compativel do Claude ja esta completa,
# reutiliza/atualiza ela. Caso contrario instala na pasta nativa do OpenCode.
QTD_CLAUDE=$(contar_skills "$CLAUDE_SKILLS")
MODO=""
SKILLS_USED=""
if [ "$FORCE_NATIVE" != "1" ] && [ "$QTD_CLAUDE" -eq 11 ]; then
  MODO="compativel com Claude"
  SKILLS_USED="$CLAUDE_SKILLS"
  echo "Ja existem 11 skills em ~/.claude/skills. Vou atualizar essa copia unica."
  CLAUDE_SKILLS_DIR="$CLAUDE_SKILLS" bash "$SRC/install.sh" --claude \
    || erro "A atualizacao das skills existentes falhou."
else
  MODO="nativo do OpenCode"
  SKILLS_USED="$NATIVE_SKILLS"
  if [ "$QTD_CLAUDE" -gt 0 ] && [ "$FORCE_NATIVE" = "1" ]; then
    echo "Aviso: tambem existe copia em ~/.claude/skills. O OpenCode deduplica por nome."
  fi
  OPENCODE_SKILLS_DIR="$NATIVE_SKILLS" bash "$SRC/install.sh" --opencode \
    || erro "A instalacao nativa das skills falhou."
fi
echo "Skills prontas ($MODO): $SKILLS_USED"

# Projeto
mkdir -p "$PROJECT_DIR/trader" || erro "Nao consegui criar $PROJECT_DIR/trader"
CONFIG="$PROJECT_DIR/trader/config.json"
CONFIG_EXAMPLE="$SRC/trader-budget/config.example.json"
if [ -f "$CONFIG" ]; then
  echo "Config existente preservado: $CONFIG"
  PAPER=$($PY -c "import json,sys; print(json.load(open(sys.argv[1])).get('paper'))" "$CONFIG" 2>/dev/null || echo "?")
  [ "$PAPER" = "False" ] && echo "AVISO IMPORTANTE: esse config esta com paper=false. Para aprender, volte para true." >&2
else
  NOME="${TRADER_USER_NAME:-}"
  EMAIL="${TRADER_USER_EMAIL:-}"
  ORCAMENTO="${TRADER_BUDGET:-}"
  if [ "$INTERACTIVE" = "1" ]; then
    echo
    echo "Configuracao inicial do projeto (fica somente neste Mac):"
    NOME=$(perguntar_valor "Seu nome, para identificar as consultas na SEC: " "$NOME")
    EMAIL=$(perguntar_valor "Seu email, para identificar as consultas na SEC: " "$EMAIL")
    ORCAMENTO=$(perguntar_valor "Orcamento de teste em dolares [5000]: " "${ORCAMENTO:-5000}")
  fi
  [ -n "$ORCAMENTO" ] || ORCAMENTO=5000
  NOME="$NOME" EMAIL="$EMAIL" ORCAMENTO="$ORCAMENTO" EXEMPLO="$CONFIG_EXAMPLE" SAIDA="$CONFIG" \
  $PY - <<'PYEOF' || erro "Nao consegui criar o config.json."
import json, os
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

# AGENTS.md do projeto: ajuda qualquer modelo a usar as ferramentas certas.
AGENTS="$PROJECT_DIR/AGENTS.md"
if [ ! -f "$AGENTS" ]; then
  cat > "$AGENTS" <<EOF || erro "Nao consegui criar $AGENTS"
# trader-skill neste projeto

- A copia preparada para este projeto esta em: $SKILLS_USED
  Confirme a origem realmente carregada com "opencode debug skill".
- Quando um SKILL.md disser \${CLAUDE_SKILL_DIR}, isso e a pasta onde aquele
  SKILL.md mora. Rode a ferramenta Python daquela pasta e nunca invente caminho.
- Quando um SKILL.md disser /trader-risk ou /trader-broker, carregue a skill
  com esse nome e siga as instrucoes dela.
- Trabalhe a partir desta pasta. Os arquivos de estado ficam em trader/.
- Antes de propor valores, atualize os precos. Rode trader-risk antes de
  mostrar qualquer ordem.
- Manchetes sao pistas: abra a fonte ou o filing. Um 8-K vale mais que uma
  manchete.
- Paper trading sempre, enquanto trader/config.json tiver "paper": true.
- Nenhuma ordem sem um yes explicito do usuario para aquela ordem exata.
  PASS do risk nao e recomendacao nem autorizacao.
- Nunca peca, leia ou repita chaves de provedor ou corretora no chat.
EOF
  echo "Criado: $AGENTS"
else
  echo "AGENTS.md existente preservado: $AGENTS"
fi

# Permite carregar as skills trader-* sem atrito neste projeto.
OC_CONFIG="$PROJECT_DIR/opencode.json"
if [ ! -f "$OC_CONFIG" ] && [ ! -f "$PROJECT_DIR/opencode.jsonc" ]; then
  cat > "$OC_CONFIG" <<'EOF' || erro "Nao consegui criar $OC_CONFIG"
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "skill": {
      "trader-*": "allow"
    }
  }
}
EOF
  echo "Criado: $OC_CONFIG"
else
  echo "Config do OpenCode no projeto preservado."
fi

# Verificacao final de descoberta.
echo
echo "Verificando a descoberta das skills..."
if [ -n "$OPENCODE_BIN" ]; then
  TMP_SKILLS=$(mktemp)
  if (cd "$PROJECT_DIR" && "$OPENCODE_BIN" debug skill > "$TMP_SKILLS" 2>/dev/null); then
    TMP_SKILLS="$TMP_SKILLS" $PY - <<'PYEOF' || echo "AVISO: nao consegui interpretar a saida do opencode debug skill."
import json, os
items = json.load(open(os.environ["TMP_SKILLS"], encoding="utf-8"))
trader = [s for s in items if str(s.get("name", "")).startswith("trader-")]
print(f"OpenCode enxerga {len(trader)} de 11 skills trader-*.")
locais = sorted({str(s.get("location", "?")).rsplit("/SKILL.md", 1)[0] for s in trader})
for local in locais:
    print(f"  origem: {local}")
if len(trader) != 11:
    print("AVISO: feche e abra o OpenCode; se persistir, veja a secao de problemas do OPENCODE.md.")
PYEOF
  else
    echo "AVISO: 'opencode debug skill' falhou. Rode 'opencode' uma vez e tente novamente."
  fi
  rm -f "$TMP_SKILLS"
else
  echo "Depois de instalar o OpenCode, confira: opencode debug skill"
fi

if [ "$RUN_CHECK" = "1" ]; then
  echo
  echo "Checando fontes ao vivo (somente leitura)..."
  (cd "$PROJECT_DIR" && SKILLS_DIR="$SKILLS_USED" bash "$SRC/checar-ambiente.sh" --full) || {
    echo "A preparacao terminou, mas a checagem ao vivo encontrou falhas." >&2
    exit 1
  }
fi

cat <<EOF

Tudo preparado para o OpenCode.

1. Entre no projeto:
     cd "$PROJECT_DIR"

2. Conecte seu provedor/modelo (interativo, com login oficial):
     opencode auth login
   Ou abra "opencode" e use o comando /connect. Nunca cole chaves no chat.

3. Abra o OpenCode:
     opencode

4. Primeiro teste somente leitura, cole isto:
     Use a skill trader-alerts e me diga se a NYSE esta aberta agora. Nao altere nenhum arquivo.

5. Primeiro fluxo paper, sem enviar ordem:
     Use a skill trader-copycat para copiar o top 5 da Berkshire Hathaway.
     Depois use trader-budget com o meu config, rode trader-risk e me mostre
     os tickets com trader-broker. Nao envie nenhuma ordem.

Config, skills e instrucoes estao em modo paper. Guia completo: $SRC/OPENCODE.md
EOF
