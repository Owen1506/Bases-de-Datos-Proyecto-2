Instituto Tecnológico de Costa Rica

Proyecto 1 – Bases de Datos 2

Profesor:
  Cristian Paz Campos Aguero

Estudiantes:
  Elian J. Trejos Quirós - 2024143262
  Owen Smith Cerdas - 2024083328

II Semestre, 2026

---

# Sitio web WideWorldImporters - SQL Server + Node.js + React

### Integrantes
- Elian J. Trejos Quirós - 2024143262
- Owen Smith Cerdas - 2024083328

### Enlace del video
https://youtu.be/6pdkmnrEXSs

---

## Introducción

Sitio web para consultar y gestionar la base de datos de ejemplo **WideWorldImporters** de Microsoft.

- Todo el procesamiento de datos (filtros, orden, paginación, cálculos y estadísticas) se hace en
  **SQL Server** mediante **stored procedures**. La API y la página solo envían parámetros y muestran
  los resultados.
- Los stored procedures acceden a las tablas únicamente por medio de **sinónimos** (esquema `syn`).
- Los INSERT, UPDATE y DELETE usan **BEGIN TRANSACTION / COMMIT / ROLLBACK**.

Tecnologías: SQL Server 2022 en Docker (WSL2), API en Node.js + Express, sitio web en React + Vite.

## Objetivos alcanzados

- **Clientes:** listado con filtros acumulativos (nombre por texto libre, categoría y método de entrega),
  restaurar filtros, orden alfabético, paginación, ventana de detalle con mapa y CRUD.
- **Proveedores:** listado con filtros (nombre y categoría), detalle con mapa, banco y cuenta, y CRUD.
- **Inventario:** listado con filtros (nombre, grupo y rango de cantidad), detalle con enlace al
  proveedor y CRUD.
- **Ventas:** listado con filtros (cliente, rango de fechas y rango de montos), detalle de la factura
  con encabezado y líneas, enlaces al cliente y a los productos, y CRUD.
- **Reportes 1 al 5:** compras a proveedores y ventas a clientes con ROLLUP; top 5 de productos,
  clientes y proveedores con DENSE_RANK y PARTITION BY.
- Validaciones en la página, en la API y en los stored procedures, con mensajes de error claros.

## Objetivos no alcanzados

- Reportes 6 al 10 (matriz de ventas por categoría y año, seguimiento mensual de compras de clientes
  y de proveedores, rotación de inventario y método de envío favorito).

## Requisitos

- Windows con WSL2 (Ubuntu)
- Docker Desktop con integración WSL2
- Node.js v20
- Archivo `WideWorldImporters-Full.bak` (https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0)

## Instalación

### 1. Configurar la contraseña

```bash
cp .env.example .env
```

Editar `.env` y poner la contraseña del usuario `sa` en `MSSQL_SA_PASSWORD`.

### 2. Levantar SQL Server

Copiar `WideWorldImporters-Full.bak` en la carpeta `backups/` y luego:

```bash
docker compose up -d
```

### 3. Restaurar la base y crear los stored procedures

Ejecutar los scripts en orden:

```bash
for f in 00_restore_wwi 01_sinonimos 02_sp_catalogos 03_sp_clientes 04_sp_proveedores 05_sp_inventario 06_sp_ventas 07_sp_estadisticas; do
  docker exec sql_wwi bash -c "/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P \"\$MSSQL_SA_PASSWORD\" -C -i /scripts/$f.sql"
done
```

| Script | Contenido |
|---|---|
| `00_restore_wwi.sql` | Restaura WideWorldImporters |
| `01_sinonimos.sql` | Sinónimos de las tablas (esquema `syn`) |
| `02_sp_catalogos.sql` | Catálogos y buscadores para los filtros y formularios |
| `03` a `06` | Stored procedures de clientes, proveedores, inventario y ventas |
| `07_sp_estadisticas.sql` | Stored procedures de los reportes |
| `99_ejemplos_ejecucion.sql` | Ejemplos de ejecución de todos los stored procedures usados por la aplicación |

### 4. Levantar la API (puerto 3000)

```bash
cd proyectos/Api
npm install
npm start
```

### 5. Levantar el sitio web (puerto 5173)

En otra terminal:

```bash
cd proyectos/WebSite
npm install
npm run dev
```

Abrir http://localhost:5173

## Estructura del proyecto

```
Proyecto-1-Bases2/
├── Script sql/                 scripts .sql en orden de ejecución
├── proyectos/
│   ├── Api/                    API en Node.js + Express
│   │   └── src/
│   │       ├── routes/         una ruta por módulo, cada una llama a sus stored procedures
│   │       ├── db.js           conexión a SQL Server
│   │       ├── validar.js      validaciones de los parámetros
│   │       └── index.js        inicio de la API
│   └── WebSite/                sitio web en React + Vite
│       └── src/
│           ├── pages/          una página por módulo (y reportes/ para las estadísticas)
│           ├── components/     ventanas de detalle, formularios, paginación, buscador
│           ├── styles/         estilos separados por parte de la interfaz
│           └── api.js          llamadas a la API
├── codigo/                     carpeta de la plantilla del curso
├── backups/                    aquí va el .bak (no se sube al repositorio)
├── docker-compose.yml          contenedor de SQL Server
├── .env.example                ejemplo del archivo con la contraseña de sa
└── README.md
```
