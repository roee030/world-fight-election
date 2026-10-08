"""Patch the generated Godot Web shell for reliable responsive startup."""

from pathlib import Path
from typing import Mapping


ASPECT_RATIO = 16.0 / 9.0


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
:root{--wf-safe-left:env(safe-area-inset-left,0px);--wf-safe-right:env(safe-area-inset-right,0px);--wf-safe-top:env(safe-area-inset-top,0px);--wf-safe-bottom:env(safe-area-inset-bottom,0px)}
html,body{position:fixed;inset:0;width:100%;height:100%;margin:0;overflow:hidden;background:#050810}
#canvas{position:fixed!important;margin:0!important;max-width:none!important;max-height:none!important;touch-action:none}
#world-fight-startup{position:fixed;inset:0;width:100%;height:100%;z-index:9999;overflow:hidden;pointer-events:none;color:#f7f2e8;font-family:Arial,sans-serif}
#world-fight-startup .wf-actions{position:absolute;left:5%;top:20.5%;width:28.5%;min-width:180px;pointer-events:auto;text-shadow:0 2px 12px #000}
#world-fight-startup button{display:block;width:100%;min-height:44px;margin:3px 0;padding:7px 10px;border:0;border-left:3px solid transparent;background:rgba(5,12,23,.72);color:#f7f2e8;text-align:left;font-size:clamp(12px,1.35vw,20px);letter-spacing:1px;cursor:pointer}
#world-fight-startup button:hover,#world-fight-startup button:active{border-left-color:#e15367;background:rgba(160,35,58,.82)}
#world-fight-startup button[aria-busy=true]{color:#ffd18a;border-left-color:#ffd18a}
#world-fight-startup .wf-loading{margin:10px 0 0 10px;color:#a9bdc6;font-size:12px;letter-spacing:.08em}
#worldFightRotateGate{display:none;position:fixed;inset:0;z-index:10000;align-items:center;justify-content:center;padding:calc(24px + var(--wf-safe-top)) calc(24px + var(--wf-safe-right)) calc(24px + var(--wf-safe-bottom)) calc(24px + var(--wf-safe-left));box-sizing:border-box;background:#050810;color:#f7f2e8;text-align:center;font-family:Arial,sans-serif}
#worldFightRotateGate .wf-rotate-card{max-width:360px;border:1px solid rgba(92,218,215,.55);padding:28px 24px;background:#0b1722}
#worldFightRotateGate strong{display:block;font-size:25px;margin-bottom:10px;color:#66d9d4}
#worldFightRotateGate span{display:block;line-height:1.55}
</style>
<script id="world-fight-responsive-script">
(() => {
  const state = { ready: false, menuVisible: true, pending: '' };
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
    rotate.style.display=fit.portrait?'flex':'none'; canvas.style.visibility=fit.portrait?'hidden':'visible';
    if (fit.portrait) { startup.style.display='none'; return; }
    const left=offsetLeft+fit.left, top=offsetTop+fit.top;
    for (const element of [canvas,startup]) { element.style.left=`${left}px`; element.style.top=`${top}px`; element.style.width=`${fit.width}px`; element.style.height=`${fit.height}px`; }
    startup.style.display=(state.menuVisible&&(!state.ready||Boolean(state.pending)))?'block':'none';
    const loading=startup.querySelector('.wf-loading'); if (loading) loading.hidden=state.ready;
  };
  window.worldFightSetReady = (ready) => { state.ready=Boolean(ready); window.layoutWorldFightViewport(); };
  window.worldFightSetMenuVisible = (visible) => { state.menuVisible=Boolean(visible); window.layoutWorldFightViewport(); };
  window.worldFightAcknowledgeAction = (action) => {
    if (state.pending&&action&&state.pending!==action) return;
    state.pending=''; window.worldFightPendingAction=''; state.menuVisible=false;
    document.querySelectorAll('#world-fight-startup button').forEach((button)=>button.setAttribute('aria-busy','false'));
    window.layoutWorldFightViewport();
  };
  window.initializeWorldFightShell = () => {
    const startup=document.getElementById('world-fight-startup');
    if (!startup || startup.dataset.initialized) return;
    startup.dataset.initialized='true';
    startup.querySelectorAll('button').forEach((button)=>button.addEventListener('click',()=>{
      if (state.pending) return; state.pending=button.dataset.action; window.worldFightPendingAction=state.pending; button.setAttribute('aria-busy','true');
      if (!document.fullscreenElement&&document.documentElement.requestFullscreen) document.documentElement.requestFullscreen().then(()=>screen.orientation?.lock?.('landscape')).catch(()=>{});
      if (typeof window.worldFightMenuAction==='function') window.worldFightMenuAction(state.pending);
    }));
    window.addEventListener('resize',window.layoutWorldFightViewport); window.addEventListener('orientationchange',window.layoutWorldFightViewport);
    if (window.visualViewport) { window.visualViewport.addEventListener('resize',window.layoutWorldFightViewport); window.visualViewport.addEventListener('scroll',window.layoutWorldFightViewport); }
    window.layoutWorldFightViewport();
  };
  document.addEventListener('DOMContentLoaded', window.initializeWorldFightShell);
})();
</script>
"""

STARTUP_MARKUP = """<div id="world-fight-startup"><div class="wf-actions"><button data-action="quick">START FIGHT</button><button data-action="campaign">CAMPAIGN</button><button data-action="lab">FIGHTER LAB</button><div class="wf-loading">LOADING GAME…</div></div></div><div id="worldFightRotateGate"><div class="wf-rotate-card"><strong>סובבו את הטלפון</strong><span>Rotate your phone to landscape<br>סובבו לרוחב כדי להתחיל לשחק</span></div></div><script>window.initializeWorldFightShell()</script>"""

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
    path.with_name("index.service.worker.js").write_text(RETIRE_WORKER, encoding="utf-8")


if __name__ == "__main__":
    patch(Path("export/web/index.html"))
