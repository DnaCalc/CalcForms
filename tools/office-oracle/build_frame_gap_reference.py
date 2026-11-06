"""Add two qualified Frame caption-gap rows to the tab measurement report."""
import copy
import hashlib
import json
import shutil

from PIL import Image

from build_tab_reference import DIRECTORY as BASE, DRAWING
from forms_parity import markdown, replay
from frame_caption_gap import native_gap, runtime_gap, window_probes
from layout_corpus import ROOT

DIRECTORY = BASE.parent / 'oxforms-jbjp.113'


def augment(base, drawing):
    rows = copy.deepcopy(base['observations'])
    drawings = {(row['form'], row['zoom']): row for row in drawing['observations']}
    for row in rows:
        if row['form'] != 'LayoutContainers':
            continue
        source = drawings[row['form'], row['zoom']]
        if row['images'] != source['images'] or row['native_capture_validation']['verified'] is not True:
            raise ValueError('Frame drawing needs the same qualified native window')
        image = Image.open(BASE / row['images'][0]['file']).convert('RGB')
        scene = source['retained_scene']
        scale = min(image.width / scene['surface']['width'], image.height / scene['surface']['height'])
        capture = source['native_control_drawings']['Group']
        raw = (DRAWING / capture['file']).read_bytes()
        if hashlib.sha256(raw).hexdigest() != capture['sha256']:
            raise ValueError('Raw Frame drawing hash differs')
        native = native_gap(raw, capture['font_metrics'], 'Details')
        probes = window_probes(image, row['native_accessible_rectangles_px']['Group'][:2], native)
        control = next(c for c in source['measurements']['controls'] if c['name'] == 'Group')
        actual = runtime_gap(scene, control['calcforms']['node_id'], 'Details', scale)
        row['parity_measurements'].setdefault('Group', {})['frame_caption_gap'] = dict(
            native=native['horizontal_gap_px'], calcforms=actual['horizontal_gap_px'])
        row['frame_caption_gap_measurement'] = dict(native=native, calcforms=actual, window_probes=probes,
            native_emf_file=capture['file'], native_emf_sha256=capture['sha256'],
            width_difference_components_px=dict(caption_advance=native['caption_advance_px'] - actual['caption_advance_px'],
                padding=sum(native['horizontal_padding_px']) - sum(actual['horizontal_padding_px']),
                total_gap=native['horizontal_gap_px'][1] - actual['horizontal_gap_px'][1]),
            method='horizontal border interruption: left offset and width; public caption exclusion, etched top strokes and qualified window boundaries versus retained caption mask')
    return rows


def build():
    DIRECTORY.mkdir(parents=True, exist_ok=True)
    baseline, reference = BASE / 'comparison.json', DRAWING / 'comparison.json'
    base = json.loads(baseline.read_text(encoding='utf-8'))
    rows = augment(base, json.loads(reference.read_text(encoding='utf-8')))
    for row in rows:
        for artifact in row['images']:
            shutil.copyfile(BASE / artifact['file'], DIRECTORY / artifact['file'])
    data = dict(schema='calcforms.layout_references.v1', owner=base['owner'],
                baseline_reference=baseline.relative_to(ROOT).as_posix(), baseline_sha256=hashlib.sha256(baseline.read_bytes()).hexdigest(),
                drawing_reference=reference.relative_to(ROOT).as_posix(), drawing_sha256=hashlib.sha256(reference.read_bytes()).hexdigest(), observations=rows)
    path = DIRECTORY / 'comparison.json'
    path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8', newline='\n')
    report = replay(path)
    path.with_name('forms-parity.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8', newline='\n')
    path.with_name('forms-parity.md').write_text(markdown(report), encoding='utf-8', newline='\n')
    print(json.dumps({k: v for k, v in report['summary'].items() if k != 'measured_failures'}))


if __name__ == '__main__':
    build()
