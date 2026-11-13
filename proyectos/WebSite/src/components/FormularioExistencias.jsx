import { useEffect, useState } from 'react';
import { consultar, enviar } from '../api';

// Ventana para cambiar la cantidad y la ubicación del producto en la sucursal del usuario
function FormularioExistencias({ productoId, alCerrar, alGuardar }) {
  const [nombre, setNombre] = useState('');
  const [cantidad, setCantidad] = useState('');
  const [ubicacion, setUbicacion] = useState('');

  const [cargando, setCargando] = useState(true);
  const [guardando, setGuardando] = useState(false);
  const [error, setError] = useState('');

  // Carga la cantidad y la ubicación actuales de esta sucursal
  async function cargar() {
    try {
      const p = await consultar('/inventario/' + productoId);
      setNombre(p.Nombre);
      setCantidad(p.CantidadDisponible);
      setUbicacion(p.Ubicacion === null ? '' : p.Ubicacion);
    } catch (e) {
      setError(e.message);
    }
    setCargando(false);
  }

  useEffect(() => {
    cargar();
  }, []);

  async function guardar(evento) {
    evento.preventDefault();

    if (cantidad === '' || Number(cantidad) < 0 || !Number.isInteger(Number(cantidad))) {
      setError('La cantidad disponible debe ser un número entero de 0 o más.');
      return;
    }

    setGuardando(true);
    setError('');
    try {
      const respuesta = await enviar('/inventario/' + productoId + '/existencias', 'PUT', {
        CantidadDisponible: cantidad,
        Ubicacion: ubicacion
      });
      alGuardar(respuesta.mensaje);
    } catch (e) {
      setError(e.message);
    }
    setGuardando(false);
  }

  return (
    <div className="fondo-ventana">
      <form className="ventana ventana-formulario" onSubmit={guardar}>
        <div className="ventana-titulo">
          <h3>Inventario de la sucursal{nombre !== '' && ': ' + nombre}</h3>
          <button type="button" className="boton-cerrar" onClick={alCerrar}>✕</button>
        </div>

        <div className="ventana-contenido">
          {error !== '' && <div className="mensaje error">{error}</div>}

          {cargando && <div className="mensaje">Cargando...</div>}

          {!cargando && (
            <div className="campos">
              <label>
                <span>Cantidad disponible <span className="obligatorio">*</span></span>
                <input type="number" min="0" step="1" value={cantidad}
                  onChange={(e) => setCantidad(e.target.value)} />
              </label>

              <label>
                Ubicación
                <input type="text" maxLength={20} placeholder="Por ejemplo L-1" value={ubicacion}
                  onChange={(e) => setUbicacion(e.target.value)} />
              </label>
            </div>
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

export default FormularioExistencias;
