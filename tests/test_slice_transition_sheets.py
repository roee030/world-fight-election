import unittest
from pathlib import Path

from PIL import Image

from tools.slice_transition_sheets import TRANSITION_NAMES, slice_transition_sheet


ROOT = Path(__file__).resolve().parents[1]


class TransitionSheetTests(unittest.TestCase):
    def test_first_transition_batch_slices_to_grounded_rgba_frames(self) -> None:
        for fighter_id in ("benny_gantz", "joint_list"):
            sheet = ROOT / "assets" / "characters" / "sprite-sheets" / "transitions" / f"{fighter_id.replace('_', '-')}-transitions.png"
            self.assertTrue(sheet.exists(), f"missing transition sheet for {fighter_id}")
            source = Image.open(sheet).convert("RGBA")
            source_bounds = source.getchannel("A").point(lambda alpha: 255 if alpha > 12 else 0).getbbox()
            self.assertIsNotNone(source_bounds)
            self.assertGreater(source_bounds[0], 0, f"{fighter_id} art touches the left sheet edge")
            self.assertGreater(source_bounds[1], 0, f"{fighter_id} art touches the top sheet edge")
            self.assertLess(source_bounds[2], source.width, f"{fighter_id} art touches the right sheet edge")
            self.assertLess(source_bounds[3], source.height, f"{fighter_id} art touches the bottom sheet edge")
            frames = slice_transition_sheet(sheet, save=False)
            self.assertEqual(len(frames), len(TRANSITION_NAMES))
            canonical = Image.open(ROOT / "assets" / "characters" / "sprites" / f"{fighter_id}-0.png").convert("RGBA")
            canonical_height = canonical.getchannel("A").getbbox()[3] - canonical.getchannel("A").getbbox()[1]
            transition_height = frames[0].getchannel("A").getbbox()[3] - frames[0].getchannel("A").getbbox()[1]
            self.assertLessEqual(abs(canonical_height - transition_height), 2, f"{fighter_id} idle changes apparent size")
            for index, frame in enumerate(frames):
                self.assertEqual(frame.mode, "RGBA", f"{fighter_id} transition {index} lost alpha")
                self.assertEqual(frame.size, (512, 512))
                bounds = frame.getchannel("A").getbbox()
                self.assertIsNotNone(bounds)
                self.assertLessEqual(bounds[2], 490)
                self.assertEqual(bounds[3], 490, f"{fighter_id} transition {index} is not grounded")


if __name__ == "__main__":
    unittest.main()
