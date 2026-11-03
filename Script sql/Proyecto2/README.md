# Proyecto 2: configuración de los nodos SQL Server

El sistema distribuido utiliza tres contenedores independientes de SQL Server 2022 Developer. Todos se comunican mediante la red Docker `wwi_red` y cada uno conserva sus datos en un volumen propio.

| Nodo | Contenedor | Conexión desde SSMS | Base de datos | Volumen |
|---|---|---|---|---|
| San José | `wwi_sanjose` | `localhost,1434` | `WideWorldImporters_SanJose` | `wwi_sanjose_data` |
| Limón | `wwi_limon` | `localhost,1435` | `WideWorldImporters_Limon` | `wwi_limon_data` |
| Corporativo | `wwi_corporativo` | `localhost,1436` | `WideWorldImporters_Corporativo` | `wwi_corporativo_data` |

El contenedor `sqlserver_wwi` del Proyecto 1 usa el puerto 1433 y no forma parte de estos tres nodos.

## Recrear los contenedores desde cero

Ejecutar los siguientes comandos en **PowerShell**, con Docker Desktop iniciado. La contraseña debe cumplir los requisitos de complejidad de SQL Server. No se guarda en el repositorio.

### 1. Crear la red Docker

```powershell
docker network create wwi_red
```

### 2. Configurar la contraseña de `sa`

```powershell
$env:MSSQL_SA_PASSWORD = Read-Host "Contraseña para SQL Server"
```

Cuando aparezca el mensaje, escribir la contraseña y presionar Enter. Los tres contenedores recibirán ese valor mediante `-e MSSQL_SA_PASSWORD`.

### 3. Crear los tres contenedores

**San José (puerto 1434):**

```powershell
docker run -d --name wwi_sanjose --hostname wwi_sanjose --network wwi_red -e "ACCEPT_EULA=Y" -e MSSQL_SA_PASSWORD -e "MSSQL_PID=Developer" -p 1434:1433 -v wwi_sanjose_data:/var/opt/mssql mcr.microsoft.com/mssql/server:2022-latest
```

**Limón (puerto 1435):**

```powershell
docker run -d --name wwi_limon --hostname wwi_limon --network wwi_red -e "ACCEPT_EULA=Y" -e MSSQL_SA_PASSWORD -e "MSSQL_PID=Developer" -p 1435:1433 -v wwi_limon_data:/var/opt/mssql mcr.microsoft.com/mssql/server:2022-latest
```

**Corporativo (puerto 1436):**

```powershell
docker run -d --name wwi_corporativo --hostname wwi_corporativo --network wwi_red -e "ACCEPT_EULA=Y" -e MSSQL_SA_PASSWORD -e "MSSQL_PID=Developer" -p 1436:1433 -v wwi_corporativo_data:/var/opt/mssql mcr.microsoft.com/mssql/server:2022-latest
```

### 4. Verificar los contenedores

```powershell
docker ps
```

Los tres nombres deben aparecer en la lista. Para conectarse desde SSMS, usar la dirección indicada en la tabla, autenticación de SQL Server, usuario `sa` y la contraseña configurada en el paso 2.

Los comandos `docker run` crean las instancias y sus volúmenes; **no crean automáticamente las bases de datos** de la tabla. Cada base debe crearse o restaurarse en su instancia correspondiente. Si la red o un contenedor ya existe, no repetir el comando de creación para ese recurso.

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

La API usa `MSSQL_CORPORATIVO_PASSWORD` en el `.env` de la raíz para conectarse a Corporativo. Al crear los nodos con los comandos anteriores, ese valor debe coincidir con la contraseña de `sa` indicada en PowerShell. El login web consulta la API; las demás rutas y permisos de SQL Server requieren una etapa posterior de autorización.
