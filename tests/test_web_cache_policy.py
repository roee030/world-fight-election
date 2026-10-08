from pathlib import Path
import unittest


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


if __name__ == "__main__":
    unittest.main()
