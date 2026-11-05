"""Recompute the committed two-engine references without starting Office."""
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageStat

from layout_corpus import CORPUS, ROOT, load_corpus


def paths(controls, prefix=''):
    for control in controls:
        yield prefix + control['name']
        yield from paths(control.get('children', []), prefix + control['name'] + '.')


def main():
    directory = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.79'
    data = json.loads((directory / 'comparison.json').read_text())
    assert data['schema'] == 'calcforms.intrinsic_layout.v1'
    assert data['pixel_parity_claimed'] is False
    owner = data['ownership']
    assert owner['excel_launches'] == 1 and owner['excel_launches_by_this_session'] == 0
    assert owner['closed'] == 'retained_by_original_session' and not owner['cleanup_notes']
    assert owner['security_changes'] == 0 and owner['workbook_unchanged']
    cleanup = json.loads((directory / 'session-cleanup.json').read_text(encoding='utf-8-sig'))
    assert cleanup['schema'] == 'calcforms.run3_cleanup.v1'
    assert cleanup['excel_launches_this_run'] == 1 and cleanup['other_processes_stopped'] == 0
    assert cleanup['excel_process_absent'] and cleanup['final_runtime_process_absent']
    original, attached = cleanup['original_session'], cleanup['attached_session']
    assert original['excel_pid'] == attached['excel_pid'] == owner['excel_pid']
    assert original['closed'] in ('already_exited', 'closed', 'terminated_owned_handle')
    assert attached['closed'] == 'retained_by_original_session' and not attached['cleanup_notes']
    assert original['workbook_unchanged'] and attached['workbook_unchanged']
    assert original['workbook_sha256'] == attached['workbook_sha256'] == owner['workbook_sha256']
    assert original['security_changes'] == attached['security_changes'] == 0
    corpus = load_corpus()
    expected = {f['name']: set(paths(f['controls'])) for f in corpus['forms']}
    expected['greeter'] = {'Prompt', 'InputName', 'Greet', 'Loud', 'Output'}
    rows = data['observations']
    assert len(rows) == 8
    assert {(r['form'], r['zoom']) for r in rows} == {(f, z) for f in expected for z in (100, 150)}
    for row in rows:
        assert row['corpus_sha256'] == hashlib.sha256(CORPUS.read_bytes()).hexdigest()
        measurements = row['measurements']
        assert measurements['client_size_equal']
        assert not measurements['missing_in_calcforms'] and not measurements['missing_in_excel']
        assert {c['name'] for c in measurements['controls']} == expected[row['form']]
        for control in measurements['controls']:
            assert control['kind_equal']
            native, runtime = control['native'], control['calcforms']
            if 'font' in native:
                assert native['font'] == 'Tahoma'
                # Native Frame reports a zoom-rounded size after 150% Zoom.
                expected_size = 8.5 if (row['form'], row['zoom'], control['name']) == ('LayoutContainers', 150, 'Group') else 8.25
                assert native['font_size'] == expected_size
            if 'tab_index' in runtime:
                assert isinstance(runtime['tab_index'], int)
        assert all(r['size_pt'] == 8.25 for r in measurements['text_runs'])
        if row['form'] == 'greeter':
            assert row['excel_state'] == row['calcforms_observation'] == 'Initialize;text=Ada;caption=(ready);loud=False'
        images = []
        assert len(row['images']) == 2
        for engine, artifact in zip(('excel', 'calcforms'), row['images']):
            assert artifact['file'] == f'{row["form"]}-{row["zoom"]}-{engine}.png'
            path = directory / artifact['file']
            assert hashlib.sha256(path.read_bytes()).hexdigest() == artifact['sha256']
            images.append(Image.open(path).convert('RGB'))
        assert images[0].size == images[1].size == tuple(row['excel']['geometry']['client_size'])
        diff = ImageChops.difference(*images)
        channels = diff.split()
        nonzero = ImageChops.lighter(channels[0], ImageChops.lighter(channels[1], channels[2]))
        unequal = images[0].width * images[0].height - nonzero.histogram()[0]
        assert unequal == row['pixels']['different_pixels']
        assert ImageStat.Stat(diff).mean == row['pixels']['mean_absolute_rgb']
    real = json.loads((directory / 'real-input.json').read_text())
    assert real['schema'] == 'calcforms.real_input.v1'
    assert real['ownership']['excel_launches_by_this_session'] == 0
    assert not real['ownership']['cleanup_notes']
    states = {
        'physical-letter': 'Initialize|Change:Adaj;text=Adaj;caption=(ready);loud=False',
        'physical-tab-return': 'Initialize|Change:Adaj|Click:Hello, Adaj;text=Adaj;caption=Hello, Adaj;loud=False',
        'physical-drag': 'Initialize|Change:Adaj|Click:Hello, Adaj;text=Adaj;caption=Hello, Adaj;loud=False',
    }
    assert len(real['observations']) == 3
    for row in real['observations']:
        assert row['state'] == states[row['action']]
        for engine, artifact in zip(('excel', 'calcforms'), row['images']):
            assert artifact['file'] == f'{row["action"]}-{engine}.png'
            assert hashlib.sha256((directory / artifact['file']).read_bytes()).hexdigest() == artifact['sha256']
    trace = (directory / 'real-input-runtime.txt').read_text()
    assert 'action=char:j' in trace and 'action=key_down:9:0' in trace and 'action=key_down:13:0' in trace
    print('Layout references: eight clients/all intrinsic kinds and three real-input observations; geometry, image hashes and recomputed pixel errors verified; no pixel parity claim.')


if __name__ == '__main__':
    main()
