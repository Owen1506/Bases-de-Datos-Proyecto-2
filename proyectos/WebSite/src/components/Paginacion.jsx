// Controles de paginacion al pie de la tabla.
// Los datos ya vienen paginados desde el SP; aqui solo se calculan los numeros
// de pagina para los botones y se avisa cual pagina se quiere ver.
// elementos: palabra que se muestra en el texto, por ejemplo "clientes" o "proveedores"
function Paginacion({ pagina, total, tamano, cantidadFilas, elementos, alCambiar }) {
  const totalPaginas = Math.ceil(total / tamano);

  // rango que se esta mostrando, por ejemplo "11-20"
  const desde = (pagina - 1) * tamano + 1;
  const hasta = desde + cantidadFilas - 1;

  // Solo se muestran hasta 5 numeros alrededor de la pagina actual
  let inicio = pagina - 2;
  if (inicio < 1) inicio = 1;
  let fin = inicio + 4;
  if (fin > totalPaginas) fin = totalPaginas;
  if (fin - inicio < 4 && fin - 4 >= 1) inicio = fin - 4;

  const numeros = [];
  for (let i = inicio; i <= fin; i++) {
    numeros.push(i);
  }

  return (
    <div className="paginacion">
      <span className="paginacion-texto">
        Mostrando {desde}-{hasta} de {total} {elementos}
      </span>

      <div className="paginacion-botones">
        <button disabled={pagina === 1} onClick={() => alCambiar(1)} title="Primera página">
          &laquo;
        </button>

        <button disabled={pagina === 1} onClick={() => alCambiar(pagina - 1)}>
          &lt; Anterior
        </button>

        {numeros.map((n) => (
          <button
            key={n}
            className={n === pagina ? 'actual' : ''}
            onClick={() => alCambiar(n)}
          >
            {n}
          </button>
        ))}

        <button disabled={pagina === totalPaginas} onClick={() => alCambiar(pagina + 1)}>
          Siguiente &gt;
        </button>

        <button disabled={pagina === totalPaginas} onClick={() => alCambiar(totalPaginas)} title="Última página">
          &raquo;
        </button>
      </div>
    </div>
  );
}

export default Paginacion;
