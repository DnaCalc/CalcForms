"""Check the saved native data-entry fixture and its explicit coverage limits."""
import hashlib
import json
from pathlib import Path
import zipfile


def main():
    root = Path(__file__).resolve().parents[2]
    fixture = root / 'fixtures/workbooks/data-entry'
    evidence = root / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.105'
    pins = json.loads((evidence / 'fixture-sha256.json').read_text(encoding='utf-8'))
    assert set(pins) == {'authoring.json', 'entry.bas', 'form-code.bas', 'order-entry.xlsm',
                         'OrderEntryForm-qualified.frm', 'OrderEntryForm-qualified.frx'}
    for name, expected in pins.items():
        assert hashlib.sha256((fixture / name).read_bytes()).hexdigest() == expected, name
    native = json.loads((fixture / 'authoring.json').read_text(encoding='utf-8'))
    assert native['workbook_sha256'] == pins['order-entry.xlsm']
    assert not native['initial_state'].startswith('CALCFORMS_NATIVE_ERROR:')
    assert native['initial_trace'] == 'Initialize|Team.Change:Sales|Product.Change:Bolt|Product.Click:Bolt'
    with zipfile.ZipFile(fixture / 'order-entry.xlsm') as book:
        assert 'xl/vbaProject.bin' in book.namelist()
    exported = (fixture / 'OrderEntryForm-qualified.frm').read_text(encoding='cp1252')
    assert '"OrderEntryForm-qualified.frx":0000' in exported
    # Native VBE inserts member attributes; compare the application code after stripping them.
    code = exported[exported.index('Option Explicit'):]
    code = '\n'.join(line for line in code.splitlines() if not line.startswith('Attribute '))
    assert code.strip() == (fixture / 'form-code.bas').read_text(encoding='utf-8').strip()
    coverage = json.loads((evidence / 'coverage.json').read_text(encoding='utf-8'))
    assert len(coverage['rows']) == 210
    assert all(row['result'] == 'fail' and row['native_measured'] is None for row in coverage['rows'])
    assert {row['scale_percent'] for row in coverage['rows']} == {100, 150}
    cleanup = json.loads((evidence / 'cleanup.json').read_text(encoding='utf-8'))
    assert cleanup['excel_launches_by_this_session'] == 1
    assert cleanup['closed'] == 'terminated_owned_handle' and cleanup['workbook_unchanged']
    assert not cleanup['input_desktop_switched'] and cleanup['security_changes'] == 0
    print('OK real workbook fixture, native initial observations, 210 missing measurements and owned cleanup')


if __name__ == '__main__':
    main()
