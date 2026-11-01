// Recuadro con una direccion (de entrega o postal), cada linea con su etiqueta.
// Lo usan los detalles de clientes y proveedores.

// Junta las dos lineas de la direccion con coma.
// Si una viene vacia (pasa en algunos proveedores) se muestra solo la otra.
function unirLineas(linea1, linea2) {
  if (!linea1) return linea2;
  if (!linea2) return linea1;
  return linea1 + ', ' + linea2;
}

function BloqueDireccion({ titulo, linea1, linea2, ciudad, codigoPostal }) {
  return (
    <div className="bloque-direccion">
      <span className="bloque-direccion-titulo">{titulo}</span>

      <div className="fila-direccion">
        <span className="dato-etiqueta">Dirección</span>
        <span>{unirLineas(linea1, linea2)}</span>
      </div>

      <div className="fila-direccion">
        <span className="dato-etiqueta">Ciudad</span>
        <span>{ciudad}</span>
      </div>

      <div className="fila-direccion">
        <span className="dato-etiqueta">Código postal</span>
        <span>{codigoPostal}</span>
      </div>
    </div>
  );
}

export default BloqueDireccion;
