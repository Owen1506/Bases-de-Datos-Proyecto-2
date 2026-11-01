import { useEffect, useState } from 'react';
import { consultar, enviar } from '../api';
import Buscador from '../components/Buscador';
import DetalleProducto from '../components/DetalleProducto';
import FormularioProducto from '../components/FormularioProducto';
import Paginacion from '../components/Paginacion';
import { ICONO_BASURERO, ICONO_LAPIZ } from '../components/Iconos';

// Cantidad de productos por pagina. Debe ser igual al @TamanoPagina del SP.
const TAMANO_PAGINA = 10;

const FILTROS_VACIOS = { nombre: '', grupoId: '', cantidadMin: '', cantidadMax: '' };

function Inventario() {
  // lo que el usuario va escribiendo en los filtros
  const [nombre, setNombre] = useState('');
  const [grupoId, setGrupoId] = useState('');
  const [cantidadMin, setCantidadMin] = useState('');
  const [cantidadMax, setCantidadMax] = useState('');

  // filtros de la ultima busqueda, se usan al cambiar de pagina
  const [filtrosAplicados, setFiltrosAplicados] = useState(FILTROS_VACIOS);

  const [grupos, setGrupos] = useState([]);

  const [productos, setProductos] = useState([]);
  const [pagina, setPagina] = useState(1);
  const [total, setTotal] = useState(0);
  const [cargando, setCargando] = useState(false);
  const [error, setError] = useState('');

  // producto seleccionado en la tabla (null = ventana de detalle cerrada)
  const [productoId, setProductoId] = useState(null);

  // cambia cada vez que se restauran los filtros, para vaciar el buscador de nombre
  const [reinicios, setReinicios] = useState(0);

  const [formularioAbierto, setFormularioAbierto] = useState(false);
  const [productoEditarId, setProductoEditarId] = useState(null); // null = producto nuevo
  const [exito, setExito] = useState('');

  async function cargarGrupos() {
    try {
      setGrupos(await consultar('/catalogos/grupos-inventario'));
    } catch (e) {
      setError(e.message);
    }
  }

  // Le pide a la API una pagina de productos con los filtros indicados.
  // El filtrado, el orden y la paginacion los hace el stored procedure.
  async function buscar(filtros, numeroPagina) {
    let ruta = '/inventario?pagina=' + numeroPagina;
    if (filtros.nombre.trim() !== '') {
      ruta += '&nombre=' + encodeURIComponent(filtros.nombre.trim());
    }
    if (filtros.grupoId !== '') {
      ruta += '&grupoId=' + filtros.grupoId;
    }
    if (filtros.cantidadMin !== '') ruta += '&cantidadMin=' + filtros.cantidadMin;
    if (filtros.cantidadMax !== '') ruta += '&cantidadMax=' + filtros.cantidadMax;

    setCargando(true);
    setError('');
    try {
      const datos = await consultar(ruta);
      setProductos(datos);
      // el total viene repetido en cada fila; si no hay filas es 0
      if (datos.length > 0) {
        setTotal(datos[0].TotalRegistros);
      } else {
        setTotal(0);
      }
      setFiltrosAplicados(filtros);
      setPagina(numeroPagina);
    } catch (e) {
      setProductos([]);
      setTotal(0);
      setError(e.message);
    }
    setCargando(false);
  }

  // Al abrir la pagina se carga el select y la primera pagina de productos
  useEffect(() => {
    cargarGrupos();
    buscar(FILTROS_VACIOS, 1);
  }, []);

  // Revisa el rango de cantidad antes de buscar. Devuelve el mensaje de error o '' si esta bien.
  function validarFiltros() {
    if (cantidadMin !== '' && (Number(cantidadMin) < 0 || !Number.isInteger(Number(cantidadMin)))) {
      return 'La cantidad mínima debe ser un número entero de 0 o más.';
    }
    if (cantidadMax !== '' && (Number(cantidadMax) < 0 || !Number.isInteger(Number(cantidadMax)))) {
      return 'La cantidad máxima debe ser un número entero de 0 o más.';
    }
    if (cantidadMin !== '' && cantidadMax !== '' && Number(cantidadMin) > Number(cantidadMax)) {
      return 'La cantidad mínima no puede ser mayor que la cantidad máxima.';
    }
    return '';
  }

  // Una busqueda nueva siempre empieza en la pagina 1
  function alBuscar(evento) {
    evento.preventDefault(); // evita que el formulario recargue la pagina
    setExito('');

    const mensajeError = validarFiltros();
    if (mensajeError !== '') {
      setError(mensajeError);
      return;
    }

    buscar({ nombre, grupoId, cantidadMin, cantidadMax }, 1);
  }

  function restaurar() {
    setNombre('');
    setReinicios(reinicios + 1);
    setGrupoId('');
    setCantidadMin('');
    setCantidadMax('');
    setExito('');
    buscar(FILTROS_VACIOS, 1);
  }

  // Cambiar de pagina mantiene los filtros de la ultima busqueda
  function cambiarPagina(numero) {
    buscar(filtrosAplicados, numero);
  }

  function abrirNuevo() {
    setProductoEditarId(null);
    setFormularioAbierto(true);
  }

  function abrirEditar(evento, id) {
    evento.stopPropagation(); // evita que el clic tambien abra el detalle
    setProductoEditarId(id);
    setFormularioAbierto(true);
  }

  // Cuando el formulario guarda bien: se cierra, se muestra el mensaje y se recarga la tabla
  function alGuardar(mensaje) {
    setFormularioAbierto(false);
    setExito(mensaje);
    buscar(filtrosAplicados, pagina);
  }

  async function eliminar(evento, producto) {
    evento.stopPropagation(); // evita que el clic tambien abra el detalle

    if (!window.confirm('¿Seguro que desea eliminar "' + producto.Nombre + '"?')) {
      return;
    }

    setExito('');
    try {
      const respuesta = await enviar('/inventario/' + producto.ProductoID, 'DELETE', {});
      setExito(respuesta.mensaje);
      buscar(filtrosAplicados, pagina);
    } catch (e) {
      // por ejemplo: "No se puede eliminar el producto porque tiene registros asociados."
      setError(e.message);
    }
  }

  return (
    <>
      <div className="titulo-modulo">
        <div>
          <h2>Inventario</h2>
          <p className="descripcion">Busque productos y haga clic en uno para ver su detalle.</p>
        </div>
        <button className="boton" onClick={abrirNuevo}>+ Nuevo producto</button>
      </div>

      <div className="modulo-columnas">
        {/* Panel izquierdo: filtros */}
        <form className="panel panel-filtros" onSubmit={alBuscar}>
          <h3>Filtros</h3>

          {/* Texto libre con sugerencias: no hace falta elegir una, se busca con lo escrito.
              El key cambia al restaurar los filtros y eso vacia el campo */}
          <Buscador
            key={reinicios}
            etiqueta="Nombre del producto"
            ruta="/catalogos/productos"
            campoId="ProductoID"
            campoTexto="Producto"
            textoInicial=""
            placeholder="Escriba parte del nombre"
            alElegir={(id, texto) => setNombre(texto)}
          />

          <label>
            Grupo
            <select value={grupoId} onChange={(e) => setGrupoId(e.target.value)}>
              <option value="">Todos</option>
              {grupos.map((g) => (
                <option key={g.GrupoID} value={g.GrupoID}>
                  {g.Grupo}
                </option>
              ))}
            </select>
          </label>

          {/* Rango de cantidad disponible */}
          <div className="rango">
            <label>
              Cantidad mínima
              <input type="number" min="0" step="1" value={cantidadMin} onChange={(e) => setCantidadMin(e.target.value)} />
            </label>
            <label>
              Cantidad máxima
              <input type="number" min="0" step="1" value={cantidadMax} onChange={(e) => setCantidadMax(e.target.value)} />
            </label>
          </div>

          <button type="submit" className="boton">Buscar</button>
          <button type="button" className="boton secundario" onClick={restaurar}>
            Restaurar filtros
          </button>
        </form>

        {/* Area principal: tabla y paginacion */}
        <div className="panel panel-resultados">
          {exito !== '' && <div className="mensaje exito">{exito}</div>}

          {error !== '' && <div className="mensaje error">{error}</div>}

          {cargando && <div className="mensaje">Cargando...</div>}

          {!cargando && error === '' && productos.length === 0 && (
            <div className="mensaje info">No se encontraron productos con esos filtros.</div>
          )}

          {!cargando && productos.length > 0 && (
            <>
              <table className="tabla">
                <thead>
                  <tr>
                    <th>Nombre</th>
                    <th>Grupo</th>
                    <th className="numero">Cantidad disponible</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  {productos.map((p) => (
                    <tr key={p.ProductoID} onClick={() => setProductoId(p.ProductoID)}>
                      <td>{p.Nombre}</td>
                      <td>{p.Grupo}</td>
                      <td className="numero">{p.CantidadDisponible.toLocaleString()}</td>
                      {/* estos botones solo se ven al pasar el mouse por la fila (ver styles/tabla.css) */}
                      <td className="acciones">
                        <button className="boton-icono" title="Editar" onClick={(e) => abrirEditar(e, p.ProductoID)}>
                          {ICONO_LAPIZ}
                        </button>
                        <button className="boton-icono peligro" title="Eliminar" onClick={(e) => eliminar(e, p)}>
                          {ICONO_BASURERO}
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>

              <Paginacion
                pagina={pagina}
                total={total}
                tamano={TAMANO_PAGINA}
                cantidadFilas={productos.length}
                elementos="productos"
                alCambiar={cambiarPagina}
              />
            </>
          )}
        </div>
      </div>

      {productoId !== null && (
        <DetalleProducto productoId={productoId} alCerrar={() => setProductoId(null)} />
      )}

      {formularioAbierto && (
        <FormularioProducto
          productoId={productoEditarId}
          alCerrar={() => setFormularioAbierto(false)}
          alGuardar={alGuardar}
        />
      )}
    </>
  );
}

export default Inventario;
