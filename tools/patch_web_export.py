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


def patch(path: Path) -> None:
    html = path.read_text(encoding="utf-8")
    if "getRegistrations()" not in html:
        html = html.replace("</head>", SCRIPT + "</head>", 1)
    path.write_text(html, encoding="utf-8")


if __name__ == "__main__":
    patch(Path("export/web/index.html"))
