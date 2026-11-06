"""Add observed programmatic behaviour and spacing to the measured corpus."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil

from behaviour_probes import parse
from build_drawing_reference import DIRECTORY as BASE
from forms_parity import replay, markdown
from layout_corpus import ROOT
from spacing_parity import measurements
from input_probes import pair as pair_input
from layout_corpus import load_corpus

DIRECTORY = BASE.parent / 'oxforms-jbjp.107'


def copy_text_capture(source, target):
    target.mkdir(exist_ok=True)
    for file in source.iterdir():
        if file.is_file() and file.name != 'files.json':
            # Source storage is UTF-8/LF. This changes no VBA text or native
            # observation, and makes exact file hashes survive Windows checkout.
            text = file.read_text(encoding='utf-8').replace('\r\n', '\n').replace('\r', '\n')
            (target / file.name).write_text(text, encoding='utf-8', newline='\n')
    manifest = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(target.iterdir())
                if p.is_file() and p.name != 'files.json'}
    (target / 'files.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8', newline='\n')


def augment(base, behaviour, input_data=None):
    rows = copy.deepcopy(base['observations'])
    cases = {(r['form'], r['zoom']): r for r in behaviour['observations']}
    if len(cases) != 6 or {z for _, z in cases} != {100, 150}:
        raise ValueError('Behaviour capture must contain all six authored cases')
    inputs = {(r['form'], r['zoom']): r for r in input_data['observations']} if input_data else {}
    if input_data and (len(inputs) != 6 or inputs.keys() != cases.keys()):
        raise ValueError('Input capture must contain all six authored cases')
    forms = {form['name']: form for form in load_corpus()['forms']}
    for row in rows:
        case = cases.get((row['form'], row['zoom']))
        if case:
            native, actual = parse(case['native']), parse(case['calcforms'])
            if native.keys() != actual.keys() or any(native[n].keys() != actual[n].keys() for n in native):
                raise ValueError('Native/runtime behaviour coverage differs')
            row['behaviour_measurements'] = {name: {metric: dict(native=facts, calcforms=actual[name][metric])
                for metric, facts in metrics.items()} for name, metrics in native.items()}
        input_case = inputs.get((row['form'], row['zoom']))
        if input_case:
            if input_case['native_facts'] != row['excel_facts']:
                raise ValueError('Native input geometry differs from the pinned image capture')
            if input_case['repeated_native_tab_cycle'] != input_case['native_parsed']['tab_cycle']:
                raise ValueError('Native traversal was not independently repeated')
            paired_input, input_detail = pair_input(forms[row['form']], input_case['native'], input_case['calcforms'])
            for name, facts in paired_input.items():
                row.setdefault('behaviour_measurements', {}).setdefault(name, {}).update(facts)
            row['input_measurement_details'] = input_detail
            origin = input_case['client_origin_px']
            row['native_accessible_rectangles_px'] = {
                point['control']: [point['native_accessible_rect_px'][0] - origin[0],
                                   point['native_accessible_rect_px'][1] - origin[1],
                                   *point['native_accessible_rect_px'][2:]] for point in input_case['points']}
        size = row['excel']['geometry']['client_size']
        spacing, detail = measurements(row, row['retained_scene'], size)
        for name, facts in spacing.items():
            row['parity_measurements'].setdefault(name, {}).update(facts)
        row['glyph_spacing_measurements'] = detail
        # Native drawings/Scene remain in the explicitly pinned base reference.
        for key in ('native_drawing', 'native_control_drawings', 'retained_scene', 'drawing_text_measurements', 'border_scan_lines'):
            row.pop(key, None)
    return rows


def build(source, input_source=None):
    source = source.resolve()
    if not source.is_relative_to(ROOT):
        raise ValueError('Behaviour source must stay in repo')
    DIRECTORY.mkdir(parents=True, exist_ok=True)
    baseline = BASE / 'comparison.json'
    base = json.loads(baseline.read_text(encoding='utf-8'))
    behaviour = json.loads((source / 'observations.json').read_text(encoding='utf-8'))
    input_data = json.loads((input_source / 'observations.json').read_text(encoding='utf-8')) if input_source else None
    rows = augment(base, behaviour, input_data)
    target = DIRECTORY / 'behaviour'
    copy_text_capture(source, target)
    if input_source:
        target = DIRECTORY / 'input'
        copy_text_capture(input_source, target)
    for row in rows:
        for artifact in row['images']:
            shutil.copyfile(BASE / artifact['file'], DIRECTORY / artifact['file'])
    reference = DIRECTORY / 'comparison.json'
    data = dict(schema='calcforms.layout_references.v1', owner=base['owner'],
                baseline_reference=baseline.relative_to(ROOT).as_posix(),
                baseline_sha256=hashlib.sha256(baseline.read_bytes()).hexdigest(), observations=rows)
    reference.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8', newline='\n')
    report = replay(reference)
    reference.with_name('forms-parity.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8', newline='\n')
    reference.with_name('forms-parity.md').write_text(markdown(report), encoding='utf-8', newline='\n')
    print(json.dumps({k: v for k, v in report['summary'].items() if k != 'measured_failures'}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--input-source', type=Path)
    args = parser.parse_args()
    build(args.source, args.input_source)
