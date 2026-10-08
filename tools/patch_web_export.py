"""Patch the generated Godot Web shell for reliable responsive startup."""

from pathlib import Path
from shutil import copyfile
from typing import Mapping


ASPECT_RATIO = 16.0 / 9.0
ROTATE_ART = Path(__file__).resolve().parents[1] / "assets" / "ui" / "rotate-device-ensemble.webp"


def fit_viewport(width: float, height: float, insets: Mapping[str, float] | None = None) -> dict[str, float | bool]:
    """Fit an uncropped 16:9 canvas inside the safe visible viewport."""
    safe = {"left": 0.0, "right": 0.0, "top": 0.0, "bottom": 0.0}
    if insets:
        safe.update({key: max(0.0, float(value)) for key, value in insets.items() if key in safe})
    usable_width = max(0.0, float(width) - safe["left"] - safe["right"])
    usable_height = max(0.0, float(height) - safe["top"] - safe["bottom"])
    if usable_height > usable_width:
        return {"portrait": True, "left": safe["left"], "top": safe["top"], "width": 0.0, "height": 0.0}
    canvas_width = min(usable_width, usable_height * ASPECT_RATIO)
    canvas_height = canvas_width / ASPECT_RATIO
    return {
        "portrait": False,
        "left": max(safe["left"], safe["left"] + (usable_width - canvas_width) * 0.5),
        "top": max(safe["top"], safe["top"] + (usable_height - canvas_height) * 0.5),
        "width": canvas_width,
        "height": canvas_height,
    }


CACHE_RETIREMENT = """<script id="world-fight-cache-retirement">
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then((items) => items.forEach((item) => item.unregister()));
}
if ('caches' in window) {
  caches.keys().then((keys) => Promise.all(keys.map((key) => caches.delete(key))));
}
</script>
"""

RESPONSIVE_SHELL = r"""<style id="world-fight-responsive-style">
:root{--wf-safe-left:env(safe-area-inset-left,0px);--wf-safe-right:env(safe-area-inset-right,0px);--wf-safe-top:env(safe-area-inset-top,0px);--wf-safe-bottom:env(safe-area-inset-bottom,0px);--wf-canvas-left:0px;--wf-canvas-top:0px;--wf-canvas-width:100vw;--wf-canvas-height:100vh}
html,body{position:fixed;inset:0;width:100%;height:100%;margin:0;overflow:hidden;background:#050810}
#canvas{position:fixed!important;left:var(--wf-canvas-left)!important;top:var(--wf-canvas-top)!important;width:var(--wf-canvas-width)!important;height:var(--wf-canvas-height)!important;margin:0!important;max-width:none!important;max-height:none!important;touch-action:none}
.wf-portrait #canvas{visibility:hidden!important}
#world-fight-startup{position:fixed;left:var(--wf-canvas-left);top:var(--wf-canvas-top);width:var(--wf-canvas-width);height:var(--wf-canvas-height);z-index:9999;overflow:hidden;pointer-events:none;color:#f7f2e8;font-family:Arial,sans-serif}
#world-fight-startup .wf-loading{position:absolute;left:50%;bottom:10%;transform:translateX(-50%);margin:0;color:#a9bdc6;font-size:12px;letter-spacing:.08em;text-shadow:0 2px 10px #000;white-space:nowrap}
#worldFightRotateGate{display:none;position:fixed;inset:0;z-index:10000;align-items:flex-end;justify-content:center;padding:calc(24px + var(--wf-safe-top)) calc(20px + var(--wf-safe-right)) calc(30px + var(--wf-safe-bottom)) calc(20px + var(--wf-safe-left));box-sizing:border-box;background-color:#050810;background-image:linear-gradient(180deg,rgba(2,6,13,0) 42%,#050810 78%),url('rotate-device-ensemble.webp');background-position:center,center top;background-size:cover,100% auto;background-repeat:no-repeat;color:#f7f2e8;text-align:center;font-family:Arial,sans-serif}
#worldFightRotateGate .wf-rotate-card{width:min(390px,calc(100vw - 40px));border:1px solid rgba(92,218,215,.65);padding:18px 20px;background:rgba(5,14,24,.9);box-shadow:0 12px 36px rgba(0,0,0,.72);backdrop-filter:blur(5px)}
#worldFightRotateGate strong{display:block;font-size:25px;margin-bottom:10px;color:#66d9d4}
#worldFightRotateGate span{display:block;line-height:1.55}
#worldFightFullscreenButton{width:100%;min-height:48px;margin-top:14px;border:1px solid #e9bd62;background:linear-gradient(180deg,#b9792f,#80501f);color:#fff8df;font-weight:800;font-size:16px;letter-spacing:.08em;cursor:pointer}
</style>
<script id="world-fight-responsive-script">
(() => {
  const state = { ready: false, menuVisible: true };
  window.worldFightPendingAction = '';
  window.worldFightFitViewport = (width, height, insets = {}) => {
    const safe = { left: Math.max(0, Number(insets.left)||0), right: Math.max(0, Number(insets.right)||0), top: Math.max(0, Number(insets.top)||0), bottom: Math.max(0, Number(insets.bottom)||0) };
    const usableWidth = Math.max(0, width-safe.left-safe.right), usableHeight = Math.max(0, height-safe.top-safe.bottom);
    if (usableHeight > usableWidth) return {portrait:true,left:safe.left,top:safe.top,width:0,height:0};
    const canvasWidth = Math.min(usableWidth, usableHeight*16/9), canvasHeight = canvasWidth*9/16;
    return {portrait:false,left:Math.max(safe.left,safe.left+(usableWidth-canvasWidth)/2),top:Math.max(safe.top,safe.top+(usableHeight-canvasHeight)/2),width:canvasWidth,height:canvasHeight};
  };
  const readSafeInsets = () => {
    const probe=document.createElement('div');
    probe.style.cssText='position:fixed;visibility:hidden;pointer-events:none;padding:var(--wf-safe-top) var(--wf-safe-right) var(--wf-safe-bottom) var(--wf-safe-left)';
    document.body.appendChild(probe); const style=getComputedStyle(probe);
    const value={top:parseFloat(style.paddingTop)||0,right:parseFloat(style.paddingRight)||0,bottom:parseFloat(style.paddingBottom)||0,left:parseFloat(style.paddingLeft)||0};
    probe.remove(); return value;
  };
  window.layoutWorldFightViewport = () => {
    const canvas=document.getElementById('canvas'), startup=document.getElementById('world-fight-startup'), rotate=document.getElementById('worldFightRotateGate');
    if (!canvas||!startup||!rotate) return;
    const viewport=window.visualViewport, width=viewport?viewport.width:window.innerWidth, height=viewport?viewport.height:window.innerHeight;
    const offsetLeft=viewport?viewport.offsetLeft:0, offsetTop=viewport?viewport.offsetTop:0;
    const fit=window.worldFightFitViewport(width,height,readSafeInsets());
    document.documentElement.classList.toggle('wf-portrait',fit.portrait);
    rotate.style.display=fit.portrait?'flex':'none';
    if (fit.portrait) { startup.style.display='none'; return; }
    const left=offsetLeft+fit.left, top=offsetTop+fit.top;
    const root=document.documentElement.style;
    root.setProperty('--wf-canvas-left',`${left}px`); root.setProperty('--wf-canvas-top',`${top}px`);
    root.setProperty('--wf-canvas-width',`${fit.width}px`); root.setProperty('--wf-canvas-height',`${fit.height}px`);
    startup.style.display=(state.menuVisible&&!state.ready)?'block':'none';
    const loading=startup.querySelector('.wf-loading'); if (loading) loading.hidden=state.ready;
  };
  window.worldFightSetReady = (ready) => { state.ready=Boolean(ready); window.layoutWorldFightViewport(); };
  window.worldFightSetMenuVisible = (visible) => { state.menuVisible=Boolean(visible); window.layoutWorldFightViewport(); };
  window.requestWorldFightFullscreen = () => {
    if (document.fullscreenElement||!document.documentElement.requestFullscreen) return Promise.resolve();
    return document.documentElement.requestFullscreen().then(()=>screen.orientation?.lock?.('landscape')).catch(()=>{});
  };
  window.worldFightAcknowledgeAction = (action) => {
    window.worldFightPendingAction=''; state.menuVisible=false;
    window.layoutWorldFightViewport();
  };
  window.initializeWorldFightShell = () => {
    const startup=document.getElementById('world-fight-startup');
    if (!startup) return;
    if (startup.dataset.initialized) { window.layoutWorldFightViewport(); return; }
    startup.dataset.initialized='true';
    document.getElementById('worldFightFullscreenButton')?.addEventListener('click',window.requestWorldFightFullscreen);
    document.addEventListener('pointerup',()=>{ if (innerWidth>innerHeight) window.requestWorldFightFullscreen(); },{once:true,passive:true});
    window.addEventListener('resize',window.layoutWorldFightViewport); window.addEventListener('orientationchange',()=>{ window.layoutWorldFightViewport(); if (innerWidth>innerHeight) window.requestWorldFightFullscreen(); });
    if (window.visualViewport) { window.visualViewport.addEventListener('resize',window.layoutWorldFightViewport); window.visualViewport.addEventListener('scroll',window.layoutWorldFightViewport); }
    window.layoutWorldFightViewport();
  };
  document.addEventListener('DOMContentLoaded', window.initializeWorldFightShell);
})();
</script>
"""

STARTUP_MARKUP = """<div id="world-fight-startup"><div class="wf-loading">LOADING GAME…</div></div><div id="worldFightRotateGate"><div class="wf-rotate-card"><strong>סובבו את הטלפון</strong><span>Rotate your phone to landscape<br>סובבו לרוחב כדי להתחיל לשחק</span><button id="worldFightFullscreenButton" type="button">⛶ FULL SCREEN</button></div></div><script>window.initializeWorldFightShell()</script>"""

RETIRE_WORKER = """/* Retire the previous Godot PWA worker without intercepting requests. */
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil(Promise.all([
    caches.keys().then((keys) => Promise.all(keys.map((key) => caches.delete(key)))),
    self.registration.unregister()
  ]).then(() => self.clients.claim())
    .then(() => self.clients.matchAll({ type: 'window' }))
    .then((clients) => Promise.all(clients.map((client) => client.navigate(client.url)))));
});
"""


def patch(path: Path) -> None:
    html = path.read_text(encoding="utf-8")
    if "world-fight-cache-retirement" not in html:
        html = html.replace("</head>", CACHE_RETIREMENT + "</head>", 1)
    if "world-fight-responsive-script" not in html:
        html = html.replace("</head>", RESPONSIVE_SHELL + "</head>", 1)
    if 'id="world-fight-startup"' not in html:
        html = html.replace("<body>", "<body>" + STARTUP_MARKUP, 1)
    path.write_text(html, encoding="utf-8")
    if ROTATE_ART.is_file():
        copyfile(ROTATE_ART, path.with_name("rotate-device-ensemble.webp"))
    path.with_name("index.service.worker.js").write_text(RETIRE_WORKER, encoding="utf-8")


if __name__ == "__main__":
    patch(Path("export/web/index.html"))
