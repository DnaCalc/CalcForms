import hashlib
import json
from PIL import Image, ImageChops, ImageStat

from capture_qualification import choose_capture
from layout_corpus import ROOT


def main():
    directory = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.84'
    data = json.loads((directory / 'comparison.json').read_text(encoding='utf-8'))
    assert data['schema'] == 'calcforms.capture_qualification.v1' and not data['pixel_parity_claimed']
    owner = data['ownership']
    assert owner['excel_launches'] == 1 and owner['excel_launches_by_this_session'] == 0
    assert owner['closed'] == 'retained_by_original_session' and not owner['cleanup_notes']
    expected = {'known-composite-150.png', 'known-parent-150.png', 'known-runtime-150.png', 'native-visible-150.png'}
    assert {a['file'] for a in data['images']} == expected
    for artifact in data['images']:
        assert hashlib.sha256((directory / artifact['file']).read_bytes()).hexdigest() == artifact['sha256']
    composite = Image.open(directory / 'known-composite-150.png').convert('RGB')
    parent = Image.open(directory / 'known-parent-150.png').convert('RGB')
    runtime = Image.open(directory / 'known-runtime-150.png').convert('RGB')
    known = data['known_case']
    assert choose_capture(composite, parent, known['qualification']['probes']) == known['qualification']
    assert known['qualification']['selected'] == 'parent'
    for image, key in [(composite, 'pixels_with_bad_composite'), (parent, 'pixels_with_parent')]:
        diff = ImageChops.difference(image, runtime)
        channels = diff.split()
        maximum = ImageChops.lighter(channels[0], ImageChops.lighter(channels[1], channels[2]))
        assert image.width * image.height - maximum.histogram()[0] == known[key]['different_pixels']
        assert ImageStat.Stat(diff).mean == known[key]['mean_absolute_rgb']
    visible = data['visible']
    assert Image.open(directory / 'native-visible-150.png').convert('RGB').getpixel(tuple(visible['sample'])) == tuple(visible['rgb']) == (240, 240, 240)
    rows = data['comparisons']
    assert len(rows) == 8
    assert {(r['form'], r['zoom']) for r in rows} == {(f, z) for f in ('greeter', 'LayoutCommon', 'LayoutSelection', 'LayoutContainers') for z in (100, 150)}
    assert all(r['client_size_equal'] and r['pixels']['comparable'] and r['validation']['verified'] for r in rows)
    for row in rows:
        if row['form'] == 'LayoutContainers':
            probes = row['validation']['probes']
            assert len(probes) == 1 and probes[0]['expected_rgb'] == [240, 240, 240]
            assert probes[0]['ole_color'] == 0x8000000f
    print('Capture references: visible native color, bad-child/valid-parent selection and eight qualified comparisons verified; pixels were selected, not synthesized.')


if __name__ == '__main__':
    main()
