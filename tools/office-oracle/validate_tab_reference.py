"""Replay qualified tab header geometry without Office or live UI."""
import hashlib
import json

from build_tab_reference import BASE, DIRECTORY, DRAWING, augment
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
    report = replay(path)
    before = replay(BASE / 'comparison.json')
    assert report == json.loads(path.with_name('forms-parity.json').read_text(encoding='utf-8'))
    assert markdown(report) == path.with_name('forms-parity.md').read_text(encoding='utf-8')
    assert report['summary']['missing_measurements'] == before['summary']['missing_measurements'] - 4 == 424
    assert report['summary']['pass_count'] == 1089 and report['summary']['fail_count'] == 521
    assert not report['full_parity_claimed']
    print('Four native header drawing rectangles measured at 100/150; all four are measured failures, 424 unknown rows remain.')


if __name__ == '__main__':
    validate()
