import { useEffect, useState } from 'react';
import { consultar, enviar } from '../api';
import Buscador from './Buscador';
import { codigoPostalValido, sitioWebValido } from '../validaciones';

// Valores de un formulario vacio (proveedor nuevo)
const DATOS_VACIOS = {
  Nombre: '',
  ReferenciaProveedor: '',
  CategoriaID: '',
  MetodoEntregaID: '',
  DiasPago: '',
  NombreBanco: '',
  NumeroCuenta: '',
  ContactoPrimarioID: null,
  ContactoAlternativoID: null,
  Telefono: '',
  Fax: '',
  SitioWeb: '',
  DireccionEntrega1: '',
  DireccionEntrega2: '',
  CiudadEntregaID: null,
  CodigoPostalEntrega: '',
  DireccionPostal1: '',
  DireccionPostal2: '',
  CiudadPostalID: null,
  CodigoPostalPostal: '',
  Latitud: '',
  Longitud: ''
};

// Cambia null por '' para que los campos de texto no den error
function textoOVacio(valor) {
  return valor === null ? '' : valor;
}

// Ventana con el formulario de proveedor.
// Si proveedorId es null se crea un proveedor nuevo; si tiene valor se edita ese proveedor.
function FormularioProveedor({ proveedorId, alCerrar, alGuardar }) {
  const esNuevo = proveedorId === null;

  const [datos, setDatos] = useState(DATOS_VACIOS);
  // textos que se muestran en los buscadores al editar (nombre de la ciudad, persona...)
  const [textos, setTextos] = useState({});

  const [categorias, setCategorias] = useState([]);
  const [metodos, setMetodos] = useState([]);

  const [cargando, setCargando] = useState(true);
  const [guardando, setGuardando] = useState(false);
  const [error, setError] = useState('');

  // Carga los selects y, si se esta editando, los datos actuales del proveedor
  async function cargar() {
    try {
      setCategorias(await consultar('/catalogos/categorias-proveedor'));
      setMetodos(await consultar('/catalogos/metodos-entrega'));

      if (!esNuevo) {
        const p = await consultar('/proveedores/' + proveedorId);
        setDatos({
          Nombre: p.Nombre,
          ReferenciaProveedor: textoOVacio(p.CodigoProveedor),
          CategoriaID: p.CategoriaID,
          MetodoEntregaID: textoOVacio(p.MetodoEntregaID),
          DiasPago: p.DiasPago,
          NombreBanco: textoOVacio(p.NombreBanco),
          NumeroCuenta: textoOVacio(p.NumeroCuenta),
          ContactoPrimarioID: p.ContactoPrimarioID,
          ContactoAlternativoID: p.ContactoAlternativoID,
          Telefono: p.Telefono,
          Fax: p.Fax,
          SitioWeb: p.SitioWeb,
          DireccionEntrega1: p.DireccionEntrega1,
          DireccionEntrega2: textoOVacio(p.DireccionEntrega2),
          CiudadEntregaID: p.CiudadEntregaID,
          CodigoPostalEntrega: p.CodigoPostalEntrega,
          DireccionPostal1: p.DireccionPostal1,
          DireccionPostal2: textoOVacio(p.DireccionPostal2),
          CiudadPostalID: p.CiudadPostalID,
          CodigoPostalPostal: p.CodigoPostalPostal,
          Latitud: textoOVacio(p.Latitud),
          Longitud: textoOVacio(p.Longitud)
        });
        setTextos({
          ContactoPrimario: p.ContactoPrimario,
          ContactoAlternativo: p.ContactoAlternativo,
          CiudadEntrega: p.CiudadEntrega + ', ' + p.ProvinciaEntrega,
          CiudadPostal: p.CiudadPostal + ', ' + p.ProvinciaPostal
        });
      }
    } catch (e) {
      setError(e.message);
    }
    setCargando(false);
  }

  useEffect(() => {
    cargar();
  }, []);

  // Cambia un solo campo del formulario y deja los demas igual
  function cambiar(campo, valor) {
    setDatos({ ...datos, [campo]: valor });
  }

  // Revisa los datos antes de enviarlos. Devuelve el mensaje de error o '' si todo esta bien.
  function validar() {
    if (datos.Nombre.trim() === '') return 'Escriba el nombre del proveedor.';
    if (datos.CategoriaID === '') return 'Seleccione una categoría.';
    if (datos.DiasPago === '' || Number(datos.DiasPago) < 0) return 'Los días de gracia deben ser 0 o más.';
    if (datos.ContactoPrimarioID === null) return 'Elija de la lista el contacto primario.';
    if (datos.ContactoAlternativoID === null) return 'Elija de la lista el contacto alternativo.';
    if (datos.Telefono.trim() === '') return 'Escriba el teléfono.';
    if (datos.Fax.trim() === '') return 'Escriba el fax.';
    if (datos.SitioWeb.trim() === '') return 'Escriba el sitio web.';
    if (!sitioWebValido(datos.SitioWeb)) return 'El sitio web debe empezar con http:// o https://, por ejemplo http://www.ejemplo.com';
    if (datos.DireccionEntrega1.trim() === '') return 'Escriba la dirección de entrega.';
    if (datos.CiudadEntregaID === null) return 'Elija de la lista la ciudad de entrega.';
    if (!codigoPostalValido(datos.CodigoPostalEntrega)) return 'El código postal de entrega debe tener 5 dígitos.';
    if (datos.DireccionPostal1.trim() === '') return 'Escriba la dirección postal.';
    if (datos.CiudadPostalID === null) return 'Elija de la lista la ciudad postal.';
    if (!codigoPostalValido(datos.CodigoPostalPostal)) return 'El código postal de la dirección postal debe tener 5 dígitos.';
    if ((datos.Latitud === '') !== (datos.Longitud === '')) return 'Escriba la latitud y la longitud, o deje ambas vacías.';
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
        respuesta = await enviar('/proveedores', 'POST', datos);
      } else {
        respuesta = await enviar('/proveedores/' + proveedorId, 'PUT', datos);
      }
      alGuardar(respuesta.mensaje);
    } catch (e) {
      // errores de la API o del SP, por ejemplo "Ya existe un proveedor con ese nombre."
      setError(e.message);
    }
    setGuardando(false);
  }

  return (
    <div className="fondo-ventana">
      <form className="ventana ventana-formulario" onSubmit={guardar}>
        <div className="ventana-titulo">
          <h3>{esNuevo ? 'Nuevo proveedor' : 'Editar proveedor'}</h3>
          <button type="button" className="boton-cerrar" onClick={alCerrar}>✕</button>
        </div>

        <div className="ventana-contenido">
          {error !== '' && <div className="mensaje error">{error}</div>}

          {cargando && <div className="mensaje">Cargando...</div>}

          {!cargando && (
            <>
              <h4>Datos generales</h4>
              <div className="campos">
                <label>
                  <span>Nombre <span className="obligatorio">*</span></span>
                  <input type="text" maxLength={100} value={datos.Nombre}
                    onChange={(e) => cambiar('Nombre', e.target.value)} />
                </label>

                <label>
                  Código del proveedor
                  <input type="text" maxLength={20} value={datos.ReferenciaProveedor}
                    onChange={(e) => cambiar('ReferenciaProveedor', e.target.value)} />
                </label>

                <label>
                  <span>Categoría <span className="obligatorio">*</span></span>
                  <select value={datos.CategoriaID} onChange={(e) => cambiar('CategoriaID', e.target.value)}>
                    <option value="">Seleccione...</option>
                    {categorias.map((c) => (
                      <option key={c.CategoriaID} value={c.CategoriaID}>{c.Categoria}</option>
                    ))}
                  </select>
                </label>

                <label>
                  Método de entrega
                  <select value={datos.MetodoEntregaID} onChange={(e) => cambiar('MetodoEntregaID', e.target.value)}>
                    <option value="">Ninguno</option>
                    {metodos.map((m) => (
                      <option key={m.MetodoEntregaID} value={m.MetodoEntregaID}>{m.MetodoEntrega}</option>
                    ))}
                  </select>
                </label>
              </div>

              <h4>Pago</h4>
              <div className="campos">
                <label>
                  Nombre del banco
                  <input type="text" maxLength={50} value={datos.NombreBanco}
                    onChange={(e) => cambiar('NombreBanco', e.target.value)} />
                </label>

                <label>
                  Número de cuenta
                  <input type="text" maxLength={20} value={datos.NumeroCuenta}
                    onChange={(e) => cambiar('NumeroCuenta', e.target.value)} />
                </label>

                <label>
                  <span>Días de gracia para pagar <span className="obligatorio">*</span></span>
                  <input type="number" min="0" value={datos.DiasPago}
                    onChange={(e) => cambiar('DiasPago', e.target.value)} />
                </label>
              </div>

              <h4>Contacto</h4>
              <div className="campos">
                <Buscador
                  etiqueta="Contacto primario" obligatorio
                  ruta="/catalogos/personas"
                  campoId="PersonaID"
                  campoTexto="Persona"
                  textoInicial={textos.ContactoPrimario || ''}
                  alElegir={(id) => cambiar('ContactoPrimarioID', id)}
                />

                <Buscador
                  etiqueta="Contacto alternativo" obligatorio
                  ruta="/catalogos/personas"
                  campoId="PersonaID"
                  campoTexto="Persona"
                  textoInicial={textos.ContactoAlternativo || ''}
                  alElegir={(id) => cambiar('ContactoAlternativoID', id)}
                />

                <label>
                  <span>Teléfono <span className="obligatorio">*</span></span>
                  <input type="text" maxLength={20} value={datos.Telefono}
                    onChange={(e) => cambiar('Telefono', e.target.value)} />
                </label>

                <label>
                  <span>Fax <span className="obligatorio">*</span></span>
                  <input type="text" maxLength={20} value={datos.Fax}
                    onChange={(e) => cambiar('Fax', e.target.value)} />
                </label>

                <label className="campo-ancho">
                  <span>Sitio web <span className="obligatorio">*</span></span>
                  <input type="text" maxLength={256} placeholder="http://" value={datos.SitioWeb}
                    onChange={(e) => cambiar('SitioWeb', e.target.value)} />
                </label>
              </div>

              <h4>Dirección de entrega</h4>
              <div className="campos">
                <label>
                  <span>Dirección <span className="obligatorio">*</span></span>
                  <input type="text" maxLength={60} value={datos.DireccionEntrega1}
                    onChange={(e) => cambiar('DireccionEntrega1', e.target.value)} />
                </label>

                <label>
                  Dirección (línea 2)
                  <input type="text" maxLength={60} value={datos.DireccionEntrega2}
                    onChange={(e) => cambiar('DireccionEntrega2', e.target.value)} />
                </label>

                <Buscador
                  etiqueta="Ciudad" obligatorio
                  ruta="/catalogos/ciudades"
                  campoId="CiudadID"
                  campoTexto="Ciudad"
                  textoInicial={textos.CiudadEntrega || ''}
                  alElegir={(id) => cambiar('CiudadEntregaID', id)}
                />

                <label>
                  <span>Código postal <span className="obligatorio">*</span></span>
                  <input type="text" maxLength={5} inputMode="numeric" placeholder="5 dígitos" value={datos.CodigoPostalEntrega}
                    onChange={(e) => cambiar('CodigoPostalEntrega', e.target.value)} />
                </label>
              </div>

              <h4>Dirección postal</h4>
              <div className="campos">
                <label>
                  <span>Dirección <span className="obligatorio">*</span></span>
                  <input type="text" maxLength={60} value={datos.DireccionPostal1}
                    onChange={(e) => cambiar('DireccionPostal1', e.target.value)} />
                </label>

                <label>
                  Dirección (línea 2)
                  <input type="text" maxLength={60} value={datos.DireccionPostal2}
                    onChange={(e) => cambiar('DireccionPostal2', e.target.value)} />
                </label>

                <Buscador
                  etiqueta="Ciudad" obligatorio
                  ruta="/catalogos/ciudades"
                  campoId="CiudadID"
                  campoTexto="Ciudad"
                  textoInicial={textos.CiudadPostal || ''}
                  alElegir={(id) => cambiar('CiudadPostalID', id)}
                />

                <label>
                  <span>Código postal <span className="obligatorio">*</span></span>
                  <input type="text" maxLength={5} inputMode="numeric" placeholder="5 dígitos" value={datos.CodigoPostalPostal}
                    onChange={(e) => cambiar('CodigoPostalPostal', e.target.value)} />
                </label>
              </div>

              <h4>Localización (opcional)</h4>
              <div className="campos">
                <label>
                  Latitud
                  <input type="number" step="any" min="-90" max="90" value={datos.Latitud}
                    onChange={(e) => cambiar('Latitud', e.target.value)} />
                </label>

                <label>
                  Longitud
                  <input type="number" step="any" min="-180" max="180" value={datos.Longitud}
                    onChange={(e) => cambiar('Longitud', e.target.value)} />
                </label>
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

export default FormularioProveedor;
