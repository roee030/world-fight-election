import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    "music": {"menu", "fight", "low_health"},
    "sfx": {"ui_focus", "ui_press", "ui_back", "jab_hit", "cross_hit", "kick_hit", "guard_hit", "whiff", "jump", "land", "special_ready", "special", "finisher", "victory", "loss"},
    "voice": {"round_one", "round_two", "final_round", "fight", "you_win", "you_lose"},
}

class AudioAssetTests(unittest.TestCase):
    def test_complete_ogg_cue_contract_and_provenance(self):
        audio = ROOT / "assets" / "audio"
        for category, cues in EXPECTED.items():
            actual = {path.stem for path in (audio / category).iterdir() if path.suffix in {".ogg", ".mp3"}}
            self.assertEqual(actual, cues)
            for cue in cues:
                matches = [path for path in (audio / category).glob(f"{cue}.*") if path.suffix in {".ogg", ".mp3"}]
                self.assertEqual(len(matches), 1)
                data = matches[0].read_bytes()
                self.assertGreater(len(data), 4_000)
                is_mp3 = data[:3] == b"ID3" or (data[0] == 0xFF and data[1] & 0xE0 == 0xE0)
                self.assertTrue(data[:4] == b"OggS" or is_mp3)
        credits = (audio / "README.md").read_text(encoding="utf-8")
        self.assertIn("Creative Commons CC0", credits)
        self.assertIn("Some unused menu stuff", credits)
        self.assertIn("Creative Commons Attribution 3.0", credits)
        self.assertIn("Alexandr Zhelanov", credits)
        self.assertIn("https://soundcloud.com/alexandr-zhelanov", credits)
        self.assertIn("Kenney Voiceover Pack: Fighter", credits)
        self.assertIn("Dark Sci-Fi Audio Pack", credits)
        self.assertIn("Kenney Impact Sounds", credits)
        self.assertIn("Kenney Interface Sounds", credits)

if __name__ == "__main__":
    unittest.main()
