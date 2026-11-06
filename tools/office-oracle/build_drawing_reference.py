"""Build the current eight-case FORMS PARITY report with native drawing facts."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image

from border_spacing import measurements as border_measurements
from drawing_parity import measurements
from forms_parity import replay, markdown
from layout_corpus import ROOT
from native_drawing import decode

DIRECTORY = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.106'


def build(session):
    session = session.resolve()
    if not session.is_relative_to(ROOT):
        raise ValueError('Capture session must stay in repo')
    DIRECTORY.mkdir(parents=True, exist_ok=True)
    rows = []
    for form in ('greeter', 'LayoutCommon', 'LayoutSelection', 'LayoutContainers'):
        for zoom in (100, 150):
            path = session / f'{form}-drawing-{zoom}/comparison.json'
            row = json.loads(path.read_text(encoding='utf-8'))
            row.pop('forms_parity', None)
            scene = json.loads((session / row.pop('scene_file')).read_text(encoding='utf-8'))
            row['retained_scene'] = scene
            drawing = json.loads(path.with_name('native-drawing.json').read_text(encoding='utf-8'))
            emf = path.with_name(drawing['file'])
            raw = emf.read_bytes()
            if hashlib.sha256(raw).hexdigest() != drawing['sha256'] or decode(raw, drawing['font_metrics']) != drawing['text']:
                raise ValueError('Native drawing does not replay')
            target = DIRECTORY / f'{form}-{zoom}-native.emf'
            shutil.copyfile(emf, target)
            drawing['file'] = target.name
            row['native_drawing'] = drawing
            row['native_control_drawings'] = json.loads(path.with_name('control-drawings.json').read_text(encoding='utf-8'))
            for name, control_drawing in row['native_control_drawings'].items():
                source = path.with_name(control_drawing['file'])
                raw = source.read_bytes()
                if hashlib.sha256(raw).hexdigest() != control_drawing['sha256'] or decode(raw, control_drawing['font_metrics']) != control_drawing['text']:
                    raise ValueError('Native control drawing does not replay')
                target = DIRECTORY / f'{form}-{zoom}-{name}-native.emf'
                shutil.copyfile(source, target)
                control_drawing['file'] = target.name
            images = [Image.open(path.with_name(engine + '-client.png')).convert('RGB')
                      for engine in ('excel', 'calcforms')]
            if row['native_capture_validation']['verified'] is not True:
                raise ValueError('Native image is not qualified')
            properties, spacing, colours, scans = border_measurements(row, scene, *images)
            measured, detail = measurements(row, scene, drawing, images[0].size)
            for name, values in measured.items():
                properties.setdefault(name, {}).update(values)
            row.update(parity_measurements=properties, spacing_measurements=spacing,
                       drawing_text_measurements=detail, border_scan_lines=scans)
            for name, values in colours.items():
                row['colour_measurements'][name].update(values)
            row['images'] = []
            for engine in ('excel', 'calcforms'):
                source = path.with_name(engine + '-client.png')
                target = DIRECTORY / f'{form}-{zoom}-{engine}.png'
                if hashlib.sha256(source.read_bytes()).hexdigest() != row[engine]['client']['sha256']:
                    raise ValueError('Client image identity differs')
                shutil.copyfile(source, target)
                row['images'].append(dict(file=target.name, sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
            rows.append(row)
    reference = DIRECTORY / 'comparison.json'
    owner = json.loads((session / 'ownership.json').read_text(encoding='utf-8'))
    reference.write_text(json.dumps(dict(schema='calcforms.layout_references.v1', owner=owner, observations=rows), indent=2) + '\n', encoding='utf-8', newline='\n')
    report = replay(reference)
    reference.with_name('forms-parity.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8', newline='\n')
    reference.with_name('forms-parity.md').write_text(markdown(report), encoding='utf-8', newline='\n')
    print(json.dumps({k: v for k, v in report['summary'].items() if k != 'measured_failures'}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--session', type=Path, required=True)
    build(parser.parse_args().session)
