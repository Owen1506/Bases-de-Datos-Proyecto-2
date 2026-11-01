// Validaciones de formato que usan los formularios de clientes y proveedores.
// Los SP revisan lo mismo; aqui solo se avisa antes de enviar.

// El sitio web debe empezar con http:// o https://, tener un punto y no tener espacios
export function sitioWebValido(url) {
  const texto = url.trim();
  const empiezaBien = texto.startsWith('http://') || texto.startsWith('https://');
  return empiezaBien && texto.includes('.') && !texto.includes(' ');
}

// El codigo postal debe tener exactamente 5 digitos (todos los de la base son asi)
export function codigoPostalValido(codigo) {
  const texto = codigo.trim();
  if (texto.length !== 5) return false;

  for (const caracter of texto) {
    if (caracter < '0' || caracter > '9') return false;
  }
  return true;
}
