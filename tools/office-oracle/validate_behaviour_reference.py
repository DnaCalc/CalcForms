"""Replay independent native/VM3 behaviour and native accessibility geometry."""
import hashlib
import json

from behaviour_probes import instrument_runtime, parse, probe_source
from build_behaviour_reference import BASE, DIRECTORY, augment
from forms_parity import markdown, replay
from input_probes import native_source, parse as parse_input, runtime_source as input_source
from layout_corpus import ROOT, load_corpus, runtime_source


def files(directory):
    manifest = json.loads((directory / 'files.json').read_text(encoding='utf-8'))
    actual = {p.name for p in directory.iterdir() if p.is_file() and p.name != 'files.json'}
    assert set(manifest) == actual
    for name, digest in manifest.items():
        assert '/' not in name and '\\' not in name
        assert hashlib.sha256((directory / name).read_bytes()).hexdigest() == digest


def validate():
    path = DIRECTORY / 'comparison.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    baseline = BASE / 'comparison.json'
    assert data['baseline_reference'] == baseline.relative_to(ROOT).as_posix()
    assert data['baseline_sha256'] == hashlib.sha256(baseline.read_bytes()).hexdigest()
    base = json.loads(baseline.read_text(encoding='utf-8'))
    corpus = load_corpus()
    forms = {form['name']: form for form in corpus['forms']}
    behaviour_dir, input_dir = DIRECTORY / 'behaviour', DIRECTORY / 'input'
    for directory in (behaviour_dir, input_dir):
        files(directory)
    behaviour = json.loads((behaviour_dir / 'observations.json').read_text(encoding='utf-8'))
    inputs = json.loads((input_dir / 'observations.json').read_text(encoding='utf-8'))
    for capture in (behaviour, inputs):
        assert capture['owner']['interactive'] is False and capture['owner']['excel_launches'] == 1
        assert capture['owner']['security_changes'] == 0 and capture['owner']['input_desktop_switched'] is False
    for case in behaviour['observations']:
        assert case['native_parsed'] == parse(case['native'])
        assert case['calcforms_parsed'] == parse(case['calcforms'])
        form = forms[case['form']]
        assert (behaviour_dir / (form['name'] + '-native.bas')).read_text(encoding='utf-8').strip().endswith(probe_source(form).strip())
        assert (behaviour_dir / (form['name'] + '-runtime.cls')).read_text(encoding='utf-8') == instrument_runtime(runtime_source(form, corpus), form)
    for case in inputs['observations']:
        assert case['native_parsed'] == parse_input(case['native'])
        assert case['calcforms_parsed'] == parse_input(case['calcforms'])
        assert case['repeated_native_tab_cycle'] == case['native_parsed']['tab_cycle']
        form = forms[case['form']]
        assert (input_dir / (form['name'] + '-native.bas')).read_text(encoding='utf-8') == native_source(form)
        assert (input_dir / f'{form["name"]}-{case["zoom"]}-runtime.cls').read_text(encoding='utf-8') == input_source(runtime_source(form, corpus), form, case['points'])
        assert len(case['points']) == len(case['native_parsed']['hits'])
        for point in case['points']:
            x, y, w, h = point['native_accessible_rect_px']
            px, py = point['screen_point_px']
            assert w > 0 and h > 0 and x <= px < x + w and y <= py < y + h
    assert augment(base, behaviour, inputs) == data['observations']
    report = replay(path)
    assert report == json.loads(path.with_name('forms-parity.json').read_text(encoding='utf-8'))
    assert markdown(report) == path.with_name('forms-parity.md').read_text(encoding='utf-8')
    assert report['summary']['missing_measurements'] == 522
    assert report['summary']['measured_failures'] and report['full_parity_claimed'] is False
    print('Behaviour: literal phases/events, complete repeated native Tab cycles, interior messages, public accessible rectangles and Scene comparisons replayed; missing coverage remains failed.')


if __name__ == '__main__':
    validate()
