import unittest
from PIL import Image

from capture_qualification import choose_capture


class CaptureQualificationTests(unittest.TestCase):
    def setUp(self):
        self.grey = Image.new('RGB', (8, 8), (240, 240, 240))
        self.white = Image.new('RGB', (8, 8), 'white')
        self.probes = [{'control': 'Pages', 'pixel': [4, 4], 'expected_rgb': [240, 240, 240]}]

    def test_bad_child_capture_selects_the_complete_parent_image(self):
        before = self.white.tobytes(), self.grey.tobytes()
        result = choose_capture(self.white, self.grey, self.probes)
        self.assertEqual('parent', result['selected'])
        self.assertEqual(before, (self.white.tobytes(), self.grey.tobytes()))

    def test_valid_composite_is_preferred(self):
        self.assertEqual('composite', choose_capture(self.grey, self.white, self.probes)['selected'])

    def test_both_bad_captures_are_unverified(self):
        result = choose_capture(self.white, self.white, self.probes)
        self.assertFalse(result['verified'])
        self.assertIsNone(result['selected'])

    def test_out_of_bounds_probe_cannot_pass(self):
        self.probes[0]['pixel'] = [8, 8]
        self.assertFalse(choose_capture(self.grey, self.grey, self.probes)['verified'])

    def test_a_valid_page_cannot_hide_a_blank_frame(self):
        composite = self.grey.copy()
        composite.putpixel((2, 2), (255, 255, 255))
        probes = self.probes + [{'control': 'Frame', 'kind': 'Frame', 'pixel': [2, 2], 'expected_rgb': [240, 240, 240]}]
        result = choose_capture(composite, self.grey, probes)
        self.assertEqual('parent', result['selected'])
        self.assertFalse(result['candidates']['composite']['matches'])
        self.assertFalse(choose_capture(composite, composite, probes)['verified'])


if __name__ == '__main__':
    unittest.main()
