// Filtro de sucursal de las estadísticas.
// Vacío = consolidado (las dos sucursales juntas); el valor es la SucursalID.
function SelectorSucursal({ valor, alCambiar }) {
  return (
    <label>
      Sucursal
      <select value={valor} onChange={(e) => alCambiar(e.target.value)}>
        <option value="">Consolidado</option>
        <option value="1">San José</option>
        <option value="2">Limón</option>
      </select>
    </label>
  );
}

export default SelectorSucursal;
