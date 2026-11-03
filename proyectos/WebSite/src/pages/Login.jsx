import { useState } from 'react';
// Datos temporales con la estructura prevista para la tabla de usuarios.
// Las contraseñas están en texto claro solo para probar la interfaz; se retirarán
// cuando el inicio de sesión se valide en la API y SQL Server.


function Login({ alIngresar }) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');


async function ingresar(evento) {
  evento.preventDefault();
  setError('');

  try {
    const respuesta = await fetch('http://localhost:3000/api/auth/login', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        username: username.trim(),
        password: password
      })
    });

    const datos = await respuesta.json();

    if (!respuesta.ok) {
      setError(datos.mensaje || 'No se pudo iniciar sesión.');
      return;
    }

    setPassword('');
    alIngresar(datos.usuario);

  } catch (error) {
    console.error('Error al iniciar sesión:', error);
    setError('No se pudo conectar con el servidor.');
  }
}


  return (
    <main className="login-pagina">
      <section className="login-panel" aria-labelledby="login-titulo">
        <div className="login-marca">Wide World Importers</div>
        <h1 id="login-titulo">Iniciar sesión</h1>
        <p className="descripcion">Ingrese sus credenciales para acceder al sistema.</p>

        <form onSubmit={ingresar}>
          <label htmlFor="login-usuario">Usuario</label>
          <input
            id="login-usuario"
            name="username"
            type="text"
            autoComplete="username"
            required
            autoFocus
            value={username}
            onChange={(evento) => { setUsername(evento.target.value); setError(''); }}
          />

          <label htmlFor="login-password">Contraseña</label>
          <input
            id="login-password"
            name="password"
            type="password"
            autoComplete="current-password"
            required
            value={password}
            onChange={(evento) => { setPassword(evento.target.value); setError(''); }}
          />

          {error && <p className="login-error" role="alert">{error}</p>}
          <button className="boton login-boton" type="submit">Ingresar</button>
        </form>
      </section>
    </main>
  );
}

export default Login;
