# trader-skill no Mac com Claude Code: comece aqui

Rota curta, só para macOS. Tempo total: uns 10 minutos, incluindo o
login no Claude. Tudo em modo paper (dinheiro de mentira): nenhuma
ordem é enviada sem você digitar `yes` para aquela ordem exata.

Pré-requisitos: macOS 13 ou mais novo, internet e uma conta Claude com
acesso ao Claude Code (o comando `claude` no Terminal).

## Passo 0: o Claude Code está neste Mac?

Abra o Terminal (tecla `Cmd + Espaço`, digite `Terminal`, Enter) e rode:

```bash
claude --version
python3 --version
```

- Se `claude` responder com uma versão, ótimo, vá ao Passo 1.
- Se der `command not found: claude`, instale pela forma oficial da
  Anthropic para Mac e depois rode `claude` uma vez para entrar na sua
  conta:

```bash
curl -fsSL https://claude.ai/install.sh | bash
# alternativa, se você já usa Homebrew:
# brew install --cask claude-code
```

- Se o primeiro `python3` (ou `git`) abrir uma janelinha da Apple
  oferecendo instalar as ferramentas de desenvolvedor, aceite, espere
  terminar e rode o comando de novo. É normal em Mac novo.

Documentação oficial do Claude Code (setup no Mac):
https://code.claude.com/docs/en/setup

## Passo 1: instale as 11 skills (escolha UM jeito)

### Jeito A: dois cliques (sem digitar comando)

1. Baixe este repositório (botão verde `Code` no GitHub, `Download ZIP`)
   e descompacte.
2. Clique com o **botão direito** em `instalar-mac.command` e escolha
   **Abrir**. Na primeira vez o macOS pede essa confirmação porque o
   arquivo veio da internet; clique em `Abrir` de novo.
3. Ele confere Python e Claude Code, instala as skills em
   `~/.claude/skills/`, roda os testes e a demo, e oferece criar
   `~/trader-projeto` já com a sua configuração (nome, email e
   orçamento; o nome e email são exigências da SEC para baixar dados
   e ficam só num arquivo local).

Se der "permissão negada", rode isto na pasta descompactada e tente
de novo:

```bash
chmod +x instalar-mac.command install.sh
```

### Jeito B: Terminal, um bloco só (copiar e colar)

```bash
git clone -b arena/23cdc45d-trader-skill https://github.com/guitronquin1989-dotcom/trader-skill.git ~/trader-skill
cd ~/trader-skill
./install.sh --demo
```

Terminou com `11 skills instaladas` e `175 testes OK`? Perfeito.

### Jeito C: plugin, sem baixar nada daqui

Dentro do Claude Code:

```text
/plugin marketplace add Jakeschincariol/trader-skill
/plugin install trader-skill@trader-skill
```

Por este jeito os comandos ganham prefixo (ex.:
`/trader-skill:trader-copycat`). Nos jeitos A e B o nome fica curto
(`/trader-copycat`), que é o que este guia usa.

## Passo 2: seu projeto e sua configuração

Se você usou o Jeito A e aceitou criar o projeto, esta parte já está
feita em `~/trader-projeto`. Senão, faça uma vez:

```bash
mkdir -p ~/trader-projeto/trader
cp ~/trader-skill/trader-budget/config.example.json ~/trader-projeto/trader/config.json
open -e ~/trader-projeto/trader/config.json
```

No editor que abrir, ajuste e salve:

```json
{
  "budget": 5000,
  "cash_buffer_pct": 10,
  "max_position_pct": 25,
  "paper": true,
  "sec_user_agent": "Seu Nome voce@exemplo.com"
}
```

Troque pelo seu nome e email de verdade e pelo seu orçamento. Mantenha
`"paper": true`.

## Passo 3: primeira rodada no Claude

Feche e abra o Terminal (o Claude Code só descobre skills novas ao
iniciar), depois:

```bash
cd ~/trader-projeto
claude
```

Dentro do Claude, digite nesta ordem:

```text
/trader-copycat
copy Berkshire top 5
```

Ele vai ler o 13F mais recente da Berkshire Hathaway direto da SEC,
dizer a data do documento (é uma foto do fim do trimestre, publicada
até 45 dias depois) e gravar `trader/targets.json`. Em seguida:

```text
/trader-budget
```
(seu orçamento do config: ele propõe quanto comprar de cada ação,
respeitando o buffer de caixa e o teto por ação)

```text
/trader-risk
```
(PASS ou BLOCK em cada proposta, com o motivo)

```text
/trader-broker
```
(mostra um ticket por vez; sem corretora conectada, para por aqui, e
está ótimo para aprender. Conectar a Alpaca em conta paper é um passo
depois, descrito em `trader-broker/SKILL.md`)

Para o dia a dia: `/trader-news`, `/trader-pelosi`, `/trader-alerts`,
`/trader-analyst`, `/trader-screener`, `/trader-tax`,
`/trader-rebalance`.

## Conferindo sem abrir o Claude

```bash
ls ~/.claude/skills/
python3 ~/.claude/skills/trader-alerts/alerts.py clock
python3 ~/.claude/skills/trader-copycat/edgar13f.py find buffett
```

## Se algo travar (Mac)

- **A skill não aparece no Claude.** Reiniciou o `claude` depois de
  instalar? Confira `ls ~/.claude/skills/`: tem que haver 11 pastas
  `trader-*`, cada uma com um `SKILL.md` dentro.
- **`command not found: claude` logo depois de instalar.** Feche e
  abra o Terminal. Se persistir, rode `claude doctor` após reabrir.
- **Gatekeeper bloqueou o `instalar-mac.command`.** Botão direito no
  arquivo, `Abrir`, confirmar. Nunca precisa desativar a segurança do
  Mac para isto.
- **Erro pedindo User-Agent da SEC.** Falta a linha `sec_user_agent`
  do Passo 2, ou a variável de ambiente: `export SEC_USER_AGENT="Seu Nome voce@exemplo.com"`.
- **Quero desinstalar.** Apague as pastas `trader-*` de
  `~/.claude/skills/` e, se quiser, `~/trader-projeto` e `~/trader-skill`.

Guia completo (todas as plataformas, corretora, segurança):
`INSTALACAO.md`. Isto não é consultoria financeira: é uma ferramenta
que lê dados públicos e faz contas. Fique no paper até dominar o fluxo.

Prefere o OpenCode ao Claude Code neste Mac? Funciona também: veja
`OPENCODE.md` (instalação com `./install.sh --opencode`).
