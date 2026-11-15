// Actualización incremental: solo procedimientos, sin restaurar ni recargar datos.
// Desde proyectos/Api: node scripts/actualizarApi.js
const path = require('node:path');
const fs = require('node:fs');
const { spawnSync } = require('node:child_process');
const raiz = path.resolve(__dirname, '../../..');
const docker = spawnSync('docker', ['--version'], { stdio: 'ignore' }).status === 0
  ? 'docker' : 'docker.exe';
const contenedores = spawnSync(docker, ['ps', '--format', '{{.Names}}'], { encoding: 'utf8' });
const nombres = new Set((contenedores.stdout || '').trim().split(/\r?\n/));
const original = nombres.has('sql_wwi') ? 'sql_wwi' : nombres.has('sqlserver_wwi') ? 'sqlserver_wwi' : null;
const pasos = [
  ...(original ? [[original, 'WideWorldImporters', '../08_sp_reportes_6_10.sql']] : []),
  ['wwi_sanjose', 'WideWorldImporters_SanJose', 'Sucursales/06_sp_ventas.sql'],
  ['wwi_limon', 'WideWorldImporters_Limon', 'Sucursales/06_sp_ventas.sql'],
  ['wwi_sanjose', 'WideWorldImporters_SanJose', 'Api/01_sucursales.sql'],
  ['wwi_limon', 'WideWorldImporters_Limon', 'Api/01_sucursales.sql'],
  ['wwi_corporativo', 'WideWorldImporters_Corporativo', 'Api/02_corporativo.sql'],
  ['wwi_corporativo', 'WideWorldImporters_Corporativo', 'Estadisticas/03_sp_reportes_6_10.sql']
];
for (const [contenedor, base, archivo] of pasos) {
  console.log(`${contenedor}: ${archivo}`);
  const sql = fs.readFileSync(path.join(raiz, 'Script sql/Proyecto2', archivo));
  const resultado = spawnSync(docker, ['exec', '-i', contenedor, 'bash', '-c',
    `/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -I -b -d ${base}`
  ], { cwd: raiz, input: sql, stdio: ['pipe', 'inherit', 'inherit'] });
  if (resultado.error) console.error(resultado.error.message);
  if (resultado.status !== 0) process.exit(1);
}
console.log('Procedimientos de la API actualizados. Reinicie la API e ingrese de nuevo en la página.');
