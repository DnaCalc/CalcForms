"""Colour classes from resolved Scene paint and recorded public native colours."""
from forms_parity import color_class, TEXTLESS
from layout_measurements import GREETER_KINDS


def rgb(paint):
    colour = paint.get('Solid') if paint else None
    if not colour or colour['alpha'] != 255:
        return None
    return [colour[k] for k in ('red', 'green', 'blue')]


def scene_colours(row, scene):
    nodes = {node['id']: node for node in scene['nodes']}
    ids = {c['name']: c['calcforms'].get('node_id') for c in row['measurements']['controls']}
    if row['form'] == 'greeter':
        ids = {name: index for index, name in enumerate(GREETER_KINDS, 1)}
    control_ids = set(ids.values())
    results = {}
    for name, node_id in ids.items():
        node = nodes[node_id]
        foreground = []

        def text_paint(current):
            for prim in current['prims']:
                if prim['op'] == 'draw_text' and (colour := rgb(prim.get('paint'))) is not None:
                    foreground.append(colour)
            for child in current['children']:
                if child not in control_ids:
                    text_paint(nodes[child])

        text_paint(node)
        bounds = node['bounds']
        face, face_node = None, node
        # Transparent controls inherit the nearest enclosing full-site fill.
        # Never classify ClearType/antialias pixels as the configured text colour.
        visited = set()
        while face_node is not None:
            if face_node['id'] in visited:
                raise ValueError('Cyclic Scene parent chain')
            visited.add(face_node['id'])
            for prim in face_node['prims']:
                if prim['op'] != 'fill_rect':
                    continue
                rect = prim['rect']
                if (rect['x'] <= bounds['x'] and rect['y'] <= bounds['y']
                        and rect['x'] + rect['w'] >= bounds['x'] + bounds['w']
                        and rect['y'] + rect['h'] >= bounds['y'] + bounds['h']):
                    face = rgb(prim.get('paint'))
                    if face is not None:
                        break
            if face is not None:
                break
            face_node = nodes.get(face_node['parent'])
        results[name] = dict(text_rgb=[list(c) for c in sorted({tuple(c) for c in foreground})], fill_rgb=face,
                             fill_node=face_node['id'] if face_node else None)
    return results


def paired_colours(row, scene, native):
    actual = scene_colours(row, scene)
    result = {}
    for control in row['measurements']['controls']:
        name = control['name']
        properties, paint = native[name], actual[name]
        result[name] = {'fill_class': dict(native=color_class(properties['fill']['rgb']),
                                         calcforms=color_class(paint['fill_rgb']) if paint['fill_rgb'] else None)}
        if control['native']['kind'] not in TEXTLESS:
            result[name]['text_class'] = dict(native=sorted({color_class(c) for c in properties['effective_text_rgb']}),
                                              calcforms=sorted({color_class(c) for c in paint['text_rgb']}) or None)
    return result
