// swarana.emirsyah.dev: serves the latest APK built by GitHub Actions.
// Visiting the domain downloads the app directly; the file is streamed from
// the GitHub "latest" release so every push to main is picked up.
const APK = 'https://github.com/emrsyah/Swarana/releases/latest/download/swarana.apk';

export default {
  async fetch(request) {
    const { pathname } = new URL(request.url);
    if (pathname === '/favicon.ico' || pathname === '/robots.txt') {
      return new Response(null, { status: 404 });
    }

    const upstream = await fetch(APK, {
      redirect: 'follow',
      cf: { cacheEverything: true, cacheTtl: 300 },
    });
    if (!upstream.ok) {
      return new Response('APK belum tersedia, coba lagi sebentar.', {
        status: 502,
        headers: { 'content-type': 'text/plain; charset=utf-8' },
      });
    }

    const headers = new Headers({
      'content-type': 'application/vnd.android.package-archive',
      'content-disposition': 'attachment; filename="swarana.apk"',
      'cache-control': 'public, max-age=300',
    });
    const len = upstream.headers.get('content-length');
    if (len) headers.set('content-length', len);
    return new Response(request.method === 'HEAD' ? null : upstream.body, { headers });
  },
};
