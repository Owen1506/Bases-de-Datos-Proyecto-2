// Barra de pestañas estilo Windows 11.
// Recibe la lista de modulos, cual esta activo y la funcion para cambiarlo.
function Pestanas({ modulos, moduloActivo, alCambiar }) {
  return (
    <nav className="pestanas">
      {modulos.map((m) => (
        <button
          key={m.id}
          // la pestaña activa lleva la clase "activa" para resaltarla
          className={m.id === moduloActivo ? 'pestana activa' : 'pestana'}
          onClick={() => alCambiar(m.id)}
        >
          {m.nombre}
        </button>
      ))}
    </nav>
  );
}

export default Pestanas;
