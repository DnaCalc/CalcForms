"""Replay complete and incomplete native clients using actual text-region reads."""
import hashlib
import json

from PIL import Image

from capture_qualification import choose_capture
from forms_parity import edges, text_roi, TEXTLESS
from layout_corpus import ROOT
from layout_measurements import native_controls

DIRECTORY = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.100'


def main():
    data = json.loads((DIRECTORY / 'reference.json').read_text(encoding='utf-8'))
    assert data['schema'] == 'calcforms.text_capture_qualification.v1'
    assert data['live_owner']['excel_launches'] == 1
    assert not data['live_owner']['interactive'] and not data['live_owner']['input_desktop_switched']
    assert {(case['form'], case['zoom']) for case in data['cases'] if case['name'] != 'interrupted-150'} == {
        (form, zoom) for form in ('greeter', 'LayoutCommon', 'LayoutSelection', 'LayoutContainers') for zoom in (100, 150)}
    assert len(data['cases']) == 9
    for case in data['cases']:
        images = []
        for artifact in case['images']:
            path = DIRECTORY / artifact['file']
            assert path.parent == DIRECTORY and hashlib.sha256(path.read_bytes()).hexdigest() == artifact['sha256']
            images.append(Image.open(path).convert('RGB'))
        assert images[0].size == images[1].size
        width, height = map(float, case['native_facts'].splitlines()[0].split(';')[:2])
        scale = [images[0].width / width, images[0].height / height]
        controls = native_controls(case['native_facts'], case['form'])
        probes = case['qualification']['text_probes']
        assert {probe['control'] for probe in probes} == {name for name, c in controls.items() if '.' not in name and c['kind'] not in TEXTLESS}
        for probe in probes:
            native = controls[probe['control']]
            assert probe['roi_px'] == text_roi(edges(native['bounds'], scale), native['kind'], scale)
            assert probe['font_height_px'] == native['font_size'] * scale[1]
            assert any(text.strip() for text in probe['sources'])
        result = choose_capture(*images, case['qualification']['probes'], probes)
        assert result == case['qualification']
        if case['name'] == 'interrupted-150':
            assert not result['verified'] and result['selected'] is None
            assert not next(s for s in result['candidates']['parent']['text_samples'] if s['control'] == 'Disabled')['matches']
            missing = {s['control'] for s in result['candidates']['composite']['text_samples'] if not s['matches']}
            assert {'Greet', 'Fractional', 'Clipped', 'LongInput', 'Disabled'} <= missing
        else:
            assert result['verified'] and result['selected'] == 'composite'
    print('Native text qualification: eight live form/scale cases pass; saved partial composite and parent both fail; images unchanged.')


if __name__ == '__main__':
    main()
