import copy
import json
import unittest

from PIL import Image, ImageDraw

from layout_corpus import ROOT
from tab_text_cells import cell, qualify


class TabTextCellsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads'
        rows = json.loads((cls.base / 'oxforms-jbjp.110/comparison.json').read_text(encoding='utf-8'))['observations']
        drawings = json.loads((cls.base / 'oxforms-jbjp.106/comparison.json').read_text(encoding='utf-8'))['observations']
        cls.row = next(r for r in rows if r['form'] == 'LayoutContainers' and r['zoom'] == 100)
        cls.drawing = next(r for r in drawings if r['form'] == 'LayoutContainers' and r['zoom'] == 100)

    def inputs(self):
        row = copy.deepcopy(self.row)
        row['native_control_drawings'] = copy.deepcopy(self.drawing['native_control_drawings'])
        image = Image.open(self.base / 'oxforms-jbjp.110' / row['images'][0]['file']).convert('RGB')
        return row, copy.deepcopy(self.drawing['retained_scene']), image

    def test_independent_native_cells_do_not_follow_runtime_advances(self):
        row, scene, image = self.inputs()
        result = qualify(row, scene, image.size, image, self.base / 'oxforms-jbjp.106')
        native = result['TabsControl']['native'][0]
        self.assertEqual([24, 30, 32, 36, 41, 45], native['character_edges_px'])
        self.assertNotEqual(native['character_edges_px'], result['TabsControl']['calcforms'][0]['character_edges_px'])

    def test_border_only_window_cannot_qualify_caption_ink(self):
        row, scene, image = self.inputs()
        result = qualify(row, scene, image.size, image, self.base / 'oxforms-jbjp.106')
        for facts in result.values():
            for item in facts['native']:
                l, t, r, b = map(round, item['roi_px'])
                ImageDraw.Draw(image).rectangle((l, t, r - 1, b - 1), fill=(240, 240, 240))
        with self.assertRaisesRegex(ValueError, 'empty'):
            qualify(row, scene, image.size, image, self.base / 'oxforms-jbjp.106')

    def test_changed_native_cells_or_runtime_literal_reject(self):
        row, scene, image = self.inputs()
        row['native_control_drawings']['TabsControl']['text'][0]['cell_edges_px'][-1] += 1
        with self.assertRaises(ValueError):
            qualify(row, scene, image.size, image, self.base / 'oxforms-jbjp.106')
        row, scene, image = self.inputs()
        for run in scene['text'].values():
            if run['source'] == 'First':
                run['source'] = 'Wrong'
        with self.assertRaises(ValueError):
            qualify(row, scene, image.size, image, self.base / 'oxforms-jbjp.106')

    def test_invalid_or_invisible_character_cells_reject(self):
        for positions, clip in [([0, 4], [8, 0, 9, 10]), ([4, 0], [0, 0, 10, 10]), ([0, float('nan')], [0, 0, 10, 10])]:
            with self.assertRaises(ValueError):
                cell('A', positions, 8, 8, 2, clip)


if __name__ == '__main__':
    unittest.main()
