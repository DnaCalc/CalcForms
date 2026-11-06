"""Measure the horizontal border interruption around a native Frame caption."""
import struct

from native_drawing import decode, records


def native_gap(raw, metrics, caption):
    source = records(raw)
    if any(kind in {9, 10, 11, 12, 17, 35, 36} for kind, _ in source):
        raise ValueError('Mapped Frame caption geometry is not qualified')
    text = [row for row in decode(raw, metrics) if row['text'] == caption]
    if len(text) != 1:
        raise ValueError('Frame caption must match exactly')
    excluded = [(i, list(struct.unpack_from('<4i', record, 8)))
                for i, (kind, record) in enumerate(source) if kind == 29 and len(record) == 24]
    if len(excluded) != 1 or sum(kind == 29 for kind, _ in source) != 1:
        raise ValueError('Frame needs one explicit caption exclusion')
    index, box = excluded[0]
    left, top, right, bottom = box
    clip = text[0]['clip_px']
    if not (index < text[0]['record'] and left < right and top == 0 < bottom
            and left <= clip[0] < clip[2] <= right and top <= clip[1] < clip[3] <= bottom):
        raise ValueError('Caption does not belong to its border gap')
    cells = text[0]['cell_edges_px']
    if not left <= cells[0] < cells[-1] <= right:
        raise ValueError('Caption advances do not fit its border gap')
    strokes = []
    for i, (kind, record) in enumerate(source[index + 1:text[0]['record']], index + 1):
        if kind != 76:
            continue
        if len(record) < 100:
            raise ValueError('Truncated Frame drawing record')
        x, y, width, height = struct.unpack_from('<4i', record, 24)
        if x < left < right < x + width and top <= y < y + height <= bottom and 0 < height < bottom / 3:
            if struct.unpack_from('<I', record, 40)[0] != 0x00F00021:
                raise ValueError('Frame requires public PATCOPY border strokes')
            strokes.append(dict(record=i, rect_px=[x, y, width, height]))
    if len(strokes) != 2:
        raise ValueError('Frame gap needs both etched top-border strokes')
    strokes.sort(key=lambda row: row['rect_px'][1])
    if strokes[0]['rect_px'][1] + strokes[0]['rect_px'][3] != strokes[1]['rect_px'][1]:
        raise ValueError('Frame top-border layers are not adjacent')
    return dict(caption=caption, exclusion_record=index, caption_record=text[0]['record'],
                exclusion_rect_px=box, border_strokes=strokes,
                horizontal_gap_px=[left, right - left], caption_advance_px=cells[-1] - cells[0],
                horizontal_padding_px=[cells[0] - left, right - cells[-1]])


def window_probes(image, origin, detail):
    left, _, right, _ = detail['exclusion_rect_px']
    y = origin[1] + detail['border_strokes'][0]['rect_px'][1]
    points = [[int(origin[0] + x), int(y)] for x in (left - 1, left, right - 1, right)]
    colours = [list(image.getpixel(tuple(point))) for point in points]
    if colours[0] not in ([160, 160, 160], [105, 105, 105]) or colours[3] != colours[0]:
        raise ValueError('Frame border does not meet both caption-gap boundaries')
    if colours[1:3] != [[240, 240, 240], [240, 240, 240]]:
        raise ValueError('Frame caption gap padding is not visible in the qualified window')
    return dict(points_px=points, colours=colours)


def runtime_gap(scene, node_id, caption, scale):
    nodes = {node['id']: node for node in scene['nodes']}
    node = nodes[node_id]
    root = nodes[scene['root']]
    if node['parent'] != root['id'] or any(not n['visible'] or n['transform'] != dict(sx=1.0, sy=1.0, tx=0.0, ty=0.0)
                                         for n in (node, root)):
        raise ValueError('Only qualified, visible root Frame geometry is supported')
    masks = [p for p in node['prims'] if p['op'] == 'fill_rect' and p['rect']['y'] == node['bounds']['y']
             and 0 < p['rect']['w'] < node['bounds']['w'] and p['rect']['h'] < node['bounds']['h'] / 2]
    text = [p for p in node['prims'] if p['op'] == 'draw_text']
    if len(masks) != 1 or len(text) != 1 or scene['text'][str(text[0]['run'])]['source'] != caption:
        raise ValueError('Runtime caption mask/literal is ambiguous')
    if text[0]['align'] != 'left' or text[0]['wrap']:
        raise ValueError('Runtime Frame caption requires a single left-aligned run')
    rect = masks[0]['rect']
    faces = [p for p in node['prims'] if p['op'] == 'fill_rect' and p['rect'] == node['bounds']]
    edges = [p for p in node['prims'] if p['op'] == 'draw_edge' and p['rect']['w'] == node['bounds']['w']
             and rect['y'] <= p['rect']['y'] < rect['y'] + rect['h']]
    if (len(faces) != 1 or masks[0]['paint'] != faces[0]['paint'] or len(edges) != 1
            or masks[0]['paint'].get('Solid', {}).get('alpha') != 255):
        raise ValueError('Caption mask must erase the actual Frame top border with its face')
    prims = node['prims']
    if not prims.index(faces[0]) < prims.index(edges[0]) < prims.index(masks[0]) < prims.index(text[0]):
        raise ValueError('Caption mask must erase the border before caption text is drawn')
    for n in (node, root):
        clip = n['clip']
        if clip and not (clip['x'] <= rect['x'] and clip['y'] <= rect['y']
                         and rect['x'] + rect['w'] <= clip['x'] + clip['w']
                         and rect['y'] + rect['h'] <= clip['y'] + clip['h']):
            raise ValueError('Runtime caption gap is clipped')
    advance = scene['text'][str(text[0]['run'])]['metrics']['advance']
    origin = text[0]['rect']['x']
    if not rect['x'] <= origin < origin + advance <= rect['x'] + rect['w']:
        raise ValueError('Runtime caption advances do not fit the border mask')
    return dict(horizontal_gap_px=[(rect['x'] - node['bounds']['x']) * scale, rect['w'] * scale], mask=rect,
                caption_advance_px=advance * scale,
                horizontal_padding_px=[(origin - rect['x']) * scale, (rect['x'] + rect['w'] - origin - advance) * scale])
