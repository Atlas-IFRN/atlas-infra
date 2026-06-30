#!/usr/bin/env bash
# Atlas — backup automático do PostgreSQL via pg_dump
#
# Faz dump do banco único `atlas` (inclui os schemas auth, tracks e
# scholarship) em arquivo comprimido com timestamp, e remove backups
# mais antigos que RETENTION_DAYS.
#
# Agendar via cron (ajuste o caminho para o seu servidor):
#   0 3 * * * /home/production/scripts/backup.sh >> /var/log/atlas-backup.log 2>&1

set -euo pipefail

# Diretório raiz do projeto (pasta acima de scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

BACKUP_DIR="${BACKUP_DIR:-/backups/atlas}"
TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
CONTAINER="atlas-postgres"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

# Carrega POSTGRES_USER / POSTGRES_PASSWORD / POSTGRES_DB do .env
if [ -f "$PROJECT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$PROJECT_DIR/.env"
  set +a
else
  echo "[$(date)] ERRO: .env não encontrado em $PROJECT_DIR" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"
OUTFILE="$BACKUP_DIR/atlas_${TIMESTAMP}.sql.gz"

echo "[$(date)] Iniciando backup do banco '${POSTGRES_DB}'..."

# Verifica se o container está rodando
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "[$(date)] ERRO: container ${CONTAINER} não está em execução." >&2
  exit 1
fi

# PGPASSWORD é passado ao processo dentro do container para autenticar o pg_dump
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$CONTAINER" \
  pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  | gzip > "$OUTFILE"

# Valida que o arquivo não saiu vazio
if [ ! -s "$OUTFILE" ]; then
  echo "[$(date)] ERRO: backup vazio, removendo ${OUTFILE}." >&2
  rm -f "$OUTFILE"
  exit 1
fi

echo "[$(date)] Backup salvo: ${OUTFILE} ($(du -h "$OUTFILE" | cut -f1))"

# Remove backups mais antigos que RETENTION_DAYS
find "$BACKUP_DIR" -name "atlas_*.sql.gz" -mtime +"$RETENTION_DAYS" -delete
echo "[$(date)] Backups com mais de ${RETENTION_DAYS} dias removidos."
