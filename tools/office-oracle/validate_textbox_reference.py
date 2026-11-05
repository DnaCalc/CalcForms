"""Check the measured TextBox correction against the same native pixels."""
import hashlib
import json

from PIL import Image, ImageChops, ImageStat

from layout_corpus import ROOT


def verify_metrics(reference, actual, stored):
    assert reference.size == actual.size
    diff = ImageChops.difference(reference, actual)
    channels = diff.split()
    nonzero = ImageChops.lighter(channels[0], ImageChops.lighter(channels[1], channels[2]))
    count = reference.width * reference.height
    assert stored['pixels'] == count
    assert stored['different_pixels'] == count - nonzero.histogram()[0]
    assert stored['mean_absolute_rgb'] == ImageStat.Stat(diff).mean


def main():
    directory = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.83'
    data = json.loads((directory / 'comparison.json').read_text(encoding='utf-8'))
    assert data['schema'] == 'calcforms.textbox_layout.v1' and not data['pixel_parity_claimed']
    owner = data['ownership']
    assert owner['excel_launches'] == 1 and owner['excel_launches_by_this_session'] == 0
    assert owner['closed'] == 'retained_by_original_session' and not owner['cleanup_notes']
    assert owner['workbook_unchanged'] and owner['security_changes'] == 0
    assert len(data['observations']) == 2
    assert {r['zoom'] for r in data['observations']} == {100, 150}
    for row in data['observations']:
        zoom = row['zoom']
        assert row['state'] == 'Initialize;text=Ada;caption=(ready);loud=False'
        images = []
        assert len(row['images']) == 2
        for engine, artifact in zip(('excel', 'calcforms'), row['images']):
            assert artifact['file'] == f'{zoom}-{engine}.png'
            path = directory / artifact['file']
            assert hashlib.sha256(path.read_bytes()).hexdigest() == artifact['sha256']
            images.append(Image.open(path).convert('RGB'))
        previous = row['before_runtime']
        assert previous['file'] == f'../oxforms-jbjp.79/greeter-{zoom}-calcforms.png'
        path = directory / previous['file']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == previous['sha256']
        before = Image.open(path).convert('RGB')
        reference, after = images
        verify_metrics(reference, before, row['pixels_before'])
        verify_metrics(reference, after, row['pixels_after'])
        crop = row['textbox_interior']
        verify_metrics(reference.crop(crop), before.crop(crop), row['textbox_before'])
        verify_metrics(reference.crop(crop), after.crop(crop), row['textbox_after'])
        assert all(a < b for a, b in zip(row['textbox_after']['mean_absolute_rgb'], row['textbox_before']['mean_absolute_rgb']))
        assert row['pixels_after']['different_pixels'] < row['pixels_before']['different_pixels']
        text = row['text_geometry']
        assert len(text) == 1 and abs(text[0]['rect']['x'] - 20.990551) < 0.001
        assert text[0]['rect']['y'] == 39 and 9.95 < text[0]['rect']['h'] < 9.97
    assert len(data['margin_calibration']) == 2
    for row in data['margin_calibration']:
        zoom = row['zoom']
        scale = zoom / 100 * 96 / 72
        positions = {}
        for margin, artifact in zip(('true', 'false'), row['images']):
            assert artifact['file'] == f'margin-{margin}-{zoom}-excel.png'
            path = directory / artifact['file']
            assert hashlib.sha256(path.read_bytes()).hexdigest() == artifact['sha256']
            image = Image.open(path).convert('RGB')
            positions[margin] = min(x for y in range(round(40*scale), round(50*scale)) for x in range(round(14*scale), round(55*scale)) if max(image.getpixel((x, y))) < 100)
        assert positions == row['text_left_dark_pixel']
        assert positions['true'] - positions['false'] == row['shift_pixels'] == 6 * scale
    print('TextBox references: same native pixels, lower errors at both scales, one font line and six-point native selection margin verified.')


if __name__ == '__main__':
    main()
