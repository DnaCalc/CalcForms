"""Add paired posted-key and real overflow observations to the pinned corpus."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil

from build_behaviour_reference import DIRECTORY as BASE, copy_text_capture
from forms_parity import markdown, replay
from keyboard_probes import parse
from layout_corpus import ROOT

DIRECTORY = BASE.parent / 'oxforms-jbjp.109'


def augment(base, keyboard):
    rows = copy.deepcopy(base['observations'])
    cases = {(c['form'], c['zoom']): c for c in keyboard['observations']}
    if len(cases) != 6:
        raise ValueError('Keyboard capture must contain all six authored cases')
    for row in rows:
        case = cases.get((row['form'], row['zoom']))
        if not case:
            if row['form'] != 'greeter':
                raise ValueError('Missing authored keyboard case')
            continue
        if case['native_facts'] != row['excel_facts']:
            raise ValueError('Native keyboard geometry changed')
        native, actual = parse(case['native']), parse(case['calcforms'])
        if native.keys() != actual.keys() or any(native[n].keys() != actual[n].keys() for n in native):
            raise ValueError('Keyboard observation coverage differs')
        for name, metrics in native.items():
            row.setdefault('behaviour_measurements', {}).setdefault(name, {}).update({
                metric: dict(native=value, calcforms=actual[name][metric]) for metric, value in metrics.items()})
    return rows


def build(source):
    source = source.resolve()
    if not source.is_relative_to(ROOT):
        raise ValueError('Keyboard source must stay in repo')
    DIRECTORY.mkdir(parents=True, exist_ok=True)
    reference = BASE / 'comparison.json'
    base = json.loads(reference.read_text(encoding='utf-8'))
    capture = json.loads((source / 'observations.json').read_text(encoding='utf-8'))
    rows = augment(base, capture)
    copy_text_capture(source, DIRECTORY / 'keyboard')
    for row in rows:
        for artifact in row['images']:
            shutil.copyfile(BASE / artifact['file'], DIRECTORY / artifact['file'])
    path = DIRECTORY / 'comparison.json'
    path.write_text(json.dumps(dict(schema='calcforms.layout_references.v1', owner=base['owner'],
        baseline_reference=reference.relative_to(ROOT).as_posix(), baseline_sha256=hashlib.sha256(reference.read_bytes()).hexdigest(),
        observations=rows), indent=2) + '\n', encoding='utf-8', newline='\n')
    report = replay(path)
    path.with_name('forms-parity.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8', newline='\n')
    path.with_name('forms-parity.md').write_text(markdown(report), encoding='utf-8', newline='\n')
    print(json.dumps({k: v for k, v in report['summary'].items() if k != 'measured_failures'}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    build(parser.parse_args().source)
