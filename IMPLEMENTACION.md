# Implementacion inicial - Practica 1

Este repositorio incluye una base para arrancar el Escenario 1 con Podman Compose en un servidor Linux sin permisos de administrador.

## Estructura

- deploy/compose/docker-compose.yml: stack base (OwnCloud, MariaDB, Redis, LDAP).
- deploy/compose/.env.example: plantilla de puertos y credenciales.
- deploy/ldap/*.ldif: OU y usuarios de ejemplo.
- deploy/haproxy/haproxy.cfg: base para Escenario 2 (balanceo).
- scripts/up.sh, down.sh, check.sh, init-ldap.sh: operacion del stack.

## Primer arranque

1. Copia .env.example a .env y adapta puertos asignados.
2. Lanza `bash scripts/up.sh`.
3. Inicializa LDAP: `bash scripts/init-ldap.sh`.
4. Comprueba estado: `bash scripts/check.sh`.

## Notas importantes

- No se usa sudo: todo persiste en `data/` dentro del repo.
- Cambia credenciales por defecto antes de exponer servicios.
- Para maxima nota, esta base se ampliara con replicas + HAProxy + Kubernetes.
