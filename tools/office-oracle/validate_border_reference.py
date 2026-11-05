"""Recompute measured border depths/classes and keep unrelated failures visible."""
import json

from PIL import Image

from border_spacing import measurements
from build_border_reference import DIRECTORY
from colour_measurements import paired_colours
from forms_parity import replay, markdown


def main():
    failures = {}
    for stage in ('before', 'after'):
        path = DIRECTORY / stage / 'comparison.json'
        data = json.loads(path.read_text(encoding='utf-8'))
        report = replay(path)
        assert len(data['observations']) == 8
        failures[stage] = 0
        for row, observation in zip(data['observations'], report['observations'], strict=True):
            images = [Image.open(path.parent / a['file']).convert('RGB') for a in row['images']]
            properties, spacing, colours, scans = measurements(row, row['retained_scene'], *images)
            assert properties == row['parity_measurements'] and spacing == row['spacing_measurements']
            expected = paired_colours(row, row['retained_scene'], row['native_colour_properties'])
            for name, values in colours.items():
                expected[name].update(values)
            assert row['colour_measurements'] == expected and row['border_scan_lines'] == scans
            for control in observation['controls']:
                for item in control['items']:
                    if item['measurement_count'] and item['metric'] in {
                            'border_thickness', 'border_class', 'drop_button_rectangle', 'drop_button_border_thickness',
                            'drop_arrow_bounds', 'drop_button_fill_bounds', 'drop_button_border_class'}:
                        failures[stage] += item['status'] == 'fail'
                        if stage == 'after':
                            assert item['status'] == 'pass', (row['form'], row['zoom'], control['name'], item)
                if stage == 'after' and control['name'] == 'ToggleOn':
                    assert next(i for i in control['items'] if i['metric'] == 'fill_class')['status'] == 'pass'
        assert report == json.loads(path.with_name('forms-parity.json').read_text(encoding='utf-8'))
        assert markdown(report) == path.with_name('forms-parity.md').read_text(encoding='utf-8')
        assert report['summary']['missing_measurements'] == 904
    assert failures == dict(before=32, after=0), failures
    print('Border replay: 32 measured border failures become pass at 1px/class tolerance; missing coverage stays failed.')


if __name__ == '__main__':
    main()
