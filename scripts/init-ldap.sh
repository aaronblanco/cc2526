#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_ENV="$ROOT_DIR/deploy/compose/.env"

if [ ! -f "$COMPOSE_ENV" ]; then
	echo "[ERROR] Falta deploy/compose/.env. Crea el archivo desde .env.example."
	exit 1
fi

source "$COMPOSE_ENV"

LDAP_PASS="${LDAP_ADMIN_PASSWORD:-admin}"

if [ -z "${LDAP_DOMAIN:-}" ]; then
	echo "[ERROR] LDAP_DOMAIN no definido en .env"
	exit 1
fi

domain_to_base_dn() {
	local domain="$1"
	local old_ifs="$IFS"
	local part
	local dn=""
	IFS='.'
	for part in $domain; do
		if [ -n "$dn" ]; then
			dn+=","
		fi
		dn+="dc=${part,,}"
	done
	IFS="$old_ifs"
	echo "$dn"
}

BASE_DN="$(domain_to_base_dn "$LDAP_DOMAIN")"
ADMIN_DN="cn=admin,${BASE_DN}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

prepare_ldif() {
	local src="$1"
	local dst="$2"
	sed "s/dc=example,dc=org/${BASE_DN}/gI" "$src" > "$dst"
}

prepare_ldif /ldif/01-ou-people.ldif "$TMP_DIR/01-ou-people.ldif"
prepare_ldif /ldif/02-user-ana.ldif "$TMP_DIR/02-user-ana.ldif"
prepare_ldif /ldif/03-user-luis.ldif "$TMP_DIR/03-user-luis.ldif"

# This script is idempotent enough for lab usage: if objects already exist, continue.
podman exec cc-ldap ldapadd -x -D "$ADMIN_DN" -w "$LDAP_PASS" -f "$TMP_DIR/01-ou-people.ldif" || true
podman exec cc-ldap ldapadd -x -D "$ADMIN_DN" -w "$LDAP_PASS" -f "$TMP_DIR/02-user-ana.ldif" || true
podman exec cc-ldap ldapadd -x -D "$ADMIN_DN" -w "$LDAP_PASS" -f "$TMP_DIR/03-user-luis.ldif" || true

echo "[OK] Carga LDAP completada."
podman exec cc-ldap ldapsearch -x -H ldap://localhost:389 -b "ou=People,${BASE_DN}"
