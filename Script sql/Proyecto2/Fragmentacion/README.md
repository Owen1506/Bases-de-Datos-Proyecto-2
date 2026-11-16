# Fragmentación de WideWorldImporters

## Asignación

| Fragmento | Corporativo | San José | Limón | Regla |
|---|---|---|---|---|
| `Warehouse.StockItems` | Principal | Copia | Copia | Un `StockItemID` y los mismos atributos de catálogo en los tres nodos. |
| `Warehouse.StockItemStockGroups` | Principal | Copia | Copia | Misma relación producto-grupo en los tres nodos. |
| `Warehouse.StockItemHoldings` | Copia consolidada | Propia | Propia | Una fila por producto y sucursal; cantidad y ubicación se escriben en la sucursal. |

El catálogo se duplica para consultar y vender productos localmente. Las existencias se fragmentan horizontalmente por sucursal para que una venta o ajuste en San José no altere la cantidad de Limón. El total empresarial se calcula sumando ambas existencias; Corporativo recibirá ambas filas como copias para las consultas, sin mantener una tercera cantidad independiente.

`StockItemID` se asigna una sola vez y se conserva en las copias. No se usa `IDENTITY` en estas tablas: esto permite importar los identificadores de `Warehouse.StockItems` y evita que cada nodo genere el mismo ID para productos diferentes. Las tablas físicas conservan nombres y columnas de WWI, pero solo las columnas que necesita este módulo; no son copias del esquema temporal completo. El catálogo se escribe en Corporativo y se replica a las sucursales.

Los SP conservan parámetros y resultados en español para la API actual. Sus consultas y escrituras usan las columnas WWI mediante `syn.*`. `Warehouse.StockItemHoldings` permite `NULL` en ubicación y datos de conteo/costo porque la carga inicial no dispone de valores propios de cada sucursal.

## Scripts

1. Crear las bases con los scripts `../Corporativo/01_crear_bd.sql`, `../SanJose/01_crear_bd.sql` y `../Limon/01_crear_bd.sql`.
2. Ejecutar `01_catalogo_productos.sql` una vez en **cada** base nueva.
3. Ejecutar `02_existencias_sucursal.sql` **solo** en San José y Limón. En una base nueva incluye `SucursalID`; para migrar una base anterior se usa el archivo 16.
4. Después de `16_inventario_nodos.sql`, `Warehouse.StockItemHoldings` existe en los tres nodos: en las sucursales con su inventario y en Corporativo como copia consolidada.

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

`Purchasing.Suppliers` comienza con `SupplierID` y `SupplierName`; `06_clientes_proveedores_publicos.sql` agrega las otras columnas publicas. `Warehouse.StockGroups`, `Warehouse.Colors` y `Warehouse.PackageTypes` siguen siendo referencias de productos. Los contactos, direcciones, telefonos y datos bancarios de proveedores **no** se exportan a las sucursales.

Después de completar la carga inicial de productos anterior:

1. Ejecutar `04_catalogos_referencia.sql` en Corporativo, San José y Limón.
2. Desde `proyectos/Api`, ejecutar:

   ```bash
   node scripts/catalogosProducto.js exportar
   node scripts/catalogosProducto.js cargar
   node scripts/catalogosProducto.js verificar
   ```

3. Si se desea comprobar directamente en SQL Server, ejecutar `05_verificar_referencias.sql` en cada nodo. Debe terminar con `EstadoReferencias = CORRECTO`.

El exportador guarda `backups/fragmentacion/catalogos_referencia.json` sin reemplazar un archivo existente. La carga conserva los IDs originales, comprueba que las cuatro tablas coincidan con el JSON y rechaza productos que referencien IDs inexistentes. Cada nodo se carga en una transacción; si ya coincide con el archivo, se omite al repetir el comando. Esta carga no cambia las publicaciones ni suscripciones de replicación.

## Clientes y proveedores

La parte publica conserva nombres de WWI: `Sales.Customers`, `Purchasing.Suppliers`, `Application.People` y las tablas de categorias, grupos de compra, metodos de entrega, paises, provincias y ciudades. El archivo 06 crea `Application.People` inicialmente con solo `PersonID`; el archivo 10 agrega los vendedores sin crear otra tabla fisica.

La parte sensible vive solo en Corporativo bajo `Sensitive.Customers`, `Sensitive.Suppliers` y `Sensitive.People`. El esquema adicional `Sensitive` es necesario porque cada parte publica y privada tiene el mismo nombre de tabla de WWI. Las columnas privadas conservan nombres y tipos de WWI, pero se omiten columnas temporales y de auditoria. `Sensitive.Suppliers` incluye tambien `InternalComments`.

`Sensitive.CustomersRemote` y `Sensitive.SuppliersRemote` son vistas de lectura en Corporativo. Exponen las columnas escalares de esas tablas, excepto `DeliveryLocation` (`geography`), porque SQL Server no permite consultar por nombre de cuatro partes una tabla remota que exponga columnas CLR. En las sucursales, `syn.CustomersSensitive` y `syn.SuppliersSensitive` apuntan a estas vistas; las tablas fisicas y la columna geografica permanecen en Corporativo.

Orden de los archivos existentes y nuevos:

1. En los tres nodos, ejecutar `06_clientes_proveedores_publicos.sql` despues de `04_catalogos_referencia.sql`. Crea las tablas publicas vacias y agrega columnas anulables a los 15 proveedores ya existentes, sin borrar sus filas.
2. Solo en Corporativo, ejecutar `07_datos_sensibles_corporativo.sql`. Crea las tres tablas privadas vacias.
3. En los tres nodos, ejecutar `08_verificar_clientes_proveedores.sql`. Debe terminar con `EstadoFragmentacion = CORRECTO`; comprueba tablas, llaves y que las sucursales no tengan tablas sensibles.
4. En los tres nodos, ejecutar `09_sinonimos_clientes_proveedores.sql`. Los sinonimos publicos son locales. En Corporativo los privados son locales; en sucursales apuntan al linked server `wwi_corporativo`. Crear el sinonimo no consulta el destino: para usarlo, se debe configurar ese linked server y sus permisos.

Los catalogos replicados tienen el mismo ID en los tres nodos. Solo los vendedores de `Application.People` llevan `SucursalID INT` con valor 1/2 para indicar su sucursal; los demas contactos llevan `NULL`. Las columnas agregadas a `Purchasing.Suppliers` quedan `NULL` hasta cargar sus valores; despues se podra exigir `NOT NULL` en las que WWI lo exige.

**Estos archivos no cargan clientes, personas ni datos sensibles.** `Pub_Catalogo` ya publica `Purchasing.Suppliers` con `replicate_ddl = 0`. Las nuevas columnas no forman parte automaticamente del articulo actual; se debe actualizar la publicacion antes de replicar cambios en ellas. No cargar esas columnas hasta completar y comprobar esa configuracion.

## Vendedores en Application.People

El nombre de tabla y las columnas `PersonID`, `FullName` e `IsSalesperson` son de WWI. `SucursalID` es la columna adicional del proyecto: 1 para San Jose y 2 para Limon. En la tabla publica, una persona con `IsSalesperson = 1` debe tener `FullName` y `SucursalID`; una persona con `IsSalesperson = 0` debe tener ambos en `NULL`. Los nombres y datos de contacto privados permanecen en `Sensitive.People` de Corporativo. Si un vendedor tambien es contacto, su nombre es publico por su condicion de vendedor.

1. En Corporativo, San Jose y Limon, ejecutar `10_vendedores_publicos.sql` despues de `06_clientes_proveedores_publicos.sql`. El script amplía la tabla existente, conserva las personas que ya hubiera y no agrega filas.
2. En los tres nodos, ejecutar `11_verificar_vendedores.sql`. Debe devolver `EstadoVendedores = CORRECTO`; antes de cargar personas es normal que `Vendedores = 0`.
3. Se puede repetir `08_verificar_clientes_proveedores.sql`: antes y despues del archivo 10 comprueba que no se publiquen nombres de contactos.

`syn.People`, creado por el archivo 09, sigue apuntando a `Application.People`. La clave unica `(SucursalID, PersonID)` permite que las facturas validen la sucursal del vendedor con una llave foranea compuesta. Se debe agregar `Application.People` a `Pub_Catalogo` y publicar estas columnas antes de cargar personas. La asignacion de vendedores a sucursales y la carga de sus nombres se haran en los scripts de carga de datos.

## Facturas, ordenes e inventario

Las tablas fisicas mantienen los nombres `Sales.Invoices`, `Sales.InvoiceLines`, `Purchasing.PurchaseOrders`, `Purchasing.PurchaseOrderLines` y `Warehouse.StockItemHoldings` de WWI. Conservan los nombres y tipos de las columnas de negocio necesarias; se omiten las columnas de auditoria, temporales y calculadas del origen. `SucursalID INT` es la columna adicional: 1 para San Jose y 2 para Limon. Las llaves primarias de facturas, lineas, ordenes e inventario usan `(SucursalID, numero)` para que Corporativo pueda reunir ambas sucursales sin choques de identificador. Las llaves foraneas de las lineas incluyen `SucursalID` y no permiten asociarlas a otra sucursal.

Orden para preparar la estructura en las bases actuales, despues de los archivos 01, 02, 04, 06 y 10 que correspondan:

1. En San Jose y Limon, ejecutar `12_facturas_sucursales.sql`; en Corporativo, `13_facturas_corporativo.sql`.
2. En San Jose y Limon, ejecutar `14_ordenes_sucursales.sql`; en Corporativo, `15_ordenes_corporativo.sql`.
3. En los tres nodos, ejecutar `16_inventario_nodos.sql`. En sucursales agrega el ID fijo de la sucursal a las filas existentes y cambia su clave primaria sin borrar filas ni modificar `QuantityOnHand`. En Corporativo crea la tabla consolidada vacia.
4. En los tres nodos, ejecutar `17_sinonimos_operaciones.sql`. `syn.Invoices`, `syn.InvoiceLines`, `syn.PurchaseOrders`, `syn.PurchaseOrderLines` y `syn.Existencias` apuntan a tablas locales.

En las sucursales, los nuevos identificadores de factura, linea y orden se generan localmente con `IDENTITY`. Corporativo no genera esos numeros: recibe el numero junto a `SucursalID`. Para importar los IDs originales de WWI se necesitara `SET IDENTITY_INSERT ON` durante la carga de cada tabla de sucursal. `Sales.Invoices.OrderID` conserva la columna original sin llave foranea porque `Sales.Orders` no se crea en estos archivos. `Sales.Invoices.SalespersonPersonID` se valida junto con `SucursalID` contra `Application.People`.

Estos archivos no insertan facturas, ordenes ni filas consolidadas de inventario. Se deben agregar los articulos reales a las publicaciones y coordinar el orden de replicacion. La comprobacion completa de las tablas se documentara despues de preparar la estructura.

## Correspondencia con Proyecto 1

| Origen | Destino | Nota |
|---|---|---|
| `Warehouse.StockItems` | `Warehouse.StockItems` | Atributos que usa el formulario actual. |
| `Warehouse.StockItemStockGroups` | `Warehouse.StockItemStockGroups` | Relación entre productos y grupos. |
| `Warehouse.StockItemHoldings` | `Warehouse.StockItemHoldings` | Cargar por sucursal; la base original no distingue San José de Limón. |

Quedan pendientes la comprobacion completa de la estructura, la carga de datos, los articulos reales de replicacion y la conexion de la API con estos modulos.
