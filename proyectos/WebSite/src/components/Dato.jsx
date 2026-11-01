// Una fila del detalle: la etiqueta a la izquierda y el valor a la derecha.
// Si el valor viene vacio muestra un guion.
function Dato({ etiqueta, valor }) {
  return (
    <div className="dato">
      <span className="dato-etiqueta">{etiqueta}</span>
      <span className="dato-valor">{valor ? valor : '-'}</span>
    </div>
  );
}

export default Dato;
