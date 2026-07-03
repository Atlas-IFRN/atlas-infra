# atlas-infra

Infraestrutura centralizada do **Atlas** — orquestração de todos os serviços via Docker Compose, configuração do Nginx, scripts de deploy e backup.

## Estrutura

```
atlas-infra/
├── docker-compose.yml          # Compose canônico de produção (10 containers)
├── docker-compose.dev.yml      # Overrides para desenvolvimento local
├── .env.example                # Template de variáveis de ambiente (sem secrets)
├── nginx/
│   └── nginx.conf              # Gateway principal com auth_request
├── postgres/
│   └── init.sql                # Inicialização dos schemas auth/tracks/scholarship
└── scripts/
    ├── backup.sh               # Backup automático via pg_dump
    └── deploy.sh               # Script de deploy no VPS
```

## Arquitetura

10 containers Docker orquestrados via Compose. O **Nginx** é o único ponto de entrada externo — valida tokens via `auth_request` antes de repassar qualquer requisição.

```
[Cliente] → Nginx (80/443)
               ├── auth_request → auth-service:8000
               ├── /api/auth/        → auth-service:8000
               ├── /api/track/       → tracks-service:8001
               ├── /api/scholarship/ → scholarship-service:8002
               └── /api/ai/          → ia-service:8003
```

| Container | Imagem | Porta interna |
|---|---|---|
| `nginx` | nginx:alpine | 80 / 443 (expostas) |
| `auth-service` | atlas-auth | 8000 |
| `tracks-service` | atlas-tracks | 8001 |
| `scholarship-service` | atlas-scholarship | 8002 |
| `ia-service` | atlas-ia | 8003 |
| `celery-worker-tracks` | atlas-tracks | — |
| `celery-worker-scholarship` | atlas-scholarship | — |
| `postgres` | postgres:16 | 5432 |
| `redis` | redis:7 | 6379 |
| `rabbitmq` | rabbitmq:3-management | 5672 / 15672 |

## Como usar

### Produção (VPS)

```bash
# Clonar e configurar
git clone https://github.com/Atlas-IFRN/atlas-infra ~/atlas
cd ~/atlas
cp .env.example .env
# editar .env com as variáveis reais

# Subir todos os serviços
docker compose up -d

# Verificar status
docker compose ps
```

### Desenvolvimento local

```bash
# Sobe apenas a infra compartilhada (postgres, redis, rabbitmq, nginx)
docker compose -f docker-compose.dev.yml up -d
```

> Cada serviço backend pode ser rodado individualmente via `python manage.py runserver` apontando para essa infra local.

## Variáveis de ambiente

Copie `.env.example` para `.env` e preencha os valores. Nunca commite o `.env` real.

## Backup

O script `scripts/backup.sh` executa `pg_dump` e salva em `/backups/` com timestamp. Configure um cron no VPS:

```bash
0 3 * * * /home/ubuntu/atlas/scripts/backup.sh
```

## Deploy

```bash
bash scripts/deploy.sh
```

O script faz pull das imagens mais recentes e recria os containers com zero downtime para os serviços stateless.

---

> Os `Dockerfile` de cada serviço permanecem em seus respectivos repositórios. Apenas a orquestração vive aqui.

