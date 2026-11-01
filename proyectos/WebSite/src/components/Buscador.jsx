import { useState } from 'react';
import { consultar } from '../api';

// Campo de texto con sugerencias, para elegir entre muchas opciones (ciudades, personas...).
// Mientras el usuario escribe se piden a la API las coincidencias y se muestran en una lista.
// Al hacer clic en una opcion se avisa su ID con alElegir.
//
// ruta: ruta del buscador en la API, por ejemplo '/catalogos/ciudades'
// campoId y campoTexto: nombres de las columnas que devuelve el SP
// ayuda: texto pequeño opcional debajo del campo
// obligatorio: si es true se muestra el asterisco rojo junto a la etiqueta
// placeholder: texto de ejemplo dentro del campo (opcional)
function Buscador({ etiqueta, ruta, campoId, campoTexto, textoInicial, alElegir, ayuda, obligatorio, placeholder }) {
  const [texto, setTexto] = useState(textoInicial);
  const [opciones, setOpciones] = useState([]);

  async function alEscribir(valor) {
    setTexto(valor);
    // si cambia el texto, la opcion elegida antes ya no vale;
    // tambien se avisa el texto, para saber si quedo algo escrito sin elegir
    alElegir(null, valor);

    // con menos de 2 letras no se busca
    if (valor.trim().length < 2) {
      setOpciones([]);
      return;
    }

    try {
      setOpciones(await consultar(ruta + '?texto=' + encodeURIComponent(valor.trim())));
    } catch (e) {
      setOpciones([]);
    }
  }

  function elegir(opcion) {
    setTexto(opcion[campoTexto]);
    setOpciones([]);
    alElegir(opcion[campoId], opcion[campoTexto]);
  }

  return (
    <label className="buscador">
      <span>
        {etiqueta} {obligatorio && <span className="obligatorio">*</span>}
      </span>
      <input
        type="text"
        value={texto}
        maxLength={100}
        placeholder={placeholder ? placeholder : 'Escriba al menos 2 letras'}
        onChange={(e) => alEscribir(e.target.value)}
        onBlur={() => setOpciones([])} // al salir del campo se cierra la lista
      />

      {ayuda && <span className="ayuda">{ayuda}</span>}

      {opciones.length > 0 && (
        <ul className="buscador-opciones">
          {opciones.map((o) => (
            // onMouseDown y no onClick: ocurre antes del onBlur, asi la opcion se elige antes de cerrar la lista
            <li key={o[campoId]} onMouseDown={() => elegir(o)}>
              {o[campoTexto]}
            </li>
          ))}
        </ul>
      )}
    </label>
  );
}

export default Buscador;
