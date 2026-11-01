import { useEffect, useState } from 'react';
import { consultar } from '../api';
import { formatoFecha, formatoMonto } from '../formato';
import Dato from './Dato';
import DetalleCliente from './DetalleCliente';
import DetalleProducto from './DetalleProducto';

// Ventana con el detalle de una factura: arriba el encabezado y abajo las lineas.
// El cliente y los productos son enlaces que abren su propio detalle encima.
function DetalleVenta({ facturaId, alCerrar }) {
  const [encabezado, setEncabezado] = useState(null);
  const [lineas, setLineas] = useState([]);
  const [error, setError] = useState('');

  // cliente o producto abierto desde un enlace (null = cerrado)
  const [clienteId, setClienteId] = useState(null);
  const [productoId, setProductoId] = useState(null);

  async function cargar() {
    try {
      const datos = await consultar('/ventas/' + facturaId);
      setEncabezado(datos.encabezado);
      setLineas(datos.lineas);
    } catch (e) {
      setError(e.message);
    }
  }

  // Cuando se abre la ventana se piden los datos de la factura
  useEffect(() => {
    cargar();
  }, []);

  return (
    // al hacer clic en el fondo oscuro se cierra la ventana
    <div className="fondo-ventana" onClick={alCerrar}>
      {/* stopPropagation evita que un clic dentro de la ventana la cierre */}
      <div className="ventana ventana-ancha" onClick={(e) => e.stopPropagation()}>
        <div className="ventana-titulo">
          <div className="titulo-con-badge">
            <h3>Factura #{facturaId}</h3>
            {encabezado !== null && <span className="badge">{formatoFecha(encabezado.Fecha)}</span>}
          </div>
          <button className="boton-cerrar" onClick={alCerrar}>✕</button>
        </div>

        <div className="ventana-contenido">
          {error !== '' && <div className="mensaje error">{error}</div>}

          {encabezado === null && error === '' && <div className="mensaje">Cargando...</div>}

          {encabezado !== null && (
            <>
              <h4>Encabezado</h4>
              <div className="detalle-dos-columnas">
                <div>
                  <Dato etiqueta="Número de factura" valor={encabezado.FacturaID} />
                  <Dato
                    etiqueta="Cliente"
                    valor={
                      <button className="enlace" onClick={() => setClienteId(encabezado.ClienteID)}>
                        {encabezado.Cliente}
                      </button>
                    }
                  />
                  <Dato etiqueta="Método de entrega" valor={encabezado.MetodoEntrega} />
                  <Dato etiqueta="Número de orden" valor={encabezado.NumeroOrdenCliente} />
                </div>
                <div>
                  <Dato etiqueta="Persona de contacto" valor={encabezado.Contacto} />
                  <Dato etiqueta="Vendedor" valor={encabezado.Vendedor} />
                  <Dato etiqueta="Fecha" valor={formatoFecha(encabezado.Fecha)} />
                  <Dato etiqueta="Instrucciones de entrega" valor={encabezado.InstruccionesEntrega} />
                </div>
              </div>

              <h4>Detalle de la factura</h4>
              <div className="tabla-contenedor-lineas">
                <table className="tabla tabla-simple">
                  <thead>
                    <tr>
                      <th>Producto</th>
                      <th className="numero">Cantidad</th>
                      <th className="numero">Precio unitario</th>
                      <th className="numero">Impuesto</th>
                      <th className="numero">Monto impuesto</th>
                      <th className="numero">Total</th>
                    </tr>
                  </thead>
                  <tbody>
                    {lineas.map((l) => (
                      <tr key={l.LineaID}>
                        <td>
                          <button className="enlace" onClick={() => setProductoId(l.ProductoID)}>
                            {l.Producto}
                          </button>
                        </td>
                        <td className="numero">{l.Cantidad}</td>
                        <td className="numero">{formatoMonto(l.PrecioUnitario)}</td>
                        <td className="numero">{l.Impuesto} %</td>
                        <td className="numero">{formatoMonto(l.MontoImpuesto)}</td>
                        <td className="numero">{formatoMonto(l.TotalLinea)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {/* el total lo calcula el SP (MontoTotal), aqui solo se muestra */}
              <p className="total-factura">
                Total de la factura: <strong>{formatoMonto(encabezado.MontoTotal)}</strong>
              </p>
            </>
          )}
        </div>
      </div>

      {/* Los detalles de cliente y producto se abren encima de esta ventana */}
      {clienteId !== null && (
        <div onClick={(e) => e.stopPropagation()}>
          <DetalleCliente clienteId={clienteId} alCerrar={() => setClienteId(null)} />
        </div>
      )}
      {productoId !== null && (
        <div onClick={(e) => e.stopPropagation()}>
          <DetalleProducto productoId={productoId} alCerrar={() => setProductoId(null)} />
        </div>
      )}
    </div>
  );
}

export default DetalleVenta;
