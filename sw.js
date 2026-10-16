// Service worker de Arte o Cringe.
// Sirve para que Chrome y Edge dejen instalar el juego en PC y para abrirlo aunque el internet falle un momento.
// Siempre pide primero a internet, así cada cambio que subes a Vercel se ve al instante.
// Solo guarda archivos de tu propio sitio; Supabase y las fuentes van directo, sin pasar por aquí.
const CACHE = 'aoc-1';

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (e) => {
  e.waitUntil((async () => {
    for (const k of await caches.keys()) if (k !== CACHE) await caches.delete(k);
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  const url = new URL(req.url);
  if (req.method !== 'GET' || url.origin !== self.location.origin) return;
  // Las páginas se guardan sin el ?sala=ABCD, para no llenar la memoria con una copia por sala.
  const clave = req.mode === 'navigate' ? url.origin + url.pathname : req;
  e.respondWith((async () => {
    try {
      const res = await fetch(req);
      if (res.ok && res.type === 'basic') {
        const copia = res.clone();
        caches.open(CACHE).then((c) => c.put(clave, copia)).catch(() => {});
      }
      return res;
    } catch (err) {
      const guardada = await caches.match(clave);
      if (guardada) return guardada;
      if (req.mode === 'navigate') {
        const inicio = await caches.match(url.origin + '/');
        if (inicio) return inicio;
      }
      throw err;
    }
  })());
});
