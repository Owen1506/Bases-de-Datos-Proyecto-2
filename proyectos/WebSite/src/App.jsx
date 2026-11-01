import { useState } from 'react';
import Pestanas from './components/Pestanas';
import Clientes from './pages/Clientes';
import Proveedores from './pages/Proveedores';
import Estadisticas from './pages/Estadisticas';
import Inventario from './pages/Inventario';
import Ventas from './pages/Ventas';

// Modulos del sitio, cada uno es una pestaña
const MODULOS = [
  { id: 'clientes', nombre: 'Clientes' },
  { id: 'proveedores', nombre: 'Proveedores' },
  { id: 'inventario', nombre: 'Inventario' },
  { id: 'ventas', nombre: 'Ventas' },
  { id: 'estadisticas', nombre: 'Estadísticas' }
];

function App() {
  const [moduloActivo, setModuloActivo] = useState('clientes');

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

  return (
    <>
      <header className="barra-ventana">
        <div className="barra-titulo">Wide World Importers</div>
        <Pestanas modulos={MODULOS} moduloActivo={moduloActivo} alCambiar={setModuloActivo} />
      </header>

      <main className="contenido">{mostrarModulo()}</main>
    </>
  );
}

export default App;
