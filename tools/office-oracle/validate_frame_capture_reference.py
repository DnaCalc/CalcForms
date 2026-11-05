"""A valid page background cannot qualify a blank Frame capture."""
import hashlib
import json
from PIL import Image
from capture_qualification import choose_capture
from layout_corpus import ROOT


def main():
    directory = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.89'
    data = json.loads((directory / 'comparison.json').read_text(encoding='utf-8'))
    assert data['schema'] == 'calcforms.frame_capture_qualification.v1' and not data['pixel_parity_claimed']
    for a in data['images']:
        assert hashlib.sha256((directory / a['file']).read_bytes()).hexdigest() == a['sha256']
    assert {r['zoom'] for r in data['observations']} == {100, 150}
    for row in data['observations']:
        z = row['zoom']
        parent = Image.open(directory / f'{z}-bad-parent.png').convert('RGB')
        composite = Image.open(directory / f'{z}-bad-composite.png').convert('RGB')
        valid = Image.open(directory / f'{z}-valid.png').convert('RGB')
        assert choose_capture(composite, parent, row['probes']) == row['rejected']
        assert not row['rejected']['verified']
        assert choose_capture(valid, valid, row['probes']) == row['accepted']
        assert row['accepted']['verified']
    visible = Image.open(directory / 'visible-100.png').convert('RGB')
    for sample in data['visible']['samples']:
        assert list(visible.getpixel(tuple(sample['pixel']))) == sample['actual_rgb'] == [240, 240, 240]
    print('Frame capture replay: both invalid variants rejected and native visible background corroborated.')


if __name__ == '__main__':
    main()
