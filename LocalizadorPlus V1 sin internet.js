// Localizador Plus V1 · iPhone: funciona sin internet (N-50).
// La primera vez que se abre con internet guarda en el iPhone la app (index.html),
// las 9 pantallas de arranque y las letras. Despues se abre desde lo guardado,
// aunque no haya internet ni funcione la pagina. Si hay internet, baja en segundo
// plano la version nueva y se ve la siguiente vez que se abre la app.
// REGLA: en cada entrega nueva del iPhone, cambiar VERSION (por ejemplo "N-51").
const VERSION = "N-54";
const CAJA = "locplus-" + VERSION;
const APP = new URL("index.html", self.registration.scope).href;
const ARRANQUES = ["750x1334", "828x1792", "1125x2436", "1170x2532", "1179x2556", "1206x2622", "1284x2778", "1290x2796", "1320x2868"]
  .map(t => new URL("LocalizadorPlus%20V1%20arranque%20" + t + ".png", self.registration.scope).href);
const LETRAS = "https://fonts.googleapis.com/css2?family=Archivo:wdth,wght@75..100,500..800&family=Atkinson+Hyperlegible:wght@400;700&display=swap";
const DE_LETRAS = u => u.hostname === "fonts.googleapis.com" || u.hostname === "fonts.gstatic.com";

// las letras: la hoja y los archivos que nombra (si falla, la app se guarda igual)
async function guardarLetras(caja) {
  const r = await fetch(LETRAS);
  if (!r.ok) return;
  await caja.put(LETRAS, r.clone());
  const hoja = await r.text();
  const archivos = [...new Set(hoja.match(/https:\/\/fonts\.gstatic\.com\/[^)'"\s]+/g) || [])];
  await Promise.all(archivos.map(a => fetch(a, { mode: "cors" }).then(f => f.ok && caja.put(a, f)).catch(() => {})));
}

self.addEventListener("install", e => {
  e.waitUntil((async () => {
    const caja = await caches.open(CAJA);
    await caja.addAll([new Request(APP, { cache: "no-cache" }), ...ARRANQUES]);
    try { await guardarLetras(caja); } catch (x) {}
    await self.skipWaiting();
  })());
});

self.addEventListener("activate", e => {
  e.waitUntil((async () => {
    const viejas = (await caches.keys()).filter(k => k.startsWith("locplus-") && k !== CAJA);
    // las letras de la version anterior se aprovechan si esta no las pudo bajar
    const caja = await caches.open(CAJA);
    for (const k of viejas) {
      const vieja = await caches.open(k);
      for (const p of await vieja.keys()) if (DE_LETRAS(new URL(p.url)) && !(await caja.match(p, { ignoreVary: true }))) await caja.put(p, await vieja.match(p));
      await caches.delete(k);
    }
    await self.clients.claim();
  })());
});

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const u = new URL(req.url);
  const enLaApp = u.origin === self.location.origin && u.href.startsWith(self.registration.scope);
  // la app: se abre lo guardado y se baja la nueva para la proxima vez
  if (enLaApp && (req.mode === "navigate" || u.pathname.endsWith("/") || u.pathname.endsWith("/index.html"))) {
    e.respondWith((async () => {
      const caja = await caches.open(CAJA);
      const guardada = await caja.match(APP);
      const nueva = fetch(APP, { cache: "no-cache" }).then(r => { if (r.ok) return caja.put(APP, r.clone()).then(() => r); return guardada || r; });
      if (guardada) { e.waitUntil(nueva.catch(() => {})); return guardada; }
      return nueva;
    })());
    return;
  }
  // arranques y letras: de lo guardado; si no estan, de internet y se guardan
  if (enLaApp || DE_LETRAS(u)) {
    e.respondWith((async () => {
      const caja = await caches.open(CAJA);
      const guardado = await caja.match(req, { ignoreVary: true });
      if (guardado) return guardado;
      const r = await fetch(req);
      if (r.ok || r.type === "opaque") e.waitUntil(caja.put(req, r.clone()).catch(() => {}));
      return r;
    })());
  }
});
