"""Office-independent interpretation of captured geometry and retained text runs."""
from __future__ import annotations

from layout_corpus import KINDS

GREETER_KINDS = {'Prompt': 'Label', 'InputName': 'TextBox', 'Greet': 'CommandButton',
                 'Loud': 'CheckBox', 'Output': 'Label'}


def native_controls(text, form):
    result = {}
    for line in text.splitlines():
        fields = line.split(';')
        if len(fields) < 6:
            continue  # form client dimensions/zoom
        if fields[1] in KINDS:
            kind, start, font_index = fields[1], 2, 6
        elif form == 'greeter' and fields[0] in GREETER_KINDS:
            kind, start, font_index = GREETER_KINDS[fields[0]], 1, 5
        else:
            raise ValueError('Unrecognized native geometry row: ' + line)
        if fields[0] in result:
            raise ValueError('Duplicate native control path: ' + fields[0])
        result[fields[0]] = {'kind': kind, 'bounds': list(map(float, fields[start:start + 4]))}
        if len(fields) >= font_index + 3:
            result[fields[0]].update(font=fields[font_index], font_size=float(fields[font_index + 1]),
                                     tab_index=int(fields[font_index + 2]))
    return result


def measure(data, scene):
    native = native_controls(data['excel_facts'], data['form'])
    runtime = {}
    if data['form'] == 'greeter':
        # The workbook regression verifies this flat fixture's persisted site
        # order. The control-blind Scene intentionally carries no MSForms names.
        nodes = {node['id']: node for node in scene['nodes']}
        for index, (name, kind) in enumerate(GREETER_KINDS.items(), 1):
            bounds = nodes[index]['bounds']
            runtime[name] = {'kind': kind, 'bounds': [bounds[k] for k in ['x', 'y', 'w', 'h']]}
        source = 'resident Scene, mapped by the verified flat greeter fixture site order'
    else:
        for line in data['calcforms_observation'].splitlines():
            fields = line.split(';')
            if len(fields) != 11 or fields[1] not in KINDS:
                raise ValueError('Unrecognized VBA geometry row: ' + line)
            if fields[0] in runtime:
                raise ValueError('Duplicate VBA control path: ' + fields[0])
            runtime[fields[0]] = {'kind': fields[1], 'bounds': list(map(float, fields[2:6])),
                                  'node_id': int(fields[6]), 'paint_origin': list(map(float, fields[7:9])),
                                  'font_size': float(fields[9]), 'tab_index': int(fields[10])}
        source = 'live production VBA controls, read by the authored fixture observation'
    rows = []
    for name in sorted(native.keys() & runtime.keys()):
        expected, actual = native[name], runtime[name]
        rows.append({'name': name, 'native': expected, 'calcforms': actual,
                     'delta_pt': [a - e for a, e in zip(actual['bounds'], expected['bounds'])],
                     'kind_equal': actual['kind'] == expected['kind']})
    runs = [{'text': run['source'], 'font_id': run['key']['font'],
             'size_pt': run['key']['size_milli_pt'] / 1000, **run['metrics']}
            for run in scene['text'].values()]
    rects = [{'node': node['id'], 'run': prim['run'], 'rect': prim['rect'], 'clip': prim['clip']}
             for node in scene['nodes'] for prim in node['prims'] if prim['op'] == 'draw_text']
    return {'bounds_source': source, 'controls': rows,
            'missing_in_calcforms': sorted(native.keys() - runtime.keys()),
            'missing_in_excel': sorted(runtime.keys() - native.keys()),
            'max_abs_delta_pt': max((abs(d) for row in rows for d in row['delta_pt']), default=0),
            'text_runs': runs, 'text_rects': rects,
            'client_size_equal': data['excel']['geometry']['client_size'] == data['calcforms']['geometry']['client_size']}
