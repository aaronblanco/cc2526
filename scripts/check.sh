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
	echo "[ERROR] Falta deploy/compose/.env. Crea el archivo desde .env.example."
	exit 1
fi

run_compose ps

echo ""
echo "[INFO] Probe HTTP OwnCloud"
source .env
curl -fsS "http://localhost:${OWNCLOUD_PORT}" >/dev/null && echo "[OK] OwnCloud responde en puerto ${OWNCLOUD_PORT}" || echo "[WARN] OwnCloud no responde aun"

echo ""
echo "[INFO] Probe LDAP interno"
podman exec cc-ldap ldapsearch -x -H ldap://localhost:389 -b dc=example,dc=org >/dev/null && echo "[OK] LDAP responde" || echo "[WARN] LDAP no responde aun"
