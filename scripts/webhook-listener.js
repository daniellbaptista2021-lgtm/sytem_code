#!/usr/bin/env node
// ============================================================
// SYSTEM CODE — Webhook Listener
// Recebe chamadas externas (N8N, Zapier, etc.) e executa acoes
// Leve: sem frameworks, apenas Node.js nativo
// Inicie com: node scripts/webhook-listener.js
// ============================================================

const http = require('http');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// --- Configuracao ---
const PORT = process.env.WEBHOOK_PORT || 9000;
const SECRET = process.env.WEBHOOK_SECRET || '';
const LOG_DIR = path.join(__dirname, '..', 'logs');
const LOG_FILE = path.join(LOG_DIR, 'webhook.log');

// Garantir diretorio de logs
if (!fs.existsSync(LOG_DIR)) fs.mkdirSync(LOG_DIR, { recursive: true });

// --- Logger ---
function log(level, msg, data = null) {
    const ts = new Date().toISOString();
    const entry = `[${ts}] [${level}] ${msg}${data ? ' | ' + JSON.stringify(data) : ''}`;
    console.log(entry);
    fs.appendFileSync(LOG_FILE, entry + '\n');
}

// --- Verificar assinatura (seguranca) ---
function verifySignature(body, signature) {
    if (!SECRET) return true; // sem secret configurado, permite tudo
    const expected = 'sha256=' + crypto.createHmac('sha256', SECRET).update(body).digest('hex');
    return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(signature || ''));
}

// --- Acoes disponiveis ---
const ACTIONS = {
    // Verificar saude dos servicos
    'health-check': () => {
        const script = path.join(__dirname, 'health.sh');
        return execSync(`bash ${script} 2>&1`).toString();
    },

    // Git pull (atualizar projeto)
    'git-pull': () => {
        const baseDir = path.join(__dirname, '..');
        return execSync(`cd ${baseDir} && git pull 2>&1`).toString();
    },

    // Listar logs recentes
    'get-logs': (body) => {
        const lines = parseInt(body.lines) || 50;
        const logFile = path.join(LOG_DIR, (body.file || 'health') + '.log');
        if (!fs.existsSync(logFile)) return 'Arquivo de log nao encontrado';
        const content = fs.readFileSync(logFile, 'utf8').split('\n');
        return content.slice(-lines).join('\n');
    },

    // Ping simples
    'ping': () => 'pong',
};

// --- Servidor HTTP ---
const server = http.createServer((req, res) => {
    const ts = new Date().toISOString();

    // Apenas POST na rota /webhook
    if (req.method !== 'POST' || req.url !== '/webhook') {
        if (req.method === 'GET' && req.url === '/health') {
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ status: 'ok', ts }));
            return;
        }
        res.writeHead(404);
        res.end('Not Found');
        return;
    }

    let rawBody = '';
    req.on('data', chunk => { rawBody += chunk.toString(); });
    req.on('end', () => {
        try {
            // Verificar assinatura
            const sig = req.headers['x-hub-signature-256'] || req.headers['x-signature'];
            if (SECRET && !verifySignature(rawBody, sig)) {
                log('WARN', 'Requisicao rejeitada: assinatura invalida', { ip: req.socket.remoteAddress });
                res.writeHead(401);
                res.end('Unauthorized');
                return;
            }

            const body = JSON.parse(rawBody || '{}');
            const action = body.action || 'ping';

            log('INFO', `Webhook recebido`, { action, ip: req.socket.remoteAddress });

            if (!ACTIONS[action]) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: `Acao desconhecida: ${action}`, available: Object.keys(ACTIONS) }));
                return;
            }

            const result = ACTIONS[action](body);
            log('INFO', `Acao executada: ${action}`);

            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ ok: true, action, result, ts }));

        } catch (err) {
            log('ERROR', `Erro ao processar webhook: ${err.message}`);
            res.writeHead(500, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: err.message }));
        }
    });
});

server.listen(PORT, '0.0.0.0', () => {
    log('INFO', `Webhook listener iniciado na porta ${PORT}`);
    log('INFO', `Rotas: POST /webhook | GET /health`);
    log('INFO', `Acoes disponiveis: ${Object.keys(ACTIONS).join(', ')}`);
});

server.on('error', (err) => {
    log('ERROR', `Erro no servidor: ${err.message}`);
    process.exit(1);
});

process.on('SIGTERM', () => { log('INFO', 'Encerrando...'); server.close(); });
process.on('SIGINT', () => { log('INFO', 'Encerrando...'); server.close(); });
