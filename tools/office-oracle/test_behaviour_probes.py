import unittest

from behaviour_probes import parse
from input_probes import native_source, parse as parse_input, validate_native_signatures
from layout_corpus import load_corpus


class BehaviourProbeTests(unittest.TestCase):
    def complete(self):
        return ''.join('InputName~' + metric + '~' + step + '~' + value + '\n'
                       for metric in ('event_order', 'value_changes')
                       for step, value in [('initial', ''), ('set', 'Change|'), ('repeat', 'Change|'), ('restore', 'Change|Change|')])

    def test_incomplete_duplicate_and_failed_phases_cannot_earn_credit(self):
        self.assertEqual(2, len(parse(self.complete())['InputName']))
        for text in (self.complete().replace('InputName~event_order~repeat~Change|\n', ''),
                     self.complete() + 'InputName~event_order~set~Change|\n',
                     self.complete() + 'CALCFORMS_NATIVE_ERROR:91:failed'):
            with self.assertRaises(ValueError):
                parse(text)

    def test_native_tab_and_multipage_index_is_checked_before_office(self):
        form = next(form for form in load_corpus()['forms'] if form['name'] == 'LayoutContainers')
        good = native_source(form)
        validate_native_signatures(form, good)
        self.assertIn('TabsControl_MouseDown(ByVal Index As Long, ', good)
        self.assertIn('PagesControl_MouseDown(ByVal Index As Long, ', good)
        for name in ('TabsControl', 'PagesControl'):
            bad = good.replace(name + '_MouseDown(ByVal Index As Long, ', name + '_MouseDown(')
            with self.assertRaisesRegex(ValueError, 'signature differs'):
                validate_native_signatures(form, bad)

    def test_real_repeated_container_focus_is_preserved_but_open_cycles_reject(self):
        text = '@initial~NestedInput\n@visit~NestedInput\n@visit~PagesControl\n@visit~PagesControl\n@visit~NestedInput\nGroup~hit_testing~interior~Group.MouseDown|\n'
        result = parse_input(text)
        self.assertEqual(['NestedInput', 'PagesControl', 'PagesControl', 'NestedInput'], result['tab_cycle'])
        self.assertEqual(['Group'], result['hits']['Group'])
        with self.assertRaisesRegex(ValueError, 'incomplete'):
            parse_input(text.replace('@visit~NestedInput\nGroup', 'Group'))
        with self.assertRaisesRegex(ValueError, 'Duplicate initial'):
            parse_input(text + '@initial~NestedInput\n')


if __name__ == '__main__':
    unittest.main()
