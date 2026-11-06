"""Replay provenance and native release observations without starting Excel."""
import hashlib
import json

from capture_lifetime_release import SOURCE
from layout_corpus import ROOT
from workbook_comparison_session import WORKBOOK


def validate():
    directory = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.95/native-release'
    data = json.loads((directory / 'observations.json').read_text(encoding='utf-8'))
    assert data['schema'] == 'calcforms.native_release.v1'
    assert data['source_sha256'] == hashlib.sha256(SOURCE.encode()).hexdigest()
    assert (directory / 'observer.bas').read_text(encoding='utf-8') == SOURCE
    assert data['workbook_sha256'] == hashlib.sha256(WORKBOOK.read_bytes()).hexdigest()
    owner = data['owner']
    assert owner['excel_launches'] == owner['excel_launches_by_this_session'] == 1
    assert not owner['interactive'] and not owner['input_desktop_switched']
    assert owner['security_changes'] == 0
    rows = data['result'].splitlines()
    assert len(rows) == 14 and rows[4] == 'same-default=True'
    assert rows[0] == 'explicit-new;initialize=1;terminate=0'
    assert rows[1] == 'explicit-unload;initialize=1;terminate=1'
    assert rows[5] == 'default-unload-held;initialize=2;terminate=2'
    assert rows[9] == 'control-unload;initialize=3;terminate=3'
    assert rows[10:12] == ['old-control-text=retained-control;error=0', 'old-control-write-error=0']
    assert rows[-1] == 'last-control-release;initialize=3;terminate=3'
    print('Native Unload/Terminate and retained control observations verified; VM3 differential is workbook_userform.rs.')


if __name__ == '__main__':
    validate()
