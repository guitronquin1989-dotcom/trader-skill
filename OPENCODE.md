# trader-skill no OpenCode

Resposta curta: **sim, roda.** O OpenCode usa o mesmo formato aberto de
Agent Skills (`SKILL.md` com `name` e `description`) e lê inclusive as
pastas do Claude Code. As ferramentas são Python puro, então nada muda
nelas: quem muda é só o agente que conversa com você.

Verificado de verdade em 2026-10-26 com o OpenCode **1.19.4**: o comando
`opencode debug skill` listou as 11 skills `trader-*` instaladas, sem
nenhum erro de leitura. Documentação oficial das skills do OpenCode:
https://opencode.ai/docs/skills/

## Instalação guiada no Mac (recomendada)

```bash
git clone -b arena/23cdc45d-trader-skill https://github.com/guitronquin1989-dotcom/trader-skill.git ~/trader-skill
cd ~/trader-skill
bash instalar-opencode-mac.sh --checar
```

O instalador pergunta antes de instalar o OpenCode, mantém **uma cópia
só** das skills, cria `~/trader-projeto` com config em paper,
`AGENTS.md` e permissão local para as skills, e termina conferindo
`opencode debug skill` (tem que enxergar 11). Ele não faz login em
provedor nem pede chave: depois rode `opencode auth login` (ou
`/connect` dentro do OpenCode) e abra o `opencode` no projeto.

As seções abaixo são o caminho manual, equivalentes.

## Instalar o OpenCode no Mac (se ainda não tem)

```bash
curl -fsSL https://opencode.ai/install | bash
# ou, com Homebrew:
# brew install anomalyco/tap/opencode
opencode --version
```

Depois abra o `opencode` uma vez e conecte um provedor/modelo (o
OpenCode é agnóstico de modelo: Anthropic, OpenAI, Google, modelos
locais etc.). Use um modelo capaz: as skills são instruções longas e
detalhadas, e modelo fraco segue instrução pior. Sem provedor
configurado, as skills são descobertas, mas ninguém as executa.

## Instalar as skills para o OpenCode (escolha UM caminho)

### Caminho 1: você já instalou para o Claude Code

Não instale nada. O OpenCode lê `~/.claude/skills/` e `.claude/skills/`
como locais compatíveis. Só feche e abra o OpenCode e confira:

```bash
opencode debug skill | grep '"name": "trader-'
# tem que listar 11 linhas (trader-copycat ... trader-rebalance)
```

### Caminho 2: instalação nativa do OpenCode

```bash
cd ~/trader-skill
./install.sh --opencode --demo
# só neste projeto, em vez de global:
# ./install.sh --opencode --project
```

Isso copia as 11 pastas para `~/.config/opencode/skills/` (ou
`./.opencode/skills/`) e ajusta os caminhos das ferramentas nas cópias
(veja a nota sobre `${CLAUDE_SKILL_DIR}` abaixo).

**Mantenha uma cópia só.** O OpenCode deduplica skills por nome entre
todos os locais que ele varre. Se as duas cópias existirem (Claude e
OpenCode), ele carrega uma delas e pode ser a antiga. Se você usa os
dois agentes na mesma máquina, a cópia de `~/.claude/skills/` serve
aos dois: fique só com ela (Caminho 1).

## Como usar dentro do OpenCode

A maior diferença prática: **skill no OpenCode não é comando de barra.**
Não existe `/trader-copycat` no menu. Quem decide carregar a skill é o
agente, lendo a descrição dela. Então peça em linguagem natural,
citando o nome da skill para não depender de adivinhação:

```bash
cd ~/trader-projeto
opencode
```

```text
Use a skill trader-copycat para copiar o top 5 da Berkshire Hathaway.
Depois use trader-budget com o meu config, trader-risk nas propostas
e me mostre os tickets com trader-broker. Não envie nenhuma ordem.
```

Exemplos equivalentes para as outras: "use a skill trader-pelosi e me
mostre os PTRs novos da Pelosi", "use trader-analyst na AAPL", "use
trader-alerts e me diga se a NYSE está aberta".

A configuração continua a mesma do Claude: `trader/config.json` no seu
projeto, com `"sec_user_agent": "Seu Nome voce@exemplo.com"` (exigência
da SEC) e `"paper": true`. É a pasta onde você roda o `opencode` que
recebe a pasta `trader/` com `targets.json`, `orders.json` etc.

### Ajuda opcional ao agente: um AGENTS.md no seu projeto

Se você notar o agente patinando nos caminhos (a cópia do Caminho 1
traz `${CLAUDE_SKILL_DIR}` literal no texto, porque quem substituía
essa variável era o Claude Code), cole isto num `AGENTS.md` na raiz do
seu projeto:

```markdown
# trader-skill neste projeto

- Quando um SKILL.md disser `${CLAUDE_SKILL_DIR}`, isso é a pasta onde
  aquele SKILL.md mora (ex.: ~/.claude/skills/trader-budget/). Rode a
  ferramenta Python daquela pasta, nunca invente o caminho.
- Quando um SKILL.md disser /trader-risk ou /trader-broker, isso quer
  dizer: carregue a skill com esse nome e siga as instruções dela.
- Paper trading sempre (`"paper": true` em trader/config.json).
  Nenhuma ordem sem o meu yes explícito para aquela ordem exata.
```

As cópias do Caminho 2 já vêm com o caminho absoluto no lugar da
variável, então o `AGENTS.md` é só um reforço.

### Permissões (opcional)

O OpenCode permite controlar o carregamento de skills em
`opencode.json`. Para liberar as do trader explicitamente:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "skill": { "trader-*": "allow" }
  }
}
```

`ask` faz o OpenCode pedir sua aprovação antes de carregar a skill;
`deny` esconde a skill do agente.

## O que muda em relação ao Claude Code

| tema | Claude Code | OpenCode |
| --- | --- | --- |
| invocar | `/trader-copycat` | pedir em linguagem natural citando a skill |
| onde mora | `~/.claude/skills/` | `~/.config/opencode/skills/` (e ele também lê a pasta do Claude) |
| plugin marketplace | `/plugin install ...` | não se aplica: copiar as pastas é o jeito |
| `argument-hint` no frontmatter | usado na UI | ignorado (campos desconhecidos são ignorados) |
| modelo | Claude | o provedor que você conectar |
| corretora (MCP) | config do Claude + cartão Allow/Deny | MCP se configura no `opencode.json`; o arquivo de exemplo do Claude Desktop não é lido aqui |

Sobre a corretora, na prática: no OpenCode o fluxo para no ticket do
`trader-broker`, igual ao Claude sem corretora. Conectar o MCP da
Alpaca no OpenCode é possível, mas é uma configuração própria dele
(não copie o `claude_desktop_config.example.json` para cá) e as regras
continuam: conta paper, `trader-risk` aprovado e o seu `yes` para cada
ordem. Na dúvida, não conecte corretora nenhuma no começo.

## Se a skill não aparecer

```bash
opencode debug skill | grep trader          # descobriu?
ls ~/.config/opencode/skills/ ~/.claude/skills/   # uma copia so?
```

- Reiniciou o OpenCode depois de instalar? Config e skills são lidos
  na inicialização.
- `SKILL.md` é tudo maiúsculo, uma pasta por skill, nome da pasta
  igual ao `name:` do frontmatter (este repo já vem assim).
- Variáveis `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1` ou
  `OPENCODE_DISABLE_CLAUDE_CODE=1` desligam a leitura de
  `~/.claude/skills/`; se você as usa, fique com o Caminho 2.
- Permissão `deny` para `skill` esconde a skill do agente.

## O que foi testado aqui (e o que só roda aí)

Testado no sandbox em 2026-10-26: OpenCode 1.19.4 instalado via npm
descobre e lê as 11 skills de `~/.claude/skills/` (`debug skill` sem
erros), nomes e descrições passam nas regras do OpenCode, o
`./install.sh --opencode` instala na pasta nativa com os caminhos
ajustados, e o `instalar-opencode-mac.sh` passou em HOMEs limpas nos
modos nativo e compatível, criando projeto e enxergando 11 de 11. O
pipeline em Python (budget, risk, broker) é o mesmo já provado na
demo. A conversa com um modelo dentro do OpenCode (quem de fato
carrega a skill e roda os comandos) só acontece na sua máquina, com
o seu provedor conectado: no sandbox do Arena as chamadas de modelo
ficam sem rede e expiram.

Isto não é consultoria financeira. Fique no paper. Guia geral:
`INSTALACAO.md`; no Mac: `COMECE-AQUI-MAC.md`.
