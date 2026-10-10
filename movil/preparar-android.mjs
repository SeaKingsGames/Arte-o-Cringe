// Ajusta el proyecto de Android que genera Capacitor antes de compilar:
//  - versionCode: un número que sube solo en cada compilación (Google Play exige que siempre suba).
//  - versionName: la "version" de package.json (la que ven los jugadores).
//  - Firma: si existe la variable AOC_KEYSTORE, la versión release se firma con tu llave.
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const aqui = dirname(fileURLToPath(import.meta.url));
const ruta = join(aqui, 'android', 'app', 'build.gradle');
const pkg = JSON.parse(readFileSync(join(aqui, 'package.json'), 'utf8'));
let g = readFileSync(ruta, 'utf8');

function cambiar(antes, despues, que) {
  if (!antes.test(g)) throw new Error(`No encontré ${que} en build.gradle. ¿Cambió la plantilla de Capacitor?`);
  g = g.replace(antes, despues);
}

const code = parseInt(process.env.VERSION_CODE || '1', 10);
if (!(code >= 1 && code < 2100000000)) throw new Error('VERSION_CODE inválido: ' + process.env.VERSION_CODE);
cambiar(/versionCode \d+/, `versionCode ${code}`, 'versionCode');
cambiar(/versionName "[^"]*"/, `versionName "${pkg.version}"`, 'versionName');

if (process.env.AOC_KEYSTORE) {
  cambiar(/\n    buildTypes \{/, `
    signingConfigs {
        release {
            storeFile file(System.getenv("AOC_KEYSTORE"))
            storePassword System.getenv("AOC_KEYSTORE_PASSWORD")
            keyAlias System.getenv("AOC_KEY_ALIAS")
            keyPassword System.getenv("AOC_KEYSTORE_PASSWORD")
        }
    }
    buildTypes {`, 'buildTypes');
  cambiar(/(\n        release \{\n)(?!            storeFile)/, '$1            signingConfig signingConfigs.release\n', 'buildTypes.release');
}

writeFileSync(ruta, g);
console.log(`Android listo: versionCode ${code}, versionName ${pkg.version}, ${process.env.AOC_KEYSTORE ? 'con firma' : 'sin firma (solo APK de prueba)'}`);
