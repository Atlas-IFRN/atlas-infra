#!/usr/bin/env bash
# Atlas — backup automático do PostgreSQL via pg_dump
# Agendar via cron: 0 3 * * * /home/ubuntu/atlas/scripts/backup.sh

set -euo pipefail

BACKUP_DIR="/backups/atlas"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
CONTAINER="atlas-postgres"
RETENTION_DAYS=7

source "$(dirname "$0")/../.env"

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Iniciando backup..."

docker exec "$CONTAINER" pg_dump \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  --no-password \
  | gzip > "$BACKUP_DIR/atlas_${TIMESTAMP}.sql.gz"

echo "[$(date)] Backup salvo em: $BACKUP_DIR/atlas_${TIMESTAMP}.sql.gz"

# Remove backups mais antigos que RETENTION_DAYS
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
echo "[$(date)] Backups antigos removidos (retenção: ${RETENTION_DAYS} dias)"

