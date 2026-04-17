# Runbook rapido en servidor (SSH/Putty)

## 1) Subir codigo

- Sube esta carpeta al servidor (scp/sftp).
- Entra por SSH y ve al directorio del proyecto.

## 2) Preflight

Ejecuta:

```bash
bash scripts/preflight.sh
```

Si falla compose, prueba manualmente:

```bash
podman compose version
podman-compose --version
```

Da permisos de ejecucion a los scripts (si hace falta):

```bash
chmod +x scripts/*.sh
```

## 3) Configuracion de puertos y credenciales

```bash
cp deploy/compose/.env.example deploy/compose/.env
nano deploy/compose/.env
```

Debes cambiar:
- OWNCLOUD_PORT, LDAP_PORT, LDAPS_PORT por puertos asignados.
- Contraseñas por valores propios.
- OWNCLOUD_DOMAIN segun host/puerto reales.

## 4) Arranque

```bash
bash scripts/up.sh
bash scripts/init-ldap.sh
bash scripts/check.sh
```

## 5) Verificacion funcional minima

- Abre `http://<host>:<OWNCLOUD_PORT>`.
- Finaliza asistente de ownCloud.
- En ownCloud, configura LDAP (app LDAP).
- Prueba login de usuario LDAP (`ana` o `luis`).
- Sube un archivo para validar funcionamiento.

## 6) Persistencia

Comprueba persistencia:

```bash
bash scripts/down.sh
bash scripts/up.sh
bash scripts/check.sh
```

Verifica que los usuarios LDAP y datos de ownCloud siguen presentes.
