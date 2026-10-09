"""Patch the generated Godot Web shell for reliable phone startup.

The shell owns only browser concerns: a full-viewport canvas, an honest
loading screen with retry, the portrait rotate gate, the mandatory landscape
fullscreen gate on phones, optional diagnostics (``?diag=1``) and retiring the
old PWA worker. Game layout is handled inside Godot (``expand`` stretch aspect).

Every injected block is wrapped in ``<!--wf:NAME-->`` markers and replaced on
each run, so patching an already patched (or older) shell is idempotent.
"""

from pathlib import Path
import json
import re
from shutil import copyfile
from typing import Mapping


ROTATE_ART = Path(__file__).resolve().parents[1] / "assets" / "ui" / "rotate-device-ensemble.webp"
SITE_CONFIG = Path(__file__).resolve().parents[1] / "data" / "site_config.json"
DISCLAIMER_VERSION = "wf-disclaimer-v2"

WEB_APP_MANIFEST = {
    "id": "./",
    "name": "World Fight: Election Edition",
    "short_name": "World Fight",
    "start_url": "./",
    "scope": "./",
    "display": "fullscreen",
    "display_override": ["fullscreen", "standalone"],
    "orientation": "landscape",
    "background_color": "#050810",
    "theme_color": "#050810",
    "icons": [
        {"src": "index.apple-touch-icon.png", "sizes": "180x180", "type": "image/png"},
        {"src": "index.icon.png", "sizes": "any", "type": "image/png"},
    ],
}

WEB_APP_LINKS = """<link rel="manifest" href="manifest.webmanifest">
<link rel="apple-touch-icon" href="index.apple-touch-icon.png">
<meta name="theme-color" content="#050810">
"""


def load_site_config(path: Path = SITE_CONFIG) -> dict:
    """Owner settings: analytics code and LinkedIn URL (empty = disabled)."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        data = {}
    return {"goatcounter_code": str(data.get("goatcounter_code", "")).strip(), "linkedin_url": str(data.get("linkedin_url", "")).strip()}


def fit_viewport(width: float, height: float, insets: Mapping[str, float] | None = None) -> dict[str, float | bool]:
    """Return the canvas rectangle: the whole safe landscape viewport.

    The game uses Godot's ``expand`` aspect, so it fills any landscape shape
    without bars, cropping or stretching. Portrait returns an empty rectangle
    because the rotate gate is shown instead of a tiny canvas.
    """
    safe = {"left": 0.0, "right": 0.0, "top": 0.0, "bottom": 0.0}
    if insets:
        safe.update({key: max(0.0, float(value)) for key, value in insets.items() if key in safe})
    usable_width = max(0.0, float(width) - safe["left"] - safe["right"])
    usable_height = max(0.0, float(height) - safe["top"] - safe["bottom"])
    if usable_height > usable_width:
        return {"portrait": True, "left": safe["left"], "top": safe["top"], "width": 0.0, "height": 0.0}
    return {"portrait": False, "left": safe["left"], "top": safe["top"], "width": usable_width, "height": usable_height}


CACHE_RETIREMENT = """<script id="world-fight-cache-retirement">
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then((items) => items.forEach((item) => item.unregister()));
}
if ('caches' in window) {
  caches.keys().then((keys) => Promise.all(keys.map((key) => caches.delete(key))));
}
</script>
"""

HEAD_SHELL = r"""<style id="world-fight-responsive-style">
html,body{position:fixed;inset:0;width:100%;height:100%;margin:0;overflow:hidden;background:#050810;touch-action:none;-webkit-user-select:none;user-select:none}
#canvas{position:fixed!important;left:0!important;top:0!important;width:100%!important;height:100%!important;margin:0!important;max-width:none!important;max-height:none!important;touch-action:none}
#status{display:none!important}
.wf-portrait #canvas{visibility:hidden!important}
.wf-overlay{position:fixed;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;box-sizing:border-box;padding:24px;color:#f7f2e8;font-family:Arial,Helvetica,sans-serif;text-align:center}
#world-fight-startup{z-index:9998;background:radial-gradient(ellipse at 50% 35%,#13293a 0%,#050810 70%)}
#world-fight-startup[hidden]{display:none}
#world-fight-startup .wf-title{font-size:clamp(28px,7vmin,54px);font-weight:900;letter-spacing:.06em}
#world-fight-startup .wf-sub{margin:6px 0 22px;color:#d9b566;font-size:clamp(11px,2.4vmin,15px);letter-spacing:.3em}
#world-fight-startup .wf-track{width:min(420px,70vw);height:10px;border:1px solid rgba(102,217,212,.6);background:rgba(4,12,20,.9);transform:skewX(-18deg)}
#world-fight-startup .wf-fill{height:100%;width:0;background:linear-gradient(90deg,#2ab8b3,#7ff4ee);transition:width .2s}
#world-fight-startup .wf-loading{margin-top:12px;color:#a9c3cb;font-size:13px;letter-spacing:.08em;min-height:18px}
#world-fight-startup .wf-error{display:none;max-width:420px;margin-top:14px;color:#ffb3b8;font-size:13px;line-height:1.5}
#world-fight-startup button{margin-top:16px;min-height:48px;padding:0 28px;border:1px solid #e9bd62;background:linear-gradient(180deg,#b9792f,#80501f);color:#fff8df;font-weight:800;font-size:15px;letter-spacing:.1em}
#world-fight-startup .wf-retry{display:none}
#worldFightRotateGate{display:none;z-index:10000;justify-content:flex-end;padding:calc(24px + env(safe-area-inset-top,0px)) 20px calc(30px + env(safe-area-inset-bottom,0px));background-color:#050810;background-image:linear-gradient(180deg,rgba(2,6,13,0) 42%,#050810 78%),url('rotate-device-ensemble.webp');background-position:center,center top;background-size:cover,100% auto;background-repeat:no-repeat}
.wf-portrait #worldFightRotateGate{display:flex}
#worldFightRotateGate .wf-rotate-card{width:min(390px,calc(100vw - 40px));max-height:60dvh;overflow:auto;border:1px solid rgba(92,218,215,.65);padding:18px 20px;background:rgba(5,14,24,.92);box-shadow:0 12px 36px rgba(0,0,0,.72)}
#worldFightRotateGate strong{display:block;font-size:25px;margin-bottom:10px;color:#66d9d4}
#worldFightRotateGate span{display:block;line-height:1.55}
#worldFightIosInstallHint{display:none;margin-top:12px;padding:10px 12px;border:1px solid rgba(232,185,79,.65);background:rgba(232,185,79,.08);color:#fff3c4;font-size:13px;line-height:1.45}
.wf-ios-browser #worldFightIosInstallHint{display:block}
.wf-ios-browser #worldFightFullscreenButton{display:none}
#worldFightFullscreenGate{display:none;z-index:9999;background:rgba(3,7,13,.86);cursor:pointer}
.wf-needs-fullscreen #worldFightFullscreenGate{display:flex}
#worldFightFullscreenGate strong{font-size:clamp(30px,8vmin,60px);font-weight:900;letter-spacing:.08em;color:#fff3c4;text-shadow:0 0 24px rgba(255,200,80,.55)}
#worldFightFullscreenGate span{margin-top:10px;color:#a9c3cb;font-size:14px;letter-spacing:.12em}
#worldFightIosGate{display:none;z-index:9999;padding:calc(12px + env(safe-area-inset-top,0px)) calc(16px + env(safe-area-inset-right,0px)) calc(12px + env(safe-area-inset-bottom,0px)) calc(16px + env(safe-area-inset-left,0px));background:rgba(3,7,13,.94)}
.wf-needs-ios-install #worldFightIosGate{display:flex}
#worldFightIosGate .wf-ios-card{width:min(560px,100%);max-height:100%;overflow:auto;box-sizing:border-box;border:1px solid rgba(232,185,79,.75);padding:14px 18px;background:linear-gradient(180deg,#0b1620,#070d14);box-shadow:0 0 40px rgba(70,220,216,.18)}
#worldFightIosGate strong{display:block;font-size:clamp(18px,5vmin,24px);color:#f2c35a;margin-bottom:6px}
#worldFightIosGate ol{margin:6px 0 8px;padding-inline-start:20px;text-align:start;line-height:1.5;font-size:clamp(12px,3.4vmin,15px)}
#worldFightIosGate .wf-ios-en{direction:ltr;color:#9fb2b8;font-size:11px;line-height:1.4;margin:0 0 6px}
#worldFightIosGate button{margin-top:6px;min-height:44px;padding:0 24px;border:1px solid #e9bd62;background:linear-gradient(180deg,#b9792f,#80501f);color:#fff8df;font-weight:800;font-size:14px;letter-spacing:.08em}
#worldFightGraphicsReset{display:none;z-index:10002;background:rgba(3,7,13,.94)}
.wf-context-lost #worldFightGraphicsReset{display:flex}
#worldFightGraphicsReset strong{font-size:22px;color:#ffd18a;margin-bottom:8px}
#worldFightGraphicsReset button{margin-top:16px;min-height:48px;padding:0 28px;border:1px solid #e9bd62;background:linear-gradient(180deg,#b9792f,#80501f);color:#fff8df;font-weight:800;font-size:15px;letter-spacing:.1em}
#worldFightDiag{position:fixed;left:6px;bottom:6px;z-index:10001;max-width:60vw;padding:6px 8px;background:rgba(0,0,0,.78);color:#9ff;font:11px/1.35 monospace;white-space:pre-wrap;pointer-events:none}
</style>
<script id="world-fight-responsive-script">
(() => {
  const state = { ready: false, fullscreenSeen: false, stage: 'download', errors: [], lastBeat: 0 };
  const params = new URLSearchParams(location.search);
  const diagnostics = params.has('diag');
  const forceIosInstallHint = params.get('qa') === 'ios-install';
  const fullscreenSupported = () => Boolean(document.documentElement.requestFullscreen || document.documentElement.webkitRequestFullscreen);
  const isFullscreen = () => Boolean(document.fullscreenElement || document.webkitFullscreenElement);
  const isTouchPhone = () => (navigator.maxTouchPoints || 0) > 0 && Math.min(screen.width, screen.height) <= 900;
  const isAppleMobile = () => /iPhone|iPad|iPod/i.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && (navigator.maxTouchPoints || 0) > 1);
  const isStandalone = () => navigator.standalone === true || matchMedia('(display-mode: standalone)').matches || matchMedia('(display-mode: fullscreen)').matches;
  try { state.iosInstallDismissed = sessionStorage.getItem('wf-ios-install-dismissed') === '1'; } catch (error) { state.iosInstallDismissed = false; }
  window.worldFightPendingAction = '';
  window.worldFightFitViewport = (width, height, insets = {}) => {
    const safe = { left: Math.max(0, Number(insets.left)||0), right: Math.max(0, Number(insets.right)||0), top: Math.max(0, Number(insets.top)||0), bottom: Math.max(0, Number(insets.bottom)||0) };
    const usableWidth = Math.max(0, width-safe.left-safe.right), usableHeight = Math.max(0, height-safe.top-safe.bottom);
    if (usableHeight > usableWidth) return {portrait:true,left:safe.left,top:safe.top,width:0,height:0};
    return {portrait:false,left:safe.left,top:safe.top,width:usableWidth,height:usableHeight};
  };
  let cachedGpu = '';
  const gpuName = () => {
    // Probe once and release the context: every live WebGL context counts
    // against the browser limit, and exceeding it kills the game's own context.
    if (cachedGpu) return cachedGpu;
    try {
      const gl = document.createElement('canvas').getContext('webgl2');
      const info = gl && gl.getExtension('WEBGL_debug_renderer_info');
      cachedGpu = gl ? (info ? gl.getParameter(info.UNMASKED_RENDERER_WEBGL) : 'webgl2') : 'NO WEBGL2';
      gl?.getExtension('WEBGL_lose_context')?.loseContext();
    } catch (error) { cachedGpu = String(error); }
    return cachedGpu;
  };
  const renderDiagnostics = () => {
    if (!diagnostics) return;
    let panel = document.getElementById('worldFightDiag');
    if (!panel) { panel = document.createElement('div'); panel.id = 'worldFightDiag'; document.body.appendChild(panel); }
    const renderer = gpuName();
    const viewport = window.visualViewport;
    const beat = state.lastBeat ? ((Date.now() - state.lastBeat) / 1000).toFixed(1) + 's ago' : 'none yet';
    const safe = window.worldFightSafeArea;
    panel.textContent = `stage: ${state.stage}  ready: ${state.ready}  engine heartbeat: ${beat}\nsafe area: L${safe.left} R${safe.right} T${safe.top} B${safe.bottom}\nwindow: ${innerWidth}x${innerHeight}  visual: ${viewport ? Math.round(viewport.width)+'x'+Math.round(viewport.height) : '-'}  dpr: ${devicePixelRatio}\nfullscreen: ${isFullscreen()}  touch: ${navigator.maxTouchPoints||0}  memory: ${navigator.deviceMemory||'?'}GB\ngpu: ${renderer}\n${state.errors.slice(-3).join('\n')}`;
  };
  const recordError = (message) => { state.errors.push(String(message).slice(0, 180)); renderDiagnostics(); };
  window.addEventListener('error', (event) => recordError(event.message || event));
  for (const level of ['error', 'warn']) {
    const original = console[level].bind(console);
    console[level] = (...args) => { original(...args); recordError(level + ': ' + args.map(String).join(' ')); };
  }
  if (diagnostics) setInterval(renderDiagnostics, 500);
  window.addEventListener('unhandledrejection', (event) => recordError(event.reason || 'rejected promise'));
  const readSafeInsets = () => {
    const probe = document.createElement('div');
    probe.style.cssText = 'position:fixed;visibility:hidden;pointer-events:none;padding:env(safe-area-inset-top,0px) env(safe-area-inset-right,0px) env(safe-area-inset-bottom,0px) env(safe-area-inset-left,0px)';
    document.body.appendChild(probe);
    const style = getComputedStyle(probe);
    const value = { top: parseFloat(style.paddingTop)||0, right: parseFloat(style.paddingRight)||0, bottom: parseFloat(style.paddingBottom)||0, left: parseFloat(style.paddingLeft)||0 };
    probe.remove();
    return value;
  };
  // The canvas is full bleed (viewport-fit=cover). Godot reads these CSS-pixel
  // insets once a second and keeps its HUD, touch controls and menu text clear
  // of notches; the same call doubles as the engine heartbeat for ?diag=1.
  window.worldFightSafeArea = { top: 0, right: 0, bottom: 0, left: 0, height: innerHeight };
  window.worldFightHeartbeat = () => { state.lastBeat = Date.now(); return JSON.stringify(window.worldFightSafeArea); };
  window.layoutWorldFightViewport = () => {
    const portrait = innerHeight > innerWidth;
    if (document.body) window.worldFightSafeArea = Object.assign(readSafeInsets(), { height: innerHeight });
    const iosBrowser = forceIosInstallHint || (isAppleMobile() && !isStandalone());
    document.documentElement.classList.toggle('wf-ios-browser', iosBrowser);
    document.documentElement.classList.toggle('wf-portrait', portrait);
    // iPhone Safari cannot enter element fullscreen, so the TAP TO FIGHT gate
    // never appears there. In landscape, explain the Home Screen web app (the
    // only way to hide Safari's bars) once per tab; one tap always plays on.
    const needsIosInstall = state.ready && !state.iosInstallDismissed && !portrait && iosBrowser && (forceIosInstallHint || (isTouchPhone() && !fullscreenSupported()));
    document.documentElement.classList.toggle('wf-needs-ios-install', needsIosInstall);
    const needsFullscreen = state.ready && !state.fullscreenRefused && !portrait && isTouchPhone() && fullscreenSupported() && !isFullscreen();
    document.documentElement.classList.toggle('wf-needs-fullscreen', needsFullscreen);
    renderDiagnostics();
  };
  window.requestWorldFightFullscreen = () => {
    const root = document.documentElement;
    let request;
    try { request = root.requestFullscreen ? root.requestFullscreen({ navigationUI: 'hide' }) : root.webkitRequestFullscreen?.(); } catch (error) { request = Promise.reject(error); }
    // A browser that refuses (or never answers) the fullscreen request must not
    // leave the gate blocking play: one tap always lets the player in.
    setTimeout(() => { if (!isFullscreen()) state.fullscreenRefused = true; window.layoutWorldFightViewport(); }, 1200);
    return Promise.resolve(request)
      .then(() => screen.orientation?.lock?.('landscape')?.catch?.(() => {}))
      .catch((error) => { state.fullscreenRefused = true; recordError('fullscreen refused: ' + (error && error.message || error)); })
      .finally(window.layoutWorldFightViewport);
  };
  window.worldFightSetReady = (ready) => {
    state.ready = Boolean(ready);
    state.stage = state.ready ? 'menu ready' : state.stage;
    const startup = document.getElementById('world-fight-startup');
    if (startup && state.ready) startup.hidden = true;
    window.layoutWorldFightViewport();
  };
  window.worldFightSetMenuVisible = () => {};
  window.worldFightAcknowledgeAction = () => { window.worldFightPendingAction = ''; };
  const watchEngineLoader = () => {
    // Mirror Godot's own loader into the branded loading screen.
    const progress = document.getElementById('status-progress');
    const notice = document.getElementById('status-notice');
    const fill = document.querySelector('#world-fight-startup .wf-fill');
    const label = document.querySelector('#world-fight-startup .wf-loading');
    const error = document.querySelector('#world-fight-startup .wf-error');
    const retry = document.querySelector('#world-fight-startup .wf-retry');
    const started = Date.now();
    let engineStartedAt = 0;
    const timer = setInterval(() => {
      if (state.ready) { clearInterval(timer); return; }
      const failed = notice && notice.style.display === 'block' && notice.textContent.trim();
      if (failed) {
        state.stage = 'error';
        error.textContent = notice.textContent.trim();
        error.style.display = 'block';
        retry.style.display = 'inline-block';
        label.textContent = 'THE GAME COULD NOT START';
        recordError(error.textContent);
        clearInterval(timer);
        return;
      }
      if (!document.getElementById('status')) {
        engineStartedAt = engineStartedAt || Date.now();
        // The game normally reports ready itself; never trap a running game.
        if (Date.now() - engineStartedAt > 10000) { window.worldFightSetReady(true); return; }
        state.stage = 'starting engine';
        fill.style.width = '100%';
        label.textContent = 'STARTING THE ARENA…';
      } else if (progress && progress.max > 0) {
        const ratio = Math.min(1, progress.value / progress.max);
        fill.style.width = `${Math.round(ratio * 100)}%`;
        label.textContent = `LOADING ${Math.round(ratio * 100)}%  ·  ${(progress.value / 1048576).toFixed(1)} / ${(progress.max / 1048576).toFixed(1)} MB` + ((Date.now() - started > 12000 && ratio < 0.6) ? '  ·  SLOW CONNECTION' : '');
      }
      renderDiagnostics();
    }, 200);
  };
  window.initializeWorldFightShell = () => {
    const startup = document.getElementById('world-fight-startup');
    if (!startup || startup.dataset.initialized) { window.layoutWorldFightViewport(); return; }
    startup.dataset.initialized = 'true';
    startup.querySelector('.wf-retry')?.addEventListener('click', () => location.reload());
    // pointerup, not click: the engine cancels touch defaults, so a tap may
    // never synthesize a click. A touch pointerup still grants user activation.
    for (const id of ['worldFightFullscreenGate', 'worldFightFullscreenButton']) {
      document.getElementById(id)?.addEventListener('pointerup', (event) => { event.preventDefault(); event.stopPropagation(); window.requestWorldFightFullscreen(); });
    }
    const onFullscreenChange = () => {
      if (isFullscreen()) state.fullscreenSeen = true;
      else if (state.fullscreenSeen && typeof window.worldFightPauseRequest === 'function') window.worldFightPauseRequest('fullscreen');
      window.layoutWorldFightViewport();
    };
    document.getElementById('worldFightReloadButton')?.addEventListener('pointerup', () => location.reload());
    document.getElementById('worldFightIosPlayButton')?.addEventListener('pointerup', (event) => {
      event.preventDefault();
      event.stopPropagation();
      state.iosInstallDismissed = true;
      try { sessionStorage.setItem('wf-ios-install-dismissed', '1'); } catch (error) {}
      window.worldFightTrack?.('ios_install_skipped', { path: 'ios/install-skipped' });
      window.layoutWorldFightViewport();
    });
    document.addEventListener('fullscreenchange', onFullscreenChange);
    document.addEventListener('webkitfullscreenchange', onFullscreenChange);
    window.addEventListener('resize', window.layoutWorldFightViewport);
    window.addEventListener('orientationchange', window.layoutWorldFightViewport);
    if (window.visualViewport) window.visualViewport.addEventListener('resize', window.layoutWorldFightViewport);
    document.addEventListener('DOMContentLoaded', () => {
      // The canvas is parsed after this shell, so attach here, not earlier.
      document.getElementById('canvas')?.addEventListener('webglcontextlost', () => {
        // Godot cannot rebuild a lost WebGL context; a frozen half-drawn frame
        // would look like a stuck game. Say so and offer a reload.
        recordError('WebGL context lost');
        document.documentElement.classList.add('wf-context-lost');
      });
      watchEngineLoader();
    });
    window.layoutWorldFightViewport();
  };
})();
</script>
"""

BODY_SHELL = """<div id="world-fight-startup" class="wf-overlay"><div class="wf-title">WORLD FIGHT</div><div class="wf-sub">ELECTION EDITION</div><div class="wf-track"><div class="wf-fill"></div></div><div class="wf-loading">LOADING GAME…</div><div class="wf-error"></div><button class="wf-retry" type="button">RETRY</button></div><div id="worldFightFullscreenGate" class="wf-overlay" role="button" aria-label="Tap to play in full screen"><strong>TAP TO FIGHT</strong><span>FULL SCREEN · LANDSCAPE</span></div><div id="worldFightIosGate" class="wf-overlay"><div class="wf-ios-card" dir="rtl" lang="he"><strong>למסך מלא באייפון</strong><ol><li>לחצו על כפתור השיתוף של Safari (או על ⋯ ואז שיתוף).</li><li>בחרו <b>הוספה למסך הבית</b> (Add to Home Screen) ואשרו.</li><li>פתחו את המשחק מהאייקון החדש – הוא ייפתח במסך מלא לרוחב.</li></ol><p class="wf-ios-en">Safari on iPhone cannot hide its bars for a web page. Share &gt; Add to Home Screen, then open World Fight from its icon for true full screen.</p><button id="worldFightIosPlayButton" type="button" dir="ltr">PLAY HERE · שחקו כאן</button></div></div><div id="worldFightRotateGate" class="wf-overlay"><div class="wf-rotate-card"><strong>סובבו את הטלפון</strong><span>Rotate your phone to landscape<br>סובבו לרוחב כדי להתחיל לשחק</span><div id="worldFightIosInstallHint" dir="rtl">למסך מלא בלי הטאבים של Safari: לחצו על שיתוף, בחרו Add to Home Screen ופתחו את המשחק מהאייקון. אם המסך לא מסתובב, בטלו נעילת סיבוב במרכז הבקרה.</div><button id="worldFightFullscreenButton" type="button">FULL SCREEN</button></div></div><div id="worldFightGraphicsReset" class="wf-overlay"><strong>GRAPHICS WERE RESET</strong><span>The browser stopped the game's graphics.</span><button id="worldFightReloadButton" type="button">TAP TO RELOAD</button></div><script>window.initializeWorldFightShell()</script>"""

RETIRE_WORKER = """/* Retire the previous Godot PWA worker without intercepting requests.
   It never navigates open pages: a forced reload would download the game twice. */
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil(Promise.all([
    caches.keys().then((keys) => Promise.all(keys.map((key) => caches.delete(key)))),
    self.registration.unregister()
  ]).then(() => self.clients.claim()));
});
"""

LEGAL_STYLE = """<style id="world-fight-legal-style">
#worldFightDisclaimer{display:none;position:fixed;inset:0;z-index:10050;align-items:center;justify-content:center;padding:12px;box-sizing:border-box;background:rgba(2,6,12,.94);font-family:Arial,Helvetica,sans-serif;color:#eef4f5}
.wf-legal-open #worldFightDisclaimer{display:flex}
.wf-legal-open #worldFightFullscreenGate{display:none!important}
.wf-legal-open #worldFightIosGate{display:none!important}
#worldFightDisclaimer .wf-legal-card{width:min(640px,100%);max-height:calc(100dvh - 24px);overflow:auto;border:1px solid rgba(232,185,79,.75);background:linear-gradient(180deg,#0b1620,#070d14);box-shadow:0 0 40px rgba(70,220,216,.18);padding:18px 20px;box-sizing:border-box}
#worldFightDisclaimer h2{margin:0 0 4px;font-size:clamp(18px,4vmin,24px);color:#f2c35a;letter-spacing:.04em}
#worldFightDisclaimer .wf-legal-sub{margin:0 0 10px;color:#7fe3df;font-size:12px;letter-spacing:.2em}
#worldFightDisclaimer .wf-legal-lead{margin:0 0 8px;padding:8px 10px;border-inline-start:4px solid #e8b94f;background:rgba(232,185,79,.08);font-weight:800;font-size:clamp(13px,2.9vmin,16px);line-height:1.45;color:#fff4d6}
#worldFightDisclaimer ul{margin:0 0 10px;padding-inline-start:18px;line-height:1.5;font-size:clamp(12px,2.6vmin,15px)}
#worldFightDisclaimer li{margin-bottom:4px}
#worldFightDisclaimer .wf-legal-en{direction:ltr;text-align:left;color:#9fb2b8;font-size:11px;line-height:1.45;margin:8px 0 10px}
#worldFightDisclaimer label{display:flex;gap:10px;align-items:flex-start;cursor:pointer;font-size:clamp(13px,2.7vmin,15px);font-weight:700;margin:8px 0 12px}
#worldFightDisclaimer input[type=checkbox]{width:22px;height:22px;flex:0 0 auto;accent-color:#e8b94f;margin-top:1px}
#worldFightDisclaimer button{width:100%;min-height:48px;border:1px solid #e9bd62;background:linear-gradient(180deg,#f6d57a,#b67d24);color:#2a1a06;font-weight:900;font-size:16px;letter-spacing:.08em;cursor:pointer}
#worldFightDisclaimer button:disabled{filter:grayscale(1);opacity:.45;cursor:not-allowed}
@media (max-height:440px){#worldFightDisclaimer .wf-legal-card{padding:10px 14px}#worldFightDisclaimer h2{font-size:17px}#worldFightDisclaimer .wf-legal-sub{margin-bottom:4px}#worldFightDisclaimer ul{font-size:12px;line-height:1.35}#worldFightDisclaimer li{margin-bottom:2px}#worldFightDisclaimer .wf-legal-en{font-size:10px;margin:4px 0 6px}#worldFightDisclaimer label{margin:4px 0 8px}#worldFightDisclaimer button{min-height:42px}}
</style>
"""

LEGAL_MARKUP = """<div id="worldFightDisclaimer" role="dialog" aria-modal="true" aria-labelledby="wfLegalTitle"><div class="wf-legal-card" dir="rtl" lang="he">
<h2 id="wfLegalTitle">לפני שמתחילים – הבהרה</h2>
<p class="wf-legal-sub">SATIRE · PARODY · FREE</p>
<p class="wf-legal-lead">המשחק הוא סאטירה בלבד, כל קשר בין הדמויות למציאות הוא מקרי בהחלט, ואין בו שום קריאה או עידוד לאלימות בעולם האמיתי.</p>
<ul>
<li>הדמויות הן קריקטורות פרודיות ומוגזמות של אישי ציבור. אין במשחק תיאור של אירועים, עמדות, אמירות או מעשים אמיתיים של איש.</li>
<li>המשחק אינו קשור, ממומן או מאושר על ידי אף אדם, מפלגה או גוף המופיעים בו.</li>
<li>המשחק מופץ בחינם לחלוטין – ללא פרסומות, ללא רכישות וללא מטרת רווח.</li>
<li>נאספים נתוני שימוש אנונימיים בלבד (ללא עוגיות וללא פרטים מזהים) לשיפור המשחק.</li>
</ul>
<p class="wf-legal-en">This game is satire only. Any resemblance between the characters and reality is purely coincidental, and it contains no call for or encouragement of violence in the real world. Characters are exaggerated parody caricatures of public figures; the game is not affiliated with, sponsored or endorsed by any person, party or organisation shown. It is completely free and non-commercial (no ads, no purchases). Anonymous, cookie-free usage statistics are collected to improve the game.</p>
<label><input id="worldFightDisclaimerCheck" type="checkbox"><span>קראתי והבנתי שהמשחק הוא סאטירה בלבד, ואני מסכים/ה לתנאים. · I understand this is satire and agree.</span></label>
<button id="worldFightDisclaimerAccept" type="button" disabled>כניסה למשחק · ENTER</button>
</div></div>
<script>(() => {
  const key = '__VERSION__';
  let accepted = false;
  try { accepted = localStorage.getItem(key) === 'accepted'; } catch (error) { accepted = false; }
  if (!accepted) document.documentElement.classList.add('wf-legal-open');
  const check = document.getElementById('worldFightDisclaimerCheck');
  const accept = document.getElementById('worldFightDisclaimerAccept');
  check.addEventListener('change', () => { accept.disabled = !check.checked; });
  const enter = (event) => {
    if (!check.checked) return;
    event.preventDefault();
    try { localStorage.setItem(key, 'accepted'); } catch (error) {}
    document.documentElement.classList.remove('wf-legal-open');
    window.worldFightTrack?.('disclaimer_accepted', { path: 'disclaimer/accepted' });
    // The accept tap is a user gesture: use it to enter fullscreen on phones.
    if (innerWidth > innerHeight && (navigator.maxTouchPoints || 0) > 0) window.requestWorldFightFullscreen?.();
    window.layoutWorldFightViewport?.();
  };
  accept.addEventListener('click', enter);
  accept.addEventListener('pointerup', enter);
})();</script>"""

ANALYTICS_SCRIPT = """<script id="world-fight-analytics">
(() => {
  // Anonymous, cookie-free game analytics (GoatCounter). GoatCounter groups
  // rows by path, so each event carries a readable path such as
  // "fight/quick/bibi" or "playtime/05min"; the details also go in the title.
  // Events wait in a queue until count.js has loaded, so early events such as
  // the session start are not lost. Without a code they stay in a ring buffer
  // shown by ?diag=1.
  const code = '__CODE__';
  const queue = [];
  window.worldFightEvents = [];
  const send = (entry) => {
    const detail = Object.entries(entry.props || {}).filter(([k]) => k !== 'path').map(([k, v]) => k + '=' + v).join(' ');
    window.goatcounter.count({ path: entry.path, title: detail || entry.name, event: true });
  };
  const ready = () => Boolean(code && window.goatcounter && window.goatcounter.count);
  window.worldFightTrack = (name, props = {}) => {
    const entry = { name: String(name), props: props || {}, path: String((props && props.path) || ('event/' + name)), at: Date.now() };
    window.worldFightEvents.push(entry);
    if (window.worldFightEvents.length > 100) window.worldFightEvents.shift();
    if (!code) return;
    if (ready()) send(entry); else queue.push(entry);
  };
  if (code) {
    const tag = document.createElement('script');
    tag.async = true;
    tag.src = 'https://gc.zgo.at/count.js';
    tag.dataset.goatcounter = 'https://' + code + '.goatcounter.com/count';
    tag.addEventListener('load', () => { while (queue.length && ready()) send(queue.shift()); });
    document.head.appendChild(tag);
  }
  const device = (navigator.maxTouchPoints || 0) > 0 ? 'touch' : 'desktop';
  window.worldFightTrack('session_start', { path: 'session/start/' + device, w: innerWidth, h: innerHeight });
  // Play-time milestones: only visible time counts. The share of sessions
  // reaching each milestone is the play-time distribution.
  const milestones = [1, 3, 5, 10, 20, 30, 60];
  let visibleSeconds = 0;
  setInterval(() => {
    if (document.visibilityState !== 'visible') return;
    visibleSeconds += 5;
    if (milestones.length && visibleSeconds >= milestones[0] * 60) {
      const minutes = milestones.shift();
      window.worldFightTrack('playtime', { path: 'playtime/' + String(minutes).padStart(2, '0') + 'min' });
    }
  }, 5000);
})();
</script>
"""


def legal_markup(version: str = DISCLAIMER_VERSION) -> str:
    return LEGAL_MARKUP.replace("__VERSION__", version)


def analytics_script(code: str) -> str:
    safe = re.sub(r"[^a-z0-9-]", "", code.lower())
    return ANALYTICS_SCRIPT.replace("__CODE__", safe)


# Blocks written by older patcher versions without markers.
LEGACY_PATTERNS = (
    re.compile(r'<script id="world-fight-cache-retirement">.*?</script>\s*', re.S),
    re.compile(r'<style id="world-fight-responsive-style">.*?</style>\s*', re.S),
    re.compile(r'<script id="world-fight-responsive-script">.*?</script>\s*', re.S),
    re.compile(r'<div id="world-fight-startup">.*?<script>window\.initializeWorldFightShell\(\)</script>', re.S),
)


def _strip(html: str) -> str:
    html = re.sub(r"<!--wf:(\w+)-->.*?<!--/wf:\1-->", "", html, flags=re.S)
    for pattern in LEGACY_PATTERNS:
        html = pattern.sub("", html)
    return html


def patch(path: Path, config: dict | None = None) -> None:
    config = load_site_config() if config is None else config
    html = _strip(path.read_text(encoding="utf-8"))
    head = "<!--wf:head-->" + WEB_APP_LINKS + CACHE_RETIREMENT + analytics_script(config.get("goatcounter_code", "")) + HEAD_SHELL + LEGAL_STYLE + "<!--/wf:head-->"
    body = "<!--wf:body-->" + legal_markup() + BODY_SHELL + "<!--/wf:body-->"
    html = html.replace("</head>", head + "</head>", 1)
    html = re.sub(r"<body([^>]*)>", lambda match: "<body" + match.group(1) + ">" + body, html, count=1)
    path.write_text(html, encoding="utf-8")
    path.with_name("manifest.webmanifest").write_text(
        json.dumps(WEB_APP_MANIFEST, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    if ROTATE_ART.is_file():
        copyfile(ROTATE_ART, path.with_name("rotate-device-ensemble.webp"))
    path.with_name("index.service.worker.js").write_text(RETIRE_WORKER, encoding="utf-8")


if __name__ == "__main__":
    patch(Path("export/web/index.html"))
