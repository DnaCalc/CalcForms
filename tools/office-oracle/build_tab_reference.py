"""Add independently qualified tab drawing sizes to the run-7 report."""
import copy
import hashlib
import json
import shutil

from PIL import Image

from forms_parity import markdown, replay
from layout_corpus import ROOT
from tab_paint import native_headers, runtime_headers, sizes, window_probes

DIRECTORY = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.110'
BASE = DIRECTORY.parent / 'oxforms-jbjp.111'
DRAWING = DIRECTORY.parent / 'oxforms-jbjp.106'


def augment(base, drawing):
    rows = copy.deepcopy(base['observations'])
    drawings = {(row['form'], row['zoom']): row for row in drawing['observations']}
    for row in rows:
        if row['form'] != 'LayoutContainers':
            continue
        source = drawings[row['form'], row['zoom']]
        if row['images'] != source['images'] or row['native_capture_validation']['verified'] is not True:
            raise ValueError('Header drawing needs the same qualified native window')
        image = Image.open(BASE / row['images'][0]['file']).convert('RGB')
        scene = source['retained_scene']
        scale = min(image.width / scene['surface']['width'], image.height / scene['surface']['height'])
        details = {}
        for name in ('TabsControl', 'PagesControl'):
            control = next(c for c in source['measurements']['controls'] if c['name'] == name)
            capture = source['native_control_drawings'][name]
            raw = (DRAWING / capture['file']).read_bytes()
            if hashlib.sha256(raw).hexdigest() != capture['sha256']:
                raise ValueError('Raw native drawing hash differs')
            captions = ['First', 'Second']
            native = native_headers(raw, capture['font_metrics'], captions)
            origin = row['native_accessible_rectangles_px'][name][:2]
            probes = window_probes(image, origin, native)
            actual = runtime_headers(scene, control['calcforms']['node_id'], captions, scale)
            row['parity_measurements'].setdefault(name, {})['tab_sizes'] = dict(native=sizes(native), calcforms=sizes(actual))
            details[name] = dict(native=native, calcforms=actual, window_probes=probes,
                native_emf_file=capture['file'], native_emf_sha256=capture['sha256'],
                method='caption-paired public header exclusion rectangles, PATCOPY outer strokes and qualified-window samples; runtime primary raised-edge rectangles')
        row['tab_paint_measurements'] = details
    return rows


def build():
    DIRECTORY.mkdir(parents=True, exist_ok=True)
    baseline, reference = BASE / 'comparison.json', DRAWING / 'comparison.json'
    base = json.loads(baseline.read_text(encoding='utf-8'))
    drawing = json.loads(reference.read_text(encoding='utf-8'))
    rows = augment(base, drawing)
    for row in rows:
        for artifact in row['images']:
            shutil.copyfile(BASE / artifact['file'], DIRECTORY / artifact['file'])
    data = dict(schema='calcforms.layout_references.v1', owner=base['owner'],
                baseline_reference=baseline.relative_to(ROOT).as_posix(),
                baseline_sha256=hashlib.sha256(baseline.read_bytes()).hexdigest(),
                drawing_reference=reference.relative_to(ROOT).as_posix(),
                drawing_sha256=hashlib.sha256(reference.read_bytes()).hexdigest(), observations=rows)
    path = DIRECTORY / 'comparison.json'
    path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8', newline='\n')
    report = replay(path)
    path.with_name('forms-parity.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8', newline='\n')
    path.with_name('forms-parity.md').write_text(markdown(report), encoding='utf-8', newline='\n')
    print(json.dumps({k: v for k, v in report['summary'].items() if k != 'measured_failures'}))


if __name__ == '__main__':
    build()
