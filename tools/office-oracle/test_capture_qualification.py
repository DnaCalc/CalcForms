import unittest
from PIL import Image, ImageDraw

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

    def test_backgrounds_cannot_qualify_blank_or_partial_text(self):
        complete = Image.new('RGB', (60, 40), (240, 240, 240))
        ImageDraw.Draw(complete).rectangle((4, 4, 12, 10), fill='black')
        ImageDraw.Draw(complete).rectangle((4, 24, 12, 30), fill=(153, 153, 153))
        partial = complete.copy()
        ImageDraw.Draw(partial).rectangle((0, 20, 59, 39), fill=(240, 240, 240))
        text = [dict(control='Upper', roi_px=[0, 0, 30, 18], font_height_px=12),
                dict(control='DisabledLower', roi_px=[0, 20, 30, 38], font_height_px=12, disabled=True)]
        background = [dict(control='Face', pixel=[55, 35], expected_rgb=[240, 240, 240])]
        self.assertTrue(choose_capture(partial, partial, background)['verified'])
        result = choose_capture(partial, complete, background, text)
        self.assertEqual('parent', result['selected'])
        self.assertFalse(result['candidates']['composite']['text_samples'][1]['matches'])
        self.assertFalse(choose_capture(partial, partial, background, text)['verified'])

    def test_selected_white_ink_qualifies_but_an_empty_blue_row_does_not(self):
        selected = Image.new('RGB', (40, 20), (0, 120, 215))
        text = [dict(control='Choices', roi_px=[0, 0, 40, 20], font_height_px=12)]
        self.assertFalse(choose_capture(selected, selected, [], text)['verified'])
        actual = selected.copy()
        ImageDraw.Draw(actual).rectangle((5, 4, 11, 11), fill='white')
        before = actual.tobytes()
        self.assertEqual('composite', choose_capture(actual, selected, [], text)['selected'])
        self.assertEqual(before, actual.tobytes())


if __name__ == '__main__':
    unittest.main()
