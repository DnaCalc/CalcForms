"""Measure border depth/classes on clear scan lines, plus ComboBox subparts."""
from combo_spacing import native_button, image_measurements
from forms_parity import color_class, definitions, edges, rounded


def profile(image, box, face):
    left, top, right, bottom = rounded(box)
    x, y = round(left + (right - left) / 3), round(top + (bottom - top) * .73)
    depth = min(8, (right - left) // 2, (bottom - top) // 2)
    points = [[(left + i, y) for i in range(depth)], [(x, top + i) for i in range(depth)],
              [(right - 1 - i, y) for i in range(depth)], [(x, bottom - 1 - i) for i in range(depth)]]
    depths, classes = [], []
    for samples in points:
        colours, face_run = [], 0
        for point in samples:
            colour = color_class(image.getpixel(point))
            colours.append(colour)
            face_run = face_run + 1 if colour == face else 0
            # Two white outer-edge pixels can match a white field's face.
            # Three consecutive face pixels establish the interior and stop
            # the scan before caption ink further into a short button.
            if face_run >= 3:
                break
        nonface = [i for i, colour in enumerate(colours) if colour != face]
        end = nonface[-1] + 1 if nonface else 0
        if end == depth:
            raise ValueError('Border scan does not reach the face in its clear ROI')
        depths.append(end)
        bands = []
        for colour in colours[:end]:
            if not bands or bands[-1] != colour:
                bands.append(colour)
        classes.append(bands)
    return dict(depths=depths, classes=classes, sample_pixels=[[list(point) for point in line] for line in points])


def runtime_button(scene, node_id, scale):
    node = next(n for n in scene['nodes'] if n['id'] == node_id)
    body = [p['rect'] for p in node['prims'] if p['op'] == 'fill_rect'
            and p['paint'].get('Solid') == dict(red=240, green=240, blue=240, alpha=255)
            and p['rect']['w'] < node['bounds']['w'] / 2 and p['rect']['h'] > 5]
    if len(body) != 1:
        raise ValueError('Expected exactly one ComboBox button face')
    return edges([body[0][k] for k in ('x', 'y', 'w', 'h')], scale)


def measurements(row, scene, native, actual):
    width, height = map(float, row['excel_facts'].splitlines()[0].split(';')[:2])
    scale = [native.width / width, native.height / height]
    properties, spacing, colours, scans = {}, {}, {}, {}
    authored = definitions(row['form'])
    for c in row['measurements']['controls']:
        name, kind = c['name'], c['native']['kind']
        if '.' in name:
            continue
        if kind in {'TextBox', 'CommandButton', 'ListBox'} or (
                kind == 'ToggleButton' and not authored.get(name, {}).get('value', False)):
            face = row['colour_measurements'][name]['fill_class']['native']
            n = profile(native, edges(c['native']['bounds'], scale), face)
            a = profile(actual, edges(c['calcforms']['bounds'], scale), face)
            properties[name] = dict(border_thickness=dict(native=n['depths'], calcforms=a['depths']),
                                    border_class=dict(native=n['classes'], calcforms=a['classes']))
            scans[name] = dict(native=n, calcforms=a)
        if kind == 'ComboBox':
            nb = native_button(native, edges(c['native']['bounds'], scale), scale)
            ab = runtime_button(scene, c['calcforms']['node_id'], scale)
            nm, am = image_measurements(native, nb), image_measurements(actual, ab)
            n, a = profile(native, nb, 'control-face'), profile(actual, ab, 'control-face')
            spacing[name] = dict(drop_button_rectangle=dict(native=nb, calcforms=ab),
                                 drop_button_border_thickness=dict(native=n['depths'], calcforms=a['depths']))
            for metric in ('drop_arrow_bounds', 'drop_button_fill_bounds'):
                spacing[name][metric] = dict(native=nm[metric], calcforms=am[metric])
            colours[name] = dict(drop_button_border_class=dict(native=n['classes'], calcforms=a['classes']))
            scans[name] = dict(native=n, calcforms=a)
    return properties, spacing, colours, scans
