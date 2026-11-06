"""Replay every field of the real inventory workbook, retaining product failures."""
import argparse
import hashlib
import json
from pathlib import Path

from layout_corpus import ROOT

DIRECTORY = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.119'
FIXTURE = ROOT / 'fixtures/workbooks/inventory'


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def compare(native, runtime):
    actual = {row['step']: row for row in runtime['observations']}
    items = []
    for case in native['observations']:
        for row in case['observations']:
            expected_state = dict(field.split('=', 1) for field in row['state'].split(';'))
            actual_state = dict(field.split('=', 1) for field in actual[row['step']]['state'].split(';'))
            assert expected_state.keys() == actual_state.keys()
            fields = [(name, value, actual_state[name]) for name, value in expected_state.items()]
            fields += [(name, row[name], actual[row['step']][name]) for name in ('trace', 'focus')]
            for field, expected, observed in fields:
                items.append(dict(zoom=case['zoom'], step=row['step'], field=field, native=expected,
                                  calcforms=observed, status='pass' if expected == observed else 'fail'))
    failed = [item for item in items if item['status'] == 'fail']
    return dict(schema='calcforms.inventory_differential.v1', full_parity_claimed=False,
                summary=dict(pass_count=len(items) - len(failed), fail_count=len(failed)), items=items)


def markdown(report):
    summary = report['summary']
    lines = ['# FORMS PARITY — inventory workbook', '',
             f"{summary['pass_count']} matching fields / {summary['fail_count']} failing fields; full parity is false.", '',
             'Every State field, original cumulative Trace and focus observation is compared at both native scales.',
             'The runtime is one headless logical replay; no window/pixel equivalence is claimed.', '',
             '| Zoom | Step | Field | Native | CalcForms |', '|---|---|---|---|---|']
    for item in report['items']:
        if item['status'] == 'fail':
            lines.append('| ' + ' | '.join(str(item[name]) for name in ('zoom', 'step', 'field', 'native', 'calcforms')) + ' |')
    lines += ['', 'All failures are retained for oxforms-jbjp.121 and oxforms-jbjp.123. No field is ignored or changed to pass.']
    return '\n'.join(lines) + '\n'


def validate(build=False, log=None):
    if log:
        line, = [line for line in log.read_text(encoding='utf-8').splitlines()
                 if line.startswith('CALCFORMS_INVENTORY_RUNTIME ')]
        runtime = json.loads(line.split(' ', 1)[1])
        runtime.update(schema='calcforms.inventory_runtime.v1', runtime='VM3 headless logical replay; StubShaper; original workbook handlers', library_base_reference='937f5ce')
        archive = DIRECTORY / 'viewport-sources'
        archive.mkdir(exist_ok=True)
        pins = {}
        for name in ('ListBox.cls', 'OxTheme.bas', 'OxInteractionManager.cls'):
            source = ROOT / 'vba/calcforms' / name
            (archive / name).write_bytes(source.read_bytes())
            pins[name] = digest(source)
        runtime['library_sources'] = pins
        (DIRECTORY / 'runtime.json').write_text(json.dumps(runtime, indent=2) + '\n', encoding='utf-8', newline='\n')
    original = read(DIRECTORY / 'observations.json')
    manifest = read(DIRECTORY / 'fixture-files.json')
    assert set(manifest) == {'inventory.xlsm', 'InventoryForm-qualified.frm', 'InventoryForm-qualified.frx', 'form-code.bas', 'entry.bas', 'authoring.json'}
    for name, expected in manifest.items():
        assert Path(name).name == name and digest(FIXTURE / name) == expected
    assert digest(FIXTURE / 'inventory.xlsm') == original['workbook_sha256']
    assert digest(FIXTURE / 'form-code.bas') == original['form_source_sha256']
    assert digest(FIXTURE / 'entry.bas') == original['entry_source_sha256']
    assert digest(DIRECTORY / 'observer.bas') == original['observer_sha256']
    native = read(DIRECTORY / 'native-focus/observations.json')
    assert digest(DIRECTORY / 'native-focus/observer.bas') == native['source_sha256']
    assert native['excel_pid'] == original['excel_pid'] and native['excel_launches'] == original['excel_launches'] == 1
    assert [case['zoom'] for case in native['observations']] == [100, 150]
    for before, after in zip(original['observations'], native['observations']):
        assert [{key: row[key] for key in ('step', 'state', 'trace')} for row in after['observations']] == before['observations']
        assert len(after['observations']) == 16 and after['initial_focus'] == 'QtyInput'
    modes = read(DIRECTORY / 'viewport-modes/observations.json')
    assert digest(DIRECTORY / 'viewport-modes/observer.bas') == modes['source_sha256']
    assert modes['excel_pid'] == original['excel_pid'] and modes['excel_launches'] == 1
    assert len(modes['observations']) == 16
    for relative in ('oxforms-jbjp.118', 'oxforms-jbjp.118/explicit-flags'):
        directory = DIRECTORY.parent / relative
        observation = read(directory / 'observations.json')
        assert digest(directory / 'observer.bas') == observation['source_sha256']
        assert observation['excel_pid'] == original['excel_pid'] and observation['excel_launches'] == 1
    runtime = read(DIRECTORY / 'runtime.json')
    if 'library_sources' in runtime:
        for name, expected in runtime['library_sources'].items():
            assert digest(DIRECTORY / 'viewport-sources' / name) == expected
    before = compare(native, read(DIRECTORY / 'before/runtime.json'))
    assert before['summary'] == dict(pass_count=300, fail_count=20)
    assert before == read(DIRECTORY / 'before/comparison.json')
    report = compare(native, runtime)
    assert report['summary'] == dict(pass_count=316, fail_count=4)
    assert all((item['field'], item['native'], item['calcforms']) in {('focus', 'CancelButton', 'SubmitButton')}
               for item in report['items'] if item['status'] == 'fail')
    path = DIRECTORY / 'comparison.json'
    if build:
        path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8', newline='\n')
        path.with_suffix('.md').write_text(markdown(report), encoding='utf-8', newline='\n')
    else:
        assert report == read(path)
        assert markdown(report) == path.with_suffix('.md').read_text(encoding='utf-8')
    print('Inventory: 316 fields match; 4 cancel-focus failures retained; original handlers and both native scales verified.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', action='store_true')
    parser.add_argument('--log', type=Path)
    args = parser.parse_args()
    validate(args.build, args.log)
