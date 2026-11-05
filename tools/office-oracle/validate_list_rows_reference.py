"""Replay the owned native ListBox pixels and independent row runs."""
import hashlib
import json

from PIL import Image

from layout_corpus import ROOT
from validate_textbox_reference import verify_metrics


def main():
    directory = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.87'
    data = json.loads((directory / 'comparison.json').read_text(encoding='utf-8'))
    assert data['schema'] == 'calcforms.list_rows.v1' and not data['pixel_parity_claimed']
    assert data['ownership']['excel_launches'] == 1 and data['ownership']['security_changes'] == 0
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
        roi = row['roi']
        verify_metrics(native.crop(roi), before.crop(roi), row['region_before'])
        verify_metrics(native.crop(roi), after.crop(roi), row['region_after'])
        assert row['region_after']['different_pixels'] < row['region_before']['different_pixels']
        assert all(a < b for a, b in zip(row['region_after']['mean_absolute_rgb'], row['region_before']['mean_absolute_rgb']))
        y0, y1, x0, x1 = row['native_selection_band'][0]
        assert all(native.getpixel((x0, y)) == (0, 120, 215) and native.getpixel((x1 - 1, y)) == (0, 120, 215) for y in range(y0, y1))
        nodes = {n['id']: n for n in row['nodes']}
        assert nodes[7]['children'] == [7903]
        child = nodes[7903]
        assert child['parent'] == 7 and child['clip'] == dict(x=13.5, y=115.5, w=127, h=69)
        text = [p for p in child['prims'] if p['op'] == 'draw_text']
        assert len(text) == 3 and len({p['run'] for p in text}) == 3
        assert [p['rect']['y'] for p in text] == [115.5, 125.25, 135]
        assert text[1]['paint']['Solid'] == dict(red=255, green=255, blue=255, alpha=255)
    print('ListBox references: independent rows, native blue bands, child clip and lower error at both scales verified.')


if __name__ == '__main__':
    main()
