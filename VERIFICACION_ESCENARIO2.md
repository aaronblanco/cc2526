# Guía de Verificación Escenario 2

Esta guía valida el despliegue con HAProxy y replicación de ownCloud.

## 1. Arranque

```bash
cd deploy/compose
podman-compose -f docker-compose.scenario2.yml up -d
```

## 2. Estado de contenedores

```bash
podman ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Esperado:
- cc-owncloud en Up
- cc-owncloud2 en Up
- cc-haproxy en Up
- cc-db, cc-redis, cc-ldap en Up (healthy cuando aplique)

## 3. Verificación de HAProxy

Abrir en navegador:
- `http://<host>:<HAPROXY_PORT>`
- `http://<host>:<HAPROXY_STATS_PORT>`

En la vista de stats deben aparecer dos backends en estado UP:
- oc1 (owncloud:8080)
- oc2 (owncloud2:8080)

## 4. Verificación funcional

1. Inicia sesión en ownCloud por HAProxy (`<HAPROXY_PORT>`).
2. Comprueba que LDAP sigue permitiendo login (por ejemplo `ana` / `ana12345`).
3. Sube un fichero de prueba.

## 5. Persistencia

```bash
podman-compose -f docker-compose.scenario2.yml down
podman-compose -f docker-compose.scenario2.yml up -d
```

Comprobar:
- Login LDAP operativo.
- Fichero de prueba sigue presente.

## 6. Evidencias recomendadas

- Salida de `podman ps -a`.
- Captura de stats de HAProxy con oc1/oc2 en UP.
- Captura de login LDAP en ownCloud vía HAProxy.
- Captura del fichero persistido tras reinicio.
