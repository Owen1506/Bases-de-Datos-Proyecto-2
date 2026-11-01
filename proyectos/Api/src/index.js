// Se usa el mismo .env de la raiz del repo (el que usa docker compose)
require('dotenv').config({ path: __dirname + '/../../../.env' });

const express = require('express');
const cors = require('cors');

const clientes = require('./routes/clientes');
const proveedores = require('./routes/proveedores');
const inventario = require('./routes/inventario');
const ventas = require('./routes/ventas');
const catalogos = require('./routes/catalogos');
const estadisticas = require('./routes/estadisticas');

const app = express();
const PUERTO = 3000;

app.use(cors());
app.use(express.json()); // para leer el cuerpo JSON de los POST y PUT

app.use('/api/clientes', clientes);
app.use('/api/proveedores', proveedores);
app.use('/api/inventario', inventario);
app.use('/api/ventas', ventas);
app.use('/api/catalogos', catalogos);
app.use('/api/estadisticas', estadisticas);

// Ruta no encontrada
app.use((req, res) => {
  res.status(404).json({ mensaje: 'Ruta no encontrada.' });
});

// Si algo falla en una ruta (por ejemplo la base no responde) cae aqui
app.use((err, req, res, next) => {
  // Los errores de los SP con THROW 50001, 50002... traen un mensaje para el usuario
  if (err.number >= 50000) {
    return res.status(400).json({ mensaje: err.message });
  }

  console.error(err);
  res.status(500).json({ mensaje: 'Ocurrió un error al consultar la base de datos.' });
});

app.listen(PUERTO, () => {
  console.log('API escuchando en http://localhost:' + PUERTO);
});
