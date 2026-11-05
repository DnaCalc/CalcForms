"""Recompute the Frame comparison and check child-local geometry/clipping."""
import hashlib
import json

from PIL import Image

from layout_corpus import ROOT
from validate_textbox_reference import verify_metrics


def main():
    directory = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.85'
    data = json.loads((directory / 'comparison.json').read_text(encoding='utf-8'))
    assert data['schema'] == 'calcforms.frame_layout.v1' and not data['pixel_parity_claimed']
    owner = data['ownership']
    assert owner['excel_launches'] == 1 and owner['excel_launches_by_this_session'] == 0
    assert owner['closed'] == 'retained_by_original_session' and not owner['cleanup_notes']
    assert owner['workbook_unchanged'] and owner['security_changes'] == 0
    assert abs(data['native_top_margin_pt'] - data['runtime_top_margin_pt'] - 0.025) < 1e-6
    assert len(data['observations']) == 2
    assert {r['zoom'] for r in data['observations']} == {100, 150}
    for row in data['observations']:
        assert row['native_frame_readback'] == 'Width=174;Height=72;InsideWidth=171;InsideHeight=64.85;SpecialEffect=3;BorderStyle=0'
        assert row['native_capture_validation']['verified']
        assert row['excel_geometry']['client_size'] == row['runtime_geometry']['client_size']
        images = []
        assert len(row['images']) == 3
        for engine, artifact in zip(('excel', 'before', 'after'), row['images']):
            assert artifact['file'] == f"{row['zoom']}-{engine}.png"
            path = directory / artifact['file']
            assert hashlib.sha256(path.read_bytes()).hexdigest() == artifact['sha256']
            images.append(Image.open(path).convert('RGB'))
        reference, before, after = images
        verify_metrics(reference, before, row['pixels_before'])
        verify_metrics(reference, after, row['pixels_after'])
        crop = row['frame_roi']
        verify_metrics(reference.crop(crop), before.crop(crop), row['frame_before'])
        verify_metrics(reference.crop(crop), after.crop(crop), row['frame_after'])
        assert row['pixels_after']['different_pixels'] < row['pixels_before']['different_pixels']
        assert all(a < b for a, b in zip(row['frame_after']['mean_absolute_rgb'], row['frame_before']['mean_absolute_rgb']))
        previous = {r['name']: r for r in row['controls_before']}
        current = {r['name']: r for r in row['controls_after']}
        assert previous.keys() == current.keys()
        for name, control in current.items():
            assert control['delta_pt'] == [0, 0, 0, 0]
            assert control['calcforms']['bounds'] == previous[name]['calcforms']['bounds']
        assert current['Group.NestedInput']['calcforms']['paint_origin'] == [25.5, 56.625]
        assert current['Group.NestedLabel']['calcforms']['paint_origin'] == [25.5, 35.625]
        nodes = {n['id']: n for n in row['frame_nodes']}
        frame, client = nodes[1], nodes[1902]
        assert frame['clip'] == frame['bounds'] == dict(x=12, y=12, w=174, h=72)
        assert frame['children'] == [1902]
        assert any(p['op'] == 'draw_edge' and p['effect'] == 'etched' for p in frame['prims'])
        assert any(p['op'] == 'draw_text' and p['rect']['y'] < client['clip']['y'] for p in frame['prims'])
        assert client['parent'] == 1 and client['children'] == [1001, 1002] and not client['prims']
        assert client['clip'] == client['bounds'] == dict(x=13.5, y=17.625, w=171, h=64.875)
        assert nodes[1001]['parent'] == nodes[1002]['parent'] == 1902
    print('Frame references: lower errors at both scales, unchanged child-local bounds, separate caption/border and child clip verified.')


if __name__ == '__main__':
    main()
