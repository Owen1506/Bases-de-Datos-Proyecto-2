// Genera SQL local con secretos del .env y aplica cuentas SQL a bases ya instaladas.
// Uso: node scripts/configurarSeguridad.js (desde proyectos/Api).
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const docker = spawnSync('docker', ['--version'], { stdio: 'ignore' }).status === 0
  ? 'docker' : 'docker.exe';

const raiz = path.resolve(__dirname, '../../..');
require('dotenv').config({ path: path.join(raiz, '.env'), quiet: true });
const sqlRaiz = path.join(raiz, 'Script sql/Proyecto2');
const secretos = {
  CLAVE_API_LOGIN: process.env.API_LOGIN_PASSWORD,
  CLAVE_API_ADMIN: process.env.API_ADMIN_PASSWORD,
  CLAVE_API_CORPORATIVO: process.env.API_CORPORATIVO_PASSWORD,
  CLAVE_API_SUCURSAL: process.env.API_SUCURSAL_PASSWORD
};

function generar() {
  for (const [nombre, valor] of Object.entries(secretos)) {
    if (!valor || valor.length < 12 || valor.length > 128 || /[\r\n]/.test(valor)) {
      throw new Error(`${nombre} debe tener entre 12 y 128 caracteres y no contener saltos de línea.`);
    }
  }
  const valores = Object.values(secretos);
  const clavesSa = ['MSSQL_SA_PASSWORD', 'MSSQL_CORPORATIVO_PASSWORD',
    'MSSQL_SANJOSE_PASSWORD', 'MSSQL_LIMON_PASSWORD'].map(nombre => process.env[nombre]);
  if (new Set(valores).size !== valores.length || valores.some(valor => clavesSa.includes(valor))) {
    throw new Error('Las claves SQL de la API deben ser distintas entre sí y de las claves de sa.');
  }
  for (const [origen, destino] of [
    ['Corporativo/07_cuentas_api.template.sql', 'Corporativo/07_cuentas_api.local.sql'],
    ['Sucursales/07_cuenta_api.template.sql', 'Sucursales/07_cuenta_api.local.sql']
  ]) {
    let sql = fs.readFileSync(path.join(sqlRaiz, origen), 'utf8');
    for (const [marcador, valor] of Object.entries(secretos)) {
      sql = sql.replaceAll(marcador, valor.replaceAll("'", "''"));
    }
    // Sin permisos restringidos: el usuario mssql del contenedor debe poder leer el archivo (está en .gitignore)
    fs.writeFileSync(path.join(sqlRaiz, destino), sql);
  }
}

function aplicar() {
  generar();
  const pasos = [
    ['wwi_corporativo', 'WideWorldImporters_Corporativo', 'Corporativo/06_login_api.sql'],
    ['wwi_corporativo', 'WideWorldImporters_Corporativo', 'Corporativo/07_cuentas_api.local.sql'],
    ['wwi_sanjose', 'WideWorldImporters_SanJose', 'Sucursales/07_cuenta_api.local.sql'],
    ['wwi_limon', 'WideWorldImporters_Limon', 'Sucursales/07_cuenta_api.local.sql'],
    ['wwi_corporativo', 'WideWorldImporters_Corporativo', 'Corporativo/08_verificar_cuentas_api.sql'],
    ['wwi_sanjose', 'WideWorldImporters_SanJose', 'Sucursales/08_verificar_cuenta_api.sql'],
    ['wwi_limon', 'WideWorldImporters_Limon', 'Sucursales/08_verificar_cuenta_api.sql']
  ];
  for (const [contenedor, base, archivo] of pasos) {
    console.log(`${contenedor}: ${archivo}`);
    const comando = '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -I -b -d '
      + base;
    const sql = fs.readFileSync(path.join(sqlRaiz, archivo));
    const resultado = spawnSync(docker, ['exec', '-i', contenedor, 'bash', '-c', comando],
      { cwd: raiz, input: sql, stdio: ['pipe', 'inherit', 'inherit'] });
    if (resultado.error || resultado.status !== 0) {
      throw new Error(`Falló ${archivo}: ${resultado.error?.message || `salida ${resultado.status}`}`);
    }
  }
  console.log('Cuentas SQL de la API configuradas. Reinicie la API.');
}

if (require.main === module) {
  try { aplicar(); } catch (error) { console.error(error.message); process.exitCode = 1; }
}
module.exports = { generar, aplicar };
