#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_DIR="$ROOT_DIR/deploy/compose"

run_compose() {
  if podman compose version >/dev/null 2>&1; then
    podman compose --env-file .env "$@"
  elif command -v podman-compose >/dev/null 2>&1; then
    podman-compose --env-file .env "$@"
  else
    echo "[ERROR] No se detecta podman compose ni podman-compose"
    exit 1
  fi
}

cd "$COMPOSE_DIR"

if [ ! -f .env ]; then
  cp .env.example .env
  echo "[INFO] Se ha creado .env desde .env.example. Editalo antes de exponer servicios en remoto."
fi

mkdir -p "$ROOT_DIR/data/slapd/config" "$ROOT_DIR/data/slapd/database" "$ROOT_DIR/data/mariadb" "$ROOT_DIR/data/owncloud"

run_compose up -d

echo "[OK] Servicios levantados."
