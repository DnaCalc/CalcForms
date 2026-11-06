"""Qualify tab caption ink within independently emitted native and retained cells."""
import math

from drawing_parity import intersect, scene_text
from forms_parity import edges, ink_geometry
from native_drawing import decode
from tab_paint import native_headers, window_probes


def cell(caption, cells, baseline, ascent, descent, clip, origin=(0, 0)):
    if len(cells) != len(caption) + 1 or not all(math.isfinite(v) for v in [*cells, baseline, ascent, descent, *clip]):
        raise ValueError('Invalid literal character cells')
    if any(b < a for a, b in zip(cells, cells[1:])) or cells[-1] <= cells[0] or min(ascent, descent) < 0:
        raise ValueError('Invalid caption advances/font line')
    bounds = intersect([cells[0], baseline - ascent, cells[-1], baseline + descent], clip)
    if bounds[0] >= bounds[2] or bounds[1] >= bounds[3]:
        raise ValueError('Caption cell has no visible area')
    return dict(caption=caption, roi_px=[v + origin[i % 2] for i, v in enumerate(bounds)],
                character_edges_px=[v + origin[0] for v in cells], baseline_px=baseline + origin[1])


def qualify(row, scene, size, image, drawing_directory):
    controls = {c['name']: c for c in row['measurements']['controls']}
    runs = scene_text(row, scene, size)
    sx = size[0] / float(row['excel_facts'].splitlines()[0].split(';')[0])
    sy = size[1] / float(row['excel_facts'].splitlines()[0].split(';')[1])
    result = {}
    for name, fact in row.get('tab_paint_measurements', {}).items():
        source = row['native_control_drawings'][name]
        raw = (drawing_directory / source['file']).read_bytes()
        import hashlib
        if hashlib.sha256(raw).hexdigest() != source['sha256'] or decode(raw, source['font_metrics']) != source['text']:
            raise ValueError('Native raw caption output changed')
        captions = [h['caption'] for h in fact['native']]
        headers = native_headers(raw, source['font_metrics'], captions)
        origin = edges(controls[name]['native']['bounds'], [sx, sy])[:2]
        window_probes(image, origin, headers)
        native = [cell(r['text'], r['cell_edges_px'], r['baseline_px'], r['font']['ascent'],
                       r['font']['descent'], r['clip_px'], origin) for r in source['text']]
        actual = []
        for caption in captions:
            records = [r for r in runs[name] if r['text'] == caption]
            if len(records) != 1:
                raise ValueError('Ambiguous runtime caption cells')
            record = records[0]
            metrics = scene['text'][str(record['run'])]['metrics']
            actual.append(cell(caption, record['cell_edges_px'], record['baseline_px'],
                               metrics['ascent'] * sy, metrics['descent'] * sy, record['clip_px']))
        if [c['caption'] for c in native] != captions:
            raise ValueError('Native caption order differs')
        for c in native:
            if not ink_geometry(image, c['roi_px'])['ink_pixels']:
                raise ValueError('Native caption cells are empty in the qualified window')
        result[name] = dict(native=native, calcforms=actual,
            method='ink within each independently emitted literal character-cell extent intersected with its actual text clip; public header strokes/window samples qualify native placement')
    return result
