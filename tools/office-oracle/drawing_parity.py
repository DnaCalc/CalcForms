"""Pair native public drawing records with production retained text geometry."""
from __future__ import annotations

from collections import defaultdict
import math

from forms_parity import color_class, definitions, edges, rounded, TEXTLESS
from layout_measurements import GREETER_KINDS


def intersect(a, b):
    return [max(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), min(a[3], b[3])]


def scene_text(row, scene, size):
    """Use exactly the Scene transform, clip, alignment and baseline equations."""
    nodes = {node['id']: node for node in scene['nodes']}
    ids = {c['calcforms'].get('node_id'): c['name'] for c in row['measurements']['controls']}
    if row['form'] == 'greeter':
        ids = dict(enumerate(GREETER_KINDS, 1))
    sx = sy = min(size[0] / scene['surface']['width'], size[1] / scene['surface']['height'])
    result = defaultdict(list)

    def walk(node_id, owner, transform, clip, site_origin):
        node = nodes[node_id]
        if not node['visible']:
            return
        owner = ids.get(node_id, owner)
        parent_sx, parent_sy, parent_tx, parent_ty = transform
        t = node['transform']
        transform = (parent_sx * t['sx'], parent_sy * t['sy'],
                     parent_sx * t['tx'] + parent_tx, parent_sy * t['ty'] + parent_ty)
        ax, ay, tx, ty = transform
        if ax <= 0 or ay <= 0:
            raise ValueError('Drawing measurements require positive Scene scales')

        def box(rect):
            return [rect['x'] * ax + tx, rect['y'] * ay + ty,
                    (rect['x'] + rect['w']) * ax + tx, (rect['y'] + rect['h']) * ay + ty]

        if node_id in ids:
            site_origin = box(node['bounds'])[:2]
        if node['clip']:
            clip = intersect(clip, box(node['clip']))
        for prim in node['prims']:
            if prim['op'] != 'draw_text' or owner is None:
                continue
            run = scene['text'][str(prim['run'])]
            rect = box(prim['rect'])
            metrics = run['metrics']
            width = metrics['advance'] * ax
            start = rect[0] + ({'left': 0, 'center': (rect[2] - rect[0] - width) / 2,
                                'right': rect[2] - rect[0] - width}[prim['align']])
            baseline = rect[1] + (rect[3] - rect[1] - (metrics['ascent'] + metrics['descent']) * ay) / 2 + metrics['ascent'] * ay
            effective_clip = rounded(intersect(clip, rect) if prim['clip'] else clip)
            result[owner].append(dict(text=run['source'], baseline_px=baseline,
                                      origin_px=[start, baseline], clip_px=effective_clip,
                                      site_origin_px=site_origin,
                                      cell_edges_px=[start + stop * ax for stop in run['caret']['stops']],
                                      node=node_id, run=prim['run']))
        for child in node['children']:
            walk(child, owner, transform, clip, site_origin)

    walk(scene['root'], None, (sx, sy, 0, 0), [0, 0, *size], None)
    return dict(result)


def sources(row):
    authored = definitions(row['form'])
    result = {}
    for c in row['measurements']['controls']:
        name, kind = c['name'], c['native']['kind']
        definition = authored.get(name, {})
        if kind in TEXTLESS:
            continue
        text = definition.get('items', definition.get('tabs', definition.get('pages',
               [definition.get('caption', definition.get('text', ''))])))
        if kind == 'ComboBox' and definition.get('items'):
            text = [definition['items'][1]]
        result[name] = text
    for probe in row['native_capture_validation']['text_probes']:
        result[probe['control']] = probe['sources']
    return result


def native_text(row, drawing, size, texts):
    width, height = map(float, row['excel_facts'].splitlines()[0].split(';')[:2])
    scale = size[0] / width, size[1] / height
    controls = {c['name']: c for c in row['measurements']['controls']}
    result, unmatched = defaultdict(list), []
    for record in drawing['text']:
        if record['font']['face'] == 'Marlett' or not record['text'].strip():
            continue  # Native symbolic check/radio layers are measured separately.
        candidates = []
        for name, captions in texts.items():
            if not any(record['text'].strip() in caption for caption in captions):
                continue
            if '.' not in name:
                left, top, right, bottom = edges(controls[name]['native']['bounds'], scale)
                x, y = record['reference_px']
                if not (left - 1 <= x <= right + 1 and top - 1 <= y <= bottom + 1):
                    continue
            candidates.append(name)
        if len(candidates) != 1:
            unmatched.append(dict(record=record['record'], candidates=candidates))
            continue
        name = candidates[0]
        # Disabled native captions include a second white embossed shadow. Use
        # the independently read effective foreground property, not that shadow.
        colour = record['colour']
        rgb = [colour & 255, (colour >> 8) & 255, (colour >> 16) & 255]
        if color_class(rgb) not in {color_class(c) for c in row['native_colour_properties'][name]['effective_text_rgb']}:
            continue
        result[name].append(record)
    return dict(result), unmatched


def text_geometry(captions, records):
    """Match literal fragments, allowing only omitted whitespace between tokens.

    Breaks are character offsets in each original caption. Clipping measures
    the first horizontal character cell cut by the right edge, per drawn line;
    it does not pretend that font-cell bounds are visible glyph-ink bounds.
    """
    if not records or any(not caption for caption in captions):
        return None
    remaining = list(records)
    baselines, breaks, clipped, lines = [], [], [], []
    for caption in captions:
        candidates = [r for r in remaining if r['text'].strip() in caption]
        candidates.sort(key=lambda r: (r['baseline_px'], r['origin_px'][0]))
        cursor, previous_y, caption_breaks, caption_clipped = 0, None, [], []
        line = None
        for record in candidates:
            fragment = record['text']
            offset = caption.find(fragment, cursor)
            if offset < 0 or caption[cursor:offset].strip():
                return None  # Ambiguous/reordered/missing literal output.
            if previous_y is None or abs(previous_y - record['baseline_px']) > .1:
                if previous_y is not None:
                    caption_breaks.append(offset)
                baselines.append(record['baseline_px'])
                line = dict(start=offset, text='', baseline_px=record['baseline_px'], records=[])
                lines.append(line)
                caption_clipped.append(None)
            line['text'] += caption[cursor:offset] + fragment
            line['records'].append(record)
            clip = record['clip_px']
            if clip is None:
                return None
            cells = record['cell_edges_px']
            if len(cells) != len(fragment) + 1 or not all(math.isfinite(v) for v in cells):
                raise ValueError('Invalid measured character-cell table')
            partial = next((i for i, right in enumerate(cells[1:]) if right > clip[2] + 1e-5), None)
            if partial is not None and caption_clipped[-1] is None:
                caption_clipped[-1] = offset + partial
            cursor = offset + len(fragment)
            previous_y = record['baseline_px']
            remaining.remove(record)
        if caption[cursor:].strip():
            return None
        breaks.append(caption_breaks)
        clipped.append(caption_clipped)
    if remaining:
        return None
    return dict(baseline=baselines, wrap_point=breaks, exact_line_breaks=breaks,
                clipping_point=clipped, lines=lines)


def measurements(row, scene, drawing, size):
    captions = sources(row)
    native, unmatched = native_text(row, drawing, size, captions)
    actual = scene_text(row, scene, size)
    for name, control_drawing in row.get('native_control_drawings', {}).items():
        expected_classes = {color_class(c) for c in row['native_colour_properties'][name]['effective_text_rgb']}
        native[name] = [r for r in control_drawing['text'] if r['font']['face'] != 'Marlett'
                        and any(r['text'].strip() and r['text'].strip() in caption for caption in captions[name])
                        and color_class([r['colour'] & 255, (r['colour'] >> 8) & 255, (r['colour'] >> 16) & 255]) in expected_classes]
        local = []
        for record in actual.get(name, []):
            x, y = record['site_origin_px']
            local.append(dict(record, origin_px=[record['origin_px'][0] - x, record['origin_px'][1] - y],
                              baseline_px=record['baseline_px'] - y,
                              clip_px=[v - (x if i % 2 == 0 else y) for i, v in enumerate(record['clip_px'])],
                              cell_edges_px=[v - x for v in record['cell_edges_px']]))
        actual[name] = local
    paired, details = {}, {}
    for name, text in captions.items():
        n = text_geometry(text, native.get(name, []))
        a = text_geometry(text, actual.get(name, []))
        details[name] = dict(captions=text, native=n, calcforms=a)
        if n is None or a is None:
            continue
        paired[name] = {metric: dict(native=n[metric], calcforms=a[metric])
                        for metric in ('baseline', 'wrap_point', 'exact_line_breaks', 'clipping_point')}
    return paired, dict(controls=details, unmatched_native_text=unmatched)
