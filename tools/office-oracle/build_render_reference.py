"""Pair fresh runtime windows/Scenes with unchanged, independently pinned native facts."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image

from border_spacing import measurements as border_measurements
from colour_measurements import paired_colours, scene_colours
from drawing_parity import measurements as drawing_measurements
from forms_parity import markdown, replay
from frame_caption_gap import runtime_gap
from layout_corpus import ROOT
from layout_measurements import measure
from spacing_parity import measurements as glyph_measurements
from tab_paint import runtime_headers, sizes
from tab_text_cells import qualify as qualify_tab_cells

DRAWING = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.106/comparison.json'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def update(row, scene, drawing, native, actual):
    """Recompute both sides from the original native inputs and new retained output."""
    for facts in row['parity_measurements'].values():
        for metric in ('border_thickness', 'border_class', 'baseline', 'wrap_point',
                       'exact_line_breaks', 'clipping_point', 'glyph_size', 'glyph_caption_gap'):
            if metric in facts:
                facts[metric]['calcforms'] = None
    row['measurements'] = measure(row, scene)
    row['native_drawing'] = drawing['native_drawing']
    row['native_control_drawings'] = drawing['native_control_drawings']
    row['calcforms_colour_paint'] = scene_colours(row, scene)
    row['colour_measurements'] = paired_colours(row, scene, row['native_colour_properties'])
    properties, spacing, colours, scans = border_measurements(row, scene, native, actual)
    text, detail = drawing_measurements(row, scene, row['native_drawing'], native.size)
    glyphs, glyph_detail = glyph_measurements(row, scene, native.size)
    for measured in (properties, text, glyphs):
        for name, facts in measured.items():
            for metric, pair in facts.items():
                old = row['parity_measurements'].get(name, {}).get(metric)
                if old and old.get('native') != pair['native']:
                    raise ValueError(f'Independent native fact changed: {name}.{metric}')
                row['parity_measurements'].setdefault(name, {})[metric] = pair
    row['spacing_measurements'] = spacing
    for name, facts in colours.items():
        row['colour_measurements'][name].update(facts)
    row['drawing_text_measurements'] = detail
    row['glyph_spacing_measurements'] = glyph_detail
    row['border_scan_lines'] = scans
    scale = min(native.width / scene['surface']['width'], native.height / scene['surface']['height'])
    controls = {c['name']: c for c in row['measurements']['controls']}
    for name, fact in row.get('tab_paint_measurements', {}).items():
        headers = runtime_headers(scene, controls[name]['calcforms']['node_id'],
                                  [h['caption'] for h in fact['native']], scale)
        fact['calcforms'] = headers
        row['parity_measurements'][name]['tab_sizes']['calcforms'] = sizes(headers)
    if 'frame_caption_gap_measurement' in row:
        fact = row['frame_caption_gap_measurement']
        expected = fact['native']
        observed = runtime_gap(scene, controls['Group']['calcforms']['node_id'], expected['caption'], scale)
        fact['calcforms'] = observed
        fact['width_difference_components_px'] = dict(
            caption_advance=expected['caption_advance_px'] - observed['caption_advance_px'],
            padding=sum(expected['horizontal_padding_px']) - sum(observed['horizontal_padding_px']),
            total_gap=expected['horizontal_gap_px'][1] - observed['horizontal_gap_px'][1])
        row['parity_measurements']['Group']['frame_caption_gap']['calcforms'] = observed['horizontal_gap_px']
    row['retained_scene'] = scene
    row['text_cell_measurements'] = qualify_tab_cells(row, scene, native.size, native, DRAWING.parent)
    for key in ('native_drawing', 'native_control_drawings'):
        row.pop(key)
    return row


def build(base_path, session, label, output, forms):
    base_path, session, output = [p.resolve() for p in (base_path, session, output)]
    if any(not p.is_relative_to(ROOT) for p in (base_path, session, output)) or output.exists():
        raise ValueError('Use repository inputs and a fresh repository output directory')
    replay(base_path)
    base = json.loads(base_path.read_text(encoding='utf-8'))
    drawings = {(r['form'], r['zoom']): r for r in json.loads(DRAWING.read_text(encoding='utf-8'))['observations']}
    output.mkdir(parents=True)
    rows = []
    for original in base['observations']:
        row = copy.deepcopy(original)
        native_path = base_path.parent / row['images'][0]['file']
        runtime_path = base_path.parent / row['images'][1]['file']
        if not forms or row['form'] in forms:
            capture_path = session / f"{row['form']}-{label}-{row['zoom']}/comparison.json"
            fresh = json.loads(capture_path.read_text(encoding='utf-8'))
            if fresh['excel_facts'] != row['excel_facts']:
                raise ValueError('Fresh paired native geometry differs from pinned native facts')
            scene = json.loads((session / fresh['scene_file']).read_text(encoding='utf-8'))
            runtime_path = capture_path.with_name('calcforms-client.png')
            if digest(runtime_path) != fresh['calcforms']['client']['sha256']:
                raise ValueError('Runtime client capture hash differs')
            for key in ('calcforms', 'calcforms_observation', 'runtime_sha256'):
                row[key] = fresh[key]
            # Pixel errors from a different window are not carried into a new report.
            row.pop('pixels', None)
            row['render_input'] = dict(capture_sha256=digest(capture_path), scene_sha256=digest(session / fresh['scene_file']),
                runtime_sha256=fresh['runtime_sha256'], capture_method=fresh['capture'])
            for suffix, source in [('capture.json', capture_path), ('scene.json', session / fresh['scene_file'])]:
                target = output / f"{row['form']}-{row['zoom']}-{suffix}"
                shutil.copyfile(source, target)
                row['render_input'][suffix.split('.')[0] + '_file'] = target.name
            row = update(row, scene, drawings[row['form'], row['zoom']],
                         Image.open(native_path).convert('RGB'), Image.open(runtime_path).convert('RGB'))
        row['images'] = []
        for engine, source in zip(('excel', 'calcforms'), (native_path, runtime_path), strict=True):
            target = output / f"{row['form']}-{row['zoom']}-{engine}.png"
            shutil.copyfile(source, target)
            row['images'].append(dict(file=target.name, sha256=digest(target)))
        rows.append(row)
    reference = output / 'comparison.json'
    owner_path = output / 'runtime-ownership.json'
    shutil.copyfile(session / 'ownership.json', owner_path)
    production = [ROOT / 'Cargo.toml', ROOT / 'Cargo.lock']
    production += sorted((ROOT / 'vba/calcforms').rglob('*.cls'))
    production += sorted((ROOT / 'vba/calcforms').rglob('*.bas'))
    production += sorted((ROOT / 'vba/calcforms').rglob('*.vba'))
    for crate in ('calcforms-pal', 'calcforms-calcvba-adapter', 'calcforms-bootstrap', 'calcforms-pal-win'):
        production += sorted((ROOT / 'crates' / crate / 'src').rglob('*.rs'))
        production.append(ROOT / 'crates' / crate / 'Cargo.toml')
    production += sorted((ROOT / 'crates/calcforms-bootstrap/examples').glob('*.rs'))
    reference.write_text(json.dumps(dict(schema='calcforms.layout_references.v1', owner=base['owner'],
        baseline_reference=base_path.relative_to(ROOT).as_posix(), baseline_sha256=digest(base_path),
        drawing_reference=DRAWING.relative_to(ROOT).as_posix(), drawing_sha256=digest(DRAWING),
        runtime_ownership=dict(file=owner_path.name, sha256=digest(owner_path)),
        production_sources={p.relative_to(ROOT).as_posix(): digest(p) for p in production}, observations=rows), indent=2) + '\n', encoding='utf-8', newline='\n')
    report = replay(reference)
    reference.with_name('forms-parity.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8', newline='\n')
    reference.with_name('forms-parity.md').write_text(markdown(report), encoding='utf-8', newline='\n')
    print(json.dumps({k: v for k, v in report['summary'].items() if k != 'measured_failures'}))


def validate(reference):
    reference = reference.resolve()
    if not reference.is_relative_to(ROOT):
        raise ValueError('Reference must stay in repository')
    data = json.loads(reference.read_text(encoding='utf-8'))
    base_path = (ROOT / data['baseline_reference']).resolve()
    drawing_path = (ROOT / data['drawing_reference']).resolve()
    if not base_path.is_relative_to(ROOT) or drawing_path != DRAWING:
        raise ValueError('Reference source path differs')
    if digest(base_path) != data['baseline_sha256'] or digest(drawing_path) != data['drawing_sha256']:
        raise ValueError('Pinned reference hash differs')
    runtime_owner = None
    if 'runtime_ownership' in data:
        artifact = data['runtime_ownership']
        owner_path = (reference.parent / artifact['file']).resolve()
        if owner_path.parent != reference.parent or digest(owner_path) != artifact['sha256']:
            raise ValueError('Runtime ownership artifact differs')
        runtime_owner = json.loads(owner_path.read_text(encoding='utf-8'))
        if runtime_owner['interactive'] or runtime_owner['security_changes'] or runtime_owner['input_desktop_switched']:
            raise ValueError('Runtime capture was not confined to its private desktop')
    base = json.loads(base_path.read_text(encoding='utf-8'))
    drawings = {(r['form'], r['zoom']): r for r in json.loads(drawing_path.read_text(encoding='utf-8'))['observations']}
    originals = {(r['form'], r['zoom']): r for r in base['observations']}
    if len(originals) != len(data['observations']):
        raise ValueError('Render report changed coverage')
    for row in data['observations']:
        identity = row['form'], row['zoom']
        original = originals[identity]
        if row['images'][0]['sha256'] != original['images'][0]['sha256']:
            raise ValueError('Independent native window changed')
        if row.get('historical_scene_reference') is True:
            source = drawings[identity]
            if [a['sha256'] for a in original['images']] != [a['sha256'] for a in source['images']]:
                raise ValueError('Historical Scene and paired windows differ')
            expected = update(copy.deepcopy(original), source['retained_scene'], source,
                Image.open(reference.parent / row['images'][0]['file']).convert('RGB'),
                Image.open(reference.parent / row['images'][1]['file']).convert('RGB'))
            expected['historical_scene_reference'] = True
        elif 'render_input' not in row:
            expected = copy.deepcopy(original)
        else:
            inputs = row['render_input']
            paths = {}
            for kind in ('capture', 'scene'):
                path = (reference.parent / inputs[kind + '_file']).resolve()
                if path.parent != reference.parent or digest(path) != inputs[kind + '_sha256']:
                    raise ValueError('Runtime artifact path/hash differs')
                paths[kind] = path
            capture = json.loads(paths['capture'].read_text(encoding='utf-8'))
            if runtime_owner is None or capture['excel']['geometry']['pid'] != runtime_owner['excel_pid']:
                raise ValueError('Fresh capture does not belong to its recorded Excel owner')
            scene = json.loads(paths['scene'].read_text(encoding='utf-8'))
            if scene != row['retained_scene'] or inputs['runtime_sha256'] != capture['runtime_sha256']:
                raise ValueError('Retained runtime identity differs')
            if row['images'][1]['sha256'] != capture['calcforms']['client']['sha256']:
                raise ValueError('Runtime client image differs from captured window')
            expected = copy.deepcopy(original)
            for key in ('calcforms', 'calcforms_observation', 'runtime_sha256'):
                expected[key] = capture[key]
            expected.pop('pixels', None)
            expected['render_input'] = inputs
            expected = update(expected, scene, drawings[identity],
                Image.open(reference.parent / row['images'][0]['file']).convert('RGB'),
                Image.open(reference.parent / row['images'][1]['file']).convert('RGB'))
        expected['images'] = row['images']
        if expected != row:
            raise ValueError('Render observation does not regenerate from captured inputs')
    report = replay(reference)
    if report != json.loads(reference.with_name('forms-parity.json').read_text(encoding='utf-8')):
        raise ValueError('Forms report differs from replay')
    if markdown(report) != reference.with_name('forms-parity.md').read_text(encoding='utf-8'):
        raise ValueError('Forms Markdown differs from replay')
    before = replay(base_path)
    def native_facts(replayed):
        return {(o['form'], o['zoom'], c['name'], i['category'], i['metric']): i['native']
                for o in replayed['observations']
                for c in [dict(name='(form)', items=o['items']), *o['controls']] for i in c['items']}
    previous, current = native_facts(before), native_facts(report)
    qualified = {(r['form'], r['zoom'], name) for r in data['observations'] for name in r.get('text_cell_measurements', {})}
    for key in previous.keys() | current.keys():
        if key in previous and key in current and previous[key] == current[key]:
            continue
        form, zoom, name, category, metric = key
        ink_metric = metric in {'ink_bounds', 'alignment_offsets', 'insets', 'visible_line_count'} or metric.endswith('_ink_bounds')
        new_advances = metric.endswith('_character_advances') and key not in previous
        if (form, zoom, name) not in qualified or not (ink_metric or new_advances):
            raise ValueError('Unqualified native measurement/report row changed: ' + str(key))
    print(json.dumps({k: v for k, v in report['summary'].items() if k != 'measured_failures'}))


def qualify_baseline(base_path, output):
    base_path, output = base_path.resolve(), output.resolve()
    if not base_path.is_relative_to(ROOT) or not output.is_relative_to(ROOT) or output.exists():
        raise ValueError('Use a fresh repository output directory')
    base = json.loads(base_path.read_text(encoding='utf-8'))
    drawings = {(r['form'], r['zoom']): r for r in json.loads(DRAWING.read_text(encoding='utf-8'))['observations']}
    output.mkdir(parents=True)
    rows = []
    for original in base['observations']:
        source = drawings[original['form'], original['zoom']]
        if [a['sha256'] for a in original['images']] != [a['sha256'] for a in source['images']]:
            raise ValueError('Historical drawing and paired windows differ')
        for artifact in original['images']:
            shutil.copyfile(base_path.parent / artifact['file'], output / artifact['file'])
        row = update(copy.deepcopy(original), source['retained_scene'], source,
            *[Image.open(output / a['file']).convert('RGB') for a in original['images']])
        row['historical_scene_reference'] = True
        rows.append(row)
    reference = output / 'comparison.json'
    reference.write_text(json.dumps(dict(schema='calcforms.layout_references.v1', owner=base['owner'],
        baseline_reference=base_path.relative_to(ROOT).as_posix(), baseline_sha256=digest(base_path),
        drawing_reference=DRAWING.relative_to(ROOT).as_posix(), drawing_sha256=digest(DRAWING), observations=rows), indent=2) + '\n', encoding='utf-8', newline='\n')
    report = replay(reference)
    reference.with_name('forms-parity.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8', newline='\n')
    reference.with_name('forms-parity.md').write_text(markdown(report), encoding='utf-8', newline='\n')
    print(json.dumps({k: v for k, v in report['summary'].items() if k != 'measured_failures'}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', type=Path)
    parser.add_argument('--session', type=Path)
    parser.add_argument('--label')
    parser.add_argument('--out', type=Path)
    parser.add_argument('--forms', nargs='+')
    parser.add_argument('--check', type=Path)
    parser.add_argument('--qualify-baseline', action='store_true')
    args = parser.parse_args()
    if args.check:
        validate(args.check)
    elif args.qualify_baseline and args.base and args.out:
        qualify_baseline(args.base, args.out)
    elif not all((args.base, args.session, args.label, args.out)):
        parser.error('Build requires --base, --session, --label and --out')
    else:
        build(args.base, args.session, args.label, args.out, args.forms)
