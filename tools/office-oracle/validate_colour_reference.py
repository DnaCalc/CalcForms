"""Replay property/paint colours without making font antialiasing a target."""
import json

from colour_measurements import paired_colours, scene_colours
from forms_parity import replay, markdown
from layout_corpus import ROOT

DIRECTORY = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.102'


def main():
    path = DIRECTORY / 'comparison.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    report = replay(path)
    assert len(data['observations']) == 8
    for row, measured in zip(data['observations'], report['observations'], strict=True):
        properties = row['native_colour_properties']
        assert row['colour_measurements'] == paired_colours(row, row['retained_scene'], properties)
        assert row['calcforms_colour_paint'] == scene_colours(row, row['retained_scene'])
        for control in measured['controls']:
            colours = [item for item in control['items'] if item['metric'] in {'fill_class', 'text_class'}]
            assert len(colours) == len({item['metric'] for item in colours})
            for item in colours:
                expected = 'fail' if control['name'] == 'ToggleOn' and item['metric'] == 'fill_class' else 'pass'
                assert item['status'] == expected, (row['form'], row['zoom'], control['name'], item)
        if row['form'] == 'LayoutCommon':
            assert properties['Disabled']['text']['rgb'] == [0, 0, 0]
            assert properties['Disabled']['effective_text_rgb'] == [[109, 109, 109]]
    assert report == json.loads((DIRECTORY / 'forms-parity.json').read_text(encoding='utf-8'))
    assert markdown(report) == (DIRECTORY / 'forms-parity.md').read_text(encoding='utf-8')
    print('Colour classes: text properties/paint agree for eight inputs; the pressed Toggle fill remains a measured failure; ink geometry stays separate.')


if __name__ == '__main__':
    main()
