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
run_compose down

echo "[OK] Servicios detenidos."
