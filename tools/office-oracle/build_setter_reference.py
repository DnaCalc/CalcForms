"""Pair fresh VM3 transcripts with the already pinned independent native corpus."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil

from behaviour_probes import parse as parse_behaviour
from build_behaviour_reference import copy_text_capture
from build_keyboard_reference import DIRECTORY as BASE
from forms_parity import markdown, replay
from input_probes import pair as pair_input
from keyboard_probes import parse as parse_keyboard
from layout_corpus import ROOT, load_corpus

DIRECTORY = BASE.parent / 'oxforms-jbjp.111'
SOURCE_NAMES = ('CheckBox', 'ToggleButton', 'OptionButtonControl', 'ComboBox', 'TabStrip', 'MultiPage', 'SpinButton', 'ScrollBar')


def augment(base, runtime):
    rows = copy.deepcopy(base['observations'])
    cases = {suite: {(c['form'], c['zoom']): c for c in data['observations']} for suite, data in runtime.items()}
    forms = {f['name']: f for f in load_corpus()['forms']}
    native_input = json.loads((BASE.parent / 'oxforms-jbjp.107/input/observations.json').read_text(encoding='utf-8'))
    inputs = {(c['form'], c['zoom']): c for c in native_input['observations']}
    for row in rows:
        identity = row['form'], row['zoom']
        if row['form'] == 'greeter':
            continue
        for suite, parser in [('behaviour', parse_behaviour), ('keyboard', parse_keyboard)]:
            observed = parser(cases[suite][identity]['calcforms'])
            for name, metrics in observed.items():
                for metric, values in metrics.items():
                    row['behaviour_measurements'][name][metric]['calcforms'] = values
        paired, detail = pair_input(forms[row['form']], inputs[identity]['native'], cases['input'][identity]['calcforms'])
        for name, metrics in paired.items():
            for metric, facts in metrics.items():
                assert row['behaviour_measurements'][name][metric]['native'] == facts['native']
                row['behaviour_measurements'][name][metric]['calcforms'] = facts['calcforms']
        row['input_measurement_details'] = detail
        row['behaviour_runtime_sha256'] = runtime['behaviour']['runtime_sha256']
    return rows


def build(source):
    source = source.resolve()
    if not source.is_relative_to(ROOT):
        raise ValueError('Runtime source must stay in repo')
    DIRECTORY.mkdir(parents=True, exist_ok=True)
    reference = BASE / 'comparison.json'
    base = json.loads(reference.read_text(encoding='utf-8'))
    runtime = {suite: json.loads((source / (suite + '.json')).read_text(encoding='utf-8'))
               for suite in ('behaviour', 'input', 'keyboard')}
    if len({data['runtime_sha256'] for data in runtime.values()}) != 1:
        raise ValueError('Runtime suites must use the same binary')
    for data in runtime.values():
        original = ROOT / data['source_reference']
        if hashlib.sha256(original.read_bytes()).hexdigest() != data['source_sha256']:
            raise ValueError('Original independent scenario source changed')
    rows = augment(base, runtime)
    copy_text_capture(source, DIRECTORY / 'runtime')
    for row in rows:
        for artifact in row['images']:
            shutil.copyfile(BASE / artifact['file'], DIRECTORY / artifact['file'])
    production = {f'vba/calcforms/{name}.cls': hashlib.sha256((ROOT / f'vba/calcforms/{name}.cls').read_bytes()).hexdigest()
                  for name in SOURCE_NAMES}
    path = DIRECTORY / 'comparison.json'
    path.write_text(json.dumps(dict(schema='calcforms.layout_references.v1', owner=base['owner'],
        baseline_reference=reference.relative_to(ROOT).as_posix(), baseline_sha256=hashlib.sha256(reference.read_bytes()).hexdigest(),
        production_sources=production, observations=rows), indent=2) + '\n', encoding='utf-8', newline='\n')
    report = replay(path)
    path.with_name('forms-parity.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8', newline='\n')
    path.with_name('forms-parity.md').write_text(markdown(report), encoding='utf-8', newline='\n')
    print(json.dumps({k: v for k, v in report['summary'].items() if k != 'measured_failures'}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    build(parser.parse_args().source)
