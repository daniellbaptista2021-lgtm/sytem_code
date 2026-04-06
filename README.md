# System Code

Agente profissional de producao, codigo e automacao rodando no Claude Code.

**Especialidades:** desenvolvimento de sites, fluxos N8N, automacao de WhatsApp, APIs, integracao de sistemas e infraestrutura.

---

## Estrutura do Projeto

```
system_code/
├── .env.example              # Template de variaveis de ambiente
├── .env                      # Credenciais reais (NAO versionado)
├── .gitignore
├── .github/
│   └── workflows/
│       └── ci.yml            # GitHub Actions — validacao automatica
├── plugins/
│   ├── installed_plugins.json
│   └── known_marketplaces.json
├── scripts/
│   ├── health.sh             # Health check dos servicos
│   └── webhook-listener.js  # Servidor webhook leve (Node.js)
├── logs/                     # Logs de runtime (nao versionados)
├── settings.json             # Permissoes e plugins do agente
└── setup.sh                  # Setup automatico do ambiente
```

---

## Setup em Nova VPS

```bash
# 1. Clonar o repositorio
git clone https://github.com/daniellbaptista2021-lgtm/sytem_code.git
cd sytem_code

# 2. Executar setup automatico
bash setup.sh

# 3. Editar credenciais
cp .env.example .env
nano .env
```

---

## Scripts Disponiveis

### Health Check
Verifica Git, GitHub CLI, N8N, Evolution API, disco e memoria.
```bash
bash scripts/health.sh
```

### Webhook Listener
Servidor HTTP leve que recebe chamadas do N8N, Zapier ou qualquer sistema externo.
```bash
node scripts/webhook-listener.js
```

**Rotas:**
- `GET /health` — status do servidor
- `POST /webhook` — executa acoes

**Acoes disponiveis via POST:**
```json
{ "action": "ping" }
{ "action": "health-check" }
{ "action": "git-pull" }
{ "action": "get-logs", "file": "health", "lines": 50 }
```

---

## Variaveis de Ambiente

Copie `.env.example` para `.env` e preencha:

| Variavel | Descricao |
|---|---|
| `GITHUB_TOKEN` | Personal Access Token do GitHub |
| `N8N_BASE_URL` | URL base do N8N |
| `EVOLUTION_API_URL` | URL da Evolution API (WhatsApp) |
| `TELEGRAM_BOT_TOKEN` | Token do bot Telegram para alertas |
| `WEBHOOK_PORT` | Porta do webhook listener (padrao: 9000) |
| `WEBHOOK_SECRET` | Secret para validar requisicoes (opcional) |

---

## CI/CD

GitHub Actions valida automaticamente a cada push:
- Sintaxe do `settings.json`
- Presenca do `.env.example`
- Garantia que `.env` nao esta versionado
- Sintaxe dos scripts bash e JS

---

## Versionamento

| Tag | Descricao |
|---|---|
| `v1.0` | Versao inicial — configuracao base do agente |
| `v1.1` | Setup automatico, health check, webhook listener, CI |
