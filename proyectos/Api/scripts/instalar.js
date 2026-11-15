// Instalador del Proyecto 2: levanta los contenedores, prepara sql_wwi y crea y llena los tres nodos en orden, un paso a la vez.
// Requisitos: Docker iniciado, nodos sin instalar, backups/WideWorldImporters-Full.bak
// y el .env de la raíz con todas las contraseñas (ver .env.example).
// Uso, desde proyectos/Api:
//   node scripts/instalar.js       instala todo
//   node scripts/instalar.js 40    continúa desde el paso 40
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');

const RAIZ = path.resolve(__dirname, '../../..');
const CARPETA_SQL = path.join(RAIZ, 'Script sql');
const CARPETA_JSON = path.join(RAIZ, 'backups/fragmentacion');
require('dotenv').config({ path: path.join(RAIZ, '.env'), quiet: true });

// Contenedor y base de datos de cada nodo. Proyecto 1 es sql_wwi, de donde salen los datos
const NODOS = {
  'Proyecto 1': { contenedor: 'sql_wwi', base: 'WideWorldImporters' },
  'Corporativo': { contenedor: 'wwi_corporativo', base: 'WideWorldImporters_Corporativo' },
  'San José': { contenedor: 'wwi_sanjose', base: 'WideWorldImporters_SanJose' },
  'Limón': { contenedor: 'wwi_limon', base: 'WideWorldImporters_Limon' }
};

// Archivo que crea cada script de carga al exportar; si ya existe, se reutiliza
const JSON_EXPORTADO = {
  'fragmentacion.js': 'carga_inicial.json',
  'catalogosProducto.js': 'catalogos_referencia.json',
  'cargaDistribuida.js': 'carga_distribuida.json'
};

// Cada paso, en orden: [dónde, qué, base opcional].
// Dónde: un nodo (ejecuta el .sql en su contenedor) o un paso especial: 'Docker', 'Carga' o 'Claves'.
// Qué: el archivo de Script sql, el script de carga con su comando, o la descripción del paso especial.
// Base: solo 'master', cuando la base del nodo todavía no existe; si falta, se usa la base del nodo.
const PASOS = [
  // 1. Contenedores: levantarlos y esperar a que SQL Server responda
  ['Docker', 'levantar los contenedores y esperar a que SQL Server responda'],

  // 2. Proyecto 1 (sql_wwi): restaurar WWI desde el .bak y sus SP. La API todavía usa algunos de ellos
  ['Proyecto 1', '00_restore_wwi.sql', 'master'],
  ['Proyecto 1', '01_sinonimos.sql'],
  ['Proyecto 1', '02_sp_catalogos.sql'],
  ['Proyecto 1', '03_sp_clientes.sql'],
  ['Proyecto 1', '04_sp_proveedores.sql'],
  ['Proyecto 1', '05_sp_inventario.sql'],
  ['Proyecto 1', '06_sp_ventas.sql'],
  ['Proyecto 1', '07_sp_estadisticas.sql'],

  // 3. Nodos: revisar que estén listos y crear las bases
  ['Corporativo', 'Proyecto2/00_verificar_nodo.sql', 'master'],
  ['San José', 'Proyecto2/00_verificar_nodo.sql', 'master'],
  ['Limón', 'Proyecto2/00_verificar_nodo.sql', 'master'],
  ['Corporativo', 'Proyecto2/Corporativo/01_crear_bd.sql', 'master'],
  ['San José', 'Proyecto2/SanJose/01_crear_bd.sql', 'master'],
  ['Limón', 'Proyecto2/Limon/01_crear_bd.sql', 'master'],

  // 4. Fragmentación: catálogo de productos e inventario de cada sucursal, con sus datos
  ['Corporativo', 'Proyecto2/Fragmentacion/01_catalogo_productos.sql'],
  ['San José', 'Proyecto2/Fragmentacion/01_catalogo_productos.sql'],
  ['Limón', 'Proyecto2/Fragmentacion/01_catalogo_productos.sql'],
  ['San José', 'Proyecto2/Fragmentacion/02_existencias_sucursal.sql'],
  ['Limón', 'Proyecto2/Fragmentacion/02_existencias_sucursal.sql'],
  ['Carga', 'fragmentacion.js exportar'],
  ['Carga', 'fragmentacion.js cargar'],
  ['Carga', 'fragmentacion.js verificar'],
  ['Corporativo', 'Proyecto2/Fragmentacion/04_catalogos_referencia.sql'],
  ['San José', 'Proyecto2/Fragmentacion/04_catalogos_referencia.sql'],
  ['Limón', 'Proyecto2/Fragmentacion/04_catalogos_referencia.sql'],
  ['Carga', 'catalogosProducto.js exportar'],
  ['Carga', 'catalogosProducto.js cargar'],
  ['Carga', 'catalogosProducto.js verificar'],
  ['Corporativo', 'Proyecto2/Fragmentacion/05_verificar_referencias.sql'],
  ['San José', 'Proyecto2/Fragmentacion/05_verificar_referencias.sql'],
  ['Limón', 'Proyecto2/Fragmentacion/05_verificar_referencias.sql'],

  // 5. Fragmentación: clientes, proveedores, vendedores, facturas y órdenes (solo estructura)
  ['Corporativo', 'Proyecto2/Fragmentacion/06_clientes_proveedores_publicos.sql'],
  ['San José', 'Proyecto2/Fragmentacion/06_clientes_proveedores_publicos.sql'],
  ['Limón', 'Proyecto2/Fragmentacion/06_clientes_proveedores_publicos.sql'],
  ['Corporativo', 'Proyecto2/Fragmentacion/07_datos_sensibles_corporativo.sql'],
  ['Corporativo', 'Proyecto2/Fragmentacion/08_verificar_clientes_proveedores.sql'],
  ['San José', 'Proyecto2/Fragmentacion/08_verificar_clientes_proveedores.sql'],
  ['Limón', 'Proyecto2/Fragmentacion/08_verificar_clientes_proveedores.sql'],
  ['Corporativo', 'Proyecto2/Fragmentacion/09_sinonimos_clientes_proveedores.sql'],
  ['San José', 'Proyecto2/Fragmentacion/09_sinonimos_clientes_proveedores.sql'],
  ['Limón', 'Proyecto2/Fragmentacion/09_sinonimos_clientes_proveedores.sql'],
  ['Corporativo', 'Proyecto2/Fragmentacion/10_vendedores_publicos.sql'],
  ['San José', 'Proyecto2/Fragmentacion/10_vendedores_publicos.sql'],
  ['Limón', 'Proyecto2/Fragmentacion/10_vendedores_publicos.sql'],
  ['Corporativo', 'Proyecto2/Fragmentacion/11_verificar_vendedores.sql'],
  ['San José', 'Proyecto2/Fragmentacion/11_verificar_vendedores.sql'],
  ['Limón', 'Proyecto2/Fragmentacion/11_verificar_vendedores.sql'],
  ['San José', 'Proyecto2/Fragmentacion/12_facturas_sucursales.sql'],
  ['Limón', 'Proyecto2/Fragmentacion/12_facturas_sucursales.sql'],
  ['Corporativo', 'Proyecto2/Fragmentacion/13_facturas_corporativo.sql'],
  ['San José', 'Proyecto2/Fragmentacion/14_ordenes_sucursales.sql'],
  ['Limón', 'Proyecto2/Fragmentacion/14_ordenes_sucursales.sql'],
  ['Corporativo', 'Proyecto2/Fragmentacion/15_ordenes_corporativo.sql'],
  ['Corporativo', 'Proyecto2/Fragmentacion/16_inventario_nodos.sql'],
  ['San José', 'Proyecto2/Fragmentacion/16_inventario_nodos.sql'],
  ['Limón', 'Proyecto2/Fragmentacion/16_inventario_nodos.sql'],
  ['Corporativo', 'Proyecto2/Fragmentacion/17_sinonimos_operaciones.sql'],
  ['San José', 'Proyecto2/Fragmentacion/17_sinonimos_operaciones.sql'],
  ['Limón', 'Proyecto2/Fragmentacion/17_sinonimos_operaciones.sql'],

  // 6. Productos: el catálogo se escribe en Corporativo y cada sucursal escribe su inventario
  ['San José', 'Proyecto2/Productos/01_trigger_existencias.sql'],
  ['Limón', 'Proyecto2/Productos/01_trigger_existencias.sql'],
  ['Corporativo', 'Proyecto2/Productos/02_sinonimos.sql'],
  ['San José', 'Proyecto2/Productos/02_sinonimos.sql'],
  ['Limón', 'Proyecto2/Productos/02_sinonimos.sql'],
  ['Corporativo', 'Proyecto2/Productos/03_version_corporativo.sql'],
  ['Corporativo', 'Proyecto2/Productos/04_sp_corporativo.sql'],
  ['San José', 'Proyecto2/Productos/05_sp_sucursal.sql'],
  ['Limón', 'Proyecto2/Productos/05_sp_sucursal.sql'],

  // 7. Carga de clientes, proveedores, facturas y órdenes en los tres nodos (antes de replicar)
  ['Carga', 'cargaDistribuida.js exportar'],
  ['Carga', 'cargaDistribuida.js cargar'],
  ['Carga', 'cargaDistribuida.js verificar'],

  // 8. Operación: SP de consultas, ventas y CRUD. Las verificaciones terminan en ROLLBACK
  ['San José', 'Proyecto2/Sucursales/02_sp_catalogos.sql'],
  ['Limón', 'Proyecto2/Sucursales/02_sp_catalogos.sql'],
  ['San José', 'Proyecto2/Sucursales/03_sp_clientes.sql'],
  ['Limón', 'Proyecto2/Sucursales/03_sp_clientes.sql'],
  ['San José', 'Proyecto2/Sucursales/04_sp_proveedores.sql'],
  ['Limón', 'Proyecto2/Sucursales/04_sp_proveedores.sql'],
  ['San José', 'Proyecto2/Sucursales/06_sp_ventas.sql'],
  ['Limón', 'Proyecto2/Sucursales/06_sp_ventas.sql'],
  ['Corporativo', 'Proyecto2/Corporativo/03_sp_clientes.sql'],
  ['Corporativo', 'Proyecto2/Corporativo/04_sp_proveedores.sql'],
  ['San José', 'Proyecto2/Sucursales/verificar_operacion.sql'],
  ['Limón', 'Proyecto2/Sucursales/verificar_operacion.sql'],
  ['Corporativo', 'Proyecto2/Corporativo/verificar_crud_catalogos.sql'],

  // 9. Estadísticas: vistas materializadas y SP de los reportes en Corporativo
  ['Corporativo', 'Proyecto2/Estadisticas/01_vistas_materializadas.sql'],
  ['Corporativo', 'Proyecto2/Estadisticas/02_sp_estadisticas.sql'],

  // 10. Usuarios del login. Los .local.sql se crean desde las plantillas con las claves del .env
  ['Corporativo', 'Proyecto2/Corporativo/02_usuarios.sql'],
  ['Claves', 'crear los .local.sql de usuarios con las claves del .env'],
  ['Corporativo', 'Proyecto2/Corporativo/03_seguridad_usuarios.local.sql'],
  ['Corporativo', 'Proyecto2/Corporativo/04_usuarios_prueba.local.sql'],
  ['Corporativo', 'Proyecto2/Corporativo/05_verificar_usuarios.sql'],

  // 11. Replicación, al final: sus agentes arrancan solos y no deben coincidir con otros cambios en las bases.
  // Corporativo distribuye; publicaciones sin instantánea porque los datos ya están cargados
  ['Corporativo', 'Proyecto2/Replicacion/01_distribuidor.sql'],
  ['San José', 'Proyecto2/Replicacion/02_publicador_sucursal.sql'],
  ['Limón', 'Proyecto2/Replicacion/02_publicador_sucursal.sql'],
  ['Corporativo', 'Proyecto2/Replicacion/03_llaves_corporativo.sql'],
  ['San José', 'Proyecto2/Replicacion/03_llaves_sucursal.sql'],
  ['Limón', 'Proyecto2/Replicacion/03_llaves_sucursal.sql'],
  ['Corporativo', 'Proyecto2/Replicacion/04_publicacion_catalogo.sql'],
  ['San José', 'Proyecto2/Replicacion/05_publicacion_sanjose.sql'],
  ['Limón', 'Proyecto2/Replicacion/05_publicacion_limon.sql']
];

// Ejecuta un programa mostrando su salida en pantalla; devuelve true si terminó sin error
function correr(programa, argumentos) {
  const resultado = spawnSync(programa, argumentos, { cwd: RAIZ, stdio: 'inherit' });
  return resultado.status === 0;
}

// Ejecuta un archivo .sql con sqlcmd dentro del contenedor del nodo
function ejecutarSql(nombreNodo, archivo, base) {
  const nodo = NODOS[nombreNodo];
  // La clave de sa se lee dentro del contenedor. -I: QUOTED_IDENTIFIER ON (vistas indexadas). -b: se detiene en el primer error
  const sqlcmd = '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -I -b -W'
    + ` -d ${base || nodo.base} -i "/scripts/${archivo}"`;
  return correr('docker', ['exec', nodo.contenedor, 'bash', '-c', sqlcmd]);
}

// Ejecuta un script de carga de esta carpeta; 'que' trae el script y su comando, por ejemplo 'fragmentacion.js cargar'
function ejecutarCarga(que) {
  const [script, comando] = que.split(' ');
  const json = JSON_EXPORTADO[script];
  if (comando === 'exportar' && fs.existsSync(path.join(CARPETA_JSON, json))) {
    console.log(`    Se omite: ya existe ${json}, se usa ese archivo.`);
    return true;
  }
  return correr('node', [path.join(__dirname, script), comando]);
}

// Hash con el formato que revisa el login de la API: scrypt$<sal>$<hash>
function hashScrypt(clave) {
  const sal = crypto.randomBytes(16);
  return 'scrypt$' + sal.toString('hex') + '$' + crypto.scryptSync(clave, sal, 64).toString('hex');
}

// Crea los .local.sql de usuarios: copia cada plantilla y cambia sus marcadores por las claves del .env
function crearArchivosUsuarios() {
  const faltan = ['CLAVE_MAESTRA_USUARIOS', 'CLAVE_ADMIN_SJ', 'CLAVE_ADMIN_LIMON', 'CLAVE_GERENTE']
    .filter((nombre) => !process.env[nombre]);
  if (faltan.length > 0) {
    console.log('    Faltan en el .env: ' + faltan.join(', '));
    return false;
  }

  // Los valores se pasan con () => para que replace no interprete los $ que traen
  const carpeta = path.join(CARPETA_SQL, 'Proyecto2/Corporativo');
  const seguridad = fs.readFileSync(path.join(carpeta, '03_seguridad_usuarios.template.sql'), 'utf8')
    .replace('REEMPLAZAR_CON_CLAVE_SEGURA', () => process.env.CLAVE_MAESTRA_USUARIOS.replaceAll("'", "''"));
  const usuarios = fs.readFileSync(path.join(carpeta, '04_usuarios_prueba.template.sql'), 'utf8')
    .replace('HASH_ADMIN_SJ', () => hashScrypt(process.env.CLAVE_ADMIN_SJ))
    .replace('HASH_ADMIN_LIMON', () => hashScrypt(process.env.CLAVE_ADMIN_LIMON))
    .replace('HASH_GERENTE', () => hashScrypt(process.env.CLAVE_GERENTE));

  fs.writeFileSync(path.join(carpeta, '03_seguridad_usuarios.local.sql'), seguridad);
  fs.writeFileSync(path.join(carpeta, '04_usuarios_prueba.local.sql'), usuarios);
  return true;
}

// Ejecuta un paso según dónde corre; devuelve true si salió bien
function ejecutarPaso(donde, que, base) {
  // Docker: levanta los contenedores si están apagados y espera a que su healthcheck indique healthy
  if (donde === 'Docker') return correr('docker', ['compose', 'up', '-d', '--wait']);
  if (donde === 'Carga') return ejecutarCarga(que);
  if (donde === 'Claves') return crearArchivosUsuarios();
  return ejecutarSql(donde, que, base);
}

// Paso inicial: 1, o el número que se indique al ejecutar
const desde = Number(process.argv[2] || 1);
if (!Number.isInteger(desde) || desde < 1 || desde > PASOS.length) {
  console.log(`El paso debe ser un número entre 1 y ${PASOS.length}.`);
  process.exit(1);
}

for (let i = desde - 1; i < PASOS.length; i++) {
  const [donde, que, base] = PASOS[i];
  console.log(`\n[${i + 1}/${PASOS.length}] ${donde}: ${que}`);
  if (!ejecutarPaso(donde, que, base)) {
    console.log(`\nFalló el paso ${i + 1}. Corrija el error y continúe con: node scripts/instalar.js ${i + 1}`);
    process.exit(1);
  }
  console.log('    OK');
}

console.log('\nInstalación completa.');
