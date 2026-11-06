"""Qualify native tab drawing rectangles against public strokes and saved windows."""
import struct

from native_drawing import decode, records


def native_headers(raw, metrics, captions):
    source = records(raw)
    if any(kind in {9, 10, 11, 12, 17, 35, 36} for kind, _ in source):
        raise ValueError('Mapped/transformed tab drawing is not qualified')
    if any(len(record) != 24 for kind, record in source if kind in {29, 30}):
        raise ValueError('Invalid clipping rectangle record')
    text = decode(raw, metrics)
    if [row['text'] for row in text] != captions:
        raise ValueError('Native header captions do not match in order')
    excluded = [(i, list(struct.unpack_from('<4i', record, 8)))
                for i, (kind, record) in enumerate(source) if kind == 29]
    if len(excluded) != len(captions) + 1:
        raise ValueError('Expected one exclusion per header followed by body exclusion')
    result, previous = [], -1
    for caption, output, (end, box) in zip(captions, text, excluded):
        if not previous < output['record'] < end:
            raise ValueError('Header drawing/text/exclusion order differs')
        left, top, right, bottom = box
        width, height = right - left, bottom - top
        if min(width, height) <= 0:
            raise ValueError('Empty native header')
        fills = []
        for i in range(previous + 1, end):
            kind, record = source[i]
            if kind != 76:
                continue
            if len(record) < 100 or struct.unpack_from('<I', record, 40)[0] != 0x00F00021:
                raise ValueError('Header requires public PATCOPY drawing records')
            if struct.unpack_from('<I', record, 88)[0] or struct.unpack_from('<I', record, 96)[0]:
                raise ValueError('Header bitmap-source drawing is not qualified')
            fills.append((i, list(struct.unpack_from('<4i', record, 24))))
        candidates = [(i, rect) for i, rect in fills if rect[0] == left and rect[1] == top
                      and rect[3] == height and 0 < rect[2] < width / 4]
        if len(candidates) != 1:
            raise ValueError('Native header left stroke is ambiguous')
        thickness = candidates[0][1][2]
        expected = [[right - thickness, top, thickness, height],
                    [left + thickness, top, width - 2 * thickness, thickness]]
        strokes = [candidates[0]]
        for rect in expected:
            matching = [(i, value) for i, value in fills if value == rect]
            if len(matching) != 1:
                raise ValueError('Native header right/top stroke does not establish rectangle')
            strokes.extend(matching)
        clip = output['clip_px']
        if not (left <= clip[0] < clip[2] <= right and top <= clip[1] < clip[3] <= bottom):
            raise ValueError('Caption clipping does not belong to its header')
        result.append(dict(caption=caption, rect_px=box, exclusion_record=end,
                           caption_record=output['record'], border_thickness_px=thickness,
                           stroke_records=[index for index, _ in strokes]))
        previous = end
    body_index, body = excluded[-1]
    clips = [list(struct.unpack_from('<4i', record, 8)) for i, (kind, record) in enumerate(source)
             if kind == 30 and i < text[0]['record']]
    if any(kind == 30 for kind, _ in source[text[0]['record']:body_index]):
        raise ValueError('Native clipping changes between the headers and shared body')
    if (not clips or any(clip != clips[0] for clip in clips) or clips[0][:2] != [0, 0] or body_index <= previous
            or body[0] != 0 or body[1] != result[-1]['rect_px'][3] or body[2:] != clips[0][2:]):
        raise ValueError('Shared tab body does not follow the header rectangles')
    return result


def window_probes(image, origin, headers):
    probes = []
    for header in headers:
        left, top, right, bottom = header['rect_px']
        # Top midpoint and outer-right midpoint avoid caption ink, rounded
        # corners and the preceding selected header's two-pixel overlap.
        points = [(int(origin[0] + (left + right) // 2), int(origin[1] + top)),
                  (int(origin[0] + right - 1), int(origin[1] + (top + bottom) // 2))]
        colours = [list(image.getpixel(point)) for point in points]
        if colours[0] not in ([255, 255, 255], [227, 227, 227]):
            raise ValueError('Native header top stroke is absent from qualified window')
        if colours[1] not in ([105, 105, 105], [160, 160, 160], [100, 100, 100], [128, 128, 128]):
            raise ValueError('Native header right stroke is absent from qualified window')
        probes.append(dict(caption=header['caption'], points_px=[list(p) for p in points], colours=colours))
    return probes


def runtime_headers(scene, node_id, captions, scale):
    nodes = {node['id']: node for node in scene['nodes']}
    node = nodes[node_id]
    ancestor, visited, clips = node, set(), []
    while ancestor is not None:
        if (ancestor['id'] in visited or not ancestor['visible']
                or ancestor['transform'] != dict(sx=1.0, sy=1.0, tx=0.0, ty=0.0)):
            raise ValueError('Runtime transformed/hidden/cyclic header ancestry is not qualified')
        visited.add(ancestor['id'])
        if ancestor['clip']:
            clips.append(ancestor['clip'])
        ancestor = nodes[ancestor['parent']] if ancestor['parent'] is not None else None
    prims = node['prims']
    edges = [(i, prim['rect']) for i, prim in enumerate(prims)
             if prim['op'] == 'draw_edge' and prim['rect']['h'] < node['bounds']['h'] / 2]
    if len(edges) != len(captions):
        raise ValueError('Runtime header edge count does not match captions')
    result = {}
    for index, rect in edges:
        if not index or prims[index - 1]['op'] != 'fill_rect' or prims[index - 1]['rect'] != rect:
            raise ValueError('Runtime header edge lacks its matching face')
        following = next((p for p in prims[index + 1:] if p['op'] == 'draw_text'), None)
        caption = scene['text'][str(following['run'])]['source'] if following is not None else None
        if caption not in captions or caption in result:
            raise ValueError('Runtime header literal does not match its edge')
        for clip in clips:
            if not (clip['x'] <= rect['x'] and clip['y'] <= rect['y']
                    and rect['x'] + rect['w'] <= clip['x'] + clip['w']
                    and rect['y'] + rect['h'] <= clip['y'] + clip['h']):
                raise ValueError('Runtime primary header edge is clipped')
        result[caption] = dict(caption=caption, rect_px=[rect['x'] * scale, rect['y'] * scale,
            (rect['x'] + rect['w']) * scale, (rect['y'] + rect['h']) * scale])
    return [result[caption] for caption in captions]


def sizes(headers):
    return [dimension for header in headers
            for dimension in (header['rect_px'][2] - header['rect_px'][0],
                              header['rect_px'][3] - header['rect_px'][1])]
