# Practica 1 - Despliegue de servicio OwnCloud

## Datos del alumno

- Nombre y apellidos: Aarón Blanco Álvarez
- Correo UGR: aaronblancoalv@correo.ugr.es
- Grupo de practicas: 1

## Entorno de desarrollo y produccion

### Desarrollo

- Sistema operativo local: Windows 11
- Shell local: PowerShell
- Editor: VS Code

### Produccion / laboratorio

- Acceso: servidor Linux remoto por SSH, sin privilegios de administrador
- Motor de contenedores: Podman
- Orquestacion: podman compose / podman-compose
- Rango de puertos asignado: 20000-20010

### Comandos de evidencia de versiones

```bash
uname -a
cat /etc/os-release
podman --version
podman compose version
podman-compose --version
```

## Resumen ejecutivo

Este repositorio contiene la base de la Practica 1 y la documentacion necesaria para reproducir dos escenarios:

- Escenario 1: OwnCloud con MariaDB, Redis y LDAP.
- Escenario 2: OwnCloud con HAProxy y una replica de ownCloud, ademas de MariaDB, Redis y LDAP.

Archivos principales del repositorio:

- `deploy/compose/docker-compose.yml`: stack del Escenario 1.
- `docker-compose.escenario2.yml`: stack del Escenario 2.
- `deploy/compose/.env`: variables de entorno usadas por el stack base.
- `deploy/ldap/*.ldif`: OU y usuarios LDAP.
- `deploy/haproxy/haproxy.cfg`: configuracion de HAProxy.

## Estructura inicial del proyecto

Estructura minima de trabajo (vista con `tree`) sobre la que se ha construido la practica en la carpeta practica_1:

```text
.
├── deploy
│   ├── compose
│   │   ├── .env
│   │   └── docker-compose.yml
│   ├── haproxy
│   │   └── haproxy.cfg
│   └── ldap
│       ├── 01-ou-people.ldif
│       ├── 02-user-ana.ldif
│       └── 03-user-luis.ldif
├── docker-compose.escenario2.yml
├── README.md
├── VERIFICACION_ESCENARIO1.md
└── VERIFICACION_ESCENARIO2.md
```


## Tarea 1 - Escenario 1

### Requisito del enunciado

Desplegar OwnCloud con, al menos, estos servicios:

- OwnCloud
- MariaDB, MySQL o PostgreSQL
- Redis
- LDAP

### Servicios y puertos

Puertos definidos en `deploy/compose/.env`:

- `20000`: OwnCloud
- `20001`: LDAP
- `20002`: LDAPS
- `20003`: reservado para HAProxy
- `20004`: reservado para estadisticas de HAProxy

### Variables de entorno

Edita directamente `deploy/compose/.env` antes de exponer el servicio en remoto. Valores actuales:

- `OWNCLOUD_PORT=20000`
- `LDAP_PORT=20001`
- `LDAPS_PORT=20002`
- `OWNCLOUD_DOMAIN=localhost:20000`
- `OWNCLOUD_TRUSTED_DOMAINS=localhost,127.0.0.1`
- `OWNCLOUD_ADMIN_USER=admin`
- `OWNCLOUD_ADMIN_PASSWORD=ChangeMeOwncloud123`
- `DB_NAME=owncloud`
- `DB_USER=owncloud`
- `DB_PASSWORD=ChangeMeDb123`
- `DB_ROOT_PASSWORD=ChangeMeRoot123`
- `LDAP_ADMIN_PASSWORD=admin`

Nota: `OWNCLOUD_DOMAIN` debe incluir el puerto de acceso real. `OWNCLOUD_TRUSTED_DOMAINS` solo debe contener hostnames o IPs, sin puerto.

### Arranque del stack

Desde la raiz de este repositorio:

```bash
cd deploy/compose
podman-compose --env-file .env up -d
```

### Verificacion basica

```bash
cd deploy/compose
podman-compose --env-file .env ps
curl -fsS "http://localhost:20000" >/dev/null && echo "[OK] OwnCloud responde"
podman exec cc-ldap ldapsearch -x -H ldap://localhost:389 -b dc=practica1,dc=org >/dev/null && echo "[OK] LDAP responde"
```

Comprobaciones esperadas:

- `cc-ldap` en `Up` y, si aplica, `healthy`.
- `cc-db` en `Up` y, si aplica, `healthy`.
- `cc-redis` en `Up` y, si aplica, `healthy`.
- `cc-owncloud` en `Up`.

### Carga de LDAP

Carga manual de OU y usuarios:

```bash
export LDAP_PASS='admin'
export BASE_DN='dc=practica1,dc=org'
export ADMIN_DN="cn=admin,${BASE_DN}"

podman exec -i cc-ldap ldapadd -x -D "$ADMIN_DN" -w "$LDAP_PASS" < deploy/ldap/01-ou-people.ldif
podman exec -i cc-ldap ldapadd -x -D "$ADMIN_DN" -w "$LDAP_PASS" < deploy/ldap/02-user-ana.ldif
podman exec -i cc-ldap ldapadd -x -D "$ADMIN_DN" -w "$LDAP_PASS" < deploy/ldap/03-user-luis.ldif
```

Verificacion de objetos creados:

```bash
podman exec cc-ldap ldapsearch -x -H ldap://localhost:389 -b "ou=People,${BASE_DN}"
```

Objetos que deben quedar creados:

- `ou=People,dc=practica1,dc=org`
- `uid=ana,ou=People,dc=practica1,dc=org`
- `uid=luis,ou=People,dc=practica1,dc=org`

### Inicio de sesion en OwnCloud

1. Abre OwnCloud en `http://localhost:20000`.
2. Entra con el administrador definido en `.env`.
3. Activa la app de LDAP si no estuviera activa.
4. Configura la conexion LDAP con estos valores:
   - Host: `ldap`
   - Port: `389`
   - Bind DN: `cn=admin,dc=practica1,dc=org`
   - Bind password: `admin`
   - Base DN: `dc=practica1,dc=org`
   - User search attribute: `uid`
   - Display name attribute: `cn`
5. Prueba login con:
   - `ana` / `ana12345`
   - `luis` / `luis12345`

### Persistencia

La persistencia del escenario 1 se apoya en volumenes nombrados de Podman para LDAP, MariaDB y OwnCloud.

Prueba recomendada:

1. Sube un archivo con el usuario LDAP `ana`.
2. Deten el stack:

```bash
cd deploy/compose
podman-compose --env-file .env down
```

3. Levantalo de nuevo:

```bash
cd deploy/compose
podman-compose --env-file .env up -d
```

4. Comprueba que el archivo sigue disponible.


## Tarea 2 - Escenario 2

### Requisito del enunciado

Desplegar OwnCloud con alta disponibilidad e incluir:

- Balanceo de carga con HAProxy o equivalente
- OwnCloud
- SGBD
- Redis
- LDAP
- Replicacion de, al menos, uno de los microservicios

### Ficheros asociados

- `docker-compose.escenario2.yml`
- `deploy/haproxy/haproxy.cfg`

### Puertos del escenario 2

Segun `deploy/compose/.env`:

- `20003`: frontend web por HAProxy
- `20004`: panel de estadisticas de HAProxy

### Arranque


```bash
podman-compose --env-file deploy/compose/.env -f docker-compose.escenario2.yml up -d
```

### Verificacion

```bash
podman ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Elementos esperados:

- `cc-haproxy`
- `cc-owncloud`
- `cc-owncloud2`
- `cc-db`
- `cc-redis`
- `cc-ldap`

Pruebas funcionales:

1. Abre OwnCloud por HAProxy en `http://localhost:20003`.
2. Abre las estadisticas en `http://localhost:20004`.
3. Comprueba que aparecen dos backends en estado UP.
4. Inicia sesion con `ana` o `luis`.
5. Sube un archivo y reinicia el stack.
6. Comprueba que el archivo sigue disponible.

### Persistencia y replica

El escenario 2 reutiliza el volumen compartido de OwnCloud y replica el servicio web en dos instancias. La verificacion detallada esta en `VERIFICACION_ESCENARIO2.md`.

## Tarea 3 - Guia de reproduccion equivalente

El enunciado pide una version equivalente con docker-compose y Kubernetes. En esta copia (`cc-p1`) quedan documentados el escenario base y el escenario con HAProxy en compose. La parte Kubernetes se ejecuta sobre la copia que si incluye los manifiestos (`kubernetes/escenario2`).

### Objetivo de la parte Kubernetes

Reproducir el Escenario 2 con los mismos componentes:

- ownCloud
- MariaDB
- Redis
- LDAP
- HAProxy
- Replica de ownCloud (2 pods)

### Equivalencia compose -> Kubernetes

- Servicio `owncloud` y `owncloud2` en compose -> Deployment `owncloud` con `replicas: 2`.
- `db`, `redis`, `ldap` -> Deployments + Services internos.
- `haproxy` -> Deployment + Service de exposicion externa.
- Volumenes de compose -> PVC para persistencia.
- LDIF y configuracion HAProxy -> ConfigMap + Job de inicializacion LDAP.

### Flujo recomendado en Kubernetes (copia con manifiestos)

1. Arrancar Minikube con rango de NodePort permitido:

```bash
minikube start --driver=podman --container-runtime=containerd \
   --extra-config=apiserver.service-node-port-range=20000-20010
```

2. Aplicar manifiestos:

```bash
minikube kubectl -- apply -f kubernetes/escenario2/00-namespace.yaml
minikube kubectl -- apply -f kubernetes/escenario2/01-secret.yaml
minikube kubectl -- apply -f kubernetes/escenario2/02-configmap.yaml
minikube kubectl -- apply -f kubernetes/escenario2/03-pvc.yaml
minikube kubectl -- apply -f kubernetes/escenario2/04-mariadb.yaml
minikube kubectl -- apply -f kubernetes/escenario2/05-redis.yaml
minikube kubectl -- apply -f kubernetes/escenario2/06-ldap.yaml
minikube kubectl -- apply -f kubernetes/escenario2/07-ldap-seed-job.yaml
minikube kubectl -- apply -f kubernetes/escenario2/08-owncloud.yaml
minikube kubectl -- apply -f kubernetes/escenario2/09-haproxy.yaml
```

3. Verificar estado:

```bash
minikube kubectl -- -n cc-practica1 get pods
minikube kubectl -- -n cc-practica1 get svc
minikube kubectl -- -n cc-practica1 get jobs
minikube kubectl -- -n cc-practica1 get endpoints owncloud
```

4. Validar acceso funcional:

- `http://docker.ugr.es:20003` (ownCloud via HAProxy)
- `http://docker.ugr.es:20004` (stats HAProxy)
- Login LDAP con `ana` y `luis`.

5. Validar persistencia:

```bash
minikube kubectl -- -n cc-practica1 rollout restart deployment owncloud
minikube kubectl -- -n cc-practica1 get pods -l app=owncloud -w
```

Comprobar que los ficheros subidos siguen presentes tras reinicio.

### Comandos utiles en Kubernetes

#### Estado rapido del namespace

```bash
minikube kubectl -- -n cc-practica1 get pods
minikube kubectl -- -n cc-practica1 get svc
minikube kubectl -- -n cc-practica1 get jobs
minikube kubectl -- -n cc-practica1 get endpoints owncloud
```

#### Logs de diagnostico

```bash
minikube kubectl -- -n cc-practica1 logs deploy/owncloud
minikube kubectl -- -n cc-practica1 logs deploy/ldap
minikube kubectl -- -n cc-practica1 logs deploy/mariadb
minikube kubectl -- -n cc-practica1 logs deploy/redis
minikube kubectl -- -n cc-practica1 logs deploy/haproxy
minikube kubectl -- -n cc-practica1 logs job/ldap-seed
```

#### Reinicios y recuperacion

```bash
minikube kubectl -- -n cc-practica1 rollout restart deployment owncloud
minikube kubectl -- -n cc-practica1 rollout restart deployment ldap
minikube kubectl -- -n cc-practica1 rollout restart deployment mariadb
minikube kubectl -- -n cc-practica1 rollout restart deployment redis
minikube kubectl -- -n cc-practica1 rollout restart deployment haproxy
```

Si el job de sembrado LDAP necesita volver a ejecutarse:

```bash
minikube kubectl -- -n cc-practica1 delete job ldap-seed
minikube kubectl -- apply -f kubernetes/escenario2/07-ldap-seed-job.yaml
```

#### Problemas frecuentes en Kubernetes

1. El NodePort no abre en el puerto esperado:

```bash
minikube kubectl -- -n cc-practica1 get svc haproxy -o wide
minikube kubectl -- -n cc-practica1 describe svc haproxy
```

2. Los pods no arrancan o quedan en Pending:

```bash
minikube kubectl -- -n cc-practica1 describe pod <nombre-del-pod>
minikube kubectl -- -n cc-practica1 get events --sort-by=.metadata.creationTimestamp
```

3. LDAP no devuelve usuarios:

```bash
minikube kubectl -- -n cc-practica1 exec deploy/ldap -- ldapsearch -x -H ldap://127.0.0.1:389 -b dc=practica1,dc=org
minikube kubectl -- -n cc-practica1 logs job/ldap-seed
```

4. Quiero limpiar contenedores viejos antes de volver a probar con Podman:

```bash
podman ps -a
podman rm -f cc-ldap cc-db cc-redis cc-owncloud cc-owncloud2 cc-haproxy
```

Esto sirve si arrastras contenedores de pruebas anteriores y quieres dejar el entorno limpio antes de levantar otra vez el escenario con `podman-compose`.


## Comandos utiles (logs y troubleshooting)

### Logs rapidos

```bash
podman logs --tail 120 cc-owncloud
podman logs --tail 120 cc-owncloud2
podman logs --tail 120 cc-db
podman logs --tail 120 cc-ldap
podman logs --tail 120 cc-redis
podman logs --tail 120 cc-haproxy
```

### Estado y puertos

```bash
podman ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
cd deploy/compose
podman-compose --env-file .env ps
```

### Reinicio controlado

Escenario 1:

```bash
cd deploy/compose
podman-compose --env-file .env down
podman-compose --env-file .env up -d
```

Escenario 2:

```bash
podman-compose --env-file deploy/compose/.env -f docker-compose.escenario2.yml down
podman-compose --env-file deploy/compose/.env -f docker-compose.escenario2.yml up -d
```

### Problemas frecuentes y solucion

1. OwnCloud no abre en el navegador:

```bash
curl -v http://localhost:20000
podman logs --tail 120 cc-owncloud
```

2. Error de login LDAP:

```bash
podman exec cc-ldap ldapsearch -x -H ldap://localhost:389 -b dc=practica1,dc=org
podman logs --tail 120 cc-ldap
```

3. HAProxy no reparte o stats vacias:

```bash
podman logs --tail 120 cc-haproxy
curl -v http://localhost:20004
```

4. Reinicio total dejando datos:

```bash
cd deploy/compose
podman-compose --env-file .env down
podman-compose --env-file .env up -d
```

## Conclusiones

La práctica se ha realizado teniendo en cuenta la parte de reutilización. Es decir, he intentado utilizar siempre que podía los mismos archivos de configuración para que sea sencillo pasar de un escenario a otro y además, incluir la parte de Kubernetes. Cabe destacar, que con el entorno más limitado, algunas cosas costaban un poco más de realizar, pero lo más complejo ha sido lidiar con configuraciones antiguas qué provocaban errores ya qué por defecto, no se eliminaban. 

## Referencias

- ENUNCIADO.MD
- OpenLDAP Admin Guide: https://www.openldap.org/doc/admin26/quickstart.html
- osixia/openldap: https://github.com/osixia/docker-openldap
- OwnCloud LDAP: https://doc.owncloud.com/server/next/admin_manual/configuration/user/user_auth_ldap.html
- MariaDB image docs: https://hub.docker.com/_/mariadb
- Redis docs: https://redis.io/docs/
- HAProxy docs: http://docs.haproxy.org/2.6/intro.html
- GitHub Copilot (Revisión de yml + documentación + afinar comandos)