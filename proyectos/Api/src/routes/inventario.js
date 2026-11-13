const express = require('express');
const { ejecutarSPCorporativo, ejecutarSPSucursal } = require('../dbNodos');
const { esEntero, vacio } = require('../validar');

const router = express.Router();

// El catálogo se escribe en Corporativo. La lista, el detalle y las existencias
// son de la sucursal del usuario, que la web manda en el encabezado X-Sucursal.

// GET /api/inventario?nombre=&grupoId=&cantidadMin=&cantidadMax=&pagina=
router.get('/', async (req, res) => {
  // si un filtro no viene se manda null y el SP no lo toma en cuenta
  let nombre = req.query.nombre || null;
  let grupoId = req.query.grupoId || null;
  let cantidadMin = req.query.cantidadMin || null;
  let cantidadMax = req.query.cantidadMax || null;
  let pagina = req.query.pagina || 1;

  if (cantidadMin !== null) {
    if (!esEntero(cantidadMin) || Number(cantidadMin) < 0) {
      return res.status(400).json({ mensaje: 'La cantidad mínima debe ser un número entero mayor o igual a cero.' });
    }
    cantidadMin = Number(cantidadMin);
  }
  if (cantidadMax !== null) {
    if (!esEntero(cantidadMax) || Number(cantidadMax) < 0) {
      return res.status(400).json({ mensaje: 'La cantidad máxima debe ser un número entero mayor o igual a cero.' });
    }
    cantidadMax = Number(cantidadMax);
  }

  if (!esEntero(pagina) || Number(pagina) < 1) {
    return res.status(400).json({ mensaje: 'La página debe ser un número entero mayor que cero.' });
  }

  if (grupoId !== null) {
    if (!esEntero(grupoId)) {
      return res.status(400).json({ mensaje: 'El grupo debe ser un número entero.' });
    }
    grupoId = Number(grupoId);
  }

  const filas = await ejecutarSPSucursal(req.get('X-Sucursal'), 'dbo.usp_Productos_Listar', {
    Nombre: nombre,
    GrupoID: grupoId,
    CantidadMin: cantidadMin,
    CantidadMax: cantidadMax,
    Pagina: Number(pagina)
  });

  res.json(filas);
});

// GET /api/inventario/5
router.get('/:id', async (req, res) => {
  if (!esEntero(req.params.id)) {
    return res.status(400).json({ mensaje: 'El código del producto debe ser un número entero.' });
  }

  const filas = await ejecutarSPSucursal(req.get('X-Sucursal'), 'dbo.usp_Productos_Detalle', {
    ProductoID: Number(req.params.id)
  });

  if (filas.length === 0) {
    return res.status(404).json({ mensaje: 'No existe un producto con ese código.' });
  }

  res.json(filas[0]);
});

// GET /api/inventario/5/editar  (datos del formulario con la versión, desde Corporativo)
router.get('/:id/editar', async (req, res) => {
  if (!esEntero(req.params.id)) {
    return res.status(400).json({ mensaje: 'El código del producto debe ser un número entero.' });
  }

  const filas = await ejecutarSPCorporativo('dbo.usp_Productos_Detalle', {
    ProductoID: Number(req.params.id)
  });

  if (filas.length === 0) {
    return res.status(404).json({ mensaje: 'No existe un producto con ese código.' });
  }

  res.json(filas[0]);
});

// ---------- Insertar, actualizar y eliminar ----------

// Revisa que un valor sea un numero (entero o con decimales) mayor o igual al minimo
function numeroValido(valor, minimo) {
  if (vacio(valor) || isNaN(Number(valor))) return false;
  return Number(valor) >= minimo;
}

// Revisa los datos del formulario. Devuelve el mensaje de error o '' si todo esta bien.
function validarProducto(p) {
  if (vacio(p.Nombre) || String(p.Nombre).trim() === '') return 'El nombre es obligatorio.';

  if (vacio(p.ProveedorID) || !esEntero(p.ProveedorID)) return 'Debe elegir un proveedor.';
  if (vacio(p.UnidadEmpaqueID) || !esEntero(p.UnidadEmpaqueID)) return 'Debe elegir la unidad de empaquetamiento.';
  if (vacio(p.EmpaqueExteriorID) || !esEntero(p.EmpaqueExteriorID)) return 'Debe elegir el empaquetamiento.';
  if (!vacio(p.ColorID) && !esEntero(p.ColorID)) return 'El color no es válido.';

  // los grupos llegan como una lista de IDs, por ejemplo [2, 4, 6]
  if (!Array.isArray(p.Grupos) || p.Grupos.length === 0) return 'Debe elegir al menos un grupo.';
  for (const grupo of p.Grupos) {
    if (!esEntero(grupo)) return 'Uno de los grupos no es válido.';
  }

  if (!esEntero(p.CantidadEmpaquetamiento) || !numeroValido(p.CantidadEmpaquetamiento, 1)) {
    return 'La cantidad por empaque debe ser un número entero mayor que cero.';
  }
  if (!esEntero(p.DiasEntrega) || !numeroValido(p.DiasEntrega, 0)) {
    return 'Los días de entrega deben ser un número entero mayor o igual a cero.';
  }
  if (!numeroValido(p.PrecioUnitario, 0)) return 'El precio unitario debe ser un número mayor o igual a cero.';
  if (!vacio(p.PrecioVenta) && !numeroValido(p.PrecioVenta, 0)) return 'El precio de venta debe ser un número mayor o igual a cero.';
  if (!numeroValido(p.Impuesto, 0) || Number(p.Impuesto) > 100) return 'El impuesto debe ser un número entre 0 y 100.';
  if (!numeroValido(p.Peso, 0) || Number(p.Peso) === 0) return 'El peso debe ser un número mayor que cero.';

  return '';
}

// Devuelve el texto sin espacios a los lados, o null si viene vacio
function textoOpcional(valor) {
  if (vacio(valor) || String(valor).trim() === '') return null;
  return String(valor).trim();
}

// Arma los parametros del SP a partir de los datos del formulario
function parametrosProducto(p) {
  return {
    Nombre: p.Nombre.trim(),
    ProveedorID: Number(p.ProveedorID),
    Grupos: p.Grupos.join(','), // el SP recibe los grupos como texto: '2,4,6'
    ColorID: vacio(p.ColorID) ? null : Number(p.ColorID),
    UnidadEmpaqueID: Number(p.UnidadEmpaqueID),
    EmpaqueExteriorID: Number(p.EmpaqueExteriorID),
    CantidadEmpaquetamiento: Number(p.CantidadEmpaquetamiento),
    Marca: textoOpcional(p.Marca),
    Tamano: textoOpcional(p.Tamano),
    Impuesto: Number(p.Impuesto),
    PrecioUnitario: Number(p.PrecioUnitario),
    PrecioVenta: vacio(p.PrecioVenta) ? null : Number(p.PrecioVenta),
    Peso: Number(p.Peso),
    DiasEntrega: Number(p.DiasEntrega),
    EsRefrigerado: p.EsRefrigerado ? 1 : 0,
    CodigoBarras: textoOpcional(p.CodigoBarras),
    ComentariosMarketing: textoOpcional(p.ComentariosMarketing)
  };
}

// POST /api/inventario  (los datos vienen en el cuerpo de la peticion)
router.post('/', async (req, res) => {
  const error = validarProducto(req.body);
  if (error !== '') {
    return res.status(400).json({ mensaje: error });
  }

  const filas = await ejecutarSPCorporativo('dbo.usp_Productos_Insertar', parametrosProducto(req.body));

  res.status(201).json({
    ProductoID: filas[0].ProductoID,
    mensaje: 'Producto creado correctamente. Puede tardar unos segundos en verse en la sucursal.'
  });
});

// PUT /api/inventario/5
router.put('/:id', async (req, res) => {
  if (!esEntero(req.params.id)) {
    return res.status(400).json({ mensaje: 'El código del producto debe ser un número entero.' });
  }

  const error = validarProducto(req.body);
  if (error !== '') {
    return res.status(400).json({ mensaje: error });
  }

  // La versión es la que trajo /editar; el SP la compara para detectar cambios de otro usuario
  if (vacio(req.body.Version) || !esEntero(req.body.Version)) {
    return res.status(400).json({ mensaje: 'Falta la versión del producto. Vuelva a cargarlo.' });
  }

  const parametros = parametrosProducto(req.body);
  parametros.ProductoID = Number(req.params.id);
  parametros.Version = Number(req.body.Version);

  await ejecutarSPCorporativo('dbo.usp_Productos_Actualizar', parametros);

  res.json({ mensaje: 'Producto actualizado correctamente. Puede tardar unos segundos en verse en la sucursal.' });
});

// DELETE /api/inventario/5
router.delete('/:id', async (req, res) => {
  if (!esEntero(req.params.id)) {
    return res.status(400).json({ mensaje: 'El código del producto debe ser un número entero.' });
  }

  await ejecutarSPCorporativo('dbo.usp_Productos_Eliminar', { ProductoID: Number(req.params.id) });

  res.json({ mensaje: 'Producto eliminado correctamente. Puede tardar unos segundos en verse en la sucursal.' });
});

// PUT /api/inventario/5/existencias  (cantidad y ubicación en la sucursal del usuario)
router.put('/:id/existencias', async (req, res) => {
  if (!esEntero(req.params.id)) {
    return res.status(400).json({ mensaje: 'El código del producto debe ser un número entero.' });
  }

  const { CantidadDisponible, Ubicacion } = req.body;

  if (vacio(CantidadDisponible) || !esEntero(CantidadDisponible) || Number(CantidadDisponible) < 0) {
    return res.status(400).json({ mensaje: 'La cantidad disponible debe ser un número entero mayor o igual a cero.' });
  }
  if (!vacio(Ubicacion) && String(Ubicacion).trim().length > 20) {
    return res.status(400).json({ mensaje: 'La ubicación debe tener 20 caracteres o menos.' });
  }

  await ejecutarSPSucursal(req.get('X-Sucursal'), 'dbo.usp_Existencias_Actualizar', {
    ProductoID: Number(req.params.id),
    CantidadDisponible: Number(CantidadDisponible),
    Ubicacion: textoOpcional(Ubicacion)
  });

  res.json({ mensaje: 'Inventario de la sucursal actualizado correctamente.' });
});

module.exports = router;
