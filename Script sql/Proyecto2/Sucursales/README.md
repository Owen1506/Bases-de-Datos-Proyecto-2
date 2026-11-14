# Operaciones de las sucursales

Estos archivos conservan las consultas y CRUD del primer proyecto sobre el
modelo distribuido.

## Instalación

Ejecutar en San José y Limón, después de la carga distribuida:

1. `02_sp_catalogos.sql`.
2. `03_sp_clientes.sql`.
3. `04_sp_proveedores.sql`.
4. `06_sp_ventas.sql`.
5. `verificar_operacion.sql`.

En Corporativo ejecutar:

1. `Corporativo/03_sp_clientes.sql`.
2. `Corporativo/04_sp_proveedores.sql`.
3. `Corporativo/verificar_crud_catalogos.sql`.

Los procedimientos de consulta leen los fragmentos públicos locales. Los
detalles de clientes y proveedores consultan los sinónimos sensibles de
Corporativo mediante SQL dinámico y devuelven `ContactoDisponible = 0` cuando
el nodo remoto no responde.

Las ventas se escriben en la sucursal indicada por `SESSION_CONTEXT`. Insertar,
actualizar y eliminar ajustan el inventario con `UPDLOCK` y `HOLDLOCK` dentro de
la misma transacción. Las líneas se reciben en `@LineasJson`.

Los CRUD de clientes y proveedores se ejecutan en Corporativo para modificar
la parte pública y sensible dentro de una sola transacción. La replicación
distribuye después la parte pública a las sucursales.

`verificar_operacion.sql` crea, modifica y elimina una factura dentro de una
transacción exterior y termina con `ROLLBACK`; no altera la carga inicial.
