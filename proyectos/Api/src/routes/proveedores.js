const express = require('express');
const { ejecutarSP } = require('../db');
const { esEntero, vacio } = require('../validar');

const router = express.Router();

// GET /api/proveedores?nombre=&categoriaId=&pagina=
router.get('/', async (req, res) => {
  // si un filtro no viene se manda null y el SP no lo toma en cuenta
  let nombre = req.query.nombre || null;
  let categoriaId = req.query.categoriaId || null;
  let pagina = req.query.pagina || 1;

  if (!esEntero(pagina) || Number(pagina) < 1) {
    return res.status(400).json({ mensaje: 'La página debe ser un número entero mayor que cero.' });
  }

  if (categoriaId !== null) {
    if (!esEntero(categoriaId)) {
      return res.status(400).json({ mensaje: 'La categoría debe ser un número entero.' });
    }
    categoriaId = Number(categoriaId);
  }

  const filas = await ejecutarSP('dbo.usp_Proveedores_Listar', {
    Nombre: nombre,
    CategoriaID: categoriaId,
    Pagina: Number(pagina)
  });

  res.json(filas);
});

// GET /api/proveedores/5
router.get('/:id', async (req, res) => {
  if (!esEntero(req.params.id)) {
    return res.status(400).json({ mensaje: 'El código del proveedor debe ser un número entero.' });
  }

  const filas = await ejecutarSP('dbo.usp_Proveedores_Detalle', {
    ProveedorID: Number(req.params.id)
  });

  if (filas.length === 0) {
    return res.status(404).json({ mensaje: 'No existe un proveedor con ese código.' });
  }

  res.json(filas[0]);
});

// ---------- Insertar, actualizar y eliminar ----------

// Campos que el formulario siempre debe mandar
const TEXTOS_OBLIGATORIOS = [
  'Nombre', 'Telefono', 'Fax', 'SitioWeb',
  'DireccionEntrega1', 'CodigoPostalEntrega', 'DireccionPostal1', 'CodigoPostalPostal'
];
const IDS_OBLIGATORIOS = [
  'CategoriaID', 'ContactoPrimarioID', 'ContactoAlternativoID', 'CiudadEntregaID', 'CiudadPostalID'
];

// Revisa los datos del formulario. Devuelve el mensaje de error o '' si todo esta bien.
function validarProveedor(p) {
  for (const campo of TEXTOS_OBLIGATORIOS) {
    if (vacio(p[campo]) || String(p[campo]).trim() === '') {
      return 'El campo ' + campo + ' es obligatorio.';
    }
  }

  for (const campo of IDS_OBLIGATORIOS) {
    if (vacio(p[campo]) || !esEntero(p[campo])) {
      return 'El campo ' + campo + ' es obligatorio y debe ser un número entero.';
    }
  }

  if (vacio(p.DiasPago) || !esEntero(p.DiasPago) || Number(p.DiasPago) < 0) {
    return 'Los días de gracia deben ser un número entero mayor o igual a cero.';
  }

  if (!vacio(p.MetodoEntregaID) && !esEntero(p.MetodoEntregaID)) {
    return 'El método de entrega no es válido.';
  }

  // La latitud y longitud son opcionales, pero si viene una debe venir la otra
  if (vacio(p.Latitud) !== vacio(p.Longitud)) {
    return 'Debe indicar la latitud y la longitud, o dejar ambas vacías.';
  }
  if (!vacio(p.Latitud)) {
    const lat = Number(p.Latitud);
    const lon = Number(p.Longitud);
    if (isNaN(lat) || lat < -90 || lat > 90) {
      return 'La latitud debe ser un número entre -90 y 90.';
    }
    if (isNaN(lon) || lon < -180 || lon > 180) {
      return 'La longitud debe ser un número entre -180 y 180.';
    }
  }

  return '';
}

// Devuelve el texto sin espacios a los lados, o null si viene vacio
function textoOpcional(valor) {
  if (vacio(valor) || String(valor).trim() === '') return null;
  return String(valor).trim();
}

// Arma los parametros del SP a partir de los datos del formulario
function parametrosProveedor(p) {
  return {
    Nombre: p.Nombre.trim(),
    CategoriaID: Number(p.CategoriaID),
    ContactoPrimarioID: Number(p.ContactoPrimarioID),
    ContactoAlternativoID: Number(p.ContactoAlternativoID),
    MetodoEntregaID: vacio(p.MetodoEntregaID) ? null : Number(p.MetodoEntregaID),
    CiudadEntregaID: Number(p.CiudadEntregaID),
    CiudadPostalID: Number(p.CiudadPostalID),
    ReferenciaProveedor: textoOpcional(p.ReferenciaProveedor),
    NombreBanco: textoOpcional(p.NombreBanco),
    NumeroCuenta: textoOpcional(p.NumeroCuenta),
    DiasPago: Number(p.DiasPago),
    Telefono: p.Telefono.trim(),
    Fax: p.Fax.trim(),
    SitioWeb: p.SitioWeb.trim(),
    DireccionEntrega1: p.DireccionEntrega1.trim(),
    DireccionEntrega2: textoOpcional(p.DireccionEntrega2),
    CodigoPostalEntrega: p.CodigoPostalEntrega.trim(),
    DireccionPostal1: p.DireccionPostal1.trim(),
    DireccionPostal2: textoOpcional(p.DireccionPostal2),
    CodigoPostalPostal: p.CodigoPostalPostal.trim(),
    Latitud: vacio(p.Latitud) ? null : Number(p.Latitud),
    Longitud: vacio(p.Longitud) ? null : Number(p.Longitud)
  };
}

// POST /api/proveedores  (los datos vienen en el cuerpo de la peticion)
router.post('/', async (req, res) => {
  const error = validarProveedor(req.body);
  if (error !== '') {
    return res.status(400).json({ mensaje: error });
  }

  const filas = await ejecutarSP('dbo.usp_Proveedores_Insertar', parametrosProveedor(req.body));

  res.status(201).json({ ProveedorID: filas[0].ProveedorID, mensaje: 'Proveedor creado correctamente.' });
});

// PUT /api/proveedores/5
router.put('/:id', async (req, res) => {
  if (!esEntero(req.params.id)) {
    return res.status(400).json({ mensaje: 'El código del proveedor debe ser un número entero.' });
  }

  const error = validarProveedor(req.body);
  if (error !== '') {
    return res.status(400).json({ mensaje: error });
  }

  const parametros = parametrosProveedor(req.body);
  parametros.ProveedorID = Number(req.params.id);

  await ejecutarSP('dbo.usp_Proveedores_Actualizar', parametros);

  res.json({ mensaje: 'Proveedor actualizado correctamente.' });
});

// DELETE /api/proveedores/5
router.delete('/:id', async (req, res) => {
  if (!esEntero(req.params.id)) {
    return res.status(400).json({ mensaje: 'El código del proveedor debe ser un número entero.' });
  }

  await ejecutarSP('dbo.usp_Proveedores_Eliminar', { ProveedorID: Number(req.params.id) });

  res.json({ mensaje: 'Proveedor eliminado correctamente.' });
});

module.exports = router;
