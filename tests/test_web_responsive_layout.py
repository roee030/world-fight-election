import unittest

from tools.patch_web_export import fit_viewport


class ResponsiveViewportTests(unittest.TestCase):
    def test_landscape_matrix_is_centered_bounded_and_sixteen_by_nine(self):
        for width, height in [
            (568, 320),
            (667, 375),
            (740, 360),
            (844, 390),
            (915, 412),
            (1024, 600),
            (1280, 720),
        ]:
            with self.subTest(viewport=(width, height)):
                result = fit_viewport(width, height)
                self.assertFalse(result["portrait"])
                self.assertAlmostEqual(result["width"] / result["height"], 16 / 9, places=6)
                self.assertGreaterEqual(result["left"], 0)
                self.assertGreaterEqual(result["top"], 0)
                self.assertLessEqual(result["left"] + result["width"], width + 1e-9)
                self.assertLessEqual(result["top"] + result["height"], height + 1e-9)

    def test_safe_area_is_removed_before_fitting_canvas(self):
        result = fit_viewport(844, 390, {"left": 47, "right": 34, "top": 0, "bottom": 21})
        self.assertFalse(result["portrait"])
        self.assertGreaterEqual(result["left"], 47)
        self.assertLessEqual(result["left"] + result["width"], 844 - 34)
        self.assertLessEqual(result["top"] + result["height"], 390 - 21)
        self.assertAlmostEqual(result["width"] / result["height"], 16 / 9, places=6)

    def test_portrait_uses_rotate_gate_instead_of_tiny_canvas(self):
        for width, height in [(320, 568), (390, 844), (412, 915)]:
            with self.subTest(viewport=(width, height)):
                result = fit_viewport(width, height)
                self.assertTrue(result["portrait"])
                self.assertEqual(result["width"], 0)
                self.assertEqual(result["height"], 0)


if __name__ == "__main__":
    unittest.main()
