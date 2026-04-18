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

Arquitectura implementada hasta este punto (Escenario 1):

- OwnCloud (frontend web)
- MariaDB (SGBD)
- Redis (cache)
- OpenLDAP (autenticacion)

## Estructura del documento por tareas evaluables

Este documento se organiza siguiendo las tareas del enunciado oficial de la Practica 1:

- Tarea 1: completada y verificada (Escenario 1).
- Tarea 2: en preparacion y despliegue (Escenario 2 con HAProxy y replica).
- Tarea 3: planificada (docker-compose y Kubernetes sobre tarea 1 o 2).

## Tarea 1 - Enunciado y trabajo realizado

**Enunciado oficial (tarea minima obligatoria):**

**1.- Diseno y despliegue de un servicio OwnCloud basado en contenedores segun la arquitectura descrita en el Escenario 1 (Ver seccion Tipos de arquitecturas de cloud propuestas). En particular, se requiere que este servicio incluya, al menos, 4 subservicios:**

- Servicio de alojamiento y gestion de archivos (ownCloud)
- Sistema gestor de base de datos (SGBD): MariaDB, MySQL o PostgreSQL
- Redis
- LDAP (autenticacion de usuarios)

## Tarea 1 - Servicios desplegados y configuracion

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

Nota: `OWNCLOUD_DOMAIN` debe incluir el puerto de acceso real, mientras que `OWNCLOUD_TRUSTED_DOMAINS` solo admite hostnames o IPs, sin puerto. Si accedes mediante túnel SSH, puedes dejar `localhost`; si accedes directamente al servidor, usa su IP o nombre real.

### Provision manual de servicios (sin scripts)

1. Levantar stack:

```bash
podman-compose -p cc-s1 -f deploy/compose/docker-compose.yml up -d
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
podman exec -i cc-ldap ldapadd -x -D "$ADMIN_DN" -w "$LDAP_PASS" < deploy/ldap/01-ou-people.ldif
```

Importar usuario ana desde el archivo LDIF local:

```bash
podman exec -i cc-ldap ldapadd -x -D "$ADMIN_DN" -w "$LDAP_PASS" < deploy/ldap/02-user-ana.ldif
```

Importar usuario luis desde el archivo LDIF local:

```bash
podman exec -i cc-ldap ldapadd -x -D "$ADMIN_DN" -w "$LDAP_PASS" < deploy/ldap/03-user-luis.ldif
```

Verificar OU y usuarios:

```bash
podman exec cc-ldap ldapsearch -x -H ldap://localhost:389 -b "ou=People,${BASE_DN}"
```

Nota 1: este flujo usa los ficheros `deploy/ldap/01-ou-people.ldif`, `deploy/ldap/02-user-ana.ldif` y `deploy/ldap/03-user-luis.ldif` desde la raiz del proyecto.

Nota 2: si aparece `Already exists`, el objeto ya estaba creado en una ejecucion previa.

Nota 3: si necesitas borrar y recrear los usuarios, elimina primero las entradas con `ldapdelete` y vuelve a importar los LDIF.

### Arranque y reinicio de contenedores

- Para arrancar o recrear lo necesario segun el compose:

```bash
podman-compose -p cc-s1 -f deploy/compose/docker-compose.yml up -d
```

- Si los contenedores ya existen y estan parados, tambien puedes usar:

```bash
podman-compose -p cc-s1 -f deploy/compose/docker-compose.yml start
```

- Si quieres reinicio completo del stack:

```bash
podman-compose -p cc-s1 -f deploy/compose/docker-compose.yml down
podman-compose -p cc-s1 -f deploy/compose/docker-compose.yml up -d
```

Para volver a iniciar despues de una parada simple, tambien vale:

```bash
podman-compose -p cc-s1 -f deploy/compose/docker-compose.yml start
```

### Cambio entre Escenario 1 y Escenario 2

Para evitar mezclar volumenes y redes entre escenarios, usar distinto nombre de proyecto (`-p`) y su compose correspondiente.

Escenario 1:

```bash
podman-compose -p cc-s1 -f deploy/compose/docker-compose.yml up -d
podman-compose -p cc-s1 -f deploy/compose/docker-compose.yml stop
podman-compose -p cc-s1 -f deploy/compose/docker-compose.yml start
podman-compose -p cc-s1 -f deploy/compose/docker-compose.yml down
```

Escenario 2:

```bash
podman-compose -p cc-s2 -f docker-compose.escenario2.yml up -d
podman-compose -p cc-s2 -f docker-compose.escenario2.yml stop
podman-compose -p cc-s2 -f docker-compose.escenario2.yml start
podman-compose -p cc-s2 -f docker-compose.escenario2.yml down
```

Nota: solo usar `down -v` cuando quieras borrar datos y reinicializar por completo el escenario.

### Integracion LDAP en OwnCloud

Abrir OwnCloud en:

- http://<host-servidor>:20000

Configuracion LDAP validada (paso a paso):

1. Iniciar sesion en OwnCloud con el admin local (`OWNCLOUD_ADMIN_USER` / `OWNCLOUD_ADMIN_PASSWORD`).

2. Ir a Apps y activar **LDAP Integration**.
	- Si no aparece en menu, abrir directamente `http://<host-servidor>:20000/index.php/settings/apps`.

3. Ir a Settings > Admin > LDAP/AD Integration.

4. En la pestaña **Server**, rellenar:
	- Host: `ldap`
	- Port: `389`
	- Use StartTLS support: desactivado
	- User DN: `cn=admin,dc=practica1,dc=org`
	- Password: valor de `LDAP_ADMIN_PASSWORD`
	- One Base DN per line: `dc=practica1,dc=org`
	- Manually enter LDAP filters: desactivado

5. Pulsar **Continue**.

6. En **Login Attributes**, usar `uid` como atributo de login (LDAP/AD Username).

7. Guardar configuracion y validar conectividad desde la propia pantalla LDAP (estado sin errores).

8. Cerrar sesion de admin y probar inicio con usuarios LDAP:
	- `ana` / `ana12345`
	- `luis` / `luis12345`

Notas de verificacion:

- Si en Users solo aparece `admin`, es normal antes de activar/configurar LDAP o antes del primer login de usuarios LDAP.
- Si no aparece la seccion LDAP en la web, se puede habilitar por CLI:

```bash
podman exec -u www-data cc-owncloud occ app:enable user_ldap
podman exec -u www-data cc-owncloud occ app:list | grep user_ldap
```

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

### Checklist de verificacion final de la Tarea 1 (Escenario 1)

- [ ] cc-ldap en estado Up (healthy)
- [ ] cc-db en estado Up (healthy)
- [ ] cc-redis en estado Up (healthy)
- [ ] cc-owncloud en estado Up
- [ ] OU People creada
- [ ] Usuarios ana y luis creados en LDAP
- [ ] Login LDAP en OwnCloud operativo
- [ ] Persistencia verificada tras reinicio

## Tarea 2 - Enunciado y plan de ejecucion

**Enunciado oficial (tarea para maxima puntuacion):**

**2.- Diseno y despliegue de un servicio OwnCloud basado en contenedores, con alta disponibilidad e inspirado en la arquitectura descrita en el Escenario 2. En particular, se requiere que este servicio incluya:**

- Balanceo de carga con HAProxy (u otra herramienta)
- Servicio web ownCloud
- SGBD
- Redis
- LDAP
- Replicacion de, al menos, uno de los microservicios anteriores

Estado actual de la Tarea 2 en este repositorio:

- Compose dedicado creado: `docker-compose.escenario2.yml`
- Configuracion de HAProxy lista para balanceo: `deploy/haproxy/haproxy.cfg`
- Guia de verificacion creada: `VERIFICACION_ESCENARIO2.md`

Siguiente paso operativo para Tarea 2:

1. Levantar escenario 2 con `podman-compose -p cc-s2 -f docker-compose.escenario2.yml up -d`.
2. Verificar backends `oc1` y `oc2` en stats de HAProxy.
3. Validar login LDAP y persistencia tambien a traves del frontend de HAProxy.

## Tarea 3 - Enunciado y plan de trabajo

**Enunciado oficial:**

**3.- Diseno y despliegue de la tarea 1 o 2 utilizando docker (docker-compose) y kubernetes.**

Objetivo previsto para esta entrega:

- Partir de la arquitectura ya validada.
- Preparar version equivalente para docker-compose.
- Adaptar despliegue a Kubernetes y documentar ejecucion.

Plan inicial para la Tarea 3:

1. Seleccionar base (Tarea 1 o Tarea 2) para migracion.
2. Generar manifiestos Kubernetes (Deployments, Services, ConfigMaps y volumenes).
3. Validar acceso a ownCloud, login LDAP y persistencia en Kubernetes.
4. Incluir en la documentacion comandos de despliegue, pruebas y evidencias.

## Conclusiones

Se ha completado y validado la Tarea 1 (Escenario 1) con Podman y podman-compose en un entorno sin privilegios de administrador. El uso de volumenes nombrados evita problemas de permisos en host y mantiene persistencia en LDAP, MariaDB y ownCloud. La autenticacion LDAP queda integrada y validada con usuarios reales del directorio.

Ademas, el repositorio ya incluye la base tecnica para continuar con la Tarea 2 (escenario de alta disponibilidad con HAProxy y replica) y un plan de trabajo para abordar la Tarea 3 en docker-compose y Kubernetes.

## Referencias bibliograficas y recursos utilizados

- Enunciado oficial de la practica (ENUNCIADO.MD)
- OpenLDAP Admin Guide: https://www.openldap.org/doc/admin26/quickstart.html
- osixia/openldap: https://github.com/osixia/docker-openldap
- OwnCloud LDAP: https://doc.owncloud.com/server/next/admin_manual/configuration/user/user_auth_ldap.html
- Nextcloud LDAP (referencia conceptual): https://docs.nextcloud.com/server/22/admin_manual/configuration_user/user_auth_ldap.html
- MariaDB image docs: https://hub.docker.com/_/mariadb
- Redis docs: https://redis.io/docs/
- HAProxy docs: http://docs.haproxy.org/2.6/intro.html
