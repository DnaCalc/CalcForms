"""Fill exactly forty formerly missing greeter input rows from independent observations."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil

from capture_greeter_input import DIRECTORY, INSTRUMENTATION, ENTRY, FORM
from forms_parity import markdown, replay
from input_probes import validate_native_signatures
from layout_corpus import ROOT
from workbook_comparison_session import WORKBOOK

BASE = DIRECTORY.parent / 'oxforms-jbjp.112/comparison.json'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def write(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8', newline='\n')


def augment(base, native, runtime):
    rows = copy.deepcopy(base['observations'])
    expected = {case['zoom']: case for case in native['observations']}
    actual = {case['zoom']: case for case in runtime['observations']}
    assert expected.keys() == actual.keys() == {100, 150}
    for row in rows:
        if row['form'] != 'greeter':
            continue
        n, a = expected[row['zoom']], actual[row['zoom']]
        paired = {}
        assert n['tab_cycle'] == n['repeated_tab_cycle'] and a['tab_cycle'] == a['repeated_tab_cycle']
        npoints = {point['control']: point for point in n['points']}
        apoints = {point['control']: point for point in a['points']}
        assert npoints.keys() == apoints.keys() == {control['name'] for control in FORM['controls']}
        for name in npoints:
            def visits(case):
                cycle = case['tab_cycle']
                assert cycle[0] == cycle[-1] and len(cycle) > 1 and '' not in cycle
                return [dict(position=i, next=cycle[i + 1]) for i, value in enumerate(cycle[:-1]) if value == name]

            def targets(point):
                events = [event for event in point['trace'].split('|') if event]
                assert events and all(event.endswith('.MouseDown') for event in events)
                return [event.rsplit('.', 1)[0] for event in events]

            metrics = dict(tab_order=dict(native=visits(n), calcforms=visits(a)),
                           hit_testing=dict(native=targets(npoints[name]), calcforms=targets(apoints[name])))
            for metric, step in [('enter_default', 'enter'), ('escape_cancel', 'escape')]:
                metrics[metric] = dict(native=[dict(step=step, events=npoints[name]['keys'][metric]['events'])],
                                       calcforms=[dict(step=step, events=apoints[name]['keys'][metric]['events'])])
            for metric in metrics:
                previous = row.get('behaviour_measurements', {}).get(name, {}).get(metric, {})
                assert previous.get('native') is None and previous.get('calcforms') is None
            paired[name] = metrics
        row.setdefault('behaviour_measurements', {}).update(paired)
        row['greeter_input_reference'] = dict(native='native.json', runtime='runtime.json')
    return rows


def validate(build=False, log=None):
    native = read(DIRECTORY / 'native.json')
    if log:
        line, = [line for line in log.read_text(encoding='utf-8').splitlines() if line.startswith('CALCFORMS_GREETER_INPUT_RUNTIME ')]
        runtime = json.loads(line.split(' ', 1)[1])
        runtime.update(schema='calcforms.greeter_input_runtime.v1', library_reference='937f5ce', input='normalized reducer events; original workbook handlers with separate MouseDown observers')
        write(DIRECTORY / 'runtime.json', runtime)
    runtime = read(DIRECTORY / 'runtime.json')
    assert digest(WORKBOOK) == native['workbook_sha256']
    assert native['original_handlers_unchanged'] and native['workbook_unchanged']
    assert digest(DIRECTORY / 'instrumentation.bas') == native['instrumentation_sha256']
    assert digest(DIRECTORY / 'observer.bas') == native['observer_sha256']
    assert (DIRECTORY / 'instrumentation.bas').read_text(encoding='utf-8') == INSTRUMENTATION
    assert (DIRECTORY / 'observer.bas').read_text(encoding='utf-8') == ENTRY
    validate_native_signatures(FORM, INSTRUMENTATION)
    assert native['owner']['excel_launches'] == 1 and not native['owner']['interactive']
    assert not native['owner']['input_desktop_switched'] and native['owner']['security_changes'] == 0
    for case in native['observations']:
        assert case['initial_focus'] == 'InputName'
        for point in case['points']:
            x, y, w, h = point['native_accessible_rect_px']
            px, py = point['screen_point_px']
            assert w > 0 and h > 0 and x <= px < x + w and y <= py < y + h
            for facts in point['keys'].values():
                before, after = facts['before'].split(';text=', 1)[0], facts['after'].split(';text=', 1)[0]
                assert after.startswith(before)
                assert [event for event in after.removeprefix(before).split('|') if event] == facts['events']
    base = read(BASE)
    rows = augment(base, native, runtime)
    path = DIRECTORY / 'comparison.json'
    if build:
        for row in base['observations']:
            for artifact in row['images']:
                shutil.copyfile(BASE.parent / artifact['file'], DIRECTORY / artifact['file'])
        write(path, dict(schema=base['schema'], owner=base['owner'], baseline_reference=BASE.relative_to(ROOT).as_posix(),
                         baseline_sha256=digest(BASE), greeter_input_owner=native['owner'], observations=rows))
    data = read(path)
    assert data['baseline_reference'] == BASE.relative_to(ROOT).as_posix() and data['baseline_sha256'] == digest(BASE)
    assert data['observations'] == rows and data['greeter_input_owner'] == native['owner']
    report = replay(path)
    assert report['summary']['pass_count'] == 1166 and report['summary']['fail_count'] == 452
    assert report['summary']['missing_measurements'] == 378 and not report['full_parity_claimed']
    if build:
        write(path.with_name('forms-parity.json'), report)
        path.with_name('forms-parity.md').write_text(markdown(report), encoding='utf-8', newline='\n')
    else:
        assert report == read(path.with_name('forms-parity.json'))
        assert markdown(report) == path.with_name('forms-parity.md').read_text(encoding='utf-8')
    print('FORMS PARITY: 1166 pass / 452 fail; 378 missing. Forty independent greeter input rows filled.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', action='store_true')
    parser.add_argument('--log', type=Path)
    args = parser.parse_args()
    validate(args.build, args.log)
