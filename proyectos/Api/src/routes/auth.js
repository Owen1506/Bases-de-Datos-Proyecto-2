
const express = require('express');
const sql = require('mssql');
const crypto = require('node:crypto');
const { conectarCorporativo } = require('../dbCorporativo');

const router = express.Router();

router.post('/login', async (req, res) => {
  const { username, password } = req.body;

  if (typeof username !== 'string' || !username.trim() ||
      typeof password !== 'string' || !password) {
    return res.status(400).json({ mensaje: 'Usuario y contraseña requeridos.' });
  }

  try {
    const pool = await conectarCorporativo();

    const resultado = await pool.request()
      .input('username', sql.VarChar(50), username.trim())
      .query(`
        OPEN SYMMETRIC KEY ClaveUsuarios
        DECRYPTION BY CERTIFICATE CertificadoUsuarios;

        SELECT
          iduser, username, fullname, active, rol, SucursalID,
          CONVERT(NVARCHAR(300), DecryptByKey([password])) AS hashGuardado
        FROM dbo.Usuarios
        WHERE username = @username;

        CLOSE SYMMETRIC KEY ClaveUsuarios;
      `);

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

    return res.json({
      mensaje: 'Inicio de sesión correcto.',
      usuario: {
        iduser: usuario.iduser,
        username: usuario.username,
        fullname: usuario.fullname,
        rol: usuario.rol,
        SucursalID: usuario.SucursalID
      }
    });

  } catch (error) {
    console.error(error);
    return res.status(500).json({ mensaje: 'Error de autenticación.' });
  }
});

module.exports = router;
