import { useEffect, useRef, useState } from 'react';
import { consultar } from '../../api';
import { formatoMonto } from '../../formato';
import Paginacion from '../../components/Paginacion';

const TAMANO_PAGINA = 10;

function ReporteComprasProveedores({ alVolver }) {
  const [categoria, setCategoria] = useState('');
  const [nombreProveedor, setNombreProveedor] = useState('');
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
    if (filtros.categoria?.trim()) parametros.set('categoria', filtros.categoria.trim());
    if (filtros.nombreProveedor?.trim()) parametros.set('nombreProveedor', filtros.nombreProveedor.trim());

    setCargando(true);
    setError('');
    try {
      const datos = await consultar('/estadisticas/compras-proveedores?' + parametros.toString());
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
    buscar({ categoria, nombreProveedor });
  }

  function restaurar() {
    setCategoria('');
    setNombreProveedor('');
    buscar();
  }

  return (
    <>
      <div className="reporte-navegacion">
        <button type="button" className="boton secundario" onClick={alVolver}>← Todos los reportes</button>
        <span>Reporte 1 de 10</span>
      </div>
      <h2>Compras a proveedores</h2>
      <p className="descripcion">Montos de órdenes de compra por proveedor y categoría de proveedor.</p>

      <div className="modulo-columnas">
        <form className="panel panel-filtros" onSubmit={alBuscar}>
          <h3>Filtros del reporte</h3>
          <label>
            Categoría del proveedor
            <input type="text" value={categoria} maxLength={100}
              placeholder="Escriba parte de la categoría"
              onChange={(e) => setCategoria(e.target.value)} />
          </label>
          <label>
            Nombre del proveedor
            <input type="text" value={nombreProveedor} maxLength={100}
              placeholder="Escriba parte del nombre"
              onChange={(e) => setNombreProveedor(e.target.value)} />
          </label>
          <button className="boton" type="submit" disabled={cargando}>Consultar</button>
          <button className="boton secundario" type="button" onClick={restaurar} disabled={cargando}>
            Restaurar filtros
          </button>
        </form>

        <section className="panel panel-resultados" aria-label="Reporte de compras a proveedores">
          {error && <div className="mensaje error" role="alert">{error}</div>}
          {cargando && <div className="mensaje" role="status">Cargando reporte...</div>}
          {!cargando && !error && filas.length === 0 && (
            <div className="mensaje info">No se encontraron órdenes de compra con esos filtros.</div>
          )}
          {!cargando && !error && filas.length > 0 && (
            <>
            <div className="reporte-tabla-contenedor">
              <table className="tabla reporte-tabla">
                <thead>
                  <tr>
                    <th scope="col">Categoría</th>
                    <th scope="col">Proveedor</th>
                    <th scope="col" className="monto">Mínimo</th>
                    <th scope="col" className="monto">Máximo</th>
                    <th scope="col" className="monto">Promedio</th>
                  </tr>
                </thead>
                <tbody>
                  {filas.map((fila, indice) => {
                    const esTotalGeneral = fila.Categoria === 'TOTAL GENERAL';
                    const esSubtotal = fila.Proveedor === 'TOTAL CATEGORIA';
                    return (
                      <tr key={indice} className={esTotalGeneral ? 'total-general' : esSubtotal ? 'subtotal' : ''}>
                        <td>{fila.Categoria}</td>
                        <td>{fila.Proveedor || '—'}</td>
                        <td className="monto">{formatoMonto(fila.MontoMinimo)}</td>
                        <td className="monto">{formatoMonto(fila.MontoMaximo)}</td>
                        <td className="monto">{formatoMonto(fila.MontoPromedio)}</td>
                      </tr>
                    );
                  })}
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

export default ReporteComprasProveedores;
