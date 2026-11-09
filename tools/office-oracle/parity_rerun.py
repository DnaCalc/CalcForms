"""Re-run the FORMS PARITY runtime scenarios against the current build and write a fresh report.

The native facts and the retained window captures are unchanged; only the CalcForms behaviour, input and
keyboard scenario transcripts are executed again (run_runtime_measurements.py, no Office), merged into the
earlier measured baseline (`.129/final/comparison.json`) and replayed. The report is written next to the
runtime transcripts together with a row-level comparison against the previous report (`.130`).

    cargo build --example layout_probe -p calcforms-bootstrap
    python run_runtime_measurements.py --out <repo-local fresh dir>/runtime-raw [--zoom]
    python parity_rerun.py --measurements <that dir> --out <fresh dir>
"""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

from build_behaviour_reference import copy_text_capture
from build_setter_reference import augment
from forms_parity import markdown, replay
from frame_mouse_reference import BASE, items, read, write
from layout_corpus import ROOT

PREVIOUS = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.130/forms-parity.json'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build(measurements, out):
    out = out.resolve()
    if not out.is_relative_to(ROOT) or out.exists():
        raise ValueError('Use a fresh repo-local output directory')
    out.mkdir(parents=True)
    copy_text_capture(measurements, out / 'runtime')
    base = read(BASE)
    runtime = {suite: read(out / 'runtime' / (suite + '.json')) for suite in ('behaviour', 'input', 'keyboard')}
    if len({capture['runtime_sha256'] for capture in runtime.values()}) != 1:
        raise ValueError('Fresh runtime suites used different binaries')
    rows = augment(base, runtime)
    for row in rows:
        for artifact in row['images']:
            shutil.copyfile(BASE.parent / artifact['file'], out / artifact['file'])
    reference = out / 'comparison.json'
    write(reference, dict(schema=base['schema'], owner=base['owner'], baseline_reference=BASE.relative_to(ROOT).as_posix(),
                          baseline_sha256=digest(BASE), observations=rows))
    result = replay(reference)
    write(reference.with_name('forms-parity.json'), result)
    reference.with_name('forms-parity.md').write_text(markdown(result), encoding='utf-8', newline='\n')
    summary = result['summary']
    counts = tuple(summary[key] for key in ('pass_count', 'fail_count', 'missing_measurements'))
    before, after = items(read(PREVIOUS)), items(result)
    gains = sorted(key for key in before if before[key]['status'] == 'fail' and after[key]['status'] == 'pass')
    losses = sorted(key for key in before if before[key]['status'] == 'pass' and after[key]['status'] == 'fail')
    changed_native = [key for key in before if before[key]['native'] != after[key]['native']]
    comparison = dict(previous=PREVIOUS.relative_to(ROOT).as_posix(), pass_fail_missing=counts,
                      gains=[list(key) for key in gains], regressions=[list(key) for key in losses],
                      rows_with_changed_native_fact=[list(key) for key in changed_native],
                      runtime_sha256=next(iter(runtime.values()))['runtime_sha256'])
    write(out / 'versus-previous.json', comparison)
    print('FORMS PARITY: %d pass / %d fail; %d missing' % counts)
    print('gains', len(gains), 'regressions', len(losses), 'changed native facts', len(changed_native))
    for key in gains:
        print('  gain', key)
    for key in losses:
        print('  regression', key)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--measurements', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    arguments = parser.parse_args()
    build(arguments.measurements.resolve(), arguments.out)
