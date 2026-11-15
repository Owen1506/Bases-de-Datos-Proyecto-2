import { useEffect, useRef, useState } from 'react';
import { consultar } from '../../api';
import { formatoFecha, formatoMonto } from '../../formato';
import Paginacion from '../../components/Paginacion';
import SelectorSucursal from '../../components/SelectorSucursal';

const MESES = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
const C = (id, titulo, tipo) => ({ id, titulo, tipo });
const REPORTES = {
  6: {
    titulo: 'Ventas por categoría y año', ruta: 'matriz-ventas-categoria',
    descripcion: 'Cada columna es un año de ventas. Un producto puede pertenecer a varios grupos; aparece en cada uno de ellos.',
    filtros: [], columnas: [C('Categoria', 'Grupo de producto'), C('TotalGeneral', 'Total de años', 'monto')]
  },
  7: {
    titulo: 'Seguimiento a clientes', ruta: 'seguimiento-clientes',
    descripcion: 'Resumen mensual por cliente. Mínimo y máximo son cantidades por línea de factura.',
    filtros: ['anioVentas', 'mes', 'grupos', 'productos'],
    columnas: [C('SucursalID', 'Sucursal', 'sucursal'), C('Anio', 'Año'), C('Mes', 'Mes', 'mes'),
      C('Cliente', 'Cliente'), C('CantidadFacturas', 'Facturas'), C('PrimeraFactura', 'Primera factura', 'fecha'),
      C('UltimaFactura', 'Última factura', 'fecha'), C('MontoTotal', 'Monto total', 'monto'),
      C('CantidadTotal', 'Cantidad'), C('CantidadMinima', 'Mínima'), C('CantidadMaxima', 'Máxima')]
  },
  8: {
    titulo: 'Seguimiento a proveedores', ruta: 'seguimiento-proveedores',
    descripcion: 'Resumen mensual de órdenes de compra. Las cantidades se expresan en empaques externos.',
    filtros: ['anioCompras', 'mes', 'grupos', 'productos'],
    columnas: [C('SucursalID', 'Sucursal', 'sucursal'), C('Anio', 'Año'), C('Mes', 'Mes', 'mes'),
      C('Proveedor', 'Proveedor'), C('CantidadOrdenes', 'Órdenes'), C('PrimeraOrden', 'Primera orden', 'fecha'),
      C('UltimaOrden', 'Última orden', 'fecha'), C('MontoTotal', 'Monto total', 'monto'),
      C('CantidadTotal', 'Cantidad'), C('CantidadMinima', 'Mínima'), C('CantidadMaxima', 'Máxima')]
  },
  9: {
    titulo: 'Rotación de inventario', ruta: 'rotacion-inventario',
    descripcion: 'Días estimados de existencias: cantidad actual dividida entre ventas diarias del año. No hay historial para calcular saldos anteriores.',
    filtros: ['anioVentas', 'grupos', 'proveedores'],
    columnas: [C('Anio', 'Año'), C('Producto', 'Producto'), C('Proveedor', 'Proveedor'),
      C('CantidadVendida', 'Unidades vendidas'), C('ExistenciaActual', 'Existencia actual'),
      C('DiasRotacion', 'Días estimados', 'dias')]
  },
  10: {
    titulo: 'Métodos de envío favoritos', ruta: 'metodos-envio-destino',
    descripcion: 'Destino según la ciudad de entrega actual del cliente. Cada factura cuenta una vez por método.',
    filtros: ['anioVentas', 'mes', 'categoriasCliente', 'grupos', 'productos'],
    columnas: [C('SucursalID', 'Sucursal', 'sucursal'), C('Ciudad', 'Ciudad de destino'),
      C('Posicion', 'Posición'), C('Metodo', 'Método de envío'), C('CantidadVentas', 'Ventas')]
  }
};
const FILTROS = {
  anioVentas: { clave: 'anio', titulo: 'Año de ventas', tipo: 'aniosVentas' },
  anioCompras: { clave: 'anio', titulo: 'Año de compras', tipo: 'aniosCompras' },
  grupos: { clave: 'grupoId', titulo: 'Categoría de producto', tipo: 'grupos' },
  productos: { clave: 'productoId', titulo: 'Producto (subcategoría)', tipo: 'productos' },
  proveedores: { clave: 'proveedorId', titulo: 'Proveedor', tipo: 'proveedores' },
  categoriasCliente: { clave: 'categoriaClienteId', titulo: 'Categoría de cliente', tipo: 'categoriasCliente' }
};

function mostrar(valor, tipo) {
  if (valor === null || valor === undefined) return '—';
  if (tipo === 'monto') return formatoMonto(valor);
  if (tipo === 'fecha') return formatoFecha(valor);
  if (tipo === 'sucursal') return valor === 1 ? 'San José' : 'Limón';
  if (tipo === 'mes') return MESES[Number(valor) - 1] || valor;
  if (tipo === 'dias') return Number(valor).toLocaleString('es-CR', { maximumFractionDigits: 2 });
  return valor;
}

function ReporteNuevo({ tipo, alVolver }) {
  const reporte = REPORTES[tipo];
  const [filtros, setFiltros] = useState({});
  const [opciones, setOpciones] = useState({});
  const [filas, setFilas] = useState([]);
  const [pagina, setPagina] = useState(1);
  const [total, setTotal] = useState(0);
  const [aplicados, setAplicados] = useState({});
  const [cargando, setCargando] = useState(false);
  const [error, setError] = useState('');
  const [errorFiltros, setErrorFiltros] = useState('');
  const solicitudActual = useRef(0);

  async function buscar(valores = {}, numeroPagina = 1) {
    const solicitud = ++solicitudActual.current;
    const params = new URLSearchParams({ pagina: String(numeroPagina) });
    for (const [clave, valor] of Object.entries(valores)) if (valor) params.set(clave, valor);
    setCargando(true);
    setError('');
    try {
      const datos = await consultar('/estadisticas/' + reporte.ruta + '?' + params);
      if (solicitud === solicitudActual.current) {
        setFilas(datos);
        setTotal(datos[0]?.TotalRegistros || 0);
        setPagina(numeroPagina);
        setAplicados({ ...valores });
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
    const tipos = [...new Set(reporte.filtros.filter(f => f !== 'mes').map(f => FILTROS[f].tipo))];
    Promise.all(tipos.map(async t => [t, await consultar('/estadisticas/filtros?tipo=' + t)]))
      .then(datos => setOpciones(Object.fromEntries(datos)))
      .catch(e => setErrorFiltros(e.message));
    buscar();
    return () => { solicitudActual.current += 1; };
  }, [tipo]);

  function alBuscar(evento) {
    evento.preventDefault();
    buscar(filtros);
  }
  function restaurar() {
    setFiltros({});
    buscar();
  }

  const columnas = tipo === 6 && filas.length
    ? [reporte.columnas[0], ...Object.keys(filas[0]).filter(k => /^\d{4}$/.test(k)).sort().map(k => C(k, k, 'monto')), reporte.columnas[1]]
    : reporte.columnas;

  return (
    <>
      <div className="reporte-navegacion">
        <button type="button" className="boton secundario" onClick={alVolver}>← Todos los reportes</button>
        <span>Reporte {tipo} de 10</span>
      </div>
      <h2>{reporte.titulo}</h2>
      <p className="descripcion">{reporte.descripcion}</p>
      <div className="modulo-columnas">
        <form className="panel panel-filtros" onSubmit={alBuscar}>
          <h3>Filtros del reporte</h3>
          {errorFiltros && <div className="mensaje error" role="alert">{errorFiltros}</div>}
          <SelectorSucursal valor={filtros.sucursal || ''}
            alCambiar={valor => setFiltros(actual => ({ ...actual, sucursal: valor }))} />
          {reporte.filtros.map(nombre => {
            if (nombre === 'mes') return (
              <label key="mes">Mes
                <select value={filtros.mes || ''} onChange={e => setFiltros(actual => ({ ...actual, mes: e.target.value }))}>
                  <option value="">Todos los meses</option>
                  {MESES.map((m, i) => <option key={m} value={i + 1}>{m}</option>)}
                </select>
              </label>
            );
            const f = FILTROS[nombre];
            return (
              <label key={nombre}>{f.titulo}
                <select value={filtros[f.clave] || ''}
                  onChange={e => setFiltros(actual => ({ ...actual, [f.clave]: e.target.value }))}>
                  <option value="">Todos</option>
                  {(opciones[f.tipo] || []).map(o => <option key={o.Id} value={o.Id}>{o.Nombre}</option>)}
                </select>
              </label>
            );
          })}
          <button className="boton" type="submit" disabled={cargando}>Consultar</button>
          <button className="boton secundario" type="button" onClick={restaurar} disabled={cargando}>Restaurar filtros</button>
        </form>

        <section className="panel panel-resultados" aria-label={reporte.titulo}>
          {error && <div className="mensaje error" role="alert">{error}</div>}
          {cargando && <div className="mensaje" role="status">Cargando reporte...</div>}
          {!cargando && !error && filas.length === 0 && <div className="mensaje info">No hay resultados con esos filtros.</div>}
          {!cargando && !error && filas.length > 0 && (
            <>
              <div className="reporte-tabla-contenedor">
                <table className="tabla reporte-tabla">
                  <thead><tr>{columnas.map(c => <th key={c.id} scope="col" className={c.tipo === 'monto' ? 'monto' : ''}>{c.titulo}</th>)}</tr></thead>
                  <tbody>{filas.map((fila, i) => (
                    <tr key={i}>{columnas.map(c => <td key={c.id} className={c.tipo === 'monto' ? 'monto' : ''}>{mostrar(fila[c.id], c.tipo)}</td>)}</tr>
                  ))}</tbody>
                </table>
              </div>
              <Paginacion pagina={pagina} total={total} tamano={10} cantidadFilas={filas.length}
                elementos="filas" alCambiar={n => buscar(aplicados, n)} />
            </>
          )}
        </section>
      </div>
    </>
  );
}

export default ReporteNuevo;
