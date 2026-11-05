"""Office-independent checks for comparison failures seen during live capture."""
import unittest

from PIL import Image

from layout_corpus import KINDS, load_corpus, walk
from layout_measurements import measure, native_controls
from layout_pixels import rank_controls


class LayoutMeasurementsTests(unittest.TestCase):
    def pixel_case(self):
        def control(name, bounds, runtime=None):
            return {'name': name, 'native': {'kind': 'Label', 'bounds': bounds},
                    'calcforms': {'bounds': bounds if runtime is None else runtime}}
        return {'pixels': {'comparable': True}, 'excel_facts': '10;8;100',
                'native_capture_validation': {'verified': True},
                'measurements': {'controls': [
                    control('Fractional', [-0.25, 0.25, 2, 1.5], [1, 0.5, 2, 1.5]),
                    control('Largest', [8, 6, 5, 5]),
                    control('Group.Child', [1, 1, 2, 2]),
                    control('Outside', [12, 12, 1, 1])]}}

    def test_pixel_regions_union_round_clip_and_rank_by_total_error(self):
        reference = Image.new('RGB', (10, 8), 'white')
        actual = reference.copy()
        for point in ((2, 1), (8, 6), (9, 7)):
            actual.putpixel(point, (0, 0, 0))
        result = rank_controls(self.pixel_case(), reference, actual)
        self.assertTrue(result['comparable'])
        self.assertEqual([1, 1], result['scale_px_per_pt'])
        self.assertEqual(['Largest', 'Fractional'], [r['name'] for r in result['ranked']])
        largest, fractional = result['ranked']
        self.assertEqual([8, 6, 10, 8], largest['roi_px'])
        self.assertEqual(1530, largest['absolute_rgb_error'])
        self.assertEqual([0, 0, 3, 2], fractional['roi_px'])
        self.assertEqual((6, 1, 765), (fractional['pixels'], fractional['different_pixels'], fractional['absolute_rgb_error']))
        self.assertEqual(['Group.Child', 'Outside'], [r['name'] for r in result['skipped']])
        scaled = rank_controls(self.pixel_case(), Image.new('RGB', (20, 24)), Image.new('RGB', (20, 24)))
        self.assertEqual([2, 3], scaled['scale_px_per_pt'])
        regions = {r['name']: r['roi_px'] for r in scaled['ranked']}
        self.assertEqual([0, 0, 6, 6], regions['Fractional'])

    def test_pixel_ranking_rejects_unqualified_or_unequal_clients(self):
        data = self.pixel_case()
        native = Image.new('RGB', (10, 8))
        result = rank_controls(data, native, Image.new('RGB', (11, 8)))
        self.assertFalse(result['comparable'])
        self.assertFalse(result['ranked'])
        data['native_capture_validation']['verified'] = False
        self.assertFalse(rank_controls(data, native, native)['comparable'])
        data['native_capture_validation']['verified'] = True
        data['pixels']['comparable'] = False
        self.assertFalse(rank_controls(data, native, native)['comparable'])
        data['pixels']['comparable'] = True
        data['excel_facts'] = '0;8;100'
        with self.assertRaisesRegex(ValueError, 'dimensions'):
            rank_controls(data, native, native)

    def test_corpus_covers_intrinsic_kinds_and_nested_sites(self):
        corpus = load_corpus()
        controls = [c for f in corpus['forms'] for c in walk(f['controls'])]
        self.assertEqual(KINDS, {c['kind'] for c in controls})
        self.assertTrue(any(c.get('children') for c in controls))
        self.assertTrue(any(c['left'] % 1 for c in controls))

    def test_duplicate_descendant_paths_cannot_silently_overwrite_facts(self):
        row = 'Group.Child;Label;12;18;138;18;Tahoma;8.25;0'
        with self.assertRaisesRegex(ValueError, 'Duplicate native'):
            native_controls(row + '\n' + row, 'LayoutContainers')

    def test_native_size_coercion_and_missing_controls_remain_visible(self):
        data = {
            'form': 'LayoutSelection',
            'excel_facts': '330;210;100\nDropdown;ComboBox;174;114;130;21.75;Tahoma;8.25;7\nExtra;Label;1;2;3;4;Tahoma;8.25;8',
            'calcforms_observation': 'Dropdown;ComboBox;174;114;130;21;8;174;114;8.25;7',
            'excel': {'geometry': {'client_size': [440, 280]}},
            'calcforms': {'geometry': {'client_size': [440, 280]}},
        }
        result = measure(data, {'nodes': [], 'text': {}})
        self.assertEqual(0.75, result['max_abs_delta_pt'])
        self.assertEqual([0, 0, 0, -0.75], result['controls'][0]['delta_pt'])
        self.assertEqual(['Extra'], result['missing_in_calcforms'])
        self.assertTrue(result['client_size_equal'])


if __name__ == '__main__':
    unittest.main()
