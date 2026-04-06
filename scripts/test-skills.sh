#!/usr/bin/env bash
# ============================================================
# SYSTEM CODE — Teste de Integracao das Skills
# Valida estrutura e conteudo de cada skill instalada
# Uso: bash scripts/test-skills.sh [caminho-das-skills]
# ============================================================

set -euo pipefail

SKILLS_DIR="${1:-$HOME/.claude/skills}"
PASS=0
FAIL=0
ERRORS=()

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); ERRORS+=("$1"); }
log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

echo "============================================================"
echo "  SYSTEM CODE — Teste de Integracao das Skills"
echo "  Diretorio: $SKILLS_DIR"
echo "  Data: $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"
echo ""

# Skills obrigatorias
REQUIRED_SKILLS=(
    "content-humanizer"
    "landing-page-generator"
    "paid-ads"
    "ad-creative"
    "agent-designer"
    "mcp-server-builder"
    "design_system"
    "campaign-analytics"
    "copywriting"
    "saas-metrics-coach"
)

# --- Teste 1: Diretorio de skills existe ---
log_info "Verificando diretorio de skills..."
if [ -d "$SKILLS_DIR" ]; then
    log_pass "Diretorio $SKILLS_DIR existe"
else
    log_fail "Diretorio $SKILLS_DIR NAO encontrado"
    echo ""
    echo "RESULTADO: $PASS passou | $FAIL falhou"
    exit 1
fi

# --- Teste 2: Cada skill obrigatoria esta instalada ---
echo ""
log_info "Verificando skills instaladas..."
for skill in "${REQUIRED_SKILLS[@]}"; do
    if [ -d "$SKILLS_DIR/$skill" ]; then
        log_pass "Skill '$skill' instalada"
    else
        log_fail "Skill '$skill' NAO encontrada em $SKILLS_DIR"
    fi
done

# --- Teste 3: Cada skill tem SKILL.md ---
echo ""
log_info "Verificando SKILL.md em cada skill..."
for skill in "${REQUIRED_SKILLS[@]}"; do
    skill_dir="$SKILLS_DIR/$skill"
    if [ -d "$skill_dir" ]; then
        if [ -f "$skill_dir/SKILL.md" ]; then
            log_pass "$skill/SKILL.md existe"
        else
            log_fail "$skill/SKILL.md NAO encontrado"
        fi
    fi
done

# --- Teste 4: SKILL.md nao esta vazio ---
echo ""
log_info "Verificando conteudo dos SKILL.md..."
for skill in "${REQUIRED_SKILLS[@]}"; do
    skill_file="$SKILLS_DIR/$skill/SKILL.md"
    if [ -f "$skill_file" ]; then
        size=$(wc -c < "$skill_file")
        if [ "$size" -gt 50 ]; then
            log_pass "$skill/SKILL.md tem conteudo ($size bytes)"
        else
            log_fail "$skill/SKILL.md esta vazio ou muito pequeno ($size bytes)"
        fi
    fi
done

# --- Teste 5: Sem arquivos sensiveis nas skills ---
echo ""
log_info "Verificando seguranca das skills..."
sensitive_found=0
for pattern in "ghp_" "sk-live" "password=" "Bearer ey"; do
    result=$(grep -r "$pattern" "$SKILLS_DIR" --include="*.md" --include="*.py" --include="*.js" --include="*.sh" 2>/dev/null || true)
    if [ -n "$result" ]; then
        log_fail "Credencial exposta nas skills com padrao: '$pattern'"
        sensitive_found=1
    fi
done
if [ $sensitive_found -eq 0 ]; then
    log_pass "Nenhuma credencial exposta nas skills"
fi

# --- Teste 6: Webhook listener responde ---
echo ""
log_info "Verificando webhook listener..."
WEBHOOK_PORT="${WEBHOOK_PORT:-9000}"
if curl -sf "http://localhost:$WEBHOOK_PORT/health" > /dev/null 2>&1; then
    response=$(curl -s "http://localhost:$WEBHOOK_PORT/health")
    if echo "$response" | grep -q '"status":"ok"'; then
        log_pass "Webhook listener online na porta $WEBHOOK_PORT"
    else
        log_fail "Webhook listener respondeu mas status inesperado: $response"
    fi
else
    log_fail "Webhook listener NAO esta respondendo na porta $WEBHOOK_PORT"
fi

# --- Teste 7: Webhook executa acao ping ---
echo ""
log_info "Testando acoes do webhook..."
if curl -sf "http://localhost:$WEBHOOK_PORT/health" > /dev/null 2>&1; then
    ping_result=$(curl -s -X POST "http://localhost:$WEBHOOK_PORT/webhook" \
        -H "Content-Type: application/json" \
        -d '{"action":"ping"}' 2>/dev/null || echo "erro")
    if echo "$ping_result" | grep -q '"result":"pong"'; then
        log_pass "Webhook acao 'ping' funcionando"
    else
        log_fail "Webhook acao 'ping' falhou: $ping_result"
    fi
else
    log_info "Webhook offline — pulando testes de acao"
fi

# --- Resultado final ---
echo ""
echo "============================================================"
TOTAL=$((PASS + FAIL))
echo "  TOTAL: $TOTAL testes | ${GREEN}$PASS passaram${NC} | ${RED}$FAIL falharam${NC}"
echo "============================================================"

if [ ${#ERRORS[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}ERROS:${NC}"
    for err in "${ERRORS[@]}"; do
        echo "  - $err"
    done
fi

echo ""
if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}Todos os testes passaram.${NC}"
    exit 0
else
    echo -e "${RED}$FAIL teste(s) falharam.${NC}"
    exit 1
fi
