const crypto = require('node:crypto');

// Sesiones locales al proceso: al reiniciar la API se requiere ingresar de nuevo.
const sesiones = new Map();
const DURACION = 8 * 60 * 60 * 1000;
function crearSesion(usuario) {
  const ahora = Date.now();
  for (const [token, sesion] of sesiones) {
    if (sesion.vence <= ahora) sesiones.delete(token);
  }
  const token = crypto.randomBytes(32).toString('hex');
  sesiones.set(token, { usuario: { ...usuario }, vence: ahora + DURACION });
  return token;
}
function autenticar(req, res, next) {
  const token = /^Bearer ([a-f0-9]{64})$/.exec(req.get('Authorization') || '')?.[1];
  const sesion = sesiones.get(token);
  if (!sesion || sesion.vence <= Date.now()) {
    sesiones.delete(token);
    return res.status(401).json({ mensaje: 'La sesión no es válida. Ingrese de nuevo.' });
  }
  req.usuario = sesion.usuario;
  req.tokenSesion = token;
  next();
}
function permitirRol(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.usuario.rol)) {
      return res.status(403).json({ mensaje: 'No tiene permiso para esta operación.' });
    }
    if (req.usuario.rol === 'Administrador' && ![1, 2].includes(req.usuario.SucursalID)) {
      return res.status(403).json({ mensaje: 'El usuario no tiene una sucursal válida.' });
    }
    next();
  };
}
function cerrarSesion(token) { sesiones.delete(token); }
module.exports = { crearSesion, autenticar, permitirRol, cerrarSesion };
