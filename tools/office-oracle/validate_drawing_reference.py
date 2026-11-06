"""Replay raw native public drawings and all paired text geometry without Excel."""
import copy
import hashlib
import json

from PIL import Image

from border_spacing import measurements as border_measurements
from build_drawing_reference import DIRECTORY
from drawing_parity import measurements
from forms_parity import replay, markdown
from native_drawing import decode


def validate():
    path = DIRECTORY / 'comparison.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    owner = data['owner']
    assert owner['excel_launches'] == 1 and owner['interactive'] is False
    assert owner['security_changes'] == 0 and owner['input_desktop_switched'] is False
    assert len(data['observations']) == 8
    for row in data['observations']:
        assert row['native_capture_validation']['verified'] is True
        for drawing in [row['native_drawing'], *row['native_control_drawings'].values()]:
            source = DIRECTORY / drawing['file']
            assert source.resolve().parent == DIRECTORY.resolve()
            raw = source.read_bytes()
            assert hashlib.sha256(raw).hexdigest() == drawing['sha256']
            assert decode(raw, drawing['font_metrics']) == drawing['text']
        native, actual = [Image.open(DIRECTORY / a['file']).convert('RGB') for a in row['images']]
        paired, detail = measurements(row, row['retained_scene'], row['native_drawing'], native.size)
        properties, spacing, colours, scans = border_measurements(row, row['retained_scene'], native, actual)
        for name, facts in paired.items():
            properties.setdefault(name, {}).update(facts)
        assert properties == row['parity_measurements']
        assert detail == row['drawing_text_measurements']
        assert spacing == row['spacing_measurements'] and scans == row['border_scan_lines']
        for name, facts in colours.items():
            assert all(row['colour_measurements'][name][key] == value for key, value in facts.items())
    report = replay(path)
    assert report == json.loads(path.with_name('forms-parity.json').read_text(encoding='utf-8'))
    assert markdown(report) == path.with_name('forms-parity.md').read_text(encoding='utf-8')
    assert report['summary']['missing_measurements'] < 904
    assert report['summary']['measured_failures'] and report['full_parity_claimed'] is False
    # Removing native drawing evidence may not retain any of its measurement credit.
    row = copy.deepcopy(data['observations'][0])
    row['native_control_drawings'] = {}
    row['native_drawing']['text'] = []
    paired, _ = measurements(row, row['retained_scene'], row['native_drawing'], native.size)
    assert paired == {}
    print('Native public drawing: raw EMF, font measurements, literal line offsets, baselines and horizontal cell clipping replayed; missing evidence remains failed.')


if __name__ == '__main__':
    validate()
