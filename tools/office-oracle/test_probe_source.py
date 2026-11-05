import unittest

from probe_source import validate_probe_source


class ProbeSourceTests(unittest.TestCase):
    def test_local_handler_is_required_for_each_entry(self):
        source = 'Public Function Good() As String\nOn Error GoTo Failed\nGood = "ok"\nFailed:\nEnd Function\n'
        self.assertEqual({'good'}, validate_probe_source(source))
        with self.assertRaisesRegex(ValueError, 'Bad'):
            validate_probe_source(source + 'Public Function Bad() As String\nBad = "unprotected"\nEnd Function\n')

    def test_comments_and_strings_do_not_supply_a_handler(self):
        for body in ["' On Error Resume Next", 'Result = "On Error Resume Next"', 'On Error GoTo 0']:
            with self.assertRaisesRegex(ValueError, 'own On Error'):
                validate_probe_source('Public Function Result() As String\n' + body + '\nEnd Function\n')

    def test_missing_error_label_is_rejected_before_excel(self):
        with self.assertRaisesRegex(ValueError, 'label is missing'):
            validate_probe_source('Public Function Result() As String\nOn Error GoTo Missing\nEnd Function\n')


if __name__ == '__main__':
    unittest.main()
