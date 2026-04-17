# Practica 1 - Despliegue de servicio OwnCloud

## Nombre del alumno

- Nombre y apellidos: Aaron Blanco Alvarez
- Correo UGR: aaronblancoalv@correo.ugr.es
- Grupo de practicas: 1

## Entorno de desarrollo y de produccion utilizado

### Entorno de desarrollo

- Sistema operativo local: Windows 11
- Cliente SSH: PuTTY
- Shell local: PowerShell
- Editor: VS Code

### Entorno de produccion

- Acceso: servidor remoto Linux por SSH, sin privilegios de administracion
- Rango de puertos asignado: 20000-20010
- Motor de contenedores: Podman
- Orquestador usado: podman-compose
- Maquinas virtuales adicionales: no utilizadas

### Comandos para registrar versiones (evidencia)

```bash
uname -a
cat /etc/os-release
podman --version
podman-compose --version
```

## Descripcion de la practica y problema a resolver

La practica consiste en desplegar OwnCloud con arquitectura de microservicios en contenedores, incorporando autenticacion LDAP, base de datos y cache.

Problemas que se resuelven:

- Servicio de ficheros multiusuario con OwnCloud.
- Autenticacion centralizada con LDAP.
- Persistencia de datos tras reinicios.
- Despliegue automatizable en entorno restringido (sin sudo).

Arquitectura implementada (Escenario 1):

- OwnCloud (frontend web)
- MariaDB (SGBD)
- Redis (cache)
- OpenLDAP (autenticacion)

## Servicios desplegados y su configuracion

### Estructura relevante del proyecto

- ENUNCIADO.MD: enunciado original.
- deploy/compose/docker-compose.yml: despliegue principal.
- deploy/compose/.env.example: plantilla de variables.
- deploy/ldap/01-ou-people.ldif: OU People.
- deploy/ldap/02-user-ana.ldif: usuario ana.
- deploy/ldap/03-user-luis.ldif: usuario luis.

### Configuracion de puertos

Asignacion utilizada dentro del rango 20000-20010:

- 20000: OwnCloud
- 20001: LDAP
- 20002: LDAPS
- 20003: reservado para HAProxy (Escenario 2)
- 20004: reservado para stats de HAProxy (Escenario 2)

### Variables de entorno

Crear archivo de trabajo:

```bash
cp deploy/compose/.env.example deploy/compose/.env
```

Valores minimos a revisar en deploy/compose/.env:

- OWNCLOUD_PORT
- LDAP_PORT
- LDAPS_PORT
- OWNCLOUD_DOMAIN
- OWNCLOUD_TRUSTED_DOMAINS
- OWNCLOUD_ADMIN_USER
- OWNCLOUD_ADMIN_PASSWORD
- DB_NAME
- DB_USER
- DB_PASSWORD
- DB_ROOT_PASSWORD
- LDAP_ADMIN_PASSWORD

### Provision manual de servicios (sin scripts)

1. Levantar stack:

```bash
podman-compose up -d
```

2. Ver estado:

```bash
podman ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

3. Verificar salud LDAP y MariaDB:

```bash
podman inspect cc-ldap --format "{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}"
podman inspect cc-db --format "{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}"
```

4. Revisar logs si hay incidencia:

```bash
podman logs --tail 120 cc-ldap
podman logs --tail 120 cc-db
podman logs --tail 120 cc-owncloud
```

### Carga manual de LDAP desde archivos LDIF (flujo usado)

Definir variables de trabajo LDAP. El `BASE_DN` debe coincidir con el dominio LDAP configurado en `deploy/compose/.env`:

```bash
export LDAP_PASS='admin'
export BASE_DN='dc=TU_DOMINIO,dc=org'
export ADMIN_DN="cn=admin,${BASE_DN}"
```

Opcional (para no escribir la clave manualmente):

```bash
source .env
export LDAP_PASS="$LDAP_ADMIN_PASSWORD"
```

Comprobar autenticacion de admin LDAP:

```bash
podman exec cc-ldap ldapwhoami -x -D "$ADMIN_DN" -w "$LDAP_PASS"
```

Resultado esperado de exito:

```text
dn:cn=admin,dc=practica1,dc=org
```

Si devuelve `Invalid credentials (49)`, revisar `LDAP_PASS` o reinicializar volumenes LDAP.

Importar OU People desde el archivo LDIF local:

```bash
podman exec -i cc-ldap ldapadd -x -D "$ADMIN_DN" -w "$LDAP_PASS" < ldif/01-ou-people.ldif
```

Importar usuario ana desde el archivo LDIF local:

```bash
podman exec -i cc-ldap ldapadd -x -D "$ADMIN_DN" -w "$LDAP_PASS" < ldif/02-user-ana.ldif
```

Importar usuario luis desde el archivo LDIF local:

```bash
podman exec -i cc-ldap ldapadd -x -D "$ADMIN_DN" -w "$LDAP_PASS" < ldif/03-user-luis.ldif
```

Verificar OU y usuarios:

```bash
podman exec cc-ldap ldapsearch -x -H ldap://localhost:389 -b "ou=People,${BASE_DN}"
```

Nota 1: este flujo usa los ficheros `ldif/01-ou-people.ldif`, `ldif/02-user-ana.ldif` y `ldif/03-user-luis.ldif` que estan en el directorio de trabajo local.

Nota 2: si aparece `Already exists`, el objeto ya estaba creado en una ejecucion previa.

Nota 3: si necesitas borrar y recrear los usuarios, elimina primero las entradas con `ldapdelete` y vuelve a importar los LDIF.

### Arranque y reinicio de contenedores

- Para arrancar o recrear lo necesario segun el compose:

```bash
podman-compose up -d
```

- Si los contenedores ya existen y estan parados, tambien puedes usar:

```bash
podman-compose start
```

- Si quieres reinicio completo del stack:

```bash
podman-compose down
podman-compose up -d
```

Para volver a iniciar despues de una parada simple, tambien vale:

```bash
podman-compose start
```

### Integracion LDAP en OwnCloud

Abrir OwnCloud en:

- http://<host-servidor>:20000

Configurar LDAP en panel de administracion de OwnCloud:

- Activar app "LDAP / Active Directory Integration"
- Host LDAP: ldap
- Puerto LDAP: 389
- Bind DN: cn=admin,dc=practica1,dc=org
- Bind password: valor de LDAP_ADMIN_PASSWORD
- Base DN: dc=practica1,dc=org
- Atributo de login: uid

Probar inicio de sesion con:

- ana / ana12345
- luis / luis12345

### Persistencia de datos

La persistencia se implementa con volumenes nombrados de Podman:

- ldap_database
- ldap_config
- mariadb_data
- owncloud_data

Comprobar volumenes:

```bash
podman volume ls
```

Prueba de persistencia:

1. Subir un archivo desde usuario LDAP en OwnCloud.
2. Reiniciar stack:

```bash
podman-compose down
podman-compose up -d
```

3. Comprobar que el archivo sigue disponible tras reinicio.

### Checklist de verificacion final (Escenario 1)

- [ ] cc-ldap en estado Up (healthy)
- [ ] cc-db en estado Up (healthy)
- [ ] cc-redis en estado Up (healthy)
- [ ] cc-owncloud en estado Up
- [ ] OU People creada
- [ ] Usuarios ana y luis creados en LDAP
- [ ] Login LDAP en OwnCloud operativo
- [ ] Persistencia verificada tras reinicio

## Conclusiones

Se ha desplegado correctamente la arquitectura base del Escenario 1 con Podman y podman-compose en un entorno sin privilegios de administrador. El uso de volumenes nombrados evita problemas de permisos en host y mantiene persistencia en LDAP, MariaDB y OwnCloud. La autenticacion LDAP queda integrada y validada con usuarios reales del directorio, cumpliendo los criterios funcionales del enunciado.

## Referencias bibliograficas y recursos utilizados

- Enunciado oficial de la practica (ENUNCIADO.MD)
- OpenLDAP Admin Guide: https://www.openldap.org/doc/admin26/quickstart.html
- osixia/openldap: https://github.com/osixia/docker-openldap
- OwnCloud LDAP: https://doc.owncloud.com/server/next/admin_manual/configuration/user/user_auth_ldap.html
- Nextcloud LDAP (referencia conceptual): https://docs.nextcloud.com/server/22/admin_manual/configuration_user/user_auth_ldap.html
- MariaDB image docs: https://hub.docker.com/_/mariadb
- Redis docs: https://redis.io/docs/
- HAProxy docs: http://docs.haproxy.org/2.6/intro.html
