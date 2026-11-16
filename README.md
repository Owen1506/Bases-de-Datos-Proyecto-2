Instituto Tecnológico de Costa Rica

Proyecto 2 – Bases de Datos II

**Profesor:** Cristian Paz Campos Agüero

**Estudiantes:**
- Elian J. Trejos Quirós - 2024143262
- Owen Smith Cerdas - 2024083328

II semestre, 2026

---

# Sitio web Wide World Importers - Base de datos distribuida

## Introducción

Aplicación web para administrar las operaciones de dos sucursales, San José y Limón, y consultar sus estadísticas desde Corporativo. Conserva los módulos del Proyecto 1 y distribuye los datos entre tres instancias de SQL Server 2022 en contenedores Docker. La instancia del Proyecto 1 se usa únicamente como fuente de la carga inicial.

## Objetivos alcanzados

| Requisito | Implementación en el repositorio |
| --- | --- |
| Sistema web y API | React + Vite y Node.js + Express. Incluye inicio de sesión, clientes, proveedores, productos, inventario, facturas y diez reportes. |
| Fragmentación y asignación | Catálogos públicos en los tres nodos; inventario y facturación propios de cada sucursal; datos de contacto y privacidad de clientes y proveedores solo en Corporativo. |
| Replicación | Scripts de replicación transaccional de Corporativo a las sucursales para catálogos, y de cada sucursal a Corporativo para facturas, órdenes e inventario. |
| Estadísticas | Diez reportes con filtro San José, Limón o consolidado. Tres vistas indexadas en Corporativo resumen facturas, órdenes y ganancia por producto. |
| Concurrencia | El catálogo de productos se escribe en Corporativo, con control de versión para modificaciones. Las ventas y los cambios de inventario usan transacciones y bloqueos. |
| Seguridad | Tabla de usuarios, roles y sucursal asignada; hashes `scrypt` cifrados mediante clave simétrica AES-256 de SQL Server. Cuentas SQL de la API separadas por función. |
| Fallo de nodo | La API informa indisponibilidad con HTTP 503; los detalles públicos de una sucursal pueden consultarse sin Corporativo, con aviso para los datos privados. Hay un guion de demostración de caída y recuperación. |

## Objetivos no alcanzados y limitaciones

**Pendiente identificado:** los sinónimos de datos privados en las sucursales apuntan a un servidor vinculado `wwi_corporativo`, pero el instalador no crea ese servidor vinculado. La API obtiene los detalles privados mediante una conexión directa a Corporativo, así que su flujo de detalle no depende de esos sinónimos; las consultas directas a los procedimientos SQL de detalle de sucursal requieren configurar el servidor vinculado y sus permisos.

## Arquitectura y decisiones de distribución

| Datos | San José | Limón | Corporativo | Motivo |
| --- | --- | --- | --- | --- |
| Productos, grupos, clientes, proveedores y referencias públicas | Copia de lectura | Copia de lectura | Escritura principal | Cada sucursal consulta y vende con catálogos locales; una sola autoridad evita conflictos de edición entre nodos. |
| Existencias | Escritura de San José | Escritura de Limón | Copia de ambas | Cada tienda controla su inventario; Corporativo calcula el total a partir de las dos filas identificadas por `SucursalID`. |
| Facturas, líneas y órdenes de compra | Escritura de San José | Escritura de Limón | Copia de ambas | Las operaciones continúan en el nodo de la sucursal y se consolidan para reportes. La clave compuesta con `SucursalID` evita choques de números locales. |
| Contactos, direcciones, teléfonos y datos bancarios privados | Sin tabla privada | Sin tabla privada | Escritura y almacenamiento | Los datos sensibles permanecen centralizados; la API los consulta en Corporativo al mostrar detalles. |
| Usuarios y estadísticas | — | — | Almacenamiento y consulta | Corporativo autentica y reúne la información de ambas sucursales. |

La carga inicial divide las existencias originales: San José recibe `ceil(cantidad/2)` y Limón `floor(cantidad/2)`. Es una asignación inicial porque la base fuente no distingue sucursales; después cada tienda mantiene su propio saldo. Los productos se crean, modifican y eliminan en Corporativo; la replicación distribuye el cambio. Los datos privados no se incluyen en los artículos de replicación.

Los tres nodos usan **SQL Server 2022 Developer** en contenedores independientes, con volúmenes propios y la red `wwi_red`. Esta implementación conserva el mismo motor en ambas sucursales. La distribución es lógica y física entre instancias; no demuestra interoperabilidad entre motores de base de datos distintos.

| Nodo | Contenedor | Puerto local | Base de datos |
| --- | --- | --- | --- |
| San José | `wwi_sanjose` | 1434 | `WideWorldImporters_SanJose` |
| Limón | `wwi_limon` | 1435 | `WideWorldImporters_Limon` |
| Corporativo | `wwi_corporativo` | 1436 | `WideWorldImporters_Corporativo` |
| Origen del Proyecto 1 | `sql_wwi` | 1433 | `WideWorldImporters` |

## Funcionalidad

- **Administrador:** ingresa con una sucursal asignada; consulta y gestiona clientes, proveedores, productos y facturas. Consulta y ajusta existencias de su sucursal. Las escrituras compartidas de clientes, proveedores y productos pasan por Corporativo; las ventas y existencias se escriben localmente.
- **Corporativo:** consulta los diez reportes con filtro por sucursal o consolidado. Los reportes cubren compras a proveedores, ventas por cliente, productos con mayor ganancia, clientes con más facturas, proveedores con más órdenes, matriz de ventas por categoría y año, seguimientos de clientes y proveedores, rotación estimada y métodos de envío por destino.
- **Sesión:** el token se mantiene en memoria del navegador; la API valida rol y sucursal en cada solicitud. La sesión dura ocho horas, termina al cerrar sesión y se pierde al reiniciar la API o recargar la página.

La tabla `dbo.Usuarios` contiene `iduser`, `username`, `password`, `fullname`, `active`, `rol`, `email`, `hiredate` y `SucursalID`. La contraseña ingresada se compara en la API con un hash `scrypt` con sal; ese hash se almacena cifrado en SQL Server mediante `EncryptByKey`, certificado y clave simétrica AES-256. `api_login`, `api_administrador`, `api_corporativo` y `api_sucursal` tienen permisos SQL separados. `sa` se reserva para instalación, carga y agentes de replicación.

## Requisitos

- Docker con Compose.
- Node.js 20.19+ o 22.12+.
- Respaldo `WideWorldImporters-Full.bak` de Microsoft SQL Server Samples.

## Instalación desde cero

Se necesita Docker con Compose, Node.js 20.19+ o 22.12+ y el respaldo `WideWorldImporters-Full.bak` de [Microsoft SQL Server Samples](https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0). Los comandos se ejecutan desde la raíz del repositorio, salvo donde se indica otra carpeta.

1. Copiar `.env.example` a `.env` y reemplazar **todas** las contraseñas de ejemplo: las cuatro de SQL Server, la clave maestra, las tres cuentas de demostración y las cuatro cuentas SQL de la API. Usar las contraseñas originales de `sa` si los volúmenes de Docker ya existen.
2. Guardar el respaldo como `backups/WideWorldImporters-Full.bak`. La carpeta `backups/` y `.env` están excluidos de Git.
3. Instalar dependencias y ejecutar el instalador en una **instalación nueva**:

   ```bash
   cd proyectos/Api
   npm ci
   node scripts/instalar.js
   ```

   El instalador inicia los contenedores, restaura el origen, crea y carga los tres nodos, instala procedimientos, vistas y cuentas, y configura la replicación al final. Si se detiene, corregir el error y continuar con `node scripts/instalar.js NUMERO_DE_PASO`, usando el número que muestra en pantalla. **No repetir desde el inicio sobre bases ya pobladas.**

4. Iniciar la API y el sitio web en terminales distintas:

   ```bash
   # Desde proyectos/Api
   npm start
   ```

   ```bash
   # Desde proyectos/WebSite
   npm ci
   npm run dev
   ```

Abrir [http://localhost:5173](http://localhost:5173). La API escucha en `http://localhost:3000`. Las cuentas de ejemplo son `admin_sj`, `admin_limon` y `gerente`; sus contraseñas son las definidas en `.env` como `CLAVE_ADMIN_SJ`, `CLAVE_ADMIN_LIMON` y `CLAVE_GERENTE`. El instalador crea archivos `.local.sql` con secretos, excluidos de Git.

Para **bases ya instaladas**, desde `proyectos/Api` se puede actualizar el contrato de procedimientos con `npm run actualizar:api`, configurar las cuentas SQL con `node scripts/configurarSeguridad.js` y reiniciar la API. Estos comandos no restauran ni recargan las bases. El procedimiento detallado de nodos y usuarios está en [la guía de SQL](Script%20sql/Proyecto2/README.md).

## Comprobación y demostración presencial

1. Consultar `http://localhost:3000/api/estado`: debe indicar que responden Corporativo, San José y Limón. Ingresar como cada administrador y como gerente para verificar los permisos y las vistas correspondientes.
2. Crear, modificar y eliminar un producto desde un administrador; consultar después el catálogo en ambas sucursales. La propagación es asíncrona y puede tardar unos segundos. Cambiar existencias de una sucursal y comprobar que el saldo de la otra permanece independiente y que Corporativo ve ambas filas.
3. Crear una factura en una sucursal y comprobar su copia y el reporte consolidado en Corporativo. Filtrar un reporte por cada sucursal y por consolidado.
4. Usar [el guion de replicación](Script%20sql/Proyecto2/Replicacion/06_demo.sql) y [el guion de caída de nodo](Script%20sql/Proyecto2/Replicacion/07_demo_falla.sql) para comprobar propagación, consultas durante una falla y entrega de cambios al recuperar el nodo. Los valores de ejemplo del guion deben revisarse contra los datos actuales antes de ejecutarlo porque modifica filas.

Si una sucursal no responde, sus operaciones reciben HTTP 503; la otra puede seguir trabajando. Si falla Corporativo, no se puede iniciar una sesión nueva, editar catálogos compartidos ni consultar estadísticas; las sesiones existentes pueden continuar con operaciones locales, y los detalles públicos omiten contactos privados. Los cambios de replicación deben verificarse tras restablecer el nodo; el guion de falla incluye una consulta de comandos pendientes. Esta solución no implementa un nodo alterno para Corporativo.

## Estructura del proyecto

| Ruta | Contenido |
| --- | --- |
| [`Script sql/Proyecto2/`](Script%20sql/Proyecto2/) | Creación de nodos, fragmentación, productos, procedimientos, vistas, seguridad y replicación. |
| [`proyectos/Api/`](proyectos/Api/) | API Express y scripts de instalación, carga y actualización. |
| [`proyectos/WebSite/`](proyectos/WebSite/) | Interfaz React/Vite. |
| [`docker-compose.yml`](docker-compose.yml) | Cuatro instancias SQL Server: origen y tres nodos distribuidos. |
| [`.env.example`](.env.example) | Plantilla de configuración sin claves reales. |

El [README de fragmentación](Script%20sql/Proyecto2/Fragmentacion/README.md) explica la estructura de los datos y la carga inicial. Algunos comentarios de esa guía describen etapas previas del desarrollo; para el estado global de la entrega prevalece esta sección de resultados y el código actual.
