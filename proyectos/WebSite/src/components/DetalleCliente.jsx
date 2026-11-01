import { useEffect, useState } from 'react';
import { consultar } from '../api';
import BloqueDireccion from './BloqueDireccion';
import Dato from './Dato';
import Mapa from './Mapa';

// Ventana con el detalle de un cliente, en dos columnas:
// izquierda la informacion general y los contactos, derecha las direcciones y el mapa
function DetalleCliente({ clienteId, alCerrar }) {
  const [cliente, setCliente] = useState(null);
  const [error, setError] = useState('');

  async function cargar() {
    try {
      setCliente(await consultar('/clientes/' + clienteId));
    } catch (e) {
      setError(e.message);
    }
  }

  // Cuando se abre la ventana se piden los datos del cliente
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
            <h3>{cliente ? cliente.Nombre : 'Detalle del cliente'}</h3>
            {cliente !== null && (
              <span className="badge">{cliente.Categoria}</span>
            )}
          </div>
          <button className="boton-cerrar" onClick={alCerrar}>✕</button>
        </div>

        <div className="ventana-contenido">
          {error !== '' && <div className="mensaje error">{error}</div>}

          {cliente === null && error === '' && <div className="mensaje">Cargando...</div>}

          {cliente !== null && (
            <div className="detalle-dos-columnas">
              {/* Columna izquierda: informacion y contactos */}
              <div>
                <h4>General</h4>
                <Dato etiqueta="Grupo de compra" valor={cliente.GrupoCompra} />
                <Dato etiqueta="Cliente por facturar" valor={cliente.ClienteFacturar} />
                <Dato etiqueta="Método de entrega" valor={cliente.MetodoEntrega} />
                <Dato etiqueta="Días de gracia para pagar" valor={cliente.DiasPago} />
                <Dato etiqueta="Teléfono" valor={cliente.Telefono} />
                <Dato etiqueta="Fax" valor={cliente.Fax} />
                <Dato
                  etiqueta="Sitio web"
                  valor={
                    <a href={cliente.SitioWeb} target="_blank" rel="noreferrer">
                      {cliente.SitioWeb}
                    </a>
                  }
                />

                <h4>Contactos</h4>
                <Dato
                  etiqueta="Primario"
                  valor={
                    <>
                      {cliente.ContactoPrimario}
                      <span className="dato-extra">{cliente.ContactoPrimarioTelefono}</span>
                      <span className="dato-extra">{cliente.ContactoPrimarioCorreo}</span>
                    </>
                  }
                />
                <Dato
                  etiqueta="Alternativo"
                  valor={
                    cliente.ContactoAlternativo && (
                      <>
                        {cliente.ContactoAlternativo}
                        <span className="dato-extra">{cliente.ContactoAlternativoTelefono}</span>
                        <span className="dato-extra">{cliente.ContactoAlternativoCorreo}</span>
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
                    linea1={cliente.DireccionEntrega1}
                    linea2={cliente.DireccionEntrega2}
                    ciudad={cliente.CiudadEntrega + ', ' + cliente.ProvinciaEntrega}
                    codigoPostal={cliente.CodigoPostalEntrega}
                  />
                  <BloqueDireccion
                    titulo="Postal"
                    linea1={cliente.DireccionPostal1}
                    linea2={cliente.DireccionPostal2}
                    ciudad={cliente.CiudadPostal + ', ' + cliente.ProvinciaPostal}
                    codigoPostal={cliente.CodigoPostalPostal}
                  />
                </div>

                <h4>Localización</h4>
                {cliente.Latitud !== null ? (
                  <Mapa latitud={cliente.Latitud} longitud={cliente.Longitud} />
                ) : (
                  <div className="mensaje info">Este cliente no tiene una ubicación registrada.</div>
                )}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default DetalleCliente;
