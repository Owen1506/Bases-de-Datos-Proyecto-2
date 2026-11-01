import { useEffect, useState } from 'react';
import { consultar, enviar } from '../api';
import { formatoFecha } from '../formato';
import Buscador from './Buscador';

// Una linea vacia de la factura
const LINEA_VACIA = { ProductoID: '', Cantidad: '', PrecioUnitario: '' };

// Valores de un formulario vacio (factura nueva)
const DATOS_VACIOS = {
  ClienteID: null,
  ContactoID: '',
  MetodoEntregaID: '',
  VendedorID: '',
  Fecha: '',
  NumeroOrdenCliente: '',
  InstruccionesEntrega: '',
  Lineas: [LINEA_VACIA]
};

// Ventana con el formulario de factura.
// Si facturaId es null se crea una factura nueva; si tiene valor se edita esa factura.
// Los impuestos y totales no se calculan aqui: los calcula el SP al guardar.
function FormularioVenta({ facturaId, alCerrar, alGuardar }) {
  const esNuevo = facturaId === null;

  const [datos, setDatos] = useState(DATOS_VACIOS);
  const [textoCliente, setTextoCliente] = useState(''); // nombre del cliente en el buscador

  // opciones de los selects
  const [contactos, setContactos] = useState([]); // dependen del cliente elegido
  const [metodos, setMetodos] = useState([]);
  const [vendedores, setVendedores] = useState([]);
  const [productos, setProductos] = useState([]);

  const [cargando, setCargando] = useState(true);
  const [guardando, setGuardando] = useState(false);
  const [error, setError] = useState('');

  // Carga los selects y, si se esta editando, los datos actuales de la factura
  async function cargar() {
    try {
      setMetodos(await consultar('/catalogos/metodos-entrega'));
      setVendedores(await consultar('/catalogos/vendedores'));
      setProductos(await consultar('/catalogos/lista-productos'));

      if (!esNuevo) {
        const factura = await consultar('/ventas/' + facturaId);
        const e = factura.encabezado;

        // solo se necesitan producto, cantidad y precio de cada linea
        const lineas = [];
        for (const l of factura.lineas) {
          lineas.push({ ProductoID: l.ProductoID, Cantidad: l.Cantidad, PrecioUnitario: l.PrecioUnitario });
        }

        setDatos({
          ClienteID: e.ClienteID,
          ContactoID: e.ContactoID,
          MetodoEntregaID: e.MetodoEntregaID,
          VendedorID: e.VendedorID,
          Fecha: formatoFecha(e.Fecha),
          NumeroOrdenCliente: e.NumeroOrdenCliente === null ? '' : e.NumeroOrdenCliente,
          InstruccionesEntrega: e.InstruccionesEntrega === null ? '' : e.InstruccionesEntrega,
          Lineas: lineas
        });
        setTextoCliente(e.Cliente);
        setContactos(await consultar('/catalogos/contactos-cliente?clienteId=' + e.ClienteID));
      }
    } catch (e) {
      setError(e.message);
    }
    setCargando(false);
  }

  useEffect(() => {
    cargar();
  }, []);

  // Cambia un solo campo del encabezado y deja los demas igual
  function cambiar(campo, valor) {
    setDatos({ ...datos, [campo]: valor });
  }

  // Al elegir un cliente se cargan sus contactos (primario y alternativo)
  async function elegirCliente(id, texto) {
    setTextoCliente(texto);
    setDatos({ ...datos, ClienteID: id, ContactoID: '' });

    if (id === null) {
      setContactos([]);
      return;
    }
    try {
      setContactos(await consultar('/catalogos/contactos-cliente?clienteId=' + id));
    } catch (e) {
      setError(e.message);
    }
  }

  // ---------- Lineas de la factura ----------

  function agregarLinea() {
    setDatos({ ...datos, Lineas: [...datos.Lineas, LINEA_VACIA] });
  }

  function quitarLinea(indice) {
    const nuevas = datos.Lineas.filter((linea, i) => i !== indice);
    setDatos({ ...datos, Lineas: nuevas });
  }

  // Cambia un campo de una linea. Al elegir un producto se propone su precio unitario.
  function cambiarLinea(indice, campo, valor) {
    const nuevas = datos.Lineas.map((linea, i) => {
      if (i !== indice) return linea;

      const cambiada = { ...linea, [campo]: valor };
      if (campo === 'ProductoID') {
        const producto = productos.find((p) => p.ProductoID === Number(valor));
        cambiada.PrecioUnitario = producto ? producto.PrecioUnitario : '';
      }
      return cambiada;
    });
    setDatos({ ...datos, Lineas: nuevas });
  }

  // Revisa los datos antes de enviarlos. Devuelve el mensaje de error o '' si todo esta bien.
  function validar() {
    if (datos.ClienteID === null) return 'Elija de la lista el cliente.';
    if (datos.ContactoID === '') return 'Seleccione la persona de contacto.';
    if (datos.MetodoEntregaID === '') return 'Seleccione el método de entrega.';
    if (datos.VendedorID === '') return 'Seleccione el vendedor.';
    if (datos.Fecha === '') return 'Seleccione la fecha de la factura.';
    if (datos.Lineas.length === 0) return 'Agregue al menos un producto.';

    for (let i = 0; i < datos.Lineas.length; i++) {
      const linea = datos.Lineas[i];
      const numero = i + 1;
      if (linea.ProductoID === '') return 'Seleccione el producto de la línea ' + numero + '.';
      if (linea.Cantidad === '' || Number(linea.Cantidad) < 1 || !Number.isInteger(Number(linea.Cantidad))) {
        return 'La cantidad de la línea ' + numero + ' debe ser un número entero mayor que cero.';
      }
      if (linea.PrecioUnitario === '' || Number(linea.PrecioUnitario) < 0) {
        return 'El precio de la línea ' + numero + ' debe ser 0 o más.';
      }
    }
    return '';
  }

  async function guardar(evento) {
    evento.preventDefault();

    const mensajeError = validar();
    if (mensajeError !== '') {
      setError(mensajeError);
      return;
    }

    setGuardando(true);
    setError('');
    try {
      let respuesta;
      if (esNuevo) {
        respuesta = await enviar('/ventas', 'POST', datos);
      } else {
        respuesta = await enviar('/ventas/' + facturaId, 'PUT', datos);
      }
      alGuardar(respuesta.mensaje);
    } catch (e) {
      // errores de la API o del SP, por ejemplo un contacto que no es del cliente
      setError(e.message);
    }
    setGuardando(false);
  }

  return (
    <div className="fondo-ventana">
      <form className="ventana ventana-ancha" onSubmit={guardar}>
        <div className="ventana-titulo">
          <h3>{esNuevo ? 'Nueva factura' : 'Editar factura #' + facturaId}</h3>
          <button type="button" className="boton-cerrar" onClick={alCerrar}>✕</button>
        </div>

        <div className="ventana-contenido">
          {error !== '' && <div className="mensaje error">{error}</div>}

          {cargando && <div className="mensaje">Cargando...</div>}

          {!cargando && (
            <>
              <h4>Encabezado</h4>
              <div className="campos">
                {/* el key hace que el buscador arranque con el nombre del cliente al editar */}
                <Buscador
                  key={'cliente-' + (esNuevo ? 'nuevo' : facturaId)}
                  etiqueta="Cliente"
                  obligatorio
                  ruta="/catalogos/clientes"
                  campoId="ClienteID"
                  campoTexto="Cliente"
                  textoInicial={textoCliente}
                  alElegir={elegirCliente}
                />

                <label>
                  <span>Persona de contacto <span className="obligatorio">*</span></span>
                  <select value={datos.ContactoID} onChange={(e) => cambiar('ContactoID', e.target.value)}
                    disabled={contactos.length === 0}>
                    <option value="">{contactos.length === 0 ? 'Primero elija el cliente' : 'Seleccione...'}</option>
                    {contactos.map((c) => (
                      <option key={c.ContactoID} value={c.ContactoID}>{c.Contacto} ({c.Tipo})</option>
                    ))}
                  </select>
                </label>

                <label>
                  <span>Método de entrega <span className="obligatorio">*</span></span>
                  <select value={datos.MetodoEntregaID} onChange={(e) => cambiar('MetodoEntregaID', e.target.value)}>
                    <option value="">Seleccione...</option>
                    {metodos.map((m) => (
                      <option key={m.MetodoEntregaID} value={m.MetodoEntregaID}>{m.MetodoEntrega}</option>
                    ))}
                  </select>
                </label>

                <label>
                  <span>Vendedor <span className="obligatorio">*</span></span>
                  <select value={datos.VendedorID} onChange={(e) => cambiar('VendedorID', e.target.value)}>
                    <option value="">Seleccione...</option>
                    {vendedores.map((v) => (
                      <option key={v.VendedorID} value={v.VendedorID}>{v.Vendedor}</option>
                    ))}
                  </select>
                </label>

                <label>
                  <span>Fecha <span className="obligatorio">*</span></span>
                  <input type="date" value={datos.Fecha} onChange={(e) => cambiar('Fecha', e.target.value)} />
                </label>

                <label>
                  Número de orden del cliente
                  <input type="text" maxLength={20} value={datos.NumeroOrdenCliente}
                    onChange={(e) => cambiar('NumeroOrdenCliente', e.target.value)} />
                </label>

                <label className="campo-ancho">
                  Instrucciones de entrega
                  <textarea rows={2} value={datos.InstruccionesEntrega}
                    onChange={(e) => cambiar('InstruccionesEntrega', e.target.value)} />
                </label>
              </div>

              <h4>Productos <span className="obligatorio">*</span></h4>
              <div className="tabla-contenedor-lineas">
                <table className="tabla tabla-simple tabla-lineas">
                  <thead>
                    <tr>
                      <th>Producto</th>
                      <th>Cantidad</th>
                      <th>Precio unitario</th>
                      <th></th>
                    </tr>
                  </thead>
                  <tbody>
                    {datos.Lineas.map((linea, indice) => (
                      <tr key={indice}>
                        <td>
                          <select value={linea.ProductoID}
                            onChange={(e) => cambiarLinea(indice, 'ProductoID', e.target.value)}>
                            <option value="">Seleccione...</option>
                            {productos.map((p) => (
                              <option key={p.ProductoID} value={p.ProductoID}>{p.Producto}</option>
                            ))}
                          </select>
                        </td>
                        <td>
                          <input type="number" min="1" step="1" value={linea.Cantidad}
                            onChange={(e) => cambiarLinea(indice, 'Cantidad', e.target.value)} />
                        </td>
                        <td>
                          <input type="number" min="0" step="0.01" value={linea.PrecioUnitario}
                            onChange={(e) => cambiarLinea(indice, 'PrecioUnitario', e.target.value)} />
                        </td>
                        <td>
                          <button type="button" className="boton-icono peligro" title="Quitar línea"
                            onClick={() => quitarLinea(indice)} disabled={datos.Lineas.length === 1}>
                            ✕
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              <div className="lineas-pie">
                <button type="button" className="boton secundario" onClick={agregarLinea}>
                  + Agregar producto
                </button>
                <span className="ayuda">El impuesto y los totales los calcula la base de datos al guardar.</span>
              </div>
            </>
          )}
        </div>

        <div className="ventana-pie">
          <span className="nota"><span className="obligatorio">*</span> Campos obligatorios</span>
          <button type="button" className="boton secundario" onClick={alCerrar}>Cancelar</button>
          <button type="submit" className="boton" disabled={cargando || guardando}>
            {guardando ? 'Guardando...' : 'Guardar'}
          </button>
        </div>
      </form>
    </div>
  );
}

export default FormularioVenta;
