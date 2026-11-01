import { useEffect, useState } from 'react';
import { consultar } from '../api';
import Dato from './Dato';
import DetalleProveedor from './DetalleProveedor';

// Ventana con el detalle de un producto, en dos columnas:
// izquierda los datos del producto y su empaque, derecha los precios y el inventario
function DetalleProducto({ productoId, alCerrar }) {
  const [producto, setProducto] = useState(null);
  const [error, setError] = useState('');

  // proveedor abierto desde el enlace (null = cerrado)
  const [proveedorId, setProveedorId] = useState(null);

  async function cargar() {
    try {
      setProducto(await consultar('/inventario/' + productoId));
    } catch (e) {
      setError(e.message);
    }
  }

  // Cuando se abre la ventana se piden los datos del producto
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
            <h3>{producto ? producto.Nombre : 'Detalle del producto'}</h3>
          </div>
          <button className="boton-cerrar" onClick={alCerrar}>✕</button>
        </div>

        <div className="ventana-contenido">
          {error !== '' && <div className="mensaje error">{error}</div>}

          {producto === null && error === '' && <div className="mensaje">Cargando...</div>}

          {producto !== null && (
            <div className="detalle-dos-columnas">
              {/* Columna izquierda: datos del producto y empaque */}
              <div>
                <h4>Producto</h4>
                <Dato
                  etiqueta="Proveedor"
                  valor={
                    <button className="enlace" onClick={() => setProveedorId(producto.ProveedorID)}>
                      {producto.Proveedor}
                    </button>
                  }
                />
                <Dato etiqueta="Grupo" valor={producto.Grupo} />
                <Dato etiqueta="Color" valor={producto.Color} />
                <Dato etiqueta="Marca" valor={producto.Marca} />
                <Dato etiqueta="Talla / tamaño" valor={producto.Tamano} />
                <Dato etiqueta="Palabras clave" valor={producto.PalabrasClave} />

                <h4>Empaque</h4>
                <Dato etiqueta="Unidad de empaquetamiento" valor={producto.UnidadEmpaquetamiento} />
                <Dato etiqueta="Empaquetamiento" valor={producto.Empaquetamiento} />
                <Dato etiqueta="Cantidad por empaque" valor={producto.CantidadEmpaquetamiento} />
                <Dato etiqueta="Peso" valor={producto.Peso + ' kg'} />
              </div>

              {/* Columna derecha: precios e inventario */}
              <div>
                <h4>Precios</h4>
                <Dato etiqueta="Precio unitario" valor={'$' + producto.PrecioUnitario} />
                <Dato
                  etiqueta="Precio de venta"
                  valor={producto.PrecioVenta !== null ? '$' + producto.PrecioVenta : null}
                />
                <Dato etiqueta="Impuesto" valor={producto.Impuesto + ' %'} />

                <h4>Inventario</h4>
                <Dato etiqueta="Cantidad disponible" valor={producto.CantidadDisponible.toLocaleString()} />
                <Dato etiqueta="Ubicación" valor={producto.Ubicacion} />
              </div>
            </div>
          )}
        </div>
      </div>

      {/* El detalle del proveedor se abre encima de esta ventana */}
      {proveedorId !== null && (
        <div onClick={(e) => e.stopPropagation()}>
          <DetalleProveedor proveedorId={proveedorId} alCerrar={() => setProveedorId(null)} />
        </div>
      )}
    </div>
  );
}

export default DetalleProducto;
