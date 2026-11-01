const express = require('express');
const { ejecutarSP } = require('../db');
const { esEntero, vacio } = require('../validar');

const router = express.Router();

// Revisa que una fecha venga como AAAA-MM-DD y sea una fecha real
function fechaValida(texto) {
  return texto.length === 10 && !isNaN(new Date(texto).getTime());
}

// Revisa que un monto sea un numero mayor o igual a cero
function montoValido(texto) {
  return !isNaN(Number(texto)) && Number(texto) >= 0;
}

// GET /api/ventas?cliente=&fechaInicio=&fechaFin=&montoMin=&montoMax=&pagina=
router.get('/', async (req, res) => {
  // si un filtro no viene se manda null y el SP no lo toma en cuenta
  const cliente = req.query.cliente || null;
  const fechaInicio = req.query.fechaInicio || null;
  const fechaFin = req.query.fechaFin || null;
  let montoMin = req.query.montoMin || null;
  let montoMax = req.query.montoMax || null;
  const pagina = req.query.pagina || 1;

  if (!esEntero(pagina) || Number(pagina) < 1) {
    return res.status(400).json({ mensaje: 'La página debe ser un número entero mayor que cero.' });
  }

  if (fechaInicio !== null && !fechaValida(fechaInicio)) {
    return res.status(400).json({ mensaje: 'La fecha inicial no es válida.' });
  }
  if (fechaFin !== null && !fechaValida(fechaFin)) {
    return res.status(400).json({ mensaje: 'La fecha final no es válida.' });
  }

  if (montoMin !== null) {
    if (!montoValido(montoMin)) {
      return res.status(400).json({ mensaje: 'El monto mínimo debe ser un número mayor o igual a cero.' });
    }
    montoMin = Number(montoMin);
  }
  if (montoMax !== null) {
    if (!montoValido(montoMax)) {
      return res.status(400).json({ mensaje: 'El monto máximo debe ser un número mayor o igual a cero.' });
    }
    montoMax = Number(montoMax);
  }

  // los rangos (fecha inicial <= final, monto minimo <= maximo) los revisa el SP
  const filas = await ejecutarSP('dbo.usp_Ventas_Listar', {
    NombreCliente: cliente,
    FechaInicio: fechaInicio,
    FechaFin: fechaFin,
    MontoMin: montoMin,
    MontoMax: montoMax,
    Pagina: Number(pagina)
  });

  res.json(filas);
});

// GET /api/ventas/5  (devuelve el encabezado y las lineas de la factura)
router.get('/:id', async (req, res) => {
  if (!esEntero(req.params.id)) {
    return res.status(400).json({ mensaje: 'El número de factura debe ser un número entero.' });
  }

  const encabezado = await ejecutarSP('dbo.usp_Ventas_Detalle', { FacturaID: Number(req.params.id) });

  if (encabezado.length === 0) {
    return res.status(404).json({ mensaje: 'No existe una factura con ese número.' });
  }

  const lineas = await ejecutarSP('dbo.usp_Ventas_DetalleLineas', { FacturaID: Number(req.params.id) });

  res.json({ encabezado: encabezado[0], lineas: lineas });
});

// ---------- Insertar, actualizar y eliminar ----------

// Revisa los datos del formulario. Devuelve el mensaje de error o '' si todo esta bien.
// Los impuestos y totales no se revisan aqui: los calcula el SP al guardar.
function validarVenta(v) {
  if (vacio(v.ClienteID) || !esEntero(v.ClienteID)) return 'Debe elegir un cliente.';
  if (vacio(v.ContactoID) || !esEntero(v.ContactoID)) return 'Debe elegir la persona de contacto.';
  if (vacio(v.MetodoEntregaID) || !esEntero(v.MetodoEntregaID)) return 'Debe elegir el método de entrega.';
  if (vacio(v.VendedorID) || !esEntero(v.VendedorID)) return 'Debe elegir el vendedor.';
  if (vacio(v.Fecha) || !fechaValida(String(v.Fecha))) return 'La fecha de la factura no es válida.';

  // las lineas llegan como lista: [{ ProductoID, Cantidad, PrecioUnitario }, ...]
  if (!Array.isArray(v.Lineas) || v.Lineas.length === 0) return 'La factura debe tener al menos un producto.';
  for (const linea of v.Lineas) {
    if (vacio(linea.ProductoID) || !esEntero(linea.ProductoID)) return 'Cada línea debe tener un producto.';
    if (!esEntero(linea.Cantidad) || Number(linea.Cantidad) < 1) return 'La cantidad de cada línea debe ser un número entero mayor que cero.';
    if (!montoValido(linea.PrecioUnitario)) return 'El precio de cada línea debe ser un número mayor o igual a cero.';
  }

  return '';
}

// Devuelve el texto sin espacios a los lados, o null si viene vacio
function textoOpcional(valor) {
  if (vacio(valor) || String(valor).trim() === '') return null;
  return String(valor).trim();
}

// Arma los parametros del SP a partir de los datos del formulario
function parametrosVenta(v) {
  // el SP recibe las lineas como texto JSON
  const lineas = [];
  for (const linea of v.Lineas) {
    lineas.push({
      ProductoID: Number(linea.ProductoID),
      Cantidad: Number(linea.Cantidad),
      PrecioUnitario: Number(linea.PrecioUnitario)
    });
  }

  return {
    ClienteID: Number(v.ClienteID),
    MetodoEntregaID: Number(v.MetodoEntregaID),
    ContactoID: Number(v.ContactoID),
    VendedorID: Number(v.VendedorID),
    Fecha: v.Fecha,
    NumeroOrdenCliente: textoOpcional(v.NumeroOrdenCliente),
    InstruccionesEntrega: textoOpcional(v.InstruccionesEntrega),
    Detalles: JSON.stringify(lineas)
  };
}

// POST /api/ventas  (los datos vienen en el cuerpo de la peticion)
router.post('/', async (req, res) => {
  const error = validarVenta(req.body);
  if (error !== '') {
    return res.status(400).json({ mensaje: error });
  }

  const filas = await ejecutarSP('dbo.usp_Ventas_Insertar', parametrosVenta(req.body));

  res.status(201).json({ FacturaID: filas[0].FacturaID, mensaje: 'Factura #' + filas[0].FacturaID + ' creada correctamente.' });
});

// PUT /api/ventas/5
router.put('/:id', async (req, res) => {
  if (!esEntero(req.params.id)) {
    return res.status(400).json({ mensaje: 'El número de factura debe ser un número entero.' });
  }

  const error = validarVenta(req.body);
  if (error !== '') {
    return res.status(400).json({ mensaje: error });
  }

  const parametros = parametrosVenta(req.body);
  parametros.FacturaID = Number(req.params.id);

  await ejecutarSP('dbo.usp_Ventas_Actualizar', parametros);

  res.json({ mensaje: 'Factura actualizada correctamente.' });
});

// DELETE /api/ventas/5
router.delete('/:id', async (req, res) => {
  if (!esEntero(req.params.id)) {
    return res.status(400).json({ mensaje: 'El número de factura debe ser un número entero.' });
  }

  await ejecutarSP('dbo.usp_Ventas_Eliminar', { FacturaID: Number(req.params.id) });

  res.json({ mensaje: 'Factura eliminada correctamente.' });
});

module.exports = router;
