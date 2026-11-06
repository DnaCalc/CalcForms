"""Validate original real-workbook scenario observations without starting Office."""
import hashlib
import json

from capture_order_entry_scenarios import SOURCE, WORKBOOK
from layout_corpus import ROOT
from validate_behaviour_reference import files


def validate():
    directory = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.105.1/native'
    files(directory)
    data = json.loads((directory / 'observations.json').read_text(encoding='utf-8'))
    assert data['workbook_sha256'] == hashlib.sha256(WORKBOOK.read_bytes()).hexdigest()
    assert data['original_handlers_unchanged'] and data['workbook_unchanged']
    assert (directory / 'observer.bas').read_text(encoding='utf-8') == SOURCE
    assert not data['owner']['interactive'] and not data['owner']['input_desktop_switched']
    assert data['owner']['security_changes'] == 0 and data['owner']['excel_pid'] == 29860
    cases = data['observations']
    assert [case['zoom'] for case in cases] == [100, 150]
    assert cases[0]['observations'] == cases[1]['observations']
    expected = ['initial', 'invalid_save', 'name', 'team', 'product', 'shipping', 'payment',
                'review_page', 'valid_save', 'cancel']
    for case in cases:
        assert case['initial_focus'] == 'NameInput'
        assert [row['step'] for row in case['observations']] == expected
        assert case['observations'] == json.loads((directory / f'zoom-{case["zoom"]}-partial.json').read_text(encoding='utf-8'))
        assert all('CALCFORMS_NATIVE_ERROR:' not in row[field]
                   for row in case['observations'] for field in ('state', 'trace'))
        assert ';saved=0;status=Ready;visible=True' in case['observations'][0]['state']
        assert ';saved=0;status=Name is required;visible=True' in case['observations'][1]['state']
        assert ';saved=1;status=Saved Ada: Washer;visible=True' in case['observations'][-2]['state']
        assert case['observations'][-1]['state'].endswith('visible=False')
        assert case['observations'][-1]['trace'].endswith('Page.Change:1|Save.Click|Save.Valid|Cancel.Click')
    print('Real workbook: ten exact State/Trace steps at 100/150, native initial focus, original handlers and workbook bytes retained.')


if __name__ == '__main__':
    validate()
