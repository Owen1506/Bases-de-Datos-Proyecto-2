import { useEffect, useRef, useState } from 'react';
import { consultar } from '../../api';
import { formatoMonto } from '../../formato';
import Paginacion from '../../components/Paginacion';

const TAMANO_PAGINA = 10;

function ReporteTop({ tipo, alVolver }) {
  const esProductos = tipo === 'productos';
  const esProveedores = tipo === 'proveedores';
  const [anios, setAnios] = useState([]);
  const [anio, setAnio] = useState('');
  const [anioInicio, setAnioInicio] = useState('');
  const [anioFin, setAnioFin] = useState('');
  const [filas, setFilas] = useState([]);
  const [pagina, setPagina] = useState(1);
  const [total, setTotal] = useState(0);
  const [filtrosAplicados, setFiltrosAplicados] = useState({});
  const [cargando, setCargando] = useState(false);
  const [error, setError] = useState('');
  const [errorAnios, setErrorAnios] = useState('');
  const solicitudActual = useRef(0);

  async function buscar(filtros = {}, numeroPagina = 1) {
    const solicitud = ++solicitudActual.current;
    const parametros = new URLSearchParams();
    parametros.set('pagina', numeroPagina);
    if (filtros.anio) parametros.set('anio', filtros.anio);
    if (filtros.anioInicio) parametros.set('anioInicio', filtros.anioInicio);
    if (filtros.anioFin) parametros.set('anioFin', filtros.anioFin);

    setCargando(true);
    setError('');
    try {
      const ruta = esProductos ? '/estadisticas/top-productos-ganancia'
        : esProveedores ? '/estadisticas/top-proveedores-ordenes'
          : '/estadisticas/top-clientes-facturas';
      const datos = await consultar(ruta + '?' + parametros);
      if (solicitud === solicitudActual.current) {
        setFilas(datos);
        setTotal(datos[0]?.TotalRegistros || 0);
        setPagina(numeroPagina);
        setFiltrosAplicados(filtros);
      }
    } catch (e) {
      if (solicitud === solicitudActual.current) {
        setFilas([]);
        setTotal(0);
        setError(e.message);
      }
    } finally {
      if (solicitud === solicitudActual.current) setCargando(false);
    }
  }

  useEffect(() => {
    consultar(esProveedores ? '/estadisticas/anios-ordenes-compra' : '/estadisticas/anios-facturas')
      .then(setAnios)
      .catch((e) => setErrorAnios(e.message));
    buscar();
    return () => { solicitudActual.current += 1; };
  }, []);

  function alBuscar(evento) {
    evento.preventDefault();
    if (!esProductos && anioInicio && anioFin && Number(anioInicio) > Number(anioFin)) {
      setError('El año inicial debe ser menor o igual que el año final.');
      return;
    }
    buscar(esProductos ? { anio } : { anioInicio, anioFin });
  }

  function restaurar() {
    setAnio('');
    setAnioInicio('');
    setAnioFin('');
    buscar();
  }

  const numero = esProductos ? 3 : esProveedores ? 5 : 4;
  const titulo = esProductos ? 'Productos con mayor ganancia por año'
    : esProveedores ? 'Proveedores con más órdenes por año'
      : 'Clientes con más facturas por año';

  return (
    <>
      <div className="reporte-navegacion">
        <button type="button" className="boton secundario" onClick={alVolver}>← Todos los reportes</button>
        <span>Reporte {numero} de 10</span>
      </div>
      <h2>{titulo}</h2>
      <p className="descripcion">
        {esProductos
          ? 'Cinco posiciones de productos ordenadas por ganancia total en cada año.'
          : esProveedores
            ? 'Cinco posiciones de proveedores ordenadas por cantidad de órdenes de compra en cada año.'
            : 'Cinco posiciones de clientes ordenadas por cantidad de facturas en cada año.'}
      </p>

      <div className="modulo-columnas">
        <form className="panel panel-filtros" onSubmit={alBuscar}>
          <h3>Filtros del reporte</h3>
          {errorAnios && <div className="mensaje error" role="alert">{errorAnios}</div>}
          {esProductos ? (
            <label>
              Año de facturación
              <select value={anio} onChange={(e) => setAnio(e.target.value)} disabled={!!errorAnios}>
                <option value="">Todos los años</option>
                {anios.map((a) => <option key={a.Anio} value={a.Anio}>{a.Anio}</option>)}
              </select>
            </label>
          ) : (
            <>
              <label>
                Año inicial
                <select value={anioInicio} onChange={(e) => setAnioInicio(e.target.value)} disabled={!!errorAnios}>
                  <option value="">Primer año disponible</option>
                  {anios.map((a) => <option key={a.Anio} value={a.Anio}>{a.Anio}</option>)}
                </select>
              </label>
              <label>
                Año final
                <select value={anioFin} onChange={(e) => setAnioFin(e.target.value)} disabled={!!errorAnios}>
                  <option value="">Último año disponible</option>
                  {anios.map((a) => <option key={a.Anio} value={a.Anio}>{a.Anio}</option>)}
                </select>
              </label>
            </>
          )}
          <button className="boton" type="submit" disabled={cargando || !!errorAnios}>Consultar</button>
          <button className="boton secundario" type="button" onClick={restaurar} disabled={cargando || !!errorAnios}>
            Restaurar filtros
          </button>
        </form>

        <section className="panel panel-resultados" aria-label={titulo}>
          {error && <div className="mensaje error" role="alert">{error}</div>}
          {cargando && <div className="mensaje" role="status">Cargando reporte...</div>}
          {!cargando && !error && filas.length === 0 && (
            <div className="mensaje info">
              No se encontraron {esProveedores ? 'órdenes de compra' : 'facturas'} para los años seleccionados.
            </div>
          )}
          {!cargando && !error && filas.length > 0 && (
            <>
            <div className="reporte-tabla-contenedor">
              <table className="tabla reporte-tabla">
                <thead>
                  <tr>
                    <th scope="col">Año</th>
                    <th scope="col">Posición</th>
                    <th scope="col">{esProductos ? 'Producto' : esProveedores ? 'Proveedor' : 'Cliente'}</th>
                    {!esProductos && <th scope="col" className="monto">{esProveedores ? 'Órdenes' : 'Facturas'}</th>}
                    <th scope="col" className="monto">
                      {esProductos ? 'Ganancia total' : esProveedores ? 'Monto total' : 'Monto total facturado'}
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {filas.map((fila) => (
                    <tr key={fila.Anio + '-' + (esProductos ? fila.ProductoID : esProveedores ? fila.ProveedorID : fila.ClienteID)}>
                      <td>{fila.Anio}</td>
                      <td>{fila.Posicion}</td>
                      <td>{esProductos ? fila.Producto : esProveedores ? fila.Proveedor : fila.Cliente}</td>
                      {!esProductos && <td className="monto">{esProveedores ? fila.CantidadOrdenes : fila.CantidadFacturas}</td>}
                      <td className="monto">
                        {formatoMonto(esProductos ? fila.GananciaTotal : esProveedores ? fila.MontoTotal : fila.MontoTotalFacturado)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <Paginacion pagina={pagina} total={total} tamano={TAMANO_PAGINA}
              cantidadFilas={filas.length} elementos="filas"
              alCambiar={(numero) => buscar(filtrosAplicados, numero)} />
            </>
          )}
        </section>
      </div>
    </>
  );
}

export default ReporteTop;
