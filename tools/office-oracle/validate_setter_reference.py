"""Replay the corrected runtime against unchanged independent native evidence."""
import hashlib
import json

from build_setter_reference import BASE, DIRECTORY, SOURCE_NAMES, augment
from forms_parity import markdown, replay
from layout_corpus import ROOT
from validate_behaviour_reference import files


def validate():
    path = DIRECTORY / 'comparison.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    baseline = BASE / 'comparison.json'
    assert data['baseline_reference'] == baseline.relative_to(ROOT).as_posix()
    assert data['baseline_sha256'] == hashlib.sha256(baseline.read_bytes()).hexdigest()
    assert set(data['production_sources']) == {f'vba/calcforms/{name}.cls' for name in SOURCE_NAMES}
    for name, digest in data['production_sources'].items():
        # This is a historical runtime capture. Verify the exact source bytes
        # archived from 25f9ff3 against the original immutable capture pins.
        # Current production behavior is separately asserted by measured_behaviour.rs.
        assert hashlib.sha256((DIRECTORY / 'sources' / name.rsplit('/', 1)[-1]).read_bytes()).hexdigest() == digest
    directory = DIRECTORY / 'runtime'
    files(directory)
    runtime = {suite: json.loads((directory / (suite + '.json')).read_text(encoding='utf-8'))
               for suite in ('behaviour', 'input', 'keyboard')}
    assert len({capture['runtime_sha256'] for capture in runtime.values()}) == 1
    for capture in runtime.values():
        assert hashlib.sha256((ROOT / capture['source_reference']).read_bytes()).hexdigest() == capture['source_sha256']
        assert {(case['form'], case['zoom']) for case in capture['observations']} == {
            (form, zoom) for form in ('LayoutCommon', 'LayoutSelection', 'LayoutContainers') for zoom in (100, 150)}
    base = json.loads(baseline.read_text(encoding='utf-8'))
    assert augment(base, runtime) == data['observations']
    report = replay(path)
    assert report == json.loads(path.with_name('forms-parity.json').read_text(encoding='utf-8'))
    assert markdown(report) == path.with_name('forms-parity.md').read_text(encoding='utf-8')
    before = replay(baseline)
    assert report['summary']['missing_measurements'] == before['summary']['missing_measurements'] == 428
    assert report['summary']['pass_count'] - before['summary']['pass_count'] == 34
    assert report['summary']['fail_count'] == 521 and not report['full_parity_claimed']
    cleanup = json.loads((DIRECTORY / 'cleanup.json').read_text(encoding='utf-8'))
    assert cleanup['excel_launches'] == 2 and cleanup['sequential']
    assert set(cleanup['processes_still_running']) == {'27884', '29860', '31644'}
    assert not any(cleanup['processes_still_running'].values())
    assert cleanup['security_changes'] == 0 and not cleanup['owner_input_or_focus_used']
    assert cleanup['server_exit_errors']
    assert all(owner['closed'] == 'terminated_owned_handle' and owner['workbook_unchanged']
               for owner in cleanup['owners'])
    print('Setter/Enter: 34 independent native failures corrected; 428 unknown rows and measured scroll failures retained.')


if __name__ == '__main__':
    validate()
