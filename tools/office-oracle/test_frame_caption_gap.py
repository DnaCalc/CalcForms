import copy
import json
import struct
import unittest

from PIL import Image

from build_frame_gap_reference import DRAWING
from frame_caption_gap import native_gap, runtime_gap, window_probes
from native_drawing import records


class FrameCaptionGapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows = [row for row in json.loads((DRAWING / 'comparison.json').read_text(encoding='utf-8'))['observations']
                    if row['form'] == 'LayoutContainers']

    def drawing(self, row):
        data = row['native_control_drawings']['Group']
        return (DRAWING / data['file']).read_bytes(), data['font_metrics']

    def test_both_native_gaps_are_observed_and_match_window_boundaries(self):
        for row in self.rows:
            raw, metrics = self.drawing(row)
            result = native_gap(raw, metrics, 'Details')
            self.assertEqual([10, 40] if row['zoom'] == 100 else [15, 64], result['horizontal_gap_px'])
            self.assertEqual([4, 4] if row['zoom'] == 100 else [6, 6], result['horizontal_padding_px'])
            image = Image.open(DRAWING / row['images'][0]['file']).convert('RGB')
            origin = [16, 16] if row['zoom'] == 100 else [24, 24]
            self.assertEqual(4, len(window_probes(image, origin, result)['points_px']))

    def test_wrong_caption_does_not_measure(self):
        raw, metrics = self.drawing(self.rows[0])
        with self.assertRaises(ValueError):
            native_gap(raw, metrics, 'Wrong')

    def test_wrong_exclusion_boundary_is_rejected_by_actual_window(self):
        row = self.rows[0]
        raw, metrics = self.drawing(row)
        changed, offset = bytearray(raw), 0
        for kind, record in records(raw):
            if kind == 29:
                struct.pack_into('<i', changed, offset + 8, 11)
                break
            offset += len(record)
        result = native_gap(changed, metrics, 'Details')
        image = Image.open(DRAWING / row['images'][0]['file']).convert('RGB')
        with self.assertRaises(ValueError):
            window_probes(image, [16, 16], result)

    def test_blank_window_does_not_qualify_a_gap(self):
        raw, metrics = self.drawing(self.rows[0])
        with self.assertRaises(ValueError):
            window_probes(Image.new('RGB', (520, 380), (240, 240, 240)), [16, 16], native_gap(raw, metrics, 'Details'))

    def test_runtime_caption_mask_must_have_the_frame_face(self):
        row = self.rows[0]
        scene = copy.deepcopy(row['retained_scene'])
        control = next(c for c in row['measurements']['controls'] if c['name'] == 'Group')
        node_id = control['calcforms']['node_id']
        node = next(n for n in scene['nodes'] if n['id'] == node_id)
        mask = next(p for p in node['prims'] if p['op'] == 'fill_rect' and p['rect']['w'] < node['bounds']['w'])
        mask['paint']['Solid']['red'] = 0
        with self.assertRaises(ValueError):
            runtime_gap(scene, node_id, 'Details', 4 / 3)

    def test_runtime_border_cannot_be_redrawn_over_the_caption_mask(self):
        row = self.rows[0]
        scene = copy.deepcopy(row['retained_scene'])
        node_id = next(c['calcforms']['node_id'] for c in row['measurements']['controls'] if c['name'] == 'Group')
        node = next(n for n in scene['nodes'] if n['id'] == node_id)
        edge = next(p for p in node['prims'] if p['op'] == 'draw_edge')
        node['prims'].remove(edge)
        node['prims'].append(edge)
        with self.assertRaises(ValueError):
            runtime_gap(scene, node_id, 'Details', 4 / 3)


if __name__ == '__main__':
    unittest.main()
