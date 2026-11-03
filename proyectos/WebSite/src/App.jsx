import { useState } from 'react';
import Pestanas from './components/Pestanas';
import Clientes from './pages/Clientes';
import Proveedores from './pages/Proveedores';
import Estadisticas from './pages/Estadisticas';
import Inventario from './pages/Inventario';
import Ventas from './pages/Ventas';
import Login from './pages/Login';

// Modulos del sitio, cada uno es una pestaña
const MODULOS = [
  { id: 'clientes', nombre: 'Clientes', roles: ['Administrador'] },
  { id: 'proveedores', nombre: 'Proveedores', roles: ['Administrador'] },
  { id: 'inventario', nombre: 'Inventario', roles: ['Administrador'] },
  { id: 'ventas', nombre: 'Ventas', roles: ['Administrador'] },
  { id: 'estadisticas', nombre: 'Estadísticas', roles: ['Corporativo'] }
];

function App() {
  const [usuario, setUsuario] = useState(null);
  const [moduloActivo, setModuloActivo] = useState('clientes');
  const modulosPermitidos = usuario ? MODULOS.filter((modulo) => modulo.roles.includes(usuario.rol)) : [];

  function ingresar(datosUsuario) {
    setUsuario(datosUsuario);
    setModuloActivo(datosUsuario.rol === 'Corporativo' ? 'estadisticas' : 'clientes');
  }

  function salir() {
    setUsuario(null);
    setModuloActivo('clientes');
  }

  // Decide que pagina mostrar segun la pestaña activa.
  // Los modulos que todavia no estan hechos muestran un aviso.
  function mostrarModulo() {
    if (moduloActivo === 'clientes') {
      return <Clientes />;
    }
    if (moduloActivo === 'proveedores') {
      return <Proveedores />;
    }
    if (moduloActivo === 'inventario') {
      return <Inventario />;
    }
    if (moduloActivo === 'ventas') {
      return <Ventas />;
    }
    if (moduloActivo === 'estadisticas') {
      return <Estadisticas />;
    }
    return <div className="mensaje info">Módulo en construcción.</div>;
  }

  if (!usuario) {
    return <Login alIngresar={ingresar} />;
  }

  return (
    <>
      <header className="barra-ventana">
        <div className="barra-titulo">
          <span>Wide World Importers</span>
          <div className="barra-usuario">
            <span>{usuario.fullname} · {usuario.rol}</span>
            <button type="button" className="barra-salir" onClick={salir}>Cerrar sesión</button>
          </div>
        </div>
        <Pestanas modulos={modulosPermitidos} moduloActivo={moduloActivo} alCambiar={setModuloActivo} />
      </header>

      <main className="contenido">
        {modulosPermitidos.some((modulo) => modulo.id === moduloActivo)
          ? mostrarModulo()
          : <div className="mensaje info">No tiene acceso a este módulo.</div>}
      </main>
    </>
  );
}

export default App;
