"""Replay actual key notifications and unsupported TopIndex without Office."""
import hashlib
import json

from build_keyboard_reference import BASE, DIRECTORY, augment
from forms_parity import markdown, replay
from keyboard_probes import parse, runtime_source, shared_source
from layout_corpus import ROOT, load_corpus, runtime_source as authored_source
from validate_behaviour_reference import files


def validate():
    path = DIRECTORY / 'comparison.json'
    reference = BASE / 'comparison.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    assert data['baseline_reference'] == reference.relative_to(ROOT).as_posix()
    assert data['baseline_sha256'] == hashlib.sha256(reference.read_bytes()).hexdigest()
    base = json.loads(reference.read_text(encoding='utf-8'))
    directory = DIRECTORY / 'keyboard'
    files(directory)
    capture = json.loads((directory / 'observations.json').read_text(encoding='utf-8'))
    assert capture['owner']['interactive'] is False and capture['owner']['security_changes'] == 0
    assert capture['owner']['excel_pid'] == 29860 and capture['owner']['input_desktop_switched'] is False
    corpus = load_corpus()
    forms = {form['name']: form for form in corpus['forms']}
    inputs = json.loads((BASE / 'input/observations.json').read_text(encoding='utf-8'))
    cases = {(c['form'], c['zoom']): c for c in inputs['observations']}
    for case in capture['observations']:
        form = forms[case['form']]
        assert case['native_parsed'] == parse(case['native'])
        assert case['calcforms_parsed'] == parse(case['calcforms'])
        assert all(v['native_visible'] for v in case['native_visibility'])
        assert (directory / (form['name'] + '-native.bas')).read_text(encoding='utf-8') == shared_source(form)
        assert (directory / f'{form["name"]}-{case["zoom"]}-runtime.cls').read_text(encoding='utf-8') == runtime_source(
            authored_source(form, corpus), form, cases[form['name'], case['zoom']]['points'])
        if form['name'] == 'LayoutSelection':
            native = case['native_parsed']['Choices']['scrolling']
            assert [r['value'] for r in native] == ['index=1;count=23;top=0', 'index=7;count=23;top=1',
                                                   'index=13;count=23;top=7', 'index=0;count=23;top=0']
    assert augment(base, capture) == data['observations']
    report = replay(path)
    assert report == json.loads(path.with_name('forms-parity.json').read_text(encoding='utf-8'))
    assert markdown(report) == path.with_name('forms-parity.md').read_text(encoding='utf-8')
    assert report['summary']['missing_measurements'] == 428
    assert report['summary']['measured_failures'] and report['full_parity_claimed'] is False
    print('Keyboard: scoped Enter/Escape notifications and genuine 23-row PageDown/Home scrolling replayed; native 0/1/7/0 TopIndex and runtime errors stay explicit.')


if __name__ == '__main__':
    validate()
