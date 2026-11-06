import unittest

from keyboard_probes import parse


class KeyboardProbeTests(unittest.TestCase):
    def test_missing_phases_and_observer_errors_do_not_pass(self):
        text = 'Choices~scrolling~initial~index=1;top=0\nChoices~scrolling~page_down_1~index=7;top=1\nChoices~scrolling~page_down_2~index=13;top=7\nChoices~scrolling~home~index=0;top=0\n'
        self.assertEqual(4, len(parse(text)['Choices']['scrolling']))
        with self.assertRaises(ValueError):
            parse(text.rsplit('\n', 2)[0] + '\n')
        with self.assertRaises(ValueError):
            parse('CALCFORMS_NATIVE_ERROR:91')
        with self.assertRaises(ValueError):
            parse(text + 'Choices~scrolling~home~index=0;top=0\n')

    def test_observed_unsupported_property_is_a_result_not_an_unknown(self):
        text = 'Choices~scrolling~initial~top_error=438\nChoices~scrolling~page_down_1~top_error=438\nChoices~scrolling~page_down_2~top_error=438\nChoices~scrolling~home~top_error=438\n'
        self.assertEqual('top_error=438', parse(text)['Choices']['scrolling'][0]['value'])


if __name__ == '__main__':
    unittest.main()
