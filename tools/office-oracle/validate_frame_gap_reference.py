"""Replay two native Frame caption-gap measurements without Office."""
import hashlib
import json

from build_frame_gap_reference import BASE, DIRECTORY, DRAWING, augment
from forms_parity import markdown, replay
from layout_corpus import ROOT


def validate():
    path = DIRECTORY / 'comparison.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    for prefix, reference in [('baseline', BASE / 'comparison.json'), ('drawing', DRAWING / 'comparison.json')]:
        assert data[prefix + '_reference'] == reference.relative_to(ROOT).as_posix()
        assert data[prefix + '_sha256'] == hashlib.sha256(reference.read_bytes()).hexdigest()
    base = json.loads((BASE / 'comparison.json').read_text(encoding='utf-8'))
    drawing = json.loads((DRAWING / 'comparison.json').read_text(encoding='utf-8'))
    assert augment(base, drawing) == data['observations']
    for row in data['observations']:
        if 'frame_caption_gap_measurement' in row:
            parts = row['frame_caption_gap_measurement']['width_difference_components_px']
            assert abs(parts['caption_advance'] + parts['padding'] - parts['total_gap']) < 0.000001
    report = replay(path)
    before = replay(BASE / 'comparison.json')
    assert report == json.loads(path.with_name('forms-parity.json').read_text(encoding='utf-8'))
    assert markdown(report) == path.with_name('forms-parity.md').read_text(encoding='utf-8')
    assert report['summary']['missing_measurements'] == before['summary']['missing_measurements'] - 2 == 422
    assert report['summary']['pass_count'] == 1089 and report['summary']['fail_count'] == 521
    assert not report['full_parity_claimed']
    print('Frame caption border gaps: two measured failures at 100/150, 422 unknown rows remain; no height/font/pixel parity claim.')


if __name__ == '__main__':
    validate()
