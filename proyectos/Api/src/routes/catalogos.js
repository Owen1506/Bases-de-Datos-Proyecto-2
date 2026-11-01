const express = require('express');
const { ejecutarSP } = require('../db');
const { esEntero } = require('../validar');

const router = express.Router();

// Catalogos para llenar los selects de los filtros y formularios

router.get('/categorias-cliente', async (req, res) => {
  res.json(await ejecutarSP('dbo.usp_Catalogo_CategoriasCliente'));
});

router.get('/metodos-entrega', async (req, res) => {
  res.json(await ejecutarSP('dbo.usp_Catalogo_MetodosEntrega'));
});

router.get('/grupos-compra', async (req, res) => {
  res.json(await ejecutarSP('dbo.usp_Catalogo_GruposCompra'));
});

router.get('/categorias-proveedor', async (req, res) => {
  res.json(await ejecutarSP('dbo.usp_Catalogo_CategoriasProveedor'));
});

router.get('/grupos-inventario', async (req, res) => {
  res.json(await ejecutarSP('dbo.usp_Catalogo_GruposInventario'));
});

router.get('/colores', async (req, res) => {
  res.json(await ejecutarSP('dbo.usp_Catalogo_Colores'));
});

router.get('/tipos-empaque', async (req, res) => {
  res.json(await ejecutarSP('dbo.usp_Catalogo_TiposEmpaque'));
});

// Lista completa de proveedores para el select del formulario de productos (son 13)
router.get('/lista-proveedores', async (req, res) => {
  res.json(await ejecutarSP('dbo.usp_Catalogo_Proveedores'));
});

// Catalogos del formulario de ventas

router.get('/vendedores', async (req, res) => {
  res.json(await ejecutarSP('dbo.usp_Catalogo_Vendedores'));
});

// Lista completa de productos con su precio, para las lineas de la factura
router.get('/lista-productos', async (req, res) => {
  res.json(await ejecutarSP('dbo.usp_Catalogo_Productos'));
});

// Contactos (primario y alternativo) de un cliente: /api/catalogos/contactos-cliente?clienteId=5
router.get('/contactos-cliente', async (req, res) => {
  const clienteId = req.query.clienteId;
  if (!esEntero(clienteId)) {
    return res.status(400).json({ mensaje: 'El cliente debe ser un número entero.' });
  }
  res.json(await ejecutarSP('dbo.usp_Catalogo_ContactosCliente', { ClienteID: Number(clienteId) }));
});

// Buscadores: reciben ?texto= y devuelven las primeras 20 coincidencias.
// Si el texto tiene menos de 2 letras no se consulta la base.

router.get('/ciudades', async (req, res) => {
  const texto = req.query.texto || '';
  if (texto.length < 2) {
    return res.json([]);
  }
  res.json(await ejecutarSP('dbo.usp_Catalogo_BuscarCiudades', { Texto: texto }));
});

router.get('/personas', async (req, res) => {
  const texto = req.query.texto || '';
  if (texto.length < 2) {
    return res.json([]);
  }
  res.json(await ejecutarSP('dbo.usp_Catalogo_BuscarPersonas', { Texto: texto }));
});

router.get('/clientes', async (req, res) => {
  const texto = req.query.texto || '';
  if (texto.length < 2) {
    return res.json([]);
  }
  res.json(await ejecutarSP('dbo.usp_Catalogo_BuscarClientes', { Texto: texto }));
});

router.get('/proveedores', async (req, res) => {
  const texto = req.query.texto || '';
  if (texto.length < 2) {
    return res.json([]);
  }
  res.json(await ejecutarSP('dbo.usp_Catalogo_BuscarProveedores', { Texto: texto }));
});

router.get('/productos', async (req, res) => {
  const texto = req.query.texto || '';
  if (texto.length < 2) {
    return res.json([]);
  }
  res.json(await ejecutarSP('dbo.usp_Catalogo_BuscarProductos', { Texto: texto }));
});

module.exports = router;
