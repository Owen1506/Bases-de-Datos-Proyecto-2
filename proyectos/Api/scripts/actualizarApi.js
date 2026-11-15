// Actualización incremental: solo procedimientos, sin restaurar ni recargar datos.
// Desde proyectos/Api: node scripts/actualizarApi.js
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const raiz = path.resolve(__dirname, '../../..');
const pasos = [
  ['wwi_sanjose', 'WideWorldImporters_SanJose', 'Sucursales/06_sp_ventas.sql'],
  ['wwi_limon', 'WideWorldImporters_Limon', 'Sucursales/06_sp_ventas.sql'],
  ['wwi_sanjose', 'WideWorldImporters_SanJose', 'Api/01_sucursales.sql'],
  ['wwi_limon', 'WideWorldImporters_Limon', 'Api/01_sucursales.sql'],
  ['wwi_corporativo', 'WideWorldImporters_Corporativo', 'Api/02_corporativo.sql']
];
for (const [contenedor, base, archivo] of pasos) {
  console.log(`${contenedor}: ${archivo}`);
  const resultado = spawnSync('docker', ['exec', contenedor, 'bash', '-c',
    `/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -I -b -d ${base} -i "/scripts/Proyecto2/${archivo}"`
  ], { cwd: raiz, stdio: 'inherit' });
  if (resultado.error) console.error(resultado.error.message);
  if (resultado.status !== 0) process.exit(1);
}
console.log('Procedimientos de la API actualizados. Reinicie la API e ingrese de nuevo en la página.');
