#!/usr/bin/env bash
# Atlas — deploy no servidor
#
# As imagens são buildadas a partir do código-fonte local (sem registry).
# O script atualiza o código (git pull) de cada repositório, rebuilda as
# imagens e recria os containers.
#
# Uso: bash scripts/deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
NGINX_CONF="$PROJECT_DIR/nginx/nginx.conf"

# Hash da config do nginx ANTES dos pulls, para detectar se ela muda neste
# deploy (ver passo 4). Arquivo ausente → string vazia.
nginx_conf_before="$(md5sum "$NGINX_CONF" 2>/dev/null | awk '{print $1}')"

# Org no GitHub (repos públicos, clonados por HTTPS)
GITHUB_ORG="Atlas-IFRN"

# Mapa path->repo dos códigos-fonte que compõem o build (relativos ao
# PROJECT_DIR). O repo vazio (".") é o próprio atlas-infra: só atualiza (pull),
# nunca clona. Os demais são clonados automaticamente se ainda não existirem.
declare -A SOURCES=(
  ["."]=""                                    # atlas-infra (este repo)
  ["frontend"]="atlas-frontend"
  ["services/auth"]="atlas-auth-service"
  ["services/track"]="atlas-track-service"
  ["services/scholarship"]="atlas-scholarship-service"
  ["services/ai"]="atlas-ai-service"
  ["services/notification"]="atlas-notification-service"
  ["services/feed"]="atlas-feed-service"
)

echo "[$(date)] Iniciando deploy do Atlas..."

# 1. Atualiza (ou clona, se ainda não existir) o código-fonte de cada repositório
for dir in "${!SOURCES[@]}"; do
  path="$PROJECT_DIR/$dir"
  repo="${SOURCES[$dir]}"
  if [ -d "$path/.git" ]; then
    echo "[$(date)] git pull em ${dir}..."
    git -C "$path" pull --ff-only || echo "  (aviso: pull falhou em ${dir}, seguindo com o código atual)"
  elif [ -n "$repo" ]; then
    echo "[$(date)] ${dir} ausente — clonando ${repo}..."
    mkdir -p "$(dirname "$path")"
    git clone "https://github.com/${GITHUB_ORG}/${repo}.git" "$path"
  else
    echo "[$(date)] ${dir} não é um repo git — pulando atualização."
  fi
done

# 2. Rebuilda as imagens a partir do código local
echo "[$(date)] Buildando imagens..."
docker compose -f "$COMPOSE_FILE" build

# 3. Recria os containers alterados
echo "[$(date)] Subindo containers..."
docker compose -f "$COMPOSE_FILE" up -d --remove-orphans

# 4. Recria o nginx SOMENTE se a config dele mudou neste deploy.
# Por que não mexer no nginx a cada deploy:
#  - IP novo dos serviços recriados NÃO exige ação: o nginx usa resolução
#    dinâmica (resolver + variável no proxy_pass) e re-resolve os upstreams
#    sozinho em ~10s.
# Por que RECRIAR (e não `nginx -s reload`) quando a config muda:
#  - O compose faz bind-mount do arquivo nginx.conf e o git TROCA O INODE ao
#    atualizá-lo. O container fica preso ao inode antigo, então `reload` recarrega
#    a config VELHA. Só `--force-recreate` re-mapeia o inode e aplica a nova.
nginx_conf_after="$(md5sum "$NGINX_CONF" 2>/dev/null | awk '{print $1}')"
if [ "$nginx_conf_before" != "$nginx_conf_after" ]; then
  echo "[$(date)] nginx.conf mudou — recriando o container nginx para aplicar a nova config..."
  docker compose -f "$COMPOSE_FILE" up -d --force-recreate nginx
else
  echo "[$(date)] nginx.conf inalterado — nginx dispensado (upstreams se re-resolvem sozinhos)."
fi

# 5. Limpa imagens órfãs
docker image prune -f

echo "[$(date)] Deploy concluído."
docker compose -f "$COMPOSE_FILE" ps
