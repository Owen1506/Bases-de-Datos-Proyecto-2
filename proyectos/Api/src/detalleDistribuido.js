const { ejecutarSPCorporativo } = require('./dbNodos');

async function completarDetalle(entidad, publico) {
  const id = entidad === 'Clientes' ? 'ClienteID' : 'ProveedorID';
  try {
    const privados = await ejecutarSPCorporativo(`dbo.usp_Api_${entidad}_Privado`, { [id]: publico[id] });
    return { ...publico, ...privados[0], ContactoDisponible: privados.length > 0 };
  } catch (error) {
    if (error.estado !== 503) throw error;
    return { ...publico, ContactoDisponible: false };
  }
}
async function completarContactoVenta(encabezado) {
  try {
    const filas = await ejecutarSPCorporativo('dbo.usp_Api_Contacto', { PersonaID: encabezado.ContactoID });
    encabezado.Contacto = filas[0]?.Contacto ?? null;
    encabezado.ContactoDisponible = filas.length > 0;
  } catch (error) {
    if (error.estado !== 503) throw error;
    encabezado.Contacto = null;
    encabezado.ContactoDisponible = false;
  }
}
module.exports = { completarDetalle, completarContactoVenta };
