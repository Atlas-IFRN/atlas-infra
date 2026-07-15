# Atlas · Infra 🏗️

> Parte do **Projeto Atlas** — plataforma acadêmica desenvolvida para o **IFRN Campus Pau dos Ferros** como Projeto Integrador de Sistemas Distribuídos. O Atlas conecta alunos a trilhas de conhecimento e bolsas, com avaliação automática de código por IA.

Repositório **central de infraestrutura**: orquestra todos os serviços do Atlas via Docker Compose, define o **gateway Nginx**, inicializa o banco e provê os scripts de **deploy** e **backup**. É o ponto de entrada para subir a plataforma inteira.

## O que este repositório contém

- **`docker-compose.yml`** (+ `dev` e `debug`) — orquestração de toda a stack.
- **`nginx/nginx.conf`** — o gateway: único container exposto ao mundo (80/443).
- **`postgres/init.sql`** — cria o banco único `atlas` e os schemas isolados.
- **`scripts/deploy.sh`** — clona/atualiza os repositórios de código, rebuilda as imagens e recria os containers.
- **`scripts/backup.sh`** — backup automático do PostgreSQL via `pg_dump` (comprimido, com retenção).

## Arquitetura em containers

| Container | Papel |
|---|---|
| **nginx** | Gateway — **único** exposto ao mundo (80/443), TLS, rate limit e `auth_request` |
| auth-service | Identidade (SUAP/JWT), gunicorn `:8000` |
| tracks-service | Trilhas e desafios, gunicorn `:8000` |
| scholarship-service | Bolsas e talentos, gunicorn `:8000` |
| feed-service | Feed institucional, gunicorn `:8000` |
| notification-service | Notificações, gunicorn `:8000` |
| ai-service | Avaliação por IA (FastAPI) `:8003` |
| celery-worker-tracks | Worker da fila `tracks` |
| celery-worker-notifications | Worker da fila `notifications` |
| frontend | SPA React servida por Nginx |
| ollama | LLM local para o ai-service |
| postgres | PostgreSQL 16 — banco único, schemas isolados |
| redis | Cache, sessões e rate limit |
| rabbitmq | Mensageria (Celery, `rabbitmq:3-management`) |

## O gateway Nginx

- **Borda autenticada:** a diretiva `auth_request` chama `auth-service/api/auth/internal/validate/` para validar o JWT **antes** de repassar a requisição, e injeta `X-User-Id` / `X-User-Role`. Rotas públicas (login, callback, `docs/`, `schema/`) ficam fora do `auth_request` para evitar deadlock.
- **Roteamento por namespace:** `/api/auth/`, `/api/track/`, `/api/scholarship/`, `/api/feed/`, `/api/notifications/`, `/api/ai/` → serviço correspondente.
- **Resolução dinâmica de upstream:** o nome do serviço é resolvido em tempo de request (padrão resiliente a recriações de container).
- **Rate limiting:** zonas dedicadas para API e busca.

## Banco de dados

PostgreSQL 16, **banco único `atlas`** com schemas isolados: `auth`, `tracks`, `scholarship`, `notification`, `feed`. Cada serviço acessa apenas o seu schema via `PGOPTIONS=-c search_path=<schema>,public` (definido no compose). Nenhum serviço consulta o schema de outro — dados cruzados passam pela API HTTP interna. Extensões `uuid-ossp` e `pg_stat_statements` habilitadas na inicialização.

## Ecossistema

| Repositório | Responsabilidade |
|---|---|
| atlas-auth-service | Identidade: SUAP OAuth2, JWT, perfis de usuário |
| atlas-track-service | Trilhas, módulos, conteúdos, progresso e submissão de desafios |
| atlas-scholarship-service | Bolsas, candidaturas, banco de talentos e notas |
| atlas-feed-service | Feed institucional: posts, comentários, curtidas e banners |
| atlas-notification-service | Notificações (consumidor central via RabbitMQ) |
| atlas-ai-service | Avaliação de repositórios GitHub por LLM local (Ollama) |
| atlas-frontend | SPA React + TypeScript (aluno e professor) |
| **atlas-infra** | **Docker Compose, Nginx (gateway), Postgres/Redis/RabbitMQ, deploy e backup** |
| atlas-observability | Prometheus + Grafana (métricas dos serviços) |

## Subindo a plataforma

```bash
# Desenvolvimento (infra compartilhada + serviços)
cp .env.example .env
docker compose -f docker-compose.dev.yml up -d

# Produção (no servidor) — atualiza código, rebuilda e recria os containers
bash scripts/deploy.sh
```

## Backup

`scripts/backup.sh` gera um dump comprimido (`atlas_<timestamp>.sql.gz`) do banco completo e remove backups mais antigos que `RETENTION_DAYS`. Agende via cron:

```cron
0 3 * * * /caminho/atlas-infra/scripts/backup.sh >> /var/log/atlas-backup.log 2>&1
```

## Variáveis de ambiente

Baseie seu `.env` no `.env.example`. Inclui credenciais do Postgres, `DJANGO_SECRET_KEY` (compartilhada entre os serviços para assinar/validar o JWT), URLs de Redis/RabbitMQ, credenciais do SUAP e configuração do Ollama.

## Observabilidade

As métricas dos serviços são coletadas pela stack separada **[atlas-observability](https://github.com/Atlas-IFRN/atlas-observability)** (Prometheus + Grafana).

## CI/CD

Workflows de GitHub Actions em `.github/workflows/` para apoio ao deploy.
