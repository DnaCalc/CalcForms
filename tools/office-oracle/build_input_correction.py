"""Pair fresh keyboard transcripts with the retained independent native report."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

from build_setter_reference import augment
from build_behaviour_reference import copy_text_capture
from forms_parity import markdown, replay
from layout_corpus import ROOT
from validate_behaviour_reference import files
from input_probes import upgrade_runtime_tab_signatures

DIRECTORY = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.112'
BASE = DIRECTORY.parent / 'oxforms-jbjp.114/final/comparison.json'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8', newline='\n')


def build(source):
    source = source.resolve()
    if not source.is_relative_to(ROOT) or (DIRECTORY / 'comparison.json').exists():
        raise ValueError('Requires a fresh repository capture')
    base = json.loads(BASE.read_text(encoding='utf-8'))
    runtime = {suite: json.loads((source / (suite + '.json')).read_text(encoding='utf-8'))
               for suite in ('behaviour', 'input', 'keyboard')}
    copy_text_capture(source, DIRECTORY / 'runtime')
    for row in base['observations']:
        for artifact in row['images']:
            shutil.copyfile(BASE.parent / artifact['file'], DIRECTORY / artifact['file'])
    names = ['ListBox.cls', 'Controls.cls', 'OxTheme.bas', 'OxInteractionManager.cls', 'runtime/WorkbookFormLifetime.vba', 'OxFrmMaterializer.cls', 'TabStrip.cls', 'MultiPage.cls', 'Page.cls']
    archive = DIRECTORY / 'sources'
    production = {}
    for name in names:
        path = ROOT / 'vba/calcforms' / name
        target = archive / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
        production[name] = digest(path)
    data = dict(schema=base['schema'], owner=base['owner'], baseline_reference=BASE.relative_to(ROOT).as_posix(),
                baseline_sha256=digest(BASE), production_sources=production, observations=augment(base, runtime))
    path = DIRECTORY / 'comparison.json'
    write(path, data)
    report = replay(path)
    write(path.with_name('forms-parity.json'), report)
    path.with_name('forms-parity.md').write_text(markdown(report), encoding='utf-8', newline='\n')
    validate()


def validate():
    path = DIRECTORY / 'comparison.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    assert data['baseline_reference'] == BASE.relative_to(ROOT).as_posix() and data['baseline_sha256'] == digest(BASE)
    base = json.loads(BASE.read_text(encoding='utf-8'))
    files(DIRECTORY / 'runtime')
    runtime = {suite: json.loads((DIRECTORY / 'runtime' / (suite + '.json')).read_text(encoding='utf-8'))
               for suite in ('behaviour', 'input', 'keyboard')}
    assert len({capture['runtime_sha256'] for capture in runtime.values()}) == 1
    for capture in runtime.values():
        assert digest(ROOT / capture['source_reference']) == capture['source_sha256']
        for case in capture['observations']:
            if 'current_source' in case:
                current = DIRECTORY / 'runtime' / case['current_source']
                assert digest(current) == case['current_source_sha256']
                original = (ROOT / case['original_source']).read_text(encoding='utf-8')
                assert upgrade_runtime_tab_signatures(original) == current.read_text(encoding='utf-8')
    for name, expected in data['production_sources'].items():
        assert digest(DIRECTORY / 'sources' / name) == expected
    assert augment(base, runtime) == data['observations']
    report = replay(path)
    assert report == json.loads(path.with_name('forms-parity.json').read_text(encoding='utf-8'))
    assert markdown(report) == path.with_name('forms-parity.md').read_text(encoding='utf-8')
    assert report['summary']['pass_count'] == 1126 and report['summary']['fail_count'] == 492
    assert report['summary']['missing_measurements'] == 418 and not report['full_parity_claimed']
    native = DIRECTORY / 'native'
    observations = json.loads((native / 'observations.json').read_text(encoding='utf-8'))
    assert digest(native / 'observer.bas') == observations['source_sha256']
    assert observations['excel_launches'] == 1 and len(observations['observations']) == 2
    assert all(len(case['observations']) == 27 for case in observations['observations'])
    focus = DIRECTORY.parent / 'oxforms-jbjp.105.1/show-focus'
    observed = json.loads((focus / 'observations.json').read_text(encoding='utf-8'))
    assert digest(focus / 'observer.bas') == observed['source_sha256']
    assert observed['observed'].startswith('initial=NameInput\n') and observed['observed'].endswith('reshow=TeamChoice')
    assert observed['excel_pid'] == observations['excel_pid'] and observed['excel_launches'] == 1
    focus150 = focus.with_name('show-focus-150')
    observed150 = json.loads((focus150 / 'observations.json').read_text(encoding='utf-8'))
    assert digest(focus150 / 'observer.bas') == observed150['source_sha256']
    assert observed150['observed'] == observed['observed']
    index = DIRECTORY.parent / 'oxforms-jbjp.108/native-index'
    captured = json.loads((index / 'observations.json').read_text(encoding='utf-8'))
    assert digest(index / 'form.bas') == captured['source_sha256']
    assert digest(index / 'observer.bas') == captured['observer_sha256']
    assert captured['excel_pid'] == observed['excel_pid'] and captured['excel_launches'] == 1
    assert len(captured['observations']) == 12
    first = [row for row in captured['observations'] if row['zoom'] == 100]
    second = [row for row in captured['observations'] if row['zoom'] == 150]
    assert [row['trace'] for row in first] == [row['trace'] for row in second]
    assert all(row['trace'].count('MouseDown:index=') == 1 and row['trace'].count('MouseUp:index=') == 1 for row in captured['observations'])
    facts = json.loads((DIRECTORY.parent / 'oxforms-jbjp.2/fm20_typelib_facts.v1.json').read_text(encoding='utf-8'))
    types = {item['documentation']['name']: item for item in facts['libraries'][0]['types']}
    for name in ('TabStrip', 'MultiPage'):
        source = (DIRECTORY / 'sources' / (name + '.cls')).read_text(encoding='utf-8')
        for event_name in ('MouseDown', 'MouseUp'):
            event, = [item for item in types[name + 'Events']['functions'] if item['documentation']['name'] == event_name]
            arguments = ', '.join('ByVal ' + item['name'] + ' As ' + item['type']['display'] for item in event['parameters'])
            assert 'Public Event ' + event_name + '(' + arguments + ')' in source
    print('FORMS PARITY:', report['summary']['pass_count'], 'pass /', report['summary']['fail_count'], 'fail; 418 missing. Native viewport, Show focus and indexed tab events retained.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    validate() if args.check else build(args.source)
