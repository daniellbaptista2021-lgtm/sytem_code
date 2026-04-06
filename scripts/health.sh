#!/bin/bash
# ============================================================
# SYSTEM CODE — Health Check
# Verifica servicos essenciais e registra status
# Executado automaticamente pelo cron a cada 15 minutos
# ============================================================

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$BASE_DIR/logs/health.log"
ENV_FILE="$BASE_DIR/.env"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
STATUS="OK"
ISSUES=()

mkdir -p "$BASE_DIR/logs"

# Carregar variaveis de ambiente
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

log() { echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"; }

# --- Verificar Git ---
if command -v git &>/dev/null; then
    GIT_STATUS=$(cd "$BASE_DIR" && git status --short 2>/dev/null | wc -l)
    log "GIT: OK | arquivos modificados nao commitados: $GIT_STATUS"
else
    ISSUES+=("Git nao encontrado")
fi

# --- Verificar GitHub CLI ---
if command -v gh &>/dev/null || [ -f "$HOME/bin/gh" ]; then
    log "GITHUB_CLI: OK"
else
    ISSUES+=("GitHub CLI nao instalado")
fi

# --- Verificar N8N (se configurado) ---
if [ -n "$N8N_BASE_URL" ] && [ "$N8N_BASE_URL" != "http://localhost:5678" ]; then
    N8N_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$N8N_BASE_URL" 2>/dev/null)
    if [ "$N8N_CODE" = "200" ] || [ "$N8N_CODE" = "302" ] || [ "$N8N_CODE" = "401" ]; then
        log "N8N: OK | status HTTP $N8N_CODE"
    else
        ISSUES+=("N8N indisponivel (HTTP $N8N_CODE)")
        log "N8N: FALHA | status HTTP $N8N_CODE"
    fi
else
    log "N8N: nao configurado"
fi

# --- Verificar Evolution API (se configurado) ---
if [ -n "$EVOLUTION_API_URL" ] && [ "$EVOLUTION_API_URL" != "http://localhost:8080" ]; then
    EVO_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$EVOLUTION_API_URL" 2>/dev/null)
    if [ "$EVO_CODE" = "200" ] || [ "$EVO_CODE" = "302" ] || [ "$EVO_CODE" = "401" ]; then
        log "EVOLUTION_API: OK | status HTTP $EVO_CODE"
    else
        ISSUES+=("Evolution API indisponivel (HTTP $EVO_CODE)")
        log "EVOLUTION_API: FALHA | status HTTP $EVO_CODE"
    fi
else
    log "EVOLUTION_API: nao configurado"
fi

# --- Verificar Webhook Listener ---
WEBHOOK_PORT="${WEBHOOK_PORT:-9000}"
if lsof -i ":$WEBHOOK_PORT" &>/dev/null 2>&1 || ss -tlnp | grep -q ":$WEBHOOK_PORT"; then
    log "WEBHOOK_LISTENER: OK | porta $WEBHOOK_PORT ativa"
else
    log "WEBHOOK_LISTENER: inativo | porta $WEBHOOK_PORT"
fi

# --- Verificar uso de disco ---
DISK_USAGE=$(df -h "$BASE_DIR" | awk 'NR==2{print $5}' | tr -d '%')
if [ "$DISK_USAGE" -gt 85 ] 2>/dev/null; then
    ISSUES+=("Disco com ${DISK_USAGE}% de uso")
    log "DISCO: ATENCAO | ${DISK_USAGE}% utilizado"
else
    log "DISCO: OK | ${DISK_USAGE:-?}% utilizado"
fi

# --- Verificar uso de memoria ---
MEM_FREE=$(free -m | awk 'NR==2{print $7}')
if [ "${MEM_FREE:-0}" -lt 100 ] 2>/dev/null; then
    ISSUES+=("Memoria livre baixa: ${MEM_FREE}MB")
    log "MEMORIA: ATENCAO | ${MEM_FREE}MB livre"
else
    log "MEMORIA: OK | ${MEM_FREE:-?}MB livre"
fi

# --- Resultado final ---
if [ ${#ISSUES[@]} -eq 0 ]; then
    log "RESULTADO: TODOS OS SERVICOS OK"
else
    STATUS="FALHA"
    log "RESULTADO: PROBLEMAS DETECTADOS"
    for issue in "${ISSUES[@]}"; do
        log "  - $issue"
    done

    # Enviar alerta via Telegram (se configurado)
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ] && \
       [ "$TELEGRAM_BOT_TOKEN" != "seu_bot_token" ]; then
        MSG="*System Code — Alerta*%0A$(date '+%d/%m/%Y %H:%M')%0A%0AProblemas detectados:%0A"
        for issue in "${ISSUES[@]}"; do
            MSG="${MSG}- ${issue}%0A"
        done
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}&text=${MSG}&parse_mode=Markdown" > /dev/null 2>&1
        log "ALERTA: enviado via Telegram"
    fi
fi

log "---"
exit 0
