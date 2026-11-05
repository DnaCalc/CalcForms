"""Failure cases which a compatibility report must not turn into passes."""
import copy
import hashlib
import json
import math
from pathlib import Path
import tempfile
import unittest

from PIL import Image, ImageDraw

from forms_parity import check, color_class, dotted_rectangle, ink_geometry, report_observation, replay, rounded, summarize
from layout_corpus import ROOT


class FormsParityTests(unittest.TestCase):
    def case(self):
        control = dict(name='Prompt', native=dict(kind='Label', bounds=[1, 1, 12, 9], tab_index=0),
                       calcforms=dict(kind='Label', bounds=[1, 1, 12, 9], tab_index=0))
        return dict(form='LayoutCommon', zoom=100, excel_facts='20;15;100',
                    excel=dict(geometry=dict(client_size=[20, 15])),
                    calcforms=dict(geometry=dict(client_size=[20, 15])),
                    native_capture_validation=dict(verified=True), pixels=dict(different_fraction=0),
                    measurements=dict(controls=[control], missing_in_calcforms=[], missing_in_excel=[]))

    def test_property_colours_override_subpixel_masks_without_duplicating_rows(self):
        data = self.case()
        native = Image.new('RGB', (20, 15), 'white')
        actual = native.copy()
        ImageDraw.Draw(native).rectangle((2, 2, 5, 4), fill=(0, 70, 100))
        ImageDraw.Draw(actual).rectangle((2, 2, 5, 4), fill='black')
        before = report_observation(data, native, actual)['controls'][0]
        self.assertEqual('fail', next(r for r in before['items'] if r['metric'] == 'text_class')['status'])
        data['colour_measurements'] = {'Prompt': {'text_class': dict(native=['dark-text'], calcforms=['dark-text']),
                                                'fill_class': dict(native='white', calcforms='white')}}
        after = report_observation(data, native, actual)['controls'][0]
        for metric in ('text_class', 'fill_class'):
            rows = [r for r in after['items'] if r['metric'] == metric]
            self.assertEqual(1, len(rows))
            self.assertEqual('pass', rows[0]['status'])
        self.assertEqual(before['text_measurements'], after['text_measurements'])

    def test_missing_measurements_and_different_vector_lengths_fail(self):
        self.assertEqual('fail', check('text', 'baseline', actual=12)['status'])
        self.assertEqual(0, check('text', 'baseline', actual=12)['measurement_count'])
        self.assertEqual('fail', check('text', 'ink', [1, 2], [1, 2, 3], 2)['status'])
        self.assertEqual('fail', check('text', 'lines', ['a', 'b'], ['ab'], 2)['status'])
        with self.assertRaisesRegex(ValueError, 'Non-finite'):
            check('layout', 'edges', [0, math.nan], [0, 1], 1)
        self.assertEqual([1, 2, 3], rounded([.5, 1.5, 2.5]))

    def test_ink_mask_ignores_light_antialias_and_preserves_selected_white_text(self):
        a = Image.new('RGB', (20, 20), 'white')
        d = ImageDraw.Draw(a)
        d.rectangle((2, 2, 6, 6), fill='black')
        d.rectangle((2, 12, 18, 18), fill=(0, 120, 215))
        d.rectangle((3, 13, 7, 17), fill='white')
        measured = ink_geometry(a, [0, 0, 20, 20])
        self.assertEqual([2, 2, 8, 18], measured['ink_bounds_px'])
        self.assertEqual([[2, 7], [13, 18]], measured['line_bands_px'])
        b = a.copy()
        b.putpixel((1, 2), (225, 225, 225))
        self.assertEqual(measured, ink_geometry(b, [0, 0, 20, 20]))
        self.assertEqual('control-face', color_class((240, 240, 240)))

    def test_layout_tolerance_and_pixel_guard_do_not_hide_other_failures(self):
        data = self.case()
        native = Image.new('RGB', (20, 15), 'white')
        ImageDraw.Draw(native).rectangle((2, 2, 5, 5), fill='black')
        actual = native.copy()
        data['measurements']['controls'][0]['calcforms']['bounds'][0] += 1.1
        result = report_observation(data, native, actual)
        items = {r['metric']: r for r in result['controls'][0]['items']}
        self.assertEqual('fail', items['rectangle_edges']['status'])
        self.assertAlmostEqual(1.1, items['rectangle_edges']['max_delta'])
        self.assertEqual('fail', items['exact_line_breaks']['status'])
        self.assertEqual('fail', items['tab_order']['status'])
        self.assertEqual('pass', items['tab_index']['status'])
        self.assertEqual('pass', result['pixel_regression_guard']['status'])
        summary = summarize([result])
        self.assertGreater(summary['missing_measurements'], 0)
        self.assertTrue(all(r['category'] != 'regression_only' for r in summary['measured_failures']))

    def test_focus_and_tab_border_do_not_become_text_ink(self):
        image = Image.new('RGB', (50, 25), 'white')
        draw = ImageDraw.Draw(image)
        draw.rectangle((10, 8, 25, 14), fill='black')
        for x in range(4, 35, 2):
            image.putpixel((x, 3), (0, 0, 0))
            image.putpixel((x, 19), (0, 0, 0))
        for y in range(3, 20, 2):
            image.putpixel((4, y), (0, 0, 0))
            image.putpixel((34, y), (0, 0, 0))
        focus = dotted_rectangle(image, [0, 0, 50, 25])
        self.assertEqual([4, 3, 35, 20], focus)
        self.assertEqual([10, 8, 26, 15], ink_geometry(image, [0, 0, 50, 25], focus=focus)['ink_bounds_px'])
        draw.line((42, 0, 42, 24), fill='black')
        self.assertEqual([10, 8, 26, 15], ink_geometry(image, [0, 0, 50, 25], focus=focus, font_height_px=12)['ink_bounds_px'])

    def test_extra_text_line_and_unqualified_captures_remain_visible(self):
        data = self.case()
        native = Image.new('RGB', (20, 15), 'white')
        ImageDraw.Draw(native).rectangle((2, 2, 5, 3), fill='black')
        actual = native.copy()
        ImageDraw.Draw(actual).rectangle((2, 7, 5, 8), fill='black')
        result = report_observation(data, native, actual)
        items = {r['metric']: r for r in result['controls'][0]['items']}
        self.assertEqual(('fail', 1, 2), tuple(items['visible_line_count'][k] for k in ('status', 'native', 'calcforms')))
        data['native_capture_validation']['verified'] = False
        result = report_observation(data, native, actual)
        items = {r['metric']: r for r in result['controls'][0]['items']}
        self.assertEqual('fail', items['ink_bounds']['status'])
        self.assertEqual(0, items['ink_bounds']['measurement_count'])
        bad = copy.deepcopy(data)
        bad['measurements']['controls'] *= 2
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            report_observation(bad, native, actual)

    def test_replay_requires_image_identity_and_reports_missing_second_scale(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'target') as directory:
            path = Path(directory) / 'comparison.json'
            row = self.case()
            row['images'] = []
            for engine in ('excel', 'calcforms'):
                image_path = path.parent / ('test-' + engine + '.png')
                Image.new('RGB', (20, 15), 'white').save(image_path)
                row['images'].append(dict(file=image_path.name, sha256=hashlib.sha256(image_path.read_bytes()).hexdigest()))
            path.write_text(json.dumps(dict(observations=[row])), encoding='utf-8')
            result = replay(path)
            self.assertEqual('fail', result['coverage'][0]['status'])
            row['images'][0]['sha256'] = '0' * 64
            path.write_text(json.dumps(dict(observations=[row])), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'hash differs'):
                replay(path)
            path.write_text(json.dumps(dict(observations=[])), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'No form'):
                replay(path)


if __name__ == '__main__':
    unittest.main()
