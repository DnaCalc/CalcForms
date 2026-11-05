"""Build paired border evidence from the reviewed before inputs and a fresh owned capture."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image

from border_spacing import measurements
from colour_measurements import paired_colours, scene_colours
from forms_parity import replay, markdown
from layout_corpus import ROOT

DIRECTORY = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.98'
BEFORE = DIRECTORY.parent / 'oxforms-jbjp.102/comparison.json'


def build(session):
    session = session.resolve()
    if not session.is_relative_to(ROOT):
        raise ValueError('Capture session must stay in the repo')
    replay(BEFORE)
    before = json.loads(BEFORE.read_text(encoding='utf-8'))
    for stage in ('before', 'after'):
        directory = DIRECTORY / stage
        directory.mkdir(parents=True, exist_ok=True)
        rows = []
        for old in before['observations']:
            if stage == 'before':
                row = json.loads(json.dumps(old))
                scene = row['retained_scene']
                sources = [BEFORE.parent / a['file'] for a in row['images']]
            else:
                path = session / f"{old['form']}-border-final-{old['zoom']}/comparison.json"
                row = json.loads(path.read_text(encoding='utf-8'))
                row.pop('forms_parity', None)
                scene_path = session / row.pop('scene_file')
                if scene_path.resolve().parent != session:
                    raise ValueError('Scene path escapes capture session')
                scene = json.loads(scene_path.read_text(encoding='utf-8'))
                row['retained_scene'] = scene
                if row['excel_facts'] != old['excel_facts']:
                    raise ValueError('Native geometry changed since colour property reads')
                row['native_colour_properties'] = old['native_colour_properties']
                sources = [path.parent / f'{engine}-client.png' for engine in ('excel', 'calcforms')]
                for engine, source in zip(('excel', 'calcforms'), sources, strict=True):
                    if hashlib.sha256(source.read_bytes()).hexdigest() != row[engine]['client']['sha256']:
                        raise ValueError('Captured image identity differs')
            native, actual = [Image.open(path).convert('RGB') for path in sources]
            row['calcforms_colour_paint'] = scene_colours(row, scene)
            row['colour_measurements'] = paired_colours(row, scene, row['native_colour_properties'])
            properties, spacing, colours, scans = measurements(row, scene, native, actual)
            row.update(parity_measurements=properties, spacing_measurements=spacing, border_scan_lines=scans)
            for name, values in colours.items():
                row['colour_measurements'][name].update(values)
            row['images'] = []
            for engine, source in zip(('excel', 'calcforms'), sources, strict=True):
                path = directory / f"{row['form']}-{row['zoom']}-{engine}.png"
                shutil.copyfile(source, path)
                row['images'].append(dict(file=path.name, sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
            rows.append(row)
        path = directory / 'comparison.json'
        path.write_text(json.dumps(dict(schema='calcforms.layout_references.v1', owner=before['owner'], observations=rows), indent=2) + '\n', encoding='utf-8', newline='\n')
        report = replay(path)
        path.with_name('forms-parity.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8', newline='\n')
        path.with_name('forms-parity.md').write_text(markdown(report), encoding='utf-8', newline='\n')
        print(stage, {k: v for k, v in report['summary'].items() if k != 'measured_failures'})


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--session', required=True, type=Path)
    build(parser.parse_args().session)
