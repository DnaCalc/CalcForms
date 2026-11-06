"""Observed check/radio drawing cells and caption origins, not pixel rankings."""
from drawing_parity import scene_text
from layout_measurements import GREETER_KINDS


def measurements(row, scene, size):
    scale = min(size[0] / scene['surface']['width'], size[1] / scene['surface']['height'])
    nodes = {n['id']: n for n in scene['nodes']}
    greeter_ids = {name: i for i, name in enumerate(GREETER_KINDS, 1)}
    text = scene_text(row, scene, size)
    paired, detail = {}, {}
    for c in row['measurements']['controls']:
        if c['native']['kind'] not in {'CheckBox', 'OptionButton'}:
            continue
        name = c['name']
        drawing = row['native_control_drawings'][name]
        glyphs = [r for r in drawing['text'] if r['font']['face'] == 'Marlett']
        captions = [r for r in drawing['text'] if r['font']['face'] != 'Marlett']
        if not glyphs or len(captions) != 1 or len(text.get(name, [])) != 1:
            continue
        # Marlett layers share one character cell. Do not guess glyph identity
        # from the private font encoding; measure only the emitted cell geometry.
        cells = [[r['cell_edges_px'][0], r['baseline_px'] - r['font']['ascent'],
                  r['cell_edges_px'][-1], r['baseline_px'] + r['font']['descent']] for r in glyphs]
        if any(cell != cells[0] for cell in cells):
            raise ValueError('Native symbolic glyph layers use different cells')
        native = cells[0]
        node = nodes[c['calcforms'].get('node_id', greeter_ids.get(name))]
        glyph = [p['rect'] for p in node['prims'] if p['op'] == ('ellipse' if c['native']['kind'] == 'OptionButton' else 'fill_rect')
                 and p['rect']['w'] < 15 and p['rect']['h'] < 15]
        # The outer radio circle is first; later ellipses are inset shading/dot.
        if not glyph:
            raise ValueError('Missing runtime outer check/radio primitive')
        rect = max(glyph, key=lambda r: r['w'] * r['h'])
        site_x, site_y = text[name][0]['site_origin_px']
        actual = [rect['x'] * scale - site_x, rect['y'] * scale - site_y,
                  (rect['x'] + rect['w']) * scale - site_x, (rect['y'] + rect['h']) * scale - site_y]
        native_size = [native[2] - native[0], native[3] - native[1]]
        actual_size = [actual[2] - actual[0], actual[3] - actual[1]]
        native_gap = captions[0]['origin_px'][0] - native[2]
        actual_gap = text[name][0]['origin_px'][0] - site_x - actual[2]
        paired[name] = dict(glyph_size=dict(native=native_size, calcforms=actual_size),
                            glyph_caption_gap=dict(native=native_gap, calcforms=actual_gap))
        detail[name] = dict(native_glyph_cell_px=native, calcforms_outer_glyph_px=actual,
                            native_caption_origin_px=captions[0]['origin_px'][0],
                            calcforms_caption_origin_px=text[name][0]['origin_px'][0] - site_x,
                            method='native emitted symbolic character cell versus retained outer glyph; caption gap to emitted text origin')
    return paired, detail
