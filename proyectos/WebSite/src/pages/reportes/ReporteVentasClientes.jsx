import { useEffect, useRef, useState } from 'react';
import { consultar } from '../../api';
import { formatoMonto } from '../../formato';
import Paginacion from '../../components/Paginacion';

const TAMANO_PAGINA = 10;

function ReporteVentasClientes({ alVolver }) {
  const [nombreCliente, setNombreCliente] = useState('');
  const [categoria, setCategoria] = useState('');
  const [filas, setFilas] = useState([]);
  const [pagina, setPagina] = useState(1);
  const [total, setTotal] = useState(0);
  const [filtrosAplicados, setFiltrosAplicados] = useState({});
  const [cargando, setCargando] = useState(false);
  const [error, setError] = useState('');
  const solicitudActual = useRef(0);

  async function buscar(filtros = {}, numeroPagina = 1) {
    const solicitud = ++solicitudActual.current;
    const parametros = new URLSearchParams();
    parametros.set('pagina', numeroPagina);
    if (filtros.nombreCliente?.trim()) parametros.set('nombreCliente', filtros.nombreCliente.trim());
    if (filtros.categoria?.trim()) parametros.set('categoria', filtros.categoria.trim());

    setCargando(true);
    setError('');
    try {
      const datos = await consultar('/estadisticas/ventas-clientes?' + parametros);
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
    buscar();
    return () => { solicitudActual.current += 1; };
  }, []);

  function alBuscar(evento) {
    evento.preventDefault();
    buscar({ nombreCliente, categoria });
  }

  function restaurar() {
    setNombreCliente('');
    setCategoria('');
    buscar();
  }

  return (
    <>
      <div className="reporte-navegacion">
        <button type="button" className="boton secundario" onClick={alVolver}>← Todos los reportes</button>
        <span>Reporte 2 de 10</span>
      </div>
      <h2>Ventas por cliente y categoría</h2>
      <p className="descripcion">Montos mínimo, máximo y promedio por factura de cada cliente.</p>

      <div className="modulo-columnas">
        <form className="panel panel-filtros" onSubmit={alBuscar}>
          <h3>Filtros del reporte</h3>
          <label>
            Nombre del cliente
            <input type="text" value={nombreCliente} maxLength={100}
              placeholder="Escriba parte del nombre"
              onChange={(e) => setNombreCliente(e.target.value)} />
          </label>
          <label>
            Categoría del cliente
            <input type="text" value={categoria} maxLength={100}
              placeholder="Escriba parte de la categoría"
              onChange={(e) => setCategoria(e.target.value)} />
          </label>
          <button className="boton" type="submit" disabled={cargando}>Consultar</button>
          <button className="boton secundario" type="button" onClick={restaurar} disabled={cargando}>
            Restaurar filtros
          </button>
        </form>

        <section className="panel panel-resultados" aria-label="Reporte de ventas por cliente">
          {error && <div className="mensaje error" role="alert">{error}</div>}
          {cargando && <div className="mensaje" role="status">Cargando reporte...</div>}
          {!cargando && !error && filas.length === 0 && (
            <div className="mensaje info">No se encontraron facturas con esos filtros.</div>
          )}
          {!cargando && !error && filas.length > 0 && (
            <>
            <div className="reporte-tabla-contenedor">
              <table className="tabla reporte-tabla">
                <thead>
                  <tr>
                    <th scope="col">Categoría</th>
                    <th scope="col">Cliente</th>
                    <th scope="col" className="monto">Mínimo</th>
                    <th scope="col" className="monto">Máximo</th>
                    <th scope="col" className="monto">Promedio</th>
                  </tr>
                </thead>
                <tbody>
                  {filas.map((fila, indice) => (
                    <tr key={indice} className={fila.TipoFila === 'general' ? 'total-general' : fila.TipoFila === 'categoria' ? 'subtotal' : ''}>
                      <td>{fila.Categoria}</td>
                      <td>{fila.Cliente || '—'}</td>
                      <td className="monto">{formatoMonto(fila.MontoMinimo)}</td>
                      <td className="monto">{formatoMonto(fila.MontoMaximo)}</td>
                      <td className="monto">{formatoMonto(fila.MontoPromedio)}</td>
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

export default ReporteVentasClientes;
