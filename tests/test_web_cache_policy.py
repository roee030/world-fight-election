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
        self.assertNotIn("phone-orientation", preset)
        self.assertNotIn("#canvas{display:block;width:100%!important;height:100%!important", preset)
        patcher = (ROOT / "tools" / "patch_web_export.py").read_text(encoding="utf-8")
        workflow = (ROOT / ".github" / "workflows" / "deploy-pages.yml").read_text(encoding="utf-8")
        self.assertIn("getRegistrations()", patcher)
        self.assertIn("caches.keys()", patcher)
        self.assertIn("python tools/patch_web_export.py", workflow)

    def test_pages_build_replaces_the_old_worker_with_a_self_destructing_worker(self):
        with TemporaryDirectory() as folder:
            root = Path(folder)
            html = root / "index.html"
            html.write_text('<html><head></head><body><script src="index.js"></script></body></html>', encoding="utf-8")
            patch(html)
            worker = (root / "index.service.worker.js").read_text(encoding="utf-8")
            patched_html = html.read_text(encoding="utf-8")
            self.assertIn("self.registration.unregister()", worker)
            self.assertIn("caches.keys()", worker)
            self.assertIn("self.clients.claim()", worker)
            self.assertIn("visualViewport", patched_html)
            self.assertIn("safe-area-inset-left", patched_html)
            self.assertIn("worldFightRotateGate", patched_html)
            self.assertIn("layoutWorldFightViewport", patched_html)
            self.assertIn("worldFightSetReady", patched_html)
            self.assertIn("worldFightSetMenuVisible", patched_html)
            self.assertIn("worldFightAcknowledgeAction", patched_html)
            self.assertIn("world-fight-startup", patched_html)
            self.assertIn("START FIGHT", patched_html)
            self.assertIn("worldFightMenuAction", patched_html)
            self.assertLess(
                patched_html.index('<div id="world-fight-startup">'),
                patched_html.index('<script src="index.js">'),
                "startup actions must parse before the blocking engine loader",
            )
            patch(html)
            patched_twice = html.read_text(encoding="utf-8")
            self.assertEqual(patched_twice.count('id="world-fight-responsive-script"'), 1)


if __name__ == "__main__":
    unittest.main()
