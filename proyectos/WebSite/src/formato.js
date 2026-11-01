// Funciones para mostrar los datos con formato (no cambian los datos, solo como se ven)

// 2645.5 -> "$2,645.50"
export function formatoMonto(valor) {
  return '$' + Number(valor).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

// "2013-01-01T00:00:00.000Z" -> "2013-01-01"
export function formatoFecha(valor) {
  return String(valor).substring(0, 10);
}
