// Cadence service worker.
//
// Strategy: NETWORK-FIRST for the app shell (index.html), CACHE-FIRST for static
// assets (icons, manifest). This matters because a plain cache-first service worker
// is the #1 reason "I fixed a bug but it still shows the old version" happens with
// PWAs — the old file just keeps getting served from cache. Network-first for the
// HTML means every reload always tries to get your latest deploy first, and only
// falls back to the cached copy if the person is actually offline.
//
// Bump CACHE_VERSION any time you want to force everyone's stale cache to drop
// immediately (rarely needed with this strategy, but handy as an escape hatch).
const CACHE_VERSION = 'cadence-v1';
const STATIC_ASSETS = [
  'icon-192.png',
  'icon-512.png',
  'apple-touch-icon.png',
  'manifest.json'
];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_VERSION)
      .then((cache) => cache.addAll(STATIC_ASSETS))
      .catch(() => {}) // don't block install if an asset is temporarily missing
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE_VERSION).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const isHTML = req.mode === 'navigate' || (req.headers.get('accept') || '').includes('text/html');

  if (isHTML) {
    event.respondWith(
      fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(CACHE_VERSION).then((cache) => cache.put(req, copy));
          return res;
        })
        .catch(() => caches.match(req)) // offline fallback only
    );
    return;
  }

  event.respondWith(
    caches.match(req).then((cached) => cached || fetch(req))
  );
});
