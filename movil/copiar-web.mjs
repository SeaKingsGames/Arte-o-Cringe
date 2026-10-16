// Copia el juego (los mismos archivos que publica Vercel) a la carpeta www de la app.
import { mkdirSync, copyFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const aqui = dirname(fileURLToPath(import.meta.url));
const raiz = join(aqui, '..');
const www = join(aqui, 'www');
mkdirSync(www, { recursive: true });
for (const f of ['index.html', 'config.js', 'terminos.html', 'privacidad.html', 'icono.png']) {
  if (!existsSync(join(raiz, f))) continue;
  copyFileSync(join(raiz, f), join(www, f));
  console.log('copiado', f);
}
