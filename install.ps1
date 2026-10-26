# Instalador do trader-skill - Windows (PowerShell)
#
# Uso (numa janela do PowerShell, dentro da pasta do repo):
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -Project   # instala em .\.claude\skills
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -Demo      # + demo offline (Berkshire, US$ 5.000)
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -NoTest    # pula os testes
#
# Instala as 11 skills em %USERPROFILE%\.claude\skills\
# Sem pip install (tudo e biblioteca padrao do Python 3.8+).
# Nada aqui envia ordem para corretora. Paper trading e o padrao.
param(
    [switch]$Project,
    [switch]$Demo,
    [switch]$NoTest
)
$ErrorActionPreference = "Stop"

$RepoUrl   = if ($env:TRADER_SKILL_REPO) { $env:TRADER_SKILL_REPO } else { "https://github.com/Jakeschincariol/trader-skill.git" }
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Dest      = if ($env:CLAUDE_SKILLS_DIR) { $env:CLAUDE_SKILLS_DIR }
             elseif ($Project) { Join-Path $ScriptDir ".claude\skills" }
             else { Join-Path $HOME ".claude\skills" }

Write-Host "== trader-skill - instalador (Windows) =="

# --- 1) Python 3.8+ ---------------------------------------------------------
$Py = $null; $PyArgs = @()
foreach ($cand in @("python", "py")) {
    if (Get-Command $cand -ErrorAction SilentlyContinue) { $Py = $cand; if ($cand -eq "py") { $PyArgs = @("-3") }; break }
}
if (-not $Py) {
    Write-Error "Python nao encontrado. Instale em https://www.python.org/downloads/ e marque 'Add python.exe to PATH'."
}
& $Py @PyArgs -c "import sys; assert sys.version_info >= (3,8), 'precisa de Python 3.8+'; print('Python OK: ' + sys.version.split()[0])"

# --- 2) Fonte: este clone, ou baixa do GitHub -------------------------------
$Src = $ScriptDir
if (-not (Test-Path (Join-Path $Src "trader-copycat\SKILL.md"))) {
    $Tmp = Join-Path $env:TEMP ("trader-skill-" + [guid]::NewGuid().ToString("N"))
    Write-Host "Clonando $RepoUrl ..."
    git clone --depth 1 $RepoUrl $Tmp
    $Src = $Tmp
}
Write-Host "Fonte: $Src"

# --- 3) Copia as 11 skills (com backup do que ja existia) -------------------
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
$Count = 0
Get-ChildItem -Directory -Path $Src -Filter "trader-*" | ForEach-Object {
    if (-not (Test-Path (Join-Path $_.FullName "SKILL.md"))) { return }
    $target = Join-Path $Dest $_.Name
    if (Test-Path $target) {
        $bk = Join-Path $Dest (".backup-" + (Get-Date -Format "yyyyMMdd-HHmmss") + "\" + $_.Name)
        New-Item -ItemType Directory -Force -Path (Split-Path $bk) | Out-Null
        Copy-Item -Recurse -Force $target $bk
        Remove-Item -Recurse -Force $target
        Write-Host "  backup de $($_.Name) anterior -> $bk"
    }
    Copy-Item -Recurse $_.FullName $target
    Get-ChildItem -Recurse -Directory $target -Filter "__pycache__" -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-Item -Recurse -Force $_.FullName }
    Write-Host "  instalada: /$($_.Name)"
    $script:Count++
}
if ($Count -ne 11) { Write-Error "Esperava 11 skills, instalou $Count" }
Write-Host "11 skills instaladas em: $Dest"

# --- 4) Verificacao ---------------------------------------------------------
if (-not $NoTest -and (Test-Path (Join-Path $Src "tests"))) {
    Write-Host ""
    Write-Host "Rodando os testes offline (poucos segundos)..."
    Push-Location $Src
    try { & $Py @PyArgs -m unittest discover -s tests 2>&1 | Select-Object -Last 4 } finally { Pop-Location }
}
Write-Host ""
Write-Host "Smoke test (usa a copia INSTALADA, nao a do repo):"
# clock sai com codigo 1 quando a NYSE esta fechada: isso e sucesso, nao erro
& $Py @PyArgs (Join-Path $Dest "trader-alerts\alerts.py") clock
$global:LASTEXITCODE = 0
& $Py @PyArgs (Join-Path $Dest "trader-copycat\edgar13f.py") find buffett

# --- 5) Demo opcional -------------------------------------------------------
if ($Demo) {
    Write-Host ""
    Write-Host "== DEMO offline: copiar Berkshire top 5 com US$ 5.000 (nada e enviado) =="
    $DemoTrader = Join-Path $ScriptDir "demo\trader"
    New-Item -ItemType Directory -Force -Path $DemoTrader | Out-Null
    Copy-Item -Force (Join-Path $Src "trader-budget\config.example.json")   (Join-Path $DemoTrader "config.json")
    Copy-Item -Force (Join-Path $Src "trader-copycat\targets.example.json") (Join-Path $DemoTrader "targets.json")
    Copy-Item -Force (Join-Path $Src "tests\fixtures\trader-rebalance\prices.json") (Join-Path $DemoTrader "prices.json")
    Push-Location (Join-Path $ScriptDir "demo")
    try {
        & $Py @PyArgs (Join-Path $Dest "trader-budget\size.py") --budget 5000 --write
        & $Py @PyArgs (Join-Path $Dest "trader-risk\check.py")
        & $Py @PyArgs (Join-Path $Dest "trader-broker\ticket.py") show | Select-Object -First 25
    } finally { Pop-Location }
    Write-Host "Demo escrita em: $DemoTrader (orders.json etc.)"
}

Write-Host ""
Write-Host "PRONTO. Proximos passos:"
Write-Host "1. Feche e abra de novo o Claude Code (ele so descobre skills novas ao iniciar)."
Write-Host "2. No projeto onde voce quer investir, crie trader\config.json a partir de"
Write-Host "   trader-budget\config.example.json e troque:"
Write-Host '     "sec_user_agent": "Seu Nome voce@exemplo.com"   <- a SEC exige nome+email'
Write-Host '   Mantenha "paper": true.'
Write-Host "3. No Claude Code, teste:   /trader-copycat copy Berkshire top 5"
Write-Host "   Depois: /trader-budget -> /trader-risk -> /trader-broker"
Write-Host "   NENHUMA ordem e enviada sem voce digitar yes para aquela ordem exata."
Write-Host ""
Write-Host "Guia completo em portugues: INSTALACAO.md"
Write-Host "Desinstalar: apague as pastas trader-* de $Dest"
