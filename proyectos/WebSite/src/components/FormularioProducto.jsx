import { useEffect, useState } from 'react';
import { consultar, enviar } from '../api';

// Valores de un formulario vacio (producto nuevo)
const DATOS_VACIOS = {
  Nombre: '',
  ProveedorID: '',
  Grupos: [],
  ColorID: '',
  Marca: '',
  Tamano: '',
  UnidadEmpaqueID: '',
  EmpaqueExteriorID: '',
  CantidadEmpaquetamiento: '',
  Peso: '',
  PrecioUnitario: '',
  PrecioVenta: '',
  Impuesto: '',
  CantidadDisponible: '',
  Ubicacion: '',
  DiasEntrega: '',
  EsRefrigerado: false,
  CodigoBarras: '',
  ComentariosMarketing: ''
};

// Cambia null por '' para que los campos de texto no den error
function textoOVacio(valor) {
  return valor === null ? '' : valor;
}

// Ventana con el formulario de producto.
// Si productoId es null se crea un producto nuevo; si tiene valor se edita ese producto.
function FormularioProducto({ productoId, alCerrar, alGuardar }) {
  const esNuevo = productoId === null;

  const [datos, setDatos] = useState(DATOS_VACIOS);

  // opciones de los selects y casillas
  const [proveedores, setProveedores] = useState([]);
  const [grupos, setGrupos] = useState([]);
  const [colores, setColores] = useState([]);
  const [empaques, setEmpaques] = useState([]);

  const [cargando, setCargando] = useState(true);
  const [guardando, setGuardando] = useState(false);
  const [error, setError] = useState('');

  // Carga las opciones y, si se esta editando, los datos actuales del producto
  async function cargar() {
    try {
      setProveedores(await consultar('/catalogos/lista-proveedores'));
      setGrupos(await consultar('/catalogos/grupos-inventario'));
      setColores(await consultar('/catalogos/colores'));
      setEmpaques(await consultar('/catalogos/tipos-empaque'));

      if (!esNuevo) {
        const p = await consultar('/inventario/' + productoId);
        setDatos({
          Nombre: p.Nombre,
          ProveedorID: p.ProveedorID,
          // el SP manda los grupos como texto "2,6,4"; se pasan a numeros para marcar las casillas
          Grupos: p.GruposIDs ? p.GruposIDs.split(',').map(Number) : [],
          ColorID: textoOVacio(p.ColorID),
          Marca: textoOVacio(p.Marca),
          Tamano: textoOVacio(p.Tamano),
          UnidadEmpaqueID: p.UnidadEmpaqueID,
          EmpaqueExteriorID: p.EmpaqueExteriorID,
          CantidadEmpaquetamiento: p.CantidadEmpaquetamiento,
          Peso: p.Peso,
          PrecioUnitario: p.PrecioUnitario,
          PrecioVenta: textoOVacio(p.PrecioVenta),
          Impuesto: p.Impuesto,
          CantidadDisponible: p.CantidadDisponible,
          Ubicacion: p.Ubicacion,
          DiasEntrega: p.DiasEntrega,
          EsRefrigerado: p.EsRefrigerado,
          CodigoBarras: textoOVacio(p.CodigoBarras),
          ComentariosMarketing: textoOVacio(p.ComentariosMarketing)
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

  // Marca o desmarca un grupo en la lista de grupos del producto
  function cambiarGrupo(grupoId, marcado) {
    let nuevosGrupos;
    if (marcado) {
      nuevosGrupos = [...datos.Grupos, grupoId];
    } else {
      nuevosGrupos = datos.Grupos.filter((g) => g !== grupoId);
    }
    cambiar('Grupos', nuevosGrupos);
  }

  // Revisa los datos antes de enviarlos. Devuelve el mensaje de error o '' si todo esta bien.
  function validar() {
    if (datos.Nombre.trim() === '') return 'Escriba el nombre del producto.';
    if (datos.ProveedorID === '') return 'Seleccione un proveedor.';
    if (datos.Grupos.length === 0) return 'Marque al menos un grupo.';
    if (datos.UnidadEmpaqueID === '') return 'Seleccione la unidad de empaquetamiento.';
    if (datos.EmpaqueExteriorID === '') return 'Seleccione el empaquetamiento.';
    if (datos.CantidadEmpaquetamiento === '' || Number(datos.CantidadEmpaquetamiento) < 1) return 'La cantidad por empaque debe ser 1 o más.';
    if (datos.Peso === '' || Number(datos.Peso) <= 0) return 'El peso debe ser mayor que cero.';
    if (datos.PrecioUnitario === '' || Number(datos.PrecioUnitario) < 0) return 'Escriba el precio unitario.';
    if (datos.PrecioVenta !== '' && Number(datos.PrecioVenta) < 0) return 'El precio de venta no puede ser negativo.';
    if (datos.Impuesto === '' || Number(datos.Impuesto) < 0 || Number(datos.Impuesto) > 100) return 'El impuesto debe estar entre 0 y 100.';
    if (datos.CantidadDisponible === '' || Number(datos.CantidadDisponible) < 0) return 'La cantidad disponible debe ser 0 o más.';
    if (datos.Ubicacion.trim() === '') return 'Escriba la ubicación en el almacén.';
    if (datos.DiasEntrega === '' || Number(datos.DiasEntrega) < 0) return 'Los días de entrega deben ser 0 o más.';
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
        respuesta = await enviar('/inventario', 'POST', datos);
      } else {
        respuesta = await enviar('/inventario/' + productoId, 'PUT', datos);
      }
      alGuardar(respuesta.mensaje);
    } catch (e) {
      // errores de la API o del SP, por ejemplo "Ya existe un producto con ese nombre."
      setError(e.message);
    }
    setGuardando(false);
  }

  return (
    <div className="fondo-ventana">
      <form className="ventana ventana-formulario" onSubmit={guardar}>
        <div className="ventana-titulo">
          <h3>{esNuevo ? 'Nuevo producto' : 'Editar producto'}</h3>
          <button type="button" className="boton-cerrar" onClick={alCerrar}>✕</button>
        </div>

        <div className="ventana-contenido">
          {error !== '' && <div className="mensaje error">{error}</div>}

          {cargando && <div className="mensaje">Cargando...</div>}

          {!cargando && (
            <>
              <h4>Datos generales</h4>
              <div className="campos">
                <label className="campo-ancho">
                  <span>Nombre <span className="obligatorio">*</span></span>
                  <input type="text" maxLength={100} value={datos.Nombre}
                    onChange={(e) => cambiar('Nombre', e.target.value)} />
                </label>

                <label>
                  <span>Proveedor <span className="obligatorio">*</span></span>
                  <select value={datos.ProveedorID} onChange={(e) => cambiar('ProveedorID', e.target.value)}>
                    <option value="">Seleccione...</option>
                    {proveedores.map((p) => (
                      <option key={p.ProveedorID} value={p.ProveedorID}>{p.Proveedor}</option>
                    ))}
                  </select>
                </label>

                <label>
                  Color
                  <select value={datos.ColorID} onChange={(e) => cambiar('ColorID', e.target.value)}>
                    <option value="">Ninguno</option>
                    {colores.map((c) => (
                      <option key={c.ColorID} value={c.ColorID}>{c.Color}</option>
                    ))}
                  </select>
                </label>

                <label>
                  Marca
                  <input type="text" maxLength={50} value={datos.Marca}
                    onChange={(e) => cambiar('Marca', e.target.value)} />
                </label>

                <label>
                  Talla / tamaño
                  <input type="text" maxLength={20} value={datos.Tamano}
                    onChange={(e) => cambiar('Tamano', e.target.value)} />
                </label>

                {/* Un producto puede estar en varios grupos, por eso son casillas */}
                <div className="campo-ancho">
                  <span className="etiqueta-campo">Grupos <span className="obligatorio">*</span></span>
                  <div className="casillas">
                    {grupos.map((g) => (
                      <label key={g.GrupoID} className="casilla">
                        <input
                          type="checkbox"
                          checked={datos.Grupos.includes(g.GrupoID)}
                          onChange={(e) => cambiarGrupo(g.GrupoID, e.target.checked)}
                        />
                        {g.Grupo}
                      </label>
                    ))}
                  </div>
                </div>
              </div>

              <h4>Empaque</h4>
              <div className="campos">
                <label>
                  <span>Unidad de empaquetamiento <span className="obligatorio">*</span></span>
                  <select value={datos.UnidadEmpaqueID} onChange={(e) => cambiar('UnidadEmpaqueID', e.target.value)}>
                    <option value="">Seleccione...</option>
                    {empaques.map((t) => (
                      <option key={t.TipoEmpaqueID} value={t.TipoEmpaqueID}>{t.TipoEmpaque}</option>
                    ))}
                  </select>
                </label>

                <label>
                  <span>Empaquetamiento <span className="obligatorio">*</span></span>
                  <select value={datos.EmpaqueExteriorID} onChange={(e) => cambiar('EmpaqueExteriorID', e.target.value)}>
                    <option value="">Seleccione...</option>
                    {empaques.map((t) => (
                      <option key={t.TipoEmpaqueID} value={t.TipoEmpaqueID}>{t.TipoEmpaque}</option>
                    ))}
                  </select>
                </label>

                <label>
                  <span>Cantidad por empaque <span className="obligatorio">*</span></span>
                  <input type="number" min="1" step="1" value={datos.CantidadEmpaquetamiento}
                    onChange={(e) => cambiar('CantidadEmpaquetamiento', e.target.value)} />
                </label>

                <label>
                  <span>Peso (kg) <span className="obligatorio">*</span></span>
                  <input type="number" min="0" step="any" value={datos.Peso}
                    onChange={(e) => cambiar('Peso', e.target.value)} />
                </label>
              </div>

              <h4>Precios</h4>
              <div className="campos">
                <label>
                  <span>Precio unitario <span className="obligatorio">*</span></span>
                  <input type="number" min="0" step="0.01" value={datos.PrecioUnitario}
                    onChange={(e) => cambiar('PrecioUnitario', e.target.value)} />
                </label>

                <label>
                  Precio de venta
                  <input type="number" min="0" step="0.01" value={datos.PrecioVenta}
                    onChange={(e) => cambiar('PrecioVenta', e.target.value)} />
                </label>

                <label>
                  <span>Impuesto (%) <span className="obligatorio">*</span></span>
                  <input type="number" min="0" max="100" step="any" value={datos.Impuesto}
                    onChange={(e) => cambiar('Impuesto', e.target.value)} />
                </label>
              </div>

              <h4>Inventario</h4>
              <div className="campos">
                <label>
                  <span>Cantidad disponible <span className="obligatorio">*</span></span>
                  <input type="number" min="0" step="1" value={datos.CantidadDisponible}
                    onChange={(e) => cambiar('CantidadDisponible', e.target.value)} />
                </label>

                <label>
                  <span>Ubicación <span className="obligatorio">*</span></span>
                  <input type="text" maxLength={20} placeholder="Por ejemplo L-1" value={datos.Ubicacion}
                    onChange={(e) => cambiar('Ubicacion', e.target.value)} />
                </label>

                <label>
                  <span>Días de entrega del proveedor <span className="obligatorio">*</span></span>
                  <input type="number" min="0" step="1" value={datos.DiasEntrega}
                    onChange={(e) => cambiar('DiasEntrega', e.target.value)} />
                </label>

                <label>
                  Código de barras
                  <input type="text" maxLength={50} value={datos.CodigoBarras}
                    onChange={(e) => cambiar('CodigoBarras', e.target.value)} />
                </label>

                <label className="casilla">
                  <input type="checkbox" checked={datos.EsRefrigerado}
                    onChange={(e) => cambiar('EsRefrigerado', e.target.checked)} />
                  Necesita refrigeración
                </label>
              </div>

              <h4>Comentarios de mercadeo</h4>
              <div className="campos">
                <label className="campo-ancho">
                  <textarea rows={3} value={datos.ComentariosMarketing}
                    onChange={(e) => cambiar('ComentariosMarketing', e.target.value)} />
                  <span className="ayuda">
                    Las palabras clave del producto se forman con el nombre y estos comentarios.
                  </span>
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

export default FormularioProducto;
