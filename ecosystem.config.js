// ============================================================
// SYSTEM CODE — PM2 Ecosystem Config
// Gerencia o webhook-listener como servico permanente
// Inicie com: ~/pm2_local/node_modules/pm2/bin/pm2 start ecosystem.config.js
// ============================================================

module.exports = {
    apps: [
        {
            name: 'system-code-webhook',
            script: './scripts/webhook-listener.js',
            cwd: '/home/claude/system_code',

            // Reinicio automatico
            watch: false,
            autorestart: true,
            restart_delay: 3000,
            max_restarts: 10,

            // Ambiente
            env: {
                NODE_ENV: 'production',
                WEBHOOK_PORT: 9000,
                PM2_HOME: '/home/claude/.pm2_home'
            },

            // Logs
            out_file: '/home/claude/system_code/logs/webhook-out.log',
            error_file: '/home/claude/system_code/logs/webhook-error.log',
            log_date_format: 'YYYY-MM-DD HH:mm:ss',
            merge_logs: true,

            // Limites de memoria (leve na VPS)
            max_memory_restart: '100M',

            // Graceful shutdown
            kill_timeout: 5000,
            listen_timeout: 3000,
        }
    ]
};
