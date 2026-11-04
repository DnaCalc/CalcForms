"""Office-independent checks for comparison failures seen during live capture."""
import unittest

from layout_corpus import KINDS, load_corpus, walk
from layout_measurements import measure, native_controls


class LayoutMeasurementsTests(unittest.TestCase):
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
