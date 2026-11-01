import { useEffect, useState } from 'react';
import { consultar } from '../api';
import BloqueDireccion from './BloqueDireccion';
import Dato from './Dato';
import Mapa from './Mapa';

// Ventana con el detalle de un proveedor, en dos columnas:
// izquierda la informacion general, el pago y los contactos; derecha las direcciones y el mapa
function DetalleProveedor({ proveedorId, alCerrar }) {
  const [proveedor, setProveedor] = useState(null);
  const [error, setError] = useState('');

  async function cargar() {
    try {
      setProveedor(await consultar('/proveedores/' + proveedorId));
    } catch (e) {
      setError(e.message);
    }
  }

  // Cuando se abre la ventana se piden los datos del proveedor
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
            <h3>{proveedor ? proveedor.Nombre : 'Detalle del proveedor'}</h3>
            {proveedor !== null && <span className="badge">{proveedor.Categoria}</span>}
          </div>
          <button className="boton-cerrar" onClick={alCerrar}>✕</button>
        </div>

        <div className="ventana-contenido">
          {error !== '' && <div className="mensaje error">{error}</div>}

          {proveedor === null && error === '' && <div className="mensaje">Cargando...</div>}

          {proveedor !== null && (
            <div className="detalle-dos-columnas">
              {/* Columna izquierda: informacion, pago y contactos */}
              <div>
                <h4>General</h4>
                <Dato etiqueta="Código del proveedor" valor={proveedor.CodigoProveedor} />
                <Dato etiqueta="Método de entrega" valor={proveedor.MetodoEntrega} />
                <Dato etiqueta="Teléfono" valor={proveedor.Telefono} />
                <Dato etiqueta="Fax" valor={proveedor.Fax} />
                <Dato
                  etiqueta="Sitio web"
                  valor={
                    <a href={proveedor.SitioWeb} target="_blank" rel="noreferrer">
                      {proveedor.SitioWeb}
                    </a>
                  }
                />

                <h4>Pago</h4>
                <Dato etiqueta="Nombre del banco" valor={proveedor.NombreBanco} />
                <Dato etiqueta="Número de cuenta" valor={proveedor.NumeroCuenta} />
                <Dato etiqueta="Días de gracia para pagar" valor={proveedor.DiasPago} />

                <h4>Contactos</h4>
                <Dato
                  etiqueta="Primario"
                  valor={
                    <>
                      {proveedor.ContactoPrimario}
                      <span className="dato-extra">{proveedor.ContactoPrimarioTelefono}</span>
                      <span className="dato-extra">{proveedor.ContactoPrimarioCorreo}</span>
                    </>
                  }
                />
                <Dato
                  etiqueta="Alternativo"
                  valor={
                    proveedor.ContactoAlternativo && (
                      <>
                        {proveedor.ContactoAlternativo}
                        <span className="dato-extra">{proveedor.ContactoAlternativoTelefono}</span>
                        <span className="dato-extra">{proveedor.ContactoAlternativoCorreo}</span>
                      </>
                    )
                  }
                />
              </div>

              {/* Columna derecha: direcciones y mapa */}
              <div>
                <h4>Direcciones</h4>
                <div className="bloques-direccion">
                  <BloqueDireccion
                    titulo="Entrega"
                    linea1={proveedor.DireccionEntrega1}
                    linea2={proveedor.DireccionEntrega2}
                    ciudad={proveedor.CiudadEntrega}
                    codigoPostal={proveedor.CodigoPostalEntrega}
                  />
                  <BloqueDireccion
                    titulo="Postal"
                    linea1={proveedor.DireccionPostal1}
                    linea2={proveedor.DireccionPostal2}
                    ciudad={proveedor.CiudadPostal}
                    codigoPostal={proveedor.CodigoPostalPostal}
                  />
                </div>

                <h4>Localización</h4>
                {proveedor.Latitud !== null ? (
                  <Mapa latitud={proveedor.Latitud} longitud={proveedor.Longitud} />
                ) : (
                  <div className="mensaje info">Este proveedor no tiene una ubicación registrada.</div>
                )}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default DetalleProveedor;
