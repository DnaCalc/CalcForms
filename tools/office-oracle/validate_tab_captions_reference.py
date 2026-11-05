"""Replay the bounded native TabStrip comparison."""
import hashlib
import json
from PIL import Image
from layout_corpus import ROOT
from validate_textbox_reference import verify_metrics


def main():
    directory = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.88'
    data = json.loads((directory / 'comparison.json').read_text(encoding='utf-8'))
    assert data['schema'] == 'calcforms.tab_captions.v1' and not data['pixel_parity_claimed']
    assert {r['zoom'] for r in data['observations']} == {100, 150}
    for row in data['observations']:
        images = []
        for label, a in zip(('excel', 'before', 'after'), row['images']):
            assert a['file'] == f"{row['zoom']}-{label}.png"
            path = directory / a['file']
            assert hashlib.sha256(path.read_bytes()).hexdigest() == a['sha256']
            images.append(Image.open(path).convert('RGB'))
        native, before, after = images
        for probe in row['native_probes']:
            assert native.getpixel(tuple(probe['pixel'])) == tuple(probe['expected_rgb'])
        verify_metrics(native, before, row['pixels_before'])
        verify_metrics(native, after, row['pixels_after'])
        roi = row['roi']
        verify_metrics(native.crop(roi), before.crop(roi), row['region_before'])
        verify_metrics(native.crop(roi), after.crop(roi), row['region_after'])
        assert row['region_after']['different_pixels'] < row['region_before']['different_pixels']
        assert all(a < b for a, b in zip(row['region_after']['mean_absolute_rgb'], row['region_before']['mean_absolute_rgb']))
        node, = row['nodes']
        assert node['clip'] == node['bounds']
        text = [p for p in node['prims'] if p['op'] == 'draw_text']
        assert [row['text'][str(p['run'])]['source'] for p in text] == ['First', 'Second']
        assert text[1]['rect']['x'] < 50 and len({p['run'] for p in text}) == 2
    print('TabStrip references: separate caption runs, complete native backgrounds and lower two-scale errors verified.')


if __name__ == '__main__':
    main()
