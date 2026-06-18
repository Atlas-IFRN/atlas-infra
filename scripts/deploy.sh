#!/usr/bin/env bash
# Atlas — deploy no VPS
# Faz pull das imagens mais recentes e recria os containers

set -euo pipefail

COMPOSE_FILE="$(dirname "$0")/../docker-compose.yml"

echo "[$(date)] Iniciando deploy do Atlas..."

# Pull das imagens mais recentes
docker compose -f "$COMPOSE_FILE" pull

# Recria containers alterados (zero downtime para stateless)
docker compose -f "$COMPOSE_FILE" up -d --remove-orphans

# Remove imagens antigas
docker image prune -f

echo "[$(date)] Deploy concluído."
docker compose -f "$COMPOSE_FILE" ps

