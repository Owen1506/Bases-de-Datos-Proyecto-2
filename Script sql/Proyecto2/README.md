# Proyecto 2: configuración de los nodos SQL Server

El sistema distribuido utiliza tres contenedores independientes de SQL Server 2022 Developer. Todos se comunican mediante la red Docker `wwi_red` y cada uno conserva sus datos en un volumen propio.

| Nodo | Contenedor | Conexión desde SSMS | Base de datos | Volumen |
|---|---|---|---|---|
| San José | `wwi_sanjose` | `localhost,1434` | `WideWorldImporters_SanJose` | `wwi_sanjose_data` |
| Limón | `wwi_limon` | `localhost,1435` | `WideWorldImporters_Limon` | `wwi_limon_data` |
| Corporativo | `wwi_corporativo` | `localhost,1436` | `WideWorldImporters_Corporativo` | `wwi_corporativo_data` |

El contenedor `sql_wwi` del Proyecto 1 usa el puerto 1433 y no forma parte de estos tres nodos. La API lo sigue usando para los módulos que todavía no se pasan a los nodos.

## Levantar los nodos

Los tres nodos y el contenedor del Proyecto 1 están definidos en `docker-compose.yml`, en la raíz del repositorio. Los comandos son los mismos en Windows, Linux y macOS, con Docker Desktop iniciado.

Cada nodo tiene el Agent de SQL Server activado (lo necesita la replicación) y ve la carpeta `backups/` de la raíz en `/var/opt/mssql/backup` y la carpeta `Script sql/` en `/scripts`.

### 1. Configurar las contraseñas

Copiar `.env.example` a `.env` en la raíz y poner la contraseña de `sa` de cada nodo en `MSSQL_SANJOSE_PASSWORD`, `MSSQL_LIMON_PASSWORD` y `MSSQL_CORPORATIVO_PASSWORD`. Deben cumplir los requisitos de complejidad de SQL Server. El archivo `.env` no se sube al repositorio.

### 2. Copiar el respaldo de WWI

Copiar `WideWorldImporters-Full.bak` en la carpeta `backups/` de la raíz.

### 3. Levantar los contenedores

```
docker compose up -d
docker ps
```

Deben aparecer `wwi_sanjose`, `wwi_limon`, `wwi_corporativo` y `sql_wwi`. Para conectarse desde SSMS, usar la dirección de la tabla, autenticación de SQL Server, usuario `sa` y la contraseña de ese nodo en `.env`.

docker compose crea las instancias y sus volúmenes; **no crea las bases de datos** de la tabla. Cada base se crea con los scripts de la sección siguiente.

### 4. Verificar cada nodo

```
docker exec wwi_corporativo bash -c '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -i /scripts/Proyecto2/00_verificar_nodo.sql'
```

Repetir con `wwi_sanjose` y `wwi_limon`. El resultado debe decir `Correcto` en `NombreServidor` y `Activo` en `Agent`. La contraseña se toma de las variables del propio contenedor, por eso el comando funciona igual en PowerShell y en bash.

### Si los contenedores ya se crearon con `docker run`

Los contenedores creados con `docker run` no tienen el Agent activado ni la carpeta `backups/`. Para pasarlos a docker compose sin perder datos:

```
docker stop wwi_sanjose wwi_limon wwi_corporativo
docker rm wwi_sanjose wwi_limon wwi_corporativo
docker network rm wwi_red
docker compose up -d
```

`docker rm` borra solo los contenedores: las bases quedan en los volúmenes `wwi_sanjose_data`, `wwi_limon_data` y `wwi_corporativo_data`, y docker compose los vuelve a usar. Al levantar, docker compose avisa que esos volúmenes no los creó él; es normal. En `.env` hay que poner la misma contraseña de `sa` que se usó al crear los contenedores, porque la de un volumen existente no cambia.

## Crear las bases de datos

Ejecutar cada archivo en su instancia correspondiente desde SSMS o `sqlcmd`:

| Archivo | Conexión desde SSMS |
|---|---|
| [`SanJose/01_crear_bd.sql`](SanJose/01_crear_bd.sql) | `localhost,1434` |
| [`Limon/01_crear_bd.sql`](Limon/01_crear_bd.sql) | `localhost,1435` |
| [`Corporativo/01_crear_bd.sql`](Corporativo/01_crear_bd.sql) | `localhost,1436` |


## Configurar usuarios en Corporativo

Ejecutar los archivos en este orden en `localhost,1436`:

1. [`Corporativo/01_crear_bd.sql`](Corporativo/01_crear_bd.sql): crear la base si falta.
2. [`Corporativo/02_usuarios.sql`](Corporativo/02_usuarios.sql): crear `dbo.Usuarios` si falta, con los roles `Administrador` y `Corporativo` y la asignación de sucursal.
3. [`Corporativo/03_seguridad_usuarios.template.sql`](Corporativo/03_seguridad_usuarios.template.sql): en una instalación nueva, copiar a un archivo `.local.sql`, reemplazar la contraseña de ejemplo y ejecutar la copia para crear la clave maestra, el certificado y la clave simétrica AES-256. Si ya existen, omitir este paso.
4. [`Corporativo/04_usuarios_prueba.template.sql`](Corporativo/04_usuarios_prueba.template.sql): copiar a un archivo `.local.sql`, sustituir los tres marcadores por hashes scrypt válidos generados con Node.js y ejecutar la copia. El formato que espera la API es `scrypt$<sal de 16 bytes en hexadecimal>$<hash de 64 bytes en hexadecimal>`. El script evita insertar un usuario cuyo `username` ya exista.
5. [`Corporativo/05_verificar_usuarios.sql`](Corporativo/05_verificar_usuarios.sql): consultar usuarios, certificado, claves y formato de los hashes descifrados. El resultado `CORRECTO` verifica el formato y el descifrado, pero no prueba una contraseña concreta.

Los archivos `.local.sql` están excluidos de Git. No publicar las contraseñas de los usuarios, los hashes reales ni la contraseña de la clave maestra. Conservar respaldos seguros de la clave maestra y del certificado con su clave privada para poder recuperar los datos cifrados.

La API usa `MSSQL_CORPORATIVO_PASSWORD` en el `.env` de la raíz para conectarse a Corporativo. Es la misma variable que usa docker compose para la contraseña de `sa` del contenedor Corporativo. El login web consulta la API; las demás rutas y permisos de SQL Server requieren una etapa posterior de autorización.
