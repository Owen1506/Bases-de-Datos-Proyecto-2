import { useState } from 'react';
import ReporteComprasProveedores from './reportes/ReporteComprasProveedores';
import ReporteVentasClientes from './reportes/ReporteVentasClientes';
import ReporteProductosGanancia from './reportes/ReporteProductosGanancia';
import ReporteClientesFacturas from './reportes/ReporteClientesFacturas';
import ReporteProveedoresOrdenes from './reportes/ReporteProveedoresOrdenes';
import '../styles/estadisticas.css';

const REPORTES = [
  { id: 1, titulo: 'Compras a proveedores', descripcion: 'Montos mínimo, máximo y promedio por proveedor y categoría.' },
  { id: 2, titulo: 'Ventas por cliente y categoría', descripcion: 'Montos mínimo, máximo y promedio por factura.' },
  { id: 3, titulo: 'Productos con mayor ganancia por año', descripcion: 'Cinco posiciones por ganancia total de ventas.' },
  { id: 4, titulo: 'Clientes con más facturas por año', descripcion: 'Cantidad de facturas y monto total facturado.' },
  { id: 5, titulo: 'Proveedores con más órdenes por año', descripcion: 'Cantidad de órdenes y monto total por proveedor.' },
  { id: 6, titulo: 'Ventas por categoría y año', descripcion: 'Matriz resumen de ventas por categoría de producto.' },
  { id: 7, titulo: 'Seguimiento a clientes', descripcion: 'Compras mensuales, fechas y cantidades por cliente.' },
  { id: 8, titulo: 'Seguimiento a proveedores', descripcion: 'Compras mensuales, fechas y cantidades por proveedor.' },
  { id: 9, titulo: 'Rotación de inventario', descripcion: 'Promedio de días de rotación por producto.' },
  { id: 10, titulo: 'Métodos de envío favoritos', descripcion: 'Métodos más usados según el destino de la venta.' }
];

const COMPONENTES = {
  1: ReporteComprasProveedores,
  2: ReporteVentasClientes,
  3: ReporteProductosGanancia,
  4: ReporteClientesFacturas,
  5: ReporteProveedoresOrdenes
};

function Estadisticas() {
  const [reporteActivo, setReporteActivo] = useState(null);
  const ReporteActivo = COMPONENTES[reporteActivo];

  if (ReporteActivo) {
    return <ReporteActivo alVolver={() => setReporteActivo(null)} />;
  }

  return (
    <>
      <h2>Estadísticas</h2>
      <p className="descripcion">Seleccione un reporte para consultar sus datos.</p>
      <div className="catalogo-reportes">
        {REPORTES.map((reporte) => (
          COMPONENTES[reporte.id] ? (
            <button key={reporte.id} type="button" className="panel reporte-tarjeta disponible"
              onClick={() => setReporteActivo(reporte.id)}>
              <span className="reporte-numero">{String(reporte.id).padStart(2, '0')}</span>
              <span className="reporte-tarjeta-texto">
                <strong>{reporte.titulo}</strong>
                <span>{reporte.descripcion}</span>
              </span>
              <span className="reporte-estado">Abrir reporte <span aria-hidden="true">→</span></span>
            </button>
          ) : (
            <div key={reporte.id} className="panel reporte-tarjeta pendiente">
              <span className="reporte-numero">{String(reporte.id).padStart(2, '0')}</span>
              <span className="reporte-tarjeta-texto">
                <strong>{reporte.titulo}</strong>
                <span>{reporte.descripcion}</span>
              </span>
              <span className="reporte-estado">Pendiente</span>
            </div>
          )
        ))}
      </div>
    </>
  );
}

export default Estadisticas;
