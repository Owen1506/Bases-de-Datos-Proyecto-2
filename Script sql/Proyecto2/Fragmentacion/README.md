# Fragmentación: productos e inventario

## Asignación

| Fragmento | Corporativo | San José | Limón | Regla |
|---|---|---|---|---|
| `catalogo.Productos` | Principal | Copia | Copia | Un `ProductoID` y los mismos atributos de catálogo en los tres nodos. |
| `catalogo.ProductoGrupos` | Principal | Copia | Copia | Misma relación producto-grupo en los tres nodos. |
| `inventario.Existencias` | No | Propia | Propia | Una fila por producto y sucursal; cantidad y ubicación locales. |

El catálogo se duplica para consultar y vender productos localmente. Las existencias se fragmentan horizontalmente por sucursal para que una venta o ajuste en San José no altere la cantidad de Limón. El total empresarial se calcula sumando ambas existencias; no se almacena como una tercera cantidad.

`ProductoID` se asigna una sola vez y se conserva en las copias. No se usa `IDENTITY` en estas tablas: esto permite importar los identificadores de `Warehouse.StockItems` y evita que cada nodo genere el mismo ID para productos diferentes. La escritura del catálogo debe coordinarse en un solo nodo antes de publicar sus cambios; la decisión de API y la publicación quedan para entregables posteriores.

## Scripts

1. Crear las bases con los scripts `../Corporativo/01_crear_bd.sql`, `../SanJose/01_crear_bd.sql` y `../Limon/01_crear_bd.sql`.
2. Ejecutar `01_catalogo_productos.sql` una vez en **cada** base nueva.
3. Ejecutar `02_existencias_sucursal.sql` **solo** en San José y Limón.
4. Ejecutar `03_verificar_estructura.sql` en cada base. En Corporativo debe indicar que no hay tabla de existencias; en cada sucursal debe indicar que sí existe.

Los scripts de estructura son repetibles: crean los objetos que faltan y no borran datos. No cambian los procedimientos del Proyecto 1 ni crean publicaciones o suscripciones. No insertar datos de prueba en estas tablas antes de la carga inicial.

## Carga inicial desde Proyecto 1

La carga está implementada en `proyectos/Api/scripts/fragmentacion.js`. Usa la conexión SQL ya instalada en la API. Lee `Warehouse.StockItems`, `Warehouse.StockItemStockGroups` y `Warehouse.StockItemHoldings` del servidor original (`localhost:1433`) y guarda una copia JSON en `backups/fragmentacion/carga_inicial.json`. Luego lee ese archivo y hace inserciones parametrizadas en los tres nodos. `backups/` está excluido de Git.

Con los cuatro contenedores activos y las tablas de fragmentación creadas, ejecutar desde `proyectos/Api`:

```bash
npm install
node scripts/fragmentacion.js exportar
node scripts/fragmentacion.js cargar
node scripts/fragmentacion.js verificar
```

La exportación necesita `MSSQL_SA_PASSWORD` en el `.env` de la raíz. La carga necesita también `MSSQL_CORPORATIVO_PASSWORD`, `MSSQL_SANJOSE_PASSWORD` y `MSSQL_LIMON_PASSWORD`. Ejecutar desde la máquina donde los puertos 1433 a 1436 estén publicados. El script se detiene si ya existe el JSON, para no reemplazar accidentalmente la copia de origen. Durante la exportación se leen las tres tablas bajo una transacción serializable; no modificar el catálogo ni el inventario de Proyecto 1 durante la migración.

La cantidad original se reparte así por producto: San José recibe `Math.ceil(cantidad / 2)` y Limón `Math.floor(cantidad / 2)`. Por ejemplo, 21 unidades quedan 11 y 10. La ubicación antigua no se copia porque no identifica una sucursal; queda vacía hasta que cada sucursal registre su ubicación real. El script comprueba que todos los productos tengan una cantidad de origen y que esa cantidad no sea negativa.

La carga se hace en una transacción por nodo. Si un nodo ya tiene exactamente los datos del JSON, se omite al repetir `cargar`; si tiene datos diferentes, se detiene antes de escribir. `verificar` compara los productos y grupos completos con el JSON y comprueba la cantidad esperada en cada sucursal. El JSON es solo una instantánea inicial: cambios posteriores requieren la futura replicación y la adaptación de la API.

## Catálogos de referencia del producto

`catalogo.ProveedoresBasicos` (ID y nombre), `catalogo.GruposProducto`, `catalogo.Colores` y `catalogo.TiposEmpaque`. Estos IDs permiten interpretar los campos `ProveedorID`, `ColorID`, `UnidadEmpaqueID`, `EmpaqueExteriorID` y `GrupoID` de los productos. Los contactos, direcciones, teléfonos y datos bancarios de proveedores **no** se exportan a las sucursales.

Después de completar la carga inicial de productos anterior:

1. Ejecutar `04_catalogos_referencia.sql` en Corporativo, San José y Limón.
2. Desde `proyectos/Api`, ejecutar:

   ```bash
   node scripts/catalogosProducto.js exportar
   node scripts/catalogosProducto.js cargar
   node scripts/catalogosProducto.js verificar
   ```

3. Si se desea comprobar directamente en SQL Server, ejecutar `05_verificar_referencias.sql` en cada nodo. Debe terminar con `EstadoReferencias = CORRECTO`.

El exportador guarda `backups/fragmentacion/catalogos_referencia.json` sin reemplazar un archivo existente. La carga conserva los IDs originales, comprueba que las cuatro tablas coincidan con el JSON y rechaza productos que referencien IDs inexistentes. Cada nodo se carga en una transacción; si ya coincide con el archivo, se omite al repetir el comando. Este paso no cambia las publicaciones ni suscripciones de replicación.

## Correspondencia con Proyecto 1

| Origen | Destino | Nota |
|---|---|---|
| `Warehouse.StockItems` | `catalogo.Productos` | Atributos que usa el formulario actual. |
| `Warehouse.StockItemStockGroups` | `catalogo.ProductoGrupos` | Relación entre productos y grupos. |
| `Warehouse.StockItemHoldings` | `inventario.Existencias` | Cargar por sucursal; la base original no distingue San José de Limón. |

Quedan pendientes los fragmentos completos de clientes y proveedores (con datos sensibles solo en Corporativo), las facturas propias de cada sucursal y la conexión de la API con estos nodos.
