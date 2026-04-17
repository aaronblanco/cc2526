# Guía de Verificación Escenario 1

Esta guía te permite verificar que el despliegue cumple todos los requisitos evaluables de la práctica.

## 1. Verificación técnica de servicios

### Estado de contenedores

```bash
podman ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

**Esperado**: Todos los contenedores en Up con estados (healthy) si aplica.

```
cc-ldap        Up X minutes (healthy)    0.0.0.0:20001->389/tcp
cc-db          Up X minutes (healthy)    3306/tcp
cc-redis       Up X minutes (healthy)    6379/tcp
cc-owncloud    Up X minutes             0.0.0.0:20000->8080/tcp
```

### Verificación de conectividad interna

```bash
podman exec cc-ldap ldapsearch -x -H ldap://localhost:389 -s base -b "" namingContexts
```

**Esperado**: Devuelve información del servidor LDAP sin errores.

```bash
podman exec cc-db mariadb-admin ping -hdb -u${DB_USER} -p${DB_PASSWORD}
```

**Esperado**: pong

```bash
podman exec cc-redis redis-cli ping
```

**Esperado**: PONG

## 2. Carga de OU y usuarios LDAP (requisito obligatorio)

Ejecuta el script de inicialización LDAP:

```bash
bash scripts/init-ldap.sh
```

Comprueba que la OU y usuarios se cargaron:

```bash
podman exec cc-ldap ldapsearch -x -H ldap://localhost:389 -b ou=People,dc=example,dc=org -D "cn=admin,dc=example,dc=org" -w admin
```

**Esperado**: Devuelve ou=People y dos usuarios: uid=ana y uid=luis.

Ejemplo de salida:

```
dn: ou=People,dc=example,dc=org
ou: People
...

dn: uid=ana,ou=People,dc=example,dc=org
uid: ana
cn: Ana Garcia
...

dn: uid=luis,ou=People,dc=example,dc=org
uid: luis
cn: Luis Romero
...
```

## 3. Acceso a OwnCloud

### Acceso inicial

1. Abre navegador web: http://<tu-servidor>:20000
2. Deberías ver asistente de bienvenida de OwnCloud
3. Si es la primera ejecución, inicia sesión con usuario de administrador:
   - Usuario: admin (del .env: OWNCLOUD_ADMIN_USER)
   - Contraseña: (del .env: OWNCLOUD_ADMIN_PASSWORD)

### Integración LDAP en OwnCloud

Una vez dentro de OwnCloud (como admin):

1. Accede a Apps (esquina superior derecha).
2. Busca y activa "LDAP / Active Directory Integration".
3. Ve a Administración > Configuración > Autenticación.
4. Configura la conexión LDAP:

   - **Host**: ldap (nombre del servicio en red interna) o 172.17.0.1:20001 (desde fuera del contenedor)
   - **Port**: 389
   - **Bind DN**: cn=admin,dc=example,dc=org
   - **Bind Password**: (tu LDAP_ADMIN_PASSWORD de .env)
   - **Base DN**: dc=example,dc=org
   - **User Search Attributes**: uid
   - **Display Name Attribute**: cn
   - **Group Search Attributes**: cn

5. Haz clic en Test Configuration y verifica que detecta usuarios.

### Prueba de login LDAP

1. Cierra sesión de admin.
2. Inicia sesión con usuario LDAP:
   - Usuario: ana
   - Contraseña: ana12345
3. Verifica que accedes correctamente.
4. Repite con usuario luis (password: luis12345).

## 4. Prueba de persistencia (crítico para evaluación)

La persistencia es un requisito explícito evaluable. Prueba lo siguiente:

### 4.1. Persistencia de LDAP

1. Verifica usuario actual en LDAP:
```bash
podman exec cc-ldap ldapsearch -x -H ldap://localhost:389 -b uid=ana,ou=People,dc=example,dc=org -w ana -D "uid=ana,ou=People,dc=example,dc=org"
```

2. Detén contenedor LDAP:
```bash
podman stop cc-ldap
```

3. Espera 10 segundos y vuelve a levantar:
```bash
podman start cc-ldap
```

4. Vuelve a verificar usuario (debería seguir existiendo):
```bash
podman exec cc-ldap ldapsearch -x -H ldap://localhost:389 -b uid=ana,ou=People,dc=example,dc=org -w ana -D "uid=ana,ou=People,dc=example,dc=org"
```

**Esperado**: El usuario sigue disponible tras reinicio.

### 4.2. Persistencia de datos OwnCloud

1. Inicia sesión en OwnCloud con usuario LDAP (ana).
2. Sube un archivo (cualquier fichero pequeño, por ejemplo un .txt).
3. Detén todos los contenedores:
```bash
podman-compose stop
```

4. Espera 10 segundos y levanta el stack de nuevo:
```bash
podman-compose up -d
```

5. Vuelve a acceder a OwnCloud:
   - http://<tu-servidor>:20000
   - Inicia sesión con ana/ana12345
   - Verifica que el archivo que subiste sigue allí.

**Esperado**: El archivo persiste tras reinicio de stack.

## 5. Verificación de logs para troubleshooting

Si algo no funciona, revisa logs:

```bash
podman logs --tail 150 cc-owncloud
podman logs --tail 150 cc-ldap
podman logs --tail 150 cc-db
```

Busca errores clave como:
- Permission denied → problema de volúmenes/permisos
- Connection refused → servicio dependiente no está listo
- Authentication failed → credenciales incorrectas en .env

## 6. Checklist de conformidad con requisitos

Marca los items conforme los verifiques:

- [ ] Contenedores cc-ldap, cc-db, cc-redis, cc-owncloud levantados y healthy
- [ ] OU "People" creada en LDAP
- [ ] Usuario LDAP "ana" con contraseña funcional existe
- [ ] Usuario LDAP "luis" con contraseña funcional existe
- [ ] OwnCloud accesible en puerto 20000
- [ ] Integración LDAP en OwnCloud completada
- [ ] Login de usuario LDAP (ana) funciona en OwnCloud
- [ ] Login de usuario LDAP (luis) funciona en OwnCloud
- [ ] Persistencia LDAP: usuarios existen tras reinicio de cc-ldap
- [ ] Persistencia OwnCloud: archivos subidos existen tras reinicio del stack

**Si todos los items están marcados ✓, tienes el Escenario 1 completo y evaluable.**

## 7. Grabación de evidencias para defensa

Se recomienda capturar/guardar para la defensa:

- Salida de `podman ps -a` mostrando todos los contenedores Up
- Salida de `podman exec cc-ldap ldapsearch ...` mostrando usuarios
- Captura pantalla de OwnCloud con usuario LDAP conectado
- Captura pantalla de un archivo subido en OwnCloud
- Salida de logs sin errores críticos

## Próximos pasos

Una vez que todo el Escenario 1 pase esta verificación:

1. **Escenario 2 (máxima nota)**:
   - Añadir HAProxy para balanceo
   - Replicar un servicio (recomendado: owncloud)
   - Documentar nueva arquitectura

2. **Equivalente en Docker/Compose y Kubernetes**:
   - Preparar mismo stack en Docker (si disponible)
   - Preparar manifiestos Kubernetes

3. **Documentación final**:
   - Completar README.md con evidencias
   - Preparar guion de defensa
