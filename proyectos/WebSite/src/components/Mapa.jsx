// Muestra un mapa de Google Maps centrado en la latitud y longitud que se le pasan
function Mapa({ latitud, longitud }) {
  const url = 'https://maps.google.com/maps?q=' + latitud + ',' + longitud + '&z=14&output=embed';

  return (
    <iframe
      title="Mapa de localización"
      className="mapa"
      src={url}
      loading="lazy"
    ></iframe>
  );
}

export default Mapa;
