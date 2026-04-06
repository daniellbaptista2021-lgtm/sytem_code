#!/bin/bash
# ============================================================
# SYSTEM CODE — Script de Setup Automatico
# Execute: bash setup.sh
# Compativel com Ubuntu/Debian sem sudo
# ============================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[SETUP]${NC} $1"; }
warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
error() { echo -e "${RED}[ERRO]${NC} $1"; exit 1; }

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log "Iniciando setup do System Code..."
log "Diretorio base: $BASE_DIR"

# --- 1. Verificar Git ---
if command -v git &>/dev/null; then
    log "Git encontrado: $(git --version)"
else
    error "Git nao encontrado. Instale manualmente: apt-get install git"
fi

# --- 2. Instalar GitHub CLI (sem sudo) ---
GH_BIN="$HOME/bin/gh"
if command -v gh &>/dev/null || [ -f "$GH_BIN" ]; then
    log "GitHub CLI ja instalado: $(gh --version | head -1)"
else
    log "Instalando GitHub CLI..."
    mkdir -p "$HOME/bin"
    GH_VERSION="2.63.2"
    GH_URL="https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz"
    curl -sL "$GH_URL" -o /tmp/gh.tar.gz
    tar -xzf /tmp/gh.tar.gz -C /tmp/
    cp "/tmp/gh_${GH_VERSION}_linux_amd64/bin/gh" "$HOME/bin/gh"
    chmod +x "$HOME/bin/gh"
    rm -rf /tmp/gh.tar.gz "/tmp/gh_${GH_VERSION}_linux_amd64"
    log "GitHub CLI instalado em $GH_BIN"
fi

# --- 3. Configurar PATH ---
SHELL_RC="$HOME/.bashrc"
if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$SHELL_RC" 2>/dev/null; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$SHELL_RC"
    log "PATH atualizado em $SHELL_RC"
fi
export PATH="$HOME/bin:$PATH"

# --- 4. Criar diretorios necessarios ---
mkdir -p "$BASE_DIR/logs"
mkdir -p "$BASE_DIR/scripts"
log "Diretorios criados"

# --- 5. Configurar .env ---
if [ ! -f "$BASE_DIR/.env" ]; then
    if [ -f "$BASE_DIR/.env.example" ]; then
        cp "$BASE_DIR/.env.example" "$BASE_DIR/.env"
        warn ".env criado a partir do .env.example — edite com suas credenciais reais"
    fi
else
    log ".env ja existe, mantendo configuracoes"
fi

# --- 6. Verificar Node.js (para webhook listener) ---
if command -v node &>/dev/null; then
    log "Node.js encontrado: $(node --version)"
else
    warn "Node.js nao encontrado. O webhook listener nao funcionara sem ele."
    warn "Instale com: curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs"
fi

# --- 7. Configurar logrotate local ---
LOGROTATE_CONF="$HOME/.logrotate.conf"
cat > "$LOGROTATE_CONF" << EOF
$BASE_DIR/logs/*.log {
    daily
    rotate 30
    compress
    missingok
    notifempty
    size 10M
    create 0644 $USER $USER
}
EOF
log "Configuracao de logrotate criada em $LOGROTATE_CONF"

# --- 8. Configurar cron para logrotate e health check ---
CRON_JOB_LOG="0 0 * * * /usr/sbin/logrotate -s $HOME/.logrotate.state $LOGROTATE_CONF 2>/dev/null"
CRON_JOB_HEALTH="*/15 * * * * $BASE_DIR/scripts/health.sh >> $BASE_DIR/logs/health.log 2>&1"

(crontab -l 2>/dev/null | grep -v "logrotate\|health.sh"; echo "$CRON_JOB_LOG"; echo "$CRON_JOB_HEALTH") | crontab -
log "Cron configurado: logrotate diario + health check a cada 15 minutos"

# --- Finalizado ---
echo ""
log "============================================"
log "Setup concluido com sucesso!"
log "============================================"
echo ""
echo "  Proximos passos:"
echo "  1. Edite .env com suas credenciais reais"
echo "  2. Execute: gh auth login (para autenticar GitHub)"
echo "  3. Execute: bash scripts/health.sh (para verificar servicos)"
echo "  4. Execute: node scripts/webhook-listener.js (para iniciar webhook)"
echo ""
