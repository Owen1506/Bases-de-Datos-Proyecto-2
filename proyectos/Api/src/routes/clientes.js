const express = require('express');
const { ejecutarSP } = require('../db');
const { esEntero, vacio } = require('../validar');

const router = express.Router();

// GET /api/clientes?nombre=&categoriaId=&metodoEntregaId=&pagina=
router.get('/', async (req, res) => {
  // si un filtro no viene se manda null y el SP no lo toma en cuenta
  let nombre = req.query.nombre || null;
  let categoriaId = req.query.categoriaId || null;
  let metodoEntregaId = req.query.metodoEntregaId || null;
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

  if (metodoEntregaId !== null) {
    if (!esEntero(metodoEntregaId)) {
      return res.status(400).json({ mensaje: 'El método de entrega debe ser un número entero.' });
    }
    metodoEntregaId = Number(metodoEntregaId);
  }

  const filas = await ejecutarSP('dbo.usp_Clientes_Listar', {
    Nombre: nombre,
    CategoriaID: categoriaId,
    MetodoEntregaID: metodoEntregaId,
    Pagina: Number(pagina)
  });

  res.json(filas);
});

// GET /api/clientes/5
router.get('/:id', async (req, res) => {
  if (!esEntero(req.params.id)) {
    return res.status(400).json({ mensaje: 'El código del cliente debe ser un número entero.' });
  }

  const filas = await ejecutarSP('dbo.usp_Clientes_Detalle', {
    ClienteID: Number(req.params.id)
  });

  if (filas.length === 0) {
    return res.status(404).json({ mensaje: 'No existe un cliente con ese código.' });
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
  'CategoriaID', 'MetodoEntregaID', 'CiudadEntregaID', 'CiudadPostalID'
];

// Revisa los datos del formulario. Devuelve el mensaje de error o '' si todo esta bien.
function validarCliente(c) {
  for (const campo of TEXTOS_OBLIGATORIOS) {
    if (vacio(c[campo]) || String(c[campo]).trim() === '') {
      return 'El campo ' + campo + ' es obligatorio.';
    }
  }

  for (const campo of IDS_OBLIGATORIOS) {
    if (vacio(c[campo]) || !esEntero(c[campo])) {
      return 'El campo ' + campo + ' es obligatorio y debe ser un número entero.';
    }
  }

  if (vacio(c.DiasPago) || !esEntero(c.DiasPago) || Number(c.DiasPago) < 0) {
    return 'Los días de gracia deben ser un número entero mayor o igual a cero.';
  }

  if (!vacio(c.GrupoCompraID) && !esEntero(c.GrupoCompraID)) {
    return 'El grupo de compra no es válido.';
  }

  // opcional: si viene vacio el cliente se factura a si mismo (lo resuelve el SP)
  if (!vacio(c.ClienteFacturarID) && !esEntero(c.ClienteFacturarID)) {
    return 'El cliente por facturar no es válido.';
  }

  // opcional: si viene vacio, el SP crea al cliente como su propio contacto (o conserva el actual al editar)
  if (!vacio(c.ContactoPrimarioID) && !esEntero(c.ContactoPrimarioID)) {
    return 'El contacto primario no es válido.';
  }

  if (!vacio(c.ContactoAlternativoID) && !esEntero(c.ContactoAlternativoID)) {
    return 'El contacto alternativo no es válido.';
  }

  // La latitud y longitud son opcionales, pero si viene una debe venir la otra
  if (vacio(c.Latitud) !== vacio(c.Longitud)) {
    return 'Debe indicar la latitud y la longitud, o dejar ambas vacías.';
  }
  if (!vacio(c.Latitud)) {
    const lat = Number(c.Latitud);
    const lon = Number(c.Longitud);
    if (isNaN(lat) || lat < -90 || lat > 90) {
      return 'La latitud debe ser un número entre -90 y 90.';
    }
    if (isNaN(lon) || lon < -180 || lon > 180) {
      return 'La longitud debe ser un número entre -180 y 180.';
    }
  }

  return '';
}

// Arma los parametros del SP a partir de los datos del formulario.
// Los campos opcionales vacios se mandan como null.
function parametrosCliente(c) {
  return {
    Nombre: c.Nombre.trim(),
    ClienteFacturarID: vacio(c.ClienteFacturarID) ? null : Number(c.ClienteFacturarID),
    CategoriaID: Number(c.CategoriaID),
    GrupoCompraID: vacio(c.GrupoCompraID) ? null : Number(c.GrupoCompraID),
    ContactoPrimarioID: vacio(c.ContactoPrimarioID) ? null : Number(c.ContactoPrimarioID),
    ContactoAlternativoID: vacio(c.ContactoAlternativoID) ? null : Number(c.ContactoAlternativoID),
    MetodoEntregaID: Number(c.MetodoEntregaID),
    CiudadEntregaID: Number(c.CiudadEntregaID),
    CiudadPostalID: Number(c.CiudadPostalID),
    DiasPago: Number(c.DiasPago),
    Telefono: c.Telefono.trim(),
    Fax: c.Fax.trim(),
    SitioWeb: c.SitioWeb.trim(),
    DireccionEntrega1: c.DireccionEntrega1.trim(),
    DireccionEntrega2: vacio(c.DireccionEntrega2) ? null : c.DireccionEntrega2.trim(),
    CodigoPostalEntrega: c.CodigoPostalEntrega.trim(),
    DireccionPostal1: c.DireccionPostal1.trim(),
    DireccionPostal2: vacio(c.DireccionPostal2) ? null : c.DireccionPostal2.trim(),
    CodigoPostalPostal: c.CodigoPostalPostal.trim(),
    Latitud: vacio(c.Latitud) ? null : Number(c.Latitud),
    Longitud: vacio(c.Longitud) ? null : Number(c.Longitud)
  };
}

// POST /api/clientes  (los datos vienen en el cuerpo de la peticion)
router.post('/', async (req, res) => {
  const error = validarCliente(req.body);
  if (error !== '') {
    return res.status(400).json({ mensaje: error });
  }

  const filas = await ejecutarSP('dbo.usp_Clientes_Insertar', parametrosCliente(req.body));

  res.status(201).json({ ClienteID: filas[0].ClienteID, mensaje: 'Cliente creado correctamente.' });
});

// PUT /api/clientes/5
router.put('/:id', async (req, res) => {
  if (!esEntero(req.params.id)) {
    return res.status(400).json({ mensaje: 'El código del cliente debe ser un número entero.' });
  }

  const error = validarCliente(req.body);
  if (error !== '') {
    return res.status(400).json({ mensaje: error });
  }

  const parametros = parametrosCliente(req.body);
  parametros.ClienteID = Number(req.params.id);

  await ejecutarSP('dbo.usp_Clientes_Actualizar', parametros);

  res.json({ mensaje: 'Cliente actualizado correctamente.' });
});

// DELETE /api/clientes/5
router.delete('/:id', async (req, res) => {
  if (!esEntero(req.params.id)) {
    return res.status(400).json({ mensaje: 'El código del cliente debe ser un número entero.' });
  }

  await ejecutarSP('dbo.usp_Clientes_Eliminar', { ClienteID: Number(req.params.id) });

  res.json({ mensaje: 'Cliente eliminado correctamente.' });
});

module.exports = router;
