const express = require('express');
const { ejecutarSPCorporativo } = require('../dbNodos');

// Las estadísticas se leen de las vistas materializadas de Corporativo
const router = express.Router();

// Filtro de todos los reportes: vacío = consolidado, 1 = San José, 2 = Limón
router.use((req, res, next) => {
  const { sucursal } = req.query;
  if (sucursal !== undefined && !['', '1', '2'].includes(sucursal)) {
    return res.status(400).json({ mensaje: 'Seleccione una sucursal válida.' });
  }
  next();
});

function sucursalId(req) {
  return req.query.sucursal ? Number(req.query.sucursal) : null;
}

function textoValido(valor) {
  return valor === undefined || (typeof valor === 'string' && valor.length <= 100);
}

function anioValido(valor) {
  return valor === undefined || (typeof valor === 'string' && /^\d{4}$/.test(valor));
}

function paginaValida(valor) {
  return valor === undefined || (
    typeof valor === 'string' && /^\d+$/.test(valor) &&
    Number(valor) >= 1 && Number(valor) <= 1000000
  );
}

// GET /api/estadisticas/compras-proveedores?categoria=&nombreProveedor=
router.get('/compras-proveedores', async (req, res) => {
  const { categoria, nombreProveedor, pagina } = req.query;

  if (![categoria, nombreProveedor].every(textoValido)) {
    return res.status(400).json({ mensaje: 'Los filtros deben ser texto de hasta 100 caracteres.' });
  }
  if (!paginaValida(pagina)) {
    return res.status(400).json({ mensaje: 'La página debe ser un número entero mayor que cero.' });
  }

  const filas = await ejecutarSPCorporativo('dbo.usp_Reporte_ComprasProveedores', {
    SucursalID: sucursalId(req),
    Categoria: categoria?.trim() || null,
    NombreProveedor: nombreProveedor?.trim() || null,
    Pagina: Number(pagina || 1)
  });

  res.json(filas);
});

router.get('/anios-facturas', async (req, res) => {
  res.json(await ejecutarSPCorporativo('dbo.usp_Reporte_AniosFacturas', { SucursalID: sucursalId(req) }));
});

router.get('/anios-ordenes-compra', async (req, res) => {
  res.json(await ejecutarSPCorporativo('dbo.usp_Reporte_AniosOrdenesCompra', { SucursalID: sucursalId(req) }));
});

router.get('/ventas-clientes', async (req, res) => {
  const { nombreCliente, categoria, pagina } = req.query;
  if (![nombreCliente, categoria].every(textoValido)) {
    return res.status(400).json({ mensaje: 'Los filtros deben ser texto de hasta 100 caracteres.' });
  }
  if (!paginaValida(pagina)) {
    return res.status(400).json({ mensaje: 'La página debe ser un número entero mayor que cero.' });
  }

  res.json(await ejecutarSPCorporativo('dbo.usp_Reporte_VentasClientes', {
    SucursalID: sucursalId(req),
    NombreCliente: nombreCliente?.trim() || null,
    Categoria: categoria?.trim() || null,
    Pagina: Number(pagina || 1)
  }));
});

router.get('/top-productos-ganancia', async (req, res) => {
  const { anio, pagina } = req.query;
  if (!anioValido(anio)) {
    return res.status(400).json({ mensaje: 'Seleccione un año válido.' });
  }
  if (!paginaValida(pagina)) {
    return res.status(400).json({ mensaje: 'La página debe ser un número entero mayor que cero.' });
  }

  res.json(await ejecutarSPCorporativo('dbo.usp_Reporte_TopProductosGanancia', {
    SucursalID: sucursalId(req),
    Anio: anio === undefined ? null : Number(anio),
    Pagina: Number(pagina || 1)
  }));
});

router.get('/top-clientes-facturas', async (req, res) => {
  const { anioInicio, anioFin, pagina } = req.query;
  if (![anioInicio, anioFin].every(anioValido)) {
    return res.status(400).json({ mensaje: 'Seleccione años válidos para el rango.' });
  }
  if (!paginaValida(pagina)) {
    return res.status(400).json({ mensaje: 'La página debe ser un número entero mayor que cero.' });
  }
  if (anioInicio && anioFin && Number(anioInicio) > Number(anioFin)) {
    return res.status(400).json({ mensaje: 'El año inicial debe ser menor o igual que el año final.' });
  }

  res.json(await ejecutarSPCorporativo('dbo.usp_Reporte_TopClientesFacturas', {
    SucursalID: sucursalId(req),
    AnioInicio: anioInicio === undefined ? null : Number(anioInicio),
    AnioFin: anioFin === undefined ? null : Number(anioFin),
    Pagina: Number(pagina || 1)
  }));
});

router.get('/top-proveedores-ordenes', async (req, res) => {
  const { anioInicio, anioFin, pagina } = req.query;
  if (![anioInicio, anioFin].every(anioValido)) {
    return res.status(400).json({ mensaje: 'Seleccione años válidos para el rango.' });
  }
  if (!paginaValida(pagina)) {
    return res.status(400).json({ mensaje: 'La página debe ser un número entero mayor que cero.' });
  }
  if (anioInicio && anioFin && Number(anioInicio) > Number(anioFin)) {
    return res.status(400).json({ mensaje: 'El año inicial debe ser menor o igual que el año final.' });
  }

  res.json(await ejecutarSPCorporativo('dbo.usp_Reporte_TopProveedoresOrdenes', {
    SucursalID: sucursalId(req),
    AnioInicio: anioInicio === undefined ? null : Number(anioInicio),
    AnioFin: anioFin === undefined ? null : Number(anioFin),
    Pagina: Number(pagina || 1)
  }));
});

module.exports = router;
