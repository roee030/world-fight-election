"""Remove stale Godot PWA state from the generated GitHub Pages shell."""

from pathlib import Path


SCRIPT = """<script>
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then((items) => items.forEach((item) => item.unregister()));
}
if ('caches' in window) {
  caches.keys().then((keys) => Promise.all(keys.map((key) => caches.delete(key))));
}
</script>
"""

LAYOUT_STYLE = """<style id="world-fight-viewport-fix">
html,body{display:flex;align-items:center;justify-content:center;width:100%;height:100%;margin:0;overflow:hidden;background:#050810}
#canvas{flex:none;width:min(100vw,calc(100dvh * 16 / 9))!important;height:min(100dvh,calc(100vw * 9 / 16))!important;max-width:100vw;max-height:100dvh;touch-action:none}
</style>
"""

CHROME_MENU = """<style id="chrome-start-menu-style">
#chrome-start-menu{display:none;position:fixed;inset:0;z-index:9999;pointer-events:none;color:#f7f2e8;font-family:Arial,sans-serif}
#chrome-start-menu .wf-actions{position:absolute;left:max(28px,5vw);top:50%;transform:translateY(-50%);width:min(340px,70vw);pointer-events:auto;text-shadow:0 2px 12px #000}
#chrome-start-menu h1{font-size:clamp(34px,5vw,62px);line-height:.9;margin:0 0 28px;letter-spacing:2px}
#chrome-start-menu button{display:block;width:100%;margin:5px 0;padding:13px 12px;border:0;border-left:4px solid transparent;background:rgba(5,12,23,.52);color:#f7f2e8;text-align:left;font-size:clamp(16px,2vw,22px);letter-spacing:1px;cursor:pointer}
#chrome-start-menu button:hover,#chrome-start-menu button:active{border-left-color:#e15367;background:rgba(160,35,58,.75)}
#chrome-start-menu small{display:block;margin-top:18px;color:#abc0c8;letter-spacing:1px}
</style>
<script id="chrome-start-menu-script">
document.addEventListener('DOMContentLoaded', () => {
  if (!/(Chrome|CriOS)/.test(navigator.userAgent)) return;
  const menu = document.createElement('div');
  menu.id = 'chrome-start-menu';
  menu.innerHTML = '<div class="wf-actions"><h1>WORLD<br>FIGHT</h1><button data-action="quick">START FIGHT</button><button data-action="campaign">CAMPAIGN</button><button data-action="lab">FIGHTER LAB</button><small>CHROME START MENU</small></div>';
  document.body.appendChild(menu);
  menu.style.display = 'block';
  menu.querySelectorAll('button').forEach((button) => button.addEventListener('click', () => {
    const action = button.dataset.action;
    window.worldFightPendingAction = action;
    if (typeof window.worldFightMenuAction === 'function') window.worldFightMenuAction(action);
  }));
});
</script>
"""

RETIRE_WORKER = """/* Retire the previous Godot PWA worker without intercepting requests. */
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil(
    Promise.all([
      caches.keys().then((keys) => Promise.all(keys.map((key) => caches.delete(key)))),
      self.registration.unregister()
    ]).then(() => self.clients.claim())
      .then(() => self.clients.matchAll({ type: 'window' }))
      .then((clients) => Promise.all(clients.map((client) => client.navigate(client.url))))
  );
});
"""


def patch(path: Path) -> None:
    html = path.read_text(encoding="utf-8")
    if "getRegistrations()" not in html:
        html = html.replace("</head>", LAYOUT_STYLE + SCRIPT + "</head>", 1)
    if "chrome-start-menu" not in html:
        html = html.replace("</head>", CHROME_MENU + "</head>", 1)
    path.write_text(html, encoding="utf-8")
    path.with_name("index.service.worker.js").write_text(RETIRE_WORKER, encoding="utf-8")


if __name__ == "__main__":
    patch(Path("export/web/index.html"))
