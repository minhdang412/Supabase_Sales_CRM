const CACHE = 'sales-crm-shell-v1'
const SHELL = ['/', '/manifest.webmanifest']
self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(SHELL)).catch(() => undefined))
  self.skipWaiting()
})
self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim())
})
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET' || new URL(event.request.url).origin !== self.location.origin) return
  if (event.request.mode === 'navigate') {
    event.respondWith(fetch(event.request).catch(() => caches.match('/')))
  }
})
