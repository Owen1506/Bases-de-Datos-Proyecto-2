const express = require('express');
const { ejecutarSPReporte } = require('../dbNodos');

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

  const filas = await ejecutarSPReporte('dbo.usp_Reporte_ComprasProveedores', {
    SucursalID: sucursalId(req),
    Categoria: categoria?.trim() || null,
    NombreProveedor: nombreProveedor?.trim() || null,
    Pagina: Number(pagina || 1)
  });

  res.json(filas);
});

router.get('/anios-facturas', async (req, res) => {
  res.json(await ejecutarSPReporte('dbo.usp_Reporte_AniosFacturas', { SucursalID: sucursalId(req) }));
});

router.get('/anios-ordenes-compra', async (req, res) => {
  res.json(await ejecutarSPReporte('dbo.usp_Reporte_AniosOrdenesCompra', { SucursalID: sucursalId(req) }));
});

router.get('/ventas-clientes', async (req, res) => {
  const { nombreCliente, categoria, pagina } = req.query;
  if (![nombreCliente, categoria].every(textoValido)) {
    return res.status(400).json({ mensaje: 'Los filtros deben ser texto de hasta 100 caracteres.' });
  }
  if (!paginaValida(pagina)) {
    return res.status(400).json({ mensaje: 'La página debe ser un número entero mayor que cero.' });
  }

  res.json(await ejecutarSPReporte('dbo.usp_Reporte_VentasClientes', {
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

  res.json(await ejecutarSPReporte('dbo.usp_Reporte_TopProductosGanancia', {
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

  res.json(await ejecutarSPReporte('dbo.usp_Reporte_TopClientesFacturas', {
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

  res.json(await ejecutarSPReporte('dbo.usp_Reporte_TopProveedoresOrdenes', {
    SucursalID: sucursalId(req),
    AnioInicio: anioInicio === undefined ? null : Number(anioInicio),
    AnioFin: anioFin === undefined ? null : Number(anioFin),
    Pagina: Number(pagina || 1)
  }));
});

const TIPOS_FILTRO = new Set(['grupos', 'productos', 'proveedores', 'categoriasCliente', 'aniosVentas', 'aniosCompras']);
function idOpcional(valor) {
  return valor === undefined || (typeof valor === 'string' && /^[1-9]\d*$/.test(valor) && Number.isSafeInteger(Number(valor)));
}
function parametrosNuevos(req, { compras = false, grupo = false, producto = false, proveedor = false, categoriaCliente = false } = {}) {
  const q = req.query;
  if (!paginaValida(q.pagina) || !anioValido(q.anio) || !idOpcional(q.mes) ||
      (q.mes !== undefined && Number(q.mes) > 12) ||
      (grupo && !idOpcional(q.grupoId)) ||
      (producto && !idOpcional(q.productoId)) ||
      (proveedor && !idOpcional(q.proveedorId)) ||
      (categoriaCliente && !idOpcional(q.categoriaClienteId))) {
    return null;
  }
  return {
    SucursalID: sucursalId(req),
    Anio: q.anio === undefined ? null : Number(q.anio),
    Mes: q.mes === undefined ? null : Number(q.mes),
    GrupoID: grupo ? (q.grupoId === undefined ? null : Number(q.grupoId)) : undefined,
    ProductoID: producto ? (q.productoId === undefined ? null : Number(q.productoId)) : undefined,
    ProveedorID: proveedor ? (q.proveedorId === undefined ? null : Number(q.proveedorId)) : undefined,
    CategoriaClienteID: categoriaCliente ? (q.categoriaClienteId === undefined ? null : Number(q.categoriaClienteId)) : undefined,
    Pagina: Number(q.pagina || 1)
  };
}
function sinIndefinidos(objeto) {
  return Object.fromEntries(Object.entries(objeto).filter(([, valor]) => valor !== undefined));
}

router.get('/filtros', async (req, res) => {
  if (!TIPOS_FILTRO.has(req.query.tipo)) {
    return res.status(400).json({ mensaje: 'Seleccione un catálogo de filtros válido.' });
  }
  res.json(await ejecutarSPReporte('dbo.usp_Reporte_Filtros', { Tipo: req.query.tipo }));
});

router.get('/matriz-ventas-categoria', async (req, res) => {
  if (!paginaValida(req.query.pagina)) return res.status(400).json({ mensaje: 'La página no es válida.' });
  res.json(await ejecutarSPReporte('dbo.usp_Reporte_MatrizVentasCategoria', {
    SucursalID: sucursalId(req), Pagina: Number(req.query.pagina || 1)
  }));
});

router.get('/seguimiento-clientes', async (req, res) => {
  const p = parametrosNuevos(req, { grupo: true, producto: true });
  if (!p) return res.status(400).json({ mensaje: 'Revise los filtros de año, mes, grupo, producto y página.' });
  res.json(await ejecutarSPReporte('dbo.usp_Reporte_SeguimientoClientes', sinIndefinidos(p)));
});

router.get('/seguimiento-proveedores', async (req, res) => {
  const p = parametrosNuevos(req, { compras: true, grupo: true, producto: true });
  if (!p) return res.status(400).json({ mensaje: 'Revise los filtros de año, mes, grupo, producto y página.' });
  res.json(await ejecutarSPReporte('dbo.usp_Reporte_SeguimientoProveedores', sinIndefinidos(p)));
});

router.get('/rotacion-inventario', async (req, res) => {
  const p = parametrosNuevos(req, { grupo: true, proveedor: true });
  if (!p) return res.status(400).json({ mensaje: 'Revise los filtros de año, grupo, proveedor y página.' });
  delete p.Mes;
  res.json(await ejecutarSPReporte('dbo.usp_Reporte_RotacionInventario', sinIndefinidos(p)));
});

router.get('/metodos-envio-destino', async (req, res) => {
  const p = parametrosNuevos(req, { grupo: true, producto: true, categoriaCliente: true });
  if (!p) return res.status(400).json({ mensaje: 'Revise los filtros de año, mes, categorías, producto y página.' });
  res.json(await ejecutarSPReporte('dbo.usp_Reporte_MetodosEnvioDestino', sinIndefinidos(p)));
});

module.exports = router;
