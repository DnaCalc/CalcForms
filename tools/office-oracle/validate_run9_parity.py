"""Replay the run 9 font and Escape evidence without starting Office."""
from fractions import Fraction
import hashlib
import json
import math
from pathlib import Path
import struct

from build_render_reference import validate as validate_render
from inventory_reference import compare
from layout_corpus import ROOT
from native_drawing import decode, records

BEADS = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads'


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def validate():
    fonts = BEADS / 'oxforms-jbjp.101'
    for directory in (fonts / 'font-context', fonts / 'font-half-pixels'):
        data = read(directory / 'observations.json')
        assert data['schema'] == 'calcforms.native_font_context.v1'
        owner = data['owner']
        assert owner['excel_launches'] == 1 and not owner['interactive']
        assert not owner['input_desktop_switched'] and owner['security_changes'] == 0
        assert len(data['observations']) == 48
        count = 0
        for row in data['observations']:
            stem = f"{row['form']}-{row['zoom']}-{str(row['requested_font_size']).replace('.', '_')}"
            # Integer requests in the first capture were written without .0.
            folder = directory / stem
            if not folder.exists() and stem.endswith('_0'):
                folder = directory / stem[:-2]
            for name, drawing in row['drawings'].items():
                returned = row['returned_font_sizes'][name]
                assert math.isfinite(returned) and returned > 0
                path = folder / drawing['file']
                assert path.parent == folder
                raw = path.read_bytes()
                assert hashlib.sha256(raw).hexdigest() == drawing['sha256']
                assert decode(raw, drawing['font_metrics']) == drawing['text']
                if row['form'] == 'LayoutCommon' and name == 'InputName':
                    assert returned == row['requested_font_size']
                    exact = Fraction(str(row['requested_font_size'])) * row['zoom'] * Fraction(96, 7200)
                    midpoint = exact - Fraction(1, 2)
                    em = -(-midpoint.numerator // midpoint.denominator)
                    assert [struct.unpack_from('<i', record, 12)[0] for kind, record in records(raw) if kind == 82] == [-em]
                    count += 1
        assert count == 16
    final = fonts / 'final/comparison.json'
    validate_render(final)
    report = read(final.with_name('forms-parity.json'))
    assert report['summary']['pass_count'] == 1169
    assert report['summary']['fail_count'] == 449
    assert report['summary']['missing_measurements'] == 378
    for row in read(final)['observations']:
        if row['form'] in ('greeter', 'LayoutCommon'):
            run, = [run for run in row['retained_scene']['text'].values() if run['source'] == 'Ada']
            height = (run['metrics']['ascent'] + run['metrics']['descent']) * row['zoom'] * 96 / 7200
            assert abs(height - (13 if row['zoom'] == 100 else 19)) < .001
            assert run['key'].get('device_em_pixels') == (None if row['zoom'] == 100 else 16)

    escape = BEADS / 'oxforms-jbjp.123'
    native = read(escape / 'native-trace/observations.json')
    runtime = {row['mode']: row for row in read(escape / 'escape-runtime.json')}
    assert len(native['observations']) == 10 and len(runtime) == 5
    assert native['owner']['excel_pid'] == read(fonts / 'font-context/observations.json')['owner']['excel_pid']
    for row in native['observations']:
        expected = {side: dict(field.split('=', 1) for field in row[side].split(';')) for side in ('before', 'after')}
        actual = runtime[row['mode']]
        for side in ('before', 'after'):
            for field in ('focus', 'text', 'visible', 'trace'):
                assert actual[side][field] == expected[side][field], (row['mode'], side, field)
        assert expected['after']['log'].startswith(expected['before']['log'])
        assert actual['after']['log'][len(actual['before']['log']):] == expected['after']['log'][len(expected['before']['log']):]
    comparison = compare(read(BEADS / 'oxforms-jbjp.119/native-focus/observations.json'), read(escape / 'inventory-runtime.json'))
    assert comparison == read(escape / 'inventory-comparison.json')
    assert comparison['summary'] == dict(pass_count=320, fail_count=0)
    print('Run 9: 96 native font cases; fitted root edit metrics; 10 Escape cases; all 320 inventory fields match.')


if __name__ == '__main__':
    validate()
