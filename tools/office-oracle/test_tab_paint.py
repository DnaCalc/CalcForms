import copy
import json
import struct
import unittest

from PIL import Image

from build_tab_reference import DRAWING
from native_drawing import records
from tab_paint import native_headers, runtime_headers, sizes, window_probes


class TabPaintTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows = [row for row in json.loads((DRAWING / 'comparison.json').read_text(encoding='utf-8'))['observations']
                    if row['form'] == 'LayoutContainers']

    def drawing(self, row, name='TabsControl'):
        data = row['native_control_drawings'][name]
        return (DRAWING / data['file']).read_bytes(), data['font_metrics']

    def test_native_sizes_are_real_drawing_regions_at_both_scales(self):
        for row in self.rows:
            for name in ('TabsControl', 'PagesControl'):
                raw, metrics = self.drawing(row, name)
                self.assertEqual([37, 21, 47, 17] if row['zoom'] == 100 else [57, 33, 71, 27],
                                 sizes(native_headers(raw, metrics, ['First', 'Second'])))

    def test_missing_caption_or_exclusion_does_not_measure(self):
        raw, metrics = self.drawing(self.rows[0])
        with self.assertRaises(ValueError):
            native_headers(raw, metrics, ['Wrong', 'Second'])
        changed, offset = bytearray(raw), 0
        for kind, record in records(raw):
            if kind == 29:
                struct.pack_into('<I', changed, offset, 43)
                break
            offset += len(record)
        with self.assertRaises(ValueError):
            native_headers(changed, metrics, ['First', 'Second'])

    def test_changed_border_rectangle_is_rejected(self):
        raw, metrics = self.drawing(self.rows[0])
        changed, offset = bytearray(raw), 0
        for kind, record in records(raw):
            if kind == 29:
                right = struct.unpack_from('<i', changed, offset + 16)[0]
                struct.pack_into('<i', changed, offset + 16, right + 1)
                break
            offset += len(record)
        with self.assertRaises(ValueError):
            native_headers(changed, metrics, ['First', 'Second'])

    def test_unknown_mapping_or_raster_operation_is_rejected(self):
        raw, metrics = self.drawing(self.rows[0])
        for target, field_offset, value in [(76, 40, 0x00CC0020), (30, 0, 9)]:
            changed, offset = bytearray(raw), 0
            for kind, record in records(raw):
                if kind == target:
                    struct.pack_into('<I', changed, offset + field_offset, value)
                    break
                offset += len(record)
            with self.assertRaises(ValueError):
                native_headers(changed, metrics, ['First', 'Second'])

    def test_window_without_header_strokes_is_rejected(self):
        raw, metrics = self.drawing(self.rows[0])
        headers = native_headers(raw, metrics, ['First', 'Second'])
        with self.assertRaises(ValueError):
            window_probes(Image.new('RGB', (520, 380), (240, 240, 240)), [16, 192], headers)

    def test_runtime_face_edge_and_literal_must_agree(self):
        row = self.rows[0]
        control = next(c for c in row['measurements']['controls'] if c['name'] == 'TabsControl')
        node_id = control['calcforms']['node_id']
        scene = copy.deepcopy(row['retained_scene'])
        node = next(n for n in scene['nodes'] if n['id'] == node_id)
        edge = next(p for p in node['prims'] if p['op'] == 'draw_edge' and p['rect']['h'] < 20)
        edge['rect']['w'] += 1
        with self.assertRaises(ValueError):
            runtime_headers(scene, node_id, ['First', 'Second'], 4 / 3)

    def test_runtime_parent_transform_cannot_silently_change_sizes(self):
        scene = copy.deepcopy(self.rows[0]['retained_scene'])
        root = next(node for node in scene['nodes'] if node['id'] == scene['root'])
        root['transform']['sx'] = 2
        with self.assertRaises(ValueError):
            runtime_headers(scene, 7, ['First', 'Second'], 4 / 3)

    def test_runtime_ancestor_clip_cannot_hide_part_of_a_header(self):
        scene = copy.deepcopy(self.rows[0]['retained_scene'])
        root = next(node for node in scene['nodes'] if node['id'] == scene['root'])
        root['clip'] = dict(x=30, y=0, w=360, h=285)
        with self.assertRaises(ValueError):
            runtime_headers(scene, 7, ['First', 'Second'], 4 / 3)


if __name__ == '__main__':
    unittest.main()
