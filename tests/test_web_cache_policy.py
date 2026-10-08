from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from tools.patch_web_export import patch


ROOT = Path(__file__).resolve().parents[1]


class WebCachePolicyTests(unittest.TestCase):
    def test_pages_build_does_not_pin_old_game_package(self):
        preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        self.assertIn("variant/extensions_support=false", preset)
        self.assertIn("progressive_web_app/enabled=false", preset)
        patcher = (ROOT / "tools" / "patch_web_export.py").read_text(encoding="utf-8")
        workflow = (ROOT / ".github" / "workflows" / "deploy-pages.yml").read_text(encoding="utf-8")
        self.assertIn("getRegistrations()", patcher)
        self.assertIn("caches.keys()", patcher)
        self.assertIn("python tools/patch_web_export.py", workflow)

    def test_pages_build_replaces_the_old_worker_with_a_self_destructing_worker(self):
        with TemporaryDirectory() as folder:
            root = Path(folder)
            html = root / "index.html"
            html.write_text("<html><head></head><body></body></html>", encoding="utf-8")
            patch(html)
            worker = (root / "index.service.worker.js").read_text(encoding="utf-8")
            patched_html = html.read_text(encoding="utf-8")
            self.assertIn("self.registration.unregister()", worker)
            self.assertIn("caches.keys()", worker)
            self.assertIn("self.clients.claim()", worker)
            self.assertIn("calc(100dvh * 16 / 9)", patched_html)
            self.assertIn("justify-content:center", patched_html)
            self.assertIn("chrome-start-menu", patched_html)
            self.assertIn("START FIGHT", patched_html)
            self.assertIn("worldFightMenuAction", patched_html)


if __name__ == "__main__":
    unittest.main()
