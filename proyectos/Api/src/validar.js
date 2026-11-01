// Revisa que un parametro sea un numero entero
function esEntero(valor) {
  return Number.isInteger(Number(valor));
}

// Revisa si un campo del formulario viene sin valor
function vacio(valor) {
  return valor === undefined || valor === null || valor === '';
}

module.exports = { esEntero, vacio };
