"""Replay the observed two-line Label word-wrap case from saved facts/images."""
import json

from forms_parity import replay
from layout_corpus import ROOT

DIRECTORY = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.99'
CAPTION = 'Long clipped label AgjpQy'
NATIVE_LINES = ['Long clipped label', 'AgjpQy']


def runtime_lines(row):
    scene = row['retained_scene']
    node_id = next(c['calcforms']['node_id'] for c in row['measurements']['controls'] if c['name'] == 'Clipped')
    node = next(n for n in scene['nodes'] if n['id'] == node_id)
    groups = {}
    for p in node['prims']:
        if p['op'] == 'draw_text':
            groups.setdefault(p['rect']['y'], []).append((p['rect']['x'], scene['text'][str(p['run'])]['source']))
    return [' '.join(text for _, text in sorted(parts)) for _, parts in sorted(groups.items())]


def breaks(lines):
    assert ' '.join(lines) == CAPTION
    result = []
    offset = 0
    for line in lines[:-1]:
        offset += len(line) + 1
        result.append(offset)
    return result


def main():
    native_images = {}
    for stage in ('before', 'after'):
        path = DIRECTORY / stage / 'comparison.json'
        data = json.loads(path.read_text(encoding='utf-8'))
        report = replay(path)
        assert {r['zoom'] for r in data['observations']} == {100, 150}
        for row, observation in zip(data['observations'], report['observations'], strict=True):
            lines = runtime_lines(row)
            actual_breaks = breaks(lines)
            for metric in ('exact_line_breaks', 'wrap_point'):
                assert row['parity_measurements']['Clipped'][metric] == dict(native=[19], calcforms=actual_breaks)
            control = next(c for c in observation['controls'] if c['name'] == 'Clipped')
            if stage == 'before':
                assert lines == [CAPTION]
                native_images[row['zoom']] = row['images'][0]['sha256']
            else:
                assert lines == NATIVE_LINES
                assert row['images'][0]['sha256'] == native_images[row['zoom']]
                for metric in ('exact_line_breaks', 'wrap_point', 'visible_line_count'):
                    assert next(i for i in control['items'] if i['metric'] == metric)['status'] == 'pass'
                ink = next(i for i in control['items'] if i['metric'] == 'ink_bounds')
                assert ink['status'] == 'fail' and ink['measurement_count'] == 2
        assert report == json.loads(path.with_name('forms-parity.json').read_text(encoding='utf-8'))
    print('Label wrap: break offset 19 and two visible lines match at both scales; font-width residual stays failed.')


if __name__ == '__main__':
    main()
