#!/usr/bin/env bash
set -euo pipefail

missing=0
for cmd in podman bash curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERROR] Falta comando: $cmd"
    missing=1
  else
    echo "[OK] $cmd disponible: $(command -v "$cmd")"
  fi
done

if podman compose version >/dev/null 2>&1; then
  echo "[OK] podman compose disponible"
elif command -v podman-compose >/dev/null 2>&1; then
  echo "[OK] podman-compose disponible"
  echo "[WARN] Ajusta scripts para usar podman-compose si podman compose no funciona"
else
  echo "[ERROR] No se detecta podman compose ni podman-compose"
  missing=1
fi

echo "[INFO] Version podman:"
podman --version || true

if [ "$missing" -ne 0 ]; then
  echo "[FAIL] Preflight incompleto"
  exit 1
fi

echo "[OK] Preflight superado"
