"""Replay circular glyph and full-site MultiPage paint evidence."""
import hashlib
import json
from PIL import Image
from layout_corpus import ROOT
from validate_textbox_reference import verify_metrics


def main():
    for bead in ('92', '93'):
        directory = ROOT / f'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.{bead}'
        data = json.loads((directory / 'comparison.json').read_text(encoding='utf-8'))
        assert data['schema'] == f'calcforms.paint_subset.{bead}.v1' and not data['pixel_parity_claimed']
        assert {r['zoom'] for r in data['observations']} == {100, 150}
        for row in data['observations']:
            images = []
            for label, artifact in zip(('excel', 'before', 'after'), row['images']):
                assert artifact['file'] == f"{row['zoom']}-{label}.png"
                path = directory / artifact['file']
                assert hashlib.sha256(path.read_bytes()).hexdigest() == artifact['sha256']
                images.append(Image.open(path).convert('RGB'))
            native, before, after = images
            verify_metrics(native, before, row['pixels_before'])
            verify_metrics(native, after, row['pixels_after'])
            for region in row['regions']:
                roi = region['roi']
                verify_metrics(native.crop(roi), before.crop(roi), region['before'])
                verify_metrics(native.crop(roi), after.crop(roi), region['after'])
                if bead == '92':
                    assert region['after']['different_pixels'] < region['before']['different_pixels']
                    assert sum(region['after']['mean_absolute_rgb']) < sum(region['before']['mean_absolute_rgb'])
            nodes = {n['id']: n for n in row['nodes']}
            if bead == '92':
                assert len([p for p in nodes[3]['prims'] if p['op'] == 'ellipse']) == 3
                assert len([p for p in nodes[4]['prims'] if p['op'] == 'ellipse']) == 2
            else:
                assert row['capture_validation']['verified']
                assert nodes[6]['clip'] == nodes[6]['bounds']
                assert nodes[6001]['clip'] == dict(x=211.5, y=117.75, w=159, h=126.75)
                text = [p for p in nodes[6]['prims'] if p['op'] == 'draw_text']
                assert len(text) == 2 and all(p['rect']['y'] < nodes[6001]['clip']['y'] for p in text)
    print('Circular glyph and MultiPage paint references replay; border error at 100% remains explicit.')


if __name__ == '__main__':
    main()
