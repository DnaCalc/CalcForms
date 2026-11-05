"""Replay measured ComboBox edit/button/arrow geometry, without Office."""
from collections import Counter
import json
from pathlib import Path

from PIL import Image

from forms_parity import color_class, edges, region, replay
from layout_corpus import ROOT

DIRECTORY = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.97'


def bounds(points):
    return [min(x for x, _ in points), min(y for _, y in points),
            max(x for x, _ in points) + 1, max(y for _, y in points) + 1] if points else []


def native_button(image, site, scale):
    left, top, right, bottom = site
    sx, sy = scale
    # Above the arrow/text, scan the last 25pt for the button's edge classes.
    y = round(top + 6 * sy)
    xs = [x for x in range(round(right - 25 * sx), round(right - sx))
          if color_class(image.getpixel((x, y))) != 'white']
    if not xs:
        raise ValueError('No native button edge in measured ROI')
    x = min(xs) + round(2.25 * sx)
    ys = [y for y in range(round(top + 1.5 * sy), round(bottom - .5 * sy))
          if color_class(image.getpixel((x, y))) != 'white']
    if not ys:
        raise ValueError('No native vertical button edge in measured ROI')
    return [min(xs), min(ys), max(xs) + 1, max(ys) + 1]


def runtime_button(nodes, scale):
    raised = [p['rect'] for n in nodes for p in n['prims'] if p['op'] == 'draw_edge' and p['effect'] == 'raised']
    if len(raised) != 1:
        raise ValueError('Expected exactly one raised drop button')
    return edges([raised[0][k] for k in ('x', 'y', 'w', 'h')], scale)


def image_measurements(image, button):
    crop, roi = region(image, button)
    pixels = [(x + roi[0], y + roi[1], crop.getpixel((x, y)))
              for y in range(crop.height) for x in range(crop.width)]
    return dict(drop_arrow_bounds=bounds([(x, y) for x, y, c in pixels if max(c) < 64]),
                drop_button_fill_bounds=bounds([(x, y) for x, y, c in pixels if color_class(c) == 'control-face']),
                drop_button_fill_class=color_class(Counter(c for _, _, c in pixels).most_common(1)[0][0]))


def measurements(row, native, actual):
    width, height, _ = map(float, row['excel_facts'].splitlines()[0].split(';'))
    scale = [native.width / width, native.height / height]
    control = next(c for c in row['measurements']['controls'] if c['name'] == 'Dropdown')
    nb = native_button(native, edges(control['native']['bounds'], scale), scale)
    ab = runtime_button(row['parity_scene_nodes'], scale)
    nm, am = image_measurements(native, nb), image_measurements(actual, ab)
    spacing = {'drop_button_rectangle': dict(native=nb, calcforms=ab)}
    for metric in ('drop_arrow_bounds', 'drop_button_fill_bounds'):
        spacing[metric] = dict(native=nm[metric], calcforms=am[metric])
    colours = {'drop_button_fill_class': dict(native=nm['drop_button_fill_class'], calcforms=am['drop_button_fill_class'])}
    return dict(Dropdown=spacing), dict(Dropdown=colours)


def main():
    for stage in ('before', 'after'):
        path = DIRECTORY / stage / 'comparison.json'
        data = json.loads(path.read_text(encoding='utf-8'))
        report = replay(path)  # hashes and engine order checked first
        for row, observation in zip(data['observations'], report['observations'], strict=True):
            native, actual = [Image.open(path.parent / a['file']).convert('RGB') for a in row['images']]
            spacing, colours = measurements(row, native, actual)
            assert row['spacing_measurements'] == spacing
            assert row['colour_measurements'] == colours
            if stage == 'after':
                control = next(c for c in observation['controls'] if c['name'] == 'Dropdown')
                for metric in ('rectangle_edges', 'ink_bounds', 'alignment_offsets', 'drop_button_rectangle',
                               'drop_arrow_bounds', 'text_class', 'fill_class', 'drop_button_fill_class'):
                    item = next(i for i in control['items'] if i['metric'] == metric)
                    assert item['status'] == 'pass', item
                # Keep the remaining native multi-shade border mismatch explicit.
                item = next(i for i in control['items'] if i['metric'] == 'drop_button_fill_bounds')
                assert item['status'] == 'fail' and item['measurement_count'] == 2, item
        expected = json.loads(path.with_name('forms-parity.json').read_text(encoding='utf-8'))
        assert report == expected
    print('ComboBox spacing: both scales replay; text/button/arrow pass, inner border residual remains fail.')


if __name__ == '__main__':
    main()
