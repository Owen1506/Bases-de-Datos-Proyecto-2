import { createRoot } from 'react-dom/client';
import App from './App';
import './styles.css';

// React dibuja toda la pagina dentro del div "root" de index.html
createRoot(document.getElementById('root')).render(<App />);
