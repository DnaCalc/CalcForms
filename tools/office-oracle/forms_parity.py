"""Measured forms parity, replayable from client images and captured facts.

Pixel equality is deliberately absent from the priority list. A missing
measurement fails coverage; it never silently passes a compatibility check.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path

from PIL import Image

from layout_corpus import ROOT, load_corpus

LAYOUT_TOLERANCE_PX = 1
TEXT_TOLERANCE_PX = 2
BEHAVIOURS = ('event_order', 'tab_order', 'enter_default', 'escape_cancel',
              'accelerators', 'hit_testing', 'selection', 'scrolling',
              'value_changes', 'show_hide_unload')
SPACING = ('insets', 'list_row_height', 'tab_sizes', 'frame_caption_gap',
           'glyph_size', 'glyph_caption_gap', 'focus_rectangle', 'border_thickness')
TEXTLESS = {'Image', 'SpinButton', 'ScrollBar'}


def check(category, metric, expected=None, actual=None, tolerance=0, unit='px', reason=None):
    measured = expected is not None and actual is not None
    delta = None
    passed = False
    if measured:
        if isinstance(expected, (int, float)) and isinstance(actual, (int, float)):
            if not all(math.isfinite(v) for v in (expected, actual)):
                raise ValueError('Non-finite parity measurement')
            delta = abs(actual - expected)
            passed = delta <= tolerance
        elif isinstance(expected, list) and isinstance(actual, list) and all(
                isinstance(v, (int, float)) for v in expected + actual) and len(expected) == len(actual):
            if not all(math.isfinite(v) for v in expected + actual):
                raise ValueError('Non-finite parity measurement')
            delta = max((abs(a - e) for e, a in zip(expected, actual)), default=0)
            passed = delta <= tolerance
        else:
            delta = 0 if actual == expected else 1
            passed = actual == expected
    return dict(category=category, metric=metric,
                status='pass' if passed else 'fail',
                native=expected, calcforms=actual, max_delta=delta,
                tolerance=tolerance, unit=unit, measurement_count=2 if measured else 0,
                reason=reason if reason else (None if measured else 'not measured in these inputs'))


def edges(bounds, scale):
    if len(bounds) != 4 or not all(math.isfinite(v) for v in bounds) or min(bounds[2:]) < 0:
        raise ValueError('Invalid control rectangle')
    x, y, w, h = bounds
    return [x * scale[0], y * scale[1], (x + w) * scale[0], (y + h) * scale[1]]


def rounded(values):
    # Match the positive-coordinate nearest-pixel rule, including .5 ties.
    return [math.floor(v + 0.5) for v in values]


def color_class(rgb):
    r, g, b = rgb[:3]
    if b > r + 40 and b > g + 20:
        return 'selection-blue'
    if max(rgb[:3]) - min(rgb[:3]) > 35:
        return 'chromatic'
    v = sum(rgb[:3]) / 3
    if v < 64:
        return 'dark-text'
    if v < 175:
        return 'shadow-or-disabled'
    if v < 230:
        return 'mid-light'
    if v < 248:
        return 'control-face'
    return 'white'


def region(image, box):
    box = [max(0, min(image.width if i % 2 == 0 else image.height, v)) for i, v in enumerate(rounded(box))]
    if box[2] <= box[0] or box[3] <= box[1]:
        return None, box
    return image.crop(box).convert('RGB'), box


def dotted_rectangle(image, box):
    crop, roi = region(image, box)
    if crop is None:
        return None
    candidates = []
    for y in range(crop.height):
        xs = [x for x in range(crop.width) if max(crop.getpixel((x, y))) < 64]
        if len(xs) < 8 or xs[-1] - xs[0] < 15:
            continue
        adjacent = sum(b == a + 1 for a, b in zip(xs, xs[1:]))
        if adjacent < len(xs) * .15:
            candidates.append((y, xs[0], xs[-1]))
    for top, left, right in candidates:
        for bottom, bl, br in candidates:
            if bottom - top < 6 or abs(bl - left) > 1 or abs(br - right) > 1:
                continue
            sides = [sum(max(crop.getpixel((x, y))) < 64 for y in range(top + 1, bottom))
                     for x in (left, right)]
            if min(sides) >= (bottom - top) / 4:
                return [roi[0] + left, roi[1] + top, roi[0] + max(right, br) + 1, roi[1] + bottom + 1]
    return None


def ink_geometry(image, box, disabled=False, focus=None, font_height_px=None):
    """Bound foreground by colour class, ignoring antialias coverage differences.

    This measures visible ink, not glyph identity or an inferred baseline. Border
    and glyph exclusion must be supplied by the caller's explicitly recorded ROI.
    """
    crop, roi = region(image, box)
    if crop is None:
        return dict(roi_px=roi, ink_bounds_px=None, line_bands_px=[], ink_pixels=0)
    points = []
    for y in range(crop.height):
        blue = [x for x in range(crop.width) if color_class(crop.getpixel((x, y))) == 'selection-blue']
        selected = len(blue) > crop.width / 3
        for x in range(crop.width):
            c = crop.getpixel((x, y))
            foreground = max(c) < (180 if disabled else 110) or (
                selected and min(blue) < x < max(blue) and min(c) > 245)
            if foreground:
                points.append((x + roi[0], y + roi[1]))
    if not points:
        return dict(roi_px=roi, ink_bounds_px=None, line_bands_px=[], ink_pixels=0)
    if focus:
        left, top, right, bottom = focus
        points = [(x, y) for x, y in points if not (
            left <= x < right and top <= y < bottom and
            (x in (left, right - 1) or y in (top, bottom - 1)))]
    if font_height_px:
        # Native tab/frame edges can cross the text ROI. A straight uninterrupted
        # segment longer than a complete font em is decoration, not a glyph stem.
        mask = set(points)
        excluded = set()
        for vertical in (False, True):
            groups = {}
            for x, y in points:
                groups.setdefault(x if vertical else y, []).append(y if vertical else x)
            limit = font_height_px + 2 if vertical else font_height_px * 3
            for axis, values in groups.items():
                values.sort()
                start = previous = values[0]
                for value in [*values[1:], values[-1] + 2]:
                    if value != previous + 1:
                        if previous - start + 1 > limit:
                            excluded.update((axis, v) if vertical else (v, axis) for v in range(start, previous + 1))
                        start = value
                    previous = value
        points = sorted(mask - excluded)
    if not points:
        return dict(roi_px=roi, ink_bounds_px=None, line_bands_px=[], ink_pixels=0)
    ys = sorted({y for _, y in points})
    bands = [[ys[0], ys[0] + 1]]
    # One blank row can occur between a dot and its stem. Two separates lines.
    for y in ys[1:]:
        if y - bands[-1][1] < 2:
            bands[-1][1] = y + 1
        else:
            bands.append([y, y + 1])
    classes = sorted({Counter(color_class(image.getpixel((x, y))) for x, y in points if top <= y < bottom).most_common(1)[0][0]
                      for top, bottom in bands})
    return dict(roi_px=roi, ink_bounds_px=[min(x for x, _ in points), min(ys),
                max(x for x, _ in points) + 1, max(ys) + 1],
                line_bands_px=bands, ink_pixels=len(points), foreground_classes=classes)


def definitions(form):
    if form == 'greeter':
        return {'Prompt': {'caption': 'Your name:', 'kind': 'Label'},
                'InputName': {'text': 'Ada', 'kind': 'TextBox'},
                'Greet': {'caption': 'Greet', 'kind': 'CommandButton'},
                'Loud': {'caption': 'Loud', 'kind': 'CheckBox'},
                'Output': {'caption': '(ready)', 'kind': 'Label'}}
    definition = next((f for f in load_corpus()['forms'] if f['name'] == form), None)
    result = {}
    def walk(controls, prefix=''):
        for c in controls:
            result[prefix + c['name']] = c
            walk(c.get('children', []), prefix + c['name'] + '.')
    if definition:
        walk(definition['controls'])
    return result


def text_roi(box, kind, scale):
    left, top, right, bottom = box
    sx, sy = scale
    if kind in {'CheckBox', 'OptionButton'}:
        left += 11 * sx  # exclude the glyph while retaining the native caption's first ink
    elif kind in {'CommandButton', 'ToggleButton', 'TextBox', 'ComboBox', 'ListBox'}:
        left += 2 * sx
        right -= 2 * sx
        top += 2 * sy
        bottom -= 2 * sy
        if kind == 'ComboBox':
            right -= 15 * sx
    elif kind == 'Frame':
        left += 4 * sx
        right -= 4 * sx
        bottom = min(bottom, top + 12 * sy)
    elif kind in {'TabStrip', 'MultiPage'}:
        left += 3 * sx
        right -= 3 * sx
        top += 2 * sy
        bottom = min(bottom, top + 11 * sy)
    return [left, top, right, bottom]


def dominant_class(image, box):
    crop, _ = region(image, box)
    if crop is None:
        return None
    return color_class(Counter(crop.get_flattened_data()).most_common(1)[0][0])


def caption_parts(image, measurement, kind, count, scale):
    """Separate known list rows. Do not guess which caption an ambiguous blob is."""
    bands = measurement['line_bands_px']
    if count == 1:
        return [measurement['ink_bounds_px']]
    if kind == 'ListBox' and len(bands) == count:
        left, _, right, _ = measurement['roi_px']
        return [ink_geometry(image, [left, top, right, bottom])['ink_bounds_px'] for top, bottom in bands]
    if kind in {'TabStrip', 'MultiPage'} and len(bands) == 1:
        crop, box = region(image, measurement['roi_px'])
        columns = [x for x in range(crop.width) if any(max(crop.getpixel((x, y))) < 110 for y in range(crop.height))]
        if not columns:
            return []
        groups = [[columns[0], columns[0] + 1]]
        for x in columns[1:]:
            if x - groups[-1][1] >= 6 * scale[0]:
                groups.append([x, x + 1])
            else:
                groups[-1][1] = x + 1
        if len(groups) == count:
            return [ink_geometry(image, [box[0] + left, box[1], box[0] + right, box[3]])['ink_bounds_px']
                    for left, right in groups]
    return []


def control_report(control, data, native, actual, scale, definition):
    name = control['name']
    expected, observed = control['native'], control['calcforms']
    kind = expected['kind']
    colour_facts = data.get('colour_measurements', {}).get(name, {})
    nbox, abox = edges(expected['bounds'], scale), edges(observed['bounds'], scale)
    absolute = data.get('native_accessible_rectangles_px', {}).get(name)
    if absolute is not None:
        if len(absolute) != 4 or not all(math.isfinite(v) for v in absolute):
            raise ValueError('Invalid observed native accessible rectangle')
        x, y, w, h = absolute
        nbox = [x, y, x + w, y + h]
        abox = edges([*observed['paint_origin'], *observed['bounds'][2:]], scale)
    rows = [check('layout', 'rectangle_edges', nbox, abox, LAYOUT_TOLERANCE_PX),
            check('layout', 'twips_to_pixel_rounding', rounded(nbox), rounded(abox), LAYOUT_TOLERANCE_PX),
            check('layout', 'control_kind', kind, observed.get('kind'), unit='identity')]
    nested = '.' in name
    qualification = data.get('native_capture_validation', {}).get('verified')
    usable = qualification is not False and native.size == actual.size and (not nested or absolute is not None)
    rows.append(check('layout', 'native_capture_qualification', 1,
                      1 if qualification is True else None, unit='qualified captures'))
    captions = ([definition.get('caption', definition.get('text', ''))] if definition else [])
    if definition:
        captions = definition.get('items', definition.get('tabs', definition.get('pages', captions)))
        if kind == 'ComboBox' and definition.get('items'):
            captions = [definition['items'][1]]  # saved corpus explicitly selects row 1
    textless = kind in TEXTLESS
    if name in data.get('text_sources', {}):
        captions = data['text_sources'][name]
        if not isinstance(captions, list) or not all(isinstance(c, str) for c in captions):
            raise ValueError('Text sources must be a list of literal strings')
    text_measurements = None
    if usable and not textless:
        nf, af = dotted_rectangle(native, nbox), dotted_rectangle(actual, abox)
        font_height = expected.get('font_size', 8.25) * scale[1]
        ntext = ink_geometry(native, text_roi(nbox, kind, scale), not definition.get('enabled', True), nf, font_height)
        atext = ink_geometry(actual, text_roi(abox, kind, scale), not definition.get('enabled', True), af, font_height)
        text_measurements = dict(native=ntext, calcforms=atext, authored_text=captions,
                                 excluded_dotted_focus=dict(native=nf, calcforms=af),
                                 method='foreground colour mask in recorded text ROI; exclude dotted focus and long straight borders; visible ink only')
        rows += [check('text', 'ink_bounds', ntext['ink_bounds_px'], atext['ink_bounds_px'], TEXT_TOLERANCE_PX),
                 check('text', 'visible_line_count', len(ntext['line_bands_px']), len(atext['line_bands_px']), unit='lines')]
        nparts = caption_parts(native, ntext, kind, len(captions), scale)
        aparts = caption_parts(actual, atext, kind, len(captions), scale)
        text_measurements['captions'] = []
        for index, caption in enumerate(captions):
            item = check('text', f'caption_{index}_ink_bounds',
                         nparts[index] if index < len(nparts) else None,
                         aparts[index] if index < len(aparts) else None, TEXT_TOLERANCE_PX)
            text_measurements['captions'].append(dict(text=caption, **item))
            rows.append(item)
        ni, ai = ntext['ink_bounds_px'], atext['ink_bounds_px']
        if ni and ai:
            rows.append(check('text', 'alignment_offsets', [ni[0] - nbox[0], ni[1] - nbox[1]],
                              [ai[0] - abox[0], ai[1] - abox[1]], TEXT_TOLERANCE_PX))
            rows.append(check('spacing', 'insets', [ni[0] - nbox[0], ni[1] - nbox[1], nbox[2] - ni[2], nbox[3] - ni[3]],
                              [ai[0] - abox[0], ai[1] - abox[1], abox[2] - ai[2], abox[3] - ai[3]], TEXT_TOLERANCE_PX))
        text_colours = colour_facts.get('text_class', dict(native=ntext.get('foreground_classes'), calcforms=atext.get('foreground_classes')))
        rows.append(check('colours', 'text_class', text_colours.get('native'), text_colours.get('calcforms'), unit='class'))
        if nf or af:
            rows.append(check('spacing', 'focus_rectangle', nf or [], af or [], LAYOUT_TOLERANCE_PX,
                              reason='dotted focus rectangle detected from repeated border marks'))
        if kind == 'ListBox':
            nb, ab = ntext['line_bands_px'], atext['line_bands_px']
            rows.append(check('spacing', 'list_row_height',
                              [b[0] - a[0] for a, b in zip(nb, nb[1:])] if len(nb) > 1 else None,
                              [b[0] - a[0] for a, b in zip(ab, ab[1:])] if len(ab) > 1 else None, LAYOUT_TOLERANCE_PX))
    elif textless:
        rows.append(check('text', 'caption_count', 0, 0, unit='captions'))
    else:
        rows.append(check('text', 'ink_bounds', reason='native parent paint origin absent' if nested else 'client capture is unqualified or sizes differ'))
    fill_colours = colour_facts.get('fill_class', dict(native=dominant_class(native, nbox) if usable else None,
                                                    calcforms=dominant_class(actual, abox) if usable else None))
    rows.append(check('colours', 'fill_class', fill_colours.get('native'), fill_colours.get('calcforms'), unit='class'))
    if not textless:
        for metric in ('baseline', 'clipping_point', 'wrap_point', 'exact_line_breaks'):
            facts = data.get('parity_measurements', {}).get(name, {}).get(metric, {})
            rows.append(check('text', metric, facts.get('native'), facts.get('calcforms'),
                              TEXT_TOLERANCE_PX if metric == 'baseline' else 0,
                              unit='character offsets' if metric != 'baseline' else 'px'))
    applicable = {'tab_sizes': kind in {'TabStrip', 'MultiPage'},
                  'frame_caption_gap': kind == 'Frame', 'glyph_size': kind in {'CheckBox', 'OptionButton'},
                  'glyph_caption_gap': kind in {'CheckBox', 'OptionButton'},
                  'focus_rectangle': kind not in {'Label', 'Frame', 'Image'},
                  'border_thickness': kind != 'Label'}
    present = {(r['category'], r['metric']) for r in rows}
    for metric in SPACING:
        if metric in applicable and not applicable[metric]:
            continue
        if metric == 'list_row_height' and kind != 'ListBox':
            continue
        if ('spacing', metric) not in present:
            facts = data.get('parity_measurements', {}).get(name, {}).get(metric, {})
            rows.append(check('spacing', metric, facts.get('native'), facts.get('calcforms'), LAYOUT_TOLERANCE_PX))
    for metric in ('text_class', 'border_class'):
        if any(r['category'] == 'colours' and r['metric'] == metric for r in rows):
            continue
        if (metric == 'text_class' and textless) or (metric == 'border_class' and kind == 'Label'):
            continue
        facts = colour_facts.get(metric, data.get('parity_measurements', {}).get(name, {}).get(metric, {}))
        rows.append(check('colours', metric, facts.get('native'), facts.get('calcforms'), unit='class'))
    for metric, facts in sorted(data.get('spacing_measurements', {}).get(name, {}).items()):
        rows.append(check('spacing', metric, facts.get('native'), facts.get('calcforms'), LAYOUT_TOLERANCE_PX))
    for metric, facts in sorted(data.get('colour_measurements', {}).get(name, {}).items()):
        if any(r['category'] == 'colours' and r['metric'] == metric for r in rows):
            continue
        rows.append(check('colours', metric, facts.get('native'), facts.get('calcforms'), unit='class'))
    for index, facts in enumerate(data.get('literal_text_measurements', {}).get(name, [])):
        rows.append(check('text', f'caption_{index}_literal_source', facts.get('native'), facts.get('calcforms'), unit='literal text'))
        rows.append(check('text', f'caption_{index}_retained_characters',
                          len(facts['native']), len(facts['calcforms']) if facts.get('calcforms') is not None else None,
                          unit='characters'))
    for metric in BEHAVIOURS:
        facts = data.get('behaviour_measurements', {}).get(name, {}).get(metric, {})
        if metric == 'tab_order' and 'tab_index' in expected and 'tab_index' in observed:
            rows.append(check('behaviour', 'tab_index', expected['tab_index'], observed['tab_index'], unit='index'))
        # A matching index is useful but does not prove traversal or skip rules.
        rows.append(check('behaviour', metric, facts.get('native'), facts.get('calcforms'), unit='ordered observations'))
    return dict(name=name, kind=kind, items=rows, text_measurements=text_measurements)


def report_observation(data, native, actual):
    header = list(map(float, data['excel_facts'].splitlines()[0].split(';')[:2]))
    if any(not math.isfinite(v) or v <= 0 for v in header):
        raise ValueError('Invalid native client dimensions')
    if data['zoom'] not in (100, 150):
        raise ValueError('Forms parity requires 100% or 150% inputs')
    scale = [native.width / header[0], native.height / header[1]]
    items = [check('layout', 'client_size', list(native.size), list(actual.size), LAYOUT_TOLERANCE_PX),
             check('layout', 'missing_controls', 0, len(data['measurements']['missing_in_calcforms']), unit='controls'),
             check('layout', 'extra_controls', 0, len(data['measurements']['missing_in_excel']), unit='controls')]
    for engine, image in (('excel', native), ('calcforms', actual)):
        items.append(check('layout', engine + '_capture_client_size',
                           data[engine]['geometry']['client_size'], list(image.size), unit='px'))
    definitions_by_name = definitions(data['form'])
    controls = [control_report(c, data, native, actual, scale, definitions_by_name.get(c['name'], {}))
                for c in data['measurements']['controls']]
    names = [c['name'] for c in controls]
    if len(names) != len(set(names)):
        raise ValueError('Duplicate control in forms parity input')
    return dict(form=data['form'], zoom=data['zoom'], scale_px_per_pt=scale, items=items, controls=controls,
                pixel_regression_guard=check('regression_only', 'different_fraction', 0,
                    data.get('pixels', {}).get('different_fraction'), .40, unit='fraction'))


def summarize(observations):
    counts = Counter()
    failures = []
    for observation in observations:
        for owner in [dict(name='(form)', items=observation['items']), *observation['controls']]:
            for item in owner['items']:
                counts[item['status']] += 1
                if item['measurement_count'] == 0:
                    counts['missing_measurements'] += 1
                if item['status'] == 'fail' and item['measurement_count']:
                    failures.append(dict(form=observation['form'], zoom=observation['zoom'], control=owner['name'], **item))
    failures.sort(key=lambda r: (-r['max_delta'], r['form'], r['zoom'], r['control'], r['metric']))
    return dict(pass_count=counts['pass'], fail_count=counts['fail'],
                missing_measurements=counts['missing_measurements'], measured_failures=failures,
                priority='measured geometry and behaviour failures; pixels excluded')


def replay(path):
    data = json.loads(path.read_text(encoding='utf-8-sig'))
    observations = []
    identities = set()
    if not data['observations']:
        raise ValueError('No form observations')
    for row in data['observations']:
        identity = (row['form'], row['zoom'])
        if identity in identities:
            raise ValueError('Duplicate form/zoom observation')
        identities.add(identity)
        images = []
        for engine, artifact in zip(('excel', 'calcforms'), row['images'], strict=True):
            if not artifact['file'].endswith('-' + engine + '.png'):
                raise ValueError('Image engine/order differs')
            image_path = path.parent / artifact['file']
            if not image_path.resolve().is_relative_to(path.parent.resolve()):
                raise ValueError('Reference image escapes comparison directory')
            if hashlib.sha256(image_path.read_bytes()).hexdigest() != artifact['sha256']:
                raise ValueError('Image hash differs: ' + artifact['file'])
            images.append(Image.open(image_path).convert('RGB'))
        observations.append(report_observation(row, *images))
    coverage = [check('coverage', f'{form}_scales', [100, 150],
                      sorted(z for f, z in identities if f == form), unit='percent')
                for form in sorted({f for f, _ in identities})]
    summary = summarize(observations)
    summary['pass_count'] += sum(r['status'] == 'pass' for r in coverage)
    summary['fail_count'] += sum(r['status'] == 'fail' for r in coverage)
    return dict(schema='calcforms.forms_parity.v1', title='FORMS PARITY',
                reference=path.resolve().relative_to(ROOT).as_posix(),
                reference_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                layout_tolerance_px=LAYOUT_TOLERANCE_PX, text_tolerance_px=TEXT_TOLERANCE_PX,
                full_parity_claimed=False, coverage=coverage,
                summary=summary, observations=observations)


def markdown(data):
    summary = data['summary']
    lines = ['# FORMS PARITY', '',
             f"{summary['pass_count']} pass; {summary['fail_count']} fail, including {summary['missing_measurements']} missing measurements.",
             'Layout tolerance: 1 px. Visible ink tolerance: 2 px. Exact line breaks and ordered behaviour require exact matches.',
             'Missing measurements fail coverage. Colour masks measure visible ink; they do not establish glyph identity or a baseline.',
             'Pixels are a coarse regression guard and do not set priorities.', '']
    for observation in data['observations']:
        lines += [f"## {observation['form']} — {observation['zoom']}%", '',
                  '| Control | Area / measurement | Result | Native | CalcForms | Maximum difference / tolerance |',
                  '|---|---|---|---|---|---|']
        for owner in [dict(name='(form)', items=observation['items']), *observation['controls']]:
            for item in owner['items']:
                def value(v):
                    def tidy(x):
                        return [tidy(a) for a in x] if isinstance(x, list) else round(x, 3) if isinstance(x, float) else x
                    return json.dumps(tidy(v), ensure_ascii=False).replace('|', '\\|') if v is not None else 'unmeasured (0)'
                lines.append(f"| {owner['name']} | {item['category']} / {item['metric']} | {item['status']} | {value(item['native'])} | {value(item['calcforms'])} | {value(item['max_delta'])} / {item['tolerance']} {item['unit']} |")
        lines.append('')
    return '\n'.join(lines).rstrip() + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, required=True)
    output = parser.add_mutually_exclusive_group(required=True)
    output.add_argument('--out', type=Path)
    output.add_argument('--check', type=Path)
    args = parser.parse_args()
    result = replay(args.reference)
    if args.check:
        if result != json.loads(args.check.read_text(encoding='utf-8-sig')):
            raise ValueError('Forms parity differs from recorded measurements')
        if args.check.with_suffix('.md').read_text(encoding='utf-8') != markdown(result):
            raise ValueError('Forms parity Markdown differs')
        print('FORMS PARITY: facts, image hashes, measurements and missing coverage replayed.')
    else:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(result, indent=2, allow_nan=False) + '\n', encoding='utf-8', newline='\n')
        args.out.with_suffix('.md').write_text(markdown(result), encoding='utf-8', newline='\n')
        print(json.dumps({k: v for k, v in result['summary'].items() if k != 'measured_failures'}))


if __name__ == '__main__':
    main()
