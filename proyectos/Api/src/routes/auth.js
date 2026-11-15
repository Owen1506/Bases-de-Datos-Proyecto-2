
const express = require('express');
const sql = require('mssql');
const crypto = require('node:crypto');
const { conectarCorporativo } = require('../dbCorporativo');

const { crearSesion, autenticar, cerrarSesion } = require('../sesion');
const router = express.Router();
router.post('/logout', autenticar, (req, res) => {
  cerrarSesion(req.tokenSesion);
  res.json({ mensaje: 'Sesión cerrada.' });
});

router.post('/login', async (req, res) => {
  const { username, password } = req.body;

  if (typeof username !== 'string' || !username.trim() ||
      typeof password !== 'string' || !password) {
    return res.status(400).json({ mensaje: 'Usuario y contraseña requeridos.' });
  }

  try {
    const pool = await conectarCorporativo('login');

    const resultado = await pool.request()
      .input('username', sql.VarChar(50), username.trim())
      .execute('dbo.usp_Api_Login');

    const usuario = resultado.recordset[0];

    if (!usuario || !usuario.active) {
      return res.status(401).json({ mensaje: 'Credenciales incorrectas.' });
    }

    const partes = usuario.hashGuardado?.split('$');

    if (partes?.length !== 3 || partes[0] !== 'scrypt' ||
        !/^[0-9a-f]{32}$/i.test(partes[1]) ||
        !/^[0-9a-f]{128}$/i.test(partes[2])) {
      throw new Error('Formato de hash inválido.');
    }

    const sal = Buffer.from(partes[1], 'hex');
    const esperado = Buffer.from(partes[2], 'hex');
    const obtenido = crypto.scryptSync(password, sal, esperado.length);

    if (!crypto.timingSafeEqual(esperado, obtenido)) {
      return res.status(401).json({ mensaje: 'Credenciales incorrectas.' });
    }

    const identidad = {
      iduser: usuario.iduser, username: usuario.username, fullname: usuario.fullname,
      rol: usuario.rol, SucursalID: usuario.SucursalID
    };
    if (!['Administrador', 'Corporativo'].includes(identidad.rol) ||
        (identidad.rol === 'Administrador' && ![1, 2].includes(identidad.SucursalID))) {
      return res.status(403).json({ mensaje: 'El usuario no tiene un rol o sucursal válido.' });
    }
    return res.json({ mensaje: 'Inicio de sesión correcto.', usuario: identidad, token: crearSesion(identidad) });

  } catch (error) {
    // Corporativo no responde: mismo aviso 503 que el resto de la API
    if (error instanceof sql.ConnectionError || ['ESOCKET', 'ECONNCLOSED', 'ETIMEOUT'].includes(error.code)) {
      return res.status(503).json({ mensaje: 'El nodo Corporativo no está disponible en este momento. Intente más tarde.' });
    }
    console.error(error);
    return res.status(500).json({ mensaje: 'Error de autenticación.' });
  }
});

module.exports = router;
